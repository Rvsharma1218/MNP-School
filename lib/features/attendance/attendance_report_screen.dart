import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/student_model.dart';
import '../../data/services/database_service.dart';
import '../whatsapp/whatsapp_service.dart';
import 'attendance_report_service.dart';

/// Individual student's complete attendance history/report.
/// Reuses the existing WhatsApp chooser UI.
class AttendanceReportScreen extends ConsumerStatefulWidget {
  const AttendanceReportScreen({super.key});

  @override
  ConsumerState<AttendanceReportScreen> createState() =>
      _AttendanceReportScreenState();
}

class _AttendanceReportScreenState
    extends ConsumerState<AttendanceReportScreen> {
  final _searchController = TextEditingController();

  List<StudentModel> _students = [];
  StudentModel? _selectedStudent;

  DateTime _fromDate = DateTime(DateTime.now().year, 1, 1);
  DateTime _toDate = DateTime.now();

  bool _loading = true;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() => _loading = true);
    try {
      final students = await DatabaseService.instance.getAllStudents();
      if (!mounted) return;
      setState(() {
        _students = students;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Unable to load students: $e');
    }
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: _toDate,
      helpText: 'Attendance From Date',
    );
    if (picked != null) setState(() => _fromDate = picked);
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: _fromDate,
      lastDate: DateTime.now(),
      helpText: 'Attendance To Date',
    );
    if (picked != null) setState(() => _toDate = picked);
  }

  Future<void> _chooseStudent() async {
    final selected = await showModalBottomSheet<StudentModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        String query = '';

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final q = query.trim().toLowerCase();
            final list = q.isEmpty
                ? _students
                : _students.where((s) {
              return s.name.toLowerCase().contains(q) ||
                  s.admissionNumber.toLowerCase().contains(q) ||
                  s.studentId.toLowerCase().contains(q) ||
                  s.mobile.contains(q);
            }).toList();

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * .82,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 18, 16, 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Choose Student',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        onChanged: (v) => setSheetState(() => query = v),
                        decoration: InputDecoration(
                          hintText: 'Search student, ID, admission no...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: list.isEmpty
                          ? const Center(child: Text('No students found'))
                          : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: list.length,
                        separatorBuilder: (_, __) =>
                        const SizedBox(height: 4),
                        itemBuilder: (_, index) {
                          final student = list[index];
                          final selected =
                              _selectedStudent?.id == student.id;
                          return ListTile(
                            selected: selected,
                            selectedTileColor:
                            AppColors.primary.withOpacity(.08),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            leading: CircleAvatar(
                              backgroundColor:
                              AppColors.primary.withOpacity(.10),
                              child: Text(
                                student.name.isEmpty
                                    ? '?'
                                    : student.name[0].toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            title: Text(
                              student.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${student.admissionNumber} • ${student.displayClass}',
                            ),
                            trailing: selected
                                ? const Icon(
                              Icons.check_circle,
                              color: AppColors.success,
                            )
                                : const Icon(Icons.chevron_right),
                            onTap: () =>
                                Navigator.pop(context, student),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selected != null && mounted) {
      setState(() => _selectedStudent = selected);
    }
  }

  Future<void> _generatePdf({required bool sendWhatsApp}) async {
    final student = _selectedStudent;
    if (student == null) {
      _showError('Please choose a student first.');
      return;
    }
    if (_fromDate.isAfter(_toDate)) {
      _showError('From date cannot be after To date.');
      return;
    }

    setState(() => _generating = true);
    try {
      final settings = await DatabaseService.instance.getSettings();
      final file =
      await AttendanceReportService.generateStudentAttendancePdf(
        student: student,
        fromDate: _fromDate,
        toDate: _toDate,
        instituteName: settings.instituteName,
      );

      if (!mounted) return;

      if (sendWhatsApp) {
        await WhatsAppService.sendPdf(
          context: context,
          phone: student.mobile,
          message: AttendanceReportService.whatsappMessage(
            student: student,
            fromDate: _fromDate,
            toDate: _toDate,
            instituteName: settings.instituteName,
          ),
          filePath: file.path,
        );
        if (mounted) _showSuccess('Attendance PDF sent to WhatsApp.');
      } else {
        await AttendanceReportService.printPdf(file);
      }
    } catch (e) {
      if (mounted) _showError('Attendance PDF failed: $e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        title: const Text('Attendance Report'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 0,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _chooseStudent,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 23,
                        backgroundColor:
                        AppColors.primary.withOpacity(.10),
                        child: const Icon(
                          Icons.person_search_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _selectedStudent == null
                            ? const Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose Student',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Select one student for attendance history',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        )
                            : Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedStudent!.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${_selectedStudent!.admissionNumber} • '
                                  '${_selectedStudent!.displayClass}'
                                  '${(_selectedStudent!.rollNumber?.isNotEmpty == true) ? ' • Roll No. ${_selectedStudent!.rollNumber}' : ''}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Attendance Date Range',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _dateTile(
                            label: 'From',
                            date: _fromDate,
                            onTap: _pickFromDate,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _dateTile(
                            label: 'To',
                            date: _toDate,
                            onTap: _pickToDate,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select any range you want: admission date to today, '
                          'one month, several months, or any custom period.',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _generating
                  ? null
                  : () => _generatePdf(sendWhatsApp: false),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(50),
              ),
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text(
                'Generate Attendance PDF',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _generating
                  ? null
                  : () => _generatePdf(sendWhatsApp: true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                minimumSize: const Size.fromHeight(50),
              ),
              icon: const Icon(Icons.share_rounded),
              label: const Text(
                'Send Attendance PDF on WhatsApp',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (_generating) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 6),
              const Text(
                'Generating attendance PDF...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dateTile({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.primary.withOpacity(.20),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    AppUtils.formatDate(date),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
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