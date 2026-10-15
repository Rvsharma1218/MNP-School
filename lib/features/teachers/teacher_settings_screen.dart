import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/providers.dart';
import '../../data/services/session_service.dart';
import '../../widgets/common_widgets.dart';

class TeacherSettingsScreen extends ConsumerWidget {
  const TeacherSettingsScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('You will need to sign in again to access your dashboard.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      // AuthService.signOut() clears local SQLite data THEN signs out of Firebase
      await AuthService.instance.signOut();
    } finally {
      await SessionService.instance.clear();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (r) => false);
      }
    }
  }

  Widget _buildCard(BuildContext context, String title, IconData icon, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final cs = Theme.of(context).colorScheme;
    final session = SessionService.instance;

    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: settingsAsync.when(
        data: (settings) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildCard(context, 'School', Icons.school_outlined, [
              _infoRow(context, Icons.business, 'Institute Name', settings.instituteName),
              _infoRow(context, Icons.calendar_month, 'Session', settings.currentSession),
              if (settings.principalName != null && settings.principalName!.isNotEmpty)
                _infoRow(context, Icons.person, 'Principal', settings.principalName!),
            ]),
            const SizedBox(height: 16),

            _buildCard(context, 'My Account & Class', Icons.badge_outlined, [
              _infoRow(context, Icons.person_outline, 'Name', session.teacherName ?? '—'),
              _infoRow(context, Icons.tag, 'Teacher ID', session.teacherId ?? '—'),
              _infoRow(
                context,
                Icons.class_outlined,
                'Assigned Class',
                session.assignedClassLabel,
              ),
            ]),
            const SizedBox(height: 16),

            _buildCard(context, 'Appearance', Icons.palette_outlined, [
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

            OutlinedButton.icon(
              onPressed: () => _logout(context, ref),
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: const Text('Logout',
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                side: const BorderSide(color: AppColors.error),
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
          color: selected ? cs.primary : cs.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? cs.primary : cs.outline),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? Colors.white : cs.onSurfaceVariant, size: 22),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : cs.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
        ]),
      ),
    );
  }
}