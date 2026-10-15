import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/file_saver.dart';
import '../../data/models/import_models.dart';
import '../../data/services/import_service.dart';
import '../../data/services/providers.dart';

class ImportScreen extends ConsumerStatefulWidget {
  final int initialTab; // 0 = Excel, 1 = PDF
  const ImportScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 2, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Import Student Data'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.table_chart_outlined), text: 'Excel Import'),
            Tab(icon: Icon(Icons.picture_as_pdf_outlined), text: 'PDF Import'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ExcelImportTab(),
          _PdfImportTab(),
        ],
      ),
    );
  }
}

// ─── Excel Import Tab ─────────────────────────────────────────────────────────

class _ExcelImportTab extends ConsumerStatefulWidget {
  const _ExcelImportTab();
  @override
  ConsumerState<_ExcelImportTab> createState() => _ExcelImportTabState();
}

class _ExcelImportTabState extends ConsumerState<_ExcelImportTab> {
  ImportResult? _result;
  bool _parsing = false;
  bool _importing = false;
  String? _filePath;
  ImportDuplicateAction _dupAction = ImportDuplicateAction.skip;
  int _importedCount = 0;
  int _totalCount = 0;
  bool _importDone = false;
  ImportSummary? _summary;

  Future<void> _pickFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final path = picked.files.first.path;
    if (path == null) return;

    setState(() {
      _parsing = true;
      _filePath = path;
      _result = null;
      _importDone = false;
      _summary = null;
    });

    try {
      final result = await ImportService.instance.parseExcelFile(path);
      if (mounted) setState(() { _result = result; _parsing = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _parsing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Parse error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _startImport() async {
    if (_result == null) return;
    final validRows = _result!.rows.where((r) => r.isValid).toList();
    if (validRows.isEmpty) return;

    setState(() {
      _importing = true;
      _importDone = false;
      _importedCount = 0;
      _totalCount = validRows.length;
    });

    try {
      final summary = await ImportService.instance.importRows(
        validRows,
        globalAction: _dupAction,
        onProgress: (cur, total) {
          if (mounted) setState(() { _importedCount = cur; _totalCount = total; });
        },
      );

      // Refresh all providers
      ref.invalidate(studentsProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(attendanceDateProvider);

      if (mounted) {
        setState(() {
          _importing = false;
          _importDone = true;
          _summary = summary;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _importing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info banner
        _InfoBanner(
          icon: Icons.table_chart_rounded,
          color: Colors.green.shade700,
          title: 'Excel Import (Recommended)',
          body: 'Select a .xlsx file to import student data. '
              'Download the template first for the correct format.',
        ),
        const SizedBox(height: 12),

        // Template download button
        OutlinedButton.icon(
          onPressed: () async {
            try {
              // Build the template bytes and show Save/Share sheet
              final bytes = await ImportService.instance.buildImportTemplateBytes();
              if (!mounted) return;
              await FileSaver.showSaveShareSheet(
                context,
                bytes: bytes,
                filename: 'student_import_template.xlsx',
                subject: 'Student Import Template',
                icon: Icons.table_chart_rounded,
                color: Colors.green.shade700,
              );
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
            }
          },
          icon: const Icon(Icons.download_rounded),
          label: const Text('Download Import Template'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.green.shade700,
            side: BorderSide(color: Colors.green.shade300),
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 12),

        // Pick file button
        ElevatedButton.icon(
          onPressed: _parsing || _importing ? null : _pickFile,
          icon: _parsing
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.upload_file_rounded),
          label: Text(_parsing ? 'Parsing file...' : 'Select Excel File (.xlsx)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
          ),
        ),

        if (_filePath != null) ...[
          const SizedBox(height: 8),
          Text(
            'File: ${_filePath!.split('/').last.split('\\').last}',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],

        // Parse result summary
        if (_result != null && !_importDone) ...[
          const SizedBox(height: 16),
          _SummaryCard(
            totalRows: _result!.totalRows,
            valid: _result!.validCount,
            duplicates: _result!.duplicateCount,
            invalid: _result!.invalidCount,
            hasAttendanceColumns: _result!.hasAttendanceColumns,
            attendanceFoundCount: _result!.attendanceFoundCount,
          ),
          const SizedBox(height: 12),

          // Duplicate action selector
          if (_result!.duplicateCount > 0) ...[
            Card(
              color: cs.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Duplicate Action',
                        style: TextStyle(fontWeight: FontWeight.w700,
                            color: cs.onSurface, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      '${_result!.duplicateCount} student(s) already exist in database.',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      _ActionChip(
                        label: 'Skip Duplicates',
                        icon: Icons.skip_next_rounded,
                        selected: _dupAction == ImportDuplicateAction.skip,
                        color: AppColors.warning,
                        onTap: () => setState(() => _dupAction = ImportDuplicateAction.skip),
                      ),
                      const SizedBox(width: 8),
                      _ActionChip(
                        label: 'Update Existing',
                        icon: Icons.update_rounded,
                        selected: _dupAction == ImportDuplicateAction.update,
                        color: AppColors.info,
                        onTap: () => setState(() => _dupAction = ImportDuplicateAction.update),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Preview table
          if (_result!.rows.isNotEmpty) ...[
            Text('Preview (first 20 rows)',
                style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface)),
            const SizedBox(height: 8),
            _ExcelPreviewTable(rows: _result!.rows.take(20).toList()),
            if (_result!.rows.length > 20)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '… and ${_result!.rows.length - 20} more rows',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 16),
          ],

          // Import button
          if (_result!.validCount > 0)
            ElevatedButton.icon(
              onPressed: _importing ? null : _startImport,
              icon: _importing
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.cloud_upload_rounded),
              label: Text(_importing
                  ? 'Importing... $_importedCount / $_totalCount'
                  : 'Import ${_result!.validCount} Students'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
              ),
            ),

          if (_importing) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _totalCount > 0 ? _importedCount / _totalCount : null,
              backgroundColor: Colors.green.shade100,
              color: Colors.green.shade700,
              borderRadius: BorderRadius.circular(4),
              minHeight: 8,
            ),
          ],
        ],

        // Import done summary
        if (_importDone && _summary != null) ...[
          const SizedBox(height: 16),
          _ImportDoneCard(
            summary: _summary!,
            onDownloadErrors: () async {
              if (_summary!.errors.isNotEmpty) {
                await ImportService.instance.downloadErrorReport(_summary!.errors);
              }
            },
          ),
        ],
      ],
    );
  }
}

// ─── PDF Import Tab ───────────────────────────────────────────────────────────

class _PdfImportTab extends ConsumerStatefulWidget {
  const _PdfImportTab();
  @override
  ConsumerState<_PdfImportTab> createState() => _PdfImportTabState();
}

class _PdfImportTabState extends ConsumerState<_PdfImportTab> {
  PdfImportResult? _result;
  bool _parsing = false;
  bool _importing = false;
  String? _filePath;
  ImportDuplicateAction _dupAction = ImportDuplicateAction.skip;
  bool _showMapping = false;
  bool _importDone = false;
  ImportSummary? _summary;
  int _importedCount = 0;
  int _totalCount = 0;

  Future<void> _pickFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final path = picked.files.first.path;
    if (path == null) return;

    setState(() {
      _parsing = true;
      _filePath = path;
      _result = null;
      _importDone = false;
      _summary = null;
    });

    try {
      final result = await ImportService.instance.parsePdfFile(path);
      if (mounted) setState(() { _result = result; _parsing = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _parsing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF parse error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _startImport() async {
    if (_result == null) return;
    final validRows = _result!.rows.where((r) => r.isValid).toList();
    if (validRows.isEmpty) return;

    setState(() {
      _importing = true;
      _importDone = false;
      _importedCount = 0;
      _totalCount = validRows.length;
    });

    try {
      final summary = await ImportService.instance.importRows(
        validRows,
        globalAction: _dupAction,
        onProgress: (cur, total) {
          if (mounted) setState(() { _importedCount = cur; _totalCount = total; });
        },
      );

      ref.invalidate(studentsProvider);
      ref.invalidate(dashboardStatsProvider);

      if (mounted) {
        setState(() {
          _importing = false;
          _importDone = true;
          _summary = summary;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _importing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info banner
        _InfoBanner(
          icon: Icons.picture_as_pdf_rounded,
          color: Colors.red.shade700,
          title: 'PDF Import (Optional)',
          body: 'Supports text-based PDFs only. Scanned/image PDFs cannot be read automatically. '
              'Excel import is recommended for best results.',
        ),
        const SizedBox(height: 12),

        // Pick PDF button
        ElevatedButton.icon(
          onPressed: _parsing || _importing ? null : _pickFile,
          icon: _parsing
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.upload_file_rounded),
          label: Text(_parsing ? 'Extracting PDF...' : 'Select PDF File'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
          ),
        ),

        if (_filePath != null) ...[
          const SizedBox(height: 8),
          Text(
            'File: ${_filePath!.split('/').last.split('\\').last}',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],

        // Warning message
        if (_result?.warningMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border.all(color: Colors.orange.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _result!.warningMessage!,
                    style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (_result != null && !_importDone) ...[
          const SizedBox(height: 16),

          // PDF Detection Summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                _StatRow('PDF Detected', '✅ Yes'),
                _StatRow('Pages', '${_result!.pages}'),
                _StatRow('Records Detected', '${_result!.detectedRecords}'),
                _StatRow('Valid', '${_result!.validCount}', color: Colors.green.shade700),
                _StatRow('Possible Duplicates', '${_result!.duplicateCount}', color: Colors.orange.shade700),
                _StatRow('Invalid / Unrecognized', '${_result!.invalidCount}', color: Colors.red.shade700),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          // Field mapping section
          if (_result!.mappings.isNotEmpty) ...[
            GestureDetector(
              onTap: () => setState(() => _showMapping = !_showMapping),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Icon(Icons.compare_arrows_rounded, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Field Mapping (${_result!.mappings.length} detected)',
                      style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface))),
                  Icon(_showMapping ? Icons.expand_less : Icons.expand_more,
                      color: cs.onSurfaceVariant),
                ]),
              ),
            ),
            if (_showMapping) ...[
              const SizedBox(height: 8),
              ..._result!.mappings.map((m) => _MappingRow(mapping: m)),
            ],
            const SizedBox(height: 12),
          ],

          // Duplicate action
          if (_result!.duplicateCount > 0) ...[
            Card(
              color: cs.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Duplicate Action',
                        style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface)),
                    const SizedBox(height: 8),
                    Row(children: [
                      _ActionChip(
                        label: 'Skip',
                        icon: Icons.skip_next_rounded,
                        selected: _dupAction == ImportDuplicateAction.skip,
                        color: AppColors.warning,
                        onTap: () => setState(() => _dupAction = ImportDuplicateAction.skip),
                      ),
                      const SizedBox(width: 8),
                      _ActionChip(
                        label: 'Update',
                        icon: Icons.update_rounded,
                        selected: _dupAction == ImportDuplicateAction.update,
                        color: AppColors.info,
                        onTap: () => setState(() => _dupAction = ImportDuplicateAction.update),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Preview table
          if (_result!.rows.isNotEmpty) ...[
            Text('Preview (first 20 rows)',
                style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface)),
            const SizedBox(height: 8),
            _ExcelPreviewTable(rows: _result!.rows.take(20).toList()),
            const SizedBox(height: 16),
          ],

          // Invalid rows warning
          if (_result!.invalidCount > 0) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '⚠️ ${_result!.invalidCount} row(s) could not be recognized accurately and will NOT be imported. '
                'Review the preview table for details.',
                style: TextStyle(color: Colors.red.shade800, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Import button
          if (_result!.validCount > 0)
            ElevatedButton.icon(
              onPressed: _importing ? null : _startImport,
              icon: _importing
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.cloud_upload_rounded),
              label: Text(_importing
                  ? 'Importing... $_importedCount / $_totalCount'
                  : 'Import ${_result!.validCount} Students'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
              ),
            )
          else if (_result!.validCount == 0 && _result!.rows.isNotEmpty)
            const Center(child: Text('No valid records to import.', style: TextStyle(color: AppColors.error))),

          if (_importing) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _totalCount > 0 ? _importedCount / _totalCount : null,
              backgroundColor: Colors.red.shade100,
              color: Colors.red.shade700,
              borderRadius: BorderRadius.circular(4),
              minHeight: 8,
            ),
          ],
        ],

        if (_importDone && _summary != null) ...[
          const SizedBox(height: 16),
          _ImportDoneCard(
            summary: _summary!,
            onDownloadErrors: () async {
              if (_summary!.errors.isNotEmpty) {
                await ImportService.instance.downloadErrorReport(_summary!.errors);
              }
            },
          ),
        ],
      ],
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _InfoBanner({required this.icon, required this.color,
      required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 14)),
              const SizedBox(height: 4),
              Text(body,
                  style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
            ]),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int totalRows;
  final int valid;
  final int duplicates;
  final int invalid;
  final bool hasAttendanceColumns;
  final int attendanceFoundCount;

  const _SummaryCard({
    required this.totalRows,
    required this.valid,
    required this.duplicates,
    required this.invalid,
    this.hasAttendanceColumns = true,
    this.attendanceFoundCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Parse Result',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 10),
            Row(children: [
              _StatBox('Total Rows', '$totalRows', Colors.blueGrey),
              const SizedBox(width: 8),
              _StatBox('Valid', '$valid', Colors.green.shade700),
              const SizedBox(width: 8),
              _StatBox('Duplicates', '$duplicates', Colors.orange.shade700),
              const SizedBox(width: 8),
              _StatBox('Invalid', '$invalid', Colors.red.shade700),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: hasAttendanceColumns ? Colors.blue.shade50 : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: hasAttendanceColumns ? Colors.blue.shade200 : Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    hasAttendanceColumns ? Icons.rule_folder_rounded : Icons.warning_amber_rounded,
                    color: hasAttendanceColumns ? Colors.blue.shade800 : Colors.amber.shade900,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasAttendanceColumns
                          ? 'Attendance Data Found: $attendanceFoundCount student(s)'
                          : 'Attendance columns were not found in this file.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: hasAttendanceColumns ? Colors.blue.shade900 : Colors.amber.shade900,
                      ),
                    ),
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

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBox(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: color), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _StatRow(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13))),
        Text(value, style: TextStyle(
          fontWeight: FontWeight.w700,
          color: color ?? cs.onSurface,
          fontSize: 13,
        )),
      ]),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _ActionChip({required this.label, required this.icon,
      required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.transparent,
          border: Border.all(color: selected ? color : Colors.grey.shade400, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: selected ? color : Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            color: selected ? color : Colors.grey.shade600,
            fontSize: 13,
          )),
        ]),
      ),
    );
  }
}

class _MappingRow extends StatefulWidget {
  final PdfFieldMapping mapping;
  const _MappingRow({required this.mapping});
  @override
  State<_MappingRow> createState() => _MappingRowState();
}

class _MappingRowState extends State<_MappingRow> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.mapping.targetField;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(widget.mapping.pdfField,
                style: TextStyle(fontSize: 13, color: cs.onSurface)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_forward_rounded, color: cs.primary, size: 18),
        ),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: kImportTargetFields.contains(_selected)
                ? _selected
                : kImportTargetFields.last,
            isDense: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: cs.surfaceContainerHighest,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: cs.outline)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: cs.outline)),
            ),
            items: kImportTargetFields
                .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 12))))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() => _selected = v);
                widget.mapping.targetField = v;
              }
            },
          ),
        ),
      ]),
    );
  }
}

class _ExcelPreviewTable extends StatelessWidget {
  final List<StudentImportRow> rows;
  const _ExcelPreviewTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.primary.withValues(alpha: 0.08)),
        dataRowMinHeight: 36,
        dataRowMaxHeight: 48,
        columnSpacing: 16,
        horizontalMargin: 12,
        columns: const [
          DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          DataColumn(label: Text('Adm No', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          DataColumn(label: Text('Class', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          DataColumn(label: Text('Section', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          DataColumn(label: Text('Total Days', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          DataColumn(label: Text('Present', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          DataColumn(label: Text('Absent', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          DataColumn(label: Text('Leave', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          DataColumn(label: Text('Attendance %', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          DataColumn(label: Text('Error', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
        ],
        rows: rows.map((row) {
          final statusColor = row.isDuplicate
              ? Colors.orange.shade700
              : row.isValid
                  ? Colors.green.shade700
                  : Colors.red.shade700;
          final statusLabel = row.isDuplicate
              ? 'Duplicate'
              : row.isValid
                  ? 'Valid'
                  : 'Invalid';

          return DataRow(
            color: WidgetStateProperty.all(
              row.isDuplicate
                  ? Colors.orange.withOpacity(0.06)
                  : row.isValid
                      ? Colors.transparent
                      : Colors.red.withOpacity(0.06),
            ),
            cells: [
              DataCell(Text('${row.rowIndex}', style: const TextStyle(fontSize: 12))),
              DataCell(Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(statusLabel,
                    style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
              )),
              DataCell(Text(row.admissionNumber, style: const TextStyle(fontSize: 12))),
              DataCell(Text(row.name, style: const TextStyle(fontSize: 12))),
              DataCell(Text(row.className ?? row.course ?? '—', style: const TextStyle(fontSize: 12))),
              DataCell(Text(row.section ?? row.batch ?? '—', style: const TextStyle(fontSize: 12))),
              DataCell(Text(row.totalAttendanceDays?.toString() ?? '—', style: const TextStyle(fontSize: 12))),
              DataCell(Text(row.presentDays?.toString() ?? '—', style: const TextStyle(fontSize: 12))),
              DataCell(Text(row.absentDays?.toString() ?? '—', style: const TextStyle(fontSize: 12))),
              DataCell(Text(row.leaveDays?.toString() ?? '—', style: const TextStyle(fontSize: 12))),
              DataCell(Text(row.attendancePercentage != null ? '${row.attendancePercentage!.toStringAsFixed(1)}%' : '—', style: const TextStyle(fontSize: 12))),
              DataCell(Text(
                row.validationError ?? '',
                style: TextStyle(fontSize: 11, color: Colors.red.shade700),
              )),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _ImportDoneCard extends StatelessWidget {
  final ImportSummary summary;
  final VoidCallback onDownloadErrors;
  const _ImportDoneCard({required this.summary, required this.onDownloadErrors});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              const Text('Import Complete',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ]),
            const SizedBox(height: 12),
            _StatRow('✅ Imported', '${summary.imported}', color: Colors.green.shade700),
            _StatRow('⏭️ Skipped', '${summary.skipped}', color: Colors.orange.shade700),
            _StatRow('🔄 Updated', '${summary.updated}', color: Colors.blue.shade700),
            _StatRow('❌ Failed', '${summary.failed}', color: Colors.red.shade700),
            if (summary.errors.isNotEmpty) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onDownloadErrors,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download Error Report'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade300),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
