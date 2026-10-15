import 'package:flutter/material.dart';
import '../../../data/models/exam_model.dart';
import '../../../data/services/database_service.dart';

class CreateExamScreen extends StatefulWidget {
  final ExamModel? editExam;
  final String? initialClass;

  const CreateExamScreen({super.key, this.editExam, this.initialClass});

  @override
  State<CreateExamScreen> createState() => _CreateExamScreenState();
}

class _CreateExamScreenState extends State<CreateExamScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _titleCtrl;
  String _selectedTerm = 'Annual';
  String _selectedClass = '';
  String _academicYear = '2026 - 2027';
  DateTime _examDate = DateTime.now();
  String _status = 'In Progress';
  bool _isDetailedMode = false;

  List<String> _availableClasses = [];
  List<Map<String, dynamic>> _subjectRows = [];
  final ScrollController _subjectsScrollCtrl = ScrollController();

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
    _tabController = TabController(length: 2, vsync: this);
    final ex = widget.editExam;
    _titleCtrl = TextEditingController(text: ex?.title ?? 'Annual Examination 2026');
    _selectedTerm = ex?.term ?? 'Annual';
    _selectedClass = ex?.className ?? widget.initialClass ?? '';
    _academicYear = ex?.academicYear ?? '2026 - 2027';
    _examDate = ex?.examDate ?? DateTime.now();
    _status = ex?.status ?? 'In Progress';
    _isDetailedMode = ex?.isDetailedMode ?? false;

    if (ex != null && ex.subjects.isNotEmpty) {
      _subjectRows = ex.subjects.map((s) {
        final isStd = _standardSubjects.contains(s.subjectName) && s.subjectName != 'Other';
        return {
          'id': 'sub_${DateTime.now().microsecondsSinceEpoch}_${s.subjectName}',
          'name': isStd ? s.subjectName : 'Other',
          'customCtrl': TextEditingController(text: s.subjectName),
          'isCompulsory': s.isCompulsory,
          'theoryPass': TextEditingController(text: s.theoryPassing.toInt().toString()),
          'theoryMax': TextEditingController(text: s.theoryMax.toInt().toString()),
          'practicalPass': TextEditingController(text: s.practicalPassing.toInt().toString()),
          'practicalMax': TextEditingController(text: s.practicalMax.toInt().toString()),
          'internalPass': TextEditingController(text: s.internalPassing.toInt().toString()),
          'internalMax': TextEditingController(text: s.internalMax.toInt().toString()),
          'passingMarks': TextEditingController(text: s.passingMarks.toInt().toString()),
          'totalMarks': TextEditingController(text: s.totalMarks.toInt().toString()),
        };
      }).toList();
    } else {
      final defaults = ['Mathematics', 'Science', 'Social Science', 'English', 'Hindi'];
      int i = 0;
      _subjectRows = defaults.map((sub) {
        i++;
        return {
          'id': 'sub_def_$i',
          'name': sub,
          'customCtrl': TextEditingController(text: sub),
          'isCompulsory': true,
          'theoryPass': TextEditingController(text: '33'),
          'theoryMax': TextEditingController(text: '100'),
          'practicalPass': TextEditingController(text: '15'),
          'practicalMax': TextEditingController(text: '50'),
          'internalPass': TextEditingController(text: '10'),
          'internalMax': TextEditingController(text: '50'),
          'passingMarks': TextEditingController(text: '33'),
          'totalMarks': TextEditingController(text: '100'),
        };
      }).toList();
    }

    _loadClasses();
  }

  @override
  void dispose() {
    _subjectsScrollCtrl.dispose();
    _tabController.dispose();
    _titleCtrl.dispose();
    for (final r in _subjectRows) {
      (r['customCtrl'] as TextEditingController).dispose();
      (r['theoryPass'] as TextEditingController).dispose();
      (r['theoryMax'] as TextEditingController).dispose();
      (r['practicalPass'] as TextEditingController).dispose();
      (r['practicalMax'] as TextEditingController).dispose();
      (r['internalPass'] as TextEditingController).dispose();
      (r['internalMax'] as TextEditingController).dispose();
      (r['passingMarks'] as TextEditingController).dispose();
      (r['totalMarks'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  Future<void> _loadClasses() async {
    final students = await DatabaseService.instance.getAllStudents();
    final settings = await DatabaseService.instance.getSettings();
    final Set<String> set = {'All Classes'};
    for (final s in students) {
      final c = s.studentType == 'school' ? s.className : s.course;
      if (c != null && c.trim().isNotEmpty) set.add(c.trim());
    }
    for (final c in settings.schoolClasses) {
      if (c.trim().isNotEmpty) set.add(c.trim());
    }
    final sorted = set.where((c) => c != 'All Classes').toList()..sort();
    setState(() {
      _availableClasses = ['All Classes', ...sorted];
      if (_selectedClass.isEmpty && _availableClasses.isNotEmpty) {
        _selectedClass = 'All Classes';
      }
    });
  }

  void _addSubject({String name = ''}) {
    final effectiveName = name.trim().isNotEmpty ? name.trim() : 'Subject ${_subjectRows.length + 1}';
    final newId = 'sub_${DateTime.now().microsecondsSinceEpoch}';
    final newRow = {
      'id': newId,
      'name': effectiveName,
      'customCtrl': TextEditingController(text: effectiveName),
      'isCompulsory': true,
      'theoryPass': TextEditingController(text: '33'),
      'theoryMax': TextEditingController(text: '100'),
      'practicalPass': TextEditingController(text: '15'),
      'practicalMax': TextEditingController(text: '50'),
      'internalPass': TextEditingController(text: '10'),
      'internalMax': TextEditingController(text: '50'),
      'passingMarks': TextEditingController(text: '33'),
      'totalMarks': TextEditingController(text: '100'),
    };

    setState(() {
      if (!_standardSubjects.contains(effectiveName)) {
        _standardSubjects.insert(_standardSubjects.length - 1, effectiveName);
      }
      _subjectRows = [..._subjectRows, newRow];
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_subjectsScrollCtrl.hasClients) {
        _subjectsScrollCtrl.animateTo(
          _subjectsScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _promptAddSubject() async {
    final nameCtrl = TextEditingController();
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

    final addedSubject = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.add_circle_outline, color: Color(0xFF1E3A8A)),
                SizedBox(width: 8),
                Text('Add Subject to Exam', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
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
                          Navigator.pop(ctx, e);
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
                        Navigator.pop(ctx, val.trim());
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Subject Name',
                      hintText: 'e.g. Sanskrit, EVS, Drawing...',
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
                  Navigator.pop(ctx, subName);
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

    if (addedSubject != null && addedSubject.trim().isNotEmpty) {
      final subName = addedSubject.trim();
      _addSubject(name: subName);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Added "$subName" to exam!', style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    }
  }

  Future<void> _saveExam() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter exam title')));
      return;
    }
    if (_subjectRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least 1 subject')));
      return;
    }

    final configs = _subjectRows.map((r) {
      final customName = (r['customCtrl'] as TextEditingController).text.trim();
      final subName = (r['name'] == 'Other')
          ? (customName.isNotEmpty ? customName : 'Subject')
          : (r['name']?.toString() ?? 'Subject');

      return ExamSubjectConfig(
        subjectName: subName.isNotEmpty ? subName : 'Subject',
        isCompulsory: r['isCompulsory'] == true,
        theoryPassing: double.tryParse((r['theoryPass'] as TextEditingController).text) ?? 33.0,
        theoryMax: double.tryParse((r['theoryMax'] as TextEditingController).text) ?? 100.0,
        practicalPassing: double.tryParse((r['practicalPass'] as TextEditingController).text) ?? 0.0,
        practicalMax: double.tryParse((r['practicalMax'] as TextEditingController).text) ?? 0.0,
        internalPassing: double.tryParse((r['internalPass'] as TextEditingController).text) ?? 0.0,
        internalMax: double.tryParse((r['internalMax'] as TextEditingController).text) ?? 0.0,
        passingMarks: double.tryParse((r['passingMarks'] as TextEditingController).text) ?? 33.0,
        totalMarks: double.tryParse((r['totalMarks'] as TextEditingController).text) ?? 100.0,
      );
    }).toList();

    final exam = ExamModel(
      id: widget.editExam?.id ?? 'exam_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleCtrl.text.trim(),
      term: _selectedTerm,
      className: _selectedClass,
      academicYear: _academicYear,
      examDate: _examDate,
      status: _status,
      isDetailedMode: _isDetailedMode,
      subjects: configs,
      createdAt: widget.editExam?.createdAt ?? DateTime.now(),
    );

    await DatabaseService.instance.saveExam(exam);
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(duration: const Duration(seconds: 3), content: Text('✓ Exam "${exam.title}" saved successfully!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, exam);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.editExam != null ? 'Edit Exam' : 'Create Exam', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: ElevatedButton(
              onPressed: _saveExam,
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amber,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Exam Details'),
            Tab(text: 'Subjects'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ─── TAB 1: EXAM DETAILS ───
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Exam Title
                const Text('Exam Title:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. Annual Examination 2026',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 8),

                // Fast Presets
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final tag in [
                        'Annual Exam',
                        'Half Yearly Exam',
                        'Unit Test 1',
                        'Pre Board',
                        'Term Examination'
                      ]) ...[
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(tag, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            onPressed: () => setState(() => _titleCtrl.text = tag),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Class & Term Selector
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Class / Course:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            key: ValueKey('exam_class_$_selectedClass'),
                            initialValue: _selectedClass.isNotEmpty ? _selectedClass : null,
                            isExpanded: true,
                            decoration: InputDecoration(
                              hintText: 'Select Class',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                            items: _availableClasses.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedClass = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Term:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            key: ValueKey('exam_term_$_selectedTerm'),
                            initialValue: _selectedTerm,
                            isExpanded: true,
                            decoration: InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Annual', child: Text('Annual Term', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'Half Yearly', child: Text('Half Yearly', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'Unit Test', child: Text('Unit Test', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'Pre Board', child: Text('Pre Board', style: TextStyle(fontSize: 12))),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedTerm = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Academic Session & Exam Status (Exam Date Removed)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Academic Year:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            key: ValueKey('exam_year_$_academicYear'),
                            initialValue: _academicYear,
                            decoration: InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                            items: const [
                              DropdownMenuItem(value: '2026 - 2027', child: Text('2026 - 2027', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: '2025 - 2026', child: Text('2025 - 2026', style: TextStyle(fontSize: 12))),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _academicYear = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Exam Status:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            key: ValueKey('exam_status_$_status'),
                            initialValue: _status,
                            decoration: InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'In Progress', child: Text('In Progress', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'Published', child: Text('Published', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'Draft', child: Text('Draft', style: TextStyle(fontSize: 12))),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _status = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ─── Evaluation Mode Selector ───
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.tune_rounded, color: Color(0xFF1E3A8A), size: 18),
                          SizedBox(width: 8),
                          Text('Mark Evaluation Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E3A8A))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text('Choose how teachers will enter marks and how report cards will be structured.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      const SizedBox(height: 10),

                      RadioListTile<bool>(
                        value: false,
                        groupValue: _isDetailedMode,
                        title: const Text('Direct / Single Obtained Marks Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: const Text('Enter single total marks per subject (e.g. 78/100). No Theory/Practical breakdown.', style: TextStyle(fontSize: 11)),
                        activeColor: const Color(0xFF1E3A8A),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setState(() => _isDetailedMode = val!),
                      ),
                      RadioListTile<bool>(
                        value: true,
                        groupValue: _isDetailedMode,
                        title: const Text('Detailed Component Mode (Theory + Practical + Internal)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: const Text('Enter marks for Theory, Practical and Internal components with separate pass criteria.', style: TextStyle(fontSize: 11)),
                        activeColor: const Color(0xFF1E3A8A),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setState(() => _isDetailedMode = val!),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Publish Status
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: InputDecoration(
                    labelText: 'Exam Status',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'In Progress', child: Text('In Progress (Marks being entered)', style: TextStyle(fontSize: 12, color: Colors.purple, fontWeight: FontWeight.bold))),
                    DropdownMenuItem(value: 'Published', child: Text('Published (Official & visible)', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold))),
                    DropdownMenuItem(value: 'Draft', child: Text('Draft', style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold))),
                    DropdownMenuItem(value: 'Not Published', child: Text('Not Published', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold))),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _status = val);
                  },
                ),
              ],
            ),
          ),

          // ─── TAB 2: SUBJECTS SETUP ───
          SingleChildScrollView(
            controller: _subjectsScrollCtrl,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info callout
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFF1E3A8A), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isDetailedMode
                              ? 'Add subjects and set passing & maximum marks for Theory, Practical and Internal components.'
                              : 'Add subjects and set passing marks (e.g. 33) and total marks (e.g. 100) for each subject.',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF1E3A8A)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Quick Add chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text('Quick Add: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      for (final qSub in ['Sanskrit', 'Urdu', 'EVS', 'Moral Science', 'Drawing', 'GK', 'P.E.', 'Computer']) ...[
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text('+ $qSub', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                            backgroundColor: const Color(0xFFEFF6FF),
                            onPressed: () => _addSubject(name: qSub),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Subject Cards List
                ..._subjectRows.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final row = entry.value;

                  return Container(
                    key: ValueKey('exam_card_${row['id']}'),
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
                        // Row: Subject Dropdown + Compulsory + Delete
                        Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: DropdownButtonFormField<String>(
                                key: ValueKey('exam_dd_${row['id']}'),
                                initialValue: _standardSubjects.contains(row['name']) ? row['name'] : 'Other',
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Subject #${idx + 1}',
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                            // Compulsory switch
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Compulsory', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                                Switch(
                                  value: row['isCompulsory'] == true,
                                  activeColor: const Color(0xFF1E3A8A),
                                  onChanged: (val) => setState(() => row['isCompulsory'] = val),
                                ),
                              ],
                            ),
                            if (_subjectRows.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _subjectRows = List.from(_subjectRows)..removeAt(idx);
                                  });
                                },
                              ),
                          ],
                        ),

                        // If 'Other', show custom name textfield
                        if (row['name'] == 'Other') ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: row['customCtrl'] as TextEditingController,
                            decoration: InputDecoration(
                              labelText: 'Type Subject Name',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),

                        // Passing vs Max Marks Breakdown
                        if (!_isDetailedMode) ...[
                          // Direct Mode: Pass / Max
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: row['passingMarks'] as TextEditingController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    labelText: 'Pass Marks',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('/', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: row['totalMarks'] as TextEditingController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    labelText: 'Total Max',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          // Detailed Component Mode: Theory, Practical, Internal
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Theory (Pass / Max)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: row['theoryPass'] as TextEditingController,
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.all(6)),
                                          ),
                                        ),
                                        const Text(' / ', style: TextStyle(fontSize: 10)),
                                        Expanded(
                                          child: TextField(
                                            controller: row['theoryMax'] as TextEditingController,
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.all(6)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Practical (Pass / Max)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: row['practicalPass'] as TextEditingController,
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.all(6)),
                                          ),
                                        ),
                                        const Text(' / ', style: TextStyle(fontSize: 10)),
                                        Expanded(
                                          child: TextField(
                                            controller: row['practicalMax'] as TextEditingController,
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.all(6)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Internal (Pass / Max)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: row['internalPass'] as TextEditingController,
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.all(6)),
                                          ),
                                        ),
                                        const Text(' / ', style: TextStyle(fontSize: 10)),
                                        Expanded(
                                          child: TextField(
                                            controller: row['internalMax'] as TextEditingController,
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.all(6)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                }),

                // Add Subject Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _promptAddSubject,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('+ Add Subject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
                      foregroundColor: const Color(0xFF1E3A8A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
