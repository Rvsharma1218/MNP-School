import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/settings_model.dart';
import '../../data/models/teacher_model.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/providers.dart';
import '../../data/services/session_service.dart';
import '../../data/services/teacher_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/student_photo_picker.dart';
import '../attendance/teacher_attendance_screen.dart';
import 'teacher_profile_screen.dart';
import 'teacher_role_access_screen.dart';

class TeacherManagementScreen extends ConsumerStatefulWidget {
  const TeacherManagementScreen({super.key});

  @override
  ConsumerState<TeacherManagementScreen> createState() => _TeacherManagementScreenState();
}

class _TeacherManagementScreenState extends ConsumerState<TeacherManagementScreen> {
  List<TeacherModel> _teachers = [];
  bool _loading = true;
  String? _schoolUid;
  String? _schoolEmail;

  // Search & Filter state
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _statusFilter = 'all'; // 'all' | 'active' | 'disabled'
  String _roleFilter = 'all'; // 'all' | 'class_teacher' | 'subject_teacher'

  // Salaries map for display
  Map<String, double> _teacherSalaries = {};

  @override
  void initState() {
    super.initState();
    final cached = TeacherService.instance.cachedTeachers;
    if (cached.isNotEmpty) {
      _teachers = List.from(cached);
      _loading = false;
    }
    _loadSalaries();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSalaries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final salRaw = prefs.getString('teacher_salaries_map');
      if (salRaw != null) {
        final Map<String, dynamic> decoded = jsonDecode(salRaw);
        _teacherSalaries = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (_teachers.isEmpty || forceRefresh) {
      setState(() => _loading = true);
    }
    final activeUid = SessionService.instance.activeSchoolUid;
    _schoolUid = activeUid.isNotEmpty ? activeUid : SessionService.instance.activeSchoolId;
    final currentEmail = AuthService.instance.currentUser?.email;
    final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
    _schoolEmail = (currentEmail != null && currentEmail.isNotEmpty)
        ? currentEmail
        : ((settings.email != null && settings.email!.isNotEmpty) ? settings.email! : '${_schoolUid!.toLowerCase()}@school.com');

    try {
      final list = await TeacherService.instance.listAllTeachers(_schoolUid!, forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _teachers = list;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[TeacherManagementScreen] Error loading teachers: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<TeacherModel> get _filteredTeachers {
    final query = _searchCtrl.text.trim().toLowerCase();
    return _teachers.where((t) {
      // Search matching
      if (query.isNotEmpty) {
        final nameMatch = t.name.toLowerCase().contains(query);
        final idMatch = t.teacherId.toLowerCase().contains(query);
        final mobileMatch = t.mobile.contains(query);
        final subjectMatch = (t.subject ?? '').toLowerCase().contains(query);
        final classMatch = (t.assignedClass ?? '').toLowerCase().contains(query);
        final emailMatch = t.authEmail.toLowerCase().contains(query);
        if (!nameMatch && !idMatch && !mobileMatch && !subjectMatch && !classMatch && !emailMatch) {
          return false;
        }
      }

      // Status filter
      if (_statusFilter == 'active' && !t.active) return false;
      if (_statusFilter == 'disabled' && t.active) return false;

      // Role filter
      final isClassTeacher = t.assignedClass != null &&
          t.assignedClass!.isNotEmpty &&
          t.assignedClass!.toLowerCase() != 'none';
      if (_roleFilter == 'class_teacher' && !isClassTeacher) return false;
      if (_roleFilter == 'subject_teacher' && isClassTeacher) return false;

      return true;
    }).toList();
  }

  // ─── ADD TEACHER SHEET ───────────────────────────────────────────────────────
  Future<void> _showAddTeacherSheet() async {
    final cs = Theme.of(context).colorScheme;
    final nameCtrl = TextEditingController();
    final fatherCtrl = TextEditingController();
    final motherCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final altPhoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final aadhaarCtrl = TextEditingController();
    final qualCtrl = TextEditingController();
    final desigCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final salaryCtrl = TextEditingController();
    final passwordCtrl = TextEditingController(text: '123456');

    String selectedGender = 'Male';
    DateTime? selectedDob;
    DateTime? selectedJoiningDate;
    String? photoUrl;
    String? aadhaarDocUrl;

    final formKey = GlobalKey<FormState>();
    bool saving = false;

    final schoolUid = _schoolUid ?? 'SCHOOL_001';
    final nextSeqTeacherId = await TeacherService.instance.getNextSequentialTeacherId(schoolUid);

    final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
    final availableClasses = <String>{...settings.schoolClasses, ...settings.computerCourses}.toList();
    final availableSections = settings.sections.isNotEmpty ? settings.sections : ['A', 'B', 'C', 'D'];

    String selectedClass = '';
    String selectedSection = '';

    String buildPreviewEmail(String rawName) {
      final cleanName = rawName.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final namePart = cleanName.length > 12 ? cleanName.substring(0, 12) : cleanName;
      final schoolPart = schoolUid.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      return '${namePart.isEmpty ? 'name' : namePart}.${nextSeqTeacherId.toLowerCase()}@${schoolPart.isEmpty ? 'school001' : schoolPart}.teachers';
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final previewEmail = buildPreviewEmail(nameCtrl.text);

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.9),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: cs.onSurfaceVariant.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Add New Teacher', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: cs.onSurface)),
                              Text('Auto ID: $nextSeqTeacherId', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Center(
                        child: StudentPhotoPicker(
                          photoPath: photoUrl,
                          onChanged: (url) => setSheetState(() => photoUrl = url),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Teacher Name *', prefixIcon: Icon(Icons.person_outline)),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        onChanged: (_) => setSheetState(() {}),
                      ),
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Mobile Number *', prefixIcon: Icon(Icons.phone_outlined)),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedClass.isEmpty ? null : selectedClass,
                              decoration: const InputDecoration(labelText: 'Assigned Class'),
                              items: [
                                const DropdownMenuItem(value: '', child: Text('None (Subject Teacher)')),
                                ...availableClasses.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                              ],
                              onChanged: (val) => setSheetState(() => selectedClass = val ?? ''),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedSection.isEmpty ? null : selectedSection,
                              decoration: const InputDecoration(labelText: 'Section'),
                              items: [
                                const DropdownMenuItem(value: '', child: Text('All / Any')),
                                ...availableSections.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                              ],
                              onChanged: (val) => setSheetState(() => selectedSection = val ?? ''),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: desigCtrl,
                              decoration: const InputDecoration(labelText: 'Designation', hintText: 'Senior Teacher'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: subjectCtrl,
                              decoration: const InputDecoration(labelText: 'Subject', hintText: 'English / Math'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: qualCtrl,
                              decoration: const InputDecoration(labelText: 'Qualification', hintText: 'B.Ed, M.Sc'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: salaryCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Salary (₹/mo)', prefixText: '₹ '),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: fatherCtrl,
                              decoration: const InputDecoration(labelText: 'Father\'s Name'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: motherCtrl,
                              decoration: const InputDecoration(labelText: 'Mother\'s Name'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: addressCtrl,
                        decoration: const InputDecoration(labelText: 'Residential Address'),
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: altPhoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(labelText: 'Alt Mobile'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: aadhaarCtrl,
                              decoration: const InputDecoration(labelText: 'Aadhaar Number'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            StudentPhotoPicker(
                              photoPath: aadhaarDocUrl,
                              onChanged: (url) => setSheetState(() => aadhaarDocUrl = url),
                              size: 56,
                              borderRadius: BorderRadius.circular(8),
                              placeholderIcon: Icons.badge_outlined,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    aadhaarDocUrl != null ? 'Aadhaar Card Attached' : 'Attach Aadhaar Card / ID Proof',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: cs.onSurface),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    aadhaarDocUrl != null ? 'Tap to view or replace image' : 'Faculty verification document (Compressed)',
                                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: passwordCtrl,
                        decoration: const InputDecoration(labelText: 'Portal Password *', prefixIcon: Icon(Icons.lock_outline)),
                        validator: (v) => v == null || v.trim().length < 6 ? 'Min 6 chars' : null,
                      ),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.mail_outline, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Portal Login Email:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  Text(previewEmail, style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', fontWeight: FontWeight.w700, color: AppColors.primary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                          onPressed: saving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setSheetState(() => saving = true);

                                  final salVal = double.tryParse(salaryCtrl.text.trim()) ?? 25000.0;
                                  final newT = await TeacherService.instance.createTeacher(
                                    schoolUid: schoolUid,
                                    schoolEmail: _schoolEmail ?? '',
                                    name: nameCtrl.text.trim(),
                                    mobile: phoneCtrl.text.trim(),
                                    password: passwordCtrl.text.trim(),
                                    assignedClass: selectedClass.isEmpty ? null : selectedClass,
                                    assignedSection: selectedSection.isEmpty ? null : selectedSection,
                                    fatherName: fatherCtrl.text.trim().isEmpty ? null : fatherCtrl.text.trim(),
                                    motherName: motherCtrl.text.trim().isEmpty ? null : motherCtrl.text.trim(),
                                    dob: selectedDob,
                                    gender: selectedGender,
                                    address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                                    alternateMobile: altPhoneCtrl.text.trim().isEmpty ? null : altPhoneCtrl.text.trim(),
                                    aadhaarNumber: aadhaarCtrl.text.trim().isEmpty ? null : aadhaarCtrl.text.trim(),
                                    qualification: qualCtrl.text.trim().isEmpty ? null : qualCtrl.text.trim(),
                                    designation: desigCtrl.text.trim().isEmpty ? null : desigCtrl.text.trim(),
                                    subject: subjectCtrl.text.trim().isEmpty ? null : subjectCtrl.text.trim(),
                                    joiningDate: selectedJoiningDate,
                                    salary: salVal,
                                    photoUrl: photoUrl,
                                    aadhaarDocUrl: aadhaarDocUrl,
                                  );

                                  _teacherSalaries[newT.teacherId] = salVal;
                                  try {
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.setString('teacher_salaries_map', jsonEncode(_teacherSalaries));
                                  } catch (_) {}

                                  Navigator.pop(ctx);
                                  _load(forceRefresh: true);

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Teacher ${newT.name} added successfully!'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  }
                                },
                          child: saving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Add Faculty Member', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── BUILD UI ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final list = _filteredTeachers;

    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        title: Text('Faculty / Teachers (${list.length})'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Faculty Daily Attendance',
            icon: const Icon(Icons.event_available_rounded, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TeacherAttendanceScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Teacher Role Permissions (ON/OFF)',
            icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TeacherRoleAccessScreen()),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by name, ID, mobile, subject...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.65)),
                prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.85)),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTeacherSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Teacher',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Container(
            color: cs.surface,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('All Staff', _statusFilter == 'all' && _roleFilter == 'all', () {
                    setState(() {
                      _statusFilter = 'all';
                      _roleFilter = 'all';
                    });
                  }, cs),
                  const SizedBox(width: 6),
                  _filterChip('Active', _statusFilter == 'active', () {
                    setState(() => _statusFilter = _statusFilter == 'active' ? 'all' : 'active');
                  }, cs),
                  const SizedBox(width: 6),
                  _filterChip('Disabled', _statusFilter == 'disabled', () {
                    setState(() => _statusFilter = _statusFilter == 'disabled' ? 'all' : 'disabled');
                  }, cs),
                  const SizedBox(width: 6),
                  _filterChip('Class Teachers', _roleFilter == 'class_teacher', () {
                    setState(() => _roleFilter = _roleFilter == 'class_teacher' ? 'all' : 'class_teacher');
                  }, cs),
                  const SizedBox(width: 6),
                  _filterChip('Subject Teachers', _roleFilter == 'subject_teacher', () {
                    setState(() => _roleFilter = _roleFilter == 'subject_teacher' ? 'all' : 'subject_teacher');
                  }, cs),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant.withOpacity(0.4)),

          // Main List Body
          Expanded(
            child: _loading
                ? const LoadingWidget()
                : list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.school_outlined, size: 56, color: cs.onSurfaceVariant.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            Text(
                              _searchCtrl.text.isNotEmpty ? 'No teachers match your search' : 'No Teachers Found',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _searchCtrl.text.isNotEmpty ? 'Try a different name or ID' : 'Tap "+ Add Teacher" to add faculty',
                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _load(forceRefresh: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
                          itemCount: list.length,
                          itemBuilder: (ctx, i) {
                            final t = list[i];
                            return _buildTeacherCard(t, cs);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ─── TEACHER CARD (MATCHES STUDENT CARD IMAGE 2 IDENTICALLY) ──────────────────
  Widget _buildTeacherCard(TeacherModel t, ColorScheme cs) {
    final assignedClassText = (t.assignedClass != null &&
            t.assignedClass!.isNotEmpty &&
            t.assignedClass!.toLowerCase() != 'none')
        ? t.displayAssignedClass
        : (t.subject != null && t.subject!.isNotEmpty ? 'Subject: ${t.subject}' : 'General Faculty');

    final fatherOrDesigText = (t.fatherName != null && t.fatherName!.isNotEmpty)
        ? t.fatherName!
        : (t.designation ?? 'Teacher');

    final salaryVal = _teacherSalaries[t.teacherId] ?? t.salary ?? 25000.0;
    final salaryText = '₹ ${salaryVal.toInt().toString()} / mo';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: cs.surface,
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TeacherProfileScreen(
                teacher: t,
                onTeacherUpdated: () => _load(forceRefresh: true),
              ),
            ),
          );
          _load(forceRefresh: true);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildPhoto(t),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Teacher Name + 'Staff' Chip
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _typeChip('Staff', cs),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Row 1: Numbers/ID + Badge/Email
                    Row(
                      children: [
                        Icon(Icons.numbers, size: 11, color: cs.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(
                          t.teacherId,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.badge_outlined, size: 11, color: cs.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            t.authEmail.isNotEmpty ? t.authEmail : t.id,
                            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Row 2: School Class / Subject
                    Row(
                      children: [
                        Icon(Icons.school_outlined, size: 11, color: cs.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            assignedClassText,
                            style: TextStyle(fontSize: 11, color: cs.onSurface),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Row 3: Father Name / Designation + Mobile
                    Row(
                      children: [
                        Icon(Icons.person_2_outlined, size: 11, color: cs.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            fatherOrDesigText,
                            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (t.mobile.isNotEmpty) ...[
                          Icon(Icons.phone_outlined, size: 11, color: cs.onSurfaceVariant),
                          const SizedBox(width: 3),
                          Text(
                            t.mobile,
                            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Row 4: Status Chip + Salary Chip
                    Row(
                      children: [
                        _statusChip(t.active ? 'Active' : 'Disabled', t.active ? AppColors.success : AppColors.error),
                        const SizedBox(width: 6),
                        _salaryChip(salaryText),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: cs.onSurfaceVariant),
                tooltip: 'Teacher Actions',
                onSelected: (action) async {
                  if (action == 'profile') {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TeacherProfileScreen(
                          teacher: t,
                          onTeacherUpdated: () => _load(forceRefresh: true),
                        ),
                      ),
                    );
                    _load(forceRefresh: true);
                  } else if (action == 'toggle') {
                    await _quickToggleTeacherActive(t);
                  } else if (action == 'delete') {
                    await _quickDeleteTeacher(t);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('View Full Profile'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          t.active ? Icons.block : Icons.check_circle_outline,
                          size: 18,
                          color: t.active ? AppColors.error : AppColors.success,
                        ),
                        SizedBox(width: 8),
                        Text(t.active ? 'Disable Account' : 'Enable Account'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Delete Teacher', style: TextStyle(color: AppColors.error)),
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
  }

  Future<void> _quickToggleTeacherActive(TeacherModel t) async {
    final newStatus = !t.active;
    final actionText = newStatus ? 'Enable' : 'Disable';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              newStatus ? Icons.check_circle_outline : Icons.block,
              color: newStatus ? AppColors.success : AppColors.error,
            ),
            const SizedBox(width: 8),
            Text('$actionText Teacher?'),
          ],
        ),
        content: Text('Are you sure you want to $actionText ${t.name}\'s account?\n\n'
            '${newStatus ? '• Teacher can log in to the portal.' : '• Teacher login access will be blocked.'}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus ? AppColors.success : AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text('Yes, $actionText'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final schoolUid = _schoolUid ?? SessionService.instance.activeSchoolId;
      await TeacherService.instance.setTeacherActive(
        schoolUid: schoolUid,
        schoolEmail: _schoolEmail ?? '',
        teacher: t,
        active: newStatus,
      );

      setState(() {
        final idx = _teachers.indexWhere((x) => x.teacherId == t.teacherId || x.id == t.id);
        if (idx != -1) {
          _teachers[idx] = _teachers[idx].copyWith(active: newStatus, status: newStatus ? 'active' : 'disabled');
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t.name} is now ${newStatus ? 'Active' : 'Disabled'}'),
            backgroundColor: newStatus ? AppColors.success : AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _quickDeleteTeacher(TeacherModel t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Teacher?'),
        content: Text('Are you sure you want to permanently delete ${t.name}? All login access will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final schoolUid = _schoolUid ?? SessionService.instance.activeSchoolId;
      await TeacherService.instance.deleteTeacher(
        schoolUid: schoolUid,
        schoolEmail: _schoolEmail,
        teacher: t,
      );

      setState(() {
        _teachers.removeWhere((x) => x.teacherId == t.teacherId || x.id == t.id || (t.authUid.isNotEmpty && x.authUid == t.authUid));
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t.name} has been deleted.'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ─── PHOTO AVATAR (56x56 identical to student card) ───────────────────────────
  Widget _buildPhoto(TeacherModel t) {
    final initials = t.name
        .trim()
        .split(' ')
        .map((p) => p.isNotEmpty ? p[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return CircleAvatar(
      radius: 28,
      backgroundColor: AppColors.primary.withOpacity(0.12),
      child: ClipOval(
        child: AppUtils.buildAppImageWidget(
          t.photoUrl,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          placeholder: Text(
            initials.isNotEmpty ? initials : 'T',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }

  // ─── CHIPS (MATCHING STUDENT CHIPS) ──────────────────────────────────────────
  Widget _typeChip(String label, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4F46E5),
        ),
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _salaryChip(String salary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        salary,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF059669),
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool isSelected, VoidCallback onTap, ColorScheme cs) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : cs.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.primary : cs.outlineVariant.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : cs.onSurface,
          ),
        ),
      ),
    );
  }
}