import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  @override
  void initState() {
    super.initState();
    _startRealtimeTeacherListener();
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

  Widget _infoRow(BuildContext context, IconData icon, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
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
