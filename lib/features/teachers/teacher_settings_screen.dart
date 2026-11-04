import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/signature_processor.dart';
import '../../data/models/settings_model.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/providers.dart';
import '../../data/services/session_service.dart';
import '../auth/pin_lock_screen.dart';

class TeacherSettingsScreen extends ConsumerStatefulWidget {
  const TeacherSettingsScreen({super.key});

  @override
  ConsumerState<TeacherSettingsScreen> createState() => _TeacherSettingsScreenState();
}

class _TeacherSettingsScreenState extends ConsumerState<TeacherSettingsScreen> {
  StreamSubscription? _teacherStreamSub;
  String? _liveName;
  String? _liveAssignedClass;
  String? _liveDesignation;
  String? _liveSubject;
  String? _liveMobile;
  String? _liveEmail;
  String? _teacherDocId;
  String? _liveSignatureUrl;
  bool _isPinConfigured = false;
  int _expandedFaqIndex = -1;

  @override
  void initState() {
    super.initState();
    _startRealtimeTeacherListener();
    _checkPinStatus();
  }

  @override
  void dispose() {
    _teacherStreamSub?.cancel();
    super.dispose();
  }

  void _startRealtimeTeacherListener() {
    final schoolId = SessionService.instance.activeSchoolId.isNotEmpty
        ? SessionService.instance.activeSchoolId
        : SessionService.instance.activeSchoolUid;
    final teacherId = SessionService.instance.teacherId;
    final teacherName = SessionService.instance.teacherName;
    if (schoolId.isEmpty) return;

    _teacherStreamSub = FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolId)
        .collection('teachers')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      for (final doc in snap.docs) {
        final data = doc.data();
        final tId = (data['teacherId'] ?? doc.id).toString().trim();
        final authUid = (data['authUid'] ?? '').toString().trim();
        final docId = doc.id.trim();
        final dName = (data['name'] ?? '').toString().trim();

        final matchId = teacherId != null && teacherId.isNotEmpty && (
            tId.toLowerCase() == teacherId.toLowerCase() ||
            authUid.toLowerCase() == teacherId.toLowerCase() ||
            docId.toLowerCase() == teacherId.toLowerCase()
        );
        final matchName = teacherName != null && teacherName.isNotEmpty &&
            dName.toLowerCase() == teacherName.toLowerCase();

        if (matchId || matchName) {
          _teacherDocId = doc.id;
          final sig = (data['signatureUrl'] ?? data['teacherSignature'] ?? data['signature'])?.toString();
          if (sig != null && sig.trim().isNotEmpty) {
            _liveSignatureUrl = sig.trim();
          }
          final name = dName;

          String parsedClass = '';
          final rawCls = data['assignedClass'];
          if (rawCls is String && rawCls.trim().isNotEmpty) {
            parsedClass = rawCls.trim();
          } else if (rawCls is List && rawCls.isNotEmpty) {
            parsedClass = rawCls.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).join(', ');
          }

          if (parsedClass.isEmpty) {
            final rawList = data['assignedClasses'];
            if (rawList is List && rawList.isNotEmpty) {
              parsedClass = rawList.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).join(', ');
            } else if (rawList is String && rawList.trim().isNotEmpty) {
              parsedClass = rawList.trim();
            }
          }

          final designation = (data['designation'] ?? '').toString().trim();
          final subject = (data['subject'] ?? data['subjects'] ?? '').toString().trim();
          final mobile = (data['mobile'] ?? '').toString().trim();
          final email = (data['authEmail'] ?? data['email'] ?? '').toString().trim();

          setState(() {
            if (name.isNotEmpty) _liveName = name;
            if (parsedClass.isNotEmpty) _liveAssignedClass = parsedClass;
            if (designation.isNotEmpty) _liveDesignation = designation;
            if (subject.isNotEmpty) _liveSubject = subject;
            if (mobile.isNotEmpty) _liveMobile = mobile;
            if (email.isNotEmpty) _liveEmail = email;
          });

          if (parsedClass.isNotEmpty) {
            SessionService.instance.updateTeacherAssignedClass(parsedClass, newName: name.isNotEmpty ? name : null);
          }
          break;
        }
      }
    }, onError: (_) {});
  }

  Future<void> _checkPinStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final p = prefs.getString('app_pin') ?? '';
      final isSet = prefs.getBool('app_pin_set') ?? (p.isNotEmpty);
      if (mounted) {
        setState(() => _isPinConfigured = isSet && p.isNotEmpty);
      }
    } catch (_) {}
  }

  Future<void> _showChangePinDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final currentSavedPin = prefs.getString('app_pin') ?? '';
    final isPinSet = prefs.getBool('app_pin_set') ?? (currentSavedPin.isNotEmpty);

    final currentPinCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.lock_reset_rounded, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Change Screen PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isPinSet) ...[
                    const Text('Current 4-Digit PIN:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: currentPinCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: 'Enter current PIN',
                        counterText: '',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text('New 4-Digit PIN:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: newPinCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: 'Enter 4-digit PIN',
                      counterText: '',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Confirm New PIN:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: confirmPinCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: 'Re-enter 4-digit PIN',
                      counterText: '',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                onPressed: () async {
                  if (isPinSet && currentPinCtrl.text.trim() != currentSavedPin) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Current PIN does not match!'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  final newP = newPinCtrl.text.trim();
                  final confP = confirmPinCtrl.text.trim();
                  if (newP.length != 4) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PIN must be exactly 4 digits.'), backgroundColor: Colors.orange),
                    );
                    return;
                  }
                  if (newP != confP) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('New PIN and Confirm PIN do not match.'), backgroundColor: Colors.red),
                    );
                    return;
                  }

                  await prefs.setString('app_pin', newP);
                  await prefs.setBool('app_pin_set', true);
                  if (ctx.mounted) Navigator.pop(ctx);

                  if (mounted) {
                    setState(() => _isPinConfigured = true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✓ 4-Digit Screen PIN saved successfully!'), backgroundColor: Colors.green),
                    );
                  }
                },
                child: const Text('Save PIN'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _lockScreenNow() async {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PinLockScreen()),
    );
  }

  Future<void> _uploadTeacherSignature() async {
    final schoolId = SessionService.instance.activeSchoolId.isNotEmpty
        ? SessionService.instance.activeSchoolId
        : SessionService.instance.activeSchoolUid;
    if (schoolId.isEmpty) return;

    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: const Text('Take Photo of Signature (कैमरा)'),
              subtitle: const Text('Sign on plain white paper & capture'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('Choose from Gallery (गैलरी)'),
              subtitle: const Text('Select image from device storage'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Processing signature & cleaning background...'), duration: Duration(seconds: 1)),
    );

    final cleanSig = await SignatureProcessor.processAndCleanSignature(picked.path, colorMode: 'dark');
    if (cleanSig == null || cleanSig.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not process signature. Please try again with clear paper.')),
        );
      }
      return;
    }

    setState(() => _liveSignatureUrl = cleanSig);

    if (_teacherDocId != null && _teacherDocId!.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('teachers')
            .doc(_teacherDocId)
            .update({
          'signatureUrl': cleanSig,
          'teacherSignature': cleanSig,
          'signature': cleanSig,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('[TeacherSettings] signature save error: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Digital signature saved! It will appear on class marksheets.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _removeTeacherSignature() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Signature?'),
        content: const Text('Are you sure you want to remove your digital signature from marksheets?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final schoolId = SessionService.instance.activeSchoolId.isNotEmpty
        ? SessionService.instance.activeSchoolId
        : SessionService.instance.activeSchoolUid;

    setState(() => _liveSignatureUrl = null);

    if (_teacherDocId != null && _teacherDocId!.isNotEmpty && schoolId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('teachers')
            .doc(_teacherDocId)
            .update({
          'signatureUrl': '',
          'teacherSignature': '',
          'signature': '',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signature removed from profile'), backgroundColor: Colors.orange),
      );
    }
  }

  Future<void> _openWhatsAppHelp(String teacherName, String schoolName, SettingsModel settings) async {
    final cleanPhone = settings.mobile.replaceAll(RegExp(r'[^0-9]'), '');
    final effectivePhone = cleanPhone.isNotEmpty ? cleanPhone : '8603481865';
    final targetNumber = effectivePhone.startsWith('91') && effectivePhone.length > 10
        ? effectivePhone
        : '91$effectivePhone';

    final msg = Uri.encodeComponent(
      'Hello Support Team, I am faculty member $teacherName from $schoolName. I need assistance with the school app.',
    );
    final url = Uri.parse('https://wa.me/$targetNumber?text=$msg');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _callHelpline(SettingsModel settings) async {
    final cleanPhone = settings.mobile.replaceAll(RegExp(r'[^0-9]'), '');
    final effectivePhone = cleanPhone.isNotEmpty ? cleanPhone : '8603481865';
    final url = Uri.parse('tel:$effectivePhone');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    } catch (_) {}
  }

  Future<void> _emailSupport() async {
    final url = Uri.parse('mailto:support@mnpschool.edu?subject=Teacher%20App%20Support%20Request');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    } catch (_) {}
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out? You will need your credentials to sign in again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await AuthService.instance.signOut();
    } finally {
      await SessionService.instance.clear();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (r) => false);
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 22),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCardGroup(BuildContext context, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildMenuTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing
              else
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? Colors.white24 : const Color(0xFF94A3B8),
                ),
            ],
          ),
        ),
      ),
    );
  }


  // ─── TEACHER FEEDBACK DIALOG ──────────────────────────────────────────────
  void _showTeacherFeedbackDialog(BuildContext context) {
    int rating = 5;
    String category = 'General Feedback';
    final commentCtrl = TextEditingController();
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                ),
                const SizedBox(width: 10),
                const Text('Send App Feedback', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rate your experience:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starNum = index + 1;
                      return IconButton(
                        icon: Icon(
                          starNum <= rating ? Icons.star_rounded : Icons.star_border_rounded,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () => setDlgState(() => rating = starNum),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  const Text('Category:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: category,
                    isDense: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'General Feedback', child: Text('General Feedback')),
                      DropdownMenuItem(value: 'Marks & Results Desk', child: Text('Marks & Results Desk')),
                      DropdownMenuItem(value: 'Student Attendance', child: Text('Student Attendance')),
                      DropdownMenuItem(value: 'App Speed & Performance', child: Text('App Speed & Performance')),
                      DropdownMenuItem(value: 'Feature Suggestion', child: Text('Feature Suggestion')),
                    ],
                    onChanged: (val) => setDlgState(() => category = val ?? 'General Feedback'),
                  ),
                  const SizedBox(height: 12),
                  const Text('Your Comments / Feedback:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: commentCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Share your thoughts, suggestions or experience...',
                      hintStyle: const TextStyle(fontSize: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: submitting
                    ? null
                    : () async {
                        setDlgState(() => submitting = true);
                        final schoolId = SessionService.instance.activeSchoolId.isNotEmpty
                            ? SessionService.instance.activeSchoolId
                            : SessionService.instance.activeSchoolUid;
                        final teacherName = SessionService.instance.teacherName ?? 'Teacher';

                        try {
                          await FirebaseFirestore.instance
                              .collection('schools')
                              .doc(schoolId)
                              .collection('feedback')
                              .add({
                            'rating': rating,
                            'category': category,
                            'comments': commentCtrl.text.trim(),
                            'submittedBy': teacherName,
                            'role': 'teacher',
                            'schoolId': schoolId,
                            'createdAt': FieldValue.serverTimestamp(),
                          });

                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✓ Thank you! Feedback submitted successfully.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setDlgState(() => submitting = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                child: submitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── TEACHER REPORT BUG / PROBLEM DIALOG ──────────────────────────────────
  void _showReportBugDialog(BuildContext context) {
    String category = 'Marks & Results';
    final descCtrl = TextEditingController();
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bug_report_rounded, color: Colors.red, size: 24),
                ),
                const SizedBox(width: 10),
                const Text('Report a Problem / Bug', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Issue Category:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: category,
                    isDense: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Marks & Results', child: Text('Marks & Results Desk')),
                      DropdownMenuItem(value: 'Student Attendance', child: Text('Student Attendance')),
                      DropdownMenuItem(value: 'Class Allocation / Role', child: Text('Class Allocation / Role')),
                      DropdownMenuItem(value: 'ID Card / Admit Card', child: Text('ID Card / Admit Card')),
                      DropdownMenuItem(value: 'Screen Lock / PIN', child: Text('Screen Lock / PIN')),
                      DropdownMenuItem(value: 'App Crash / Lag', child: Text('App Crash / Lag')),
                      DropdownMenuItem(value: 'Other Issue', child: Text('Other Issue')),
                    ],
                    onChanged: (val) => setDlgState(() => category = val ?? 'Marks & Results'),
                  ),
                  const SizedBox(height: 12),
                  const Text('Describe the problem in detail:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: descCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'What went wrong? E.g., Mark sheet error on Class 5...',
                      hintStyle: const TextStyle(fontSize: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Our technical team will review this report and fix the issue.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: submitting
                    ? null
                    : () async {
                        if (descCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please describe the problem')),
                          );
                          return;
                        }
                        setDlgState(() => submitting = true);
                        final schoolId = SessionService.instance.activeSchoolId.isNotEmpty
                            ? SessionService.instance.activeSchoolId
                            : SessionService.instance.activeSchoolUid;
                        final teacherName = SessionService.instance.teacherName ?? 'Teacher';

                        try {
                          await FirebaseFirestore.instance
                              .collection('schools')
                              .doc(schoolId)
                              .collection('bug_reports')
                              .add({
                            'category': category,
                            'description': descCtrl.text.trim(),
                            'reportedBy': teacherName,
                            'role': 'teacher',
                            'schoolId': schoolId,
                            'status': 'open',
                            'createdAt': FieldValue.serverTimestamp(),
                          });

                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✓ Problem report sent to technical team. Thank you!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setDlgState(() => submitting = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                child: submitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Send Report'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── THEME & LANGUAGE SECTION ─────────────────────────────────────────────
  Widget _buildThemeAndLanguageSection(BuildContext context, SettingsModel settings) {
    final currentLang = ref.watch(appLanguageProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('DISPLAY & PREFERENCES (थीम एवं भाषा)'),
        _buildCardGroup(context, [
          // Theme Selector
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.palette_outlined, color: Color(0xFF6366F1), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Theme Mode (ऐप का रंग)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          SizedBox(height: 2),
                          Text('Choose Light, Dark or System Default', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildChoiceChip(
                        label: '☀️ Light',
                        selected: themeMode == ThemeMode.light,
                        onTap: () => ref.read(themeModeProvider.notifier).setMode('light'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildChoiceChip(
                        label: '🌙 Dark',
                        selected: themeMode == ThemeMode.dark,
                        onTap: () => ref.read(themeModeProvider.notifier).setMode('dark'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildChoiceChip(
                        label: '⚙️ System',
                        selected: themeMode == ThemeMode.system,
                        onTap: () => ref.read(themeModeProvider.notifier).setMode('system'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Language Selector
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.language_rounded, color: Color(0xFF0D9488), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('App Language (भाषा)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          SizedBox(height: 2),
                          Text('Choose English, हिंदी or Hinglish', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildChoiceChip(
                        label: '🇬🇧 English',
                        selected: currentLang == 'en',
                        onTap: () => ref.read(appLanguageProvider.notifier).setLanguage('en'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildChoiceChip(
                        label: '🇮🇳 हिंदी',
                        selected: currentLang == 'hi',
                        onTap: () => ref.read(appLanguageProvider.notifier).setLanguage('hi'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildChoiceChip(
                        label: '🔤 Hinglish',
                        selected: currentLang == 'hinglish',
                        onTap: () => ref.read(appLanguageProvider.notifier).setLanguage('hinglish'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? const Color(0xFF1D4ED8) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final session = SessionService.instance;

    final teacherName = _liveName ?? session.teacherName ?? 'Teacher';
    final designation = _liveDesignation ?? 'Faculty Member';
    final subject = _liveSubject ?? 'All Subjects';
    final mobile = _liveMobile ?? '—';
    final email = _liveEmail ?? '${teacherName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}.${(session.teacherId ?? 't001').toLowerCase()}@faculty';

    final effectiveAssignedClass = (_liveAssignedClass != null && _liveAssignedClass!.isNotEmpty)
        ? _liveAssignedClass!
        : (session.assignedClass?.isNotEmpty == true
            ? session.assignedClass!
            : (session.hasAllClassesAccess ? 'All Classes' : 'All Classes'));

    final hasSignature = _liveSignatureUrl != null && _liveSignatureUrl!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Teacher Settings & Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: settingsAsync.when(
        data: (settings) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            // ─── HEADER IDENTITY CARD (PRINCIPAL STYLE) ───
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white30, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            teacherName.isNotEmpty ? teacherName[0].toUpperCase() : 'T',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              teacherName,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$designation • ID: ${session.teacherId ?? "TCH-001"}',
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white38),
                        ),
                        child: Text(
                          'Session: ${settings.currentSession.isNotEmpty ? settings.currentSession : "2026-27"}',
                          style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.school_rounded, size: 16, color: Color(0xFFFBBF24)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Class Teacher: $effectiveAssignedClass ($subject)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── SECTION 1: ACADEMIC & CLASS DUTIES ───
            _buildSectionHeader('ACADEMIC & CLASS DUTIES (कक्षा एवं शैक्षणिक कार्य)'),
            _buildCardGroup(context, [
              _buildMenuTile(
                context: context,
                title: 'Class Promotion Desk',
                subtitle: 'Promote assigned class students to next academic session with 1-click',
                icon: Icons.upgrade_rounded,
                iconColor: const Color(0xFF059669),
                iconBg: const Color(0xFFD1FAE5),
                onTap: () => Navigator.pushNamed(context, AppRoutes.promoteStudents),
              ),
              const Divider(height: 1, indent: 64),
              _buildMenuTile(
                context: context,
                title: 'Assigned Classes & Subjects',
                subtitle: 'Classes: $effectiveAssignedClass • Specialization: $subject',
                icon: Icons.menu_book_rounded,
                iconColor: const Color(0xFF2563EB),
                iconBg: const Color(0xFFDBEAFE),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('ASSIGNED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                ),
                onTap: null,
              ),
              const Divider(height: 1, indent: 64),
              _buildMenuTile(
                context: context,
                title: 'Faculty Account ID & Email',
                subtitle: email,
                icon: Icons.badge_rounded,
                iconColor: const Color(0xFF7C3AED),
                iconBg: const Color(0xFFEDE9FE),
                trailing: Text(mobile != '—' ? mobile : (session.teacherId ?? ''), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ),
            ]),

            // ─── SECTION 2: DIGITAL CREDENTIALS & SIGNATURE ───
            _buildSectionHeader('DIGITAL SIGNATURE & CREDENTIALS (हस्ताक्षर एवं डिजिटल पहचान)'),
            _buildCardGroup(context, [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE9FE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.draw_rounded, color: Color(0xFF7C3AED), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Class Teacher Signature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(
                                hasSignature ? 'Active on Student Report Cards & Marksheets' : 'Not uploaded (blank on marksheets)',
                                style: TextStyle(fontSize: 11.5, color: hasSignature ? const Color(0xFF059669) : Colors.orange.shade800),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: hasSignature ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            hasSignature ? 'ACTIVE' : 'MISSING',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: hasSignature ? const Color(0xFF059669) : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (hasSignature) ...[
                      Container(
                        height: 75,
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Center(
                          child: Image.memory(
                            base64Decode(_liveSignatureUrl!.contains(',')
                                ? _liveSignatureUrl!.split(',').last
                                : _liveSignatureUrl!),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Text('Signature Preview Error', style: TextStyle(color: Colors.red, fontSize: 11)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _uploadTeacherSignature,
                            icon: const Icon(Icons.upload_file_rounded, size: 16),
                            label: Text(hasSignature ? 'Change Signature' : 'Upload Signature', style: const TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF7C3AED),
                              side: const BorderSide(color: Color(0xFF7C3AED)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        if (hasSignature) ...[
                          const SizedBox(width: 10),
                          TextButton.icon(
                            onPressed: _removeTeacherSignature,
                            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                            label: const Text('Remove', style: TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ]),

            // ─── SECTION 3: SECURITY & APP PREFERENCES ───
            _buildSectionHeader('SECURITY & SCREEN ACCESS (सुरक्षा एवं स्क्रीन लॉक)'),
            _buildCardGroup(context, [
              _buildMenuTile(
                context: context,
                title: 'Screen Security PIN',
                subtitle: _isPinConfigured ? '4-Digit PIN configured (Tap to update PIN)' : 'Set 4-Digit PIN to protect student marks & attendance',
                icon: Icons.pin_rounded,
                iconColor: const Color(0xFFF59E0B),
                iconBg: const Color(0xFFFEF3C7),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _isPinConfigured ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _isPinConfigured ? 'PROTECTED' : 'NOT SET',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _isPinConfigured ? const Color(0xFF059669) : const Color(0xFFDC2626),
                    ),
                  ),
                ),
                onTap: _showChangePinDialog,
              ),
              const Divider(height: 1, indent: 64),
              _buildMenuTile(
                context: context,
                title: 'Lock Screen Now',
                subtitle: 'Instantly lock app to prevent unauthorized access in classroom',
                icon: Icons.lock_clock_rounded,
                iconColor: const Color(0xFF6366F1),
                iconBg: const Color(0xFFEEF2FF),
                onTap: _lockScreenNow,
              ),
            ]),

            // ─── DISPLAY & PREFERENCES (THEME & LANGUAGE) ───
            _buildThemeAndLanguageSection(context, settings),

            // ─── SECTION 4: HELP DESK & SUPPORT ───
            _buildSectionHeader('HELP & SUPPORT DESK (सहायता एवं हेल्पलाइन)'),
            _buildCardGroup(context, [
              _buildMenuTile(
                context: context,
                title: 'WhatsApp Faculty Help Desk',
                subtitle: 'Direct WhatsApp chat with pre-filled teacher & school credentials',
                icon: Icons.chat_rounded,
                iconColor: const Color(0xFF10B981),
                iconBg: const Color(0xFFD1FAE5),
                onTap: () => _openWhatsAppHelp(teacherName, settings.schoolName, settings),
              ),
              const Divider(height: 1, indent: 64),
              _buildMenuTile(
                context: context,
                title: 'Call Technical Helpline',
                subtitle: 'Helpline: ${settings.mobile.isNotEmpty ? settings.mobile : "8603481865"} (School Admin & Support)',
                icon: Icons.phone_in_talk_rounded,
                iconColor: const Color(0xFF0284C7),
                iconBg: const Color(0xFFE0F2FE),
                onTap: () => _callHelpline(settings),
              ),
              const Divider(height: 1, indent: 64),
              _buildMenuTile(
                context: context,
                title: 'Send App Feedback (फीडबैक दें)',
                subtitle: 'Rate the app & suggest features to principal / admin',
                icon: Icons.rate_review_outlined,
                iconColor: const Color(0xFFF59E0B),
                iconBg: const Color(0xFFFEF3C7),
                onTap: () => _showTeacherFeedbackDialog(context),
              ),
              const Divider(height: 1, indent: 64),
              _buildMenuTile(
                context: context,
                title: 'Report a Problem / Bug (समस्या दर्ज करें)',
                subtitle: 'Submit an issue to technical support team for fast resolution',
                icon: Icons.bug_report_outlined,
                iconColor: const Color(0xFFEF4444),
                iconBg: const Color(0xFFFEE2E2),
                onTap: () => _showReportBugDialog(context),
              ),
              const Divider(height: 1, indent: 64),
              _buildMenuTile(
                context: context,
                title: 'Official Email Support',
                subtitle: 'support@mnpschool.edu',
                icon: Icons.alternate_email_rounded,
                iconColor: const Color(0xFFEA580C),
                iconBg: const Color(0xFFFFEDD5),
                onTap: _emailSupport,
              ),
            ]),

            // ─── FAQ ACCORDION ───
            _buildSectionHeader('TEACHER FAQS & GUIDES (सामान्य प्रश्न एवं सहायता)'),
            _buildCardGroup(context, [
              _buildFaqItem(
                index: 0,
                question: 'Pre-Primary classes ke direct grades kaise enter karein?',
                answer: 'Nursery se Balvatika tak mark entry open karte hi "Grade Entry (A+, A, B, etc.)" toggle automatic on rehta hai. Aap direct chips par tap karke grades assign kar sakte hain.',
              ),
              const Divider(height: 1),
              _buildFaqItem(
                index: 1,
                question: 'Oral (मौखिक) subjects ke marks kaise daalein?',
                answer: 'Mark Entry Desk par subject category selector mein "Oral (🗣️)" choose karein, ya Detailed Mode on karke "Oral" column mein alag se numbers daalein.',
              ),
              const Divider(height: 1),
              _buildFaqItem(
                index: 2,
                question: 'Mera digital signature marksheet par kaise dikhega?',
                answer: 'Upar "Class Teacher Signature" section se camera ya gallery se plain white paper par kiya signature upload karein. Marksheet generate hone par "CLASS TEACHER SIGN" ke upar automatic print hoga.',
              ),
              const Divider(height: 1),
              _buildFaqItem(
                index: 3,
                question: 'Students ko next session mein promote kaise karein?',
                answer: 'Upar "Academic & Class Duties" ke andar "Class Promotion Desk" par tap karein. Wahan apni assigned class choose karke 1-tap promote kar sakte hain.',
              ),
            ]),

            // ─── SECTION 5: SYSTEM INFO & LOGOUT ───
            _buildSectionHeader('SYSTEM & LOGOUT (सिस्टम एवं लॉगआउट)'),
            _buildCardGroup(context, [
              _buildMenuTile(
                context: context,
                title: 'MNP School App Version',
                subtitle: 'v2.0.6 (Build 2013) • High-Speed Resumable Engine',
                icon: Icons.system_update_alt_rounded,
                iconColor: const Color(0xFF64748B),
                iconBg: const Color(0xFFF1F5F9),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('UP TO DATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                ),
                onTap: null,
              ),
              const Divider(height: 1, indent: 64),
              _buildMenuTile(
                context: context,
                title: 'Sign Out Account',
                subtitle: 'Securely logout from this mobile device',
                icon: Icons.logout_rounded,
                iconColor: const Color(0xFFDC2626),
                iconBg: const Color(0xFFFEE2E2),
                onTap: () => _logout(context),
              ),
            ]),

            const SizedBox(height: 30),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading settings: $e')),
      ),
    );
  }

  Widget _buildFaqItem({required int index, required String question, required String answer}) {
    final isExpanded = _expandedFaqIndex == index;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        initiallyExpanded: isExpanded,
        onExpansionChanged: (val) {
          setState(() {
            _expandedFaqIndex = val ? index : -1;
          });
        },
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: Text(
              answer,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
