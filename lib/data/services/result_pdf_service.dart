import '../../core/utils/file_saver.dart';
import 'dart:io';
import 'package:flutter/material.dart' show BuildContext, Icons;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/result_model.dart';
import '../models/settings_model.dart';
import '../models/student_model.dart';
import '../../core/utils/app_utils.dart';

/// Centralized service to generate official Statement of Marks / Exam Result PDFs matching the Website 1:1.
class ResultPdfService {
  ResultPdfService._();
  static final ResultPdfService instance = ResultPdfService._();

  // Custom Colors matching website exactly
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

  static const PdfColor promotedBg = PdfColor.fromInt(0xFFFEF3C7);
  static const PdfColor promotedText = PdfColor.fromInt(0xFFB45309);
  static const PdfColor promotedBorder = PdfColor.fromInt(0xFFF59E0B);

  // ─── Single Marksheet Page Builder ──────────────────────────────────────────
  pw.Page buildMarksheetPage({
    required ResultModel result,
    required StudentModel student,
    required SettingsModel settings,
    required pw.Font ttf,
    required pw.Font ttfBold,
    pw.MemoryImage? logoImage,
    pw.MemoryImage? sigImage,
    pw.MemoryImage? stampImage,
  }) {
    final rawSubjects = result.subjects.isNotEmpty
        ? result.subjects
        : [
            SubjectResult(
              subjectName: 'General',
              marks: result.obtainedMarks,
              totalMarks: result.totalMarks > 0 ? result.totalMarks : 100,
            )
          ];

    final hasDetailedBreakdown = result.isDetailedMode ||
        rawSubjects.any((s) =>
            s.theoryMarks > 0 ||
            s.practicalMarks > 0 ||
            s.internalMarks > 0);

    final totalTheory = rawSubjects.fold<double>(0, (sum, s) => sum + s.theoryMarks);
    final totalPractical = rawSubjects.fold<double>(0, (sum, s) => sum + s.practicalMarks);
    final totalInternal = rawSubjects.fold<double>(0, (sum, s) => sum + s.internalMarks);

    final totalMax = rawSubjects.fold<double>(0, (sum, s) => sum + s.totalMarks);
    final totalObt = rawSubjects.fold<double>(0, (sum, s) {
      final obt = s.marks > 0 ? s.marks : (s.theoryMarks + s.practicalMarks + s.internalMarks);
      return sum + obt;
    });
    final pct = totalMax > 0 ? ((totalObt / totalMax) * 100) : 0.0;
    final pctStr = pct.toStringAsFixed(1);

    String calcGrade(double p) {
      if (p >= 90) return 'A+';
      if (p >= 80) return 'A';
      if (p >= 70) return 'B+';
      if (p >= 60) return 'B';
      if (p >= 50) return 'C';
      if (p >= 40) return 'D';
      return 'F';
    }

    final overallGrade = result.overallGrade.isNotEmpty ? result.overallGrade : calcGrade(pct);
    final finalStatus = result.finalResultStatus;
    final isPromoted = finalStatus == 'PROMOTED';
    final isPass = finalStatus == 'PASS' || (!isPromoted && result.isPass);

    final studentName = (student.name).isNotEmpty ? student.name : 'Student';
    final fatherName = (student.fatherName).isNotEmpty ? student.fatherName : '—';
    final classStr = student.studentType == 'school'
        ? 'Class ${student.className ?? ""}${(student.section != null && student.section!.isNotEmpty) ? " - ${student.section}" : ""}'
        : ((student.course != null && student.course!.isNotEmpty) ? student.course! : '—');
    final stuId = student.studentId.isNotEmpty ? student.studentId : '—';
    final rollNo = (student.rollNumber != null && student.rollNumber!.isNotEmpty) ? student.rollNumber! : 'N/A';
    final sessionStr = (student.session != null && student.session!.isNotEmpty)
        ? student.session!
        : (settings.currentSession.isNotEmpty ? settings.currentSession : '2026-27');

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 20),
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
                      pw.Image(logoImage, width: 48, height: 48, fit: pw.BoxFit.contain),
                      pw.SizedBox(height: 4),
                    ],
                    pw.Text(
                      (settings.instituteName.isNotEmpty
                              ? settings.instituteName
                              : 'MISSION NAVODAYA PUBLIC SCHOOL')
                          .toUpperCase(),
                      style: pw.TextStyle(
                        font: ttfBold,
                        fontSize: 20,
                        color: primaryNavy,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 3),
                    if (settings.address.isNotEmpty)
                      pw.Text(
                        settings.address,
                        style: pw.TextStyle(font: ttf, fontSize: 9.5, color: textMuted),
                        textAlign: pw.TextAlign.center,
                      ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Affiliation: ${(settings.affiliationNumber != null && settings.affiliationNumber!.isNotEmpty) ? settings.affiliationNumber! : "Recognized"}'
                      '${settings.mobile.isNotEmpty ? " • Helpline: ${settings.mobile}" : ""}',
                      style: pw.TextStyle(font: ttf, fontSize: 9, color: textMuted),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 8),

                    // Title Pill Banner
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                      decoration: const pw.BoxDecoration(
                        color: primaryNavy,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
                      ),
                      child: pw.Text(
                        'OFFICIAL REPORT CARD & STATEMENT OF MARKS',
                        style: pw.TextStyle(
                          font: ttfBold,
                          fontSize: 10.5,
                          color: goldText,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      (result.examName.isNotEmpty ? result.examName : 'Examination').toUpperCase(),
                      style: pw.TextStyle(font: ttfBold, fontSize: 13, color: textDark),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),
              pw.Divider(color: primaryNavy, thickness: 1),
              pw.SizedBox(height: 8),

              // ─── Student Particulars Card ──────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: pw.BoxDecoration(
                  color: cardBg,
                  border: pw.Border.all(color: borderLight, width: 1),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Left Column
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Student Name:', studentName.toUpperCase(), ttf, ttfBold, isHighlight: true),
                          pw.SizedBox(height: 5),
                          _buildInfoRow("Father's Name:", fatherName, ttf, ttfBold),
                          pw.SizedBox(height: 5),
                          _buildInfoRow('Class / Course:', classStr, ttf, ttfBold),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 16),
                    // Right Column
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Student ID:', stuId, ttf, ttfBold),
                          pw.SizedBox(height: 5),
                          _buildInfoRow('Roll Number:', rollNo, ttf, ttfBold),
                          pw.SizedBox(height: 5),
                          _buildInfoRow('Academic Session:', sessionStr, ttf, ttfBold),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // ─── Marks Table ───────────────────────────────────────
              if (!hasDetailedBreakdown)
                pw.Table(
                  border: pw.TableBorder.all(color: borderLight, width: 0.8),
                  columnWidths: const {
                    0: pw.FixedColumnWidth(28),
                    1: pw.FlexColumnWidth(3.8),
                    2: pw.FlexColumnWidth(1.6),
                    3: pw.FlexColumnWidth(1.8),
                    4: pw.FlexColumnWidth(1.2),
                  },
                  children: [
                    // Table Header
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: primaryNavy),
                      children: [
                        _buildTableHeaderCell('S.No', ttfBold, align: pw.TextAlign.center, fontSize: 9, hPadding: 2),
                        _buildTableHeaderCell('Subject Name', ttfBold, align: pw.TextAlign.left, fontSize: 9, hPadding: 6),
                        _buildTableHeaderCell('Max Marks', ttfBold, align: pw.TextAlign.center, fontSize: 9, hPadding: 2),
                        _buildTableHeaderCell('Marks Obtained', ttfBold, align: pw.TextAlign.center, fontSize: 9, hPadding: 2),
                        _buildTableHeaderCell('Grade', ttfBold, align: pw.TextAlign.center, fontSize: 9, hPadding: 2),
                      ],
                    ),
                    // Table Rows
                    ...rawSubjects.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final sub = entry.value;
                      final sMax = sub.totalMarks;
                      final sObt = sub.marks > 0 ? sub.marks : (sub.theoryMarks + sub.practicalMarks + sub.internalMarks);
                      final sPct = sMax > 0 ? (sObt / sMax) * 100 : 0.0;
                      final sGrade = calcGrade(sPct);
                      final isEven = idx % 2 == 1;

                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: isEven ? cardBg : PdfColors.white,
                        ),
                        children: [
                          _buildTableCell('${idx + 1}', ttf, align: pw.TextAlign.center, fontSize: 9.5, hPadding: 2),
                          _buildTableCell(sub.subjectName, ttfBold, align: pw.TextAlign.left, fontSize: 9.5, hPadding: 6),
                          _buildTableCell('${sMax.toInt()}', ttf, align: pw.TextAlign.center, fontSize: 9.5, hPadding: 2),
                          _buildTableCell('${sObt.toInt()}', ttfBold, align: pw.TextAlign.center, color: primaryNavy, fontSize: 9.5, hPadding: 2),
                          _buildTableCell(sGrade, ttfBold, align: pw.TextAlign.center, fontSize: 9.5, hPadding: 2),
                        ],
                      );
                    }),
                    // Grand Total Row
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: totalBg),
                      children: [
                        _buildTotalCell('', ttfBold, fontSize: 10, hPadding: 2),
                        _buildTotalCell('GRAND TOTAL', ttfBold, align: pw.TextAlign.left, fontSize: 10, hPadding: 6),
                        _buildTotalCell('${totalMax.toInt()}', ttfBold, align: pw.TextAlign.center, fontSize: 10, hPadding: 2),
                        _buildTotalCell('${totalObt.toInt()}', ttfBold, align: pw.TextAlign.center, color: primaryNavy, fontSize: 10, hPadding: 2),
                        _buildTotalCell(overallGrade, ttfBold, align: pw.TextAlign.center, fontSize: 10, hPadding: 2),
                      ],
                    ),
                  ],
                )
              else
                pw.Table(
                  border: pw.TableBorder.all(color: borderLight, width: 0.8),
                  columnWidths: const {
                    0: pw.FixedColumnWidth(24),
                    1: pw.FlexColumnWidth(3.0),
                    2: pw.FlexColumnWidth(1.2),
                    3: pw.FlexColumnWidth(1.2),
                    4: pw.FlexColumnWidth(1.2),
                    5: pw.FlexColumnWidth(1.2),
                    6: pw.FlexColumnWidth(1.4),
                    7: pw.FlexColumnWidth(1.1),
                  },
                  children: [
                    // Table Header
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: primaryNavy),
                      children: [
                        _buildTableHeaderCell('S.No', ttfBold, align: pw.TextAlign.center, fontSize: 8.5, hPadding: 2),
                        _buildTableHeaderCell('Subject Name', ttfBold, align: pw.TextAlign.left, fontSize: 8.5, hPadding: 4),
                        _buildTableHeaderCell('Theory', ttfBold, align: pw.TextAlign.center, fontSize: 8.5, hPadding: 2),
                        _buildTableHeaderCell('Practical', ttfBold, align: pw.TextAlign.center, fontSize: 8.5, hPadding: 2),
                        _buildTableHeaderCell('Internal', ttfBold, align: pw.TextAlign.center, fontSize: 8.5, hPadding: 2),
                        _buildTableHeaderCell('Max', ttfBold, align: pw.TextAlign.center, fontSize: 8.5, hPadding: 2),
                        _buildTableHeaderCell('Total Obt', ttfBold, align: pw.TextAlign.center, fontSize: 8.5, hPadding: 2),
                        _buildTableHeaderCell('Grade', ttfBold, align: pw.TextAlign.center, fontSize: 8.5, hPadding: 2),
                      ],
                    ),
                    // Table Rows
                    ...rawSubjects.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final sub = entry.value;
                      final sMax = sub.totalMarks;
                      final sObt = sub.marks > 0 ? sub.marks : (sub.theoryMarks + sub.practicalMarks + sub.internalMarks);
                      final sPct = sMax > 0 ? (sObt / sMax) * 100 : 0.0;
                      final sGrade = calcGrade(sPct);
                      final isEven = idx % 2 == 1;

                      final theoryVal = sub.theoryMarks > 0
                          ? '${sub.theoryMarks.toInt()}'
                          : (sub.marks > 0 ? '${sub.marks.toInt()}' : '—');
                      final practicalVal = sub.practicalMarks > 0 ? '${sub.practicalMarks.toInt()}' : '—';
                      final internalVal = sub.internalMarks > 0 ? '${sub.internalMarks.toInt()}' : '—';

                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: isEven ? cardBg : PdfColors.white,
                        ),
                        children: [
                          _buildTableCell('${idx + 1}', ttf, align: pw.TextAlign.center, fontSize: 9, hPadding: 2),
                          _buildTableCell(sub.subjectName, ttfBold, align: pw.TextAlign.left, fontSize: 9, hPadding: 4),
                          _buildTableCell(theoryVal, ttf, align: pw.TextAlign.center, fontSize: 9, hPadding: 2),
                          _buildTableCell(practicalVal, ttf, align: pw.TextAlign.center, fontSize: 9, hPadding: 2),
                          _buildTableCell(internalVal, ttf, align: pw.TextAlign.center, fontSize: 9, hPadding: 2),
                          _buildTableCell('${sMax.toInt()}', ttf, align: pw.TextAlign.center, fontSize: 9, hPadding: 2),
                          _buildTableCell('${sObt.toInt()}', ttfBold, align: pw.TextAlign.center, color: primaryNavy, fontSize: 9, hPadding: 2),
                          _buildTableCell(sGrade, ttfBold, align: pw.TextAlign.center, fontSize: 9, hPadding: 2),
                        ],
                      );
                    }),
                    // Grand Total Row
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: totalBg),
                      children: [
                        _buildTotalCell('', ttfBold, fontSize: 9.5, hPadding: 2),
                        _buildTotalCell('GRAND TOTAL', ttfBold, align: pw.TextAlign.left, fontSize: 9.5, hPadding: 4),
                        _buildTotalCell(totalTheory > 0 ? '${totalTheory.toInt()}' : (totalObt > 0 ? '${totalObt.toInt()}' : '—'), ttfBold, align: pw.TextAlign.center, fontSize: 9.5, hPadding: 2),
                        _buildTotalCell(totalPractical > 0 ? '${totalPractical.toInt()}' : '—', ttfBold, align: pw.TextAlign.center, fontSize: 9.5, hPadding: 2),
                        _buildTotalCell(totalInternal > 0 ? '${totalInternal.toInt()}' : '—', ttfBold, align: pw.TextAlign.center, fontSize: 9.5, hPadding: 2),
                        _buildTotalCell('${totalMax.toInt()}', ttfBold, align: pw.TextAlign.center, fontSize: 9.5, hPadding: 2),
                        _buildTotalCell('${totalObt.toInt()}', ttfBold, align: pw.TextAlign.center, color: primaryNavy, fontSize: 9.5, hPadding: 2),
                        _buildTotalCell(overallGrade, ttfBold, align: pw.TextAlign.center, fontSize: 9.5, hPadding: 2),
                      ],
                    ),
                  ],
                ),

              pw.SizedBox(height: 14),

              // ─── Performance Summary Banner ────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: pw.BoxDecoration(
                  color: cardBg,
                  border: pw.Border.all(color: primaryNavy, width: 1),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text('Percentage: ', style: pw.TextStyle(font: ttf, fontSize: 11, color: textDark)),
                        pw.Text('$pctStr%', style: pw.TextStyle(font: ttfBold, fontSize: 13, color: primaryNavy)),
                        pw.SizedBox(width: 16),
                        pw.Text('•  Overall Grade: ', style: pw.TextStyle(font: ttf, fontSize: 11, color: textDark)),
                        pw.Text(overallGrade, style: pw.TextStyle(font: ttfBold, fontSize: 13, color: primaryNavy)),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: pw.BoxDecoration(
                        color: isPromoted
                            ? promotedBg
                            : (isPass ? passBg : failBg),
                        border: pw.Border.all(
                          color: isPromoted
                              ? promotedBorder
                              : (isPass ? passText : failText),
                          width: 1,
                        ),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                      ),
                      child: pw.Text(
                        isPromoted
                            ? 'STATUS: PROMOTED TO NEXT CLASS'
                            : (isPass ? 'STATUS: PASSED' : 'STATUS: NEEDS IMPROVEMENT'),
                        style: pw.TextStyle(
                          font: ttfBold,
                          fontSize: 10,
                          color: isPromoted
                              ? promotedText
                              : (isPass ? passText : failText),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // ─── Signatures & QR Code ──────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  // Class Teacher Sign
                  pw.Column(
                    children: [
                      pw.Container(width: 130, height: 1.2, color: textDark),
                      pw.SizedBox(height: 4),
                      pw.Text('CLASS TEACHER SIGN', style: pw.TextStyle(font: ttfBold, fontSize: 9.5, color: textMuted)),
                    ],
                  ),

                  // QR Code
                  pw.Container(
                    padding: const pw.EdgeInsets.all(3),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: borderLight, width: 1),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: 'RESULT:${result.examName}|STUDENT:${student.studentId}|PCT:$pctStr%|GRADE:$overallGrade|STATUS:$finalStatus',
                      width: 50,
                      height: 50,
                    ),
                  ),

                  // Director Sign & Official Stamp (Signature layered inside/over stamp)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 140,
                        height: 46,
                        child: pw.Stack(
                          alignment: pw.Alignment.center,
                          children: [
                            if (stampImage != null)
                              pw.Opacity(
                                opacity: 0.88,
                                child: pw.Image(stampImage, width: 44, height: 44, fit: pw.BoxFit.contain),
                              ),
                            if (sigImage != null)
                              pw.Image(sigImage, width: 120, height: 40, fit: pw.BoxFit.contain),
                          ],
                        ),
                      ),
                      pw.Container(width: 140, height: 1.2, color: textDark),
                      pw.SizedBox(height: 3),
                      pw.Text('Director Sign', style: pw.TextStyle(font: ttfBold, fontSize: 9, color: textMuted)),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Date of Issue: ${_formatDate(DateTime.now())}  |  Computer Generated Academic Marksheet',
                  style: pw.TextStyle(font: ttf, fontSize: 8.5, color: textMuted),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Generate Single Document ───────────────────────────────────────────────
  Future<pw.Document> generateDocument({
    required ResultModel result,
    required StudentModel student,
    required SettingsModel settings,
  }) async {
    final ttf = await PdfGoogleFonts.notoSansRegular();
    final ttfBold = await PdfGoogleFonts.notoSansBold();

    final logoBytes = await AppUtils.loadAppImageBytes(settings.logoPath);
    final logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    final sigBytes = await AppUtils.loadAppImageBytes(settings.principalSignature);
    final sigImage = sigBytes != null ? pw.MemoryImage(sigBytes) : null;

    final stampBytes = await AppUtils.loadAppImageBytes(settings.schoolStamp);
    final stampImage = stampBytes != null ? pw.MemoryImage(stampBytes) : null;

    final doc = pw.Document();
    doc.addPage(
      buildMarksheetPage(
        result: result,
        student: student,
        settings: settings,
        ttf: ttf,
        ttfBold: ttfBold,
        logoImage: logoImage,
        sigImage: sigImage,
        stampImage: stampImage,
      ),
    );
    return doc;
  }

  // ─── Generate Batch Document (Multiple Students in One PDF) ─────────────────
  Future<pw.Document> generateBatchDocument({
    required List<MapEntry<StudentModel, ResultModel>> items,
    required SettingsModel settings,
  }) async {
    final ttf = await PdfGoogleFonts.notoSansRegular();
    final ttfBold = await PdfGoogleFonts.notoSansBold();

    final logoBytes = await AppUtils.loadAppImageBytes(settings.logoPath);
    final logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    final sigBytes = await AppUtils.loadAppImageBytes(settings.principalSignature);
    final sigImage = sigBytes != null ? pw.MemoryImage(sigBytes) : null;

    final stampBytes = await AppUtils.loadAppImageBytes(settings.schoolStamp);
    final stampImage = stampBytes != null ? pw.MemoryImage(stampBytes) : null;

    final doc = pw.Document();

    for (final item in items) {
      doc.addPage(
        buildMarksheetPage(
          result: item.value,
          student: item.key,
          settings: settings,
          ttf: ttf,
          ttfBold: ttfBold,
          logoImage: logoImage,
          sigImage: sigImage,
          stampImage: stampImage,
        ),
      );
    }

    return doc;
  }

  // ─── Direct Print / Print Preview ──────────────────────────────────────────
  Future<void> printResult({
    required ResultModel result,
    required StudentModel student,
    required SettingsModel settings,
  }) async {
    final pdf = await generateDocument(
      result: result,
      student: student,
      settings: settings,
    );
    final pdfBytes = await pdf.save();
    final fileName = 'Marksheet_${student.name.replaceAll(' ', '_')}_${result.examName.replaceAll(' ', '_')}.pdf';
    try {
      await FileSaver.saveCategorizedFile(
        bytes: pdfBytes,
        filename: fileName,
        category: FileCategory.results,
        schoolName: settings.instituteName,
      );
    } catch (_) {}

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: fileName,
    );
  }

  // ─── Share PDF File ────────────────────────────────────────────────────────
  Future<void> shareResult({
    required ResultModel result,
    required StudentModel student,
    required SettingsModel settings,
  }) async {
    final pdf = await generateDocument(
      result: result,
      student: student,
      settings: settings,
    );
    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Marksheet_${student.name.replaceAll(' ', '_')}_${result.examName.replaceAll(' ', '_')}.pdf',
    );
  }

  // ─── Create Temp PDF File ──────────────────────────────────────────────────
  Future<File> createPdfFile({
    required ResultModel result,
    required StudentModel student,
    required SettingsModel settings,
  }) async {
    final pdf = await generateDocument(
      result: result,
      student: student,
      settings: settings,
    );
    final bytes = await pdf.save();
    final tempDir = await getTemporaryDirectory();
    final cleanStu = student.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final cleanExam = result.examName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final file = File('${tempDir.path}/Marksheet_${cleanStu}_$cleanExam.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  // ─── Save PDF directly to Device Storage (Downloads) ──────────────────────
  Future<String> saveResultPdfToDevice({
    required ResultModel result,
    required StudentModel student,
    required SettingsModel settings,
  }) async {
    final doc = await generateDocument(result: result, student: student, settings: settings);
    final bytes = await doc.save();
    final safeStu = student.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final safeExam = result.examName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final fileName = 'Marksheet_${safeStu}_${safeExam}.pdf';

    return await FileSaver.saveCategorizedFile(
      bytes: bytes,
      filename: fileName,
      category: FileCategory.results,
      schoolName: settings.schoolName,
    );
  }

  // ─── Print or Share Single PDF via FileSaver Sheet ─────────────────────────
  Future<void> printOrShareResultPdf({
    required ResultModel result,
    required StudentModel student,
    required SettingsModel settings,
    BuildContext? context,
  }) async {
    final doc = await generateDocument(result: result, student: student, settings: settings);
    final bytes = await doc.save();
    final safeStu = student.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final safeExam = result.examName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final fileName = 'Marksheet_${safeStu}_${safeExam}.pdf';

    if (context != null) {
      await FileSaver.showSaveShareSheet(
        context,
        bytes: bytes,
        filename: fileName,
        subject: '${settings.schoolName} - Marksheet ${student.name}',
        category: FileCategory.results,
        schoolName: settings.schoolName,
        icon: Icons.grade_outlined,
      );
    } else {
      await Printing.layoutPdf(onLayout: (_) => bytes, name: fileName);
    }
  }

  // ─── Print or Share Batch Class Marksheets ─────────────────────────────────
  Future<void> printOrShareBatchResultPdf({
    required List<MapEntry<StudentModel, ResultModel>> items,
    required SettingsModel settings,
    required BuildContext context,
    required String className,
    required String examName,
  }) async {
    final doc = await generateBatchDocument(items: items, settings: settings);
    final bytes = await doc.save();
    final safeClass = className.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final safeExam = examName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final fileName = 'Class_${safeClass}_${safeExam}_All_Marksheets.pdf';

    await FileSaver.showSaveShareSheet(
      context,
      bytes: bytes,
      filename: fileName,
      subject: '${settings.schoolName} - Class $className Marksheets ($examName)',
      category: FileCategory.results,
      schoolName: settings.schoolName,
      icon: Icons.description_outlined,
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  static pw.Widget _buildInfoRow(
    String label,
    String value,
    pw.Font ttf,
    pw.Font ttfBold, {
    bool isHighlight = false,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 100,
          child: pw.Text(
            label,
            style: pw.TextStyle(font: ttf, fontSize: 9.5, color: textMuted),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              font: ttfBold,
              fontSize: 10,
              color: isHighlight ? primaryNavy : textDark,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTableHeaderCell(
    String text,
    pw.Font ttfBold, {
    pw.TextAlign align = pw.TextAlign.left,
    double fontSize = 10,
    double hPadding = 6,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: hPadding, vertical: 6.5),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: ttfBold, fontSize: fontSize, color: PdfColors.white),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor color = textDark,
    double fontSize = 10,
    double hPadding = 6,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: hPadding, vertical: 5.5),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: fontSize, color: color),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _buildTotalCell(
    String text,
    pw.Font ttfBold, {
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor color = textDark,
    double fontSize = 11,
    double hPadding = 6,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: hPadding, vertical: 6.5),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: ttfBold, fontSize: fontSize, color: color),
        textAlign: align,
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
