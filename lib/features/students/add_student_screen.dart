import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/student_model.dart';
import '../../data/models/settings_model.dart';
import '../../data/services/database_service.dart';
import '../../data/services/providers.dart';
import '../../data/services/session_service.dart';
import '../../widgets/student_photo_picker.dart';

class AddStudentScreen extends ConsumerStatefulWidget {
  const AddStudentScreen({super.key});

  @override
  ConsumerState<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends ConsumerState<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _fatherCtrl = TextEditingController();
  final _motherCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _altMobileCtrl = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _addressCtrl  = TextEditingController();
  final _admissionNoCtrl = TextEditingController();
  final _aadhaarCtrl = TextEditingController();
  final _rollCtrl = TextEditingController();
  final _batchCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _admissionDateCtrl = TextEditingController();

  String _gender = 'Male';
  String _studentType = 'school';
  String _course = SettingsModel.defaultCourses.first;
  String _selectedClass = SettingsModel.defaultClasses.first;
  String _selectedSection = 'A';
  String _status = 'active';
  String _session = '2026-27';
  int _courseDurationMonths = 6;
  DateTime _dob = DateTime(2010, 1, 1);
  DateTime _admissionDate = DateTime.now();
  String? _photoPath;
  String? _aadhaarDocPath;
  bool _saving = false;
  bool _checkingAdmNo = false;
  bool _admNoExists = false;

  final _courses = SettingsModel.defaultCourses;
  final _classes = SettingsModel.defaultClasses;
  final _sections = ['A', 'B', 'C', 'D', 'E'];
  final _durations = [3, 6, 9, 12, 18, 24];
  final _statuses = ['active', 'completed', 'left', 'suspended'];

  @override
  void initState() {
    super.initState();
    _dobCtrl.text = _formatDate(_dob);
    _admissionDateCtrl.text = _formatDate(_admissionDate);

    // Load current session from settings and auto-generate next admission number
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final students = ref.read(studentsProvider).valueOrNull ?? [];
      ref.read(settingsProvider).whenData((s) {
        if (mounted) {
          setState(() {
            _session = s.currentSession;
            if (_admissionNoCtrl.text.isEmpty) {
              _admissionNoCtrl.text = _generateNextAdmissionNumber(students, s.currentSession);
            }
          });
        }
      });

      // Pre-fill class/section from teacher's assigned context.
      // Use SessionService (set at login) first, fallback to provider.
      if (SessionService.instance.isTeacher) {
        final sessionClass = SessionService.instance.assignedClass ?? '';
        final sessionSection = SessionService.instance.assignedSection ?? '';
        final tc = sessionClass.isNotEmpty
            ? sessionClass
            : ref.read(teacherSelectedClassProvider);
        final ts = sessionSection.isNotEmpty
            ? sessionSection
            : ref.read(teacherSelectedSectionProvider);
        if (mounted) {
          setState(() {
            if (tc.isNotEmpty && _classes.contains(tc)) _selectedClass = tc;
            if (ts.isNotEmpty && _sections.contains(ts)) _selectedSection = ts;
          });
        }
      }
    });
  }

  String _generateNextAdmissionNumber(List<StudentModel> students, String session) {
    final yearMatch = RegExp(r'\d{4}').firstMatch(session);
    final year = yearMatch != null ? yearMatch.group(0)! : DateTime.now().year.toString();
    final regex = RegExp('ADM-$year-(\\d+)', caseSensitive: false);
    int maxSeq = 0;

    for (final s in students) {
      final adm = s.admissionNumber;
      final match = regex.firstMatch(adm);
      if (match != null && match.group(1) != null) {
        final seq = int.tryParse(match.group(1)!);
        if (seq != null && seq > maxSeq) {
          maxSeq = seq;
        }
      }
    }

    final nextSeq = maxSeq + 1;
    return 'ADM-$year-${nextSeq.toString().padLeft(3, '0')}';
  }

  String _generateNextStudentId(List<StudentModel> students, String session) {
    final yearMatch = RegExp(r'\d{4}').firstMatch(session);
    final year = yearMatch != null ? yearMatch.group(0)! : DateTime.now().year.toString();
    final regex = RegExp('STU$year(\\d+)', caseSensitive: false);
    int maxSeq = 0;

    for (final s in students) {
      final id = s.studentId;
      final match = regex.firstMatch(id);
      if (match != null && match.group(1) != null) {
        final seq = int.tryParse(match.group(1)!);
        if (seq != null && seq > maxSeq) {
          maxSeq = seq;
        }
      }
    }

    final nextSeq = maxSeq + 1;
    return 'STU$year${nextSeq.toString().padLeft(3, '0')}';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _fatherCtrl.dispose();
    _motherCtrl.dispose();
    _mobileCtrl.dispose();
    _altMobileCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _admissionNoCtrl.dispose();
    _aadhaarCtrl.dispose();
    _rollCtrl.dispose();
    _batchCtrl.dispose();
    _dobCtrl.dispose();
    _admissionDateCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  Future<void> _checkAdmissionNumber(String value) async {
    if (value.trim().isEmpty) return;
    setState(() => _checkingAdmNo = true);
    final exists = await DatabaseService.instance.isAdmissionNumberExists(value.trim());
    if (mounted) setState(() { _checkingAdmNo = false; _admNoExists = exists; });
  }

  Future<void> _pickDate(bool isDob) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isDob ? _dob : _admissionDate,
      firstDate: isDob ? DateTime(1990) : DateTime(2000),
      lastDate: isDob ? DateTime.now() : DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isDob) { _dob = picked; _dobCtrl.text = _formatDate(picked); }
        else { _admissionDate = picked; _admissionDateCtrl.text = _formatDate(picked); }
      });
    }
  }

  DateTime? _calcExpectedCompletion() {
    if (_studentType != 'computer') return null;
    return DateTime(_admissionDate.year, _admissionDate.month + _courseDurationMonths, _admissionDate.day);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_admNoExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admission Number already exists!'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final students = ref.read(studentsProvider).valueOrNull ?? [];
      final studentId = _generateNextStudentId(students, _session);
      final admissionNo = _admissionNoCtrl.text.trim().isNotEmpty
          ? _admissionNoCtrl.text.trim()
          : _generateNextAdmissionNumber(students, _session);
      final id = studentId;

      final student = StudentModel(
        id: id,
        admissionNumber: admissionNo,
        studentId: studentId,
        name: _nameCtrl.text.trim(),
        fatherName: _fatherCtrl.text.trim(),
        motherName: _motherCtrl.text.trim().isEmpty ? null : _motherCtrl.text.trim(),
        mobile: _mobileCtrl.text.trim(),
        alternateMobile: _altMobileCtrl.text.trim().isEmpty ? null : _altMobileCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        dob: _dob,
        gender: _gender,
        address: _addressCtrl.text.trim(),
        photoPath: _photoPath,
        aadhaarNumber: _aadhaarCtrl.text.trim().isEmpty ? null : _aadhaarCtrl.text.trim(),
        aadhaarDocPath: _aadhaarDocPath,
        studentType: _studentType,
        className: _studentType == 'school' ? _selectedClass : null,
        section: _studentType == 'school' ? _selectedSection : null,
        rollNumber: _studentType == 'school' && _rollCtrl.text.trim().isNotEmpty
            ? _rollCtrl.text.trim() : null,
        course: _studentType == 'computer' ? _course : null,
        batch: _studentType == 'computer' && _batchCtrl.text.trim().isNotEmpty
            ? _batchCtrl.text.trim() : null,
        courseDurationMonths: _studentType == 'computer' ? _courseDurationMonths : null,
        expectedCompletionDate: _calcExpectedCompletion(),
        status: _status,
        session: _session,
        admissionDate: _admissionDate,
        createdAt: DateTime.now(),
      );

      await ref.read(studentsProvider.notifier).addStudent(student);
      ref.invalidate(dashboardStatsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${student.name} added successfully!'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        title: const Text('Add Student'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Photo
            _buildPhotoSection(),
            const SizedBox(height: 20),

            // Student Type Toggle
            _buildStudentTypeToggle(),
            const SizedBox(height: 16),

            // Basic Info
            _buildCard('Basic Information', Icons.person_outline, [
              _buildTextField(_admissionNoCtrl, 'Admission Number *',
                  icon: Icons.numbers,
                  onChanged: _checkAdmissionNumber,
                  suffix: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_checkingAdmNo)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      else if (_admNoExists)
                        const Icon(Icons.error, color: AppColors.error)
                      else if (_admissionNoCtrl.text.isNotEmpty)
                        const Icon(Icons.check_circle, color: AppColors.success),
                      IconButton(
                        tooltip: 'Auto-generate',
                        icon: const Icon(Icons.refresh, size: 20, color: AppColors.primary),
                        onPressed: () {
                          final students = ref.read(studentsProvider).valueOrNull ?? [];
                          setState(() {
                            _admissionNoCtrl.text = _generateNextAdmissionNumber(students, _session);
                            _admNoExists = false;
                          });
                        },
                      ),
                    ],
                  ),
                  errorText: _admNoExists ? 'Admission Number already exists' : null,
                  validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
              const SizedBox(height: 14),
              _buildTextField(_nameCtrl, 'Student Name *', icon: Icons.person,
                  validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
              const SizedBox(height: 14),
              _buildTextField(_fatherCtrl, "Father's Name *", icon: Icons.person_2,
                  validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
              const SizedBox(height: 14),
              _buildTextField(_motherCtrl, "Mother's Name", icon: Icons.person_2_outlined),
              const SizedBox(height: 14),
              _buildTextField(_mobileCtrl, 'Mobile *', icon: Icons.phone,
                  inputType: TextInputType.phone,
                  validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
              const SizedBox(height: 14),
              _buildTextField(_altMobileCtrl, 'Alternate Mobile', icon: Icons.phone_android,
                  inputType: TextInputType.phone),
              const SizedBox(height: 14),
              _buildTextField(_emailCtrl, 'Email (Optional)', icon: Icons.email_outlined,
                  inputType: TextInputType.emailAddress),
              const SizedBox(height: 14),
              _buildGenderRow(),
              const SizedBox(height: 14),
              _buildTextField(_aadhaarCtrl, 'Aadhaar / Document ID', icon: Icons.badge_outlined,
                  inputType: TextInputType.number),
              const SizedBox(height: 14),
              _buildAadhaarDocPicker(),
              const SizedBox(height: 14),
              _buildTextField(_dobCtrl, 'Date of Birth', icon: Icons.cake,
                  readOnly: true,
                  suffix: const Icon(Icons.calendar_today),
                  onTap: () => _pickDate(true)),
              const SizedBox(height: 14),
              _buildTextField(_addressCtrl, 'Address *', icon: Icons.location_on,
                  maxLines: 3,
                  validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
            ]),
            const SizedBox(height: 16),

            // Admission & Session
            _buildCard('Admission Details', Icons.calendar_month_outlined, [
              _buildTextField(_admissionDateCtrl, 'Admission Date', icon: Icons.event,
                  readOnly: true,
                  suffix: const Icon(Icons.calendar_today),
                  onTap: () => _pickDate(false)),
              const SizedBox(height: 14),
              _buildDropdown('Academic Session', SettingsModel.getSessions(), _session,
                      (v) => setState(() => _session = v!)),
              const SizedBox(height: 14),
              _buildStatusDropdown(),
            ]),
            const SizedBox(height: 16),

            // School / Computer specific
            if (_studentType == 'school') _buildSchoolDetails(),
            if (_studentType == 'computer') _buildComputerDetails(),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.person_add_rounded),
                label: Text(_saving ? 'Saving...' : 'Add Student',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, IconData icon, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ]),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController ctrl,
      String label, {
        IconData? icon,
        TextInputType? inputType,
        bool readOnly = false,
        int? maxLines,
        Widget? suffix,
        String? errorText,
        VoidCallback? onTap,
        ValueChanged<String>? onChanged,
        FormFieldValidator<String>? validator,
      }) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: ctrl,
      keyboardType: inputType,
      readOnly: readOnly,
      maxLines: maxLines ?? 1,
      onTap: onTap,
      onChanged: onChanged,
      validator: validator,
      // Explicit text color so typed text is always visible in dark mode
      style: TextStyle(color: cs.onSurface, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        hintStyle: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.6), fontSize: 13),
        prefixIcon: icon != null ? Icon(icon, size: 20, color: cs.onSurfaceVariant) : null,
        suffixIcon: suffix,
        errorText: errorText,
        filled: true,
        fillColor: cs.surfaceVariant,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.outline)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.outline)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.error, width: 1.5)),
      ),
    );
  }

  Widget _buildGenderRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gender *', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: ['Male', 'Female', 'Other'].map((g) {
            final sel = _gender == g;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _gender = g),
                child: Builder(builder: (context) {
                  final cs = Theme.of(context).colorScheme;
                  return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? cs.primary : cs.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: sel ? cs.primary : cs.outline),
                      ),
                      child: Text(g, textAlign: TextAlign.center,
                          style: TextStyle(color: sel ? Colors.white : cs.onSurface,
                              fontWeight: FontWeight.w600, fontSize: 13)));
                }),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<String>(
      value: _status,
      decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.circle_outlined)),
      items: _statuses.map((s) {
        final label = StudentModel(id: '', admissionNumber: '', studentId: '', name: '',
            fatherName: '', mobile: '', dob: DateTime.now(), gender: '', address: '',
            studentType: '', admissionDate: DateTime.now(), createdAt: DateTime.now(),
            status: s).statusLabel;
        return DropdownMenuItem(value: s, child: Text(label));
      }).toList(),
      onChanged: (v) => setState(() => _status = v!),
    );
  }

  Widget _buildStudentTypeToggle() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: cs.surfaceVariant, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          _typeTab('school', Icons.school_rounded, 'School Student'),
          _typeTab('computer', Icons.computer_rounded, 'Computer Student'),
        ],
      ),
    );
  }

  Widget _typeTab(String type, IconData icon, String label) {
    final selected = _studentType == type;
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _studentType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [BoxShadow(color: cs.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? Colors.white : cs.onSurfaceVariant, size: 18),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(
                  color: selected ? Colors.white : cs.onSurface,
                  fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSchoolDetails() {
    return _buildCard('School Details', Icons.school_outlined, [
      _buildDropdown('Class *', _classes, _selectedClass,
              (v) => setState(() => _selectedClass = v!)),
      const SizedBox(height: 14),
      _buildDropdown('Section', _sections, _selectedSection,
              (v) => setState(() => _selectedSection = v!)),
      const SizedBox(height: 14),
      _buildTextField(_rollCtrl, 'Roll Number', icon: Icons.format_list_numbered,
          inputType: TextInputType.number),
    ]);
  }

  Widget _buildComputerDetails() {
    return _buildCard('Computer Institute Details', Icons.computer_outlined, [
      _buildDropdown('Course *', _courses, _course, (v) => setState(() => _course = v!)),
      const SizedBox(height: 14),
      _buildTextField(_batchCtrl, 'Batch (e.g. Morning, 2024-25)',
          icon: Icons.group_outlined),
      const SizedBox(height: 14),
      // Course Duration
      DropdownButtonFormField<int>(
        value: _courseDurationMonths,
        decoration: const InputDecoration(labelText: 'Course Duration', prefixIcon: Icon(Icons.schedule)),
        items: _durations.map((d) =>
            DropdownMenuItem(value: d, child: Text('$d Months'))).toList(),
        onChanged: (v) => setState(() => _courseDurationMonths = v!),
      ),
      const SizedBox(height: 8),
      // Expected completion
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.successLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_available, color: AppColors.success, size: 18),
            const SizedBox(width: 8),
            Text(
              'Expected Completion: ${_calcExpectedCompletion() != null ? '${_calcExpectedCompletion()!.day}/${_calcExpectedCompletion()!.month}/${_calcExpectedCompletion()!.year}' : 'N/A'}',
              style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildDropdown(String label, List<dynamic> items, dynamic value, ValueChanged<dynamic> onChanged) {
    final cs = Theme.of(context).colorScheme;
    return DropdownButtonFormField(
      value: items.contains(value) ? value : items.first,
      onChanged: onChanged,
      style: TextStyle(color: cs.onSurface, fontSize: 14),
      dropdownColor: cs.surface,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        filled: true,
        fillColor: cs.surfaceVariant,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.outline)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.outline)),
      ),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text('$item'))).toList(),
    );
  }

  Widget _buildPhotoSection() {
    return Center(
      child: StudentPhotoPicker(
        photoPath: _photoPath,
        onChanged: (path) => setState(() => _photoPath = path),
        size: 110,
      ),
    );
  }

  Widget _buildAadhaarDocPicker() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          StudentPhotoPicker(
            photoPath: _aadhaarDocPath,
            onChanged: (path) => setState(() => _aadhaarDocPath = path),
            size: 64,
            borderRadius: BorderRadius.circular(8),
            placeholderIcon: Icons.badge_outlined,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _aadhaarDocPath != null ? 'Aadhaar Card Photo Attached' : 'Attach Aadhaar Card Photo',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: cs.onSurface),
                ),
                const SizedBox(height: 3),
                Text(
                  _aadhaarDocPath != null ? 'Tap image to view, crop or change' : 'Official student verification document (Compressed)',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
