import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_routes.dart';
import '../data/services/auth_service.dart';
import '../data/services/providers.dart';
import '../data/services/session_service.dart';

/// A modern responsive shell for Web / Desktop view (> 800px).
/// On mobile screens (< 800px), it returns the [body] directly without extra chrome.
class ResponsiveWebLayout extends ConsumerWidget {
  final Widget body;
  final String title;
  final String currentRoute;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const ResponsiveWebLayout({
    super.key,
    required this.body,
    required this.title,
    this.currentRoute = AppRoutes.dashboard,
    this.actions,
    this.floatingActionButton,
  });

  static Widget _buildSidebarLogo(String? logoPath) {
    if (logoPath != null && logoPath.isNotEmpty) {
      if (logoPath.startsWith('http://') || logoPath.startsWith('https://')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            logoPath,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.school_rounded, color: Colors.white, size: 26),
          ),
        );
      }
      if (logoPath.startsWith('data:image')) {
        try {
          final bytes = base64Decode(logoPath.split(',').last);
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(bytes, fit: BoxFit.cover),
          );
        } catch (_) {}
      }
      final file = File(logoPath);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(file, fit: BoxFit.cover),
        );
      }
    }
    return const Icon(
      Icons.school_rounded,
      color: Colors.white,
      size: 26,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width >= 850;

    if (!isDesktop) {
      return body;
    }

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsAsync = ref.watch(settingsProvider);
    final isPrincipal = SessionService.instance.isPrincipal;
    final roleName = isPrincipal ? 'Principal' : 'Teacher';
    final teacherName = SessionService.instance.teacherName;
    final assignedClass = SessionService.instance.assignedClassLabel;
    final instituteName = settingsAsync.whenOrNull(data: (s) => s.instituteName) ?? 'School Manager';
    final currentSession = settingsAsync.whenOrNull(data: (s) => s.currentSession) ?? '2026-27';

    return Scaffold(
      backgroundColor: cs.surface,
      floatingActionButton: floatingActionButton,
      body: Row(
        children: [
          // ─── Left Sidebar Navigation ────────────────────────────────────
          Container(
            width: 260,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Institute Branding Header ───────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: _buildSidebarLogo(settingsAsync.valueOrNull?.logoPath),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              instituteName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Session: $currentSession',
                                style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 8),

                // ─── Navigation Items List ───────────────────────────────
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    children: [
                      const _SidebarSectionTitle(title: 'MAIN MENU'),
                      _SidebarTile(
                        icon: Icons.dashboard_rounded,
                        title: 'Dashboard',
                        selected: currentRoute == AppRoutes.dashboard,
                        onTap: () {
                          if (currentRoute != AppRoutes.dashboard) {
                            Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
                          }
                        },
                      ),
                      _SidebarTile(
                        icon: Icons.people_alt_rounded,
                        title: 'Students',
                        selected: currentRoute == AppRoutes.studentList,
                        onTap: () {
                          if (currentRoute != AppRoutes.studentList) {
                            Navigator.pushReplacementNamed(context, AppRoutes.studentList);
                          }
                        },
                      ),
                      _SidebarTile(
                        icon: Icons.fact_check_rounded,
                        title: 'Daily Attendance',
                        selected: currentRoute == AppRoutes.attendance,
                        onTap: () {
                          if (currentRoute != AppRoutes.attendance) {
                            Navigator.pushReplacementNamed(context, AppRoutes.attendance);
                          }
                        },
                      ),
                      _SidebarTile(
                        icon: Icons.assessment_rounded,
                        title: 'Attendance Report',
                        selected: currentRoute == AppRoutes.attendanceReport,
                        onTap: () {
                          Navigator.pushNamed(context, AppRoutes.attendanceReport);
                        },
                      ),

                      if (isPrincipal) ...[
                        const SizedBox(height: 12),
                        const _SidebarSectionTitle(title: 'FINANCE & REPORTS'),
                        _SidebarTile(
                          icon: Icons.payments_rounded,
                          title: 'Fees & Collections',
                          selected: currentRoute == AppRoutes.feesCollected,
                          onTap: () {
                            Navigator.pushNamed(context, AppRoutes.feesCollected);
                          },
                        ),
                        _SidebarTile(
                          icon: Icons.pending_actions_rounded,
                          title: 'Pending Dues',
                          selected: currentRoute == AppRoutes.feesPending,
                          onTap: () {
                            Navigator.pushNamed(context, AppRoutes.feesPending);
                          },
                        ),
                      ],

                      const SizedBox(height: 12),
                      const _SidebarSectionTitle(title: 'MANAGEMENT'),
                      _SidebarTile(
                        icon: Icons.bar_chart_rounded,
                        title: 'All Reports & Export',
                        selected: currentRoute == AppRoutes.reports,
                        onTap: () {
                          if (currentRoute != AppRoutes.reports) {
                            Navigator.pushReplacementNamed(context, AppRoutes.reports);
                          }
                        },
                      ),
                      _SidebarTile(
                        icon: Icons.qr_code_scanner_rounded,
                        title: 'QR Scanner',
                        selected: currentRoute == AppRoutes.qrScanner,
                        onTap: () {
                          Navigator.pushNamed(context, AppRoutes.qrScanner);
                        },
                      ),
                      _SidebarTile(
                        icon: Icons.settings_rounded,
                        title: 'Institute Settings',
                        selected: currentRoute == AppRoutes.settings,
                        onTap: () {
                          if (currentRoute != AppRoutes.settings) {
                            Navigator.pushReplacementNamed(context, AppRoutes.settings);
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const Divider(color: Colors.white12, height: 1),

                // ─── Current User & Role Pill ────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  color: Colors.black.withValues(alpha: 0.2),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: isPrincipal ? AppColors.accent : AppColors.secondary,
                        child: Icon(
                          isPrincipal ? Icons.admin_panel_settings : Icons.school,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isPrincipal ? 'Principal Account' : (teacherName ?? 'Teacher'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              isPrincipal ? 'Full Admin Access' : assignedClass,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                        tooltip: 'Sign Out',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Sign Out'),
                              content: const Text('Are you sure you want to sign out of the portal?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await AuthService.instance.signOut();
                            await SessionService.instance.clear();
                            if (context.mounted) {
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                AppRoutes.login,
                                (route) => false,
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Main Content Canvas ─────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                // ─── Top Web Header Bar ────────────────────────────────────
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Page Title & Breadcrumb
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                'Portal',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right, size: 12, color: cs.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Actions injected from child screens
                      if (actions != null) ...actions!,

                      const SizedBox(width: 12),

                      // Live Date & Time pill
                      _LiveHeaderDatePill(),

                      const SizedBox(width: 12),

                      // Theme Switcher Button
                      IconButton.filledTonal(
                        icon: Icon(
                          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                          size: 18,
                        ),
                        tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                        onPressed: () {
                          final currentMode = ref.read(themeModeProvider);
                          final nextMode = currentMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
                          ref.read(themeModeProvider.notifier).setMode(
                                nextMode == ThemeMode.dark ? 'dark' : 'light',
                              );
                        },
                      ),

                      const SizedBox(width: 12),

                      // User Profile Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: AppColors.primary,
                              child: Text(
                                roleName[0],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              roleName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── Main Body Content ─────────────────────────────────────
                Expanded(
                  child: body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarSectionTitle extends StatelessWidget {
  final String title;
  const _SidebarSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : Colors.white.withValues(alpha: 0.7),
                size: 19,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (selected)
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveHeaderDatePill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat('EEE, dd MMM yyyy').format(now);
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            dateStr,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
