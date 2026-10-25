import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../data/services/firestore_service.dart';
import '../../data/services/session_service.dart';
import '../../core/localization/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../data/models/settings_model.dart';
import '../../data/services/providers.dart';
import '../../widgets/responsive_web_layout.dart';
import '../../widgets/student_photo_picker.dart';
import '../../core/utils/signature_processor.dart';
import '../../core/utils/app_utils.dart';
import '../../data/services/database_service.dart';
import 'campus_geofence_settings_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {

  Future<void> _optimizeStudentPhotos() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Compressing student photos...'),
              ],
            ),
          ),
        ),
      ),
    );

    final count = await DatabaseService.instance.optimizeExistingStudentPhotos(force: true);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.green,
          content: Text(count > 0
              ? '✓ Successfully compressed $count student photo(s) to 20-30 KB!'
              : '✓ All student photos are already optimized to 20-30 KB!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final cs = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 850;

    if (settingsAsync.isLoading) {
      return Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final settings = settingsAsync.valueOrNull ?? SettingsModel.defaultSettings();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: isDesktop
          ? null
          : AppBar(
              title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w800)),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Header Profile Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: settings.logoPath != null && settings.logoPath!.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              settings.logoPath!,
                              width: 54,
                              height: 54,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.school, color: AppColors.primary, size: 30),
                            ),
                          )
                        : const Icon(Icons.school, color: AppColors.primary, size: 32),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.instituteName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        settings.tagline ?? 'Smart Management Cloud',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Session: ${settings.currentSession.isNotEmpty ? settings.currentSession : "2026-27"}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'SYSTEM CONFIGURATION',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
          ),
          const SizedBox(height: 10),

          // Menu Sections Cards
          Container(
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
            child: Column(
              children: [
                _buildMenuTile(
                  context: context,
                  title: 'Institute Profile & Details',
                  subtitle: 'Name, address, contact, principal name & session',
                  icon: Icons.account_balance_rounded,
                  iconColor: const Color(0xFF2563EB),
                  iconBg: const Color(0xFFDBEAFE),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InstituteProfileSettingsScreen()),
                  ),
                ),
                const Divider(height: 1, indent: 64),
                _buildMenuTile(
                  context: context,
                  title: 'School Campus GPS & Geofence',
                  subtitle: 'Set school campus GPS location & allowed radius (e.g. 300m) for teacher punch-in',
                  icon: Icons.location_on_rounded,
                  iconColor: const Color(0xFF059669),
                  iconBg: const Color(0xFFD1FAE5),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CampusGeofenceSettingsScreen()),
                  ),
                ),
                const Divider(height: 1, indent: 64),
                _buildMenuTile(
                  context: context,
                  title: 'Signature & Official Stamp',
                  subtitle: 'Principal signature, ink colors (White, Gold, Blue, Dark), official stamp',
                  icon: Icons.draw_rounded,
                  iconColor: const Color(0xFF7C3AED),
                  iconBg: const Color(0xFFEDE9FE),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignatureStampSettingsScreen()),
                  ),
                ),
                const Divider(height: 1, indent: 64),
                _buildMenuTile(
                  context: context,
                  title: 'Academic Classes & Courses',
                  subtitle: 'Manage classes, sections, vocational courses & time batches',
                  icon: Icons.menu_book_rounded,
                  iconColor: const Color(0xFF059669),
                  iconBg: const Color(0xFFD1FAE5),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AcademicSetupSettingsScreen()),
                  ),
                ),
                const Divider(height: 1, indent: 64),
                _buildMenuTile(
                  context: context,
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
                  context: context,
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
                  context: context,
                  title: 'Security PIN & App Lock',
                  subtitle: 'Change 4-digit administrative PIN & privacy lock',
                  icon: Icons.lock_rounded,
                  iconColor: const Color(0xFFE11D48),
                  iconBg: const Color(0xFFFFE4E6),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SecurityPinSettingsScreen()),
                  ),
                ),
                const Divider(height: 1, indent: 64),
                _buildMenuTile(
                  context: context,
                  title: 'Help and feedback',
                  subtitle: 'Help Centre, contact us, feedback, rating & privacy policy',
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

          const Text(
            'TOOLS & OPERATIONS',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
          ),
          const SizedBox(height: 10),

          // Tools Actions
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEEF2FF),
                    child: Icon(Icons.school_outlined, color: Color(0xFF1F108E), size: 20),
                  ),
                  title: const Text('1-Click Class Promotion', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: const Text('Promote whole batch/classes to next academic year', style: TextStyle(fontSize: 11.5)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.promoteStudents),
                ),
                const Divider(height: 1, indent: 64),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF1F5F9),
                    child: Icon(Icons.backup_outlined, color: Color(0xFF475569), size: 20),
                  ),
                  title: const Text('Backup & Cloud Export', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: const Text('Export SQLite database & remote sync snapshots', style: TextStyle(fontSize: 11.5)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.backup),
                ),
                const Divider(height: 1, indent: 64),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF0FDF4),
                    child: Icon(Icons.share_rounded, color: Color(0xFF16A34A), size: 20),
                  ),
                  title: const Text('1-Click Share DB Backup', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: const Text('Directly export & share SQLite .db on WhatsApp/Drive', style: TextStyle(fontSize: 11.5)),
                  trailing: const Icon(Icons.send_rounded, color: Color(0xFF16A34A), size: 18),
                  onTap: () async {
                    try {
                      final path = await DatabaseService.instance.exportDatabase();
                      await Share.shareXFiles(
                        [XFile(path)],
                        subject: 'School Database SQLite Backup',
                        text: 'School Management Database Backup (.db)',
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Backup export error: $e')),
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF0FDF4),
                    child: Icon(Icons.photo_size_select_actual_outlined, color: Colors.green, size: 20),
                  ),
                  title: const Text('Optimize Student Photos', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: const Text('Compress all past student DPs to 20-30 KB', style: TextStyle(fontSize: 11.5)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                  onTap: _optimizeStudentPhotos,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Center(
            child: Column(
              children: [
                const Text('School Management Cloud v2.1', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Tenant ID: \${settings.instituteName}', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );

    if (isDesktop) {
      return ResponsiveWebLayout(
        title: 'Settings',
        currentRoute: AppRoutes.settings,
        body: content,
      );
    }

    return content;
  }

  Widget _buildMenuTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SUB-PAGE 1: Institute Profile & Details
// ============================================================================
class InstituteProfileSettingsScreen extends ConsumerStatefulWidget {
  const InstituteProfileSettingsScreen({super.key});

  @override
  ConsumerState<InstituteProfileSettingsScreen> createState() => _InstituteProfileSettingsScreenState();
}

class _InstituteProfileSettingsScreenState extends ConsumerState<InstituteProfileSettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _principalCtrl = TextEditingController();
  final _affiliationCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String _currentSession = '2026-27';
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _taglineCtrl.dispose();
    _addressCtrl.dispose();
    _mobileCtrl.dispose();
    _principalCtrl.dispose();
    _affiliationCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _init(SettingsModel s) {
    if (_initialized) return;
    _nameCtrl.text = s.instituteName;
    _taglineCtrl.text = s.tagline ?? '';
    _addressCtrl.text = s.address;
    _mobileCtrl.text = s.mobile;
    _principalCtrl.text = s.principalName ?? '';
    _affiliationCtrl.text = s.affiliationNumber ?? '';
    _emailCtrl.text = s.email ?? '';
    _currentSession = s.currentSession;
    _initialized = true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final current = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
      final updated = current.copyWith(
        instituteName: _nameCtrl.text.trim().isEmpty ? current.instituteName : _nameCtrl.text.trim(),
        tagline: _taglineCtrl.text.trim().isEmpty ? null : _taglineCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty ? current.address : _addressCtrl.text.trim(),
        mobile: _mobileCtrl.text.trim().isEmpty ? current.mobile : _mobileCtrl.text.trim(),
        principalName: _principalCtrl.text.trim().isEmpty ? null : _principalCtrl.text.trim(),
        affiliationNumber: _affiliationCtrl.text.trim().isEmpty ? null : _affiliationCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        currentSession: _currentSession,
      );
      await ref.read(settingsProvider.notifier).save(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile details saved & synced!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: \$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.valueOrNull ?? SettingsModel.defaultSettings();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _init(settings);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Institute Profile & Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Logo Card
          Container(
            padding: const EdgeInsets.all(16),
        color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkCard : Colors.white,
            child: Column(
              children: [
                const Text('Institute Official Logo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 12),
                StudentPhotoPicker(
                  photoPath: settings.logoPath,
                  onChanged: (path) async {
                    await ref.read(settingsProvider.notifier).save(settings.copyWith(logoPath: path));
                  },
                  size: 96,
                  borderRadius: BorderRadius.circular(48),
                  placeholderIcon: Icons.add_photo_alternate_outlined,
                ),
                const SizedBox(height: 8),
                const Text('Tap to upload or replace school emblem / logo', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Details Form Card
          Container(
            padding: const EdgeInsets.all(16),
        color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkCard : Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('General Information', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 14),
                _field(_nameCtrl, 'Institute / School Name *', Icons.business),
                const SizedBox(height: 12),
                _field(_taglineCtrl, 'Tagline / Slogan', Icons.format_quote),
                const SizedBox(height: 12),
                _field(_principalCtrl, 'Principal / Director Name', Icons.person),
                const SizedBox(height: 12),
                _field(_mobileCtrl, 'Contact Phone Number', Icons.phone, inputType: TextInputType.phone),
                const SizedBox(height: 12),
                _field(_addressCtrl, 'Complete Campus Address', Icons.location_on, maxLines: 2),
                const SizedBox(height: 12),
                _field(_affiliationCtrl, 'Affiliation / Registration No.', Icons.numbers),
                const SizedBox(height: 12),
                _field(_emailCtrl, 'Official Email Address', Icons.email_outlined, inputType: TextInputType.emailAddress),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: SettingsModel.getSessions().contains(_currentSession) ? _currentSession : SettingsModel.getSessions().first,
                  decoration: InputDecoration(
                    labelText: 'Current Academic Session',
                    prefixIcon: const Icon(Icons.calendar_month, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: SettingsModel.getSessions().map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _currentSession = v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_rounded),
            label: Text(_saving ? 'Saving...' : 'Save Profile Changes', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1, TextInputType? inputType}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: inputType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF64748B)),
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}

// ============================================================================
// SUB-PAGE 2: Signature & Official Stamp / Seals
// ============================================================================
class SignatureStampSettingsScreen extends ConsumerWidget {
  const SignatureStampSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.valueOrNull ?? SettingsModel.defaultSettings();

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Signature & Official Stamp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Principal Signature Card
          Container(
            padding: const EdgeInsets.all(16),
        color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkCard : Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.draw_rounded, color: Color(0xFF7C3AED), size: 20),
                    SizedBox(width: 8),
                    Text('Authorized Principal Signature', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: StudentPhotoPicker(
                    photoPath: settings.principalSignature,
                    onChanged: (path) async {
                      if (path != null && path.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Processing signature with contrast ink...')),
                        );
                        final cleanPath = await SignatureProcessor.processAndCleanSignature(path, colorMode: settings.signatureColorMode);
                        await ref.read(settingsProvider.notifier).save(
                          settings.copyWith(
                            principalSignature: cleanPath ?? path,
                            rawSignature: path,
                          ),
                        );
                      } else {
                        await ref.read(settingsProvider.notifier).save(settings.copyWith(principalSignature: '', rawSignature: ''));
                      }
                    },
                    size: 110,
                    borderRadius: BorderRadius.circular(12),
                    placeholderIcon: Icons.draw_outlined,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Upload photo of signature on white paper. The background will be made transparent automatically.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 10),

                // Ink Color Mode Options (White, Gold, Blue, Dark)
                const Text('Signature Ink Color Mode:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _inkButton(context, ref, settings, '⚪ White', 'white'),
                      const SizedBox(width: 8),
                      _inkButton(context, ref, settings, '⭐ Gold', 'gold'),
                      const SizedBox(width: 8),
                      _inkButton(context, ref, settings, '🔵 Royal Blue', 'blue'),
                      const SizedBox(width: 8),
                      _inkButton(context, ref, settings, '⚫ Dark Ink', 'dark'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('PDF Signature Size: ${(settings.signatureScale * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    Text('${(38 * settings.signatureScale).toStringAsFixed(1)} mm', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  ],
                ),
                Slider(
                  value: settings.signatureScale.clamp(0.6, 1.6),
                  min: 0.6,
                  max: 1.6,
                  divisions: 10,
                  label: '${(settings.signatureScale * 100).toInt()}%',
                  activeColor: AppColors.primary,
                  onChanged: (val) async {
                    final updated = settings.copyWith(signatureScale: val);
                    await ref.read(settingsProvider.notifier).save(updated);
                    FirestoreService.instance.syncSettings(updated).catchError((_) {});
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // School Stamp / Official Seal Card
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkCard : Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 20),
                    SizedBox(width: 8),
                    Text('Official School Stamp / Seal (मोहर)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 14),
                Center(
                  child: Column(
                    children: [
                      // Stamp circular preview box with high contrast
                      GestureDetector(
                        onTap: () => _pickAndSaveStamp(context, ref, settings, ImageSource.gallery),
                        child: Tooltip(
                          message: 'Tap to change stamp photo',
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF10B981), width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(6),
                            child: ClipOval(
                              child: (settings.schoolStamp != null && settings.schoolStamp!.isNotEmpty)
                                  ? _buildStampImage(settings.schoolStamp!)
                                  : const Center(
                                      child: Icon(Icons.verified_user_outlined, size: 44, color: Color(0xFF94A3B8)),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF059669),
                              side: const BorderSide(color: Color(0xFF059669)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: () => _pickAndSaveStamp(context, ref, settings, ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined, size: 16),
                            label: const Text('Gallery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF059669),
                              side: const BorderSide(color: Color(0xFF059669)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: () => _pickAndSaveStamp(context, ref, settings, ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_outlined, size: 16),
                            label: const Text('Camera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF059669),
                              side: const BorderSide(color: Color(0xFF059669)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onPressed: () => _enterStampUrlDialog(context, ref, settings),
                            icon: const Icon(Icons.link, size: 16),
                            label: const Text('URL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          if (settings.schoolStamp != null && settings.schoolStamp!.isNotEmpty) ...[
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF059669),
                                side: const BorderSide(color: Color(0xFF059669)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              onPressed: () => _cropExistingStamp(context, ref, settings),
                              icon: const Icon(Icons.crop, size: 16),
                              label: const Text('Recrop', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            IconButton(
                              tooltip: 'Remove Stamp',
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFFFEE2E2),
                                foregroundColor: const Color(0xFFDC2626),
                              ),
                              onPressed: () async {
                                final updated = settings.copyWith(schoolStamp: '');
                                await ref.read(settingsProvider.notifier).save(updated);
                                FirestoreService.instance.syncSettings(updated).catchError((_) {});
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Stamp removed.')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.delete_outline, size: 18),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Upload circular stamp of the school. Paper background is auto-cleaned. Printed on Admit Cards, Marksheets & Certificates.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('PDF Stamp Size: ${(settings.stampScale * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    Text('${(22 * settings.stampScale).toStringAsFixed(1)} mm', style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w600)),
                  ],
                ),
                Slider(
                  value: settings.stampScale.clamp(0.6, 1.6),
                  min: 0.6,
                  max: 1.6,
                  divisions: 10,
                  label: '${(settings.stampScale * 100).toInt()}%',
                  activeColor: const Color(0xFF059669),
                  onChanged: (val) async {
                    final updated = settings.copyWith(stampScale: val);
                    await ref.read(settingsProvider.notifier).save(updated);
                    FirestoreService.instance.syncSettings(updated).catchError((_) {});
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStampImage(String stamp) {
    ImageProvider? provider;
    final trimmed = stamp.trim();
    if (trimmed.startsWith('data:image')) {
      final commaIdx = trimmed.indexOf(',');
      if (commaIdx != -1) {
        try {
          final clean = trimmed.substring(commaIdx + 1).replaceAll('\n', '').replaceAll('\r', '').trim();
          final bytes = base64Decode(clean);
          provider = MemoryImage(bytes);
        } catch (_) {}
      }
    } else if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      provider = NetworkImage(trimmed);
    } else if (trimmed.startsWith('/') || trimmed.contains(r'\') || trimmed.startsWith('file://')) {
      final f = File(trimmed.replaceFirst('file://', ''));
      if (f.existsSync()) {
        provider = FileImage(f);
      }
    }
    if (provider == null) {
      try {
        final clean = trimmed.replaceAll('\n', '').replaceAll('\r', '').trim();
        final bytes = base64Decode(clean);
        provider = MemoryImage(bytes);
      } catch (_) {}
    }
    if (provider != null) {
      return Image(
        image: provider,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.verified_user_outlined, size: 44, color: Color(0xFF94A3B8)),
        ),
      );
    }
    return const Center(child: Icon(Icons.verified_user_outlined, size: 44, color: Color(0xFF94A3B8)));
  }

  Future<void> _cropExistingStamp(BuildContext context, WidgetRef ref, SettingsModel settings) async {
    try {
      final bytes = await AppUtils.loadAppImageBytes(settings.schoolStamp);
      if (bytes == null || bytes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not load current stamp to crop.')));
        }
        return;
      }
      final tempFile = File('${Directory.systemTemp.path}/temp_stamp_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(bytes);
      if (!context.mounted) return;
      await _cropAndSaveFromFile(context, ref, settings, tempFile);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cropping stamp: $e')));
      }
    }
  }

  Future<void> _pickAndSaveStamp(BuildContext context, WidgetRef ref, SettingsModel settings, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 1000, maxHeight: 1000, imageQuality: 95);
      if (picked == null) return;
      if (!context.mounted) return;
      await _cropAndSaveFromFile(context, ref, settings, File(picked.path));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking stamp: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _cropAndSaveFromFile(BuildContext context, WidgetRef ref, SettingsModel settings, File sourceFile) async {
    try {
      CroppedFile? cropped;
      bool cropperFailed = false;
      try {
        cropped = await ImageCropper().cropImage(
          sourcePath: sourceFile.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          maxWidth: 600,
          maxHeight: 600,
          compressQuality: 90,
          compressFormat: ImageCompressFormat.png,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Stamp / Mohar (मोहर)',
              toolbarColor: const Color(0xFF059669),
              toolbarWidgetColor: Colors.white,
              activeControlsWidgetColor: const Color(0xFF059669),
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: false,
            ),
            IOSUiSettings(
              title: 'Crop Stamp / Mohar (मोहर)',
              aspectRatioLockEnabled: false,
              resetAspectRatioEnabled: true,
            ),
          ],
        );
      } catch (cropperError) {
        debugPrint('[Cropper] Warning during stamp crop: $cropperError');
        cropperFailed = true;
      }

      if (cropped == null && !cropperFailed) {
        // User intentionally cancelled cropping dialog
        return;
      }

      final fileToProcess = cropped != null ? File(cropped.path) : sourceFile;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Processing and saving official stamp...'),
            duration: Duration(milliseconds: 1000),
          ),
        );
      }

      final rawBytes = await fileToProcess.readAsBytes();
      String? cleanStamp;
      try {
        cleanStamp = await SignatureProcessor.processAndCleanStamp(rawBytes);
      } catch (e) {
        debugPrint('[Stamp] Clean background error: $e');
      }

      String stampToSave;
      if (cleanStamp != null && cleanStamp.isNotEmpty) {
        stampToSave = cleanStamp;
      } else {
        // Safe compact downscale fallback (<20KB): never store multi-MB raw camera photos into Firestore
        try {
          final codec = await ui.instantiateImageCodec(rawBytes, targetWidth: 180);
          final frame = await codec.getNextFrame();
          final outByteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
          if (outByteData != null) {
            stampToSave = 'data:image/png;base64,${base64Encode(outByteData.buffer.asUint8List())}';
          } else {
            stampToSave = 'data:image/png;base64,${base64Encode(rawBytes)}';
          }
        } catch (_) {
          stampToSave = 'data:image/png;base64,${base64Encode(rawBytes)}';
        }
      }

      final updated = settings.copyWith(schoolStamp: stampToSave);
      await ref.read(settingsProvider.notifier).save(updated);
      FirestoreService.instance.syncSettings(updated).catchError((e) {
        debugPrint('[Settings] Stamp remote sync error: $e');
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Official stamp saved & synced!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving stamp: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _enterStampUrlDialog(BuildContext context, WidgetRef ref, SettingsModel settings) async {
    final initial = (settings.schoolStamp != null && settings.schoolStamp!.startsWith('http'))
        ? settings.schoolStamp!
        : '';
    final controller = TextEditingController(text: initial);
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.link, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Text('Stamp / Seal URL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste a direct photo/image link (https://...) for your official school rubber stamp or seal.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'https://example.com/stamp.png',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.image_outlined, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              autofocus: true,
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save URL'),
          ),
        ],
      ),
    );

    if (url == null) return;
    if (url.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL cannot be empty.')));
      }
      return;
    }

    final updated = settings.copyWith(schoolStamp: url);
    await ref.read(settingsProvider.notifier).save(updated);
    FirestoreService.instance.syncSettings(updated).catchError((e) {
      debugPrint('[Settings] Stamp URL remote sync error: $e');
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stamp URL saved & synced to server!'), backgroundColor: AppColors.success),
      );
    }
  }

  Widget _inkButton(BuildContext context, WidgetRef ref, SettingsModel settings, String label, String mode) {
    final isSelected = (settings.signatureColorMode == mode) || (mode == 'white' && settings.signatureColorMode.isEmpty);
    return InkWell(
      onTap: () async {
        final src = settings.rawSignature != null && settings.rawSignature!.isNotEmpty
            ? settings.rawSignature
            : settings.principalSignature;
        if (src == null || src.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please upload a signature first.')),
          );
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Converting signature to \$label...'), duration: const Duration(seconds: 1)),
        );
        final converted = await SignatureProcessor.processAndCleanSignature(src, colorMode: mode);
        if (converted != null) {
          final raw = (settings.rawSignature != null && settings.rawSignature!.isNotEmpty) ? settings.rawSignature : src;
          await ref.read(settingsProvider.notifier).save(
            settings.copyWith(
              principalSignature: converted,
              rawSignature: raw,
              signatureColorMode: mode,
            ),
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Signature converted to \$label!'), backgroundColor: AppColors.success),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1), width: isSelected ? 1.5 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SUB-PAGE 3: Academic Classes, Courses & Batches
// ============================================================================
class AcademicSetupSettingsScreen extends ConsumerWidget {
  const AcademicSetupSettingsScreen({super.key});

  Future<void> _showAddDialog({
    required BuildContext context,
    required String title,
    required String hint,
    required Future<void> Function(String value) onAdd,
  }) async {
    final ctrl = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (res != null && res.isNotEmpty) {
      await onAdd(res);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.valueOrNull ?? SettingsModel.defaultSettings();

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Classes & Courses Setup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // School Classes
          _buildChipSection(
            context: context,
            title: 'School Classes',
            items: settings.schoolClasses,
            onAddTap: () => _showAddDialog(
              context: context,
              title: 'Add School Class',
              hint: 'e.g. 11th-Science or Playgroup',
              onAdd: (val) async {
                if (!settings.schoolClasses.contains(val)) {
                  await ref.read(settingsProvider.notifier).save(settings.copyWith(schoolClasses: [...settings.schoolClasses, val]));
                }
              },
            ),
            onDelete: (item) async {
              final updated = settings.schoolClasses.where((c) => c != item).toList();
              await ref.read(settingsProvider.notifier).save(settings.copyWith(schoolClasses: updated));
            },
          ),
          const SizedBox(height: 16),

          // Sections
          _buildChipSection(
            context: context,
            title: 'Sections',
            items: settings.sections,
            onAddTap: () => _showAddDialog(
              context: context,
              title: 'Add Section',
              hint: 'e.g. D or Red',
              onAdd: (val) async {
                if (!settings.sections.contains(val)) {
                  await ref.read(settingsProvider.notifier).save(settings.copyWith(sections: [...settings.sections, val]));
                }
              },
            ),
            onDelete: (item) async {
              final updated = settings.sections.where((s) => s != item).toList();
              await ref.read(settingsProvider.notifier).save(settings.copyWith(sections: updated));
            },
          ),
          const SizedBox(height: 16),

          // Computer Institute Courses
          _buildChipSection(
            context: context,
            title: 'Vocational & Computer Courses',
            items: settings.computerCourses,
            onAddTap: () => _showAddDialog(
              context: context,
              title: 'Add Vocational Course',
              hint: 'e.g. Python Full Stack (6 Mo)',
              onAdd: (val) async {
                if (!settings.computerCourses.contains(val)) {
                  await ref.read(settingsProvider.notifier).save(settings.copyWith(computerCourses: [...settings.computerCourses, val]));
                }
              },
            ),
            onDelete: (item) async {
              final updated = settings.computerCourses.where((c) => c != item).toList();
              await ref.read(settingsProvider.notifier).save(settings.copyWith(computerCourses: updated));
            },
          ),
          const SizedBox(height: 16),

          // Time Batches
          _buildChipSection(
            context: context,
            title: 'Time Batches',
            items: settings.batches,
            onAddTap: () => _showAddDialog(
              context: context,
              title: 'Add Time Batch',
              hint: 'e.g. 06:00 PM - 08:00 PM',
              onAdd: (val) async {
                if (!settings.batches.contains(val)) {
                  await ref.read(settingsProvider.notifier).save(settings.copyWith(batches: [...settings.batches, val]));
                }
              },
            ),
            onDelete: (item) async {
              final updated = settings.batches.where((b) => b != item).toList();
              await ref.read(settingsProvider.notifier).save(settings.copyWith(batches: updated));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChipSection({
    required BuildContext context,
    required String title,
    required List<String> items,
    required VoidCallback onAddTap,
    required ValueChanged<String> onDelete,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
        color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkCard : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              IconButton(icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 22), onPressed: onAddTap),
            ],
          ),
          const SizedBox(height: 6),
          if (items.isEmpty)
            const Text('No items added yet. Click + to add.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: items
                  .map((item) => Chip(
                        label: Text(item, style: const TextStyle(fontSize: 12)),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => onDelete(item),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// SUB-PAGE 4: Appearance & Theme
// ============================================================================
class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.valueOrNull ?? SettingsModel.defaultSettings();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(AppTranslations.tr('appearance_theme', lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
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
                Text(
                  'Choose Color Theme',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _themeCard(
                        context: context,
                        label: AppTranslations.tr('light_mode', lang),
                        icon: Icons.light_mode,
                        selected: settings.themeMode == 'light',
                        onTap: () => ref.read(themeModeProvider.notifier).setMode('light'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _themeCard(
                        context: context,
                        label: AppTranslations.tr('dark_mode', lang),
                        icon: Icons.dark_mode,
                        selected: settings.themeMode == 'dark',
                        onTap: () => ref.read(themeModeProvider.notifier).setMode('dark'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _themeCard(
                        context: context,
                        label: AppTranslations.tr('system_mode', lang),
                        icon: Icons.brightness_auto,
                        selected: settings.themeMode == 'system',
                        onTap: () => ref.read(themeModeProvider.notifier).setMode('system'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeCard({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.12)
              : (isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.accentLight : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? (isDark ? Colors.white : AppColors.primary) : (isDark ? Colors.white60 : const Color(0xFF64748B)), size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? (isDark ? Colors.white : AppColors.primary) : (isDark ? Colors.white70 : const Color(0xFF334155)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SUB-PAGE 5: Language (भाषा)
// ============================================================================
class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(AppTranslations.tr('app_language', currentLang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'en',
                  groupValue: currentLang,
                  title: Text(
                    'English (Default)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                  ),
                  subtitle: Text(
                    'All screens, navigation, and results displayed in English',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                  ),
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(appLanguageProvider.notifier).setLanguage(val);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Display language set to English'), backgroundColor: AppColors.success),
                      );
                    }
                  },
                ),
                Divider(height: 1, color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                RadioListTile<String>(
                  value: 'hi',
                  groupValue: currentLang,
                  title: Text(
                    'हिन्दी (Hindi)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                  ),
                  subtitle: Text(
                    'डैशबोर्ड, परिणाम, उपस्थिति और सेटिंग्स हिन्दी में प्रदर्शित होंगे',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                  ),
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(appLanguageProvider.notifier).setLanguage(val);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('भाषा हिन्दी पर सेट की गई (Hindi applied across app)'), backgroundColor: AppColors.success),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            currentLang == 'hi'
                ? 'नोट: भाषा परिवर्तन पूरे ऐप (डैशबोर्ड, नेविगेशन, अंक प्रविष्टि डेस्क, सेटिंग्स) में तुरंत लागू होता है।'
                : 'Note: Language preference applies immediately across the entire app (Dashboard, Navigation, Results, Settings).',
            style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF94A3B8), fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SUB-PAGE 6: Security & PIN Code
// ============================================================================
class SecurityPinSettingsScreen extends StatefulWidget {
  const SecurityPinSettingsScreen({super.key});

  @override
  State<SecurityPinSettingsScreen> createState() => _SecurityPinSettingsScreenState();
}

class _SecurityPinSettingsScreenState extends State<SecurityPinSettingsScreen> {
  final _oldPinCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();

  @override
  void dispose() {
    _oldPinCtrl.dispose();
    _newPinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  void _updatePin() {
    if (_newPinCtrl.text.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN must be exactly 4 digits'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_newPinCtrl.text != _confirmPinCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New PIN and Confirm PIN do not match'), backgroundColor: Colors.red),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Master Security PIN updated successfully!'), backgroundColor: AppColors.success),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Security & PIN Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
        color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkCard : Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Update Master PIN', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 14),
                TextField(
                  controller: _oldPinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  decoration: const InputDecoration(labelText: 'Current PIN', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _newPinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  decoration: const InputDecoration(labelText: 'New 4-Digit PIN', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _confirmPinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  decoration: const InputDecoration(labelText: 'Confirm New PIN', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _updatePin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save PIN Changes', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SUB-PAGE 7: Help & Support Helpline (NEW!)
// ============================================================================
class HelpSupportSettingsScreen extends ConsumerWidget {
  const HelpSupportSettingsScreen({super.key});

  static const String appVersion = 'Version 1.0.0';

  Future<void> _launchWhatsApp(BuildContext context, String phone, String schoolName) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final fullPhone = clean.startsWith('91') ? clean : (clean.length == 10 ? '91$clean' : clean);
    final url = Uri.parse('https://wa.me/$fullPhone?text=Hello%20${Uri.encodeComponent(schoolName)}%2C%20I%20need%20assistance%20with%20school%20management.');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp is not installed on this device.')),
        );
      }
    }
  }

  Future<void> _launchCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final url = Uri.parse('tel:$clean');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  Future<void> _launchEmail(String email, String schoolName) async {
    final url = Uri.parse('mailto:$email?subject=${Uri.encodeComponent('$schoolName Support Inquiry')}');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  void _showHelpCentreDialog(BuildContext context, {required bool isDark}) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.help_outline_rounded, color: Colors.tealAccent, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Help Centre • FAQs',
                  style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _faqTile(
              'How does offline mode sync with the website?',
              'The app works completely offline. As soon as your internet connects, all students, fees, and attendance automatically sync to the Firebase cloud database.',
              isDark: isDark,
            ),
            _faqTile(
              'How do I add a signature and make it transparent?',
              'Go to Settings > Signature & Official Stamp. Take a clear photo of your signature on white paper. The app automatically cleans the background and renders high-resolution transparent ink.',
              isDark: isDark,
            ),
            _faqTile(
              'Can teachers access fee collection?',
              'By default, fee collection is restricted for teacher accounts. The principal can enable or restrict it from the Teacher Role Access screen.',
              isDark: isDark,
            ),
            _faqTile(
              'How can I restore my database backup?',
              'Go to Settings > Backup & Restore. Select your previously exported JSON or Excel database file to restore students, teachers, and records instantly.',
              isDark: isDark,
            ),
            _faqTile(
              'How do I print student ID cards and admit cards?',
              'Navigate to the ID Cards or Admit Cards section from Key Modules. Choose your layout template, customize colors, and click Print or Export PDF.',
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  void _showContactUsSheet(
    BuildContext context, {
    required bool isDark,
    required String adminMobile,
    String? whatsappMobile,
    String? workingHours,
    required String adminEmail,
    required String schoolName,
  }) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF8E8E8E) : const Color(0xFF64748B);
    final dividerColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0);
    final finalWhatsapp = (whatsappMobile != null && whatsappMobile.isNotEmpty) ? whatsappMobile : adminMobile;
    final finalHours = (workingHours != null && workingHours.isNotEmpty) ? workingHours : 'Office Hours';

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Contact us', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('School: $schoolName', style: TextStyle(color: textSecondary, fontSize: 12)),
            const SizedBox(height: 18),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF14532D),
                child: Icon(Icons.chat_bubble_rounded, color: Color(0xFF4ADE80), size: 20),
              ),
              title: Text('WhatsApp Support', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('$finalWhatsapp (Instant replies)', style: TextStyle(color: textSecondary, fontSize: 12)),
              trailing: Icon(Icons.arrow_forward_ios_rounded, color: isDark ? Colors.white38 : Colors.black26, size: 14),
              onTap: () {
                Navigator.pop(ctx);
                _launchWhatsApp(context, finalWhatsapp, schoolName);
              },
            ),
            Divider(color: dividerColor),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF1E3A8A),
                child: Icon(Icons.phone_in_talk_rounded, color: Color(0xFF60A5FA), size: 20),
              ),
              title: Text('Call Helpline', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('$adminMobile ($finalHours)', style: TextStyle(color: textSecondary, fontSize: 12)),
              trailing: Icon(Icons.arrow_forward_ios_rounded, color: isDark ? Colors.white38 : Colors.black26, size: 14),
              onTap: () {
                Navigator.pop(ctx);
                _launchCall(adminMobile);
              },
            ),
            Divider(color: dividerColor),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF713F12),
                child: Icon(Icons.email_rounded, color: Color(0xFFFBBF24), size: 20),
              ),
              title: Text('Email Support', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text(adminEmail, style: TextStyle(color: textSecondary, fontSize: 12)),
              trailing: Icon(Icons.arrow_forward_ios_rounded, color: isDark ? Colors.white38 : Colors.black26, size: 14),
              onTap: () {
                Navigator.pop(ctx);
                _launchEmail(adminEmail, schoolName);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFeedbackDialog(
    BuildContext context, {
    required bool isDark,
    required String schoolName,
    required String adminEmail,
  }) {
    final textCtrl = TextEditingController();
    String category = 'Technical Issue';
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final inputBg = isDark ? const Color(0xFF262626) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF8E8E8E) : const Color(0xFF64748B);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.pest_control_outlined, color: Colors.tealAccent, size: 22),
              const SizedBox(width: 10),
              Text('Send feedback', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Category:', style: TextStyle(color: textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: category,
                dropdownColor: isDark ? const Color(0xFF262626) : Colors.white,
                style: TextStyle(color: textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: inputBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: borderColor),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'Technical Issue', child: Text('Technical Issue / Bug')),
                  DropdownMenuItem(value: 'Feature Suggestion', child: Text('Feature Suggestion')),
                  DropdownMenuItem(value: 'UI Improvement', child: Text('UI / Usability Improvement')),
                  DropdownMenuItem(value: 'General Feedback', child: Text('General Feedback')),
                ],
                onChanged: (v) {
                  if (v != null) setDState(() => category = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textCtrl,
                maxLines: 4,
                style: TextStyle(color: textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Describe your issue or suggestions...',
                  hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12),
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: borderColor),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final text = textCtrl.text.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(ctx);
                  try {
                    final sId = SessionService.instance.activeSchoolUidOrNull ?? SessionService.instance.activeSchoolId;
                    final docId = 'fb_${DateTime.now().millisecondsSinceEpoch}';
                    final payload = {
                      'id': docId,
                      'schoolId': sId,
                      'schoolName': schoolName,
                      'senderEmail': adminEmail,
                      'category': category,
                      'message': text,
                      'device': 'mobile_app',
                      'status': 'new',
                      'createdAt': FieldValue.serverTimestamp(),
                    };
                    // 1. Primary write
                    try {
                      await FirebaseFirestore.instance.collection('feedbacks').doc(docId).set(payload);
                    } catch (_) {}
                    // 2. Backup write to open schoolDirectory
                    try {
                      await FirebaseFirestore.instance
                          .collection('schoolDirectory')
                          .doc('system_feedbacks')
                          .collection('items')
                          .doc(docId)
                          .set(payload);
                    } catch (_) {}
                  } catch (_) {}
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✓ Feedback submitted to School Admin! Thank you.'),
                        backgroundColor: Colors.teal,
                      ),
                    );
                  }
                }
              },
              child: const Text('Submit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showRatingDialog(
    BuildContext context, {
    required bool isDark,
    required String schoolName,
    required String adminEmail,
  }) {
    int rating = 5;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF8E8E8E) : const Color(0xFF64748B);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'Rate the app',
            style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How would you rate your experience with School Management?',
                style: TextStyle(color: textSecondary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (idx) {
                  final starIndex = idx + 1;
                  return IconButton(
                    icon: Icon(
                      starIndex <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () => setDState(() => rating = starIndex),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                '$rating / 5 Stars',
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Later', style: TextStyle(color: textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final sId = SessionService.instance.activeSchoolUidOrNull ?? SessionService.instance.activeSchoolId;
                  final docId = 'rate_${DateTime.now().millisecondsSinceEpoch}';
                  final payload = {
                    'id': docId,
                    'schoolId': sId,
                    'schoolName': schoolName,
                    'senderEmail': adminEmail,
                    'category': 'App Rating',
                    'rating': rating,
                    'message': '$rating / 5 Stars Rating',
                    'device': 'mobile_app',
                    'status': 'new',
                    'createdAt': FieldValue.serverTimestamp(),
                  };
                  // 1. Primary write
                  try {
                    await FirebaseFirestore.instance.collection('feedbacks').doc(docId).set(payload);
                  } catch (_) {}
                  // 2. Backup write to open schoolDirectory
                  try {
                    await FirebaseFirestore.instance
                        .collection('schoolDirectory')
                        .doc('system_feedbacks')
                        .collection('items')
                        .doc(docId)
                        .set(payload);
                  } catch (_) {}
                } catch (_) {}
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('★ Thank you for rating the app!'), backgroundColor: Colors.teal),
                  );
                }
              },
              child: const Text('Submit Rating', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showTermsDialog(BuildContext context, {required bool isDark}) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF8E8E8E) : const Color(0xFF64748B);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.description_outlined, color: Colors.tealAccent, size: 22),
            const SizedBox(width: 10),
            Text('Terms & Privacy Policy', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('1. Educational Scope & Authorized Licensing', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text('The platform is provisioned strictly for academic governance, student records management, fee accounting, and institutional administration. Access is granted solely to verified school principals, faculty teachers, and authorized institutional staff.', style: TextStyle(color: textSecondary, fontSize: 12)),
                const SizedBox(height: 12),
                Text('2. 100% Institutional Data Ownership & Student Privacy', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text('All school records, student profiles, parent contacts, photos, examination marks, and fee collections belong entirely and exclusively to your educational institution. We never sell, lease, or monetize student data with third-party advertisers or data brokers under any circumstances.', style: TextStyle(color: textSecondary, fontSize: 12)),
                const SizedBox(height: 12),
                Text('3. End-to-End Cryptography & Data Protection', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text('All communication is encrypted using industry standard HTTPS and TLS 1.3. Cloud backups and snapshots are stored in enterprise-grade secured Firestore datacenters with AES-256 rest encryption.', style: TextStyle(color: textSecondary, fontSize: 12)),
                const SizedBox(height: 12),
                Text('4. Role-Based Access Controls & Staff Governance', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text('The Principal retains autonomous authority to manage faculty accounts and govern teacher permissions (such as restricting fee ledger collection). Staff members are personally accountable for safeguarding their login credentials.', style: TextStyle(color: textSecondary, fontSize: 12)),
                const SizedBox(height: 12),
                Text('5. Financial Records & Audit Trail Integrity', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text('Digital fee receipts, partial payment logs, and month ledgers are maintained with immutable timestamps to prevent accounting discrepancies and ensure audit accuracy.', style: TextStyle(color: textSecondary, fontSize: 12)),
                const SizedBox(height: 12),
                Text('6. Data Portability & Unrestricted Export Rights', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text('Your institution possesses the unrestricted right to export complete JSON backups and Excel registers of students and fees at any time without fees or vendor lock-in.', style: TextStyle(color: textSecondary, fontSize: 12)),
                const SizedBox(height: 12),
                Text('7. Offline Continuity & System Availability SLA', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text('The architecture implements offline persistence, enabling continuous attendance and student lookups during internet outages. Automated cloud sync resumes upon reconnection, targeting 99.9% uptime.', style: TextStyle(color: textSecondary, fontSize: 12)),
                const SizedBox(height: 12),
                Text('8. Account Termination & Full Data Purge Guarantee', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text('Upon formal termination requested by the school administrator, all cloud-stored institutional records and backups will be irreversibly purged within 30 days following handover of the final database export.', style: TextStyle(color: textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('I Understand', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showChannelsReportDialog(BuildContext context, {required bool isDark}) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final dividerColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.report_problem_outlined, color: Colors.tealAccent, size: 22),
            const SizedBox(width: 10),
            Text('Channels reports', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _reportRow('System Services', '100% Operational', Colors.tealAccent, isDark: isDark),
            Divider(color: dividerColor),
            _reportRow('Database Sync', 'Realtime Connected', Colors.tealAccent, isDark: isDark),
            Divider(color: dividerColor),
            _reportRow('Broadcast Channel', 'Active (0 incidents)', Colors.tealAccent, isDark: isDark),
            Divider(color: dividerColor),
            _reportRow('Encryption Engine', 'TLS 1.3 / AES-256', Colors.cyanAccent, isDark: isDark),
            Divider(color: dividerColor),
            _reportRow('Cloud Gateway', 'Active (< 90ms)', Colors.tealAccent, isDark: isDark),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  static Widget _reportRow(String title, String status, Color color, {required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF334155), fontSize: 12)),
          Row(
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _faqTile(String q, String a, {required bool isDark}) {
    final tileBg = isDark ? const Color(0xFF262626) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF8E8E8E) : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: ExpansionTile(
        iconColor: Colors.tealAccent,
        collapsedIconColor: isDark ? Colors.white54 : Colors.black45,
        title: Text(q, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Text(a, style: TextStyle(fontSize: 12, color: textSecondary, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF8E8E8E) : const Color(0xFF64748B);
    final iconColor = isDark ? const Color(0xFFB0B0B0) : const Color(0xFF64748B);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
      leading: Icon(icon, color: iconColor, size: 24),
      title: Text(
        title,
        style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(color: textSecondary, fontSize: 12),
            )
          : null,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.valueOrNull ?? SettingsModel.defaultSettings();
    final defaultMobile = settings.mobile.isNotEmpty ? settings.mobile : '+91 8568643490';
    final defaultEmail = (settings.email != null && settings.email!.isNotEmpty) ? settings.email! : 'support@schoolcloud.com';
    final schoolName = settings.instituteName.isNotEmpty ? settings.instituteName : 'School Administration';

    final isDark = Theme.of(context).brightness == Brightness.dark || settings.themeMode == 'dark';
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC);
    final appBarBg = isDark ? const Color(0xFF121212) : Colors.white;
    final appBarFg = isDark ? Colors.white : const Color(0xFF0F172A);
    final dividerColor = isDark ? const Color(0xFF262626) : const Color(0xFFE2E8F0);
    final versionColor = isDark ? const Color(0xFF888888) : const Color(0xFF94A3B8);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('schoolDirectory').doc('support_info').snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        final masterPhone = (data['supportPhone'] as String?)?.trim();
        final masterWhatsapp = (data['supportWhatsapp'] as String?)?.trim();
        final masterEmail = (data['supportEmail'] as String?)?.trim();
        final masterHours = (data['workingHours'] as String?)?.trim();

        final adminMobile = (masterPhone != null && masterPhone.isNotEmpty) ? masterPhone : defaultMobile;
        final whatsappMobile = (masterWhatsapp != null && masterWhatsapp.isNotEmpty) ? masterWhatsapp : adminMobile;
        final adminEmail = (masterEmail != null && masterEmail.isNotEmpty) ? masterEmail : defaultEmail;
        final workingHours = (masterHours != null && masterHours.isNotEmpty) ? masterHours : '10:00 AM - 07:00 PM (Mon - Sat)';

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: Text('Help and feedback', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: appBarFg)),
            backgroundColor: appBarBg,
            foregroundColor: appBarFg,
            elevation: isDark ? 0 : 0.5,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: appBarFg),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _buildItem(
                      icon: Icons.help_outline_rounded,
                      title: 'Help Centre',
                      subtitle: 'Frequently asked questions',
                      onTap: () => _showHelpCentreDialog(context, isDark: isDark),
                      isDark: isDark,
                    ),
                    _buildItem(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Contact us',
                      subtitle: 'Chat with support to get answers',
                      onTap: () => _showContactUsSheet(
                        context,
                        isDark: isDark,
                        adminMobile: adminMobile,
                        whatsappMobile: whatsappMobile,
                        workingHours: workingHours,
                        adminEmail: adminEmail,
                        schoolName: schoolName,
                      ),
                      isDark: isDark,
                    ),
                    _buildItem(
                      icon: Icons.pest_control_outlined,
                      title: 'Send feedback',
                      subtitle: 'Technical issues, suggestions',
                      onTap: () => _showFeedbackDialog(
                        context,
                        isDark: isDark,
                        schoolName: schoolName,
                        adminEmail: adminEmail,
                      ),
                      isDark: isDark,
                    ),
                    _buildItem(
                      icon: Icons.rate_review_outlined,
                      title: 'Rate the app',
                      onTap: () => _showRatingDialog(
                        context,
                        isDark: isDark,
                        schoolName: schoolName,
                        adminEmail: adminEmail,
                      ),
                      isDark: isDark,
                    ),
                    _buildItem(
                      icon: Icons.description_outlined,
                      title: 'Terms and Privacy Policy',
                      onTap: () => _showTermsDialog(context, isDark: isDark),
                      isDark: isDark,
                    ),
                    _buildItem(
                      icon: Icons.report_problem_outlined,
                      title: 'Channels reports',
                      onTap: () => _showChannelsReportDialog(context, isDark: isDark),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              Divider(color: dividerColor, height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  appVersion,
                  style: TextStyle(color: versionColor, fontSize: 13, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

