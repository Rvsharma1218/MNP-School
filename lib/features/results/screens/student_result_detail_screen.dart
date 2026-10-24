import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/file_saver.dart';
import '../../../data/models/result_model.dart';
import '../../../data/models/settings_model.dart';
import '../../../data/models/student_model.dart';
import '../../../data/services/database_service.dart';
import '../../../data/services/providers.dart';
import '../../../data/services/result_pdf_service.dart';
import '../../whatsapp/whatsapp_service.dart';
import 'student_mark_entry_screen.dart';

class StudentResultDetailScreen extends ConsumerStatefulWidget {
  final StudentModel student;
  final ResultModel result;

  const StudentResultDetailScreen({
    super.key,
    required this.student,
    required this.result,
  });

  @override
  ConsumerState<StudentResultDetailScreen> createState() => _StudentResultDetailScreenState();
}

class _StudentResultDetailScreenState extends ConsumerState<StudentResultDetailScreen> {
  late ResultModel _currentResult;
  late TextEditingController _remarksCtrl;
  late String _status;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentResult = widget.result;
    _remarksCtrl = TextEditingController(text: _currentResult.remarks ?? '');
    _status = _currentResult.finalResultStatus;
  }

  @override
  void dispose() {
    _remarksCtrl.dispose();
    super.dispose();
  }

  bool get _isDetailedMode {
    return _currentResult.isDetailedMode ||
        _currentResult.subjects.any((s) =>
            s.theoryMarks > 0 ||
            s.practicalMarks > 0 ||
            s.internalMarks > 0);
  }

  Future<void> _updateStatusAndRemarks() async {
    setState(() => _isSaving = true);
    final updated = _currentResult.copyWith(
      status: _status,
      remarks: _remarksCtrl.text.trim().isNotEmpty ? _remarksCtrl.text.trim() : null,
    );
    await DatabaseService.instance.saveResult(updated);
    setState(() {
      _currentResult = updated;
      _isSaving = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: const Text('✓ Result details updated successfully!'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }

  Future<void> _navigateToEditMarks() async {
    final updated = await Navigator.push<ResultModel>(
      context,
      MaterialPageRoute(
        builder: (_) => StudentMarkEntryScreen(
          student: widget.student,
          editResult: _currentResult,
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        _currentResult = updated;
        _remarksCtrl.text = updated.remarks ?? '';
        _status = updated.finalResultStatus;
      });
    }
  }

  Future<void> _deleteResult() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Marksheet'),
        content: Text('Are you sure you want to delete this result for ${widget.student.name}? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService.instance.deleteResult(_currentResult.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Result deleted successfully!'), backgroundColor: Colors.red),
        );
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _savePdfToDevice() async {
    final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
    try {
      final path = await ResultPdfService.instance.saveResultPdfToDevice(
        result: _currentResult,
        student: widget.student,
        settings: settings,
      );
      if (mounted) {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          if (!mounted) return;
          await FileSaver.showSaveShareSheet(
            context,
            bytes: bytes,
            filename: path.split(RegExp(r"[/\\]")).last,
            subject: 'Marksheet - ${widget.student.name}',
            category: FileCategory.results,
            icon: Icons.picture_as_pdf_rounded,
            color: const Color(0xFF1E3A8A),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Text('Error saving PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generatePdf() async {
    final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
    await ResultPdfService.instance.printOrShareResultPdf(
      result: _currentResult,
      student: widget.student,
      settings: settings,
    );
  }

  Future<void> _shareOnWhatsApp() async {
    final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
    String? pdfPath;
    try {
      pdfPath = await ResultPdfService.instance.saveResultPdfToDevice(
        result: _currentResult,
        student: widget.student,
        settings: settings,
      );
    } catch (e) {
      debugPrint('Error generating result PDF for WhatsApp: $e');
    }

    final subjects = _currentResult.subjects.map((s) => {
      'name': s.subjectName,
      'obtained': s.marks,
      'total': s.totalMarks,
    }).toList();

    final msg = WhatsAppService.buildResultVoucherText(
      studentName: widget.student.name,
      rollNumber: widget.student.rollNumber,
      admissionNumber: widget.student.admissionNumber,
      className: widget.student.displayClass,
      examName: _currentResult.examName,
      totalMarks: _currentResult.totalMarks,
      obtainedMarks: _currentResult.obtainedMarks,
      percentage: _currentResult.overallPercentage,
      grade: _currentResult.overallGrade,
      status: _currentResult.finalResultStatus,
      subjects: subjects,
      remarks: _currentResult.remarks,
      instituteName: settings.instituteName.isNotEmpty ? settings.instituteName : 'Mission Navodaya Public School',
      institutePhone: settings.mobile,
    );

    if (!mounted) return;
    await WhatsAppService.showResultShareSheet(
      context,
      studentName: widget.student.name,
      phone: widget.student.mobile,
      alternatePhone: widget.student.alternateMobile,
      examName: _currentResult.examName,
      message: msg,
      filePath: pdfPath,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalObt = _currentResult.obtainedMarks;
    final totalMax = _currentResult.totalMarks;
    final pct = _currentResult.overallPercentage;
    final grade = _currentResult.overallGrade;
    final isPass = _currentResult.isPass;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Result Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Save PDF to Storage',
            onPressed: _savePdfToDevice,
          ),
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'Print / Preview PDF',
            onPressed: _generatePdf,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            tooltip: 'Delete Result',
            onPressed: _deleteResult,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Simple Student Info Header (Clean, as originally in app) ───
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.student.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${widget.student.displayClass} • Roll: ${widget.student.rollNumber ?? widget.student.studentId} • ID: ${widget.student.studentId}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isDetailedMode
                              ? Colors.purple.withValues(alpha: 0.12)
                              : Colors.teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isDetailedMode ? Colors.purple : Colors.teal,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _isDetailedMode ? 'Detailed Mode' : 'Direct Marks Mode',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isDetailedMode ? Colors.purple : Colors.teal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Exam: ${_currentResult.examName}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E3A8A)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isPass
                                  ? (_currentResult.finalResultStatus == 'PROMOTED' ? Colors.amber.shade800 : Colors.green)
                                  : Colors.red)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _currentResult.finalResultStatus,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isPass
                                ? (_currentResult.finalResultStatus == 'PROMOTED' ? Colors.amber.shade800 : Colors.green)
                                : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── Marksheet Table ───
            Text(
              _isDetailedMode ? 'Subject Performance (Detailed Components)' : 'Subject Performance (Single Obtained Marks)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    ),
                    columnSpacing: 16,
                    horizontalMargin: 12,
                    headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    dataTextStyle: const TextStyle(fontSize: 12),
                    columns: _buildTableColumns(),
                    rows: _buildTableRows(isDark),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ─── Summary Card ───
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(
                      'Total Marks',
                      '${totalObt.toInt()} / ${totalMax.toInt()}',
                      const Color(0xFF1E3A8A),
                    ),
                  ),
                  Container(width: 1, height: 35, color: Colors.grey.shade300),
                  Expanded(
                    child: _buildMetricItem(
                      'Percentage',
                      '${pct.toStringAsFixed(1)}%',
                      pct >= 40 ? Colors.green : Colors.red,
                    ),
                  ),
                  Container(width: 1, height: 35, color: Colors.grey.shade300),
                  Expanded(
                    child: _buildMetricItem(
                      'Grade',
                      grade,
                      Colors.indigo,
                    ),
                  ),
                  Container(width: 1, height: 35, color: Colors.grey.shade300),
                  Expanded(
                    child: _buildMetricItem(
                      'Result',
                      _status,
                      isPass ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── Status Override & Remarks ───
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Result Status Override:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['PASS', 'PROMOTED', 'FAIL'].map((st) {
                      final selected = _status.toUpperCase() == st;
                      final col = st == 'PASS'
                          ? Colors.green
                          : st == 'PROMOTED'
                              ? Colors.orange
                              : Colors.red;
                      return ChoiceChip(
                        label: Text(st, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: selected ? Colors.white : col)),
                        selected: selected,
                        selectedColor: col,
                        backgroundColor: col.withValues(alpha: 0.1),
                        side: BorderSide(color: col),
                        onSelected: (val) {
                          if (val) setState(() => _status = st);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text('Remarks / Teacher Note:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _remarksCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'e.g. Excellent performance, promoted to next class',
                      hintStyle: const TextStyle(fontSize: 12),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _updateStatusAndRemarks,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: _isSaving
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded, size: 16),
                      label: const Text('Update Status & Remarks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ─── Primary Bottom Action Buttons ───
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _savePdfToDevice,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Save PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _generatePdf,
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('Print / Preview', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E3A8A),
                      side: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _navigateToEditMarks,
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text('Edit Marks', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade400, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _deleteResult,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Delete Result', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _shareOnWhatsApp,
                icon: const Icon(Icons.chat_rounded, size: 18),
                label: const Text('Share Marksheet via WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  List<DataColumn> _buildTableColumns() {
    if (_isDetailedMode) {
      return const [
        DataColumn(label: Text('#')),
        DataColumn(label: Text('Subject Name')),
        DataColumn(label: Text('Theory')),
        DataColumn(label: Text('Practical')),
        DataColumn(label: Text('Internal')),
        DataColumn(label: Text('Max Marks')),
        DataColumn(label: Text('Total Obt')),
        DataColumn(label: Text('Grade')),
        DataColumn(label: Text('Status')),
      ];
    } else {
      return const [
        DataColumn(label: Text('#')),
        DataColumn(label: Text('Subject Name')),
        DataColumn(label: Text('Max Marks')),
        DataColumn(label: Text('Marks Obtained')),
        DataColumn(label: Text('Grade')),
        DataColumn(label: Text('Status')),
      ];
    }
  }

  List<DataRow> _buildTableRows(bool isDark) {
    final rows = <DataRow>[];
    for (int i = 0; i < _currentResult.subjects.length; i++) {
      final s = _currentResult.subjects[i];
      if (_isDetailedMode) {
        rows.add(
          DataRow(
            cells: [
              DataCell(Text('${i + 1}')),
              DataCell(Text(s.subjectName, style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(s.theoryMarks.toInt().toString())),
              DataCell(Text(s.practicalMarks.toInt().toString())),
              DataCell(Text(s.internalMarks.toInt().toString())),
              DataCell(Text(s.totalMarks.toInt().toString())),
              DataCell(Text(
                s.marks.toInt().toString(),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
              )),
              DataCell(Text(s.grade, style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (s.isPass ? Colors.green : Colors.red).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    s.isPass ? 'PASS' : 'FAIL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: s.isPass ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        rows.add(
          DataRow(
            cells: [
              DataCell(Text('${i + 1}')),
              DataCell(Text(s.subjectName, style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(s.totalMarks.toInt().toString())),
              DataCell(Text(
                s.marks.toInt().toString(),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
              )),
              DataCell(Text(s.grade, style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (s.isPass ? Colors.green : Colors.red).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    s.isPass ? 'PASS' : 'FAIL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: s.isPass ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
    return rows;
  }

  Widget _buildMetricItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
