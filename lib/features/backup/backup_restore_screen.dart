import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../data/services/database_service.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _loading = false;
  String? _message;
  bool _isSuccess = false;

  Future<void> _export() async {
    setState(() { _loading = true; _message = null; });
    try {
      final path = await DatabaseService.instance.exportDatabase();
      setState(() { _isSuccess = true; _message = 'Backup saved to:\n$path'; });
    } catch (e) {
      setState(() { _isSuccess = false; _message = 'Export failed: $e'; });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _import() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup'),
        content: const Text(
            '⚠️ Warning: Restoring will REPLACE all current data with the backup. This cannot be undone.\n\nAre you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final filePath = result.files.first.path;
    if (filePath == null) return;

    if (!filePath.endsWith('.db')) {
      setState(() { _isSuccess = false; _message = 'Please select a valid .db backup file.'; });
      return;
    }

    setState(() { _loading = true; _message = null; });
    try {
      await DatabaseService.instance.importDatabase(filePath);
      setState(() { _isSuccess = true; _message = 'Backup restored successfully! Please restart the app.'; });
    } catch (e) {
      setState(() { _isSuccess = false; _message = 'Restore failed: $e'; });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Backup & Restore'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_sync, size: 48, color: Colors.white),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Data Safety', style: TextStyle(color: Colors.white,
                          fontSize: 18, fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text('Export your database or restore from a backup file.',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Export card
          _ActionCard(
            icon: Icons.upload_file,
            title: 'Export Backup',
            subtitle: 'Save a copy of your database to phone storage',
            color: AppColors.success,
            buttonLabel: 'Export Database',
            onTap: _loading ? null : _export,
          ),
          const SizedBox(height: 16),

          // Import card
          _ActionCard(
            icon: Icons.download_for_offline,
            title: 'Restore Backup',
            subtitle: 'Replace current data with a backup .db file',
            color: AppColors.warning,
            buttonLabel: 'Choose Backup File',
            onTap: _loading ? null : _import,
          ),
          const SizedBox(height: 24),

          // Loading
          if (_loading)
            const Center(child: CircularProgressIndicator()),

          // Result message
          if (_message != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (_isSuccess ? AppColors.success : AppColors.error).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isSuccess ? AppColors.success : AppColors.error,
                ),
              ),
              child: Row(
                children: [
                  Icon(_isSuccess ? Icons.check_circle : Icons.error,
                      color: _isSuccess ? AppColors.success : AppColors.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_message!,
                        style: TextStyle(
                          color: _isSuccess ? AppColors.success : AppColors.error,
                          fontWeight: FontWeight.w500,
                        )),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),
          // Tips
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Row(children: [
                  Icon(Icons.tips_and_updates, color: AppColors.info, size: 18),
                  SizedBox(width: 8),
                  Text('Tips', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.info)),
                ]),
                SizedBox(height: 8),
                Text('• Export regularly to avoid data loss\n'
                    '• Store backup file in Google Drive for safety\n'
                    '• Backup file has .db extension\n'
                    '• After restore, restart the app',
                    style: TextStyle(fontSize: 13, color: AppColors.info)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle, buttonLabel;
  final Color color;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon, required this.title, required this.subtitle,
    required this.color, required this.buttonLabel, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(backgroundColor: color),
                icon: Icon(icon, size: 18),
                label: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
