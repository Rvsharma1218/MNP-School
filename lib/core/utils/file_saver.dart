import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List, debugPrint;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';

enum FileCategory {
  admitCards('Admit_Cards', 'Admit Cards'),
  idCards('ID_Cards', 'Student ID Cards'),
  feeReceipts('Fee_Receipts', 'Fee Receipts'),
  timetable('Time_Table', 'Class Timetables'),
  results('Results_Marksheet', 'Marksheets & Results'),
  attendance('Attendance_Reports', 'Attendance Registers'),
  salarySlips('Salary_Slips', 'Staff Salary Slips'),
  backups('Backups', 'School Backups'),
  general('General', 'Documents');

  final String folderName;
  final String displayName;
  const FileCategory(this.folderName, this.displayName);
}

/// Handles saving files to organized device storage or sharing.
class FileSaver {
  /// Base folder name for the school in Downloads
  static const String mainSchoolFolder = 'Mission_Navodaya_Public_School';

  /// Saves [bytes] into `Download/SchoolManager/<folderName>/<filename>`.
  /// Returns the saved absolute file path.
  static Future<String> saveCategorizedFile({
    required List<int> bytes,
    required String filename,
    required FileCategory category,
    String? schoolName,
  }) async {
    if (kIsWeb) {
      await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: filename);
      return filename;
    }

    final sanitizedSchool = (schoolName != null && schoolName.trim().isNotEmpty)
        ? schoolName.trim().replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_')
        : mainSchoolFolder;

    // ─── Try public Downloads folder (/storage/emulated/0/Download)
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final parts = extDir.path.split('/Android');
        if (parts.length >= 2) {
          final downloadsRoot = '${parts[0]}/Download';
          final targetDir = Directory('$downloadsRoot/$sanitizedSchool/${category.folderName}');
          await targetDir.create(recursive: true);
          final file = File('${targetDir.path}/$filename');
          await file.writeAsBytes(bytes, flush: true);
          return file.path;
        }
      }
    } catch (e) {
      debugPrint('External download dir error: $e');
    }

    // ─── Fallback: App external or documents directory
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory('${appDir.path}/$sanitizedSchool/${category.folderName}');
      await targetDir.create(recursive: true);
      final file = File('${targetDir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e) {
      debugPrint('App document dir fallback error: $e');
      rethrow;
    }
  }

  /// Backward-compatible method
  static Future<String> saveToDownloads(List<int> bytes, String filename) async {
    return saveCategorizedFile(
      bytes: bytes,
      filename: filename,
      category: FileCategory.general,
    );
  }

  /// Shows a stylish bottom sheet with Save to Device + Share buttons.
  static Future<void> showSaveShareSheet(
    BuildContext context, {
    required List<int> bytes,
    required String filename,
    required String subject,
    FileCategory category = FileCategory.general,
    String? schoolName,
    IconData icon = Icons.file_present_rounded,
    Color color = const Color(0xFF2563EB),
  }) async {
    if (kIsWeb) {
      await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: filename);
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$filename')..writeAsBytesSync(bytes);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SaveShareSheet(
        bytes: bytes,
        tempFile: tempFile,
        filename: filename,
        subject: subject,
        category: category,
        schoolName: schoolName,
        icon: icon,
        color: color,
      ),
    );
  }
}

class _SaveShareSheet extends StatefulWidget {
  final List<int> bytes;
  final File tempFile;
  final String filename;
  final String subject;
  final FileCategory category;
  final String? schoolName;
  final IconData icon;
  final Color color;

  const _SaveShareSheet({
    required this.bytes,
    required this.tempFile,
    required this.filename,
    required this.subject,
    required this.category,
    this.schoolName,
    required this.icon,
    required this.color,
  });

  @override
  State<_SaveShareSheet> createState() => _SaveShareSheetState();
}

class _SaveShareSheetState extends State<_SaveShareSheet> {
  bool _saving = false;
  String? _savedPath;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final path = await FileSaver.saveCategorizedFile(
        bytes: widget.bytes,
        filename: widget.filename,
        category: widget.category,
        schoolName: widget.schoolName,
      );
      if (mounted) setState(() { _saving = false; _savedPath = path; });
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final kb = (widget.bytes.length / 1024).toStringAsFixed(1);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // File info
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.filename,
                          style: TextStyle(fontWeight: FontWeight.w700,
                              fontSize: 15, color: cs.onSurface),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: widget.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(widget.category.displayName.toUpperCase(), style: TextStyle(fontSize: 9,
                              fontWeight: FontWeight.w800, color: widget.color)),
                        ),
                        const SizedBox(width: 6),
                        Text('$kb KB', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      ]),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 16),

              // Saved path banner
              if (_savedPath != null) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('File saved to folder!',
                                style: TextStyle(fontWeight: FontWeight.w700,
                                    color: Colors.green, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(_savedPath!,
                                style: TextStyle(fontSize: 11, color: Colors.green.shade800),
                                maxLines: 3, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Action buttons
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : Icon(_savedPath != null ? Icons.check_rounded : Icons.download_rounded),
                    label: Text(
                      _saving
                          ? 'Saving...'
                          : _savedPath != null
                              ? 'Saved ✓'
                              : 'Save in Folder',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _savedPath != null ? Colors.green.shade800 : const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Share.shareXFiles(
                        [XFile(widget.tempFile.path)],
                        subject: widget.subject,
                      );
                    },
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
