import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/utils/file_saver.dart';
import '../../../data/models/exam_model.dart';
import '../../../data/models/result_model.dart';
import '../../../data/models/settings_model.dart';
import '../../../data/models/student_model.dart';
import '../../../data/services/database_service.dart';
import '../../../data/services/providers.dart';
import '../../../data/services/result_pdf_service.dart';
import '../../../data/services/session_service.dart';
import '../../whatsapp/whatsapp_service.dart';
import 'class_mark_entry_desk_screen.dart';
import 'create_exam_screen.dart';
import 'student_mark_entry_screen.dart';
import 'student_result_detail_screen.dart';

class ResultDashboardScreen extends ConsumerStatefulWidget {
  final String? initialStudentId;
  final StudentModel? initialStudent;

  const ResultDashboardScreen({super.key, this.initialStudentId, this.initialStudent});

  @override
  ConsumerState<ResultDashboardScreen> createState() => _ResultDashboardScreenState();
}

class _ResultDashboardScreenState extends ConsumerState<ResultDashboardScreen>
    with SingleTickerProviderStateMixin {
  static List<ExamModel>? _cachedExams;
  static List<ResultModel>? _cachedResults;

  late TabController _tabController;
  bool _loading = true;
  bool _initialStudentHandled = false;

  String _academicYear = '2025-2026';
  final List<String> _academicYears = ['2024-2025', '2025-2026', '2026-2027'];

  List<ExamModel> _exams = [];
  List<ResultModel> _results = [];
  List<StudentModel> _students = [];
  final Map<String, StudentModel> _studentLookup = {};

  void _rebuildStudentLookup() {
    _studentLookup.clear();
    for (final s in _students) {
      if (s.id.isNotEmpty) _studentLookup[s.id.toLowerCase()] = s;
      if (s.studentId.isNotEmpty) _studentLookup[s.studentId.toLowerCase()] = s;
      if (s.admissionNumber.isNotEmpty) _studentLookup[s.admissionNumber.toLowerCase()] = s;
      if (s.name.isNotEmpty) _studentLookup[s.name.trim().toLowerCase()] = s;
    }
  }

  StudentModel? _findStudent(ResultModel r) {
    final rId = r.studentId.trim().toLowerCase();
    if (rId.isNotEmpty) {
      final s = _studentLookup[rId];
      if (s != null) return s;
    }
    final rName = (r.studentName ?? '').trim().toLowerCase();
    if (rName.isNotEmpty) {
      final s = _studentLookup[rName];
      if (s != null) return s;
    }
    return null;
  }

  StudentModel _fallbackStudent(ResultModel r) {
    return StudentModel(
      id: r.studentId.isNotEmpty ? r.studentId : (r.id.isNotEmpty ? r.id : 'std_${DateTime.now().millisecondsSinceEpoch}'),
      admissionNumber: r.rollNumber?.isNotEmpty == true ? r.rollNumber! : r.studentId,
      studentId: r.studentId,
      name: (r.studentName != null && r.studentName!.isNotEmpty) ? r.studentName! : 'Student #${r.studentId}',
      fatherName: '',
      mobile: '',
      dob: DateTime(2010),
      gender: 'Other',
      address: '',
      studentType: 'school',
      className: r.className,
      rollNumber: r.rollNumber,
      status: 'active',
      admissionDate: r.createdAt,
      createdAt: r.createdAt,
    );
  }

  String _selectedClassFilter = 'All Classes';
  List<String> _availableClasses = ['All Classes'];
  String _searchQuery = '';
  int _resultsCurrentPage = 0;
  static const int _pageSize = 10;

  void _populateClassFilters(List<StudentModel> stus, SettingsModel settings) {
    final enrolledClasses = stus
        .map((s) => (s.className?.trim().isNotEmpty == true) ? s.className!.trim() : (s.course?.trim() ?? ''))
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();

    final Set<String> classSet = {};
    if (SessionService.instance.hasAllClassesAccess) {
      classSet.add('All Classes');
      classSet.addAll(enrolledClasses);
      classSet.addAll(settings.schoolClasses);
    } else {
      final allowed = SessionService.instance.filterAllowedClasses([...enrolledClasses, ...settings.schoolClasses]);
      if (allowed.length > 1) classSet.add('All Classes');
      classSet.addAll(allowed);
    }
    _availableClasses = classSet.toList()..sort(_compareClassNames);
  }

  @override
  void initState() {
    super.initState();
    final isTeacher = SessionService.instance.isTeacher;
    if (isTeacher && !SessionService.instance.hasAllClassesAccess) {
      final curSettings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
      final allowed = SessionService.instance.filterAllowedClasses(curSettings.schoolClasses);
      if (allowed.isNotEmpty) {
        _selectedClassFilter = allowed.first;
      }
    }
    final cachedStudents = ref.read(studentsProvider).valueOrNull;
    final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
    if (_cachedExams != null && _cachedResults != null && cachedStudents != null && cachedStudents.isNotEmpty) {
      _exams = _cachedExams!;
      _results = _cachedResults!;
      _students = cachedStudents;
      _rebuildStudentLookup();
      _populateClassFilters(cachedStudents, settings);
      _loading = false;
    }
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadDashboardData(isInitial: _loading);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData({bool isInitial = false}) async {
    if (isInitial && _exams.isEmpty && mounted) setState(() => _loading = true);
    final db = DatabaseService.instance;
    final data = await Future.wait([
      db.getAllExams(),
      db.getAllResults(),
      db.getAllStudents(),
    ]);
    final exams = data[0] as List<ExamModel>;
    final results = data[1] as List<ResultModel>;
    final students = data[2] as List<StudentModel>;
    final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
    _cachedExams = exams;
    _cachedResults = results;
    _populateClassFilters(students, settings);

    final enrolledClasses = students
        .map((s) => (s.className?.trim().isNotEmpty == true) ? s.className!.trim() : (s.course?.trim() ?? ''))
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();

    final Set<String> classSet = {'All Classes'};
    classSet.addAll(enrolledClasses);
    classSet.addAll(settings.schoolClasses);

    _availableClasses = classSet.toList()..sort(_compareClassNames);
    _exams = exams;
    _results = results;
    _students = students;
    _rebuildStudentLookup();

    // If an initial student was supplied (e.g. from Student Profile or search)
    final targetStudentId = widget.initialStudent?.id ?? widget.initialStudentId;
    if (!_initialStudentHandled && targetStudentId != null && targetStudentId.isNotEmpty) {
      _initialStudentHandled = true;
      final target = widget.initialStudent ?? students.where((s) => s.id == targetStudentId).firstOrNull;
      if (target != null) {
        final existing = results.where((r) => r.studentId == target.id).firstOrNull;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudentMarkEntryScreen(
                student: target,
                editResult: existing,
              ),
            ),
          ).then((_) {
            if (mounted) _loadDashboardData();
          });
        });
      }
    }

    if (mounted) setState(() => _loading = false);
  }

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

  static bool _matchesClassName(String c, String filterClass) {
    if (filterClass == 'All Classes') return true;
    final c1 = c.trim().toLowerCase();
    final target = filterClass.trim().toLowerCase();
    if (c1.isEmpty) return false;
    if (c1 == target) return true;

    final n1 = c1.replaceAll('class', '').replaceAll('th', '').replaceAll('st', '').replaceAll('nd', '').replaceAll('rd', '').replaceAll(' ', '');
    final nTarget = target.replaceAll('class', '').replaceAll('th', '').replaceAll('st', '').replaceAll('nd', '').replaceAll('rd', '').replaceAll(' ', '');
    if (n1.isNotEmpty && n1 == nTarget) return true;

    if (c1.contains(target) || target.contains(c1)) return true;
    return false;
  }

  bool _matchesClass(StudentModel s, String filterClass) {
    return _matchesClassName(s.className ?? s.course ?? '', filterClass);
  }



  Future<void> _deleteExam(ExamModel exam) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Exam'),
        content: Text('Are you sure you want to delete exam "${exam.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService.instance.deleteExam(exam.id);
      await _loadDashboardData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(duration: Duration(seconds: 3), content: Text('Exam deleted successfully'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteResult(ResultModel result, StudentModel? student) async {
    final sName = student?.name ?? 'Student #${result.studentId}';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Result?'),
        content: Text('Are you sure you want to delete the result of $sName for "${result.examName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService.instance.deleteResult(result.id);
      await _loadDashboardData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(duration: Duration(seconds: 3), content: Text('Result deleted successfully.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _shareResultPdf(ResultModel result, StudentModel? student) async {
    if (student == null) return;
    try {
      final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
      final path = await ResultPdfService.instance.saveResultPdfToDevice(
        result: result,
        student: student,
        settings: settings,
      );
      final subjects = result.subjects.map((s) => {
        'name': s.subjectName,
        'obtained': s.marks,
        'total': s.totalMarks,
      }).toList();
      final msg = WhatsAppService.buildResultVoucherText(
        studentName: student.name,
        rollNumber: student.rollNumber,
        admissionNumber: student.admissionNumber,
        className: student.displayClass,
        examName: result.examName,
        totalMarks: result.totalMarks,
        obtainedMarks: result.obtainedMarks,
        percentage: result.overallPercentage,
        grade: result.overallGrade,
        status: result.finalResultStatus,
        subjects: subjects,
        remarks: result.remarks,
        instituteName: settings.instituteName.isNotEmpty ? settings.instituteName : 'Mission Navodaya Public School',
        institutePhone: settings.mobile,
      );
      if (!mounted) return;
      await WhatsAppService.showResultShareSheet(
        context,
        studentName: student.name,
        phone: student.mobile,
        alternatePhone: student.alternateMobile,
        examName: result.examName,
        message: msg,
        filePath: path,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text("Error sharing PDF: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showResultActionsSheet(ResultModel r, StudentModel? student) {
    if (student == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                title: Text(
                  student.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Text("${student.displayClass} • ${r.examName} • ${r.obtainedMarks.toInt()}/${r.totalMarks.toInt()} (${r.overallPercentage.toStringAsFixed(1)}%)"),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (r.isPass ? Colors.green : Colors.red).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    r.finalResultStatus,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: r.isPass ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.share_rounded, color: Colors.green),
                title: const Text("Share Marksheet (WhatsApp)"),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareResultPdf(r, student);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_rounded, color: Color(0xFF0D9488)),
                title: const Text("Save PDF to Device"),
                onTap: () {
                  Navigator.pop(ctx);
                  _saveResultPdf(r, student);
                },
              ),
              ListTile(
                leading: const Icon(Icons.print_rounded, color: Color(0xFF1E3A8A)),
                title: const Text("Print / Preview Marksheet"),
                onTap: () async {
                  Navigator.pop(ctx);
                  final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
                  await ResultPdfService.instance.printOrShareResultPdf(
                    result: r,
                    student: student,
                    settings: settings,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text("Delete Result", style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteResult(r, student);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveResultPdf(ResultModel result, StudentModel? student) async {
    if (student == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 2),
            content: Text("Student information not found."),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    try {
      final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
      final path = await ResultPdfService.instance.saveResultPdfToDevice(
        result: result,
        student: student,
        settings: settings,
      );
      if (mounted) {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          if (!mounted) return;
          await FileSaver.showSaveShareSheet(
            context,
            bytes: bytes,
            filename: path.split(RegExp(r"[/\\]")).last,
            subject: 'Marksheet - ${student.name}',
            category: FileCategory.results,
            icon: Icons.picture_as_pdf_rounded,
            color: const Color(0xFF1E3A8A),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            content: Text("Error saving PDF: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadBulkMarksheetsPdf() async {
    var filtered = _results.where((r) {
      return r.obtainedMarks > 0 || r.subjects.any((s) => s.marks > 0 || s.theoryMarks > 0 || s.practicalMarks > 0 || s.internalMarks > 0);
    }).toList();

    if (_selectedClassFilter != 'All Classes') {
      filtered = filtered.where((r) {
        final student = _students.where((s) => s.id == r.studentId).firstOrNull;
        return student != null && _matchesClass(student, _selectedClassFilter);
      }).toList();
    }

    if (filtered.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No results available for $_selectedClassFilter to download!'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final items = <MapEntry<StudentModel, ResultModel>>[];
    for (final r in filtered) {
      final s = _students.where((stu) => stu.id == r.studentId).firstOrNull;
      if (s != null) {
        items.add(MapEntry(s, r));
      }
    }

    if (items.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No matching students found for selected results.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
    await ResultPdfService.instance.printOrShareBatchResultPdf(
      items: items,
      settings: settings,
      context: context,
      className: _selectedClassFilter,
      examName: items.first.value.examName,
    );
  }

  Future<void> _exportResultsCsv() async {
    var filtered = _results.where((r) {
      return r.obtainedMarks > 0 || r.subjects.any((s) => s.marks > 0 || s.theoryMarks > 0 || s.practicalMarks > 0 || s.internalMarks > 0);
    }).toList();

    if (_selectedClassFilter != 'All Classes') {
      filtered = filtered.where((r) {
        final student = _students.where((s) => s.id == r.studentId).firstOrNull;
        return student != null && _matchesClass(student, _selectedClassFilter);
      }).toList();
    }

    if (filtered.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No results to export for $_selectedClassFilter!'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final csvRows = <List<String>>[];
    csvRows.add([
      'S.No',
      'Roll No',
      'Student ID',
      'Student Name',
      'Father Name',
      'Mother Name',
      'Class',
      'Section',
      'Exam Title',
      'Academic Year',
      'Total Marks Obtained',
      'Total Maximum Marks',
      'Percentage (%)',
      'Grade',
      'Status',
      'Remarks',
    ]);

    for (int i = 0; i < filtered.length; i++) {
      final r = filtered[i];
      final s = _students.where((stu) => stu.id == r.studentId).firstOrNull;
      final rollNo = s?.rollNumber ?? s?.studentId ?? '-';
      final sName = s?.name ?? 'Student #${r.studentId}';
      final sClass = s?.className ?? s?.course ?? s?.displayClass ?? _selectedClassFilter;
      final sSection = s?.section ?? 'A';
      final sFather = s?.fatherName ?? '-';
      final sMother = s?.motherName ?? '-';
      final status = (r.status ?? (r.isPass ? 'PASS' : 'FAIL')).toUpperCase();

      csvRows.add([
        '${i + 1}',
        rollNo,
        s?.studentId ?? r.studentId,
        sName,
        sFather,
        sMother,
        sClass,
        sSection,
        r.examName,
        _academicYear,
        r.obtainedMarks.toStringAsFixed(1),
        r.totalMarks.toStringAsFixed(1),
        '${r.overallPercentage.toStringAsFixed(1)}%',
        r.overallGrade,
        status,
        r.remarks ?? '',
      ]);
    }

    final csvContent = csvRows
        .map((row) => row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(','))
        .join('\r\n');

    final cleanClass = _selectedClassFilter.replaceAll(' ', '_');
    final filename = 'Results_${cleanClass}_${DateTime.now().millisecondsSinceEpoch}.csv';

    final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
    try {
      final bytes = utf8.encode(csvContent);
      if (mounted) {
        await FileSaver.showSaveShareSheet(
          context,
          bytes: bytes,
          filename: filename,
          subject: 'Results Export CSV - $_selectedClassFilter',
          category: FileCategory.results,
          schoolName: settings.instituteName,
          icon: Icons.table_chart_rounded,
          color: const Color(0xFF0D9488),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            content: Text('Error exporting CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportResultsListPdf() async {
    var filtered = _results.where((r) {
      if (_selectedClassFilter == 'All Classes') return true;
      final s = _students.where((stu) => stu.id == r.studentId).firstOrNull;
      final sClass = s?.className ?? s?.course ?? '';
      return sClass.trim().toLowerCase() == _selectedClassFilter.trim().toLowerCase();
    }).toList();

    // Sort by roll number then name
    filtered.sort((a, b) {
      final sa = _students.where((s) => s.id == a.studentId).firstOrNull;
      final sb = _students.where((s) => s.id == b.studentId).firstOrNull;
      final rA = int.tryParse(sa?.rollNumber ?? '') ?? 999999;
      final rB = int.tryParse(sb?.rollNumber ?? '') ?? 999999;
      if (rA != rB) return rA.compareTo(rB);
      return (sa?.name ?? '').compareTo(sb?.name ?? '');
    });

    final items = <MapEntry<StudentModel, ResultModel>>[];
    for (final r in filtered) {
      final s = _students.where((stu) => stu.id == r.studentId).firstOrNull;
      if (s != null) {
        items.add(MapEntry(s, r));
      }
    }

    if (items.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No results available to generate PDF list.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
    await ResultPdfService.instance.printOrExportResultsListPdf(
      items: items,
      settings: settings,
      context: context,
      className: _selectedClassFilter,
      examName: items.first.value.examName,
      academicYear: _academicYear,
    );
  }

  Future<void> _shareResultsSummary() async {
    var filtered = _results.where((r) {
      return r.obtainedMarks > 0 || r.subjects.any((s) => s.marks > 0 || s.theoryMarks > 0 || s.practicalMarks > 0 || s.internalMarks > 0);
    }).toList();

    if (_selectedClassFilter != 'All Classes') {
      filtered = filtered.where((r) {
        final student = _students.where((s) => s.id == r.studentId).firstOrNull;
        return student != null && _matchesClass(student, _selectedClassFilter);
      }).toList();
    }

    final totalCount = filtered.length;
    final passCount = filtered.where((r) => r.isPass).length;
    final failCount = totalCount - passCount;
    final passRate = totalCount > 0 ? (passCount / totalCount * 100).toStringAsFixed(0) : '0';

    final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
    final summary = StringBuffer();
    summary.writeln('📊 *${settings.schoolName} - Results Summary*');
    summary.writeln('Academic Year: $_academicYear | Class: $_selectedClassFilter');
    summary.writeln('-----------------------------------');
    summary.writeln('Total Students Evaluated: $totalCount');
    summary.writeln('Passed: $passCount | Failed: $failCount');
    summary.writeln('Overall Pass Rate: $passRate%');
    summary.writeln('-----------------------------------');

    for (int i = 0; i < filtered.length && i < 15; i++) {
      final r = filtered[i];
      final s = _students.where((stu) => stu.id == r.studentId).firstOrNull;
      final sName = s?.name ?? 'Student #${r.studentId}';
      summary.writeln('${i + 1}. $sName: ${r.obtainedMarks.toInt()}/${r.totalMarks.toInt()} (${r.overallPercentage.toStringAsFixed(1)}%) - Grade: ${r.overallGrade} [${r.finalResultStatus}]');
    }
    if (filtered.length > 15) {
      summary.writeln('... and ${filtered.length - 15} more students.');
    }

    await Share.share(summary.toString());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: true,
      child: Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Results & Exams', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Academic Year Dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _academicYear,
                  dropdownColor: const Color(0xFF1E3A8A),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                  items: _academicYears.map((y) {
                    return DropdownMenuItem(value: y, child: Text(y));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _academicYear = val);
                  },
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Bulk Options',
            onSelected: (val) {
              if (val == 'bulk_pdf') {
                _downloadBulkMarksheetsPdf();
              } else if (val == 'results_list_pdf') {
                _exportResultsListPdf();
              } else if (val == 'bulk_csv') {
                _exportResultsCsv();
              } else if (val == 'share_summary') {
                _shareResultsSummary();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'results_list_pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_rounded, color: Colors.blueAccent, size: 20),
                    SizedBox(width: 10),
                    Text('Export Results List (PDF)', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'bulk_pdf',
                child: Row(
                  children: [
                    Icon(Icons.style_rounded, color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Text('Bulk PDF Marksheets', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'bulk_csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart_rounded, color: Color(0xFF0D9488), size: 20),
                    SizedBox(width: 10),
                    Text('Export Results (CSV)', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share_summary',
                child: Row(
                  children: [
                    Icon(Icons.share_rounded, color: Colors.green, size: 20),
                    SizedBox(width: 10),
                    Text('Share Results Summary', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(text: 'Exams (${_exams.length})'),
            Tab(text: 'Results (${_results.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildExamsTab(isDark),
                _buildResultsTab(isDark),
              ],
            ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              onPressed: () async {
                final res = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateExamScreen()),
                );
                if (res != null) {
                  await _loadDashboardData();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Create New Exam', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
    ),
  );
}

  // ─── TAB 1: EXAMS ───
  Widget _buildExamsTab(bool isDark) {
    if (_exams.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 14),
              const Text(
                'No Exams Created Yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap "+ Create New Exam" below to setup an examination with direct or detailed subject configuration.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateExamScreen()),
                  );
                  await _loadDashboardData();
                },
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Create Exam Now'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
      itemCount: _exams.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final ex = _exams[i];
        final isDetailed = ex.isDetailedMode;

        return Card(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          elevation: 1.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: const Color(0xFFE2E8F0)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClassMarkEntryDeskScreen(
                    initialExam: ex,
                    initialClass: ex.className.isNotEmpty ? ex.className : null,
                  ),
                ),
              ).then((_) => _loadDashboardData());
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.menu_book_rounded, color: Color(0xFF1E3A8A), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ex.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${ex.term} • ${ex.className} • ${ex.academicYear}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      // Status / Mode badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDetailed
                              ? Colors.purple.withValues(alpha: 0.1)
                              : Colors.teal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDetailed ? Colors.purple : Colors.teal,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          isDetailed ? 'Detailed' : 'Direct',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDetailed ? Colors.purple : Colors.teal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${ex.subjects.length} Subjects Configured',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E3A8A)),
                      ),
                      Row(
                        children: [
                          if (SessionService.instance.isPrincipal)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                              tooltip: 'Delete Exam',
                              onPressed: () => _deleteExam(ex),
                            ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A8A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ClassMarkEntryDeskScreen(
                                    initialExam: ex,
                                    initialClass: ex.className.isNotEmpty ? ex.className : null,
                                  ),
                                ),
                              ).then((_) => _loadDashboardData());
                            },
                            icon: const Icon(Icons.edit_note_rounded, size: 16),
                            label: const Text('Mark Entry Desk', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── TAB 2: RESULTS ───
  Widget _buildResultsTab(bool isDark) {
    // Include all created examination results
    var filteredResults = _results.toList();

    if (_selectedClassFilter != 'All Classes') {
      filteredResults = filteredResults.where((r) {
        final student = _findStudent(r);
        final cls = student?.className ?? student?.course ?? r.className ?? '';
        return _matchesClassName(cls, _selectedClassFilter);
      }).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      filteredResults = filteredResults.where((r) {
        final student = _findStudent(r);
        final sName = (student?.name ?? r.studentName ?? '').toLowerCase();
        final roll = (student?.rollNumber ?? r.rollNumber ?? '').toLowerCase();
        final sId = (student?.studentId ?? r.studentId).toLowerCase();
        final exam = r.examName.toLowerCase();
        return sName.contains(q) || roll.contains(q) || sId.contains(q) || exam.contains(q);
      }).toList();
    }

    // Sort strictly Roll Number-wise (numerical when available, then alphabetical/name)
    filteredResults.sort((a, b) {
      final sa = _findStudent(a);
      final sb = _findStudent(b);
      final rollA = (sa?.rollNumber ?? a.rollNumber ?? '').trim();
      final rollB = (sb?.rollNumber ?? b.rollNumber ?? '').trim();
      final numA = int.tryParse(rollA);
      final numB = int.tryParse(rollB);
      if (numA != null && numB != null) {
        final cmp = numA.compareTo(numB);
        if (cmp != 0) return cmp;
      } else if (rollA.isNotEmpty && rollB.isNotEmpty) {
        final cmp = rollA.compareTo(rollB);
        if (cmp != 0) return cmp;
      } else if (rollA.isNotEmpty) {
        return -1;
      } else if (rollB.isNotEmpty) {
        return 1;
      }
      final nameA = (sa?.name ?? a.studentName ?? '').toLowerCase();
      final nameB = (sb?.name ?? b.studentName ?? '').toLowerCase();
      return nameA.compareTo(nameB);
    });

    final totalCount = filteredResults.length;
    final passCount = filteredResults.where((r) => r.isPass).length;
    final failCount = totalCount - passCount;
    final passRate = totalCount > 0 ? (passCount / totalCount * 100).toStringAsFixed(0) : '0';

    final totalPages = (totalCount / _pageSize).ceil();
    final safePage = totalPages == 0 ? 0 : _resultsCurrentPage.clamp(0, totalPages - 1);
    final startIndex = totalCount == 0 ? 0 : safePage * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, totalCount);
    final pagedResults = filteredResults.sublist(startIndex, endIndex);

    return Column(
      children: [
        // Filter bar
        Container(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _availableClasses.contains(_selectedClassFilter) ? _selectedClassFilter : 'All Classes',
                  decoration: InputDecoration(
                    labelText: 'Class Filter',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: _availableClasses.map((c) {
                    return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedClassFilter = val;
                        _resultsCurrentPage = 0;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search student / exam...',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (val) => setState(() {
                    _searchQuery = val;
                    _resultsCurrentPage = 0;
                  }),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Quick Stats Strip
        if (_results.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            child: Row(
              children: [
                Expanded(
                  child: _buildMiniStatCard('Results', '$totalCount', const Color(0xFF1E3A8A), isDark),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniStatCard('Passed', '$passCount', Colors.green, isDark),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniStatCard('Failed', '$failCount', Colors.red, isDark),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniStatCard('Pass Rate', '$passRate%', Colors.teal, isDark),
                ),
              ],
            ),
          ),

        // Results list
        Expanded(
          child: filteredResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assessment_outlined, size: 54, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      Text(
                        'No results found for $_selectedClassFilter',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
                  itemCount: pagedResults.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final r = pagedResults[i];
                    final student = _findStudent(r);
                    final effectiveStudent = student ?? _fallbackStudent(r);
                    final isPass = r.isPass;

                    return Card(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: const Color(0xFFE2E8F0)),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final updated = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StudentResultDetailScreen(
                                student: effectiveStudent,
                                result: r,
                              ),
                            ),
                          );
                          if (updated == true && mounted) {
                            _loadDashboardData();
                          }
                        },
                        onLongPress: () => _showResultActionsSheet(r, effectiveStudent),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                                child: Text(
                                  r.overallGrade,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A), fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            effectiveStudent.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (effectiveStudent.rollNumber != null && effectiveStudent.rollNumber!.trim().isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Roll: ${effectiveStudent.rollNumber!.trim()}',
                                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "${effectiveStudent.displayClass} • Exam: ${r.examName}",
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "${r.obtainedMarks.toInt()}/${r.totalMarks.toInt()} (${r.overallPercentage.toStringAsFixed(1)}%) • Grade: ${r.overallGrade}",
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E3A8A)),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (isPass ? Colors.green : Colors.red).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  r.finalResultStatus,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isPass ? Colors.green : Colors.red,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, size: 22, color: Color(0xFF64748B)),
                                tooltip: "Actions",
                                onSelected: (val) async {
                                  if (student == null) return;
                                  if (val == "share") {
                                    _shareResultPdf(r, student);
                                  } else if (val == "download") {
                                    _saveResultPdf(r, student);
                                  } else if (val == "print") {
                                    final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
                                    await ResultPdfService.instance.printOrShareResultPdf(
                                      result: r,
                                      student: student,
                                      settings: settings,
                                    );
                                  } else if (val == "delete") {
                                    _deleteResult(r, student);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: "share",
                                    child: Row(
                                      children: [
                                        Icon(Icons.share_rounded, size: 18, color: Colors.green),
                                        SizedBox(width: 10),
                                        Text("Share / WhatsApp", style: TextStyle(fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: "download",
                                    child: Row(
                                      children: [
                                        Icon(Icons.download_rounded, size: 18, color: Color(0xFF0D9488)),
                                        SizedBox(width: 10),
                                        Text("Save PDF", style: TextStyle(fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: "print",
                                    child: Row(
                                      children: [
                                        Icon(Icons.print_rounded, size: 18, color: Color(0xFF1E3A8A)),
                                        SizedBox(width: 10),
                                        Text("Print / Preview", style: TextStyle(fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: "delete",
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                        SizedBox(width: 10),
                                        Text("Delete Result", style: TextStyle(fontSize: 13, color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Pagination Bar (10 results per page)
        if (totalPages > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${startIndex + 1}–$endIndex of $totalCount',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: safePage > 0 ? () => setState(() => _resultsCurrentPage = safePage - 1) : null,
                      tooltip: 'Previous Page',
                      visualDensity: VisualDensity.compact,
                    ),
                    Text(
                      'Page ${safePage + 1} of $totalPages',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: safePage < totalPages - 1 ? () => setState(() => _resultsCurrentPage = safePage + 1) : null,
                      tooltip: 'Next Page',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }


  Widget _buildMiniStatCard(String title, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        ],
      ),
    );
  }
}
