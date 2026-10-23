import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';

import '../models/fee_model.dart';
import '../models/result_model.dart';
import '../models/settings_model.dart';
import '../models/student_model.dart';
import '../../core/utils/app_utils.dart';
import '../../core/utils/file_saver.dart';
import '../../features/whatsapp/whatsapp_service.dart';

/// Centralized service to generate official Comprehensive Full Student Statements (PDF, Excel & WhatsApp).
class StudentFullReportService {
  StudentFullReportService._();
  static final StudentFullReportService instance = StudentFullReportService._();

  static const PdfColor primaryNavy = PdfColor.fromInt(0xFF1F108E);
  static const PdfColor goldText = PdfColor.fromInt(0xFFFFD700);
  static const PdfColor textDark = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor textMuted = PdfColor.fromInt(0xFF475569);
  static const PdfColor borderLight = PdfColor.fromInt(0xFFCBD5E1);
  static const PdfColor cardBg = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor totalBg = PdfColor.fromInt(0xFFEEF2FF);

  static const PdfColor passBg = PdfColor.fromInt(0xFFDCFCE7);
  static const PdfColor passText = PdfColor.fromInt(0xFF166534);
  static const PdfColor failBg = PdfColor.fromInt(0xFFFEE2E2);
  static const PdfColor failText = PdfColor.fromInt(0xFF991B1B);

  // ─── Filter Helper ────────────────────────────────────────────────────────
  ({
    List<PaymentModel> payments,
    Map<String, dynamic> attendance,
    List<ResultModel> results,
    String filterLabel,
  }) filterData({
    required List<PaymentModel> allPayments,
    required Map<String, dynamic> allAttendance,
    required List<ResultModel> allResults,
    required String monthFilter,
  }) {
    if (monthFilter == 'all') {
      return (
        payments: allPayments,
        attendance: allAttendance,
        results: allResults,
        filterLabel: 'ALL TIME / COMPREHENSIVE LIFETIME (TILL DATE)',
      );
    }

    try {
      final parts = monthFilter.split('-');
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final dt = DateTime(y, m);
      final label = DateFormat('MMMM yyyy').format(dt).toUpperCase();

      final filteredPayments = allPayments.where((p) {
        final d = DateFormat('yyyy-MM').format(p.paymentDate);
        return d == monthFilter;
      }).toList();

      final filteredAtt = Map<String, dynamic>.fromEntries(
        allAttendance.entries.where((e) => e.key.startsWith(monthFilter)),
      );

      final filteredResults = allResults.where((r) {
        final d = DateFormat('yyyy-MM').format(r.createdAt);
        return d == monthFilter;
      }).toList();

      return (
        payments: filteredPayments,
        attendance: filteredAtt,
        results: filteredResults.isNotEmpty ? filteredResults : allResults,
        filterLabel: 'MONTH: $label',
      );
    } catch (_) {
      return (
        payments: allPayments,
        attendance: allAttendance,
        results: allResults,
        filterLabel: 'ALL TIME / COMPREHENSIVE LIFETIME',
      );
    }
  }

  // ─── Generate PDF Document ────────────────────────────────────────────────
  Future<pw.Document> generateDocument({
    required StudentModel student,
    required List<PaymentModel> payments,
    required Map<String, dynamic> attendance,
    required List<ResultModel> results,
    required SettingsModel settings,
    String monthFilter = 'all',
  }) async {
    final ttf = await PdfGoogleFonts.notoSansRegular();
    final ttfBold = await PdfGoogleFonts.notoSansBold();

    final logoBytes = await AppUtils.loadAppImageBytes(settings.logoPath);
    final logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    final sigBytes = await AppUtils.loadAppImageBytes(settings.principalSignature);
    final sigImage = sigBytes != null ? pw.MemoryImage(sigBytes) : null;

    final stampBytes = await AppUtils.loadAppImageBytes(settings.schoolStamp);
    final stampImage = stampBytes != null ? pw.MemoryImage(stampBytes) : null;

    final filtered = filterData(
      allPayments: payments,
      allAttendance: attendance,
      allResults: results,
      monthFilter: monthFilter,
    );

    final totalFee = student.totalFees > 0 ? student.totalFees : 0.0;
    final paidFee = filtered.payments.fold<double>(0.0, (sum, p) => sum + p.amount);
    final remainingDue = (totalFee - paidFee).clamp(0.0, double.infinity);

    // Attendance stats
    int totalMarked = 0, present = 0, absent = 0, leave = 0;
    filtered.attendance.forEach((_, val) {
      String status = '';
      if (val is Map) {
        status = (val[student.id] ?? val[student.studentId] ?? '').toString().toLowerCase();
      } else if (val is String) {
        status = val.toLowerCase();
      }
      if (status.isNotEmpty) {
        totalMarked++;
        if (status == 'present') present++;
        if (status == 'absent') absent++;
        if (status == 'leave') leave++;
      }
    });
    final attPct = totalMarked > 0 ? ((present / totalMarked) * 100).toStringAsFixed(1) : '0.0';

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context ctx) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: primaryNavy, width: 2),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // ─── Header ───────────────────────────────────────────
                pw.Center(
                  child: pw.Column(
                    children: [
                      if (logoImage != null) ...[
                        pw.Image(logoImage, width: 44, height: 44, fit: pw.BoxFit.contain),
                        pw.SizedBox(height: 6),
                      ],
                      pw.Text(
                        (settings.instituteName.isNotEmpty ? settings.instituteName : 'MISSION NAVODAYA PUBLIC SCHOOL').toUpperCase(),
                        style: pw.TextStyle(font: ttfBold, fontSize: 17, color: primaryNavy),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 3),
                      if (settings.address.isNotEmpty)
                        pw.Text(
                          settings.address,
                          style: pw.TextStyle(font: ttf, fontSize: 8.5, color: textMuted),
                          textAlign: pw.TextAlign.center,
                        ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Affiliation: ${(settings.affiliationNumber != null && settings.affiliationNumber!.isNotEmpty) ? settings.affiliationNumber! : "Recognized"}'
                        '${settings.mobile.isNotEmpty ? " • Helpline: ${settings.mobile}" : ""}',
                        style: pw.TextStyle(font: ttf, fontSize: 8, color: textMuted),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 8),

                      // Title Banner
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: const pw.BoxDecoration(
                          color: primaryNavy,
                          borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
                        ),
                        child: pw.Text(
                          'STUDENT COMPREHENSIVE PERFORMANCE & FEE STATEMENT',
                          style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: goldText, letterSpacing: 0.8),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'REPORT PERIOD: ${filtered.filterLabel}',
                        style: pw.TextStyle(font: ttfBold, fontSize: 8, color: textMuted),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 8),
                pw.Divider(color: primaryNavy, thickness: 1),
                pw.SizedBox(height: 6),

                // ─── Student Particulars Card ──────────────────────────
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: cardBg,
                    border: pw.Border.all(color: borderLight, width: 1),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Student Name:', student.name.toUpperCase(), ttf, ttfBold, isHighlight: true),
                            pw.SizedBox(height: 3),
                            _buildInfoRow("Father's Name:", student.fatherName.isNotEmpty ? student.fatherName : '—', ttf, ttfBold),
                            pw.SizedBox(height: 3),
                            _buildInfoRow('Class / Course:', student.displayClass, ttf, ttfBold),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 14),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Student ID:', student.studentId, ttf, ttfBold),
                            pw.SizedBox(height: 3),
                            _buildInfoRow('Roll / Contact:', 'Roll: ${student.rollNumber ?? "N/A"} • Mob: ${student.mobile}', ttf, ttfBold),
                            pw.SizedBox(height: 3),
                            _buildInfoRow('Session:', student.session ?? settings.currentSession, ttf, ttfBold),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 10),

                // ─── Fee Account Standing Banner ───────────────────────
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: totalBg,
                    border: pw.Border.all(color: primaryNavy, width: 0.8),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('FEE ACCOUNT STATUS:', style: pw.TextStyle(font: ttfBold, fontSize: 8, color: primaryNavy)),
                      pw.Text('Total Course Fee: Rs. ${totalFee.toStringAsFixed(0)}', style: pw.TextStyle(font: ttf, fontSize: 8, color: textDark)),
                      pw.Text('Total Paid: Rs. ${paidFee.toStringAsFixed(0)}', style: pw.TextStyle(font: ttfBold, fontSize: 8, color: passText)),
                      pw.Text('Balance Due: Rs. ${remainingDue.toStringAsFixed(0)}',
                          style: pw.TextStyle(font: ttfBold, fontSize: 8, color: remainingDue > 0 ? failText : passText)),
                    ],
                  ),
                ),

                pw.SizedBox(height: 8),

                // ─── Payment Receipts Mini Table ───────────────────────
                pw.Text('Fee Payment Receipts (${filtered.payments.length})', style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: primaryNavy)),
                pw.SizedBox(height: 3),
                if (filtered.payments.isEmpty)
                  pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: borderLight, width: 0.8), color: cardBg),
                    child: pw.Center(
                      child: pw.Text('No payment transactions recorded for this period.', style: pw.TextStyle(font: ttf, fontSize: 7.5, color: textMuted)),
                    ),
                  )
                else
                  pw.Table(
                    border: pw.TableBorder.all(color: borderLight, width: 0.6),
                    columnWidths: const {
                      0: pw.FixedColumnWidth(26),
                      1: pw.FlexColumnWidth(2.5),
                      2: pw.FlexColumnWidth(2.5),
                      3: pw.FlexColumnWidth(2.5),
                      4: pw.FlexColumnWidth(3.5),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: primaryNavy),
                        children: [
                          _buildTh('S.N.', ttfBold, align: pw.TextAlign.center),
                          _buildTh('Receipt No', ttfBold),
                          _buildTh('Date', ttfBold),
                          _buildTh('Amount (Rs.)', ttfBold, align: pw.TextAlign.center),
                          _buildTh('Mode & Remarks', ttfBold),
                        ],
                      ),
                      ...filtered.payments.take(6).map((p) {
                        final idx = filtered.payments.indexOf(p);
                        final rNo = p.receiptNumber.isNotEmpty ? p.receiptNumber : 'REC-${p.id.take(6)}';
                        final dateStr = DateFormat('dd/MM/yyyy').format(p.paymentDate);
                        return pw.TableRow(
                          decoration: pw.BoxDecoration(color: idx % 2 == 1 ? cardBg : PdfColors.white),
                          children: [
                            _buildTd('${idx + 1}', ttf, align: pw.TextAlign.center),
                            _buildTd(rNo, ttfBold),
                            _buildTd(dateStr, ttf),
                            _buildTd('Rs. ${p.amount.toStringAsFixed(0)}', ttfBold, align: pw.TextAlign.center, color: passText),
                            _buildTd('${p.paymentMode} • ${p.remarks ?? "Fee Payment"}', ttf),
                          ],
                        );
                      }),
                    ],
                  ),

                pw.SizedBox(height: 8),

                // ─── Attendance Summary Banner ─────────────────────────
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: cardBg,
                    border: pw.Border.all(color: borderLight, width: 0.8),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('ATTENDANCE RECORD:', style: pw.TextStyle(font: ttfBold, fontSize: 8, color: primaryNavy)),
                      pw.Text('Total Days: $totalMarked', style: pw.TextStyle(font: ttf, fontSize: 8, color: textDark)),
                      pw.Text('Present: $present', style: pw.TextStyle(font: ttf, fontSize: 8, color: passText)),
                      pw.Text('Absent: $absent', style: pw.TextStyle(font: ttf, fontSize: 8, color: failText)),
                      pw.Text('Leave: $leave', style: pw.TextStyle(font: ttf, fontSize: 8, color: textDark)),
                      pw.Text('Rate: $attPct%', style: pw.TextStyle(font: ttfBold, fontSize: 8, color: double.parse(attPct) >= 75 ? passText : failText)),
                    ],
                  ),
                ),

                pw.SizedBox(height: 8),

                // ─── Academic Exam Results ─────────────────────────────
                if (filtered.results.isNotEmpty) ...[
                  pw.Text('Academic Examination Results (${filtered.results.length})', style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: primaryNavy)),
                  pw.SizedBox(height: 3),
                  pw.Table(
                    border: pw.TableBorder.all(color: borderLight, width: 0.6),
                    columnWidths: const {
                      0: pw.FixedColumnWidth(26),
                      1: pw.FlexColumnWidth(3.5),
                      2: pw.FlexColumnWidth(2),
                      3: pw.FlexColumnWidth(2),
                      4: pw.FlexColumnWidth(2),
                      5: pw.FlexColumnWidth(2),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: primaryNavy),
                        children: [
                          _buildTh('S.N.', ttfBold, align: pw.TextAlign.center),
                          _buildTh('Exam Name', ttfBold),
                          _buildTh('Max Marks', ttfBold, align: pw.TextAlign.center),
                          _buildTh('Obtained', ttfBold, align: pw.TextAlign.center),
                          _buildTh('Percentage', ttfBold, align: pw.TextAlign.center),
                          _buildTh('Grade', ttfBold, align: pw.TextAlign.center),
                        ],
                      ),
                      ...filtered.results.take(4).map((r) {
                        final idx = filtered.results.indexOf(r);
                        final tMax = r.subjects.isNotEmpty ? r.subjects.fold<double>(0, (s, e) => s + e.totalMarks) : r.totalMarks;
                        final tObt = r.subjects.isNotEmpty ? r.subjects.fold<double>(0, (s, e) => s + e.marks) : r.obtainedMarks;
                        final p = tMax > 0 ? ((tObt / tMax) * 100).toStringAsFixed(1) : '0';
                        return pw.TableRow(
                          decoration: pw.BoxDecoration(color: idx % 2 == 1 ? cardBg : PdfColors.white),
                          children: [
                            _buildTd('${idx + 1}', ttf, align: pw.TextAlign.center),
                            _buildTd(r.examName, ttfBold),
                            _buildTd(tMax.toStringAsFixed(0), ttf, align: pw.TextAlign.center),
                            _buildTd(tObt.toStringAsFixed(0), ttfBold, align: pw.TextAlign.center, color: primaryNavy),
                            _buildTd('$p%', ttf, align: pw.TextAlign.center),
                            _buildTd(r.overallGrade, ttfBold, align: pw.TextAlign.center, color: passText),
                          ],
                        );
                      }),
                    ],
                  ),
                ],

                pw.Spacer(),

                // ─── Signatures ────────────────────────────────────────
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Column(
                      children: [
                        pw.Container(width: 120, height: 1, color: textDark),
                        pw.SizedBox(height: 3),
                        pw.Text('CLASS INCHARGE / OFFICE', style: pw.TextStyle(font: ttfBold, fontSize: 8, color: textMuted)),
                      ],
                    ),
                    // Director Sign & Official Stamp (Signature layered inside/over stamp)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(
                          width: 120,
                          height: 40,
                          child: pw.Stack(
                            alignment: pw.Alignment.center,
                            children: [
                              if (stampImage != null)
                                pw.Opacity(
                                  opacity: 0.88,
                                  child: pw.Image(stampImage, width: 36, height: 36, fit: pw.BoxFit.contain),
                                ),
                              if (sigImage != null)
                                pw.Image(sigImage, width: 100, height: 26, fit: pw.BoxFit.contain),
                            ],
                          ),
                        ),
                        pw.Container(width: 120, height: 1, color: textDark),
                        pw.SizedBox(height: 3),
                        pw.Text("Director Sign", style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: textMuted)),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 6),
                pw.Center(
                  child: pw.Text(
                    'Statement Generated on: ${DateFormat("dd/MM/yyyy").format(DateTime.now())}  |  Official Student Master Record',
                    style: pw.TextStyle(font: ttf, fontSize: 7, color: textMuted),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return doc;
  }

  // ─── Print / Layout PDF ───────────────────────────────────────────────────
  Future<void> printReport({
    required StudentModel student,
    required List<PaymentModel> payments,
    required Map<String, dynamic> attendance,
    required List<ResultModel> results,
    required SettingsModel settings,
    String monthFilter = 'all',
  }) async {
    final pdf = await generateDocument(
      student: student,
      payments: payments,
      attendance: attendance,
      results: results,
      settings: settings,
      monthFilter: monthFilter,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Statement_${student.name}_${monthFilter == "all" ? "Full" : monthFilter}',
    );
  }

  // ─── Share PDF ────────────────────────────────────────────────────────────
  Future<void> shareReport({
    required StudentModel student,
    required List<PaymentModel> payments,
    required Map<String, dynamic> attendance,
    required List<ResultModel> results,
    required SettingsModel settings,
    String monthFilter = 'all',
  }) async {
    final pdf = await generateDocument(
      student: student,
      payments: payments,
      attendance: attendance,
      results: results,
      settings: settings,
      monthFilter: monthFilter,
    );
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Statement_${student.name}.pdf',
    );
  }

  // ─── Export Excel ─────────────────────────────────────────────────────────
  Future<void> exportExcel(
    BuildContext context, {
    required StudentModel student,
    required List<PaymentModel> payments,
    required Map<String, dynamic> attendance,
    required List<ResultModel> results,
    required SettingsModel settings,
    String monthFilter = 'all',
  }) async {
    final filtered = filterData(
      allPayments: payments,
      allAttendance: attendance,
      allResults: results,
      monthFilter: monthFilter,
    );

    final totalFee = student.totalFees > 0 ? student.totalFees : 0.0;
    final paidFee = filtered.payments.fold<double>(0.0, (sum, p) => sum + p.amount);
    final remainingDue = (totalFee - paidFee).clamp(0.0, double.infinity);

    final excel = Excel.createExcel();

    // Sheet 1: Profile & Summary
    final sheet1 = excel['Profile & Summary'];
    sheet1.appendRow([TextCellValue('INSTITUTION'), TextCellValue(settings.instituteName)]);
    sheet1.appendRow([TextCellValue('REPORT TYPE'), TextCellValue('Student Comprehensive Full Statement')]);
    sheet1.appendRow([TextCellValue('PERIOD / FILTER'), TextCellValue(filtered.filterLabel)]);
    sheet1.appendRow([TextCellValue('DATE OF EXPORT'), TextCellValue(DateFormat('dd/MM/yyyy').format(DateTime.now()))]);
    sheet1.appendRow([]);
    sheet1.appendRow([TextCellValue('--- STUDENT MASTER PARTICULARS ---')]);
    sheet1.appendRow([TextCellValue('Student Name'), TextCellValue(student.name)]);
    sheet1.appendRow([TextCellValue('Student ID'), TextCellValue(student.studentId)]);
    sheet1.appendRow([TextCellValue('Admission Number'), TextCellValue(student.admissionNumber)]);
    sheet1.appendRow([TextCellValue('Class / Course'), TextCellValue(student.displayClass)]);
    sheet1.appendRow([TextCellValue('Roll Number'), TextCellValue(student.rollNumber ?? '')]);
    sheet1.appendRow([TextCellValue("Father's Name"), TextCellValue(student.fatherName)]);
    sheet1.appendRow([TextCellValue("Mother's Name"), TextCellValue(student.motherName ?? '—')]);
    sheet1.appendRow([TextCellValue('Mobile'), TextCellValue(student.mobile)]);
    sheet1.appendRow([TextCellValue('Date of Birth'), TextCellValue(DateFormat('dd/MM/yyyy').format(student.dob))]);
    sheet1.appendRow([TextCellValue('Address'), TextCellValue(student.address)]);
    sheet1.appendRow([]);
    sheet1.appendRow([TextCellValue('--- FINANCIAL ACCOUNT STANDING ---')]);
    sheet1.appendRow([TextCellValue('Total Course Fee (INR)'), TextCellValue(totalFee.toStringAsFixed(0))]);
    sheet1.appendRow([TextCellValue('Total Fee Paid (INR)'), TextCellValue(paidFee.toStringAsFixed(0))]);
    sheet1.appendRow([TextCellValue('Remaining Balance Due (INR)'), TextCellValue(remainingDue.toStringAsFixed(0))]);

    // Sheet 2: Fee Transactions
    final sheet2 = excel['Fee Transactions'];
    sheet2.appendRow([
      TextCellValue('S.No'),
      TextCellValue('Receipt No'),
      TextCellValue('Date'),
      TextCellValue('Amount (INR)'),
      TextCellValue('Mode'),
      TextCellValue('Remarks'),
    ]);
    for (int i = 0; i < filtered.payments.length; i++) {
      final p = filtered.payments[i];
      sheet2.appendRow([
        TextCellValue('${i + 1}'),
        TextCellValue(p.receiptNumber.isNotEmpty ? p.receiptNumber : p.id.take(8)),
        TextCellValue(DateFormat('dd/MM/yyyy').format(p.paymentDate)),
        TextCellValue(p.amount.toStringAsFixed(0)),
        TextCellValue(p.paymentMode),
        TextCellValue(p.remarks ?? 'Fee Payment'),
      ]);
    }

    // Sheet 3: Attendance Log
    final sheet3 = excel['Attendance Log'];
    sheet3.appendRow([TextCellValue('Date'), TextCellValue('Status')]);
    filtered.attendance.forEach((k, v) {
      String status = '';
      if (v is Map) {
        status = (v[student.id] ?? v[student.studentId] ?? '').toString().toUpperCase();
      } else {
        status = v.toString().toUpperCase();
      }
      sheet3.appendRow([TextCellValue(k), TextCellValue(status)]);
    });

    // Sheet 4: Exam Results
    final sheet4 = excel['Exam Results'];
    sheet4.appendRow([
      TextCellValue('Exam Name'),
      TextCellValue('Total Max'),
      TextCellValue('Total Obtained'),
      TextCellValue('Percentage'),
      TextCellValue('Grade'),
    ]);
    for (final r in filtered.results) {
      final tMax = r.subjects.isNotEmpty ? r.subjects.fold<double>(0, (s, e) => s + e.totalMarks) : r.totalMarks;
      final tObt = r.subjects.isNotEmpty ? r.subjects.fold<double>(0, (s, e) => s + e.marks) : r.obtainedMarks;
      final p = tMax > 0 ? ((tObt / tMax) * 100).toStringAsFixed(1) : '0';
      sheet4.appendRow([
        TextCellValue(r.examName),
        TextCellValue(tMax.toStringAsFixed(0)),
        TextCellValue(tObt.toStringAsFixed(0)),
        TextCellValue('$p%'),
        TextCellValue(r.overallGrade),
      ]);
    }

    final bytes = excel.encode();
    if (bytes != null) {
      final cleanFilter = monthFilter == 'all' ? 'AllTime' : monthFilter;
      await FileSaver.showSaveShareSheet(
        context,
        bytes: Uint8List.fromList(bytes),
        filename: 'Student_Report_${student.name.replaceAll(' ', '_')}_$cleanFilter.xlsx',
        subject: 'Student Full Statement - ${student.name}',
        icon: Icons.table_chart_rounded,
        color: Colors.teal,
      );
    }
  }

  // ─── Share WhatsApp ───────────────────────────────────────────────────────
  Future<void> shareWhatsApp(
    BuildContext context, {
    required StudentModel student,
    required List<PaymentModel> payments,
    required Map<String, dynamic> attendance,
    required List<ResultModel> results,
    required SettingsModel settings,
    String monthFilter = 'all',
  }) async {
    final filtered = filterData(
      allPayments: payments,
      allAttendance: attendance,
      allResults: results,
      monthFilter: monthFilter,
    );

    final totalFee = student.totalFees > 0 ? student.totalFees : 0.0;
    final paidFee = filtered.payments.fold<double>(0.0, (sum, p) => sum + p.amount);
    final remainingDue = (totalFee - paidFee).clamp(0.0, double.infinity);

    int totalMarked = 0, present = 0;
    filtered.attendance.forEach((_, val) {
      String status = '';
      if (val is Map) {
        status = (val[student.id] ?? val[student.studentId] ?? '').toString().toLowerCase();
      } else if (val is String) {
        status = val.toLowerCase();
      }
      if (status.isNotEmpty) {
        totalMarked++;
        if (status == 'present') present++;
      }
    });
    final attPct = totalMarked > 0 ? ((present / totalMarked) * 100).toStringAsFixed(1) : 'N/A';

    final latestResult = filtered.results.isNotEmpty ? filtered.results.last : null;
    final resText = latestResult != null
        ? '${latestResult.examName} (${latestResult.overallGrade})'
        : 'N/A';

    final msg = '''
🎓 *${settings.instituteName.toUpperCase()}*
📋 *STUDENT COMPREHENSIVE PERFORMANCE & ACCOUNT STATEMENT*
📅 *Period:* ${filtered.filterLabel}

👤 *STUDENT DETAILS:*
• Name: *${student.name}*
• Student ID: ${student.studentId}
• Class/Course: ${student.displayClass}
• Roll No: ${student.rollNumber ?? 'N/A'}

💰 *FEE ACCOUNT STANDING:*
• Total Fees: ₹${totalFee.toStringAsFixed(0)}
• Total Paid: ₹${paidFee.toStringAsFixed(0)}
• Balance Due: *₹${remainingDue.toStringAsFixed(0)}*
• Status: *${remainingDue <= 0 ? 'FULLY PAID ✅' : 'DUES PENDING ⚠️'}*
• Total Receipts: ${filtered.payments.length}

📊 *ATTENDANCE RECORD:*
• Working Days Marked: $totalMarked
• Present Days: $present
• Attendance Rate: $attPct${attPct != 'N/A' ? '%' : ''}

🏆 *LATEST EXAM RESULT:*
• $resText

_For any queries or official paper receipt, kindly contact the institute office._
${settings.mobile.isNotEmpty ? "📞 Helpline: ${settings.mobile}" : ""}''';

    await WhatsAppService.sendMessage(
      context: context,
      phone: student.mobile,
      message: msg,
    );
  }

  // ─── Table Helpers ────────────────────────────────────────────────────────
  pw.Widget _buildTh(String title, pw.Font bold, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(title, style: pw.TextStyle(font: bold, fontSize: 7, color: PdfColors.white), textAlign: align),
    );
  }

  pw.Widget _buildTd(String val, pw.Font font, {pw.TextAlign align = pw.TextAlign.left, PdfColor color = textDark}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(val, style: pw.TextStyle(font: font, fontSize: 7, color: color), textAlign: align),
    );
  }

  pw.Widget _buildInfoRow(String label, String value, pw.Font normal, pw.Font bold, {bool isHighlight = false}) {
    return pw.Row(
      children: [
        pw.SizedBox(width: 75, child: pw.Text(label, style: pw.TextStyle(font: normal, fontSize: 8, color: textMuted))),
        pw.Expanded(
          child: pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 8.5, color: isHighlight ? primaryNavy : textDark)),
        ),
      ],
    );
  }
}

extension _StringExt on String {
  String take(int n) => length <= n ? this : substring(0, n);
}
