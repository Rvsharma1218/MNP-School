import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../core/utils/file_saver.dart';
import '../../core/utils/signature_processor.dart';
import '../../data/models/settings_model.dart';
import '../../data/models/teacher_model.dart';
import '../../data/services/providers.dart';
import '../../data/services/session_service.dart';
import '../../data/services/teacher_service.dart';
import '../../widgets/student_photo_picker.dart';
import '../attendance/teacher_attendance_screen.dart';

class TeacherProfileScreen extends ConsumerStatefulWidget {
  final TeacherModel teacher;
  final VoidCallback? onTeacherUpdated;

  const TeacherProfileScreen({
    super.key,
    required this.teacher,
    this.onTeacherUpdated,
  });

  @override
  ConsumerState<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends ConsumerState<TeacherProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TeacherModel _teacher;
  bool _showPassword = false;

  // Attendance
  Map<String, String> _attendanceHistory = {};
  bool _loadingAttendance = true;

  // Salary
  Map<String, double> _teacherSalaries = {};
  Map<String, List<Map<String, dynamic>>> _salaryHistory = {};

  @override
  void initState() {
    super.initState();
    _teacher = widget.teacher;
    _tabController = TabController(length: 5, vsync: this);
    _loadSalaries();
    _loadTeacherAttendance();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── SALARY PERSISTENCE ───────────────────────────────────────────────────────
  Future<void> _loadSalaries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final salRaw = prefs.getString('teacher_salaries_map');
      if (salRaw != null) {
        final Map<String, dynamic> decoded = jsonDecode(salRaw);
        _teacherSalaries = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
      }
      final histRaw = prefs.getString('teacher_salary_history_map');
      if (histRaw != null) {
        final Map<String, dynamic> decoded = jsonDecode(histRaw);
        _salaryHistory = decoded.map((k, v) => MapEntry(k, List<Map<String, dynamic>>.from(v)));
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _saveSalaries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('teacher_salaries_map', jsonEncode(_teacherSalaries));
      await prefs.setString('teacher_salary_history_map', jsonEncode(_salaryHistory));
    } catch (_) {}
  }

  // ─── ATTENDANCE PERSISTENCE ───────────────────────────────────────────────────
  Future<void> _loadTeacherAttendance() async {
    final schoolUid = SessionService.instance.activeSchoolUid;
    if (schoolUid.isEmpty) {
      if (mounted) setState(() => _loadingAttendance = false);
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolUid)
          .collection('teacher_attendance')
          .get();

      final map = <String, String>{};
      final teacherKey = _teacher.teacherId.isNotEmpty ? _teacher.teacherId : _teacher.authUid;

      for (final doc in snap.docs) {
        final data = doc.data();
        final records = data['records'] as Map<String, dynamic>?;
        if (records != null) {
          final st = records[teacherKey]?.toString() ??
                     records[_teacher.teacherId]?.toString() ??
                     records[_teacher.authUid]?.toString();
          if (st != null && st.isNotEmpty) {
            map[doc.id] = st;
          }
        }
      }

      if (mounted) {
        setState(() {
          _attendanceHistory = map;
          _loadingAttendance = false;
        });
      }
    } catch (e) {
      debugPrint('[TeacherProfileScreen] Error loading attendance: $e');
      if (mounted) setState(() => _loadingAttendance = false);
    }
  }

  // 1-Click Today Attendance Marking
  Future<void> _markTodayAttendance(String status) async {
    final schoolUid = SessionService.instance.activeSchoolUid;
    if (schoolUid.isEmpty) return;
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final teacherKey = _teacher.teacherId.isNotEmpty ? _teacher.teacherId : _teacher.authUid;

    setState(() {
      _attendanceHistory[todayKey] = status;
    });

    try {
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolUid)
          .collection('teacher_attendance')
          .doc(todayKey)
          .set({
        'date': todayKey,
        'records': {
          teacherKey: status,
          if (_teacher.teacherId.isNotEmpty) _teacher.teacherId: status,
          if (_teacher.authUid.isNotEmpty) _teacher.authUid: status,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marked ${_teacher.name} as ${status.toUpperCase()} for Today!'),
            backgroundColor: status == 'present'
                ? const Color(0xFF10B981)
                : status == 'absent'
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFF59E0B),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[TeacherProfileScreen] Error marking 1-click attendance: $e');
    }
  }

  // ─── CONTACT HELPERS ──────────────────────────────────────────────────────────
  void _callPhone(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _openWhatsApp(String phone) async {
    var clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length == 10) clean = '91$clean';
    if (clean.isEmpty) return;
    final uri = Uri.parse('https://wa.me/$clean?text=Hello%20${Uri.encodeComponent(_teacher.name)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ─── DISABLE / ENABLE WITH EXPLICIT YES/NO DIALOG ────────────────────────────
  Future<void> _toggleActive() async {
    final newStatus = !_teacher.active;
    final actionText = newStatus ? 'Enable' : 'Disable';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              newStatus ? Icons.check_circle_outline : Icons.block,
              color: newStatus ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
            const SizedBox(width: 8),
            Text('$actionText Teacher?'),
          ],
        ),
        content: Text(
          'Are you sure you want to $actionText ${_teacher.name}\'s account?\n\n'
          '${newStatus ? '• The teacher will be able to log in to the portal.' : '• The teacher will be prevented from logging in to the portal.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: Text('Yes, $actionText'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final schoolUid = SessionService.instance.activeSchoolUid;
    final schoolEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    await TeacherService.instance.setTeacherActive(
      schoolUid: schoolUid,
      schoolEmail: schoolEmail,
      teacher: _teacher,
      active: newStatus,
    );

    setState(() {
      _teacher = _teacher.copyWith(active: newStatus);
    });
    widget.onTeacherUpdated?.call();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_teacher.name} is now ${newStatus ? 'Active' : 'Disabled'}'),
          backgroundColor: newStatus ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  // ─── RESET PASSWORD ──────────────────────────────────────────────────────────
  Future<void> _showResetPasswordDialog() async {
    final passwordCtrl = TextEditingController(text: '123456');
    bool obscure = true;

    final newPassword = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Reset Password — ${_teacher.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter new portal password for this teacher (minimum 6 characters):',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (passwordCtrl.text.trim().length < 6) return;
                Navigator.pop(ctx, passwordCtrl.text.trim());
              },
              child: const Text('Confirm Reset'),
            ),
          ],
        ),
      ),
    );

    if (newPassword == null || newPassword.isEmpty) return;

    try {
      final schoolUid = SessionService.instance.activeSchoolUid;
      final schoolEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      await TeacherService.instance.resetTeacherPassword(
        schoolUid: schoolUid.isNotEmpty ? schoolUid : 'SCHOOL_001',
        schoolEmail: schoolEmail,
        teacher: _teacher,
        newPassword: newPassword,
      );

      setState(() {
        _teacher = _teacher.copyWith(password: newPassword);
      });
      widget.onTeacherUpdated?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully. Share new password with teacher.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reset failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ─── EDIT TEACHER SHEET ──────────────────────────────────────────────────────
  Future<void> _showEditTeacherSheet() async {
    final cs = Theme.of(context).colorScheme;
    final nameCtrl = TextEditingController(text: _teacher.name);
    final fatherCtrl = TextEditingController(text: _teacher.fatherName ?? '');
    final motherCtrl = TextEditingController(text: _teacher.motherName ?? '');
    final phoneCtrl = TextEditingController(text: _teacher.mobile);
    final altPhoneCtrl = TextEditingController(text: _teacher.alternateMobile ?? '');
    final addressCtrl = TextEditingController(text: _teacher.address ?? '');
    final aadhaarCtrl = TextEditingController(text: _teacher.aadhaarNumber ?? '');
    final qualCtrl = TextEditingController(text: _teacher.qualification ?? '');
    final desigCtrl = TextEditingController(text: _teacher.designation ?? '');
    final subjectCtrl = TextEditingController(text: _teacher.subject ?? '');
    final salaryCtrl = TextEditingController(
      text: (_teacher.salary != null && _teacher.salary! > 0)
          ? _teacher.salary!.toInt().toString()
          : (_teacherSalaries[_teacher.teacherId]?.toInt().toString() ?? '25000'),
    );

    String selectedGender = _teacher.gender ?? 'Male';
    DateTime? selectedDob = _teacher.dob;
    DateTime? selectedJoiningDate = _teacher.joiningDate;
    String? photoUrl = _teacher.photoUrl;
    String? aadhaarDocUrl = _teacher.aadhaarDocUrl;

    final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
    final availableClasses = <String>{...settings.schoolClasses, ...settings.computerCourses}.toList();
    final availableSections = settings.sections.isNotEmpty ? settings.sections : ['A', 'B', 'C', 'D'];

    String selectedClass = (_teacher.assignedClass != null && _teacher.assignedClass!.toLowerCase() != 'none')
        ? _teacher.assignedClass!
        : '';
    String selectedSection = _teacher.assignedSection ?? '';

    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
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
                          Text('Edit Teacher Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: cs.onSurface)),
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
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Full Name *', prefixIcon: Icon(Icons.person_outline)),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
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
                              decoration: const InputDecoration(labelText: 'Subject', hintText: 'Mathematics'),
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

                                  final schoolUid = SessionService.instance.activeSchoolUid;
                                  final schoolEmail = FirebaseAuth.instance.currentUser?.email ?? '';
                                  final salVal = double.tryParse(salaryCtrl.text.trim()) ?? 25000.0;

                                  await TeacherService.instance.updateTeacherDetails(
                                    schoolUid: schoolUid.isNotEmpty ? schoolUid : 'SCHOOL_001',
                                    schoolEmail: schoolEmail,
                                    teacher: _teacher,
                                    newName: nameCtrl.text.trim(),
                                    assignedClass: selectedClass,
                                    assignedSection: selectedSection,
                                    mobile: phoneCtrl.text.trim(),
                                    fatherName: fatherCtrl.text.trim(),
                                    motherName: motherCtrl.text.trim(),
                                    dob: selectedDob,
                                    gender: selectedGender,
                                    address: addressCtrl.text.trim(),
                                    alternateMobile: altPhoneCtrl.text.trim(),
                                    aadhaarNumber: aadhaarCtrl.text.trim(),
                                    qualification: qualCtrl.text.trim(),
                                    designation: desigCtrl.text.trim(),
                                    subject: subjectCtrl.text.trim(),
                                    joiningDate: selectedJoiningDate,
                                    salary: salVal,
                                    photoUrl: photoUrl,
                                    aadhaarDocUrl: aadhaarDocUrl,
                                  );

                                  _teacherSalaries[_teacher.teacherId] = salVal;
                                  await _saveSalaries();

                                  setState(() {
                                    _teacher = _teacher.copyWith(
                                      name: nameCtrl.text.trim(),
                                      mobile: phoneCtrl.text.trim(),
                                      assignedClass: selectedClass,
                                      assignedSection: selectedSection,
                                      fatherName: fatherCtrl.text.trim(),
                                      motherName: motherCtrl.text.trim(),
                                      address: addressCtrl.text.trim(),
                                      alternateMobile: altPhoneCtrl.text.trim(),
                                      aadhaarNumber: aadhaarCtrl.text.trim(),
                                      qualification: qualCtrl.text.trim(),
                                      designation: desigCtrl.text.trim(),
                                      subject: subjectCtrl.text.trim(),
                                      salary: salVal,
                                      photoUrl: photoUrl,
                                      aadhaarDocUrl: aadhaarDocUrl,
                                    );
                                  });

                                  widget.onTeacherUpdated?.call();
                                  Navigator.pop(ctx);

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Teacher profile updated successfully!'), backgroundColor: AppColors.success),
                                    );
                                  }
                                },
                          child: saving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Save Profile Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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

  // ─── DELETE TEACHER ──────────────────────────────────────────────────────────
  Future<void> _deleteTeacher() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Teacher?'),
        content: Text('Are you sure you want to permanently delete ${_teacher.name}? All login access will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final schoolUid = SessionService.instance.activeSchoolUid;
      final schoolEmail = FirebaseAuth.instance.currentUser?.email;
      await TeacherService.instance.deleteTeacher(
        schoolUid: schoolUid,
        schoolEmail: schoolEmail,
        teacher: _teacher,
      );
      widget.onTeacherUpdated?.call();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_teacher.name} has been deleted.'), backgroundColor: AppColors.success),
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

  // ─── PAY SALARY DIALOG & RECORDING ───────────────────────────────────────────
  void _showPaySalaryDialog() {
    final defaultSalary = _teacher.salary ?? (_teacherSalaries[_teacher.teacherId] ?? 25000.0);
    final amountCtrl = TextEditingController(text: defaultSalary.toInt().toString());
    final currentMonth = DateFormat('MMMM yyyy').format(DateTime.now());
    String selectedMonth = currentMonth;
    String paymentMode = 'Bank Transfer';
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.payments_rounded, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Pay Salary — ${_teacher.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Salary Amount (₹)', prefixText: '₹ '),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: paymentMode,
                  decoration: const InputDecoration(labelText: 'Payment Mode'),
                  items: ['Bank Transfer', 'UPI / Online', 'Cash', 'Cheque']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => paymentMode = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: 'Transaction Note / Ref #', hintText: 'e.g. Txn #987623 / UTR'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
              icon: const Icon(Icons.receipt_long_rounded, size: 16),
              label: const Text('Confirm & Print Slip'),
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text.trim()) ?? defaultSalary;
                final now = DateTime.now();
                final record = {
                  'teacherId': _teacher.teacherId,
                  'teacherName': _teacher.name,
                  'month': selectedMonth,
                  'amount': amt,
                  'mode': paymentMode,
                  'note': noteCtrl.text.trim(),
                  'date': now.toIso8601String(),
                };

                final list = _salaryHistory[_teacher.teacherId] ?? [];
                list.insert(0, record);
                _salaryHistory[_teacher.teacherId] = list;
                _teacherSalaries[_teacher.teacherId] = amt;
                await _saveSalaries();

                Navigator.pop(ctx);
                setState(() {});
                _generateSalarySlipPdf(record);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── OFFICIAL SALARY SLIP PDF WITH STAMP, SIGNATURE, DATE & TIME ─────────────
  Future<void> _generateSalarySlipPdf(Map<String, dynamic> record) async {
    final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
    final pdf = pw.Document();

    pw.MemoryImage? stampImage;
    pw.MemoryImage? sigImage;
    pw.MemoryImage? logoImage;

    try {
      if (settings.schoolStamp != null && settings.schoolStamp!.isNotEmpty) {
        final cleanStamp = await SignatureProcessor.processAndCleanStamp(settings.schoolStamp);
        final stampBytes = await AppUtils.loadAppImageBytes(cleanStamp ?? settings.schoolStamp);
        if (stampBytes != null) stampImage = pw.MemoryImage(stampBytes);
      }
    } catch (_) {
      try {
        final stampBytes = await AppUtils.loadAppImageBytes(settings.schoolStamp);
        if (stampBytes != null) stampImage = pw.MemoryImage(stampBytes);
      } catch (_) {}
    }

    try {
      final sigRaw = settings.rawSignature ?? settings.principalSignature;
      if (sigRaw != null && sigRaw.isNotEmpty) {
        final cleanSig = await SignatureProcessor.processAndCleanSignature(sigRaw, colorMode: 'dark');
        final sigBytes = await AppUtils.loadAppImageBytes(cleanSig ?? sigRaw);
        if (sigBytes != null) sigImage = pw.MemoryImage(sigBytes);
      }
    } catch (_) {
      try {
        final sigRaw = settings.rawSignature ?? settings.principalSignature;
        final sigBytes = await AppUtils.loadAppImageBytes(sigRaw);
        if (sigBytes != null) sigImage = pw.MemoryImage(sigBytes);
      } catch (_) {}
    }

    try {
      final logoBytes = await AppUtils.loadAppImageBytes(settings.logoPath);
      if (logoBytes != null) logoImage = pw.MemoryImage(logoBytes);
    } catch (_) {}

    DateTime recordDate = DateTime.now();
    try {
      if (record['date'] != null) {
        recordDate = DateTime.parse(record['date']);
      }
    } catch (_) {}
    final formattedDateTime = DateFormat('dd MMM yyyy, hh:mm a').format(recordDate);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context ctx) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blueGrey700, width: 1.5),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Row with School Info & Logo
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoImage != null) ...[
                      pw.Container(
                        width: 44,
                        height: 44,
                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                      ),
                      pw.SizedBox(width: 10),
                    ],
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            settings.instituteName.toUpperCase(),
                            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                            textAlign: pw.TextAlign.center,
                          ),
                          if (settings.address.isNotEmpty)
                            pw.Text(
                              settings.address,
                              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                              textAlign: pw.TextAlign.center,
                            ),
                          pw.Text(
                            'Phone: ${settings.mobile} | Email: ${settings.email ?? "N/A"}',
                            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                            textAlign: pw.TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  color: PdfColors.blue50,
                  child: pw.Center(
                    child: pw.Text(
                      'STAFF SALARY PAYMENT VOUCHER / SLIP',
                      style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                    ),
                  ),
                ),
                pw.Divider(thickness: 1, color: PdfColors.blueGrey300),
                pw.SizedBox(height: 4),

                // Key Info Grid
                pw.Row(
                  children: [
                    pw.Expanded(child: _pdfField('Faculty Name:', _teacher.name)),
                    pw.Expanded(child: _pdfField('Teacher ID:', _teacher.teacherId)),
                  ],
                ),
                pw.Row(
                  children: [
                    pw.Expanded(child: _pdfField('Designation:', _teacher.designation ?? 'Teacher')),
                    pw.Expanded(child: _pdfField('Class / Subject:', _teacher.displayAssignedClass)),
                  ],
                ),
                pw.Row(
                  children: [
                    pw.Expanded(child: _pdfField('Salary Month:', record['month'].toString())),
                    pw.Expanded(child: _pdfField('Payment Mode:', record['mode'].toString())),
                  ],
                ),
                pw.Row(
                  children: [
                    pw.Expanded(child: _pdfField('Transaction Ref:', record['note'].toString().isEmpty ? 'N/A' : record['note'].toString())),
                    pw.Expanded(child: _pdfField('Date & Time:', formattedDateTime)),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 1, color: PdfColors.blueGrey300),

                // Amount Row
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('NET SALARY DISBURSED:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                      pw.Text('Rs. ${record['amount']}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Amount in Words: Rupees ${record['amount']} Only',
                  style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey800),
                ),

                pw.Spacer(),

                // Signatures & Stamp Row
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    // Teacher Signature
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(width: 85, height: 0.8, color: PdfColors.grey700),
                        pw.SizedBox(height: 2),
                        pw.Text('Teacher Signature', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                    // Principal Sign & Mohar with dynamic scale & centered alignment
                    (() {
                      final stampScale = (settings.stampScale > 0) ? settings.stampScale : 1.0;
                      final sigScale = (settings.signatureScale > 0) ? settings.signatureScale : 1.0;
                      final stampDim = 54.0 * stampScale;
                      final sigW = 72.0 * sigScale;
                      final sigH = 36.0 * sigScale;
                      final boxW = [stampDim, sigW, 125.0].reduce((a, b) => a > b ? a : b) + 12.0;
                      final boxH = [stampDim, sigH, 52.0].reduce((a, b) => a > b ? a : b) + 6.0;

                      return pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Container(
                            width: boxW,
                            height: boxH,
                            child: pw.Stack(
                              alignment: pw.Alignment.center,
                              children: [
                                if (stampImage != null)
                                  pw.Opacity(
                                    opacity: 0.88,
                                    child: pw.Image(stampImage, width: stampDim, height: stampDim, fit: pw.BoxFit.contain),
                                  ),
                                if (sigImage != null)
                                  pw.Center(
                                    child: pw.Image(sigImage, width: sigW, height: sigH, fit: pw.BoxFit.contain),
                                  ),
                              ],
                            ),
                          ),
                          pw.Container(width: boxW, height: 0.8, color: PdfColors.grey700),
                          pw.SizedBox(height: 2),
                          pw.Text('Director / Principal Sign & Stamp', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        ],
                      );
                    })(),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    final fileName = 'Salary_Slip_${_teacher.name.replaceAll(' ', '_')}_${record['month']}.pdf';
    final pdfBytes = await pdf.save();

    String? savedPath;
    try {
      savedPath = await FileSaver.saveCategorizedFile(
        bytes: pdfBytes,
        filename: fileName,
        category: FileCategory.salarySlips,
        schoolName: settings.instituteName,
      );
    } catch (_) {}

    if (mounted && savedPath != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0F766E),
          content: Text('Salary Slip Saved to: $savedPath', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: fileName,
    );
  }

  static pw.Widget _pdfField(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        children: [
          pw.Text('$label ', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.black), overflow: pw.TextOverflow.clip),
          ),
        ],
      ),
    );
  }

  // ─── BUILD SCREEN ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isClassTeacher = _teacher.assignedClass != null &&
        _teacher.assignedClass!.isNotEmpty &&
        _teacher.assignedClass!.toLowerCase() != 'none';

    return Scaffold(
      backgroundColor: cs.background,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, innerScrolled) => [
          SliverAppBar(
            expandedHeight: 330,
            pinned: true,
            floating: false,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
                tooltip: 'Edit Teacher',
                onPressed: _showEditTeacherSheet,
              ),
              IconButton(
                icon: Icon(_teacher.active ? Icons.block : Icons.check_circle_outline, color: Colors.white),
                tooltip: _teacher.active ? 'Disable Account' : 'Enable Account',
                onPressed: _toggleActive,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (val) {
                  if (val == 'reset') _showResetPasswordDialog();
                  if (val == 'delete') _deleteTeacher();
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'reset',
                    child: Row(
                      children: [
                        Icon(Icons.lock_reset, size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Reset Password'),
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
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E1B4B), AppColors.primary, Color(0xFF4338CA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 48, bottom: 50),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Avatar Photo
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.white,
                            child: ClipOval(
                              child: (_teacher.photoUrl != null && _teacher.photoUrl!.isNotEmpty)
                                  ? AppUtils.buildAppImageWidget(
                                      _teacher.photoUrl,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      placeholder: Center(
                                        child: Text(
                                          _teacher.name.isNotEmpty ? _teacher.name[0].toUpperCase() : 'T',
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        _teacher.name.isNotEmpty ? _teacher.name[0].toUpperCase() : 'T',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Name & Teacher ID
                        Text(
                          _teacher.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Teacher ID: ${_teacher.teacherId}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Badges Row
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _headerBadge(
                                isClassTeacher
                                    ? 'Class Teacher: ${_teacher.displayAssignedClass}'
                                    : 'Subject Teacher',
                                isClassTeacher ? Icons.school : Icons.menu_book,
                                const Color(0xFF10B981),
                              ),
                              const SizedBox(width: 6),
                              if (_teacher.designation != null && _teacher.designation!.isNotEmpty) ...[
                                _headerBadge(
                                  _teacher.designation!,
                                  Icons.badge_outlined,
                                  const Color(0xFF6366F1),
                                ),
                                const SizedBox(width: 6),
                              ],
                              _headerBadge(
                                _teacher.active ? 'Active' : 'Disabled',
                                _teacher.active ? Icons.check_circle : Icons.block,
                                _teacher.active ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: const Color(0xFFFBBF24),
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.65),
              labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
              unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(icon: Icon(Icons.person_outline, size: 16), text: 'Personal'),
                Tab(icon: Icon(Icons.work_outline, size: 16), text: 'Academic'),
                Tab(icon: Icon(Icons.payments_outlined, size: 16), text: 'Salary & Slips'),
                Tab(icon: Icon(Icons.key_outlined, size: 16), text: 'Portal Login'),
                Tab(icon: Icon(Icons.event_available_outlined, size: 16), text: 'Attendance'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPersonalTab(cs),
            _buildAcademicTab(cs),
            _buildSalaryTab(cs),
            _buildCredentialsTab(cs),
            _buildAttendanceTab(cs),
          ],
        ),
      ),
    );
  }

  Widget _headerBadge(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  // ─── TAB 1: PERSONAL INFO ─────────────────────────────────────────────────────
  Widget _buildPersonalTab(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Quick Contact Actions Bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _teacher.mobile.isNotEmpty ? () => _callPhone(_teacher.mobile) : null,
                  icon: const Icon(Icons.phone, size: 16),
                  label: const Text('Call', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _teacher.mobile.isNotEmpty ? () => _openWhatsApp(_teacher.mobile) : null,
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        _cardSection(
          title: 'Personal & Family Details',
          icon: Icons.person_outline,
          color: const Color(0xFF4F46E5),
          cs: cs,
          children: [
            _infoRow('Full Name', _teacher.name, cs),
            _infoRow('Father\'s Name', _teacher.fatherName ?? '—', cs),
            _infoRow('Mother\'s Name', _teacher.motherName ?? '—', cs),
            _infoRow(
              'Date of Birth',
              _teacher.dob != null ? DateFormat('dd MMM yyyy').format(_teacher.dob!) : '—',
              cs,
            ),
            _infoRow('Gender', _teacher.gender ?? 'Male', cs),
            _infoRow('Primary Mobile', _teacher.mobile.isNotEmpty ? _teacher.mobile : '—', cs, copyable: true),
            _infoRow('Alt Mobile', _teacher.alternateMobile ?? '—', cs, copyable: true),
            _infoRow('Aadhaar Card', _teacher.aadhaarNumber ?? '—', cs, copyable: true),
            _buildAadhaarDocTile(cs),
            _infoRow('Residential Address', _teacher.address ?? '—', cs),
          ],
        ),
        const SizedBox(height: 14),

        ElevatedButton.icon(
          onPressed: _showEditTeacherSheet,
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('Edit Teacher Details', style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.surfaceVariant,
            foregroundColor: cs.onSurface,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _deleteTeacher,
          icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
          label: const Text('Delete Teacher Permanently', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.error),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildAadhaarDocTile(ColorScheme cs) {
    final hasDoc = _teacher.aadhaarDocUrl != null && _teacher.aadhaarDocUrl!.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: hasDoc ? () => _showFullDocImage(_teacher.aadhaarDocUrl!, 'Teacher Aadhaar / ID Card') : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 54,
                height: 42,
                color: cs.surfaceContainerHighest,
                child: hasDoc
                    ? AppUtils.buildAppImageWidget(
                        _teacher.aadhaarDocUrl!,
                        width: 54,
                        height: 42,
                        fit: BoxFit.cover,
                        placeholder: const Center(child: Icon(Icons.badge_outlined, size: 20)),
                      )
                    : Icon(Icons.badge_outlined, color: cs.onSurfaceVariant, size: 24),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Aadhaar Document', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: cs.onSurface)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: hasDoc ? AppColors.success.withValues(alpha: 0.15) : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        hasDoc ? 'VERIFIED' : 'NO DOCUMENT',
                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: hasDoc ? AppColors.success : cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  hasDoc ? 'Tap image or view button to view full card' : 'No document uploaded yet',
                  style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (hasDoc)
            IconButton(
              icon: const Icon(Icons.visibility_outlined, size: 18),
              tooltip: 'View Document',
              onPressed: () => _showFullDocImage(_teacher.aadhaarDocUrl!, 'Teacher Aadhaar / ID Card'),
            ),
        ],
      ),
    );
  }

  void _showFullDocImage(String path, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            Flexible(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: AppUtils.buildAppImageWidget(
                  path,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ─── TAB 2: ACADEMIC INFO ─────────────────────────────────────────────────────
  Widget _buildAcademicTab(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _cardSection(
          title: 'Role & Academic Allocation',
          icon: Icons.school_outlined,
          color: const Color(0xFF0284C7),
          cs: cs,
          children: [
            _infoRow('Designation', _teacher.designation ?? 'Faculty / Teacher', cs),
            _infoRow('Assigned Class', _teacher.displayAssignedClass, cs),
            _infoRow('Assigned Section', _teacher.assignedSection ?? 'All Sections', cs),
            _infoRow('Subject Specialization', _teacher.subject ?? 'All Subjects', cs),
            _infoRow('Educational Qualification', _teacher.qualification ?? 'B.Ed, Master Degree', cs),
            _infoRow(
              'Joining Date',
              _teacher.joiningDate != null ? DateFormat('dd MMM yyyy').format(_teacher.joiningDate!) : '—',
              cs,
            ),
          ],
        ),
      ],
    );
  }

  // ─── TAB 3: SALARY & PAYMENT HISTORY & PDF ────────────────────────────────────
  Widget _buildSalaryTab(ColorScheme cs) {
    final curSal = _teacher.salary ?? (_teacherSalaries[_teacher.teacherId] ?? 25000.0);
    final history = _salaryHistory[_teacher.teacherId] ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Monthly Salary Card with "Pay Salary" Action
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF059669), Color(0xFF10B981)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF059669).withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'MONTHLY SALARY RATE',
                    style: TextStyle(
                      color: Color(0xFFD1FAE5),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showPaySalaryDialog,
                    icon: const Icon(Icons.payments_rounded, size: 16),
                    label: const Text('Pay Salary', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF059669),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '₹ ${curSal.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Official compensation rate configured in teacher profile.',
                style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 11.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Salary History List
        _cardSection(
          title: 'Salary Payment History & Slips',
          icon: Icons.history_edu_rounded,
          color: const Color(0xFF4F46E5),
          cs: cs,
          children: [
            if (history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No past salary payments recorded yet.\nClick "Pay Salary" above to record a payment.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              )
            else
              ...history.map((item) {
                final amt = item['amount'] ?? 0;
                final mode = item['mode'] ?? 'Bank Transfer';
                final dateStr = item['date'] != null
                    ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(item['date']))
                    : 'Recent';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF10B981).withOpacity(0.15),
                        child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('₹ $amt Paid', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            Text('$mode | Month: ${item["month"] ?? "Current"}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            Text(dateStr, style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF2563EB)),
                        tooltip: 'Download / Print Slip (Stamp & Sign)',
                        onPressed: () => _generateSalarySlipPdf(item),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ],
    );
  }

  // ─── TAB 4: PORTAL LOGIN CREDENTIALS ─────────────────────────────────────────
  Widget _buildCredentialsTab(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFC7D2FE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Color(0xFF4338CA), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Teacher Portal Access Credentials',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Color(0xFF1E1B4B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Share these login details with the teacher so they can access their dedicated Teacher Dashboard in the app and website.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF374151), height: 1.3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        _cardSection(
          title: 'Login Information',
          icon: Icons.vpn_key_outlined,
          color: const Color(0xFF4338CA),
          cs: cs,
          children: [
            _credentialRow(
              label: 'Teacher ID',
              value: _teacher.teacherId,
              icon: Icons.badge_outlined,
              cs: cs,
              onCopy: () => _copyToClipboard(_teacher.teacherId, 'Teacher ID'),
            ),
            const Divider(height: 16),

            _credentialRow(
              label: 'Login Email Address',
              value: _teacher.authEmail,
              icon: Icons.mail_outline,
              cs: cs,
              onCopy: () => _copyToClipboard(_teacher.authEmail, 'Login Email'),
            ),
            const Divider(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Portal Password',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _showPassword ? (_teacher.password.isNotEmpty ? _teacher.password : '123456') : '••••••••',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                  color: cs.primary,
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                  tooltip: _showPassword ? 'Hide Password' : 'Show Password',
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  color: cs.primary,
                  onPressed: () => _copyToClipboard(_teacher.password.isNotEmpty ? _teacher.password : '123456', 'Password'),
                  tooltip: 'Copy Password',
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showResetPasswordDialog,
                icon: const Icon(Icons.lock_reset, size: 16),
                label: const Text('Reset Password'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  final pass = _teacher.password.isNotEmpty ? _teacher.password : '123456';
                  final text = '🏫 School Teacher Portal Credentials:\n\n'
                      '👤 Name: ${_teacher.name}\n'
                      '🆔 Teacher ID: ${_teacher.teacherId}\n'
                      '📧 Login Email: ${_teacher.authEmail}\n'
                      '🔑 Password: $pass\n\n'
                      'Please keep your credentials safe and login to your teacher portal.';
                  _copyToClipboard(text, 'Complete Credentials');
                },
                icon: const Icon(Icons.share_outlined, size: 16),
                label: const Text('Share Credentials'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── TAB 5: ATTENDANCE & 1-CLICK MARKING ──────────────────────────────────────
  Widget _buildAttendanceTab(ColorScheme cs) {
    if (_loadingAttendance) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalLogs = _attendanceHistory.length;
    final presentCount = _attendanceHistory.values.where((v) => v == 'present').length;
    final absentCount = _attendanceHistory.values.where((v) => v == 'absent').length;
    final leaveCount = _attendanceHistory.values.where((v) => v == 'leave' || v == 'half_day').length;
    final presentPct = totalLogs > 0 ? ((presentCount / totalLogs) * 100).round() : 100;

    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayStatus = _attendanceHistory[todayKey];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ─── 1-CLICK ATTENDANCE FOR TODAY ─────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.7)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Today\'s Attendance (${DateFormat('dd MMM').format(DateTime.now())}):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: cs.onSurface),
                  ),
                  if (todayStatus != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (todayStatus == 'present' ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        todayStatus.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: todayStatus == 'present' ? const Color(0xFF059669) : const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _oneClickAttBtn('P', 'Present', 'present', const Color(0xFF10B981), todayStatus == 'present'),
                  const SizedBox(width: 6),
                  _oneClickAttBtn('A', 'Absent', 'absent', const Color(0xFFEF4444), todayStatus == 'absent'),
                  const SizedBox(width: 6),
                  _oneClickAttBtn('HD', 'Half Day', 'half_day', const Color(0xFFF59E0B), todayStatus == 'half_day'),
                  const SizedBox(width: 6),
                  _oneClickAttBtn('L', 'Leave', 'leave', const Color(0xFF8B5CF6), todayStatus == 'leave'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Attendance Stat Summary Cards
        Row(
          children: [
            Expanded(
              child: _statPill(
                title: 'Attendance Rate',
                value: '$presentPct%',
                subtitle: '$presentCount of $totalLogs days',
                color: const Color(0xFF059669),
                cs: cs,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statPill(
                title: 'Total Absent',
                value: '$absentCount',
                subtitle: '$leaveCount on leave',
                color: const Color(0xFFDC2626),
                cs: cs,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Full Attendance screen button
        OutlinedButton.icon(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TeacherAttendanceScreen()),
            );
            _loadTeacherAttendance();
          },
          icon: const Icon(Icons.calendar_month_outlined, size: 16),
          label: const Text('Open Full School Faculty Attendance Sheet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1.2),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),

        // Attendance History List
        _cardSection(
          title: 'Recent Attendance Logs',
          icon: Icons.history_rounded,
          color: const Color(0xFF2563EB),
          cs: cs,
          children: [
            if (_attendanceHistory.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No daily attendance logged yet for this faculty member.\nUse the 1-click buttons above to record today\'s presence.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              )
            else
              ...(_attendanceHistory.entries.toList()
                    ..sort((a, b) => b.key.compareTo(a.key)))
                  .take(15)
                  .map((entry) {
                final dateStr = entry.key;
                final status = entry.value;

                Color badgeColor;
                String label;
                if (status == 'present') {
                  badgeColor = const Color(0xFF059669);
                  label = 'PRESENT';
                } else if (status == 'absent') {
                  badgeColor = const Color(0xFFDC2626);
                  label = 'ABSENT';
                } else if (status == 'half_day') {
                  badgeColor = const Color(0xFFD97706);
                  label = 'HALF DAY';
                } else {
                  badgeColor = const Color(0xFF7C3AED);
                  label = 'LEAVE';
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 13, color: cs.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: badgeColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ],
    );
  }

  Widget _oneClickAttBtn(String code, String label, String statusKey, Color color, bool isSelected) {
    return Expanded(
      child: InkWell(
        onTap: () => _markTodayAttendance(statusKey),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? color : color.withOpacity(0.3), width: isSelected ? 1.5 : 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                code,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? Colors.white : color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white.withOpacity(0.9) : color.withOpacity(0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── HELPER CARD WIDGETS ─────────────────────────────────────────────────────
  Widget _cardSection({
    required String title,
    required IconData icon,
    required Color color,
    required ColorScheme cs,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: cs.outlineVariant.withOpacity(0.4)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, ColorScheme cs, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: cs.onSurface),
            ),
          ),
          if (copyable && value != '—')
            InkWell(
              onTap: () => _copyToClipboard(value, label),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.copy_rounded, size: 14, color: cs.primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _credentialRow({
    required String label,
    required String value,
    required IconData icon,
    required ColorScheme cs,
    required VoidCallback onCopy,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                  color: cs.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy_rounded, size: 18),
          color: cs.primary,
          onPressed: onCopy,
          tooltip: 'Copy $label',
        ),
      ],
    );
  }

  Widget _statPill({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required ColorScheme cs,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
