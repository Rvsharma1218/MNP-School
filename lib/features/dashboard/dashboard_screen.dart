import '../../data/services/auth_service.dart';
import '../../data/services/firestore_service.dart';
import 'online_enquiries_screen.dart';
import '../../core/localization/app_translations.dart';
import '../security/security_verification_dialog.dart';
import '../security/device_security_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/student_model.dart';
import '../../data/models/settings_model.dart';
import '../../data/services/providers.dart';
import '../../data/services/session_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/responsive_web_layout.dart';
import '../teachers/teacher_management_screen.dart';
import '../teachers/teacher_settings_screen.dart';
import '../attendance/teacher_attendance_screen.dart';
import '../attendance/teacher_punch_in_card.dart';
import '../teachers/teacher_role_access_screen.dart';
import 'all_modules_screen.dart';
import 'school_status_screen.dart';
import '../settings/settings_screen.dart';
import '../notice/notice_screen.dart';
import '../../data/services/teacher_permissions_service.dart';
import 'principal_complaints_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentTabIndex = 0;
  final List<int> _tabHistory = [0];
  final Set<int> _builtTabs = {0}; // Only build tabs when first visited

  void _switchTab(int newIndex) {
    if (_currentTabIndex == newIndex) return;
    setState(() {
      _builtTabs.add(newIndex);
      _tabHistory.add(newIndex);
      _currentTabIndex = newIndex;
    });
  }

  DateTime? _lastBackPressTime;

  void _showPermissionLockedDialog(BuildContext context, String moduleName) {
    final lang = ref.read(appLanguageProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lock_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 8),
            Text(AppTranslations.tr('access_denied', lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          lang == 'hi'
              ? 'प्रिंसिपल द्वारा "$moduleName" की अनुमति नहीं दी गई है। कृपया स्कूल एडमिनिस्ट्रेशन से संपर्क करें।'
              : 'Permission for "$moduleName" has not been granted by the School Principal. Please contact administration.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleBackPress() {
    if (_tabHistory.length > 1) {
      setState(() {
        _tabHistory.removeLast();
        _currentTabIndex = _tabHistory.last;
      });
      return;
    }
    if (_currentTabIndex != 0) {
      setState(() {
        _currentTabIndex = 0;
        _tabHistory.clear();
        _tabHistory.add(0);
      });
      return;
    }

    final now = DateTime.now();
    if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit app'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    SystemNavigator.pop();
  }
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  StreamSubscription? _securityRevokeSub;

  @override
  void initState() {
    super.initState();
    // Update live clock every minute
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    // Initialize teacher's working class/section from session assignment
    if (SessionService.instance.isTeacher) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final assignedClass = SessionService.instance.assignedClass ?? '';
        final assignedSection = SessionService.instance.assignedSection ?? '';
        // Only set if not already set (e.g. teacher may have changed it)
        if (ref.read(teacherSelectedClassProvider).isEmpty && assignedClass.isNotEmpty) {
          ref.read(teacherSelectedClassProvider.notifier).state = assignedClass;
          ref.read(classFilterProvider.notifier).state = assignedClass;
        }
        if (ref.read(teacherSelectedSectionProvider).isEmpty && assignedSection.isNotEmpty) {
          ref.read(teacherSelectedSectionProvider.notifier).state = assignedSection;
          ref.read(sectionFilterProvider.notifier).state = assignedSection;
        }
      });
    }

    // Listen for remote session revocation
    _securityRevokeSub = DeviceSecurityService.instance.onSessionRevoked.listen((isRevoked) {
      if (mounted && isRevoked) {
        SecurityVerificationDialog.showIfNeeded(context);
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _securityRevokeSub?.cancel();
    super.dispose();
  }

  String _getUserDisplayName(bool isPrincipal, SettingsModel settings) {
    if (isPrincipal) {
      if (settings.principalName?.isNotEmpty == true) return settings.principalName!;
      if (settings.instituteName.isNotEmpty) return settings.instituteName;
      return 'Principal / Admin';
    }
    return SessionService.instance.teacherName ?? 'Teacher';
  }

  String _getUserInitials(bool isPrincipal, SettingsModel settings) {
    final name = _getUserDisplayName(isPrincipal, settings).trim();
    if (name.isEmpty) return isPrincipal ? 'AD' : 'TC';
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    if (name.length >= 2) {
      return name.substring(0, 2).toUpperCase();
    }
    return name[0].toUpperCase();
  }

  void _showAccountDialog(BuildContext context, SettingsModel settings, bool isPrincipal) {
    final userName = _getUserDisplayName(isPrincipal, settings);
    // Use the actual Firebase Auth email for principal, teacher ID label for teachers
    final userEmail = SessionService.instance.isPrincipal
        ? (FirebaseAuth.instance.currentUser?.email?.isNotEmpty == true
            ? FirebaseAuth.instance.currentUser!.email!
            : (settings.email?.isNotEmpty == true ? settings.email! : 'Not set'))
        : '${SessionService.instance.teacherId ?? 'Teacher'}  ·  ${SessionService.instance.teacherName ?? ''}';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Avatar & Details
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      _getUserInitials(isPrincipal, settings),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userEmail,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE9FE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isPrincipal ? 'ADMIN ACCESS' : 'TEACHER ACCESS',
                            style: const TextStyle(
                              color: Color(0xFF6D28D9),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 4),

              // Menu Item 1: My Profile
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 22),
                title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  Navigator.pop(ctx);
                  _showProfileDetails(context, settings, isPrincipal);
                },
              ),

              // Menu Item 2: Account Settings
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.settings_outlined, color: AppColors.primary, size: 22),
                title: const Text('Account Settings', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (isPrincipal) {
                    await Navigator.pushNamed(context, AppRoutes.settings);
                    ref.read(settingsProvider.notifier).load();
                  } else {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TeacherSettingsScreen()),
                    );
                  }
                },
              ),

              // Menu Item 3: Change Password
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.key_outlined, color: AppColors.primary, size: 22),
                title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  Navigator.pop(ctx);
                  _showChangePasswordDialog(context, isPrincipal);
                },
              ),

              const SizedBox(height: 4),
              const Divider(),
              const SizedBox(height: 4),

              // Menu Item 4: Logout
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout_rounded, color: AppColors.error, size: 22),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await SessionService.instance.clear();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (r) => false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileDetails(BuildContext context, SettingsModel settings, bool isPrincipal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.badge_outlined, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(isPrincipal ? 'Institute Profile' : 'Teacher Profile'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileRow('Name', _getUserDisplayName(isPrincipal, settings)),
            _buildProfileRow('School ID', SessionService.instance.activeSchoolId),
            if (isPrincipal) ...[
              _buildProfileRow('Institute', settings.instituteName),
              _buildProfileRow('Mobile', settings.mobile),
              if (settings.email?.isNotEmpty == true) _buildProfileRow('Email', settings.email!),
              if (settings.address.isNotEmpty) _buildProfileRow('Address', settings.address),
              _buildProfileRow('Session', settings.currentSession),
            ] else ...[
              _buildProfileRow('Role', 'Faculty / Teacher'),
              _buildProfileRow('Assigned Class', SessionService.instance.assignedClass ?? 'General'),
              _buildProfileRow('Section', SessionService.instance.assignedSection ?? 'A'),
            ],
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showChangePasswordDialog(context, isPrincipal);
            },
            icon: const Icon(Icons.key_rounded, size: 16),
            label: const Text('Change Password'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, bool isPrincipal) {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSubmitting = false;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          actionsPadding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.key_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Change Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text('Update your login security credentials', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (errorText != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 16, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text('Current Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(
                  controller: currentPassCtrl,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    hintText: 'Enter current password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                      onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('New Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(
                  controller: newPassCtrl,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    hintText: 'Minimum 6 characters',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    prefixIcon: const Icon(Icons.lock_reset_rounded, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Confirm New Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(
                  controller: confirmPassCtrl,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    hintText: 'Re-enter new password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    prefixIcon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                      onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final currentPass = currentPassCtrl.text.trim();
                      final newPass = newPassCtrl.text.trim();
                      final confirmPass = confirmPassCtrl.text.trim();

                      if (currentPass.isEmpty) {
                        setDialogState(() => errorText = 'Please enter your current password.');
                        return;
                      }
                      if (newPass.length < 6) {
                        setDialogState(() => errorText = 'New password must be at least 6 characters long.');
                        return;
                      }
                      if (newPass != confirmPass) {
                        setDialogState(() => errorText = 'New passwords do not match.');
                        return;
                      }

                      setDialogState(() {
                        isSubmitting = true;
                        errorText = null;
                      });

                      try {
                        await AuthService.instance.changePassword(
                          currentPassword: currentPass,
                          newPassword: newPass,
                        );

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password updated successfully!'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSubmitting = false;
                          errorText = AuthService.instance.friendlyError(e);
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Update Password', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyModuleTile({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final cs = Theme.of(context).colorScheme;
    final isPrincipal = SessionService.instance.isPrincipal;
    final perms = ref.watch(teacherPermissionsProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 850;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final settings = settingsAsync.valueOrNull ?? SettingsModel.defaultSettings();
    final instituteName = settings.instituteName.isNotEmpty ? settings.instituteName : 'My Institute';
    final logoPath = settings.logoPath;
    final session = 'Session: ${settings.currentSession}';

    if (isDesktop) {
      return ResponsiveWebLayout(
        title: 'Dashboard Overview',
        currentRoute: AppRoutes.dashboard,
        floatingActionButton: (isPrincipal || perms.canAddStudents) ? FloatingActionButton(
          heroTag: 'desktop_dashboard_add_student_fab',
          tooltip: 'Add Student',
          onPressed: () async {
            await Navigator.pushNamed(context, AppRoutes.addStudent);
            ref.read(studentsProvider.notifier).loadStudents();
            ref.invalidate(dashboardStatsProvider);
          },
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          child: const Icon(Icons.person_add_alt_1_rounded, size: 24),
        ) : null,
        body: _WebDashboardView(statsAsync: statsAsync, isPrincipal: isPrincipal),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
      backgroundColor: cs.background,
      floatingActionButton: _currentTabIndex == 0 && (isPrincipal || perms.canAddStudents) ? FloatingActionButton(
        heroTag: 'dashboard_add_student_fab',
        tooltip: 'Add Student',
        onPressed: () async {
          await Navigator.pushNamed(context, AppRoutes.addStudent);
          ref.read(studentsProvider.notifier).loadStudents();
          ref.invalidate(dashboardStatsProvider);
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.person_add_alt_1_rounded, size: 24),
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.read(studentsProvider.notifier).loadStudents();
        },
        child: CustomScrollView(
          slivers: [
            // ─── Header SliverAppBar ─────────────────────────────────────
            SliverAppBar(
              expandedHeight: 230,
              pinned: true,
              stretch: true,
              backgroundColor: AppColors.primary,
              actions: [
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.qrScanner),
                  tooltip: 'Scan QR',
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: Colors.white),
                  onPressed: () => _switchTab(2),
                ),
                if (isPrincipal)
                  IconButton(
                    icon: const Icon(Icons.assignment_ind_outlined, color: Colors.white),
                    tooltip: 'Online Enquiries & Admissions Desk',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OnlineEnquiriesScreen()),
                    ),
                  ),
                if (isPrincipal)
                  IconButton(
                    icon: const Icon(Icons.mark_chat_unread_outlined, color: Colors.white),
                    tooltip: 'Parent Complaints',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PrincipalComplaintsScreen()),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Colors.white),
                  tooltip: 'Settings',
                  onPressed: () => _switchTab(3),
                ),
                // ─── Account Profile Badge (matching website Image 1) ─────────
                Padding(
                  padding: const EdgeInsets.only(right: 12, left: 4),
                  child: InkWell(
                    onTap: () => _showAccountDialog(context, settings, isPrincipal),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white38, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: Center(
                              child: Text(
                                _getUserInitials(isPrincipal, settings),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 110),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getUserDisplayName(isPrincipal, settings),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                Text(
                                  isPrincipal ? 'Principal / Admin' : 'Teacher',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 9,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF040E1E),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF051329),
                        Color(0xFF081E3E),
                        Color(0xFF030B17),
                      ],
                    ),
                    image: DecorationImage(
                      image: const AssetImage('assets/images/header_campus_bg.jpg'),
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      opacity: 0.16,
                      colorFilter: ColorFilter.mode(
                        const Color(0xFF040E1E).withValues(alpha: 0.70),
                        BlendMode.darken,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _LiveDateTimeWidget(now: _now),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.40),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1),
                            ),
                            child: Row(
                              children: [
                                _buildLogoWidget(logoPath),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        instituteName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.2,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black87,
                                              offset: Offset(0, 1),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        session,
                                        style: const TextStyle(
                                          color: Color(0xFFFFD54F),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Builder(
                            builder: (context) {
                              final stats = statsAsync.valueOrNull;
                              if (stats == null) return const SizedBox();
                              return Row(
                                children: [
                                  _headerStat(
                                      '${stats.isFiltered ? stats.totalStudents : stats.totalStudents}',
                                      stats.isFiltered ? (stats.filterLabel.isNotEmpty ? 'Students' : 'Students') : 'Students',
                                      Icons.people),

                                  // FIX: Hide Collected from Teachers
                                  if (isPrincipal) ...[
                                    const SizedBox(width: 20),
                                    _headerStat(
                                        AppUtils.formatCurrency(stats.totalCollected),
                                        'Collected',
                                        Icons.currency_rupee),
                                  ],

                                  const SizedBox(width: 20),
                                  _headerStat('${stats.presentToday}',
                                      'Present Today', Icons.check_circle_outline),

                                  // Show absent count in header for Teacher when filtered
                                  if (!isPrincipal && stats.isFiltered) ...[
                                    const SizedBox(width: 20),
                                    _headerStat('${stats.absentToday}',
                                        'Absent', Icons.cancel_outlined),
                                  ],
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ─── Body ─────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Builder(
                builder: (context) {
                  final stats = statsAsync.valueOrNull;
                  if (stats != null) {
                    return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (stats.overdueCount > 0 && isPrincipal) ...[
                        _OverdueAlert(count: stats.overdueCount),
                        const SizedBox(height: 16),
                      ],

                      // ─── Teacher Class/Section Selector ────────────────
                      if (!isPrincipal) ...[
                        _TeacherClassSectionSelector(),
                        const SizedBox(height: 16),
                      ],

                      // ─── Teacher: No Class Selected Placeholder ────────
                      if (!isPrincipal && !stats.isFiltered) ...[
                        _NoClassSelectedPlaceholder(),
                        const SizedBox(height: 16),
                      ],

                      // ─── Teacher: Filtered Stat Cards ──────────────────
                      if (!isPrincipal && stats.isFiltered) ...[
                        GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.6,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            StatCard(
                              title: 'Total Students',
                              value: '${stats.totalStudents}',
                              icon: Icons.people,
                              gradient: AppColors.gradientBlue,
                              onTap: () {
                                if (!isPrincipal && !perms.canViewStudents) {
                                  _showPermissionLockedDialog(context, 'Students Directory');
                                  return;
                                }
                                Navigator.pushNamed(context, AppRoutes.studentList);
                              },
                            ),
                            StatCard(
                              title: 'Present Today',
                              value: '${stats.presentToday}',
                              icon: Icons.check_circle_outline,
                              gradient: AppColors.gradientGreen,
                              onTap: () {
                                if (!isPrincipal && !perms.canMarkAttendance) {
                                  _showPermissionLockedDialog(context, 'Attendance');
                                  return;
                                }
                                Navigator.pushNamed(context, AppRoutes.attendance);
                              },
                            ),
                            StatCard(
                              title: 'Absent Today',
                              value: '${stats.absentToday}',
                              icon: Icons.cancel_outlined,
                              gradient: AppColors.gradientRed,
                              onTap: () {
                                if (!isPrincipal && !perms.canMarkAttendance) {
                                  _showPermissionLockedDialog(context, 'Attendance');
                                  return;
                                }
                                Navigator.pushNamed(context, AppRoutes.attendance);
                              },
                            ),
                            StatCard(
                              title: 'On Leave',
                              value: '${stats.leaveToday}',
                              icon: Icons.event_busy_outlined,
                              gradient: AppColors.gradientOrange,
                              onTap: () {
                                if (!isPrincipal && !perms.canMarkAttendance) {
                                  _showPermissionLockedDialog(context, 'Attendance');
                                  return;
                                }
                                Navigator.pushNamed(context, AppRoutes.attendance);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ─── Teacher Campus GPS Punch-In Card (Teachers Only) ───
                      if (!isPrincipal) ...[
                        const TeacherPunchInCard(),
                        const SizedBox(height: 14),
                      ],

                      // ─── Exact Mockup Match: Quick Pills & Financial Summary ───
                      if (isPrincipal) ...[
                        // "?"?"? BIG PROMINENT FEATURE CARDS: Students & Computer "?"?"?
                        Row(
                          children: [
                            // 1. Big School Students Card
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  ref.read(studentFilterProvider.notifier).state = 'school';
                                  Navigator.pushNamed(context, AppRoutes.studentList);
                                },
                                borderRadius: BorderRadius.circular(18),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF2563EB).withValues(alpha: 0.28),
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
                                          Container(
                                            padding: const EdgeInsets.all(9),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.school_rounded, color: Colors.white, size: 22),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Text('REGULAR', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        '${stats.totalStudents}',
                                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'School Students',
                                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Tap to view all classes →',
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 10.5, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // 2. Big Computer Students Card
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  ref.read(studentFilterProvider.notifier).state = 'computer';
                                  Navigator.pushNamed(context, AppRoutes.studentList);
                                },
                                borderRadius: BorderRadius.circular(18),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0D9488).withValues(alpha: 0.28),
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
                                          Container(
                                            padding: const EdgeInsets.all(9),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.computer_rounded, color: Colors.white, size: 22),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Text('VOCATIONAL', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Courses',
                                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Computer Institute',
                                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'DCA, ADCA, Tally →',
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 10.5, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // "?"?"? COMPACT SLEEK CARDS: Fees Collected & Fees Pending "?"?"?
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => Navigator.pushNamed(context, AppRoutes.feesCollected),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7).withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                                        child: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFD97706), size: 15),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Collected', style: TextStyle(fontSize: 10, color: Color(0xFF92400E), fontWeight: FontWeight.w600)),
                                            Text(AppUtils.formatCurrency(stats.totalCollected), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF78350F))),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkWell(
                                onTap: () => Navigator.pushNamed(context, AppRoutes.feesPending),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2).withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFFECACA)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                                        child: const Icon(Icons.pending_actions_rounded, color: Color(0xFFDC2626), size: 15),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Pending', style: TextStyle(fontSize: 10, color: Color(0xFFB91C1C), fontWeight: FontWeight.w600)),
                                            Text(AppUtils.formatCurrency(stats.totalPending), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // ─── Online Admission & Recruitment Desk Card (Principal Only) ───
                        _buildOnlineEnquiriesCard(context, isPrincipal),
                        const SizedBox(height: 14),
                        // ─── Live Parent Complaints & Desk Card (Principal Only) ───
                        _buildParentComplaintsCard(context, isPrincipal),
                        const SizedBox(height: 14),

                        // ─── Key Modules Section (Matching Left Phone) ───
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Key Modules', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF0F172A))),
                            InkWell(
                              onTap: () => _switchTab(1),
                              child: const Row(
                                children: [
                                  Text('See All', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 13)),
                                  SizedBox(width: 2),
                                  Icon(Icons.chevron_right_rounded, color: Color(0xFF2563EB), size: 18),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // 2x2 Grid of Key Modules
                        GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 2.1,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            // 1. Student Attendance (Purple)
                            _buildKeyModuleTile(
                              title: 'Student Attendance',
                              icon: Icons.calendar_month_rounded,
                              iconColor: const Color(0xFF7C3AED),
                              iconBg: const Color(0xFFEDE9FE),
                              onTap: () {
                                if (!isPrincipal && !perms.canMarkAttendance) {
                                  _showPermissionLockedDialog(context, 'Attendance');
                                  return;
                                }
                                Navigator.pushNamed(context, AppRoutes.attendance);
                              },
                            ),
                            // 2. Collect Fee (Pink)
                            _buildKeyModuleTile(
                              title: 'Collect Fee',
                              icon: Icons.account_balance_wallet_rounded,
                              iconColor: const Color(0xFFD946EF),
                              iconBg: const Color(0xFFFAE8FF),
                              onTap: () {
                                if (!isPrincipal && !perms.canCollectFees) {
                                  _showPermissionLockedDialog(context, 'Fee Collection');
                                  return;
                                }
                                Navigator.pushNamed(context, AppRoutes.feesCollected);
                              },
                            ),
                            // 3. Students (Blue)
                            _buildKeyModuleTile(
                              title: 'Students',
                              icon: Icons.people_alt_rounded,
                              iconColor: const Color(0xFF2563EB),
                              iconBg: const Color(0xFFDBEAFE),
                              onTap: () {
                                if (!isPrincipal && !perms.canViewStudents) {
                                  _showPermissionLockedDialog(context, 'Students Directory');
                                  return;
                                }
                                Navigator.pushNamed(context, AppRoutes.studentList);
                              },
                            ),
                            // 4. Notice (Yellow)
                            _buildKeyModuleTile(
                              title: 'Notice',
                              icon: Icons.notifications_rounded,
                              iconColor: const Color(0xFFEAB308),
                              iconBg: const Color(0xFFFEF9C3),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const NoticeScreen()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ─── Charts (Principal only or both when relevant) ─
                      if (stats.monthlyCollection.isNotEmpty && isPrincipal) ...[
                        _MonthlyChart(data: stats.monthlyCollection),
                        const SizedBox(height: 16),
                      ],
                      // Class distribution: show for principal always;
                      // for teacher only when NOT filtered (filtered view
                      // would show whole-school chart which is misleading).
                      if (stats.studentsByClass.isNotEmpty && isPrincipal) ...[
                        _ClassDistributionChart(data: stats.studentsByClass),
                        const SizedBox(height: 16),
                      ],
                      if (stats.studentsByCourse.isNotEmpty && isPrincipal) ...[
                        _CourseDistributionChart(data: stats.studentsByCourse),
                        const SizedBox(height: 16),
                      ],

                      // ─── School Live Status Quick Banner ─────────────────────────
                      InkWell(
                        onTap: () {
                          if (!isPrincipal && !perms.canViewSchoolStatus) {
                            _showPermissionLockedDialog(context, 'School Status');
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SchoolStatusScreen()),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'School Daily Status • Real-Time Health',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? const Color(0xFF34D399) : const Color(0xFF065F46),
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF10B981)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const SizedBox(height: 80),
                    ],
                  ),
                );
              }
              if (statsAsync.isLoading) {
                return const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: LoadingWidget(message: 'Loading dashboard...'),
                );
              }
              if (statsAsync.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text('Error: ${statsAsync.error}', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () =>
                              ref.invalidate(dashboardStatsProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ),
          ],
        ),
      ),
      // Lazy-load: don't build these tabs until user navigates to them
      _builtTabs.contains(1) ? const AllModulesScreen(isEmbedded: true) : const SizedBox.shrink(),
      _builtTabs.contains(2) ? const NoticeScreen() : const SizedBox.shrink(),
      _builtTabs.contains(3) ? (isPrincipal ? const SettingsScreen() : const TeacherSettingsScreen()) : const SizedBox.shrink(),
    ],
  ),
  bottomNavigationBar: Container(
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 10,
          offset: const Offset(0, -2),
        ),
      ],
      border: Border(
        top: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
    ),
    child: NavigationBar(
      selectedIndex: _currentTabIndex,
      onDestinationSelected: (idx) => _switchTab(idx),
      backgroundColor: Colors.transparent,
      indicatorColor: AppColors.primary.withOpacity(0.15),
      destinations: [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
          label: AppTranslations.tr('nav_dashboard', ref.watch(appLanguageProvider)),
        ),
        NavigationDestination(
          icon: Icon(Icons.grid_view_outlined),
          selectedIcon: Icon(Icons.grid_view_rounded, color: AppColors.primary),
          label: AppTranslations.tr('nav_more', ref.watch(appLanguageProvider)),
        ),
        NavigationDestination(
          icon: Icon(Icons.campaign_outlined),
          selectedIcon: Icon(Icons.campaign_rounded, color: AppColors.primary),
          label: AppTranslations.tr('notice_board', ref.watch(appLanguageProvider)),
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings_rounded, color: AppColors.primary),
          label: AppTranslations.tr('settings', ref.watch(appLanguageProvider)),
        ),
      ],
    ),
  ),
),
);
}

  
  static Widget _buildCompactHomeModule({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildLogoWidget(String? logoPath) {
    if (logoPath != null && logoPath.isNotEmpty) {
      if (logoPath.startsWith('http://') || logoPath.startsWith('https://')) {
        return Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              logoPath,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.school, color: Colors.white, size: 30),
              ),
            ),
          ),
        );
      }
      if (logoPath.startsWith('data:image')) {
        try {
          final base64String = logoPath.split(',').last;
          final bytes = base64Decode(base64String);
          return Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(bytes, fit: BoxFit.cover),
            ),
          );
        } catch (_) {}
      }
      final file = File(logoPath);
      if (file.existsSync()) {
        return Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(file, fit: BoxFit.cover),
          ),
        );
      }
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.school, color: Colors.white, size: 30),
    );
  }

  Widget _headerStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Row(children: [
          Icon(icon, color: Colors.white70, size: 13),
          const SizedBox(width: 3),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
        ]),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7), fontSize: 10)),
      ],
    );
  }

  Widget _buildOnlineEnquiriesCard(BuildContext context, bool isPrincipal) {
    if (!isPrincipal) return const SizedBox.shrink();

    final admStream = FirestoreService.instance.watchAdmissionEnquiries();
    final teachStream = FirestoreService.instance.watchTeacherApplications();

    if (admStream == null && teachStream == null) return const SizedBox.shrink();

    final initAdm = FirestoreService.instance.cachedAdmissionsList;
    final initTeach = FirestoreService.instance.cachedTeachersList;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: admStream,
      initialData: initAdm.isNotEmpty ? initAdm : null,
      builder: (context, admSnap) {
        final admissions = admSnap.data ?? initAdm;
        final pendingAdm = admissions.where((i) => (i['status'] ?? 'pending').toString().toLowerCase() == 'pending').length;

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: teachStream,
          initialData: initTeach.isNotEmpty ? initTeach : null,
          builder: (context, teachSnap) {
            final teachers = teachSnap.data ?? initTeach;
            final pendingTeach = teachers.where((i) => (i['status'] ?? 'pending').toString().toLowerCase() == 'pending').length;
            final totalPending = pendingAdm + pendingTeach;
            final totalAll = admissions.length + teachers.length;

            return InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OnlineEnquiriesScreen()),
              ),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: totalPending > 0 ? const Color(0xFF38BDF8).withValues(alpha: 0.6) : const Color(0xFF1E293B),
                    width: totalPending > 0 ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (totalPending > 0 ? const Color(0xFF0284C7) : Colors.black).withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: (totalPending > 0 ? const Color(0xFF38BDF8) : const Color(0xFF64748B)).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.assignment_ind_rounded,
                        color: totalPending > 0 ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Online Enquiries Desk',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                  ),
                                ),
                              ),
                              if (totalPending > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amberAccent.shade700,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$totalPending NEW',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            totalPending > 0
                                ? '$pendingAdm Pending Admissions · $pendingTeach Faculty Applications'
                                : (totalAll > 0 ? '$totalAll Applications received from website' : 'View online admissions & teacher applications'),
                            style: TextStyle(
                              color: totalPending > 0 ? const Color(0xFFBAE6FD) : Colors.white60,
                              fontSize: 12,
                              fontWeight: totalPending > 0 ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 14),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildParentComplaintsCard(BuildContext context, bool isPrincipal) {
    if (!isPrincipal) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('feedbacks').snapshots(),
      builder: (context, snapshot) {
        int pendingCount = 0;
        int urgentCount = 0;

        if (snapshot.hasData) {
          final activeSchool = SessionService.instance.activeSchoolId.toLowerCase();
          for (final doc in snapshot.data!.docs) {
            final d = doc.data() as Map<String, dynamic>;
            final sId = (d['schoolId'] ?? '').toString().toLowerCase();
            final isParent = d['type'] == 'parent_complaint' || d['studentId'] != null;
            if (isParent && (sId.isEmpty || sId == activeSchool || sId.contains('school_') || activeSchool.contains('007'))) {
              final status = (d['status'] ?? 'new').toString().toLowerCase();
              if (status != 'resolved') {
                pendingCount++;
                if (d['priority'] == 'urgent' || d['urgent'] == true) urgentCount++;
              }
            }
          }
        }

        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PrincipalComplaintsScreen()),
          ),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: urgentCount > 0 ? const Color(0xFFEF4444).withValues(alpha: 0.6) : const Color(0xFF334155),
                width: urgentCount > 0 ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: (urgentCount > 0 ? const Color(0xFFEF4444) : Colors.black).withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: (urgentCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF3B82F6)).withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mark_chat_unread_rounded,
                    color: urgentCount > 0 ? const Color(0xFFF87171) : const Color(0xFF60A5FA),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Parent Complaints & Desk',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (urgentCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'URGENT',
                                style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        pendingCount > 0
                            ? '$pendingCount pending complaints awaiting review'
                            : 'All parent messages & complaints resolved',
                        style: TextStyle(
                          color: pendingCount > 0 ? const Color(0xFFFBBF24) : const Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: pendingCount > 0 ? const Color(0xFFF59E0B).withValues(alpha: 0.2) : Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: pendingCount > 0 ? const Color(0xFFF59E0B).withValues(alpha: 0.4) : Colors.white24,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pendingCount > 0 ? '$pendingCount New' : 'View',
                        style: TextStyle(
                          color: pendingCount > 0 ? const Color(0xFFFDE68A) : Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OverdueAlert extends StatelessWidget {
  final int count;
  const _OverdueAlert({required this.count});


  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                shape: BoxShape.circle),
            child: const Icon(Icons.warning_rounded,
                color: AppColors.error, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count Overdue Fee${count > 1 ? 's' : ''}',
                    style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                const Text('Students with past-due fee dates',
                    style: TextStyle(color: AppColors.error, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.error),
        ],
      ),
    );
  }
}

/// Shown on the Teacher dashboard when no class/section has been selected yet.
/// Guides the teacher to use the selector above to activate filtered stats.
class _NoClassSelectedPlaceholder extends StatelessWidget {
  const _NoClassSelectedPlaceholder();


  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.filter_list_rounded,
                color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            'Select Your Class & Section',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use the selector above to choose your assigned class and section.\nDashboard statistics will update automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _MonthlyChart({required this.data});


  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final values =
    data.map((d) => (d['total'] as num).toDouble()).toList();
    final months = data.map((d) => d['month'] as String).toList();
    final maxY = values.isEmpty
        ? 1000.0
        : values.reduce((a, b) => a > b ? a : b) * 1.25;

    return Card(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.bar_chart,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text('Monthly Fee Collection',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: cs.onSurface)),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                        AppUtils.formatCurrency(rod.toY),
                        const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 11),
                      ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, _) {
                          final i = val.toInt();
                          if (i < 0 || i >= months.length) {
                            return const SizedBox();
                          }
                          final parts = months[i].split('-');
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              parts.length >= 2
                                  ? _monthAbbr(int.tryParse(parts[1]) ?? 1)
                                  : months[i],
                              style: TextStyle(
                                  fontSize: 9, color: cs.onSurfaceVariant),
                            ),
                          );
                        },
                        reservedSize: 24,
                      ),
                    ),
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: cs.outlineVariant, strokeWidth: 0.8),
                  ),
                  barGroups: List.generate(
                    values.length,
                        (i) => BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: values[i],
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        width: 18,
                        borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(5)),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _monthAbbr(int m) {
    const abbr = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return m >= 1 && m <= 12 ? abbr[m] : '';
  }
}

class _ClassDistributionChart extends StatelessWidget {
  final Map<String, int> data;
  const _ClassDistributionChart({required this.data});


  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entries = data.entries.toList();
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    final colors = [
      AppColors.primary, AppColors.secondary, AppColors.success,
      AppColors.warning, Colors.purple, Colors.teal,
      Colors.pink, Colors.orange, Colors.indigo, Colors.cyan,
      Colors.red, Colors.green,
    ];

    return Card(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.pie_chart,
                    color: AppColors.secondary, size: 18),
              ),
              const SizedBox(width: 10),
              Text('Students by Class',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: cs.onSurface)),
            ]),
            const SizedBox(height: 14),
            Row(
              children: [
                SizedBox(
                  height: 140,
                  width: 140,
                  child: PieChart(
                    PieChartData(
                      sections: List.generate(entries.length, (i) {
                        final e = entries[i];
                        final pct =
                        total > 0 ? e.value / total * 100 : 0.0;
                        return PieChartSectionData(
                          value: e.value.toDouble(),
                          title: '${pct.toStringAsFixed(0)}%',
                          color: colors[i % colors.length],
                          radius: 50,
                          titleStyle: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        );
                      }),
                      sectionsSpace: 2,
                      centerSpaceRadius: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 6,
                    children: List.generate(entries.length, (i) {
                      final e = entries[i];
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                  color: colors[i % colors.length],
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text('Cls ${e.key}: ${e.value}',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: cs.onSurfaceVariant)),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseDistributionChart extends StatelessWidget {
  final Map<String, int> data;
  const _CourseDistributionChart({required this.data});


  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entries = data.entries.toList();
    final maxVal = entries.isEmpty
        ? 1
        : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final colors = [
      AppColors.success, AppColors.warning, Colors.purple,
      Colors.teal, Colors.pink, Colors.indigo
    ];

    return Card(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.computer,
                    color: AppColors.success, size: 18),
              ),
              const SizedBox(width: 10),
              Text('Students by Course',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: cs.onSurface)),
            ]),
            const SizedBox(height: 14),
            ...List.generate(entries.length, (i) {
              final e = entries[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: cs.onSurface)),
                          Text('${e.value}',
                              style: TextStyle(
                                  color: cs.onSurfaceVariant, fontSize: 11)),
                        ]),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: e.value / maxVal,
                        minHeight: 8,
                        backgroundColor:
                        colors[i % colors.length].withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation(
                            colors[i % colors.length]),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 5),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

class _TeacherClassSectionSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final studentsAsync = ref.watch(studentsProvider);
    final selectedClass = ref.watch(teacherSelectedClassProvider);
    final selectedSection = ref.watch(teacherSelectedSectionProvider);

    // Extract unique classes and sections from loaded students
    final students = studentsAsync.valueOrNull ?? [];
    final classes = students
        .where((s) => s.studentType == 'school' && (s.className?.isNotEmpty == true))
        .map((s) => s.className!)
        .toSet()
        .toList()
      ..sort((a, b) {
        final ai = int.tryParse(a);
        final bi = int.tryParse(b);
        if (ai != null && bi != null) return ai.compareTo(bi);
        return a.compareTo(b);
      });
    final sections = students
        .where((s) => s.section?.isNotEmpty == true)
        .map((s) => s.section!)
        .toSet()
        .toList()
      ..sort();

    // If teacher has an assigned class or only 1 class available, don't show redundant selector
    final assignedClass = SessionService.instance.assignedClass;
    if ((assignedClass != null && assignedClass.isNotEmpty) || classes.length <= 1) {
      return const SizedBox.shrink();
    }

    return Card(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.class_outlined, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text('My Class & Section',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: cs.onSurface)),
            ]),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    context: context,
                    label: 'Class',
                    value: selectedClass.isEmpty ? null : selectedClass,
                    items: classes,
                    onChanged: (v) {
                      ref.read(teacherSelectedClassProvider.notifier).state = v ?? '';
                      // Also sync the global filter provider
                      ref.read(classFilterProvider.notifier).state = v ?? '';
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    context: context,
                    label: 'Section',
                    value: selectedSection.isEmpty ? null : selectedSection,
                    items: sections,
                    onChanged: (v) {
                      ref.read(teacherSelectedSectionProvider.notifier).state = v ?? '';
                      ref.read(sectionFilterProvider.notifier).state = v ?? '';
                    },
                  ),
                ),
              ],
            ),
            if (selectedClass.isNotEmpty || selectedSection.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.primary, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Working: ${selectedClass.isNotEmpty ? "Class $selectedClass" : "All Classes"}'
                          '${selectedSection.isNotEmpty ? " - Section $selectedSection" : ""}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required BuildContext context,
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    return DropdownButtonFormField<String>(
      value: value != null && items.contains(value) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      dropdownColor: cs.surface,
      isExpanded: true,
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('All', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
        ),
        ...items.map((c) => DropdownMenuItem<String>(
          value: c,
          child: Text(c, style: TextStyle(color: cs.onSurface, fontSize: 13)),
        )),
      ],
      onChanged: onChanged,
    );
  }
}

class _LiveDateTimeWidget extends StatelessWidget {
  final DateTime now;
  const _LiveDateTimeWidget({required this.now});


  @override
  Widget build(BuildContext context) {
    final dayName = DateFormat('EEEE').format(now);
    final dateStr = DateFormat('dd MMM yyyy').format(now);
    final timeStr = DateFormat('hh:mm a').format(now);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: Colors.white70, size: 13),
          const SizedBox(width: 5),
          Text(
            '$dayName, $dateStr',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          const Icon(Icons.access_time, color: Colors.white70, size: 13),
          const SizedBox(width: 5),
          Text(
            timeStr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ─── FULL WEB DESKTOP DASHBOARD ("SB SAMNE HOGA") ───────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _WebDashboardView extends ConsumerStatefulWidget {
  final AsyncValue<DashboardStats> statsAsync;
  final bool isPrincipal;

  const _WebDashboardView({
    required this.statsAsync,
    required this.isPrincipal,
  });

  @override
  ConsumerState<_WebDashboardView> createState() => _WebDashboardViewState();
}

class _WebDashboardViewState extends ConsumerState<_WebDashboardView> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selectedClass = ref.watch(teacherSelectedClassProvider);
    final selectedSection = ref.watch(teacherSelectedSectionProvider);
    final studentsAsync = ref.watch(studentsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardStatsProvider);
        await ref.read(studentsProvider.notifier).loadStudents();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── ROW 1: TOP KPI METRIC CARDS ──────────────────────────────────
            Builder(
              builder: (context) {
                final stats = widget.statsAsync.valueOrNull;
                if (stats != null) return _buildTopMetricsGrid(stats, cs);
                if (widget.statsAsync.isLoading) return const LinearProgressIndicator();
                return Text('Error loading stats: ${widget.statsAsync.error}', style: const TextStyle(color: AppColors.error));
              },
            ),
            const SizedBox(height: 20),

            // ─── ROW 2: CLASS/SECTION FILTER & ACTION BAR ─────────────────────
            _buildControlBar(cs, selectedClass, selectedSection),
            const SizedBox(height: 24),

            // ─── ROW 3: DUAL-COLUMN MAIN DASHBOARD CONTENT ────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Left Column: Live Student Directory Table (Wide) ─────────
                Expanded(
                  flex: 65,
                  child: _buildStudentDirectoryCard(cs, studentsAsync, selectedClass, selectedSection),
                ),
                const SizedBox(width: 20),

                // ── Right Column: Today's Attendance & Finance Analytics ─────
                Expanded(
                  flex: 35,
                  child: Column(
                    children: [
                      // Today's Attendance Breakdown Card
                      Builder(
                        builder: (context) {
                          final stats = widget.statsAsync.valueOrNull;
                          if (stats != null) return _buildAttendanceBreakdownCard(stats, cs);
                          if (widget.statsAsync.isLoading) return const Card(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                          return const SizedBox();
                        },
                      ),
                      const SizedBox(height: 20),

                      // Fee Collection Summary Card (for Principal)
                      if (widget.isPrincipal)
                        Builder(
                          builder: (context) {
                            final stats = widget.statsAsync.valueOrNull;
                            if (stats != null) return _buildFinanceSummaryCard(stats, cs);
                            return const SizedBox();
                          },
                        ),

                      // Quick Actions & Management Links Card
                      _buildQuickShortcutsCard(cs),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTopMetricsGrid(DashboardStats stats, ColorScheme cs) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: constraints.maxWidth > 1200 ? 2.4 : 2.0,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _WebMetricCard(
              title: 'Total Students',
              value: '${stats.totalStudents}',
              subtitle: 'School: ${stats.schoolStudents} | Computer: ${stats.computerStudents}',
              icon: Icons.people_alt_rounded,
              color: const Color(0xFF2563EB),
              onTap: () => Navigator.pushNamed(context, AppRoutes.studentList),
            ),
            _WebMetricCard(
              title: "Today's Attendance",
              value: stats.totalStudents > 0
                  ? '${(stats.presentToday / stats.totalStudents * 100).toStringAsFixed(1)}%'
                  : '0.0%',
              subtitle: '${stats.presentToday} Present / ${stats.absentToday} Absent',
              icon: Icons.fact_check_rounded,
              color: const Color(0xFF059669),
              onTap: () => Navigator.pushNamed(context, AppRoutes.attendance),
            ),
            if (widget.isPrincipal) ...[
              _WebMetricCard(
                title: 'Total Collected',
                value: AppUtils.formatCurrency(stats.totalCollected),
                subtitle: 'All-time Fee Receipts',
                icon: Icons.payments_rounded,
                color: const Color(0xFF0D9488),
                onTap: () => Navigator.pushNamed(context, AppRoutes.feesCollected),
              ),
              _WebMetricCard(
                title: 'Pending Dues',
                value: AppUtils.formatCurrency(stats.totalPending),
                subtitle: stats.overdueCount > 0 ? '${stats.overdueCount} Overdue Payments!' : 'All clear',
                icon: Icons.pending_actions_rounded,
                color: stats.overdueCount > 0 ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                onTap: () => Navigator.pushNamed(context, AppRoutes.feesPending),
              ),
            ] else ...[
              _WebMetricCard(
                title: 'School Students',
                value: '${stats.schoolStudents}',
                subtitle: 'Assigned Classes',
                icon: Icons.school_rounded,
                color: const Color(0xFF7C3AED),
                onTap: () => Navigator.pushNamed(context, AppRoutes.studentList),
              ),
              _WebMetricCard(
                title: 'Computer Students',
                value: '${stats.computerStudents}',
                subtitle: 'Course Batches',
                icon: Icons.laptop_chromebook_rounded,
                color: const Color(0xFFD97706),
                onTap: () => Navigator.pushNamed(context, AppRoutes.studentList),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildControlBar(ColorScheme cs, String selectedClass, String selectedSection) {
    final studentsAsync = ref.watch(studentsProvider);
    final students = studentsAsync.valueOrNull ?? [];
    final classes = students
        .where((s) => s.studentType == 'school' && (s.className?.isNotEmpty == true))
        .map((s) => s.className!)
        .toSet()
        .toList()
      ..sort();
    final sections = students
        .where((s) => s.section?.isNotEmpty == true)
        .map((s) => s.section!)
        .toSet()
        .toList()
      ..sort();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Class & Section Selector
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Class Filter:',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(width: 10),
              // Class dropdown
              SizedBox(
                width: 130,
                child: DropdownButtonFormField<String>(
                  value: selectedClass.isEmpty ? null : selectedClass,
                  decoration: InputDecoration(
                    hintText: 'All Classes',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('All Classes', style: TextStyle(fontSize: 13))),
                    ...classes.map((c) => DropdownMenuItem(value: c, child: Text('Class $c', style: const TextStyle(fontSize: 13)))),
                  ],
                  onChanged: (v) {
                    ref.read(teacherSelectedClassProvider.notifier).state = v ?? '';
                    ref.read(classFilterProvider.notifier).state = v ?? '';
                  },
                ),
              ),
              const SizedBox(width: 10),
              // Section dropdown
              SizedBox(
                width: 120,
                child: DropdownButtonFormField<String>(
                  value: selectedSection.isEmpty ? null : selectedSection,
                  decoration: InputDecoration(
                    hintText: 'All Sec',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('All Sec', style: TextStyle(fontSize: 13))),
                    ...sections.map((s) => DropdownMenuItem(value: s, child: Text('Sec $s', style: const TextStyle(fontSize: 13)))),
                  ],
                  onChanged: (v) {
                    ref.read(teacherSelectedSectionProvider.notifier).state = v ?? '';
                    ref.read(sectionFilterProvider.notifier).state = v ?? '';
                  },
                ),
              ),
            ],
          ),

          const Spacer(),

          // Rapid Action Buttons
          Wrap(
            spacing: 10,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Add Student'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pushNamed(context, AppRoutes.addStudent),
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.fact_check_rounded, size: 16),
                label: const Text('Mark Attendance'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pushNamed(context, AppRoutes.attendance),
              ),
              if (widget.isPrincipal)
                OutlinedButton.icon(
                  icon: const Icon(Icons.receipt_long_rounded, size: 16),
                  label: const Text('Fee Receipts'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.feesCollected),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentDirectoryCard(
      ColorScheme cs,
      AsyncValue<List<StudentModel>> studentsAsync,
      String selectedClass,
      String selectedSection,
      ) {
    return Card(
      color: cs.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row with Title and Search Field
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live Student Directory',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Quick view and manage enrolled students',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: 240,
                  height: 38,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search student...',
                      hintStyle: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.studentList),
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const Divider(height: 24),

            // Students Data Table
            studentsAsync.when(
              data: (allStudents) {
                final query = _searchCtrl.text.toLowerCase().trim();
                final filtered = allStudents.where((s) {
                  if (selectedClass.isNotEmpty && s.className != selectedClass) return false;
                  if (selectedSection.isNotEmpty && s.section != selectedSection) return false;
                  if (query.isNotEmpty) {
                    final match = s.name.toLowerCase().contains(query) ||
                        s.studentId.toLowerCase().contains(query) ||
                        s.admissionNumber.toLowerCase().contains(query) ||
                        s.mobile.contains(query);
                    if (!match) return false;
                  }
                  return true;
                }).take(10).toList(); // Show top 10 on dashboard

                if (filtered.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text('No students match the current filters.'),
                    ),
                  );
                }

                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(cs.surfaceContainerHighest.withValues(alpha: 0.5)),
                      dataRowMinHeight: 52,
                      dataRowMaxHeight: 56,
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(label: Text('Student', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                        DataColumn(label: Text('ID / Adm No', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                        DataColumn(label: Text('Class / Course', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                        DataColumn(label: Text('Mobile', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                      ],
                      rows: filtered.map<DataRow>((s) {
                        return DataRow(
                          cells: [
                            // Student Name & Avatar
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                    child: ClipOval(
                                      child: AppUtils.buildAppImageWidget(
                                        s.photoPath,
                                        width: 32,
                                        height: 32,
                                        fit: BoxFit.cover,
                                        placeholder: Text(
                                          s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primary),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        s.name,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                      ),
                                      Text(
                                        s.fatherName,
                                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // ID & Admission No
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(s.admissionNumber, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                  Text(s.studentId, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            // Class / Course
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  s.displayClass,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                                ),
                              ),
                            ),
                            // Mobile
                            DataCell(Text(s.mobile, style: const TextStyle(fontSize: 12))),
                            // Status Badge
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Color(s.statusColor).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  s.statusLabel,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(s.statusColor)),
                                ),
                              ),
                            ),
                            // Actions
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.person_outline, size: 18),
                                    tooltip: 'View Profile',
                                    onPressed: () => Navigator.pushNamed(context, AppRoutes.studentProfile, arguments: s.id),
                                  ),
                                  if (widget.isPrincipal)
                                    IconButton(
                                      icon: const Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.success),
                                      tooltip: 'Fee Receipt',
                                      onPressed: () => Navigator.pushNamed(context, AppRoutes.fees, arguments: s.id),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.assignment_outlined, size: 18, color: AppColors.secondary),
                                    tooltip: 'Result',
                                    onPressed: () => Navigator.pushNamed(context, AppRoutes.result, arguments: s.id),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceBreakdownCard(DashboardStats stats, ColorScheme cs) {
    return Card(
      color: cs.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.pie_chart_rounded, color: AppColors.success, size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  "Today's Attendance Status",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    if (stats.totalStudents > 0) ...[
                      Expanded(
                        flex: (stats.presentToday * 100).clamp(1, 10000),
                        child: Container(color: AppColors.success),
                      ),
                      Expanded(
                        flex: (stats.absentToday * 100).clamp(1, 10000),
                        child: Container(color: AppColors.error),
                      ),
                      Expanded(
                        flex: (stats.leaveToday * 100).clamp(0, 10000),
                        child: Container(color: AppColors.warning),
                      ),
                    ] else
                      Expanded(child: Container(color: cs.surfaceContainerHighest)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Stats breakdown chips
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _attendanceBadge('Present', '${stats.presentToday}', AppColors.success),
                _attendanceBadge('Absent', '${stats.absentToday}', AppColors.error),
                _attendanceBadge('Leave', '${stats.leaveToday}', AppColors.warning),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _attendanceBadge(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(count, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildFinanceSummaryCard(DashboardStats stats, ColorScheme cs) {
    return Card(
      color: cs.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Fee Collection Overview',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _financeRow('Total Collected:', AppUtils.formatCurrency(stats.totalCollected), AppColors.success),
            const Divider(height: 16),
            _financeRow('Total Pending:', AppUtils.formatCurrency(stats.totalPending), AppColors.error),
            const Divider(height: 16),
            _financeRow('Overdue Count:', '${stats.overdueCount} Students', stats.overdueCount > 0 ? AppColors.error : cs.onSurface),
          ],
        ),
      ),
    );
  }

  Widget _financeRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: valueColor)),
      ],
    );
  }

  Widget _buildQuickShortcutsCard(ColorScheme cs) {
    return Card(
      color: cs.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Tools & Shortcuts',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _shortcutTile(Icons.assignment_rounded, 'Attendance Report', () => Navigator.pushNamed(context, AppRoutes.attendanceReport), cs),
            _shortcutTile(Icons.bar_chart_rounded, 'Export Excel & PDF Reports', () => Navigator.pushNamed(context, AppRoutes.reports), cs),
            if (widget.isPrincipal) ...[
              _shortcutTile(Icons.manage_accounts_rounded, 'Teacher Management', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherManagementScreen()));
              }, cs),
              _shortcutTile(Icons.co_present_rounded, 'Teacher Attendance', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherAttendanceScreen()));
              }, cs),
              _shortcutTile(Icons.admin_panel_settings_rounded, 'Teacher Role Permissions (ON/OFF)', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherRoleAccessScreen()));
              }, cs),
            ],
            _shortcutTile(Icons.settings_rounded, 'Institute Settings', () => Navigator.pushNamed(context, AppRoutes.settings), cs),
          ],
        ),
      ),
    );
  }

  Widget _shortcutTile(IconData icon, String title, VoidCallback onTap, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              Icon(Icons.chevron_right, size: 16, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _WebMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });


  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

