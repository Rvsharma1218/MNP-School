import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/student_model.dart';
import '../../data/services/database_service.dart';
import '../whatsapp/whatsapp_service.dart';
import 'attendance_report_service.dart';

enum _RangeType { today, allDays, custom }

/// Choose Student → THIS screen → Today / All Days / Custom Date Range →
/// date-wise PDF → WhatsApp/Share, per the Attendance Report spec.
///
/// Existing Attendance / Choose Student UI is untouched — this screen only
/// covers the "Particular Student Attendance Report" step that comes after
/// a student is picked.
class AttendanceReportOptionsScreen extends StatefulWidget {
  final String studentId;

  const AttendanceReportOptionsScreen({super.key, required this.studentId});

  @override
  State<AttendanceReportOptionsScreen> createState() =>
      _AttendanceReportOptionsScreenState();
}

class _AttendanceReportOptionsScreenState
    extends State<AttendanceReportOptionsScreen> {
  StudentModel? _student;
  bool _loadingStudent = true;

  _RangeType _rangeType = _RangeType.today;
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();

  bool _generating = false;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _loadStudent();
  }

  Future<void> _loadStudent() async {
    final student = await DatabaseService.instance.getStudentById(widget.studentId);
    if (!mounted) return;
    setState(() {
      _student = student;
      _loadingStudent = false;
    });
  }

  /// Resolves the actual (from, to) range for the current selection.
  /// "All Days" needs the student's earliest attendance record — computed
  /// lazily right when the user generates/shares, not kept in state, so it
  /// always reflects the latest data.
  Future<(DateTime, DateTime)> _resolveRange() async {
    final today = DateTime.now();
    switch (_rangeType) {
      case _RangeType.today:
        return (today, today);
      case _RangeType.custom:
        return (_fromDate, _toDate);
      case _RangeType.allDays:
        final records =
            await DatabaseService.instance.getAttendanceByStudentId(widget.studentId);
        if (records.isEmpty) return (today, today);
        final earliest = records.map((r) => r.date).reduce(
              (a, b) => a.isBefore(b) ? a : b,
            );
        return (earliest, today);
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _fromDate : _toDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
        if (_toDate.isBefore(_fromDate)) _toDate = _fromDate;
      } else {
        _toDate = picked;
        if (_fromDate.isAfter(_toDate)) _fromDate = _toDate;
      }
    });
  }

  Future<void> _preview() async {
    final student = _student;
    if (student == null) return;
    setState(() => _generating = true);
    try {
      final (from, to) = await _resolveRange();
      final settings = await DatabaseService.instance.getSettings();
      final file = await AttendanceReportService.generateStudentAttendancePdf(
        student: student,
        fromDate: from,
        toDate: to,
        instituteName: settings.instituteName,
      );
      await AttendanceReportService.printPdf(file);
    } catch (e) {
      _showError('PDF generation failed: $e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _shareOnWhatsApp() async {
    final student = _student;
    if (student == null) return;
    setState(() => _sharing = true);
    try {
      final (from, to) = await _resolveRange();
      final settings = await DatabaseService.instance.getSettings();
      final file = await AttendanceReportService.generateStudentAttendancePdf(
        student: student,
        fromDate: from,
        toDate: to,
        instituteName: settings.instituteName,
      );

      if (!mounted) return;
      // Existing WhatsApp / WhatsApp Business chooser UI, unchanged.
      await WhatsAppService.sendPdf(
        context: context,
        phone: student.mobile,
        message: AttendanceReportService.whatsappMessage(
          student: student,
          fromDate: from,
          toDate: to,
          instituteName: settings.instituteName,
        ),
        filePath: file.path,
      );
    } catch (e) {
      _showError('Unable to share attendance PDF: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Attendance Report'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loadingStudent
          ? const Center(child: CircularProgressIndicator())
          : _student == null
              ? const Center(child: Text('Student not found'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _studentHeaderCard(_student!),
                    const SizedBox(height: 16),
                    _rangeCard(),
                    const SizedBox(height: 16),
                    _actionsCard(),
                  ],
                ),
    );
  }

  Widget _studentHeaderCard(StudentModel s) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text(
                s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 3),
                  Text(
                    '${s.displayClass} • Roll ${s.rollNumber?.isNotEmpty == true ? s.rollNumber : '—'}',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rangeCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Date Range',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            _rangeOption(
              type: _RangeType.today,
              title: 'Today',
              subtitle: 'Sirf aaj ki attendance',
              icon: Icons.today_rounded,
            ),
            _rangeOption(
              type: _RangeType.allDays,
              title: 'All Days',
              subtitle: 'Starting record se aaj tak — koi limit nahi',
              icon: Icons.all_inclusive_rounded,
            ),
            _rangeOption(
              type: _RangeType.custom,
              title: 'Custom Date Range',
              subtitle: 'From aur To date khud choose karo',
              icon: Icons.date_range_rounded,
            ),
            if (_rangeType == _RangeType.custom) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(child: _dateField('From', _fromDate, () => _pickDate(isFrom: true))),
                  const SizedBox(width: 12),
                  Expanded(child: _dateField('To', _toDate, () => _pickDate(isFrom: false))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rangeOption({
    required _RangeType type,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _rangeType == type;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _rangeType = type),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: selected ? AppColors.primary : AppColors.textPrimary,
                      )),
                  Text(subtitle,
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Radio<_RangeType>(
              value: type,
              groupValue: _rangeType,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _rangeType = v!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField(String label, DateTime value, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(_fmt(value),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                ),
                const Icon(Icons.calendar_month_rounded, size: 17, color: AppColors.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionsCard() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _generating ? null : _preview,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            icon: _generating
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.picture_as_pdf_rounded),
            label: Text(_generating ? 'Generating...' : 'Preview / Print PDF'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _sharing ? null : _shareOnWhatsApp,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
            icon: _sharing
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.chat_bubble_rounded),
            label: Text(_sharing ? 'Preparing PDF...' : 'Send on WhatsApp'),
          ),
        ),
      ],
    );
  }
}
