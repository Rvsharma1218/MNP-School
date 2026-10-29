import 'package:flutter/material.dart';
import '../../../data/models/exam_model.dart';
import '../../../data/models/result_model.dart';
import '../../../data/models/student_model.dart';
import '../../../data/services/database_service.dart';

class StudentMarkEntryScreen extends StatefulWidget {
  final StudentModel student;
  final ResultModel? editResult;
  final ExamModel? exam;
  final List<Map<String, String>>? subjectTemplate;

  const StudentMarkEntryScreen({
    super.key,
    required this.student,
    this.editResult,
    this.exam,
    this.subjectTemplate,
  });

  @override
  State<StudentMarkEntryScreen> createState() => _StudentMarkEntryScreenState();
}

class _StudentMarkEntryScreenState extends State<StudentMarkEntryScreen> {
  late TextEditingController _examCtrl;
  late TextEditingController _passCriteriaCtrl;
  late TextEditingController _remarksCtrl;

  bool _isDetailedMode = false;
  String _selectedStatus = 'AUTO';

  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _subjectRows = [];

  final List<String> _standardSubjects = [
    'Mathematics',
    'Science',
    'Social Science',
    'English',
    'Hindi',
    'Sanskrit',
    'Urdu',
    'EVS',
    'Moral Science',
    'Computer',
    'General Knowledge',
    'Drawing / Art',
    'Physical Education',
    'Music',
    'Physics',
    'Chemistry',
    'Biology',
    'Economics',
    'Accountancy',
    'Business Studies',
    'History',
    'Geography',
    'Political Science',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final res = widget.editResult;
    final ex = widget.exam;

    _examCtrl = TextEditingController(text: res?.examName ?? ex?.title ?? 'Term Examination 2026');
    _passCriteriaCtrl = TextEditingController(text: '33');
    _remarksCtrl = TextEditingController(text: res?.remarks ?? '');
    _selectedStatus = res?.status ?? 'AUTO';

    // ─── CRITICAL: AUTO-OPEN IN THE EXACT SAVED MODE ───
    if (res != null) {
      _isDetailedMode = res.isDetailedMode ||
          res.subjects.any((s) => s.theoryMarks > 0 || s.practicalMarks > 0 || s.internalMarks > 0);
    } else if (ex != null) {
      _isDetailedMode = ex.isDetailedMode;
    }

    _initSubjectRows();
  }

  void _initSubjectRows() {
    final res = widget.editResult;
    final ex = widget.exam;

    if (res != null && res.subjects.isNotEmpty) {
      // Load existing result subjects (retaining saved mode and marks)
      _subjectRows = res.subjects.map((s) {
        final isStd = _standardSubjects.contains(s.subjectName) && s.subjectName != 'Other';
        return {
          'id': 'res_${s.subjectName}_${DateTime.now().microsecondsSinceEpoch}',
          'name': isStd ? s.subjectName : 'Other',
          'customCtrl': TextEditingController(text: s.subjectName),
          'marks': TextEditingController(text: s.marks > 0 ? s.marks.toInt().toString() : ''),
          'theory': TextEditingController(text: s.theoryMarks > 0 ? s.theoryMarks.toInt().toString() : (s.marks > 0 && _isDetailedMode && s.practicalMarks == 0 && s.internalMarks == 0 ? s.marks.toInt().toString() : '')),
          'practical': TextEditingController(text: s.practicalMarks > 0 ? s.practicalMarks.toInt().toString() : ''),
          'internal': TextEditingController(text: s.internalMarks > 0 ? s.internalMarks.toInt().toString() : ''),
          'totalMarks': TextEditingController(text: s.totalMarks > 0 ? s.totalMarks.toInt().toString() : '100'),
        };
      }).toList();
    } else if (ex != null && ex.subjects.isNotEmpty) {
      // Pre-fill from selected Exam's subjects (deduplicated)
      final seen = <String>{};
      final uniqueSubs = ex.subjects.where((s) => seen.add(s.subjectName.trim().toLowerCase())).toList();
      _subjectRows = uniqueSubs.map((s) {
        final isStd = _standardSubjects.contains(s.subjectName) && s.subjectName != 'Other';
        final maxM = _isDetailedMode ? (s.theoryMax + s.practicalMax + s.internalMax) : s.totalMarks;
        return {
          'id': 'ex_${s.subjectName}_${DateTime.now().microsecondsSinceEpoch}',
          'name': isStd ? s.subjectName : 'Other',
          'customCtrl': TextEditingController(text: s.subjectName),
          'marks': TextEditingController(text: ''),
          'theory': TextEditingController(text: ''),
          'practical': TextEditingController(text: ''),
          'internal': TextEditingController(text: ''),
          'totalMarks': TextEditingController(text: (maxM > 0 ? maxM : 100).toInt().toString()),
        };
      }).toList();
    } else if (widget.subjectTemplate != null && widget.subjectTemplate!.isNotEmpty) {
      // Pre-fill from class template
      _subjectRows = widget.subjectTemplate!.map((tmpl) {
        final name = tmpl['name'] ?? 'Subject';
        final maxM = tmpl['maxMarks'] ?? '100';
        final isStd = _standardSubjects.contains(name) && name != 'Other';
        return {
          'id': 'tmpl_${name}_${DateTime.now().microsecondsSinceEpoch}',
          'name': isStd ? name : 'Other',
          'customCtrl': TextEditingController(text: name),
          'marks': TextEditingController(text: ''),
          'theory': TextEditingController(text: ''),
          'practical': TextEditingController(text: ''),
          'internal': TextEditingController(text: ''),
          'totalMarks': TextEditingController(text: maxM),
        };
      }).toList();
    } else {
      // Clean 5 standard default subjects
      final defaults = ['Mathematics', 'Science', 'Social Science', 'English', 'Hindi'];
      _subjectRows = defaults.map((name) {
        return {
          'id': 'def_${name}_${DateTime.now().microsecondsSinceEpoch}',
          'name': name,
          'customCtrl': TextEditingController(text: name),
          'marks': TextEditingController(text: ''),
          'theory': TextEditingController(text: ''),
          'practical': TextEditingController(text: ''),
          'internal': TextEditingController(text: ''),
          'totalMarks': TextEditingController(text: '100'),
        };
      }).toList();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _examCtrl.dispose();
    _passCriteriaCtrl.dispose();
    _remarksCtrl.dispose();
    for (final r in _subjectRows) {
      (r['customCtrl'] as TextEditingController).dispose();
      (r['marks'] as TextEditingController).dispose();
      (r['theory'] as TextEditingController).dispose();
      (r['practical'] as TextEditingController).dispose();
      (r['internal'] as TextEditingController).dispose();
      (r['totalMarks'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  void _addSubjectRow({String name = '', String maxMarks = '100'}) {
    final effectiveName = name.trim().isNotEmpty ? name.trim() : 'Subject ${_subjectRows.length + 1}';
    setState(() {
      if (!_standardSubjects.contains(effectiveName)) {
        _standardSubjects.insert(_standardSubjects.length - 1, effectiveName);
      }
      _subjectRows = [
        ..._subjectRows,
        {
          'id': 'sub_${DateTime.now().microsecondsSinceEpoch}',
          'name': effectiveName,
          'customCtrl': TextEditingController(text: effectiveName),
          'marks': TextEditingController(text: ''),
          'theory': TextEditingController(text: ''),
          'practical': TextEditingController(text: ''),
          'internal': TextEditingController(text: ''),
          'totalMarks': TextEditingController(text: maxMarks),
        },
      ];
    });

    // Wait for layout then scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _promptAddSubject() async {
    final nameCtrl = TextEditingController();
    final maxCtrl = TextEditingController(text: '100');
    final popularElectives = [
      'Sanskrit',
      'Urdu',
      'EVS',
      'Moral Science',
      'Drawing / Art',
      'General Knowledge',
      'Physical Education',
      'Music',
      'Computer',
    ];

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.add_circle_outline, color: Color(0xFF1E3A8A)),
                SizedBox(width: 8),
                Text('Add Subject', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1-Tap Add Elective:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: popularElectives.map((e) {
                      return ActionChip(
                        avatar: const Icon(Icons.add_circle, size: 16, color: Color(0xFF1E3A8A)),
                        label: Text(e, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                        backgroundColor: const Color(0xFFEFF6FF),
                        onPressed: () {
                          final maxVal = maxCtrl.text.trim().isNotEmpty ? maxCtrl.text.trim() : '100';
                          Navigator.pop(ctx, {'name': e, 'max': maxVal});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text('Or Enter Custom Name:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    autofocus: false,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        final maxVal = maxCtrl.text.trim().isNotEmpty ? maxCtrl.text.trim() : '100';
                        Navigator.pop(ctx, {'name': val.trim(), 'max': maxVal});
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Subject Name',
                      hintText: 'e.g. Sanskrit, EVS, Drawing...',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: maxCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max Marks',
                      hintText: '100',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton.icon(
                onPressed: () {
                  final subName = nameCtrl.text.trim();
                  if (subName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a subject name or tap an elective chip')),
                    );
                    return;
                  }
                  final maxVal = maxCtrl.text.trim().isNotEmpty ? maxCtrl.text.trim() : '100';
                  Navigator.pop(ctx, {'name': subName, 'max': maxVal});
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Subject'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && result['name'] != null && result['name']!.trim().isNotEmpty) {
      final subName = result['name']!.trim();
      final maxVal = result['max'] ?? '100';
      _addSubjectRow(name: subName, maxMarks: maxVal);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Added subject: $subName (Max: $maxVal)', style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    }
  }

  Future<void> _saveResult() async {
    final passCriteria = double.tryParse(_passCriteriaCtrl.text) ?? 33.0;

    final subs = _subjectRows.map((r) {
      final customName = (r['customCtrl'] as TextEditingController).text.trim();
      final subName = (r['name'] == 'Other' || customName.isNotEmpty) ? customName : (r['name']?.toString() ?? 'Subject');
      final maxM = double.tryParse((r['totalMarks'] as TextEditingController).text) ?? 100.0;
      final th = double.tryParse((r['theory'] as TextEditingController).text) ?? 0.0;
      final pr = double.tryParse((r['practical'] as TextEditingController).text) ?? 0.0;
      final inM = double.tryParse((r['internal'] as TextEditingController).text) ?? 0.0;
      final obt = _isDetailedMode ? (th + pr + inM) : (double.tryParse((r['marks'] as TextEditingController).text) ?? 0.0);

      return SubjectResult(
        subjectName: subName.isNotEmpty ? subName : 'Subject',
        marks: obt,
        totalMarks: maxM,
        passingMarks: maxM * (passCriteria / 100.0),
        theoryMarks: _isDetailedMode ? th : 0.0,
        practicalMarks: _isDetailedMode ? pr : 0.0,
        internalMarks: _isDetailedMode ? inM : 0.0,
      );
    }).toList();

    double totalObt = 0;
    double totalMax = 0;
    int failCount = 0;
    for (final s in subs) {
      totalObt += s.marks;
      totalMax += s.totalMarks;
      if (!s.isPass) failCount++;
    }
    final pct = totalMax > 0 ? (totalObt / totalMax) * 100 : 0.0;
    if (totalObt == 0 && subs.every((s) => s.marks == 0 && s.theoryMarks == 0)) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Marks Not Entered'),
          content: Text('No marks entered for ${widget.student.name} (Obtained: 0). Do you still want to save this with 0 marks?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              child: const Text('Yes, Save 0 Marks'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }
    String autoStatus = (failCount > 0 || pct < passCriteria || totalObt == 0) ? 'FAIL' : 'PASS';
    String finalStatus = _selectedStatus == 'AUTO' ? autoStatus : _selectedStatus;

    final resId = widget.editResult?.id ?? 'res_${widget.student.id}_${DateTime.now().millisecondsSinceEpoch}';
    final resultModel = ResultModel(
      id: resId,
      studentId: widget.student.studentId.isNotEmpty ? widget.student.studentId : widget.student.id,
      studentName: widget.student.name,
      className: widget.student.displayClass,
      rollNumber: widget.student.rollNumber,
      examName: _examCtrl.text.trim().isNotEmpty ? _examCtrl.text.trim() : 'Term Examination 2026',
      subjects: subs,
      status: finalStatus,
      createdAt: widget.editResult?.createdAt ?? DateTime.now(),
      isDetailedMode: _isDetailedMode,
      remarks: _remarksCtrl.text.trim().isNotEmpty ? _remarksCtrl.text.trim() : null,
    );

    await DatabaseService.instance.saveResult(resultModel);
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      Navigator.pop(context, resultModel);
    }
  }

  Future<void> _deleteResult() async {
    if (widget.editResult == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Result?'),
        content: Text('Are you sure you want to delete the result of ${widget.student.name} for "${widget.editResult!.examName}"?'),
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
      await DatabaseService.instance.deleteResult(widget.editResult!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Result deleted successfully.'), backgroundColor: Colors.red),
        );
        Navigator.pop(context, 'deleted');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final passCriteria = double.tryParse(_passCriteriaCtrl.text) ?? 33.0;

    // Live calculation
    double totalObt = 0;
    double totalMax = 0;
    for (final r in _subjectRows) {
      final maxM = double.tryParse((r['totalMarks'] as TextEditingController).text) ?? 100.0;
      final th = double.tryParse((r['theory'] as TextEditingController).text) ?? 0.0;
      final pr = double.tryParse((r['practical'] as TextEditingController).text) ?? 0.0;
      final inM = double.tryParse((r['internal'] as TextEditingController).text) ?? 0.0;
      final obt = _isDetailedMode ? (th + pr + inM) : (double.tryParse((r['marks'] as TextEditingController).text) ?? 0.0);
      totalObt += obt;
      totalMax += maxM;
    }

    final pct = totalMax > 0 ? (totalObt / totalMax) * 100 : 0.0;
    final grade = pct >= 90 ? 'A+' : pct >= 80 ? 'A' : pct >= 70 ? 'B+' : pct >= 60 ? 'B' : pct >= 50 ? 'C' : pct >= 40 ? 'D' : 'F';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Enter Marks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (widget.editResult != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              tooltip: 'Delete Result',
              onPressed: _deleteResult,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: ElevatedButton(
              onPressed: _saveResult,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1E3A8A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── SCROLLABLE CONTENT ───
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Student Info Header (Clean, as in original app) ───
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                          child: Text(
                            widget.student.name.isNotEmpty ? widget.student.name[0] : 'S',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A), fontSize: 16),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.student.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.student.displayClass} • Roll: ${widget.student.rollNumber ?? widget.student.studentId} • ID: ${widget.student.studentId}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Exam Name & Pass Criteria Row
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Exam Title:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _examCtrl,
                              decoration: InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Pass Criteria:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _passCriteriaCtrl,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                suffixText: '%',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ─── Mode Pill Toggle ───
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _isDetailedMode = false),
                            borderRadius: BorderRadius.circular(9),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: !_isDetailedMode ? (isDark ? const Color(0xFF1E293B) : Colors.white) : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: !_isDetailedMode ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))] : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Direct Marks Mode',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: !_isDetailedMode ? const Color(0xFF1E3A8A) : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _isDetailedMode = true),
                            borderRadius: BorderRadius.circular(9),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _isDetailedMode ? const Color(0xFF1E3A8A) : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: _isDetailedMode ? [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4, offset: const Offset(0, 2))] : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Detailed (Theory/Practical)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _isDetailedMode ? Colors.white : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Subjects Header & Quick Add Chips
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Subjects (${_subjectRows.length}):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ElevatedButton.icon(
                        onPressed: _promptAddSubject,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add Subject', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Quick Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text('Quick Add: ', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                        for (final qSub in ['Sanskrit', 'Urdu', 'EVS', 'Moral Science', 'Drawing', 'GK', 'P.E.', 'Computer']) ...[
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              label: Text('+ $qSub', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                              backgroundColor: const Color(0xFFEFF6FF),
                              onPressed: () => _addSubjectRow(name: qSub),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ─── Subject Entry Cards ───
                  ..._subjectRows.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final row = entry.value;

                    final maxM = double.tryParse((row['totalMarks'] as TextEditingController).text) ?? 100.0;
                    final th = double.tryParse((row['theory'] as TextEditingController).text) ?? 0.0;
                    final pr = double.tryParse((row['practical'] as TextEditingController).text) ?? 0.0;
                    final inM = double.tryParse((row['internal'] as TextEditingController).text) ?? 0.0;
                    final obt = _isDetailedMode ? (th + pr + inM) : (double.tryParse((row['marks'] as TextEditingController).text) ?? 0.0);
                    final isPassed = obt >= (maxM * (passCriteria / 100.0));

                    return Container(
                      key: ValueKey(row['id']),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Subject Dropdown (NO Subject Code)
                              Expanded(
                                flex: 5,
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey('dd_${row['id']}'),
                                  initialValue: _standardSubjects.contains(row['name']) ? row['name'] : 'Other',
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: 'Subject #${idx + 1}',
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  ),
                                  items: _standardSubjects.toSet().map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        row['name'] = val;
                                        if (val != 'Other') {
                                          (row['customCtrl'] as TextEditingController).text = val;
                                        }
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Max Marks
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: row['totalMarks'] as TextEditingController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  decoration: const InputDecoration(
                                    labelText: 'Max',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // Pass/Fail badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isPassed ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isPassed ? 'PASS' : 'FAIL',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isPassed ? Colors.green : Colors.red),
                                ),
                              ),

                              if (_subjectRows.length > 1) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _subjectRows = List.from(_subjectRows)..removeAt(idx);
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),

                          // Custom subject name if 'Other'
                          if (row['name'] == 'Other') ...[
                            const SizedBox(height: 8),
                            TextField(
                              controller: row['customCtrl'] as TextEditingController,
                              decoration: const InputDecoration(
                                labelText: 'Type Custom Subject Name',
                                isDense: true,
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                          const SizedBox(height: 8),

                          // Direct vs Detailed Inputs
                          if (!_isDetailedMode) ...[
                            Row(
                              children: [
                                const Text('Obtained Marks: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: row['marks'] as TextEditingController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                                    decoration: InputDecoration(
                                      hintText: 'e.g. 78',
                                      suffixText: '/ ${maxM.toInt()}',
                                      isDense: true,
                                      border: const OutlineInputBorder(),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: row['theory'] as TextEditingController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(labelText: 'Theory', isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.all(6)),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: TextField(
                                    controller: row['practical'] as TextEditingController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(labelText: 'Practical', isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.all(6)),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: TextField(
                                    controller: row['internal'] as TextEditingController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(labelText: 'Internal', isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.all(6)),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: Text('Total: ${obt.toInt()} / ${maxM.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1E3A8A))),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  }),

                  // Add Another Subject Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _promptAddSubject,
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                      label: const Text('+ Add Another Subject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
                        foregroundColor: const Color(0xFF1E3A8A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Result Status Override
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Result Status Override:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedStatus,
                        decoration: InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'AUTO', child: Text('Auto-Calculate (Standard)', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'PROMOTED', child: Text('PROMOTED (Next Class with Grace)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber))),
                          DropdownMenuItem(value: 'PASS', child: Text('PASS (Manual Override)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green))),
                          DropdownMenuItem(value: 'FAIL', child: Text('FAIL (Manual Override)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red))),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedStatus = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Remarks (Optional)
                  TextField(
                    controller: _remarksCtrl,
                    decoration: InputDecoration(
                      labelText: 'Remarks (Optional)',
                      hintText: 'e.g. Promoted to next class with grace in Mathematics',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // ─── STICKY BOTTOM SUMMARY BAR ───
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -3)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Total Marks', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    Text('${totalObt.toInt()} / ${totalMax.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Percentage', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    Text('${pct.toStringAsFixed(1)}% ($grade)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A8A))),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _saveResult,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Save Result', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
