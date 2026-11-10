import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/file_saver.dart';
import '../../../data/models/exam_model.dart';
import '../../../data/models/result_model.dart';
import '../../../data/models/settings_model.dart';
import '../../../data/models/student_model.dart';
import '../../../data/services/database_service.dart';
import '../../../data/services/providers.dart';
import '../../../data/services/result_pdf_service.dart';
import '../../../data/services/session_service.dart';
import 'create_exam_screen.dart';
import 'student_mark_entry_screen.dart';
import 'student_result_detail_screen.dart';

class ClassMarkEntryDeskScreen extends ConsumerStatefulWidget {
  final ExamModel? initialExam;
  final String? initialClass;

  const ClassMarkEntryDeskScreen({
    super.key,
    this.initialExam,
    this.initialClass,
  });

  @override
  ConsumerState<ClassMarkEntryDeskScreen> createState() => _ClassMarkEntryDeskScreenState();
}

class _ClassMarkEntryDeskScreenState extends ConsumerState<ClassMarkEntryDeskScreen> {
  bool _loading = true;
  String _selectedClass = 'All Classes';
  List<String> _availableClasses = ['All Classes'];

  List<ExamModel> _allExams = [];
  ExamModel? _selectedExam;
  String _examTitle = 'Term Examination 2026';

  List<StudentModel> _allStudents = [];
  List<ResultModel> _allResults = [];
  String _searchQuery = '';
  String _statusFilter = 'All'; // 'All', 'Completed', 'Pending'
  StreamSubscription? _resultsSub;
  DateTime? _lastResultsReload;

  @override
  void initState() {
    super.initState();
    // Live automatic sync when marks are entered, edited, or saved anywhere
    _resultsSub = DatabaseService.onResultsChanged.stream.listen((_) {
      if (mounted) _loadResultsOnly();
    });
    _loadData(forceRefresh: false);
  }

  @override
  void dispose() {
    _resultsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadResultsOnly() async {
    final now = DateTime.now();
    if (_lastResultsReload != null && now.difference(_lastResultsReload!).inMilliseconds < 400) {
      return;
    }
    _lastResultsReload = now;
    final results = await DatabaseService.instance.getAllResults(forceRefresh: true);
    if (mounted) {
      setState(() {
        _allResults = results;
      });
    }
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() => _loading = true);
    final db = DatabaseService.instance;
    final cachedStudents = ref.read(studentsProvider).valueOrNull;
    final data = await Future.wait([
      (cachedStudents != null && cachedStudents.isNotEmpty && !forceRefresh)
          ? Future.value(cachedStudents)
          : db.getAllStudents(forceRefresh: forceRefresh),
      db.getAllResults(forceRefresh: forceRefresh),
      db.getAllExams(forceRefresh: forceRefresh),
    ]);
    final students = data[0] as List<StudentModel>;
    final results = data[1] as List<ResultModel>;
    final exams = data[2] as List<ExamModel>;
    final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();

    final enrolledClasses = students
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
    _allStudents = SessionService.instance.hasAllClassesAccess
        ? students
        : students.where((s) => SessionService.instance.canAccessClass(s.className)).toList();
    _allResults = results;
    _allExams = exams;

    // 1. Resolve selected exam first
    if (widget.initialExam != null) {
      _selectedExam = widget.initialExam;
      _examTitle = widget.initialExam!.title;
    } else if (_selectedExam != null) {
      _selectedExam = exams.firstWhere((e) => e.id == _selectedExam!.id, orElse: () => exams.first);
      _examTitle = _selectedExam!.title;
    } else if (exams.isNotEmpty) {
      _selectedExam = exams.first;
      _examTitle = exams.first.title;
    }

    // 2. Resolve selected class strictly from the selected exam's classes!
    final validClasses = _dropdownClasses;
    if (_selectedClass.isNotEmpty && validClasses.contains(_selectedClass)) {
      // PRESERVE user selected class filter!
    } else if (_selectedExam != null &&
        _selectedExam!.className.isNotEmpty &&
        _selectedExam!.className.trim().toLowerCase() != 'all classes') {
      final examClasses = _selectedExam!.className.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
      if (widget.initialClass != null && examClasses.any((ec) => _normalizeClass(ec) == _normalizeClass(widget.initialClass!))) {
        _selectedClass = widget.initialClass!;
      } else if (examClasses.length > 1) {
        _selectedClass = 'All Exam Classes';
      } else {
        _selectedClass = examClasses.first;
      }
    } else if (widget.initialClass != null && widget.initialClass!.isNotEmpty) {
      _selectedClass = widget.initialClass!;
    } else {
      _selectedClass = 'All Classes';
    }

    if (mounted) setState(() => _loading = false);
  }

  List<String> get _dropdownClasses {
    if (_selectedExam != null &&
        _selectedExam!.className.isNotEmpty &&
        _selectedExam!.className.trim().toLowerCase() != 'all classes') {
      final examClasses = _selectedExam!.className
          .split(',')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toList();
      if (examClasses.length > 1) {
        return ['All Exam Classes', ...examClasses];
      }
      return examClasses;
    }
    return _availableClasses;
  }

  static String _normalizeClass(String s) {
    return s.trim().toLowerCase().replaceAll(RegExp(r'^class\\s*', caseSensitive: false), '').trim();
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

  bool _matchesClass(StudentModel s, String filterClass) {
    if (filterClass == 'All Classes' || filterClass == 'All Exam Classes') return true;
    final c1 = (s.className ?? '').trim().toLowerCase();
    final c2 = (s.course ?? '').trim().toLowerCase();
    final target = filterClass.trim().toLowerCase();

    if (c1 == target || c2 == target) return true;

    final n1 = c1.replaceAll('class', '').replaceAll('th', '').replaceAll('st', '').replaceAll('nd', '').replaceAll('rd', '').replaceAll(' ', '');
    final nTarget = target.replaceAll('class', '').replaceAll('th', '').replaceAll('st', '').replaceAll('nd', '').replaceAll('rd', '').replaceAll(' ', '');
    if (n1.isNotEmpty && n1 == nTarget) return true;

    if (c1.contains(target) || target.contains(c1)) return true;
    return false;
  }

  List<StudentModel> get _scopeCandidates {
    var list = _allStudents;

    // 1. If an exam is selected and has specific classes, restrict strictly to the exam's classes!
    if (_selectedExam != null &&
        _selectedExam!.className.isNotEmpty &&
        _selectedExam!.className.trim().toLowerCase() != 'all classes') {
      final examClasses = _selectedExam!.className
          .split(',')
          .map((c) => _normalizeClass(c))
          .where((c) => c.isNotEmpty)
          .toList();
      list = list.where((s) {
        final sCls = _normalizeClass(s.className ?? s.course ?? '');
        return examClasses.any((ec) => ec == sCls || ec.contains(sCls) || sCls.contains(ec));
      }).toList();
    }

    // 2. If a specific class dropdown filter is active (not All Classes / All Exam Classes), apply it:
    if (_selectedClass != 'All Classes' && _selectedClass != 'All Exam Classes' && _selectedClass.isNotEmpty) {
      list = list.where((s) => _matchesClass(s, _selectedClass)).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((s) {
        final nameMatch = s.name.toLowerCase().contains(q);
        final rollMatch = (s.rollNumber ?? '').toLowerCase().contains(q);
        final idMatch = s.studentId.toLowerCase().contains(q);
        return nameMatch || rollMatch || idMatch;
      }).toList();
    }

    return list;
  }

  List<StudentModel> get _filteredStudents {
    final list = _scopeCandidates;
    if (_statusFilter == 'Completed') {
      return list.where((s) => _getResultForStudent(s) != null).toList();
    } else if (_statusFilter == 'Pending') {
      return list.where((s) => _getResultForStudent(s) == null).toList();
    }
    return list;
  }

  bool _matchesStudent(ResultModel r, StudentModel s) {
    final rId = r.studentId.trim().toLowerCase();
    final rName = (r.studentName ?? '').trim().toLowerCase();
    final sId = s.id.trim().toLowerCase();
    final sStuId = s.studentId.trim().toLowerCase();
    final sAdm = s.admissionNumber.trim().toLowerCase();
    final sName = s.name.trim().toLowerCase();
    final rRoll = (r.rollNumber ?? '').trim().toLowerCase();
    final sRoll = (s.rollNumber ?? '').trim().toLowerCase();
    final rClass = _normalizeClass(r.className ?? '');
    final sClass = _normalizeClass(s.className ?? s.course ?? '');

    // 1. Strict ID Match (Primary & Unique identity)
    if (rId.isNotEmpty) {
      if (rId == sId || rId == sStuId || rId == sAdm) return true;
    }

    // 2. Strict Roll + Class match (with leading zero normalization e.g. '01' == '1')
    if (rRoll.isNotEmpty && sRoll.isNotEmpty) {
      final rNum = int.tryParse(rRoll);
      final sNum = int.tryParse(sRoll);
      final rollMatches = (rNum != null && sNum != null && rNum == sNum) || rRoll == sRoll;
      if (rollMatches) {
        final classMatches = rClass.isEmpty || sClass.isEmpty || rClass == sClass || rClass.contains(sClass) || sClass.contains(rClass);
        if (classMatches) {
          if (rName.isEmpty || sName.isEmpty || rName == sName) return true;
          // Handles partial/spelling variations like "Adit Kumar" vs "Aditya Kumar" when Roll and Class are identical
          final rFirst = rName.split(' ').first;
          final sFirst = sName.split(' ').first;
          if (rFirst == sFirst || rFirst.startsWith(sFirst) || sFirst.startsWith(rFirst) || rName.contains(sFirst) || sName.contains(rFirst)) {
            return true;
          }
        }
      }
    }

    // 3. Name + Class match
    if (rName.isNotEmpty && sName.isNotEmpty && rName == sName) {
      final classMatches = rClass.isEmpty || sClass.isEmpty || rClass == sClass || rClass.contains(sClass) || sClass.contains(rClass);
      if (classMatches) return true;
    }

    return false;
  }

  ResultModel? _getResultForStudent(StudentModel s) {
    final selTitle = (_selectedExam?.title ?? _examTitle).trim().toLowerCase();
    return _allResults.where((r) {
      final isStud = _matchesStudent(r, s);
      if (!isStud) return false;
      final rEx = r.examName.trim().toLowerCase();
      return rEx == selTitle || rEx.contains(selTitle) || selTitle.contains(rEx);
    }).firstOrNull;
  }

  ExamModel? _getEffectiveExamForStudent(StudentModel student) {
    final sClass = (student.className ?? student.displayClass).trim().toLowerCase();
    final cleanTitle = _examTitle.trim().toLowerCase();

    bool matchesClass(ExamModel e) {
      final eClass = e.className.trim().toLowerCase();
      if (eClass.isEmpty || eClass == 'all classes') return true;
      final split = eClass.split(',').map((c) => _normalizeClass(c)).where((c) => c.isNotEmpty).toList();
      final normStudentClass = _normalizeClass(sClass);
      return split.any((ec) => ec == normStudentClass || ec.contains(normStudentClass) || normStudentClass.contains(ec));
    }

    // 1. Exact match for this student's class and exam title
    final exactClassMatch = _allExams.where((e) {
      final eTitle = e.title.trim().toLowerCase();
      return eTitle == cleanTitle && matchesClass(e) && e.className.trim().toLowerCase() != 'all classes' && e.className.trim().isNotEmpty;
    }).firstOrNull;
    if (exactClassMatch != null) return exactClassMatch;

    // 2. Global exam for All Classes with this exam title
    final globalMatch = _allExams.where((e) {
      final eTitle = e.title.trim().toLowerCase();
      final eClass = e.className.trim().toLowerCase();
      return eTitle == cleanTitle && (eClass.isEmpty || eClass == 'all classes');
    }).firstOrNull;
    if (globalMatch != null) return globalMatch;

    // 3. Fallback: match by title alone
    final titleMatch = _allExams.where((e) => e.title.trim().toLowerCase() == cleanTitle).firstOrNull;
    if (titleMatch != null) return titleMatch;

    return _selectedExam;
  }

  Future<void> _openMarkEntry(StudentModel student) async {
    final existing = _getResultForStudent(student);
    final saved = await Navigator.push<ResultModel>(
      context,
      MaterialPageRoute(
        builder: (_) => StudentMarkEntryScreen(
          student: student,
          exam: _getEffectiveExamForStudent(student),
          editResult: existing,
        ),
      ),
    );

    if (saved != null) {
      // 1. Instantly update in-memory list with zero delay (Optimistic UI Update)
      setState(() {
        final idx = _allResults.indexWhere((r) => r.id == saved.id || _matchesStudent(r, student));
        if (idx >= 0) {
          _allResults[idx] = saved;
        } else {
          _allResults.insert(0, saved);
        }
      });

      // 2. Clear reload throttle and persist fresh from DB
      _lastResultsReload = null;
      await _loadResultsOnly();

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Text('✓ Marks saved for ${student.name} • ${saved.division}'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    }
  }

  Future<void> _openResultDetails(StudentModel student, ResultModel result) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentResultDetailScreen(
          student: student,
          result: result,
        ),
      ),
    );
    await _loadResultsOnly();
  }

  Future<void> _deleteStudentResult(StudentModel s, ResultModel r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Result?'),
        content: Text('Are you sure you want to delete result for ${s.name} (${r.examName})?'),
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
      await DatabaseService.instance.deleteResult(r.id);
      await _loadResultsOnly();
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(duration: const Duration(seconds: 3), content: Text('Result deleted for ${s.name}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveSingleStudentPdf(StudentModel s, ResultModel r) async {
    try {
      final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
      final path = await ResultPdfService.instance.saveResultPdfToDevice(
        result: r,
        student: s,
        settings: settings,
      );
      if (mounted) {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          await FileSaver.showSaveShareSheet(
            context,
            bytes: bytes,
            filename: path.split(RegExp(r"[/\\]")).last,
            subject: 'Marksheet - ${s.name}',
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
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Text('Error saving PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadAllMarksheetsPdf() async {
    final filtered = _filteredStudents;
    final resultsWithStudents = <Map<String, dynamic>>[];

    for (final s in filtered) {
      final r = _getResultForStudent(s);
      if (r != null) {
        resultsWithStudents.add({'result': r, 'student': s});
      }
    }

    if (resultsWithStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No completed marksheet records found for this class!'), backgroundColor: Colors.orange),
      );
      return;
    }

    final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
    int count = 0;
    for (final item in resultsWithStudents) {
      await ResultPdfService.instance.printOrShareResultPdf(
        result: item['result'] as ResultModel,
        student: item['student'] as StudentModel,
        settings: settings,
      );
      count++;
      if (count >= 10) break; // prevent memory crash on printing dialogs
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generated PDF for $count students.'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _exportExcel() async {
    final filtered = _filteredStudents;
    final csvRows = <List<String>>[];

    // CSV Header (NO subject code, clean format)
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
      'Mode',
      'Total Marks Obtained',
      'Total Maximum Marks',
      'Percentage',
      'Grade',
      'Status',
      'Remarks',
    ]);

    int sNo = 1;
    for (final s in filtered) {
      final r = _getResultForStudent(s);
      final isDetailed = r != null &&
          (r.isDetailedMode ||
              r.subjects.any((sub) =>
                  sub.practicalMarks > 0 ||
                  sub.internalMarks > 0 ||
                  (sub.theoryMarks > 0 && sub.marks > 0 && sub.theoryMarks != sub.marks)));

      csvRows.add([
        '$sNo',
        s.rollNumber ?? '',
        s.studentId,
        s.name,
        s.fatherName,
        s.motherName ?? '',
        s.className ?? (s.course ?? s.displayClass),
        s.section ?? 'A',
        r?.examName ?? _examTitle,
        r != null ? (isDetailed ? 'Detailed' : 'Direct') : 'Pending',
        r != null ? r.obtainedMarks.toInt().toString() : 'N/A',
        r != null ? r.totalMarks.toInt().toString() : 'N/A',
        r != null ? '${r.overallPercentage.toStringAsFixed(1)}%' : 'N/A',
        r != null ? r.overallGrade : 'N/A',
        r?.status ?? 'PENDING',
        r?.remarks ?? '',
      ]);
      sNo++;
    }

    final csvContent = csvRows.map((row) => row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(',')).join('\n');
    final filename = 'Marks_Desk_${_selectedClass.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.csv';

    final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
    try {
      final bytes = utf8.encode(csvContent);
      if (mounted) {
        await FileSaver.showSaveShareSheet(
          context,
          bytes: bytes,
          filename: filename,
          subject: 'Marksheet Desk CSV - $_selectedClass',
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
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Text('Error exporting file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final candidates = _scopeCandidates;

    int completedCount = 0;
    for (final s in candidates) {
      if (_getResultForStudent(s) != null) completedCount++;
    }
    final totalCount = candidates.length;
    final pendingCount = totalCount - completedCount;
    final students = _filteredStudents;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Mark Entry Desk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => _loadData(forceRefresh: true),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Options',
            onSelected: (val) async {
              if (val == 'edit_exam') {
                if (_selectedExam != null) {
                  final updated = await Navigator.push<ExamModel>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateExamScreen(editExam: _selectedExam),
                    ),
                  );
                  if (updated != null) {
                    _selectedExam = updated;
                    _examTitle = updated.title;
                    await _loadData();
                  }
                }
              } else if (val == 'export_csv') {
                _exportExcel();
              } else if (val == 'batch_pdf') {
                _downloadAllMarksheetsPdf();
              }
            },
            itemBuilder: (context) => [
              if (_selectedExam != null)
                const PopupMenuItem(
                  value: 'edit_exam',
                  child: Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: Color(0xFF1E3A8A), size: 20),
                      SizedBox(width: 10),
                      Text('Edit Exam Subjects', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'export_csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart_rounded, color: Color(0xFF0D9488), size: 20),
                    SizedBox(width: 10),
                    Text('Export CSV / Excel', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'batch_pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Text('Batch PDF Download', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ─── Filter Section ───
                Container(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Class Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              key: ValueKey('desk_class_${_selectedExam?.id}_$_selectedClass'),
                              value: _dropdownClasses.contains(_selectedClass)
                                  ? _selectedClass
                                  : (_dropdownClasses.isNotEmpty ? _dropdownClasses.first : 'All Classes'),
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Class',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              items: _dropdownClasses.map((c) {
                                return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedClass = val;
                                    final cleanTitle = _examTitle.trim().toLowerCase();
                                    final targetClass = val.trim().toLowerCase();
                                    _selectedExam = _allExams.where((e) {
                                      final eTitle = e.title.trim().toLowerCase();
                                      final eClass = e.className.trim().toLowerCase();
                                      final split = eClass.split(',').map((c) => c.trim()).toList();
                                      return eTitle == cleanTitle && (eClass == targetClass || split.contains(targetClass));
                                    }).firstOrNull ?? _allExams.where((e) => e.title.trim().toLowerCase() == cleanTitle).firstOrNull;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Exam Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              key: ValueKey('desk_exam_$_examTitle'),
                              initialValue: _allExams.any((e) => e.title == _examTitle) ? _examTitle : (_allExams.isNotEmpty ? _allExams.first.title : _examTitle),
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Exam',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              items: _allExams.isNotEmpty
                                  ? _allExams.map((e) => e.title.trim()).where((t) => t.isNotEmpty).toSet().map((title) {
                                      return DropdownMenuItem(
                                        value: title,
                                        child: Text(title, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                                      );
                                    }).toList()
                                  : [
                                      DropdownMenuItem(
                                        value: _examTitle,
                                        child: Text(_examTitle, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                                      ),
                                    ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _examTitle = val;
                                    _selectedExam = _allExams.firstWhere((e) => e.title == val, orElse: () => _allExams.first);
                                    // When switching exam, restrict class dropdown strictly to this exam's classes!
                                    if (_selectedExam != null &&
                                        _selectedExam!.className.isNotEmpty &&
                                        _selectedExam!.className.trim().toLowerCase() != 'all classes') {
                                      final examClasses = _selectedExam!.className.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
                                      if (examClasses.length > 1) {
                                        _selectedClass = 'All Exam Classes';
                                      } else {
                                        _selectedClass = examClasses.first;
                                      }
                                    } else {
                                      _selectedClass = 'All Classes';
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Search Box & Status Pills
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search by student name or roll...',
                                hintStyle: const TextStyle(fontSize: 12),
                                prefixIcon: const Icon(Icons.search, size: 18),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (val) => setState(() => _searchQuery = val),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Status Quick Pills
                      Row(
                        children: [
                          _buildFilterChip('All', totalCount.toString(), Colors.blueGrey),
                          const SizedBox(width: 8),
                          _buildFilterChip('Completed', completedCount.toString(), Colors.green),
                          const SizedBox(width: 8),
                          _buildFilterChip('Pending', pendingCount.toString(), Colors.orange),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // ─── Student List ───
                Expanded(
                  child: students.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 10),
                              Text(
                                'No students found for $_selectedClass',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          itemCount: students.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final s = students[i];
                            final res = _getResultForStudent(s);
                            final isFilled = res != null;
                            final isPass = res?.isPass ?? false;

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isFilled
                                      ? (isPass ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3))
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Serial index
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1E3A8A)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Simple Student Details Header (NO bulky profile cards!)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${s.displayClass} • Roll: ${s.rollNumber ?? s.studentId}',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        ),
                                        if (isFilled) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            '${res.obtainedMarks.toInt()} / ${res.totalMarks.toInt()} (${res.overallPercentage.toStringAsFixed(1)}%) • Grade: ${res.overallGrade}',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1E3A8A),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // Status Chip with Division
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isFilled
                                          ? (isPass ? Colors.green.withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12))
                                          : Colors.grey.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isFilled ? (isPass ? '\ (\)' : res.finalResultStatus) : 'PENDING',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isFilled
                                            ? (isPass
                                                ? (res.finalResultStatus == 'PROMOTED' ? Colors.amber.shade800 : Colors.green)
                                                : Colors.red)
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Actions: Enter/Edit + 3-dots menu for filled records
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isFilled ? const Color(0xFF0D9488) : const Color(0xFF1E3A8A),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    onPressed: () => _openMarkEntry(s),
                                    child: Text(
                                      isFilled ? 'Edit' : 'Enter',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),

                                  if (isFilled)
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFF64748B)),
                                      padding: EdgeInsets.zero,
                                      tooltip: 'Actions',
                                      onSelected: (val) {
                                        if (val == 'view') {
                                          _openResultDetails(s, res);
                                        } else if (val == 'pdf') {
                                          _saveSingleStudentPdf(s, res);
                                        } else if (val == 'delete') {
                                          _deleteStudentResult(s, res);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(
                                          value: 'view',
                                          child: Row(
                                            children: [
                                              Icon(Icons.remove_red_eye_outlined, size: 18, color: Color(0xFF1E3A8A)),
                                              SizedBox(width: 8),
                                              Text('View Report Card', style: TextStyle(fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'pdf',
                                          child: Row(
                                            children: [
                                              Icon(Icons.download_rounded, size: 18, color: Color(0xFF0D9488)),
                                              SizedBox(width: 8),
                                              Text('Save PDF', style: TextStyle(fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Delete Result', style: TextStyle(fontSize: 13, color: Colors.red)),
                                            ],
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
              ],
            ),
    );
  }

  Widget _buildFilterChip(String label, String count, Color color) {
    final isSel = _statusFilter == label;
    return InkWell(
      onTap: () => setState(() => _statusFilter = label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSel ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSel ? Colors.white : color,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSel ? Colors.white.withValues(alpha: 0.25) : color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSel ? Colors.white : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
