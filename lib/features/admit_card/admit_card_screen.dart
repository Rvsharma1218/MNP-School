import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/app_utils.dart';
import '../../core/utils/file_saver.dart';
import '../../data/models/settings_model.dart';
import '../../data/models/student_model.dart';
import '../../data/services/database_service.dart';
import '../../data/services/providers.dart';

class AdmitCardScreen extends ConsumerStatefulWidget {
  final String? studentId;
  const AdmitCardScreen({super.key, this.studentId});

  @override
  ConsumerState<AdmitCardScreen> createState() => _AdmitCardScreenState();
}

class _AdmitCardScreenState extends ConsumerState<AdmitCardScreen> {
  bool _loading = true;
  bool _generatingPdf = false;
  String _examName = 'ANNUAL EXAMINATION 2026';
  String _selectedClass = 'All Classes';
  List<String> _availableClasses = ['All Classes'];
  List<StudentModel> _allStudents = [];
  List<StudentModel> _classStudents = [];
  StudentModel? _selectedStudent;

  final TextEditingController _searchCtrl = TextEditingController();
  List<StudentModel> _searchResults = [];

  static int _compareClassNames(String a, String b) {
    if (a == b) return 0;
    if (a == 'All Classes') return -1;
    if (b == 'All Classes') return 1;

    int getRank(String c) {
      final lower = c.trim().toLowerCase();
      if (lower.contains('play') || lower.contains('pre-nursery') || lower.contains('pg')) return 1;
      if (lower.contains('nursery') || lower == 'nur') return 2;
      if (lower.contains('lkg') || lower.contains('l.k.g') || lower.contains('lower kg')) return 3;
      if (lower.contains('ukg') || lower.contains('u.k.g') || lower.contains('upper kg')) return 4;
      if (lower.contains('kg')) return 5;

      final match = RegExp(r'\d+').firstMatch(lower);
      if (match != null) {
        final numVal = int.tryParse(match.group(0) ?? '');
        if (numVal != null) return 10 + numVal;
      }
      return 100;
    }

    final rankA = getRank(a);
    final rankB = getRank(b);
    if (rankA != rankB) return rankA.compareTo(rankB);
    return a.compareTo(b);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() {
      _searchResults = _allStudents.where((s) {
        final name = s.name.toLowerCase();
        final roll = (s.rollNumber ?? '').toLowerCase();
        final aadhar = (s.aadhaarNumber ?? '').toLowerCase();
        return name.contains(q) || roll.contains(q) || aadhar.contains(q);
      }).take(10).toList();
    });
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final db = DatabaseService.instance;
    final students = await db.getAllStudents();
    final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
    final classes = settings.schoolClasses.isNotEmpty ? settings.schoolClasses : SettingsModel.defaultClasses;

    final sortedClasses = [...classes]..sort(_compareClassNames);

    _allStudents = students;
    _availableClasses = ['All Classes', ...sortedClasses];

    if (widget.studentId != null && widget.studentId!.isNotEmpty) {
      _selectedStudent = students.where((s) => s.id == widget.studentId).firstOrNull;
      if (_selectedStudent != null && _selectedStudent!.className != null) {
        _selectedClass = _selectedStudent!.className!;
      }
    }

    await _loadClassExamTitle(_selectedClass);
    _filterClassStudents();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadClassExamTitle(String className) async {
    final title = await _getClassExamName(className);
    if (mounted) {
      setState(() => _examName = title);
    }
  }

  void _filterClassStudents() {
    if (_selectedClass == 'All Classes') {
      _classStudents = List.from(_allStudents);
    } else {
      _classStudents = _allStudents.where((s) => (s.className ?? '').trim().toLowerCase() == _selectedClass.trim().toLowerCase()).toList();
    }
  }

  Future<String> _getClassExamName(String className) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanKey = className.toLowerCase().replaceAll(' ', '_');
    return prefs.getString('admit_exam_title_$cleanKey') ??
           prefs.getString('admit_exam_title_global') ??
           'ANNUAL EXAMINATION 2026';
  }

  Future<void> _saveClassExamName(String className, String examName) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanKey = className.toLowerCase().replaceAll(' ', '_');
    await prefs.setString('admit_exam_title_$cleanKey', examName);
    await prefs.setString('admit_exam_title_global', examName);
  }

  // ─── LOCAL STORAGE FOR DYNAMIC TIMETABLE PER CLASS ───
  Future<List<Map<String, String>>> _getClassSchedule(String className) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanKey = className.toLowerCase().replaceAll(' ', '_');
    final stored = prefs.getString('admit_schedule_$cleanKey');
    if (stored != null) {
      try {
        final List<dynamic> list = jsonDecode(stored);
        return list.map((item) => Map<String, String>.from(item as Map)).toList();
      } catch (_) {}
    }

    // Default Fallback with Real Dates
    final now = DateTime.now();
    final df = DateFormat('dd/MM/yyyy');
    return [
      {'date': df.format(now.add(const Duration(days: 2))), 'subject': 'Mathematics', 'timing': '09:30 AM - 12:30 PM'},
      {'date': df.format(now.add(const Duration(days: 4))), 'subject': 'Science', 'timing': '09:30 AM - 12:30 PM'},
      {'date': df.format(now.add(const Duration(days: 6))), 'subject': 'Social Studies', 'timing': '09:30 AM - 12:30 PM'},
      {'date': df.format(now.add(const Duration(days: 8))), 'subject': 'English', 'timing': '09:30 AM - 12:30 PM'},
      {'date': df.format(now.add(const Duration(days: 10))), 'subject': 'Hindi', 'timing': '09:30 AM - 12:30 PM'},
    ];
  }

  Future<void> _saveClassSchedule(String className, List<Map<String, String>> schedule) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanKey = className.toLowerCase().replaceAll(' ', '_');
    await prefs.setString('admit_schedule_$cleanKey', jsonEncode(schedule));
  }

  // ─── CLASS SCHEDULE & EXAM NAME EDITOR MODAL ───
  Future<void> _showEditScheduleDialog() async {
    final targetClass = _selectedClass;
    final currentSchedule = await _getClassSchedule(targetClass);
    final currentExamName = await _getClassExamName(targetClass);

    final TextEditingController examTitleCtrl = TextEditingController(text: currentExamName);
    final List<Map<String, TextEditingController>> rows = currentSchedule.map((p) => {
      'date': TextEditingController(text: p['date'] ?? ''),
      'subject': TextEditingController(text: p['subject'] ?? ''),
      'timing': TextEditingController(text: p['timing'] ?? '09:30 AM - 12:30 PM'),
    }).toList();

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.88,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exam Name & Schedule',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                        Text(
                          'Class: $targetClass • Real Dates & Exam Title on PDF',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ─── Exam Title Input & Quick Presets ───
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC7D2FE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.badge_outlined, size: 16, color: Color(0xFF1E3A8A)),
                          SizedBox(width: 6),
                          Text(
                            'Exam Name / Title (Which Exam):',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: examTitleCtrl,
                        decoration: InputDecoration(
                          hintText: 'e.g. ANNUAL EXAMINATION 2026',
                          isDense: true,
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final preset in [
                              'ANNUAL EXAMINATION 2026',
                              'HALF YEARLY EXAMINATION',
                              'PRE-BOARD EXAMINATION 2026',
                              'PERIODIC TEST - 1',
                              'FINAL TERM EXAMINATION',
                            ]) ...[
                              ActionChip(
                                label: Text(preset, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                backgroundColor: isDark ? const Color(0xFF334155) : Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                onPressed: () {
                                  setSheetState(() {
                                    examTitleCtrl.text = preset;
                                  });
                                },
                              ),
                              const SizedBox(width: 6),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 4),

                // List of exam papers
                Expanded(
                  child: ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) {
                      final item = rows[idx];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                                  child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: item['subject'],
                                    decoration: const InputDecoration(
                                      labelText: 'Subject Name',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                  ),
                                ),
                                if (rows.length > 1) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                    onPressed: () {
                                      setSheetState(() => rows.removeAt(idx));
                                    },
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: ctx,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime(2025),
                                        lastDate: DateTime(2030),
                                      );
                                      if (picked != null) {
                                        setSheetState(() {
                                          item['date']!.text = DateFormat('dd/MM/yyyy').format(picked);
                                        });
                                      }
                                    },
                                    child: IgnorePointer(
                                      child: TextField(
                                        controller: item['date'],
                                        decoration: const InputDecoration(
                                          labelText: 'Exam Date (DD/MM/YYYY)',
                                          prefixIcon: Icon(Icons.calendar_today, size: 16),
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: item['timing'],
                                    decoration: const InputDecoration(
                                      labelText: 'Timing',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        setSheetState(() {
                          rows.add({
                            'date': TextEditingController(text: DateFormat('dd/MM/yyyy').format(DateTime.now())),
                            'subject': TextEditingController(text: 'Subject ${rows.length + 1}'),
                            'timing': TextEditingController(text: '09:30 AM - 12:30 PM'),
                          });
                        });
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Paper'),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final updated = rows.map((r) => {
                          'date': r['date']!.text.trim(),
                          'subject': r['subject']!.text.trim(),
                          'timing': r['timing']!.text.trim(),
                        }).toList();

                        await _saveClassSchedule(targetClass, updated);
                        final newTitle = examTitleCtrl.text.trim().isNotEmpty
                            ? examTitleCtrl.text.trim()
                            : 'ANNUAL EXAMINATION 2026';
                        await _saveClassExamName(targetClass, newTitle);

                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('✓ Saved exam schedule & title for $targetClass!'), backgroundColor: Colors.green),
                          );
                          setState(() {
                            _examName = newTitle;
                          });
                        }
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Save Details'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── PDF EXPORT / PRINT GENERATOR ───
  Future<void> _generateAndExportPDF({StudentModel? singleStudent}) async {
    setState(() => _generatingPdf = true);
    try {
      final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
      final schoolName = settings.schoolName.isNotEmpty ? settings.schoolName : 'MISSION NAVODAYA PUBLIC SCHOOL';

      final logoBytes = await AppUtils.loadAppImageBytes(settings.logoPath);
      final sigBytes = await AppUtils.loadAppImageBytes(settings.principalSignature);
      final stampBytes = await AppUtils.loadAppImageBytes(settings.schoolStamp);

      final pw.MemoryImage? logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;
      final pw.MemoryImage? sigImage = sigBytes != null ? pw.MemoryImage(sigBytes) : null;
      final pw.MemoryImage? stampImage = stampBytes != null ? pw.MemoryImage(stampBytes) : null;

      final targetStudents = singleStudent != null ? [singleStudent] : _classStudents;
      if (targetStudents.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No students found for Admit Card generation!')));
        }
        return;
      }

      final Map<String, pw.MemoryImage?> photoMap = {};
      for (final s in targetStudents) {
        if (s.photoPath != null && s.photoPath!.isNotEmpty) {
          final pBytes = await AppUtils.loadAppImageBytes(s.photoPath);
          if (pBytes != null) {
            photoMap[s.id] = pw.MemoryImage(pBytes);
          }
        }
      }

      final pdf = pw.Document();

      for (final s in targetStudents) {
        final photo = photoMap[s.id];
        final studentClass = s.className ?? _selectedClass;
        final schedule = await _getClassSchedule(studentClass);
        final examTitle = await _getClassExamName(studentClass);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            build: (pw.Context ctx) => _buildAdmitCardLayout(s, settings, logoImage, sigImage, photo, stampImage, schedule, examTitle),
          ),
        );
      }

      final bytes = await pdf.save();
      final filename = singleStudent != null
          ? 'AdmitCard_${singleStudent.name.replaceAll(' ', '_')}.pdf'
          : (_selectedClass == 'All Classes' ? 'All_Classes_Admit_Cards.pdf' : 'Class_${_selectedClass}_Admit_Cards.pdf');

      if (mounted) {
        await FileSaver.showSaveShareSheet(
          context,
          bytes: bytes,
          filename: filename,
          subject: '$schoolName - Admit Cards',
          category: FileCategory.admitCards,
          schoolName: schoolName,
          icon: Icons.badge_outlined,
          color: const Color(0xFF1E3A8A),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  pw.Widget _buildAdmitCardLayout(
    StudentModel s,
    SettingsModel settings,
    pw.MemoryImage? logo,
    pw.MemoryImage? sig,
    pw.MemoryImage? photo,
    pw.MemoryImage? stamp,
    List<Map<String, String>> schedule,
    String examTitle,
  ) {
    final schoolName = settings.schoolName.isNotEmpty ? settings.schoolName : 'MISSION NAVODAYA PUBLIC SCHOOL';
    final session = settings.currentSession.isNotEmpty ? settings.currentSession : '2026-27';
    final aadhaar = (s.aadhaarNumber != null && s.aadhaarNumber!.isNotEmpty) ? s.aadhaarNumber! : 'NOT SUBMITTED';

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromHex('#1E3A8A'), width: 2),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      padding: const pw.EdgeInsets.all(18),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header with Logo and Banner
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#1E3A8A'),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logo != null) ...[
                  pw.Container(
                    width: 46,
                    height: 46,
                    padding: const pw.EdgeInsets.all(2),
                    decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(5)),
                    child: pw.Image(logo, fit: pw.BoxFit.contain),
                  ),
                  pw.SizedBox(width: 10),
                ],
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        schoolName.toUpperCase(),
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 16, fontWeight: pw.FontWeight.bold),
                        maxLines: 2,
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        settings.address.isNotEmpty ? settings.address : 'Main Campus',
                        style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#0F172A'),
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColor.fromHex('#334155'), width: 0.8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text('SESSION: $session', style: pw.TextStyle(color: PdfColor.fromHex('#FDE047'), fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 3),
                      pw.Text('ADMIT CARD', style: pw.TextStyle(color: PdfColors.white, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // Exam Title Banner
          pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColor.fromHex('#1E3A8A'), width: 1.5),
                borderRadius: pw.BorderRadius.circular(6),
                color: PdfColors.white,
              ),
              child: pw.Text(
                examTitle.toUpperCase(),
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E3A8A')),
              ),
            ),
          ),
          pw.SizedBox(height: 14),

          // Student Details Row with Photo
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Photo Box
              pw.Container(
                width: 95,
                height: 115,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey500, width: 1),
                  borderRadius: pw.BorderRadius.circular(6),
                  color: PdfColors.white,
                ),
                child: photo != null
                    ? pw.ClipRRect(horizontalRadius: 5, verticalRadius: 5, child: pw.Image(photo, fit: pw.BoxFit.cover))
                    : pw.Center(
                        child: pw.Text('AFFIX\nPHOTO HERE', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500)),
                      ),
              ),
              pw.SizedBox(width: 16),

              // Details Grid
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildPdfRow('STUDENT NAME', s.name.toUpperCase()),
                    _buildPdfRow('ROLL NO / ADM NO', '${s.rollNumber ?? "N/A"}  /  ${s.admissionNumber.isNotEmpty ? s.admissionNumber : s.id}'),
                    _buildPdfRow('CLASS & SECTION', s.displayClass),
                    _buildPdfRow("FATHER'S NAME", s.fatherName.isNotEmpty ? s.fatherName.toUpperCase() : 'N/A'),
                    _buildPdfRow('DOB / GENDER', '${DateFormat("dd/MM/yyyy").format(s.dob)}  /  ${s.gender}'),
                    _buildPdfRow('AADHAAR NUMBER', aadhaar, isHighlight: true),
                  ],
                ),
              ),

              // QR Code
              pw.Container(
                padding: const pw.EdgeInsets.all(3),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(6)),
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: 'ADMIT:${s.name}|Roll:${s.rollNumber ?? s.id}|Class:${s.className}|Exam:$examTitle',
                  width: 54,
                  height: 54,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),

          // Exam Schedule Table (with real dates)
          pw.Text('EXAMINATION SCHEDULE & TIME TABLE', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E3A8A'))),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8), child: pw.Text('DATE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8), child: pw.Text('SUBJECT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8), child: pw.Text('TIMING', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8), child: pw.Text('INVIGILATOR SIGN', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5))),
                ],
              ),
              ...schedule.take(7).map((row) => pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8), child: pw.Text(row['date'] ?? '-', style: const pw.TextStyle(fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8), child: pw.Text(row['subject'] ?? '-', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8), child: pw.Text(row['timing'] ?? '-', style: const pw.TextStyle(fontSize: 9.5))),
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8), child: pw.Text('----------------', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey400))),
                ],
              )),
            ],
          ),
          pw.SizedBox(height: 12),

          // Instructions for Candidates
          pw.Text('INSTRUCTIONS FOR CANDIDATES:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
          pw.SizedBox(height: 4),
          pw.Text(
            '1. Candidate must bring this Admit Card to the Examination Centre on every exam day.\n'
            '2. Entry to the examination hall is permitted up to 15 minutes prior to commencement.\n'
            '3. Electronic devices, smartwatches, and mobile phones are strictly prohibited.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800, lineSpacing: 1.4),
          ),
          pw.Spacer(),

          // Signatures Section
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                children: [
                  pw.Container(width: 130, height: 1.2, color: PdfColors.grey600),
                  pw.SizedBox(height: 4),
                  pw.Text('Candidate Signature', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Container(width: 130, height: 1.2, color: PdfColors.grey600),
                  pw.SizedBox(height: 4),
                  pw.Text('Class Teacher Sign', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              // Director Sign & Official Stamp (Signature layered inside/over stamp)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 140,
                    height: 46,
                    child: pw.Stack(
                      alignment: pw.Alignment.center,
                      children: [
                        if (stamp != null)
                          pw.Opacity(
                            opacity: 0.88,
                            child: pw.Image(stamp, width: 44, height: 44, fit: pw.BoxFit.contain),
                          ),
                        if (sig != null)
                          pw.Image(sig, width: 120, height: 40, fit: pw.BoxFit.contain),
                      ],
                    ),
                  ),
                  pw.Container(width: 140, height: 1.2, color: PdfColor.fromHex('#1E3A8A')),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Director Sign',
                    style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E3A8A')),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfRow(String label, String value, {bool isHighlight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3.5),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 115, child: pw.Text('$label:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800))),
          pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: isHighlight ? PdfColor.fromHex('#1D4ED8') : PdfColors.black))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
    final schoolName = settings.schoolName.isNotEmpty ? settings.schoolName : 'MISSION NAVODAYA PUBLIC SCHOOL';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Admit Cards Studio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_calendar_rounded, color: Colors.white),
            tooltip: 'Edit Class Exam Schedule & Dates',
            onPressed: _showEditScheduleDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Hero Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.badge_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    schoolName,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '$_examName • Session ${settings.currentSession}',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Generate verified official Admit Cards with school logo, photo, QR code, subject time-table & principal seal.',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (widget.studentId != null && _selectedStudent != null) ...[
                    // ── SINGLE STUDENT VIEW (FOR PARENT PORTAL) ──
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.15),
                                  child: const Icon(Icons.school_rounded, color: Color(0xFF1E3A8A), size: 30),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedStudent!.name,
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Class: ${_selectedStudent!.displayClass}  •  Roll: ${_selectedStudent!.rollNumber ?? "N/A"}',
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                      ),
                                      Text(
                                        'Adm No: ${_selectedStudent!.admissionNumber.isNotEmpty ? _selectedStudent!.admissionNumber : _selectedStudent!.id}',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                icon: _generatingPdf
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.download_rounded, color: Colors.white),
                                label: Text(
                                  _generatingPdf ? 'Generating...' : 'Download Official Admit Card (PDF)',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E3A8A),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _generatingPdf ? null : () => _generateAndExportPDF(singleStudent: _selectedStudent),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    // ── MULTI-STUDENT STUDIO VIEW (FOR PRINCIPAL / TEACHERS) ──
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Individual Student Admit Card', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _searchCtrl,
                              decoration: InputDecoration(
                                hintText: 'Search by student name, roll number, or Aadhaar...',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchCtrl.text.isNotEmpty
                                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchCtrl.clear())
                                    : null,
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            if (_searchResults.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                constraints: const BoxConstraints(maxHeight: 200),
                                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: _searchResults.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (ctx, idx) {
                                    final s = _searchResults[idx];
                                    return ListTile(
                                      dense: true,
                                      title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text('Roll: ${s.rollNumber ?? "N/A"} • Class: ${s.displayClass}'),
                                      trailing: ElevatedButton.icon(
                                        icon: const Icon(Icons.download, size: 14),
                                        label: const Text('Admit Card', style: TextStyle(fontSize: 11)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF1E3A8A),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        ),
                                        onPressed: () {
                                          _generateAndExportPDF(singleStudent: s);
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Batch Print by Class
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Class Batch Download & Print', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                IconButton(
                                  icon: const Icon(Icons.settings_outlined, size: 18),
                                  tooltip: 'Edit Class Schedule',
                                  onPressed: _showEditScheduleDialog,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Class Filter
                            DropdownButtonFormField<String>(
                              initialValue: _selectedClass,
                              decoration: InputDecoration(
                                labelText: 'Filter Class for Batch Print',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: _availableClasses.map((c) => DropdownMenuItem(value: c, child: Text(c == 'All Classes' ? 'All Classes (Whole School)' : 'Class $c'))).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedClass = val;
                                    _filterClassStudents();
                                  });
                                  _loadClassExamTitle(val);
                                }
                              },
                            ),
                            const SizedBox(height: 12),

                            // Edit Class Schedule & Exam Title Button
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _showEditScheduleDialog,
                                icon: const Icon(Icons.edit_calendar_rounded, size: 18, color: Color(0xFF1E3A8A)),
                                label: Text('Edit Exam Title & Schedule ($_selectedClass)', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF1E3A8A)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Count chip
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                children: [
                                  const Icon(Icons.people_outline, color: Color(0xFF1E3A8A), size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${_classStudents.length} Admit Cards Ready for Printing & Export ($_selectedClass)',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A), fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Bulk Download button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _generatingPdf ? null : () => _generateAndExportPDF(),
                                icon: _generatingPdf
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.download_rounded),
                                label: Text(_generatingPdf ? 'Generating Hall Tickets...' : 'Download & Print Batch (${_classStudents.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E3A8A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
