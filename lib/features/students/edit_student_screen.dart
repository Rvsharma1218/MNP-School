import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/student_model.dart';
import '../../data/models/settings_model.dart';
import '../../data/services/database_service.dart';
import '../../data/services/providers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/student_photo_picker.dart';

class EditStudentScreen extends ConsumerStatefulWidget {
  final String studentId;
  const EditStudentScreen({super.key, required this.studentId});

  @override
  ConsumerState<EditStudentScreen> createState() => _EditStudentScreenState();
}

class _EditStudentScreenState extends ConsumerState<EditStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  StudentModel? _student;
  bool _loading = true;
  bool _saving = false;
  bool _checkingAdmNo = false;
  bool _admNoExists = false;

  final _nameCtrl = TextEditingController();
  final _fatherCtrl = TextEditingController();
  final _motherCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _altMobileCtrl = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _addressCtrl   = TextEditingController();
  final _admissionNoCtrl = TextEditingController();
  final _aadhaarCtrl = TextEditingController();
  final _rollCtrl = TextEditingController();
  final _batchCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _admissionDateCtrl = TextEditingController();

  String _gender = 'Male';
  String _studentType = 'school';
  String _course = 'DCA';
  String _selectedClass = '1';
  String _selectedSection = 'A';
  String _status = 'active';
  String _session = '2026-27';
  int _courseDurationMonths = 6;
  DateTime _dob = DateTime(2010);
  DateTime _admissionDate = DateTime.now();
  String? _photoPath;
  String? _aadhaarDocPath;

  final _courses = SettingsModel.defaultCourses;
  final _classes = SettingsModel.defaultClasses;
  final _sections = ['A', 'B', 'C', 'D', 'E'];
  final _durations = [3, 6, 9, 12, 18, 24];

  @override
  void initState() {
    super.initState();
    _loadStudent();
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _fatherCtrl.dispose(); _motherCtrl.dispose();
    _mobileCtrl.dispose(); _altMobileCtrl.dispose(); _emailCtrl.dispose(); _addressCtrl.dispose();
    _admissionNoCtrl.dispose(); _aadhaarCtrl.dispose(); _rollCtrl.dispose(); _batchCtrl.dispose();
    _dobCtrl.dispose(); _admissionDateCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  Future<void> _loadStudent() async {
    final s = await DatabaseService.instance.getStudentById(widget.studentId);
    if (s != null && mounted) {
      setState(() {
        _student = s;
        _nameCtrl.text = s.name;
        _fatherCtrl.text = s.fatherName;
        _motherCtrl.text = s.motherName ?? '';
        _mobileCtrl.text = s.mobile;
        _altMobileCtrl.text = s.alternateMobile ?? '';
        _emailCtrl.text     = s.email ?? '';
        _addressCtrl.text   = s.address;
        _admissionNoCtrl.text = s.admissionNumber;
        _aadhaarCtrl.text   = s.aadhaarNumber ?? '';
        _rollCtrl.text = s.rollNumber ?? '';
        _batchCtrl.text = s.batch ?? '';
        _gender = s.gender;
        _studentType = s.studentType;
        _course = s.course ?? 'DCA';
        _selectedClass = s.className ?? '1';
        _selectedSection = s.section ?? 'A';
        _status = s.status;
        _session = s.session ?? '2026-27';
        _courseDurationMonths = s.courseDurationMonths ?? 6;
        _dob = s.dob;
        _admissionDate = s.admissionDate;
        _photoPath = s.photoPath;
        _aadhaarDocPath = s.aadhaarDocPath;
        _dobCtrl.text = _fmt(s.dob);
        _admissionDateCtrl.text = _fmt(s.admissionDate);
        _loading = false;
      });
    }
  }

  Future<void> _checkAdmissionNumber(String value) async {
    if (value.trim().isEmpty || value.trim() == _student?.admissionNumber) return;
    setState(() => _checkingAdmNo = true);
    final exists = await DatabaseService.instance.isAdmissionNumberExists(value.trim(), excludeId: widget.studentId);
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
        if (isDob) { _dob = picked; _dobCtrl.text = _fmt(picked); }
        else { _admissionDate = picked; _admissionDateCtrl.text = _fmt(picked); }
      });
    }
  }

  DateTime? _calcExpectedCompletion() {
    if (_studentType != 'computer') return null;
    return DateTime(_admissionDate.year, _admissionDate.month + _courseDurationMonths, _admissionDate.day);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _student == null) return;
    if (_admNoExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admission Number already exists!'), backgroundColor: AppColors.error),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final updated = _student!.copyWith(
        name: _nameCtrl.text.trim(),
        fatherName: _fatherCtrl.text.trim(),
        motherName: _motherCtrl.text.trim().isEmpty ? null : _motherCtrl.text.trim(),
        mobile: _mobileCtrl.text.trim(),
        alternateMobile: _altMobileCtrl.text.trim().isEmpty ? null : _altMobileCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        admissionNumber: _admissionNoCtrl.text.trim(),
        gender: _gender,
        studentType: _studentType,
        photoPath: _photoPath,
        clearPhoto: _photoPath == null || _photoPath!.trim().isEmpty,
        aadhaarNumber: _aadhaarCtrl.text.trim().isEmpty ? null : _aadhaarCtrl.text.trim(),
        aadhaarDocPath: _aadhaarDocPath,
        clearAadhaarDoc: _aadhaarDocPath == null || _aadhaarDocPath!.trim().isEmpty,
        dob: _dob,
        admissionDate: _admissionDate,
        status: _status,
        session: _session,
        className: _studentType == 'school' ? _selectedClass : null,
        section: _studentType == 'school' ? _selectedSection : null,
        rollNumber: _studentType == 'school' && _rollCtrl.text.trim().isNotEmpty
            ? _rollCtrl.text.trim() : null,
        course: _studentType == 'computer' ? _course : null,
        batch: _studentType == 'computer' && _batchCtrl.text.trim().isNotEmpty
            ? _batchCtrl.text.trim() : null,
        courseDurationMonths: _studentType == 'computer' ? _courseDurationMonths : null,
        expectedCompletionDate: _calcExpectedCompletion(),
      );
      await ref.read(studentsProvider.notifier).updateStudent(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student updated!'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: LoadingWidget());
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit — ${_student?.name ?? 'Student'}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Photo
            Center(
              child: StudentPhotoPicker(
                photoPath: _photoPath,
                onChanged: (path) => setState(() => _photoPath = path),
                size: 100,
              ),
            ),
            const SizedBox(height: 20),

            // Type Toggle
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: ['school', 'computer'].map((t) {
                  final sel = _studentType == t;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _studentType = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          t == 'school' ? '🏫 School Student' : '💻 Computer Student',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: sel
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Admission No
            _field(_admissionNoCtrl, 'Admission Number *', Icons.numbers,
                onChanged: _checkAdmissionNumber,
                suffix: _checkingAdmNo
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : _admNoExists ? const Icon(Icons.error, color: AppColors.error)
                    : null,
                errorText: _admNoExists ? 'Already exists' : null,
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
            const SizedBox(height: 14),
            _field(_nameCtrl, 'Student Name *', Icons.person,
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
            const SizedBox(height: 14),
            _field(_fatherCtrl, "Father's Name *", Icons.person_2,
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
            const SizedBox(height: 14),
            _field(_motherCtrl, "Mother's Name", Icons.person_2_outlined),
            const SizedBox(height: 14),
            _field(_mobileCtrl, 'Mobile *', Icons.phone, inputType: TextInputType.phone,
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
            const SizedBox(height: 14),
            _field(_altMobileCtrl, 'Alternate Mobile', Icons.phone_android, inputType: TextInputType.phone),
            const SizedBox(height: 14),
            _field(_emailCtrl, 'Email (Optional)', Icons.email_outlined,
                inputType: TextInputType.emailAddress),
            const SizedBox(height: 14),
            _field(_dobCtrl, 'Date of Birth', Icons.cake,
                readOnly: true, suffix: const Icon(Icons.calendar_today), onTap: () => _pickDate(true)),
            const SizedBox(height: 14),
            _field(_addressCtrl, 'Address *', Icons.location_on, maxLines: 3,
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
            const SizedBox(height: 14),
            _field(_admissionDateCtrl, 'Admission Date', Icons.event,
                readOnly: true, suffix: const Icon(Icons.calendar_today), onTap: () => _pickDate(false)),
            const SizedBox(height: 14),

            // Gender
            _buildGenderRow(),
            const SizedBox(height: 14),
            _field(_aadhaarCtrl, 'Aadhaar / Document ID', Icons.badge_outlined,
                inputType: TextInputType.number),
            const SizedBox(height: 14),
            _buildAadhaarDocPicker(),
            const SizedBox(height: 14),

            // Status
            _buildDropdown('Status', ['active', 'completed', 'left', 'suspended'],
                _status, (v) => setState(() => _status = v!),
                displayText: (v) => StudentModel(id: '', admissionNumber: '', studentId: '',
                    name: '', fatherName: '', mobile: '', dob: DateTime.now(), gender: '',
                    address: '', studentType: '', admissionDate: DateTime.now(),
                    createdAt: DateTime.now(), status: v).statusLabel),
            const SizedBox(height: 14),

            // Session
            _buildDropdown('Academic Session', SettingsModel.getSessions(),
                SettingsModel.getSessions().contains(_session) ? _session : SettingsModel.getSessions().first,
                    (v) => setState(() => _session = v!)),
            const SizedBox(height: 14),

            // School/Computer specific
            if (_studentType == 'school') ...[
              _buildDropdown('Class', _classes.contains(_selectedClass) ? _classes : [_selectedClass, ..._classes], _selectedClass,
                      (v) => setState(() => _selectedClass = v!)),
              const SizedBox(height: 14),
              _buildDropdown('Section', _sections.contains(_selectedSection) ? _sections : [_selectedSection, ..._sections], _selectedSection,
                      (v) => setState(() => _selectedSection = v!)),
              const SizedBox(height: 14),
              _field(_rollCtrl, 'Roll Number', Icons.format_list_numbered, inputType: TextInputType.number),
            ],
            if (_studentType == 'computer') ...[
              _buildDropdown('Course', _courses.contains(_course) ? _courses : [_course, ..._courses], _course,
                      (v) => setState(() => _course = v!)),
              const SizedBox(height: 14),
              _field(_batchCtrl, 'Batch', Icons.group_outlined),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                value: _durations.contains(_courseDurationMonths) ? _courseDurationMonths : 6,
                decoration: InputDecoration(
                  labelText: 'Course Duration',
                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  prefixIcon: Icon(Icons.schedule, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.outline)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.outline)),
                ),
                dropdownColor: Theme.of(context).colorScheme.surface,
                items: _durations.map((d) => DropdownMenuItem(
                  value: d,
                  child: Text('$d Months',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                )).toList(),
                onChanged: (v) => setState(() => _courseDurationMonths = v!),
              ),
              if (_calcExpectedCompletion() != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.event_available, color: AppColors.success, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Expected Completion: ${_calcExpectedCompletion()!.day}/${_calcExpectedCompletion()!.month}/${_calcExpectedCompletion()!.year}',
                        style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ]),
                  ),
                ),
            ],
            const SizedBox(height: 24),

            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Saving...' : 'Update Student',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderRow() {
    final cs = Theme.of(context).colorScheme;
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
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sel ? AppColors.primary : cs.outline,
                    ),
                  ),
                  child: Text(g, textAlign: TextAlign.center,
                      style: TextStyle(
                        color: sel ? Colors.white : cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      )),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>(String label, List<T> items, T value, ValueChanged<T?> onChanged,
      {String Function(T)? displayText}) {
    final cs = Theme.of(context).colorScheme;
    return DropdownButtonFormField<T>(
      value: items.contains(value) ? value : items.first,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outline),
        ),
      ),
      dropdownColor: cs.surface,
      items: items.map((item) => DropdownMenuItem<T>(
          value: item,
          child: Text(displayText != null ? displayText(item) : '$item',
            style: TextStyle(color: cs.onSurface),
          ))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {
    TextInputType? inputType, bool readOnly = false, int? maxLines, Widget? suffix,
    String? errorText, VoidCallback? onTap, ValueChanged<String>? onChanged,
    FormFieldValidator<String>? validator,
  }) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: ctrl, keyboardType: inputType, readOnly: readOnly,
      maxLines: maxLines ?? 1, onTap: onTap, onChanged: onChanged, validator: validator,
      style: TextStyle(color: cs.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: cs.onSurfaceVariant),
        prefixIcon: Icon(icon, size: 20, color: cs.onSurfaceVariant),
        suffixIcon: suffix,
        errorText: errorText,
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
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