import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import '../../data/services/database_service.dart';
import '../../core/utils/app_utils.dart';

/// Handles the heavy export logic for Complete Student Data export.
/// Separated from UI for clarity and testability.
class CompleteExportService {
  static final CompleteExportService instance = CompleteExportService._();
  CompleteExportService._();

  String _rs(double v) => '\u20B9${v.toInt()}';

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  }

  String _fmtTime(DateTime? d) {
    if (d == null) return '';
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ─── Complete Excel Export ─────────────────────────────────────────────────

  Future<(List<int>, String)> exportCompleteExcel({
    void Function(int, int)? onProgress,
  }) async {
    final students = await DatabaseService.instance.getAllStudents();
    final settings = await DatabaseService.instance.getSettings();
    // Batch-load ONCE instead of one query per student — getFeeByStudentId()
    // and getAttendanceSummary() each internally reload their entire table on
    // every call, so calling them per-student in a loop was effectively
    // O(N²) and is exactly why export hung for larger student counts.
    final feesMap = await DatabaseService.instance.getAllFeesMap();
    final attendanceMap = await DatabaseService.instance.getAllAttendanceSummaries();

    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Complete Student Data');
    final sheet = excel['Complete Student Data'];

    // ── Header row styles
    CellStyle hdrStyle() => CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#1A237E'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );

    CellStyle secStyle(String hex) => CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString(hex),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );

    // ── Row 0: Section labels
    final sectionRow = [
      // Basic (10 cols)
      'BASIC INFORMATION', '', '', '', '', '', '', '', '', '',
      // Academic (7 cols)
      'ACADEMIC INFORMATION', '', '', '', '', '', '',
      // Fee (7 cols)
      'FEE INFORMATION', '', '', '', '', '', '',
      // Attendance (5 cols)
      'ATTENDANCE SUMMARY', '', '', '', '',
      // Institute (2 cols)
      'INSTITUTE', '',
    ];
    for (int i = 0; i < sectionRow.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      if (sectionRow[i].isNotEmpty) cell.value = TextCellValue(sectionRow[i]);
      // Color by section
      if (i < 10) cell.cellStyle = secStyle('#1565C0');
      else if (i < 17) cell.cellStyle = secStyle('#2E7D32');
      else if (i < 24) cell.cellStyle = secStyle('#E65100');
      else if (i < 29) cell.cellStyle = secStyle('#6A1B9A');
      else cell.cellStyle = secStyle('#00695C');
    }

    // ── Row 1: Column headers
    final headers = [
      // Basic
      'Admission No', 'Student ID', 'Student Name', "Father's Name", "Mother's Name",
      'Mobile', 'Alt Mobile', 'Gender', 'Date of Birth', 'Address',
      // Academic
      'Student Type', 'Class/Course', 'Section', 'Roll No', 'Admission Date',
      'Session', 'Status',
      // Fee
      'Total Fees', 'Paid Fees', 'Remaining Fees', 'Fee Status',
      'Last Payment Date', 'Last Payment Time', 'Payment Mode',
      // Attendance
      'Total Days', 'Present', 'Absent', 'Leave', 'Attendance %',
      // Institute
      'Institute Name', 'Academic Session',
    ];
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = hdrStyle();
    }

    // ── Column widths
    final widths = [
      14, 12, 22, 20, 20, 14, 14, 10, 14, 30,
      13, 18, 10, 10, 16, 12, 12,
      14, 12, 16, 12, 18, 16, 14,
      12, 10, 10, 10, 14,
      30, 14,
    ];
    for (int i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i].toDouble());
    }

    // ── Data rows
    for (int si = 0; si < students.length; si++) {
      final s = students[si];
      final fee = feesMap[s.id];
      final attendance = attendanceMap[s.id] ?? const {'total': 0, 'present': 0, 'absent': 0, 'leave': 0};

      final total = attendance['total'] ?? 0;
      final present = attendance['present'] ?? 0;
      final absent = attendance['absent'] ?? 0;
      final leave = total - present - absent;
      final pct = total > 0 ? '${(present / total * 100).toStringAsFixed(1)}%' : '0.0%';

      final lastPayment = fee?.payments.isNotEmpty == true ? fee!.payments.first : null;
      final paymentMode = lastPayment?.paymentMode ?? '';
      final lastPaidDate = _fmtDate(fee?.lastPaidDate);
      final lastPaidTime = _fmtTime(lastPayment?.paymentDate);

      final rowIndex = si + 2; // 0=section, 1=header, 2+=data
      final rowData = [
        // Basic
        TextCellValue(s.admissionNumber),
        TextCellValue(s.studentId),
        TextCellValue(s.name),
        TextCellValue(s.fatherName),
        TextCellValue(s.motherName ?? ''),
        TextCellValue(s.mobile),
        TextCellValue(s.alternateMobile ?? ''),
        TextCellValue(s.gender),
        TextCellValue(_fmtDate(s.dob)),
        TextCellValue(s.address),
        // Academic
        TextCellValue(s.studentType == 'school' ? 'School' : 'Computer'),
        TextCellValue(s.studentType == 'school' ? (s.className ?? '') : (s.course ?? '')),
        TextCellValue(s.section ?? s.batch ?? ''),
        TextCellValue(s.rollNumber ?? ''),
        TextCellValue(_fmtDate(s.admissionDate)),
        TextCellValue(s.session ?? ''),
        TextCellValue(s.statusLabel),
        // Fee
        DoubleCellValue(fee?.totalFees ?? 0),
        DoubleCellValue(fee?.paidFees ?? 0),
        DoubleCellValue(fee?.remainingFees ?? 0),
        TextCellValue(fee?.feeStatus ?? 'Not Set'),
        TextCellValue(lastPaidDate),
        TextCellValue(lastPaidTime),
        TextCellValue(paymentMode),
        // Attendance
        IntCellValue(total),
        IntCellValue(present),
        IntCellValue(absent),
        IntCellValue(leave < 0 ? 0 : leave),
        TextCellValue(pct),
        // Institute
        TextCellValue(settings.instituteName),
        TextCellValue(settings.currentSession),
      ];

      for (int ci = 0; ci < rowData.length; ci++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: ci, rowIndex: rowIndex))
            .value = rowData[ci];
      }

      onProgress?.call(si + 1, students.length);
      if (si % 50 == 0) await Future.delayed(const Duration(milliseconds: 5));
    }

    // Return bytes + filename for the caller to handle save/share
    final bytes = excel.encode()!;
    final ts = DateTime.now().toIso8601String().substring(0, 10);
    final filename = 'complete_student_data_$ts.xlsx';
    return (bytes, filename);
  }

  // ─── Complete PDF Export ───────────────────────────────────────────────────

  /// Loads Unicode fonts needed to render ₹ correctly. `PdfGoogleFonts`
  /// downloads from the network on first use — with no/poor connectivity
  /// that download can hang indefinitely, which was a major contributor to
  /// "Export PDF gets stuck". We now time it out and fall back to the
  /// built-in font so export always completes (₹ may show as a box on a
  /// device that has never had internet access, but the export itself will
  /// never hang or crash).
  Future<(pw.Font, pw.Font)> _loadPdfFonts() async {
    try {
      final regular = await PdfGoogleFonts.notoSansRegular()
          .timeout(const Duration(seconds: 8));
      final bold = await PdfGoogleFonts.notoSansBold()
          .timeout(const Duration(seconds: 8));
      return (regular, bold);
    } catch (_) {
      return (pw.Font.helvetica(), pw.Font.helveticaBold());
    }
  }

  /// Builds the Complete PDF report and returns its bytes + a suggested
  /// filename, mirroring [exportCompleteExcel]. The caller (Reports screen)
  /// is responsible for saving/sharing the file and closing its own loading
  /// dialog — this method no longer opens the native print sheet itself,
  /// which used to compete with the app's own non-dismissible loading
  /// dialog and made the export look "stuck".
  Future<(List<int>, String)> exportCompletePdf({
    void Function(int, int)? onProgress,
  }) async {
    final students = await DatabaseService.instance.getAllStudents();
    final settings = await DatabaseService.instance.getSettings();
    // Batch-load ONCE — see exportCompleteExcel() for why this matters.
    final feesMap = await DatabaseService.instance.getAllFeesMap();
    final attendanceMap = await DatabaseService.instance.getAllAttendanceSummaries();
    final (regular, bold) = await _loadPdfFonts();

    final now = DateTime.now();
    final genDate = _fmtDate(now);
    final genTime = _fmtTime(now);

    // Load institute logo if available
    pw.ImageProvider? logoImage;
    final logoBytes = await AppUtils.loadAppImageBytes(settings.logoPath);
    if (logoBytes != null) {
      logoImage = pw.MemoryImage(logoBytes);
    }

    pw.TextStyle style({double size = 9, bool isBold = false, PdfColor? color}) {
      return pw.TextStyle(
        font: isBold ? bold : regular,
        fontSize: size,
        color: color,
      );
    }

    pw.Widget headerWidget() {
      return pw.Container(
        decoration: const pw.BoxDecoration(
          gradient: pw.LinearGradient(
            colors: [PdfColors.indigo900, PdfColors.indigo600],
            begin: pw.Alignment.centerLeft,
            end: pw.Alignment.centerRight,
          ),
        ),
        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: pw.Row(
          children: [
            if (logoImage != null) ...[
              pw.Image(logoImage, width: 40, height: 40),
              pw.SizedBox(width: 10),
            ],
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(settings.instituteName,
                      style: style(size: 16, isBold: true, color: PdfColors.white)),
                  pw.Text('Complete Student Data Report',
                      style: style(size: 11, color: PdfColors.indigo100)),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Generated: $genDate $genTime',
                    style: style(size: 8, color: PdfColors.indigo100)),
                pw.Text('Total Students: ${students.length}',
                    style: style(size: 8, isBold: true, color: PdfColors.amber200)),
              ],
            ),
          ],
        ),
      );
    }

    // Build student card for each student.
    //
    // IMPORTANT — layout is a single vertical column (not side-by-side
    // columns). The PDF importer (_parseAppCompleteStudentPdf in
    // import_service.dart) reads extracted text top-to-bottom expecting one
    // "Label : Value" per line, in STUDENT INFO -> ACADEMIC INFO -> FEE INFO
    // -> ATTENDANCE order. A 3-column side-by-side layout puts several
    // labels/values at the same vertical position, so Syncfusion's text
    // extractor interleaves them onto the same line and the parser can't
    // recognize any fields — that was the exact cause of "Records Detected: 0"
    // on PDF import. Keeping every field on its own full-width line is what
    // makes EXPORT PDF -> IMPORT PDF round-trip correctly.
    Future<pw.Widget> buildStudentCard(int idx) async {
      final s = students[idx];
      final fee = feesMap[s.id];
      final attSummary = attendanceMap[s.id] ?? const {'total': 0, 'present': 0, 'absent': 0, 'leave': 0};

      final total = attSummary['total'] ?? 0;
      final present = attSummary['present'] ?? 0;
      final absent = attSummary['absent'] ?? 0;
      final leave = (total - present - absent).clamp(0, 9999);
      final pct = total > 0 ? '${(present / total * 100).toStringAsFixed(1)}%' : '0.0%';
      final lastPayment = fee?.payments.isNotEmpty == true ? fee!.payments.first : null;

      // Load student photo
      pw.ImageProvider? studentPhoto;
      if (s.photoPath != null) {
        try {
          final photoBytes = await AppUtils.loadAppImageBytes(s.photoPath);
          if (photoBytes != null) {
            studentPhoto = pw.MemoryImage(photoBytes);
          }
        } catch (_) {}
      }

      pw.Widget infoRow(String label, String value, {PdfColor? valueColor}) {
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            children: [
              pw.SizedBox(
                width: 110,
                child: pw.Text(label, style: style(size: 8, color: PdfColors.grey700)),
              ),
              pw.Text(': ', style: style(size: 8, color: PdfColors.grey700)),
              pw.Expanded(
                child: pw.Text(
                  value.isEmpty ? '—' : value,
                  style: style(size: 8, isBold: value.isNotEmpty, color: valueColor),
                ),
              ),
            ],
          ),
        );
      }

      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.indigo200, width: 0.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Card Header
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: const pw.BoxDecoration(
                color: PdfColors.indigo50,
                borderRadius: pw.BorderRadius.only(
                  topLeft: pw.Radius.circular(6),
                  topRight: pw.Radius.circular(6),
                ),
              ),
              child: pw.Row(
                children: [
                  pw.Text('${idx + 1}. ',
                      style: style(size: 10, isBold: true, color: PdfColors.indigo900)),
                  pw.Text(s.name,
                      style: style(size: 11, isBold: true, color: PdfColors.indigo900)),
                  pw.Spacer(),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: pw.BoxDecoration(
                      color: s.status == 'active'
                          ? PdfColors.green100
                          : s.status == 'completed'
                          ? PdfColors.blue100
                          : PdfColors.orange100,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text(s.statusLabel,
                        style: style(
                          size: 8,
                          isBold: true,
                          color: s.status == 'active'
                              ? PdfColors.green800
                              : s.status == 'completed'
                              ? PdfColors.blue800
                              : PdfColors.orange800,
                        )),
                  ),
                ],
              ),
            ),
            // Card Body — single vertical column, one "Label : Value" per
            // line, section by section. This is what makes the exported
            // PDF re-importable (see comment above buildStudentCard).
            pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (studentPhoto != null) ...[
                    pw.Container(
                      width: 55, height: 65,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.indigo200),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.ClipRRect(
                        horizontalRadius: 4, verticalRadius: 4,
                        child: pw.Image(studentPhoto, fit: pw.BoxFit.cover),
                      ),
                    ),
                    pw.SizedBox(width: 10),
                  ],
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('STUDENT INFO',
                            style: style(size: 7, isBold: true, color: PdfColors.indigo700)),
                        pw.Divider(color: PdfColors.indigo200, thickness: 0.5),
                        infoRow('Adm No', s.admissionNumber),
                        infoRow('Student ID', s.studentId),
                        infoRow("Father's Name", s.fatherName),
                        infoRow("Mother's Name", s.motherName ?? ''),
                        infoRow('Mobile', s.mobile),
                        infoRow('Alt Mobile', s.alternateMobile ?? ''),
                        infoRow('Gender', s.gender),
                        infoRow('Date of Birth', _fmtDate(s.dob)),
                        infoRow('Address', s.address),

                        pw.SizedBox(height: 6),
                        pw.Text('ACADEMIC INFO',
                            style: style(size: 7, isBold: true, color: PdfColors.green800)),
                        pw.Divider(color: PdfColors.green200, thickness: 0.5),
                        infoRow('Student Type', s.studentType == 'school' ? 'School' : 'Computer'),
                        infoRow('Class/Course', s.displayClass),
                        infoRow('Section/Batch', s.section ?? s.batch ?? ''),
                        infoRow('Roll No', s.rollNumber ?? ''),
                        infoRow('Admission Date', _fmtDate(s.admissionDate)),
                        infoRow('Session', s.session ?? ''),

                        pw.SizedBox(height: 6),
                        pw.Text('FEE INFO',
                            style: style(size: 7, isBold: true, color: PdfColors.orange800)),
                        pw.Divider(color: PdfColors.orange200, thickness: 0.5),
                        infoRow('Total Fees', fee != null ? _rs(fee.totalFees) : '—'),
                        infoRow('Paid Fees', fee != null ? _rs(fee.paidFees) : '—',
                            valueColor: PdfColors.green700),
                        infoRow('Remaining', fee != null ? _rs(fee.remainingFees) : '—',
                            valueColor: fee != null && fee.remainingFees > 0
                                ? PdfColors.red700
                                : PdfColors.green700),
                        infoRow('Fee Status', fee?.feeStatus ?? 'Not Set'),
                        infoRow('Last Paid', _fmtDate(fee?.lastPaidDate)),
                        infoRow('Payment Mode', lastPayment?.paymentMode ?? ''),

                        pw.SizedBox(height: 6),
                        pw.Text('ATTENDANCE',
                            style: style(size: 7, isBold: true, color: PdfColors.purple800)),
                        pw.Divider(color: PdfColors.purple200, thickness: 0.5),
                        infoRow('Total Days', '$total'),
                        infoRow('Present', '$present'),
                        infoRow('Absent', '$absent'),
                        infoRow('Leave', '$leave'),
                        infoRow('Attendance', pct),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Collect all student cards. For very large datasets, yield to the
    // event loop periodically so the app stays responsive and any progress
    // callback actually gets a chance to update the UI.
    final List<pw.Widget> allCards = [];
    for (int i = 0; i < students.length; i++) {
      allCards.add(await buildStudentCard(i));
      onProgress?.call(i + 1, students.length);
      if (i % 50 == 0) await Future.delayed(const Duration(milliseconds: 5));
    }

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        header: (ctx) => headerWidget(),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount} | ${settings.instituteName}',
            style: style(size: 8, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) => [
          pw.SizedBox(height: 8),
          ...allCards,
        ],
      ),
    );

    final bytes = await pdf.save();
    final ts = DateTime.now().toIso8601String().substring(0, 10);
    final filename = 'complete_student_data_$ts.pdf';
    return (bytes, filename);
  }
}