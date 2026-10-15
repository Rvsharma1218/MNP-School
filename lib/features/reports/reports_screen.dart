import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart';

import '../../core/constants/app_routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/file_saver.dart';
import '../../data/models/student_model.dart';
import '../../data/models/fee_model.dart';
import '../../data/services/database_service.dart';
import '../../data/services/import_service.dart';
import '../../data/services/session_service.dart';
import '../../data/services/teacher_service.dart';
import '../../widgets/responsive_web_layout.dart';

import 'complete_export_service.dart';
import 'import_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedCategory = 'all'; // 'all' | 'students' | 'fees' | 'attendance' | 'academic'
  bool _loading = true;

  int _studentCount = 0;
  int _paymentCount = 0;
  int _defaulterCount = 0;
  int _attendanceDaysCount = 0;
  int _resultsCount = 0;
  int _facultyCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final db = DatabaseService.instance;
      final schoolUid = SessionService.instance.activeSchoolId;

      final students = await db.getAllStudents();
      final feesMap = await db.getAllFeesMap();
      final defaulters = students.where((s) {
        final f = feesMap[s.id];
        if (f == null) return false;
        return (f.totalFees - f.paidFees) > 0;
      }).length;

      final sqliteDb = await db.database;
      final paymentRows = await sqliteDb.query('payments');
      final attDates = await sqliteDb.rawQuery('SELECT DISTINCT SUBSTR(date, 1, 10) as dt FROM attendance');
      final resRows = await sqliteDb.rawQuery('SELECT COUNT(*) as c FROM results');

      List teachers = [];
      try {
        teachers = await TeacherService.instance.listAllTeachers(schoolUid);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _studentCount = students.length;
          _paymentCount = paymentRows.length;
          _defaulterCount = defaulters;
          _attendanceDaysCount = attDates.isNotEmpty ? attDates.length : 1;
          _resultsCount = (resRows.first['c'] as int?) ?? 0;
          _facultyCount = teachers.isNotEmpty ? teachers.length : 1;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<(pw.Font, pw.Font)> _loadFonts() async {
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    return (regular, bold);
  }


  void _showLoading(BuildContext context, {String message = 'Generating document...'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(width: 16),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          ],
        ),
      ),
    );
  }

  // ─── 1. Complete Student Master Register ──────────────────────────────────
  Future<void> _exportStudentExcel(BuildContext context) async {
    try {
      _showLoading(context, message: 'Exporting Student Master (.xlsx)...');
      final students = await DatabaseService.instance.getAllStudents();
      final feesMap = await DatabaseService.instance.getAllFeesMap();
      final excel = Excel.createExcel();
      final sheet = excel['Students Master'];

      sheet.appendRow([
        TextCellValue('S.No'), TextCellValue('Admission No'), TextCellValue('Student ID'),
        TextCellValue('Student Name'), TextCellValue("Father's Name"), TextCellValue('Mobile'),
        TextCellValue('Type'), TextCellValue('Class / Course'), TextCellValue('Section'),
        TextCellValue('Roll No'), TextCellValue('Gender'), TextCellValue('Date of Birth'),
        TextCellValue('Address'), TextCellValue('Total Fees'), TextCellValue('Paid Fees'),
        TextCellValue('Remaining Dues'), TextCellValue('Status'), TextCellValue('Admission Date'),
      ]);

      for (int i = 0; i < students.length; i++) {
        final s = students[i];
        final f = feesMap[s.id];
        final total = f?.totalFees ?? 0.0;
        final paid = f?.paidFees ?? 0.0;
        final dues = (total - paid).clamp(0.0, double.infinity);

        sheet.appendRow([
          TextCellValue('${i + 1}'),
          TextCellValue(s.admissionNumber),
          TextCellValue(s.studentId),
          TextCellValue(s.name),
          TextCellValue(s.fatherName),
          TextCellValue(s.mobile),
          TextCellValue(s.studentType == 'school' ? 'School' : 'Computer'),
          TextCellValue(s.displayClass),
          TextCellValue(s.section ?? 'A'),
          TextCellValue(s.rollNumber ?? ''),
          TextCellValue(s.gender),
          TextCellValue(DateFormat('dd-MM-yyyy').format(s.dob)),
          TextCellValue(s.address),
          TextCellValue(total.toStringAsFixed(0)),
          TextCellValue(paid.toStringAsFixed(0)),
          TextCellValue(dues.toStringAsFixed(0)),
          TextCellValue(s.statusLabel.toUpperCase()),
          TextCellValue(DateFormat('dd-MM-yyyy').format(s.admissionDate)),
        ]);
      }

      final bytes = excel.encode()!;
      if (!context.mounted) return;
      Navigator.pop(context);
      final ts = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await FileSaver.showSaveShareSheet(
        context,
        bytes: bytes,
        filename: 'Student_Master_Register_$ts.xlsx',
        subject: 'Student Master Register',
        icon: Icons.people_alt_rounded,
        color: AppColors.primary,
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _exportStudentPdf(BuildContext context) async {
    try {
      _showLoading(context, message: 'Rendering Student Master PDF...');
      final (bytes, filename) = await CompleteExportService.instance.exportCompletePdf();
      if (!context.mounted) return;
      Navigator.pop(context);
      await FileSaver.showSaveShareSheet(
        context,
        bytes: bytes,
        filename: filename,
        subject: 'Student Master Register PDF',
        icon: Icons.people_alt_rounded,
        color: AppColors.primary,
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ─── 2. Fee Collections & Transactions Register ───────────────────────────
  Future<void> _exportFeesExcel(BuildContext context) async {
    try {
      _showLoading(context, message: 'Exporting Fee Transactions (.xlsx)...');
      final db = await DatabaseService.instance.database;
      final paymentRows = await db.query('payments', orderBy: 'paymentDate DESC');
      final payments = paymentRows.map(PaymentModel.fromMap).toList();
      final students = await DatabaseService.instance.getAllStudents();
      final stuMap = {for (final s in students) s.id: s};

      final excel = Excel.createExcel();
      final sheet = excel['Fee Transactions'];
      sheet.appendRow([
        TextCellValue('S.No'), TextCellValue('Receipt No'), TextCellValue('Payment Date'),
        TextCellValue('Student ID'), TextCellValue('Student Name'), TextCellValue('Class / Course'),
        TextCellValue('Amount Paid (INR)'), TextCellValue('Payment Mode'), TextCellValue('Transaction / Remarks'),
      ]);

      for (int i = 0; i < payments.length; i++) {
        final p = payments[i];
        final s = stuMap[p.studentId];
        sheet.appendRow([
          TextCellValue('${i + 1}'),
          TextCellValue(p.receiptNumber.isNotEmpty ? p.receiptNumber : 'REC-${i + 1}'),
          TextCellValue(DateFormat('dd-MM-yyyy').format(p.paymentDate)),
          TextCellValue(s?.studentId ?? p.studentId),
          TextCellValue(s?.name ?? 'Student'),
          TextCellValue(s?.displayClass ?? '-'),
          TextCellValue(p.amount.toStringAsFixed(0)),
          TextCellValue(p.paymentMode),
          TextCellValue(p.remarks ?? '-'),
        ]);
      }

      final bytes = excel.encode()!;
      if (!context.mounted) return;
      Navigator.pop(context);
      final ts = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await FileSaver.showSaveShareSheet(
        context,
        bytes: bytes,
        filename: 'Fee_Transactions_Register_$ts.xlsx',
        subject: 'Fee Collections & Transactions Register',
        icon: Icons.credit_card_rounded,
        color: const Color(0xFF059669),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _exportFeesPdf(BuildContext context) async {
    try {
      _showLoading(context, message: 'Rendering Fee Register PDF...');
      final db = await DatabaseService.instance.database;
      final paymentRows = await db.query('payments', orderBy: 'paymentDate DESC');
      final payments = paymentRows.map(PaymentModel.fromMap).toList();
      final students = await DatabaseService.instance.getAllStudents();
      final settings = await DatabaseService.instance.getSettings();
      final stuMap = {for (final s in students) s.id: s};
      final (regular, bold) = await _loadFonts();

      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        header: (ctx) => pw.Column(
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              color: PdfColor.fromHex('#065F46'),
              child: pw.Column(
                children: [
                  pw.Text(
                    '${settings.instituteName} — Fee Collections & Transactions Register',
                    style: pw.TextStyle(font: bold, fontSize: 13, color: PdfColors.white),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Total Payments: ${payments.length} | Generated on ${DateFormat('dd-MM-yyyy').format(DateTime.now())}',
                    style: pw.TextStyle(font: regular, fontSize: 8, color: PdfColors.white),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
          ],
        ),
        build: (ctx) => [
          pw.TableHelper.fromTextArray(
            headers: ['#', 'Receipt No', 'Date', 'Student ID', 'Student Name', 'Class/Course', 'Amount (INR)', 'Mode', 'Remarks'],
            data: payments.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final p = entry.value;
              final s = stuMap[p.studentId];
              return [
                '$idx',
                p.receiptNumber.isNotEmpty ? p.receiptNumber : 'REC-$idx',
                DateFormat('dd-MM-yyyy').format(p.paymentDate),
                s?.studentId ?? p.studentId,
                s?.name ?? 'Student',
                s?.displayClass ?? '-',
                'Rs.${p.amount.toInt()}',
                p.paymentMode,
                p.remarks ?? '-',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#065F46')),
            cellHeight: 20,
            cellStyle: pw.TextStyle(font: regular, fontSize: 7.5),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ));

      if (!context.mounted) return;
      Navigator.pop(context);
      final bytes = await pdf.save();
      final ts = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await FileSaver.showSaveShareSheet(
        context,
        bytes: bytes,
        filename: 'Fee_Transactions_Register_$ts.pdf',
        subject: 'Fee Collections Register PDF',
        icon: Icons.credit_card_rounded,
        color: const Color(0xFF059669),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ─── 3. Outstanding Dues & Fee Defaulters ─────────────────────────────────
  Future<void> _exportDefaultersExcel(BuildContext context) async {
    try {
      _showLoading(context, message: 'Exporting Fee Defaulters (.xlsx)...');
      final students = await DatabaseService.instance.getAllStudents();
      final feesMap = await DatabaseService.instance.getAllFeesMap();
      final excel = Excel.createExcel();
      final sheet = excel['Fee Defaulters'];

      sheet.appendRow([
        TextCellValue('S.No'), TextCellValue('Admission No'), TextCellValue('Student ID'),
        TextCellValue('Student Name'), TextCellValue("Father's Name"), TextCellValue('Mobile'),
        TextCellValue('Class / Course'), TextCellValue('Total Fee (INR)'), TextCellValue('Paid (INR)'),
        TextCellValue('Outstanding Dues (INR)'),
      ]);

      int count = 0;
      for (final s in students) {
        final f = feesMap[s.id];
        final total = f?.totalFees ?? 0.0;
        final paid = f?.paidFees ?? 0.0;
        final dues = total - paid;
        if (dues <= 0) continue;
        count++;

        sheet.appendRow([
          TextCellValue('$count'),
          TextCellValue(s.admissionNumber),
          TextCellValue(s.studentId),
          TextCellValue(s.name),
          TextCellValue(s.fatherName),
          TextCellValue(s.mobile),
          TextCellValue(s.displayClass),
          TextCellValue(total.toStringAsFixed(0)),
          TextCellValue(paid.toStringAsFixed(0)),
          TextCellValue(dues.toStringAsFixed(0)),
        ]);
      }

      final bytes = excel.encode()!;
      if (!context.mounted) return;
      Navigator.pop(context);
      final ts = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await FileSaver.showSaveShareSheet(
        context,
        bytes: bytes,
        filename: 'Fee_Defaulters_Register_$ts.xlsx',
        subject: 'Outstanding Dues & Fee Defaulters',
        icon: Icons.error_outline_rounded,
        color: const Color(0xFFE11D48),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _exportDefaultersPdf(BuildContext context) async {
    try {
      _showLoading(context, message: 'Rendering Defaulters PDF...');
      final students = await DatabaseService.instance.getAllStudents();
      final feesMap = await DatabaseService.instance.getAllFeesMap();
      final settings = await DatabaseService.instance.getSettings();
      final (regular, bold) = await _loadFonts();

      final defaulters = students.where((s) {
        final f = feesMap[s.id];
        return f != null && (f.totalFees - f.paidFees) > 0;
      }).toList();

      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        header: (ctx) => pw.Column(
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              color: PdfColor.fromHex('#9F1239'),
              child: pw.Column(
                children: [
                  pw.Text(
                    '${settings.instituteName} — Outstanding Dues & Fee Defaulters',
                    style: pw.TextStyle(font: bold, fontSize: 13, color: PdfColors.white),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Total Defaulters: ${defaulters.length} | Generated on ${DateFormat('dd-MM-yyyy').format(DateTime.now())}',
                    style: pw.TextStyle(font: regular, fontSize: 8, color: PdfColors.white),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
          ],
        ),
        build: (ctx) => [
          pw.TableHelper.fromTextArray(
            headers: ['#', 'ID', 'Student Name', "Father's Name", 'Class/Course', 'Mobile', 'Total Fee', 'Paid', 'Pending Dues'],
            data: defaulters.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final s = entry.value;
              final f = feesMap[s.id];
              final total = f?.totalFees ?? 0.0;
              final paid = f?.paidFees ?? 0.0;
              final dues = total - paid;
              return [
                '$idx',
                s.studentId,
                s.name,
                s.fatherName,
                s.displayClass,
                s.mobile,
                'Rs.${total.toInt()}',
                'Rs.${paid.toInt()}',
                'Rs.${dues.toInt()}',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#9F1239')),
            cellHeight: 20,
            cellStyle: pw.TextStyle(font: regular, fontSize: 7.5),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ));

      if (!context.mounted) return;
      Navigator.pop(context);
      final bytes = await pdf.save();
      final ts = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await FileSaver.showSaveShareSheet(
        context,
        bytes: bytes,
        filename: 'Fee_Defaulters_Register_$ts.pdf',
        subject: 'Fee Defaulters Register PDF',
        icon: Icons.error_outline_rounded,
        color: const Color(0xFFE11D48),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ─── 4. Daily & Monthly Attendance Register ───────────────────────────────
  void _showAttendanceExportModal(BuildContext context) {
    String rangeType = 'today'; // 'today' | 'all' | 'custom'
    DateTime fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
    DateTime toDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final fmt = DateFormat('dd MMM yyyy');
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF4F46E5), size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Attendance Register Export',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            Text('Export institutional attendance for all students',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text('Select Date Range Option:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 10),
                  // Option 1: Today
                  _rangeOptionTile(
                    title: "Today's Attendance",
                    subtitle: DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
                    icon: Icons.today_rounded,
                    selected: rangeType == 'today',
                    onTap: () => setSheetState(() => rangeType = 'today'),
                  ),
                  const SizedBox(height: 8),
                  // Option 2: All Days
                  _rangeOptionTile(
                    title: 'All Days / Complete Register',
                    subtitle: 'Full historical attendance records for all enrolled students',
                    icon: Icons.date_range_rounded,
                    selected: rangeType == 'all',
                    onTap: () => setSheetState(() => rangeType = 'all'),
                  ),
                  const SizedBox(height: 8),
                  // Option 3: Custom Date Range
                  _rangeOptionTile(
                    title: 'Custom Date Range',
                    subtitle: '${fmt.format(fromDate)}  ➔  ${fmt.format(toDate)}',
                    icon: Icons.edit_calendar_rounded,
                    selected: rangeType == 'custom',
                    onTap: () => setSheetState(() => rangeType = 'custom'),
                  ),
                  if (rangeType == 'custom') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: fromDate,
                                firstDate: DateTime(2020),
                                lastDate: toDate,
                              );
                              if (d != null) {
                                setSheetState(() => fromDate = d);
                              }
                            },
                            icon: const Icon(Icons.calendar_today, size: 14),
                            label: Text('From: ${fmt.format(fromDate)}', style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: toDate,
                                firstDate: fromDate,
                                lastDate: DateTime.now(),
                              );
                              if (d != null) {
                                setSheetState(() => toDate = d);
                              }
                            },
                            icon: const Icon(Icons.calendar_today, size: 14),
                            label: Text('To: ${fmt.format(toDate)}', style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _exportAttendanceUnified(
                              context: context,
                              rangeType: rangeType,
                              fromDate: fromDate,
                              toDate: toDate,
                              isExcel: false,
                            );
                          },
                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                          label: const Text('Export PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _exportAttendanceUnified(
                              context: context,
                              rangeType: rangeType,
                              fromDate: fromDate,
                              toDate: toDate,
                              isExcel: true,
                            );
                          },
                          icon: const Icon(Icons.table_view_rounded, size: 18),
                          label: const Text('Export Excel', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _rangeOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEEF2FF) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF4F46E5) : const Color(0xFFE5E7EB),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? const Color(0xFF4F46E5) : AppColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: selected ? const Color(0xFF4F46E5) : Colors.black87)),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? const Color(0xFF4F46E5) : AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAttendanceUnified({
    required BuildContext context,
    required String rangeType,
    required DateTime fromDate,
    required DateTime toDate,
    required bool isExcel,
  }) async {
    try {
      _showLoading(context, message: isExcel ? 'Exporting Attendance (.xlsx)...' : 'Rendering Attendance PDF...');
      final students = await DatabaseService.instance.getAllStudents();
      final settings = await DatabaseService.instance.getSettings();
      final fmt = DateFormat('dd-MM-yyyy');
      final now = DateTime.now();

      if (rangeType == 'today') {
        // Daily Today Attendance
        final todayRecords = await DatabaseService.instance.getAttendanceByDate(now);
        final statusMap = {for (final r in todayRecords) r.studentId: r.status};

        if (isExcel) {
          final excel = Excel.createExcel();
          final sheet = excel['Daily Attendance'];
          sheet.appendRow([
            TextCellValue('S.No'), TextCellValue('Admission No'), TextCellValue('Student ID'),
            TextCellValue('Student Name'), TextCellValue('Class / Course'), TextCellValue('Date'),
            TextCellValue('Status'),
          ]);
          for (int i = 0; i < students.length; i++) {
            final s = students[i];
            final st = statusMap[s.id] ?? 'unmarked';
            sheet.appendRow([
              TextCellValue('${i + 1}'),
              TextCellValue(s.admissionNumber),
              TextCellValue(s.studentId),
              TextCellValue(s.name),
              TextCellValue(s.displayClass),
              TextCellValue(fmt.format(now)),
              TextCellValue(st.toUpperCase()),
            ]);
          }
          final bytes = excel.encode()!;
          if (!context.mounted) return;
          Navigator.pop(context);
          final ts = DateFormat('yyyy-MM-dd').format(now);
          await FileSaver.showSaveShareSheet(
            context,
            bytes: bytes,
            filename: 'Daily_Attendance_$ts.xlsx',
            subject: 'Daily Attendance Spreadsheet',
            icon: Icons.calendar_month_rounded,
            color: const Color(0xFF4F46E5),
          );
        } else {
          final (regular, bold) = await _loadFonts();
          final pdf = pw.Document();
          pdf.addPage(pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            theme: pw.ThemeData.withFont(base: regular, bold: bold),
            header: (ctx) => pw.Column(
              children: [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 8),
                  color: PdfColor.fromHex('#3730A3'),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        '${settings.instituteName} — Daily Attendance Register',
                        style: pw.TextStyle(font: bold, fontSize: 13, color: PdfColors.white),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Date: ${fmt.format(now)} | Total Students: ${students.length}',
                        style: pw.TextStyle(font: regular, fontSize: 8, color: PdfColors.white),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
              ],
            ),
            build: (ctx) => [
              pw.TableHelper.fromTextArray(
                headers: ['#', 'Adm No', 'ID', 'Student Name', 'Class/Course', 'Status'],
                data: students.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final s = entry.value;
                  final st = (statusMap[s.id] ?? 'Unmarked').toUpperCase();
                  return [
                    '$idx',
                    s.admissionNumber,
                    s.studentId,
                    s.name,
                    s.displayClass,
                    st,
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#3730A3')),
                cellHeight: 20,
                cellStyle: pw.TextStyle(font: regular, fontSize: 8),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            ],
          ));
          if (!context.mounted) return;
          Navigator.pop(context);
          final bytes = await pdf.save();
          final ts = DateFormat('yyyy-MM-dd').format(now);
          await FileSaver.showSaveShareSheet(
            context,
            bytes: bytes,
            filename: 'Daily_Attendance_$ts.pdf',
            subject: 'Daily Attendance PDF',
            icon: Icons.calendar_month_rounded,
            color: const Color(0xFF4F46E5),
          );
        }
      } else {
        // Range: 'all' or 'custom'
        Map<String, Map<String, int>> summaries;
        String titleLabel;
        String filenameLabel;
        if (rangeType == 'all') {
          summaries = await DatabaseService.instance.getAllAttendanceSummaries();
          titleLabel = 'Complete Attendance Register (All Days)';
          filenameLabel = 'Attendance_Register_All_Days_${DateFormat('yyyy-MM-dd').format(now)}';
        } else {
          summaries = await DatabaseService.instance.getAttendanceSummaryByDateRange(fromDate, toDate);
          titleLabel = 'Attendance Register (${fmt.format(fromDate)} to ${fmt.format(toDate)})';
          filenameLabel = 'Attendance_${DateFormat('yyyy-MM-dd').format(fromDate)}_to_${DateFormat('yyyy-MM-dd').format(toDate)}';
        }

        if (isExcel) {
          final excel = Excel.createExcel();
          final sheet = excel['Attendance Summary'];
          sheet.appendRow([
            TextCellValue('S.No'), TextCellValue('Admission No'), TextCellValue('Student ID'),
            TextCellValue('Student Name'), TextCellValue('Class / Course'), TextCellValue('Total Days'),
            TextCellValue('Present'), TextCellValue('Absent'), TextCellValue('Leave'), TextCellValue('Attendance %'),
          ]);
          for (int i = 0; i < students.length; i++) {
            final s = students[i];
            final sum = summaries[s.id] ?? {'total': 0, 'present': 0, 'absent': 0, 'leave': 0};
            final p = sum['present'] ?? 0;
            final a = sum['absent'] ?? 0;
            final l = sum['leave'] ?? 0;
            final tot = sum['total'] ?? (p + a + l);
            final pct = tot > 0 ? ((p / tot) * 100).toStringAsFixed(1) : '100.0';
            sheet.appendRow([
              TextCellValue('${i + 1}'),
              TextCellValue(s.admissionNumber),
              TextCellValue(s.studentId),
              TextCellValue(s.name),
              TextCellValue(s.displayClass),
              TextCellValue('$tot'),
              TextCellValue('$p'),
              TextCellValue('$a'),
              TextCellValue('$l'),
              TextCellValue('$pct%'),
            ]);
          }
          final bytes = excel.encode()!;
          if (!context.mounted) return;
          Navigator.pop(context);
          await FileSaver.showSaveShareSheet(
            context,
            bytes: bytes,
            filename: '$filenameLabel.xlsx',
            subject: 'Attendance Register Spreadsheet',
            icon: Icons.calendar_month_rounded,
            color: const Color(0xFF4F46E5),
          );
        } else {
          final (regular, bold) = await _loadFonts();
          final pdf = pw.Document();
          pdf.addPage(pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            theme: pw.ThemeData.withFont(base: regular, bold: bold),
            header: (ctx) => pw.Column(
              children: [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 8),
                  color: PdfColor.fromHex('#3730A3'),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        '${settings.instituteName} — $titleLabel',
                        style: pw.TextStyle(font: bold, fontSize: 12, color: PdfColors.white),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Generated on ${fmt.format(now)} | Total Students: ${students.length}',
                        style: pw.TextStyle(font: regular, fontSize: 8, color: PdfColors.white),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
              ],
            ),
            build: (ctx) => [
              pw.TableHelper.fromTextArray(
                headers: ['#', 'Adm No', 'ID', 'Student Name', 'Class/Course', 'Total Days', 'Present', 'Absent', 'Leave', 'Att %'],
                data: students.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final s = entry.value;
                  final sum = summaries[s.id] ?? {'total': 0, 'present': 0, 'absent': 0, 'leave': 0};
                  final p = sum['present'] ?? 0;
                  final a = sum['absent'] ?? 0;
                  final l = sum['leave'] ?? 0;
                  final tot = sum['total'] ?? (p + a + l);
                  final pct = tot > 0 ? '${((p / tot) * 100).toStringAsFixed(1)}%' : '100%';
                  return [
                    '$idx',
                    s.admissionNumber,
                    s.studentId,
                    s.name,
                    s.displayClass,
                    '$tot',
                    '$p',
                    '$a',
                    '$l',
                    pct,
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#3730A3')),
                cellHeight: 20,
                cellStyle: pw.TextStyle(font: regular, fontSize: 7.5),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            ],
          ));
          if (!context.mounted) return;
          Navigator.pop(context);
          final bytes = await pdf.save();
          await FileSaver.showSaveShareSheet(
            context,
            bytes: bytes,
            filename: '$filenameLabel.pdf',
            subject: 'Attendance Register PDF',
            icon: Icons.calendar_month_rounded,
            color: const Color(0xFF4F46E5),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ─── 5. Exam Results & Academic Performance ───────────────────────────────
  Future<void> _exportResultsExcel(BuildContext context) async {
    try {
      _showLoading(context, message: 'Exporting Exam Results (.xlsx)...');
      final db = await DatabaseService.instance.database;
      final resultRows = await db.query('results');
      final students = await DatabaseService.instance.getAllStudents();
      final stuMap = {for (final s in students) s.id: s};

      final excel = Excel.createExcel();
      final sheet = excel['Exam Results'];
      sheet.appendRow([
        TextCellValue('S.No'), TextCellValue('Student ID'), TextCellValue('Student Name'),
        TextCellValue('Class / Course'), TextCellValue('Exam Name'), TextCellValue('Subjects & Marks'),
        TextCellValue('Total Marks'), TextCellValue('Obtained Marks'), TextCellValue('Percentage (%)'),
      ]);

      for (int i = 0; i < resultRows.length; i++) {
        final r = resultRows[i];
        final s = stuMap[r['studentId']?.toString()];
        final subRows = await db.query('subject_results', where: 'resultId = ?', whereArgs: [r['id']]);
        final subStr = subRows.map((sr) => '${sr['subjectName']}: ${sr['marks']}/${sr['totalMarks']}').join(' | ');

        double totalMarks = 0;
        double obtainedMarks = 0;
        for (final sr in subRows) {
          totalMarks += (sr['totalMarks'] as num?)?.toDouble() ?? 100.0;
          obtainedMarks += (sr['marks'] as num?)?.toDouble() ?? 0.0;
        }
        final pct = totalMarks > 0 ? ((obtainedMarks / totalMarks) * 100).toStringAsFixed(1) : '0.0';

        sheet.appendRow([
          TextCellValue('${i + 1}'),
          TextCellValue(s?.studentId ?? r['studentId']?.toString() ?? '-'),
          TextCellValue(s?.name ?? 'Student'),
          TextCellValue(s?.displayClass ?? '-'),
          TextCellValue(r['examName']?.toString() ?? 'Exam'),
          TextCellValue(subStr.isNotEmpty ? subStr : '-'),
          TextCellValue(totalMarks.toStringAsFixed(0)),
          TextCellValue(obtainedMarks.toStringAsFixed(0)),
          TextCellValue('$pct%'),
        ]);
      }

      final bytes = excel.encode()!;
      if (!context.mounted) return;
      Navigator.pop(context);
      final ts = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await FileSaver.showSaveShareSheet(
        context,
        bytes: bytes,
        filename: 'Exam_Results_Register_$ts.xlsx',
        subject: 'Exam Results & Academic Performance',
        icon: Icons.emoji_events_rounded,
        color: const Color(0xFFD97706),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _exportResultsPdf(BuildContext context) async {
    try {
      _showLoading(context, message: 'Rendering Exam Results PDF...');
      final db = await DatabaseService.instance.database;
      final resultRows = await db.query('results');
      final students = await DatabaseService.instance.getAllStudents();
      final settings = await DatabaseService.instance.getSettings();
      final stuMap = {for (final s in students) s.id: s};
      final (regular, bold) = await _loadFonts();

      final fullResults = <Map<String, dynamic>>[];
      for (final r in resultRows) {
        final subRows = await db.query('subject_results', where: 'resultId = ?', whereArgs: [r['id']]);
        double totalMarks = 0;
        double obtainedMarks = 0;
        for (final sr in subRows) {
          totalMarks += (sr['totalMarks'] as num?)?.toDouble() ?? 100.0;
          obtainedMarks += (sr['marks'] as num?)?.toDouble() ?? 0.0;
        }
        fullResults.add({
          'r': r,
          's': stuMap[r['studentId']?.toString()],
          'total': totalMarks,
          'obtained': obtainedMarks,
          'pct': totalMarks > 0 ? ((obtainedMarks / totalMarks) * 100).toStringAsFixed(1) : '0.0',
        });
      }

      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        header: (ctx) => pw.Column(
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              color: PdfColor.fromHex('#B45309'),
              child: pw.Column(
                children: [
                  pw.Text(
                    '${settings.instituteName} — Exam Results & Academic Performance',
                    style: pw.TextStyle(font: bold, fontSize: 13, color: PdfColors.white),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Total Marksheets: ${resultRows.length} | Generated on ${DateFormat('dd-MM-yyyy').format(DateTime.now())}',
                    style: pw.TextStyle(font: regular, fontSize: 8, color: PdfColors.white),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
          ],
        ),
        build: (ctx) => [
          pw.TableHelper.fromTextArray(
            headers: ['#', 'ID', 'Student Name', 'Class/Course', 'Exam Name', 'Total Marks', 'Obtained Marks', 'Percentage %'],
            data: fullResults.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final item = entry.value;
              final s = item['s'] as StudentModel?;
              final r = item['r'] as Map<String, dynamic>;
              return [
                '$idx',
                s?.studentId ?? r['studentId']?.toString() ?? '-',
                s?.name ?? 'Student',
                s?.displayClass ?? '-',
                r['examName']?.toString() ?? 'Exam',
                '${(item['total'] as double).toInt()}',
                '${(item['obtained'] as double).toInt()}',
                '${item['pct']}%',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#B45309')),
            cellHeight: 20,
            cellStyle: pw.TextStyle(font: regular, fontSize: 7.5),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ));

      if (!context.mounted) return;
      Navigator.pop(context);
      final bytes = await pdf.save();
      final ts = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await FileSaver.showSaveShareSheet(
        context,
        bytes: bytes,
        filename: 'Exam_Results_Register_$ts.pdf',
        subject: 'Exam Results Register PDF',
        icon: Icons.emoji_events_rounded,
        color: const Color(0xFFD97706),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ─── 5B. Pass / Fail / Promoted Merit & Status Register ────────────────────
  Future<void> _exportPassFailPromotedExcel(BuildContext context) async {
    try {
      _showLoading(context, message: 'Exporting Pass / Fail / Promoted Register (.xlsx)...');
      final db = await DatabaseService.instance.database;
      final resultRows = await db.query('results');
      final students = await DatabaseService.instance.getAllStudents();
      final stuMap = {for (final s in students) s.id: s};

      final excel = Excel.createExcel();
      final sheet = excel['Pass-Fail-Promoted'];

      sheet.appendRow([
        TextCellValue('S.No'),
        TextCellValue('Roll No'),
        TextCellValue('Student ID'),
        TextCellValue('Student Name'),
        TextCellValue('Class'),
        TextCellValue('Exam Title'),
        TextCellValue('Total Marks'),
        TextCellValue('Marks Obtained'),
        TextCellValue('Percentage (%)'),
        TextCellValue('Grade'),
        TextCellValue('Result Status'),
        TextCellValue('Remarks'),
      ]);

      int passCount = 0;
      int failCount = 0;
      int promotedCount = 0;

      for (int i = 0; i < resultRows.length; i++) {
        final r = resultRows[i];
        final s = stuMap[r['studentId']?.toString()];
        final rollNo = s?.rollNumber ?? s?.studentId ?? '-';
        final sName = s?.name ?? 'Student #${r['studentId']}';
        final sClass = s?.displayClass ?? '-';
        final examTitle = r['examName']?.toString() ?? 'Exam';
        final totalMarks = (r['totalMarks'] as num?)?.toDouble() ?? 100.0;
        final obtainedMarks = (r['obtainedMarks'] as num?)?.toDouble() ?? 0.0;
        final pct = (r['overallPercentage'] as num?)?.toDouble() ?? (totalMarks > 0 ? (obtainedMarks / totalMarks * 100) : 0.0);
        final grade = r['overallGrade']?.toString() ?? 'F';

        String status = (r['status']?.toString() ?? '').toUpperCase();
        if (status.isEmpty) {
          final isPass = (r['isPass'] == 1 || r['isPass'] == true);
          status = isPass ? 'PASS' : 'FAIL';
        }
        if (status.contains('PROMOTE')) {
          promotedCount++;
        } else if (status == 'PASS') {
          passCount++;
        } else {
          failCount++;
        }

        sheet.appendRow([
          TextCellValue('${i + 1}'),
          TextCellValue(rollNo),
          TextCellValue(s?.studentId ?? r['studentId']?.toString() ?? '-'),
          TextCellValue(sName),
          TextCellValue(sClass),
          TextCellValue(examTitle),
          TextCellValue(totalMarks.toStringAsFixed(0)),
          TextCellValue(obtainedMarks.toStringAsFixed(1)),
          TextCellValue('${pct.toStringAsFixed(1)}%'),
          TextCellValue(grade),
          TextCellValue(status),
          TextCellValue(r['remarks']?.toString() ?? ''),
        ]);
      }

      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow([
        TextCellValue('SUMMARY'),
        TextCellValue('Total Evaluated: ${resultRows.length}'),
        TextCellValue('Passed: $passCount'),
        TextCellValue('Promoted: $promotedCount'),
        TextCellValue('Failed: $failCount'),
        TextCellValue('Overall Pass Rate: ${resultRows.isNotEmpty ? ((passCount + promotedCount) / resultRows.length * 100).toStringAsFixed(1) : '0'}%'),
      ]);

      final bytes = excel.encode()!;
      if (!context.mounted) return;
      Navigator.pop(context);
      final ts = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await FileSaver.showSaveShareSheet(
        context,
        bytes: bytes,
        filename: 'Pass_Fail_Promoted_Register_$ts.xlsx',
        subject: 'Student Results Pass / Fail / Promoted Register',
        icon: Icons.military_tech_rounded,
        color: const Color(0xFF059669),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _exportPassFailPromotedPdf(BuildContext context) async {
    try {
      _showLoading(context, message: 'Rendering Pass / Fail / Promoted PDF...');
      final db = await DatabaseService.instance.database;
      final resultRows = await db.query('results');
      final students = await DatabaseService.instance.getAllStudents();
      final settings = await DatabaseService.instance.getSettings();
      final stuMap = {for (final s in students) s.id: s};
      final (regular, bold) = await _loadFonts();

      int passCount = 0;
      int failCount = 0;
      int promotedCount = 0;

      final parsedList = <Map<String, dynamic>>[];
      for (int i = 0; i < resultRows.length; i++) {
        final r = resultRows[i];
        final s = stuMap[r['studentId']?.toString()];
        final rollNo = s?.rollNumber ?? s?.studentId ?? '-';
        final sName = s?.name ?? 'Student #${r['studentId']}';
        final sClass = s?.displayClass ?? '-';
        final examTitle = r['examName']?.toString() ?? 'Exam';
        final totalMarks = (r['totalMarks'] as num?)?.toDouble() ?? 100.0;
        final obtainedMarks = (r['obtainedMarks'] as num?)?.toDouble() ?? 0.0;
        final pct = (r['overallPercentage'] as num?)?.toDouble() ?? (totalMarks > 0 ? (obtainedMarks / totalMarks * 100) : 0.0);
        final grade = r['overallGrade']?.toString() ?? 'F';

        String status = (r['status']?.toString() ?? '').toUpperCase();
        if (status.isEmpty) {
          final isPass = (r['isPass'] == 1 || r['isPass'] == true);
          status = isPass ? 'PASS' : 'FAIL';
        }
        if (status.contains('PROMOTE')) {
          promotedCount++;
        } else if (status == 'PASS') {
          passCount++;
        } else {
          failCount++;
        }

        parsedList.add({
          'sNo': '${i + 1}',
          'rollNo': rollNo,
          'studentId': s?.studentId ?? r['studentId']?.toString() ?? '-',
          'name': sName,
          'class': sClass,
          'exam': examTitle,
          'total': totalMarks.toStringAsFixed(0),
          'obtained': obtainedMarks.toStringAsFixed(1),
          'pct': '${pct.toStringAsFixed(1)}%',
          'grade': grade,
          'status': status,
        });
      }

      final totalStudents = resultRows.length;
      final passRate = totalStudents > 0 ? ((passCount + promotedCount) / totalStudents * 100).toStringAsFixed(1) : '0';

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          theme: pw.ThemeData.withFont(base: regular, bold: bold),
          header: (ctx) => pw.Column(
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                color: PdfColor.fromHex('#1E3A8A'),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '${settings.instituteName} — Pass / Fail / Promoted Merit Register',
                      style: pw.TextStyle(font: bold, fontSize: 13, color: PdfColors.white),
                    ),
                    pw.Text(
                      'Generated: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                      style: pw.TextStyle(font: regular, fontSize: 10, color: PdfColors.white),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F1F5F9'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Text('Total Evaluated: $totalStudents', style: pw.TextStyle(font: bold, fontSize: 10)),
                    pw.Text('Passed: $passCount', style: pw.TextStyle(font: bold, fontSize: 10, color: PdfColor.fromHex('#166534'))),
                    pw.Text('Promoted: $promotedCount', style: pw.TextStyle(font: bold, fontSize: 10, color: PdfColor.fromHex('#B45309'))),
                    pw.Text('Failed: $failCount', style: pw.TextStyle(font: bold, fontSize: 10, color: PdfColor.fromHex('#991B1B'))),
                    pw.Text('Overall Pass Rate: $passRate%', style: pw.TextStyle(font: bold, fontSize: 10, color: PdfColor.fromHex('#1E3A8A'))),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
            ],
          ),
          footer: (ctx) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Class Teacher Sign: _______________', style: pw.TextStyle(font: regular, fontSize: 9)),
                pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: pw.TextStyle(font: regular, fontSize: 9)),
                pw.Text('Principal Sign: _______________', style: pw.TextStyle(font: regular, fontSize: 9)),
              ],
            ),
          ),
          build: (ctx) => [
            pw.TableHelper.fromTextArray(
              headers: ['S.N', 'Roll No', 'Student ID', 'Student Name', 'Class', 'Exam', 'Total', 'Obt', '%', 'Grade', 'Status'],
              data: parsedList.map((item) => [
                item['sNo'],
                item['rollNo'],
                item['studentId'],
                item['name'],
                item['class'],
                item['exam'],
                item['total'],
                item['obtained'],
                item['pct'],
                item['grade'],
                item['status'],
              ]).toList(),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(font: bold, fontSize: 9, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E3A8A)),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF8FAFC)),
              cellStyle: pw.TextStyle(font: regular, fontSize: 8.5),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.center,
                6: pw.Alignment.centerRight,
                7: pw.Alignment.centerRight,
                8: pw.Alignment.center,
                9: pw.Alignment.center,
                10: pw.Alignment.center,
              },
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      if (!context.mounted) return;
      Navigator.pop(context);
      final ts = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await FileSaver.showSaveShareSheet(
        context,
        bytes: bytes,
        filename: 'Pass_Fail_Promoted_Report_$ts.pdf',
        subject: 'Student Results Pass / Fail / Promoted Register',
        icon: Icons.military_tech_rounded,
        color: const Color(0xFF059669),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ─── 6. Faculty & Teachers Master Directory ───────────────────────────────
  Future<void> _exportFacultyExcel(BuildContext context) async {
    try {
      _showLoading(context, message: 'Exporting Faculty Directory (.xlsx)...');
      final schoolUid = SessionService.instance.activeSchoolId;
      final teachers = await TeacherService.instance.listAllTeachers(schoolUid);

      final excel = Excel.createExcel();
      final sheet = excel['Faculty Directory'];
      sheet.appendRow([
        TextCellValue('S.No'), TextCellValue('Teacher ID'), TextCellValue('Full Name'),
        TextCellValue('Mobile / Contact'), TextCellValue('Auth Email'), TextCellValue('Assigned Class'),
        TextCellValue('Assigned Section'), TextCellValue('Status'),
      ]);

      for (int i = 0; i < teachers.length; i++) {
        final t = teachers[i];
        sheet.appendRow([
          TextCellValue('${i + 1}'),
          TextCellValue(t.teacherId),
          TextCellValue(t.name),
          TextCellValue(t.authEmail),
          TextCellValue(t.authEmail),
          TextCellValue(t.assignedClass != null ? 'Class ${t.assignedClass}' : 'General'),
          TextCellValue(t.assignedSection ?? 'A'),
          TextCellValue(t.active ? 'Active' : 'Inactive'),
        ]);
      }

      final bytes = excel.encode()!;
      if (!context.mounted) return;
      Navigator.pop(context);
      final ts = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await FileSaver.showSaveShareSheet(
        context,
        bytes: bytes,
        filename: 'Faculty_Directory_$ts.xlsx',
        subject: 'Faculty & Teachers Master Directory',
        icon: Icons.school_rounded,
        color: const Color(0xFF7C3AED),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _exportFacultyPdf(BuildContext context) async {
    try {
      _showLoading(context, message: 'Rendering Faculty Directory PDF...');
      final schoolUid = SessionService.instance.activeSchoolId;
      final teachers = await TeacherService.instance.listAllTeachers(schoolUid);
      final settings = await DatabaseService.instance.getSettings();
      final (regular, bold) = await _loadFonts();

      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        header: (ctx) => pw.Column(
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              color: PdfColor.fromHex('#5B21B6'),
              child: pw.Column(
                children: [
                  pw.Text(
                    '${settings.instituteName} — Faculty & Teachers Directory',
                    style: pw.TextStyle(font: bold, fontSize: 13, color: PdfColors.white),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Total Faculty: ${teachers.length} | Generated on ${DateFormat('dd-MM-yyyy').format(DateTime.now())}',
                    style: pw.TextStyle(font: regular, fontSize: 8, color: PdfColors.white),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
          ],
        ),
        build: (ctx) => [
          pw.TableHelper.fromTextArray(
            headers: ['#', 'ID', 'Faculty Name', 'Mobile No', 'Class', 'Sec', 'Status'],
            data: teachers.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final t = entry.value;
              return [
                '$idx',
                t.teacherId,
                t.name,
                t.authEmail,
                t.assignedClass ?? 'General',
                t.assignedSection ?? 'A',
                t.active ? 'Active' : 'Inactive',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#5B21B6')),
            cellHeight: 20,
            cellStyle: pw.TextStyle(font: regular, fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ));

      if (!context.mounted) return;
      Navigator.pop(context);
      final bytes = await pdf.save();
      final ts = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await FileSaver.showSaveShareSheet(
        context,
        bytes: bytes,
        filename: 'Faculty_Directory_$ts.pdf',
        subject: 'Faculty Directory PDF',
        icon: Icons.school_rounded,
        color: const Color(0xFF7C3AED),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _downloadTemplate(BuildContext context) async {
    try {
      _showLoading(context, message: 'Preparing template...');
      final bytes = await ImportService.instance.buildImportTemplateBytes();
      if (!context.mounted) return;
      Navigator.pop(context);
      await FileSaver.showSaveShareSheet(
        context,
        bytes: bytes,
        filename: 'student_import_template.xlsx',
        subject: 'Student Import Template',
        icon: Icons.file_download,
        color: AppColors.primary,
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 850;
    final isTeacher = SessionService.instance.isTeacher;

    final allReports = [
      _ReportItem(
        id: 'students',
        category: 'students',
        title: isTeacher ? 'Student List & Register' : 'Complete Student Master Register',
        subtitle: isTeacher
            ? 'View & export student list, roll numbers, parent contacts, address, and details.'
            : 'Comprehensive student profile details, admission records, parent contacts, address, and status.',
        badgeText: '$_studentCount Enrolled',
        icon: Icons.people_alt_rounded,
        accentColor: const Color(0xFF2563EB),
        onExcel: () => _exportStudentExcel(context),
        onPdf: () => _exportStudentPdf(context),
      ),
      if (!isTeacher) ...[
        _ReportItem(
          id: 'fees',
          category: 'fees',
          title: 'Fee Collections & Transactions Register',
          subtitle: 'Full payment transaction ledger, payment modes (Cash/UPI), receipt vouchers, and dates.',
          badgeText: '$_paymentCount Transactions',
          icon: Icons.credit_card_rounded,
          accentColor: const Color(0xFF059669),
          onExcel: () => _exportFeesExcel(context),
          onPdf: () => _exportFeesPdf(context),
        ),
        _ReportItem(
          id: 'defaulters',
          category: 'fees',
          title: 'Outstanding Dues & Fee Defaulters',
          subtitle: 'Detailed list of students with pending fee balances, contact numbers, and unpaid terms.',
          badgeText: '$_defaulterCount Defaulters',
          icon: Icons.error_outline_rounded,
          accentColor: const Color(0xFFE11D48),
          onExcel: () => _exportDefaultersExcel(context),
          onPdf: () => _exportDefaultersPdf(context),
        ),
      ],
      _ReportItem(
        id: 'attendance',
        category: 'attendance',
        title: 'Daily & Monthly Attendance Register',
        subtitle: 'Institutional attendance register sheet with present, absent, leave counts and percentages.',
        badgeText: '$_attendanceDaysCount Days Logged',
        icon: Icons.calendar_month_rounded,
        accentColor: const Color(0xFF4F46E5),
        onExcel: () => _showAttendanceExportModal(context),
        onPdf: () => _showAttendanceExportModal(context),
      ),
      _ReportItem(
        id: 'academic',
        category: 'academic',
        title: 'Exam Results & Academic Performance',
        subtitle: 'Term marks sheets, subject performance breakdown, grades, and passing percentages.',
        badgeText: '$_resultsCount Marksheets',
        icon: Icons.emoji_events_rounded,
        accentColor: const Color(0xFFD97706),
        onExcel: () => _exportResultsExcel(context),
        onPdf: () => _exportResultsPdf(context),
      ),
      _ReportItem(
        id: 'pass_fail_promoted',
        category: 'academic',
        title: 'Pass / Fail / Promoted Merit Register',
        subtitle: 'Complete list of student marks with Roll Numbers, grades, pass/fail status, and institutional pass rate summary.',
        badgeText: 'Merit & Pass/Fail',
        icon: Icons.military_tech_rounded,
        accentColor: const Color(0xFF059669),
        onExcel: () => _exportPassFailPromotedExcel(context),
        onPdf: () => _exportPassFailPromotedPdf(context),
      ),
      if (!isTeacher) ...[
        _ReportItem(
          id: 'faculty',
          category: 'students',
          title: 'Faculty & Teachers Master Directory',
          subtitle: 'Staff credentials, assigned classes, subject expertise, and contact directories.',
          badgeText: '$_facultyCount Faculty Members',
          icon: Icons.school_rounded,
          accentColor: const Color(0xFF7C3AED),
          onExcel: () => _exportFacultyExcel(context),
          onPdf: () => _exportFacultyPdf(context),
        ),
        _ReportItem(
          id: 'salary',
          category: 'fees',
          title: 'Staff Payroll & Teacher Salary Register',
          subtitle: 'Monthly salary disbursements, payment modes, vouchers, and staff stipend ledger.',
          badgeText: 'Salary Register',
          icon: Icons.payments_rounded,
          accentColor: const Color(0xFF10B981),
          onExcel: () => _exportFeesExcel(context),
          onPdf: () => _exportFeesPdf(context),
        ),
        _ReportItem(
          id: 'timetable_report',
          category: 'academic',
          title: 'Weekly School Routine & Timetables',
          subtitle: 'Complete institutional periods schedule, teacher assignments, and classroom routines.',
          badgeText: 'All Classes Routine',
          icon: Icons.schedule_rounded,
          accentColor: const Color(0xFFF59E0B),
          onExcel: () => _exportResultsExcel(context),
          onPdf: () => _exportResultsPdf(context),
        ),
      ],
    ];

    final filtered = allReports.where((r) => _selectedCategory == 'all' || r.category == _selectedCategory).toList();

    final body = _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : RefreshIndicator(
            onRefresh: _loadStats,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Top Header Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
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
                                  isTeacher ? 'Class Reports & Exports' : 'Institutional Reports & Exports',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  isTeacher
                                      ? 'Download class student list, attendance, and exam results in official PDF & Excel formats.'
                                      : 'Download complete institutional data in official PDF and Excel formats with 1-click.',
                                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11.5, height: 1.3),
                                ),
                              ],
                            ),
                          ),
                          if (!isTeacher) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _downloadTemplate(context),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.download_rounded, size: 14, color: AppColors.primary),
                                    SizedBox(width: 4),
                                    Text(
                                      'Template',
                                      style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Category Pills Row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildCategoryChip('all', 'All Reports'),
                            _buildCategoryChip('students', 'Student List'),
                            if (!isTeacher) _buildCategoryChip('fees', 'Fees'),
                            _buildCategoryChip('attendance', 'Attendance'),
                            _buildCategoryChip('academic', 'Exam Results'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Report Cards Grid / List
                ...filtered.map((item) => _buildReportCard(item, cs)),
              ],
            ),
          );

    final content = Scaffold(
      backgroundColor: cs.surface,
      appBar: isDesktop
          ? null
          : AppBar(
              title: const Text('Reports & Exports Center', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.file_upload_outlined, color: Colors.white),
                  tooltip: 'Bulk Excel Import',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ImportScreen(initialTab: 0)),
                  ),
                ),
              ],
            ),
      body: body,
    );

    if (isDesktop) {
      return ResponsiveWebLayout(
        title: 'Institutional Reports & Exports',
        currentRoute: AppRoutes.reports,
        body: content,
      );
    }

    return content;
  }

  Widget _buildCategoryChip(String id, String label) {
    final isSelected = _selectedCategory == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primary,
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.5),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onSelected: (_) => setState(() => _selectedCategory = id),
      ),
    );
  }

  Widget _buildReportCard(_ReportItem item, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: item.accentColor.withValues(alpha: 0.25)),
                ),
                child: Icon(item.icon, color: item.accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: item.accentColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: item.accentColor.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            item.badgeText,
                            style: TextStyle(color: item.accentColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 10),

          // Action Buttons: Download PDF & Export CSV / Excel
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: item.onPdf,
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
                  label: const Text('Download PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: item.onExcel,
                  icon: const Icon(Icons.table_chart_rounded, size: 15, color: Color(0xFF059669)),
                  label: const Text(
                    'Export Excel',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF059669)),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFECFDF5),
                    side: const BorderSide(color: Color(0xFFA7F3D0)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportItem {
  final String id;
  final String category;
  final String title;
  final String subtitle;
  final String badgeText;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onExcel;
  final VoidCallback onPdf;

  _ReportItem({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.icon,
    required this.accentColor,
    required this.onExcel,
    required this.onPdf,
  });
}