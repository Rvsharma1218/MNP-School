import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/signature_helper.dart';
import '../../data/models/settings_model.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/providers.dart';
import '../../data/services/session_service.dart';
import '../auth/pin_lock_screen.dart';
import '../settings/settings_screen.dart';

class TeacherSettingsScreen extends ConsumerStatefulWidget {
  const TeacherSettingsScreen({super.key});

  @override
  ConsumerState<TeacherSettingsScreen> createState() => _TeacherSettingsScreenState();
}

class _TeacherSettingsScreenState extends ConsumerState<TeacherSettingsScreen> {
  StreamSubscription? _teacherStreamSub;
  String? _liveName;
  String? _liveAssignedClass;
  String? _liveAssignedSection;
  String? _liveDesignation;
  String? _liveSubject;
  String? _liveMobile;
  String? _liveEmail;
  String? _teacherDocId;
  String? _liveSignatureUrl;
  bool _isPinConfigured = false;

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

          final sec = data['assignedSection']?.toString().trim();
          final desig = data['designation']?.toString();
          final sub = data['subject']?.toString();
          final mob = data['mobile']?.toString();
          final em = (data['email'] ?? data['authEmail'])?.toString();

          setState(() {
            _liveName = name.isNotEmpty ? name : null;
            _liveAssignedClass = parsedClass.isNotEmpty ? parsedClass : null;
            _liveAssignedSection = (sec != null && sec.isNotEmpty) ? sec : null;
            _liveDesignation = desig;
            _liveSubject = sub;
            _liveMobile = mob;
            _liveEmail = em;
          });
          break;
        }
      }
    });
  }

  Future<void> _checkPinStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString('user_pin');
    if (mounted) {
      setState(() => _isPinConfigured = pin != null && pin.length == 4);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out of your faculty account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await AuthService.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
      }
    }
  }

  void _openSignatureScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherSignatureSubScreen(
          teacherName: _liveName ?? SessionService.instance.teacherName ?? 'Teacher',
          teacherDocId: _teacherDocId,
          initialSignatureUrl: _liveSignatureUrl,
          onSignatureUpdated: (url) {
            setState(() => _liveSignatureUrl = url);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF64748B);
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    final teacherName = _liveName ?? SessionService.instance.teacherName ?? 'Teacher';
    final email = _liveEmail ?? FirebaseAuth.instance.currentUser?.email ?? '';
    final teacherId = SessionService.instance.teacherId ?? '';
    final assignedClass = _liveAssignedClass ?? SessionService.instance.assignedClass ?? '';
    final assignedSec = _liveAssignedSection ?? SessionService.instance.assignedSection ?? '';
    final isClassTeacher = assignedClass.isNotEmpty && assignedClass.toLowerCase() != 'none';
    final displayClass = isClassTeacher ? (assignedClass.startsWith('Class') ? assignedClass : 'Class $assignedClass') : 'Subject Teacher';
    final hasSignature = _liveSignatureUrl != null && _liveSignatureUrl!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Settings & Preferences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Log out',
            onPressed: _logout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // ─── TEACHER PROFILE HEADER (Identical to Principal Profile Card) ───
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [AppColors.primary, const Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    teacherName.isNotEmpty ? teacherName[0].toUpperCase() : 'T',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              teacherName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isClassTeacher ? const Color(0xFF10B981) : Colors.white24,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isClassTeacher ? 'CLASS TEACHER' : 'FACULTY',
                              style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        email.isNotEmpty ? email : (teacherId.isNotEmpty ? 'ID: $teacherId' : 'MNP School Faculty'),
                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$displayClass${assignedSec.isNotEmpty ? " (Sec $assignedSec)" : ""}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ─── CARD 1: APP PREFERENCES & SECURITY ───
          const Text(
            'PREFERENCES & SECURITY',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                _buildMenuTile(
                  title: 'App Appearance & Theme',
                  subtitle: 'Switch between Light, Dark, or System mode',
                  icon: Icons.palette_rounded,
                  iconColor: const Color(0xFFD97706),
                  iconBg: const Color(0xFFFEF3C7),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AppearanceSettingsScreen()),
                  ),
                ),
                const Divider(height: 1, indent: 64),
                _buildMenuTile(
                  title: 'Language (भाषा)',
                  subtitle: 'English, हिन्दी (App Display Language)',
                  icon: Icons.translate_rounded,
                  iconColor: const Color(0xFF0284C7),
                  iconBg: const Color(0xFFE0F2FE),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LanguageSettingsScreen()),
                  ),
                ),
                const Divider(height: 1, indent: 64),
                _buildMenuTile(
                  title: 'Security PIN & App Lock',
                  subtitle: _isPinConfigured ? '4-Digit PIN configured (Tap to change PIN)' : 'Set 4-Digit PIN to protect marks & attendance',
                  icon: Icons.lock_rounded,
                  iconColor: const Color(0xFFE11D48),
                  iconBg: const Color(0xFFFFE4E6),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SecurityPinSettingsScreen()),
                  ),
                ),
                const Divider(height: 1, indent: 64),
                _buildMenuTile(
                  title: 'Class Teacher Digital Signature',
                  subtitle: hasSignature ? 'Active on Student Report Cards & Marksheets' : 'Upload signature for automatic marksheet printing',
                  icon: Icons.draw_rounded,
                  iconColor: const Color(0xFF7C3AED),
                  iconBg: const Color(0xFFEDE9FE),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: hasSignature ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      hasSignature ? 'ACTIVE' : 'MISSING',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: hasSignature ? const Color(0xFF059669) : const Color(0xFFB45309),
                      ),
                    ),
                  ),
                  onTap: _openSignatureScreen,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ─── CARD 2: HELP & SUPPORT ───
          const Text(
            'HELP & SUPPORT',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                _buildMenuTile(
                  title: 'Help and feedback',
                  subtitle: 'FAQs, Send feedback, Report problem & helpline contact',
                  icon: Icons.help_outline_rounded,
                  iconColor: const Color(0xFF0D9488),
                  iconBg: const Color(0xFFCCFBF1),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HelpSupportSettingsScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ─── CARD 3: ACCOUNT & LOGOUT ───
          const Text(
            'ACCOUNT',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                _buildMenuTile(
                  title: 'Log out',
                  subtitle: 'Sign out of your faculty account on this device',
                  icon: Icons.logout_rounded,
                  iconColor: AppColors.error,
                  iconBg: const Color(0xFFFEE2E2),
                  onTap: _logout,
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          Center(
            child: Text(
              'MNP School • Faculty Portal v2.0.8',
              style: TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11,
          color: isDark ? Colors.white60 : const Color(0xFF64748B),
        ),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
      onTap: onTap,
    );
  }
}

// ─── TEACHER DIGITAL SIGNATURE SUB-SCREEN ────────────────────────────────────

class TeacherSignatureSubScreen extends StatefulWidget {
  final String teacherName;
  final String? teacherDocId;
  final String? initialSignatureUrl;
  final ValueChanged<String?> onSignatureUpdated;

  const TeacherSignatureSubScreen({
    super.key,
    required this.teacherName,
    this.teacherDocId,
    this.initialSignatureUrl,
    required this.onSignatureUpdated,
  });

  @override
  State<TeacherSignatureSubScreen> createState() => _TeacherSignatureSubScreenState();
}

class _TeacherSignatureSubScreenState extends State<TeacherSignatureSubScreen> {
  String? _signatureUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _signatureUrl = widget.initialSignatureUrl;
  }

  Future<void> _pickAndProcess(ImageSource source) async {
    final cleanSig = await SignatureHelper.pickCropAndCleanSignature(context, source);
    if (cleanSig == null) return;

    setState(() => _signatureUrl = cleanSig);
    await _saveToFirestore(cleanSig);
  }

  Future<void> _saveToFirestore(String? signature) async {
    final schoolId = SessionService.instance.activeSchoolId.isNotEmpty
        ? SessionService.instance.activeSchoolId
        : SessionService.instance.activeSchoolUid;

    if (widget.teacherDocId != null && widget.teacherDocId!.isNotEmpty && schoolId.isNotEmpty) {
      setState(() => _saving = true);
      try {
        await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('teachers')
            .doc(widget.teacherDocId)
            .update({
          'signatureUrl': signature ?? '',
          'teacherSignature': signature ?? '',
          'signature': signature ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        widget.onSignatureUpdated(signature);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(signature != null ? '✓ Digital signature saved & background removed!' : 'Signature removed'),
              backgroundColor: signature != null ? Colors.green : Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
  }

  Future<void> _removeSignature() async {
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
    setState(() => _signatureUrl = null);
    await _saveToFirestore(null);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasSig = _signatureUrl != null && _signatureUrl!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Digital Signature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.draw_rounded, color: Color(0xFF7C3AED), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Class Teacher Signature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(
                            hasSig ? 'Active on Student Report Cards & Marksheets' : 'Not uploaded (blank on marksheets)',
                            style: TextStyle(
                              fontSize: 11,
                              color: hasSig ? const Color(0xFF059669) : Colors.orange.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: hasSig ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        hasSig ? 'ACTIVE' : 'MISSING',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: hasSig ? const Color(0xFF059669) : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (hasSig) ...[
                  SignatureHelper.buildSignaturePreviewBox(
                    context: context,
                    signatureUrl: _signatureUrl,
                    teacherName: widget.teacherName,
                    onCropEdit: () => _pickAndProcess(ImageSource.gallery),
                    onRemove: _removeSignature,
                  ),
                  const SizedBox(height: 14),
                ],

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : () => _pickAndProcess(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined, size: 16),
                        label: Text(hasSig ? 'Change (Gallery)' : 'Upload from Gallery', style: const TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF7C3AED),
                          side: const BorderSide(color: Color(0xFF7C3AED)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : () => _pickAndProcess(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined, size: 16),
                        label: const Text('Capture Camera', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_saving) ...[
                  const SizedBox(height: 12),
                  const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome, color: Color(0xFF059669), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Automatic Background Removal & High Precision Ink',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'White paper par signature karke camera ya gallery se upload karein. Crop tool se signature select karein, background automatically remove ho jayega aur transparent marksheet print ke liye save ho jayega.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF047857), height: 1.3),
                      ),
                    ],
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
