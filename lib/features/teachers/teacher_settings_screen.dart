import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/utils/signature_processor.dart';
import '../auth/pin_lock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/providers.dart';
import '../../data/services/session_service.dart';
import '../../widgets/common_widgets.dart';

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
    final schoolId = SessionService.instance.activeSchoolId;
    final teacherId = SessionService.instance.teacherId;
    final teacherName = SessionService.instance.teacherName;
    if (schoolId.isEmpty) return;

    // Listen to real-time teacher profile updates from Firestore
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

          // Parse assigned class from both string and list formats
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
    }, onError: (e) {
      debugPrint('[TeacherSettings] stream note: $e');
    });
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out? You will need to sign in again to access your classes.'),
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

  Widget _buildCard(BuildContext context, String title, IconData icon, List<Widget> children, {Widget? trailing}) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            if (trailing != null) ...[
              const Spacer(),
              trailing,
            ],
          ]),
          const Divider(height: 24),
          ...children,
        ]),
      ),
    );
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
                      const SnackBar(content: Text('✓ 4-Digit Screen PIN changed successfully!'), backgroundColor: Colors.green),
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
    final schoolId = SessionService.instance.activeSchoolId;
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
      const SnackBar(content: Text('Processing signature and cleaning background...'), duration: Duration(seconds: 2)),
    );

    final cleanSig = await SignatureProcessor.processAndCleanSignature(picked.path, colorMode: 'dark');
    if (cleanSig == null || cleanSig.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not process signature. Please try again with good lighting.')),
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
            .update({'signatureUrl': cleanSig});
      } catch (e) {
        debugPrint('[TeacherSettings] signature save note: $e');
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

  Future<void> _openWhatsAppHelp(String teacherName, String schoolName) async {
    final msg = Uri.encodeComponent(
      'Hello Support Team, I am faculty member $teacherName from $schoolName. I need assistance with the school app.',
    );
    final url = Uri.parse('https://wa.me/919142825442?text=$msg');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _callHelpline() async {
    final url = Uri.parse('tel:+919142825442');
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

  Widget _infoRow(BuildContext context, IconData icon, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              softWrap: true,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedClassChips(String assigned) {
    final clean = assigned.trim();
    final isAll = clean.toLowerCase() == 'all' ||
        clean.toLowerCase() == 'all classes' ||
        clean.toLowerCase() == 'all classes (full access)' ||
        SessionService.instance.hasAllClassesAccess;

    if (isAll) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF4338CA).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF4338CA).withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.stars_rounded, size: 18, color: Color(0xFF4338CA)),
            SizedBox(width: 8),
            Text(
              '★ All Classes Access (Full School)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4338CA)),
            ),
          ],
        ),
      );
    }

    final classes = clean
        .split(RegExp(r'[,|]'))
        .map((c) => c.trim().replaceAll(RegExp(r'^class\s*', caseSensitive: false), ''))
        .where((c) => c.isNotEmpty && c.toLowerCase() != 'none')
        .toList();

    if (classes.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.shade400),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 16, color: Colors.amber),
            SizedBox(width: 6),
            Text(
              'No Specific Classes Assigned',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: classes.map((c) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0D9488).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFF0D9488)),
              const SizedBox(width: 6),
              Text(
                'Class $c',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D9488)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final cs = Theme.of(context).colorScheme;
    final session = SessionService.instance;

    final effectiveAssignedClass = (_liveAssignedClass != null && _liveAssignedClass!.isNotEmpty)
        ? _liveAssignedClass!
        : (session.assignedClass?.isNotEmpty == true
            ? session.assignedClass!
            : (session.hasAllClassesAccess ? 'All Classes' : 'All Classes'));

    final teacherName = _liveName ?? session.teacherName ?? 'Teacher';
    final designation = _liveDesignation ?? 'Faculty Member';
    final subject = _liveSubject ?? 'All Subjects';
    final mobile = _liveMobile ?? '—';
    final email = _liveEmail ?? '${teacherName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}.${(session.teacherId ?? 't001').toLowerCase()}@faculty';

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Faculty Settings & Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: settingsAsync.when(
        data: (settings) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Teacher Profile Card
            _buildCard(
              context,
              'Faculty Account Profile',
              Icons.badge_outlined,
              [
                // Top header with avatar and name
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      child: Text(
                        teacherName.isNotEmpty ? teacherName[0].toUpperCase() : 'T',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
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
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              designation,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                _infoRow(context, Icons.tag, 'Teacher ID', session.teacherId ?? '—'),
                _infoRow(context, Icons.menu_book_outlined, 'Subject', subject),
                if (mobile != '—') _infoRow(context, Icons.phone_outlined, 'Contact Mobile', mobile),
                _infoRow(context, Icons.alternate_email, 'Account / Username', email),
                const Divider(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.class_outlined, size: 18, color: cs.onSurfaceVariant),
                          const SizedBox(width: 10),
                          Text(
                            'Assigned Teaching Classes',
                            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Classes and sections you have permissions to manage attendance and marks:',
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
                      ),
                      const SizedBox(height: 10),
                      _buildAssignedClassChips(effectiveAssignedClass),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // School Information Card
            _buildCard(context, 'School Information', Icons.school_outlined, [
              _infoRow(context, Icons.business, 'Institute Name', settings.instituteName),
              _infoRow(context, Icons.calendar_month, 'Academic Session', settings.currentSession),
              if (settings.principalName != null && settings.principalName!.isNotEmpty)
                _infoRow(context, Icons.person_outline, 'Principal / Head', settings.principalName!),
            ]),
            const SizedBox(height: 16),

            // ─── Digital Signature Card ──────────────────────────────────────
            _buildCard(
              context,
              'Class Teacher Digital Signature',
              Icons.draw_outlined,
              [
                const Text(
                  'Your digital signature will be automatically printed on official report cards & marksheets for your assigned class standard.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                if (_liveSignatureUrl != null && _liveSignatureUrl!.isNotEmpty) ...[
                  Container(
                    height: 80,
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    alignment: Alignment.center,
                    child: _liveSignatureUrl!.startsWith('data:image')
                        ? Image.memory(
                            base64Decode(_liveSignatureUrl!.split(',').last),
                            height: 64,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Text('Signature Preview'),
                          )
                        : Image.network(
                            _liveSignatureUrl!,
                            height: 64,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Text('Signature Preview'),
                          ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _uploadTeacherSignature,
                    icon: Icon(_liveSignatureUrl != null ? Icons.refresh_rounded : Icons.camera_alt_rounded, size: 18),
                    label: Text(
                      _liveSignatureUrl != null ? 'Re-upload / Change Signature' : 'Upload Digital Signature (Camera/Gallery)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ─── Security & Screen PIN Lock Card ─────────────────────────────
            _buildCard(
              context,
              'Screen PIN Lock & Privacy',
              Icons.lock_outline_rounded,
              [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isPinConfigured ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isPinConfigured ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                            size: 14,
                            color: _isPinConfigured ? const Color(0xFF166534) : const Color(0xFFB45309),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isPinConfigured ? '4-Digit PIN Active' : 'PIN Not Configured',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _isPinConfigured ? const Color(0xFF166534) : const Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _showChangePinDialog,
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: Text(_isPinConfigured ? 'Change PIN' : 'Set PIN', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Quick 4-digit PIN prevents unauthorized access to marks and student records when stepping away from device.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _lockScreenNow,
                  icon: const Icon(Icons.lock_clock_rounded, size: 18),
                  label: const Text('Lock Screen Now (तत्काल स्क्रीन लॉक करें)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ─── Academic Operations & Promotion Card ────────────────────────
            _buildCard(
              context,
              'Academic Management',
              Icons.school_rounded,
              [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.upgrade_rounded, color: Color(0xFF1E3A8A), size: 22),
                  ),
                  title: const Text('1-Click Class Promotion (कक्षा प्रोन्नति)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  subtitle: const Text('Promote whole batch or single student to next session', style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.promoteStudents),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ─── Help & Support Desk Card ────────────────────────────────────
            _buildCard(
              context,
              'Help & Technical Support (सहायता केंद्र)',
              Icons.headset_mic_outlined,
              [
                const Text(
                  'Reach out to school tech desk for marksheets, login credentials, or feature support:',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _openWhatsAppHelp(teacherName, settings.instituteName),
                        icon: const Icon(Icons.chat_rounded, size: 15),
                        label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _callHelpline,
                        icon: const Icon(Icons.phone_outlined, size: 15),
                        label: const Text('Call', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _emailSupport,
                        icon: const Icon(Icons.mail_outline_rounded, size: 15),
                        label: const Text('Email', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const Text('Frequently Asked Questions (FAQ):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                const SizedBox(height: 6),
                for (int i = 0; i < 4; i++) ...[
                  Builder(
                    builder: (ctx) {
                      final faqs = [
                        {
                          'q': 'Pre-Primary (Nursery, LKG, UKG) me Grade kaise enter karein?',
                          'a': 'Marksheet screen par Pre-Primary student select karne par direct Grade buttons (A+, A, B+, B, C, D) aate hain. 1-tap me grade select ho jata hai.',
                        },
                        {
                          'q': 'Class Teacher Signature marksheet par kaise aayega?',
                          'a': 'Upar "Upload Digital Signature" button se apne sign ka photo upload karein. App background clean karke transparent signature marksheet par render karega.',
                        },
                        {
                          'q': 'Screen PIN Lock kaise change karein?',
                          'a': 'Upar "Screen PIN Lock" card me "Change PIN" par tap karein aur naya 4-digit PIN enter karke Save karein.',
                        },
                        {
                          'q': 'Students ko agli class me Promote kaise karein?',
                          'a': 'Academic Management card me "1-Click Class Promotion" par tap karein, apni class chunein aur Promote button dabaayein.',
                        },
                      ];
                      final isExp = _expandedFaqIndex == i;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => setState(() => _expandedFaqIndex = isExp ? -1 : i),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        faqs[i]['q']!,
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                      ),
                                    ),
                                    Icon(isExp ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: const Color(0xFF64748B)),
                                  ],
                                ),
                                if (isExp) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    faqs[i]['a']!,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.3),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Theme Card
            _buildCard(context, 'Display & Theme', Icons.palette_outlined, [
              Row(
                children: [
                  Expanded(
                    child: _ThemeOption(
                      label: 'Light',
                      icon: Icons.light_mode,
                      selected: settings.themeMode == 'light',
                      onTap: () => ref.read(themeModeProvider.notifier).setMode('light'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ThemeOption(
                      label: 'Dark',
                      icon: Icons.dark_mode,
                      selected: settings.themeMode == 'dark',
                      onTap: () => ref.read(themeModeProvider.notifier).setMode('dark'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ThemeOption(
                      label: 'System',
                      icon: Icons.brightness_auto,
                      selected: settings.themeMode == 'system',
                      onTap: () => ref.read(themeModeProvider.notifier).setMode('system'),
                    ),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 24),

            // Logout Button
            OutlinedButton.icon(
              onPressed: () => _logout(context, ref),
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: const Text(
                'Logout from Teacher Account',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                side: const BorderSide(color: AppColors.error, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
        loading: () => const LoadingWidget(),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? cs.primary : cs.outline),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? Colors.white : cs.onSurfaceVariant, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : cs.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ]),
      ),
    );
  }
}
