import '../../core/utils/file_saver.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/fee_model.dart';
import '../models/settings_model.dart';
import '../models/student_model.dart';
import '../../core/utils/app_utils.dart';
import '../services/database_service.dart';

/// Centralized service to generate official Receipt PDFs matching the Website 100%.
class ReceiptPdfService {
  ReceiptPdfService._();
  static final ReceiptPdfService instance = ReceiptPdfService._();

  static String numberToWords(double amount) {
    final num = amount.toInt();
    if (num == 0) return 'Zero';
    const ones = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
      'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
      'Seventeen', 'Eighteen', 'Nineteen'
    ];
    const tens = [
      '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
    ];

    String convertLessThanOneThousand(int n) {
      if (n == 0) return '';
      String tempStr = '';
      if (n >= 100) {
        tempStr += '${ones[n ~/ 100]} Hundred ';
        n %= 100;
      }
      if (n >= 20) {
        tempStr += '${tens[n ~/ 10]} ';
        n %= 10;
      }
      if (n > 0) {
        tempStr += '${ones[n]} ';
      }
      return tempStr;
    }

    String str = '';
    int rem = num;

    if (rem >= 10000000) {
      final cr = rem ~/ 10000000;
      str += '${convertLessThanOneThousand(cr)}Crore ';
      rem %= 10000000;
    }
    if (rem >= 100000) {
      final lk = rem ~/ 100000;
      str += '${convertLessThanOneThousand(lk)}Lakh ';
      rem %= 100000;
    }
    if (rem >= 1000) {
      final th = rem ~/ 1000;
      str += '${convertLessThanOneThousand(th)}Thousand ';
      rem %= 1000;
    }
    str += convertLessThanOneThousand(rem);
    return str.trim().isEmpty ? 'Zero' : str.trim();
  }

  Future<pw.Document> generateDocument({
    required StudentModel student,
    required PaymentModel payment,
    required SettingsModel settings,
    MonthlyFeeModel? fee,
  }) async {
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();

    final logoBytes = await AppUtils.loadAppImageBytes(settings.logoPath);
    final logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    final sigBytes = await AppUtils.loadAppImageBytes(settings.principalSignature);
    final sigImage = sigBytes != null ? pw.MemoryImage(sigBytes) : null;

    final stampBytes = await AppUtils.loadAppImageBytes(settings.schoolStamp);
    final stampImage = stampBytes != null ? pw.MemoryImage(stampBytes) : null;

    final feeMonthRaw = payment.feeMonth ?? fee?.month ?? '';
    final monthKey = PaymentModel.toMonthKey(payment.monthKey ?? feeMonthRaw, payment.paymentDate);
    final feeMonthLabel = PaymentModel.toFeeMonthLabel(feeMonthRaw.isNotEmpty ? feeMonthRaw : monthKey, payment.paymentDate);

    // Resolve MonthlyFeeModel if fee was passed as null or with human label like 'August 2026'
    MonthlyFeeModel? resolvedFee = fee;
    if (resolvedFee == null && monthKey.isNotEmpty) {
      try {
        resolvedFee = await DatabaseService.instance.getMonthlyFee(student.id, monthKey) ??
            await DatabaseService.instance.getMonthlyFee(student.studentId, monthKey) ??
            await DatabaseService.instance.getMonthlyFee(payment.studentId, monthKey);
      } catch (_) {}
    }

    // Try to load feeStructure and aggregate fee
    StudentFeeStructureModel? structure;
    FeeModel? aggregateFee;
    try {
      structure = await DatabaseService.instance.getFeeStructure(student.id) ??
          await DatabaseService.instance.getFeeStructure(student.studentId) ??
          await DatabaseService.instance.getFeeStructure(payment.studentId);
      aggregateFee = await DatabaseService.instance.getFeeByStudentId(student.id) ??
          await DatabaseService.instance.getFeeByStudentId(student.studentId) ??
          await DatabaseService.instance.getFeeByStudentId(payment.studentId);
    } catch (_) {}

    final doc = pw.Document();

    const darkText = PdfColors.black;
    final lightGrey = PdfColor.fromHex('#F5F5F5');
    final greenColor = PdfColor.fromHex('#1B5E20');
    final greenBg = PdfColor.fromHex('#E8F5E9');
    final redColor = PdfColor.fromHex('#B71C1C');
    final redBg = PdfColor.fromHex('#FFEBEE');
    final carryColor = PdfColor.fromHex('#A06400');
    final carryBg = PdfColor.fromHex('#FFFBEB');

    String fmtDate(DateTime d) {
      final loc = d.toLocal();
      return '${loc.day.toString().padLeft(2, '0')}/${loc.month.toString().padLeft(2, '0')}/${loc.year}';
    }

    String fmtTime(DateTime d) {
      final loc = d.toLocal();
      final hour = loc.hour == 0 ? 12 : loc.hour > 12 ? loc.hour - 12 : loc.hour;
      final minute = loc.minute.toString().padLeft(2, '0');
      final period = loc.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    }

    String fmtDateLong(DateTime d) {
      final loc = d.toLocal();
      const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${loc.day} ${m[loc.month - 1]} ${loc.year}';
    }

    // 1. Resolve monthly particulars snapshot from payment or student record
    Map<String, dynamic>? mp;
    if (student.monthlyParticulars != null) {
      if (student.monthlyParticulars![monthKey] is Map) {
        mp = Map<String, dynamic>.from(student.monthlyParticulars![monthKey] as Map);
      } else if (feeMonthLabel.isNotEmpty && student.monthlyParticulars![feeMonthLabel] is Map) {
        mp = Map<String, dynamic>.from(student.monthlyParticulars![feeMonthLabel] as Map);
      }
    }

    final ps = payment.particularsSnapshot ?? mp;

    // Resolve Tuition Fee with accurate fallback hierarchy (never mistakenly default to partial payment amount)
    final double standardMonthlyTuition = (structure?.tuitionFee != null && structure!.tuitionFee > 0)
        ? structure.tuitionFee
        : ((student.feeStructure != null && (student.feeStructure!['tuitionFee'] as num?)?.toDouble() != null && ((student.feeStructure!['tuitionFee'] as num).toDouble() > 0))
            ? (student.feeStructure!['tuitionFee'] as num).toDouble()
            : (student.monthlyFee != null && student.monthlyFee! > 0
                ? student.monthlyFee!
                : (resolvedFee?.tuitionFee != null && resolvedFee!.tuitionFee > 0
                    ? resolvedFee.tuitionFee
                    : 0.0)));

    final double tuition = (ps != null && ps['tuitionFee'] != null && (ps['tuitionFee'] as num).toDouble() > 0)
        ? (ps['tuitionFee'] as num).toDouble()
        : (resolvedFee?.tuitionFee != null && resolvedFee!.tuitionFee > 0
            ? resolvedFee.tuitionFee
            : (standardMonthlyTuition > 0
                ? standardMonthlyTuition
                : (payment.totalDemand != null && payment.totalDemand! > 0
                    ? payment.totalDemand!
                    : payment.amount)));

    final admission = (ps != null && ps['admissionFee'] != null)
        ? (ps['admissionFee'] as num).toDouble()
        : (resolvedFee?.admissionFee ?? 0.0);
    final exam = (ps != null && (ps['examinationFee'] != null || ps['examFee'] != null))
        ? ((ps['examinationFee'] ?? ps['examFee']) as num).toDouble()
        : (resolvedFee?.examinationFee ?? 0.0);
    final prevDueParticular = (ps != null && (ps['previousDue'] != null || ps['previousDues'] != null))
        ? ((ps['previousDue'] ?? ps['previousDues']) as num).toDouble()
        : (resolvedFee?.previousDue ?? (payment.previousDue ?? (student.previousDue ?? 0.0)));
    final game = (ps != null && ps['gameFee'] != null)
        ? (ps['gameFee'] as num).toDouble()
        : (resolvedFee?.gameFee ?? (structure?.gameFee ?? 0.0));
    final reAdm = (ps != null && ps['reAdmissionFee'] != null)
        ? (ps['reAdmissionFee'] as num).toDouble()
        : (resolvedFee?.reAdmissionFee ?? 0.0);
    final dev = (ps != null && ps['developmentFee'] != null)
        ? (ps['developmentFee'] as num).toDouble()
        : (resolvedFee?.developmentFee ?? 0.0);
    final schoolId = (ps != null && (ps['schoolId'] != null || ps['schoolIdFee'] != null))
        ? ((ps['schoolId'] ?? ps['schoolIdFee']) as num).toDouble()
        : (resolvedFee?.schoolIdFee ?? 0.0);
    final tieBag = (ps != null && (ps['tieBagBelt'] != null || ps['tieBagBeltFee'] != null))
        ? ((ps['tieBagBelt'] ?? ps['tieBagBeltFee']) as num).toDouble()
        : (resolvedFee?.tieBagBeltFee ?? 0.0);
    final backDues = (ps != null && ps['backDues'] != null)
        ? (ps['backDues'] as num).toDouble()
        : (resolvedFee?.backDues ?? 0.0);
    final transport = (ps != null && ps['transportFee'] != null)
        ? (ps['transportFee'] as num).toDouble()
        : (resolvedFee?.transportFee ?? (structure?.transportFee ?? 0.0));
    final other = (ps != null && ps['otherFee'] != null)
        ? (ps['otherFee'] as num).toDouble()
        : (resolvedFee?.otherFee ?? 0.0);
    final fine = (ps != null && ps['lateFine'] != null)
        ? (ps['lateFine'] as num).toDouble()
        : (resolvedFee?.lateFine ?? 0.0);

    // 13 particulars matching website
    final particulars = <MapEntry<String, double>>[
      MapEntry('Admission Fee', admission),
      MapEntry('Tuition Fee', tuition),
      MapEntry('Examination Fee', exam),
      MapEntry('Previous Dues', prevDueParticular),
      MapEntry('Game Fee', game),
      MapEntry('Re-Admission Fee', reAdm),
      MapEntry('Development Fee', dev),
      MapEntry('School ID', schoolId),
      MapEntry('Tie, Bag, Belt', tieBag),
      MapEntry('Back Dues', backDues),
      MapEntry('Transport Fee', transport),
      MapEntry('Other Fee', other),
      MapEntry('Late Fine', fine),
    ];

    final double totalParticulars = particulars.fold(0.0, (sum, p) => sum + p.value);
    final double totalDemand = (payment.totalDemand != null && payment.totalDemand! > 0)
        ? payment.totalDemand!
        : (totalParticulars > 0
            ? totalParticulars
            : (resolvedFee?.totalDue != null && resolvedFee!.totalDue > 0
                ? resolvedFee.totalDue
                : (standardMonthlyTuition > 0
                    ? standardMonthlyTuition
                    : (student.initialTotalFees != null && student.initialTotalFees! > 0
                        ? student.initialTotalFees!
                        : (aggregateFee != null && aggregateFee.totalFees > 0
                            ? aggregateFee.totalFees
                            : payment.amount)))));

    // Try to load prior payment details (for multi-payment / full paid receipts of the same period)
    PaymentModel? priorPayment;
    bool isSameMonthPrior = false;
    try {
      final payments = await DatabaseService.instance.getPayments(student.id);
      payments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
      for (final p in payments) {
        if (p.id != payment.id && !p.paymentDate.isAfter(payment.paymentDate)) {
          priorPayment = p;
          if (p.feeMonth != null && payment.feeMonth != null && p.feeMonth == payment.feeMonth) {
            isSameMonthPrior = true;
          }
          break;
        }
      }
    } catch (_) {}

    final double amountPaid = payment.amount;
    final double previousPaid = (payment.previousPaid != null && payment.previousPaid! > 0)
        ? payment.previousPaid!
        : (isSameMonthPrior && priorPayment != null ? priorPayment.amount : 0.0);

    final DateTime? lastPaidDate = (priorPayment != null)
        ? priorPayment.paymentDate
        : (aggregateFee?.lastPaidDate ?? resolvedFee?.lastPaymentDate);

    final double totalPaidAfter = payment.totalPaidAfter ?? (previousPaid + amountPaid);

    final double remainingDue = (payment.balanceDue != null && payment.balanceDue! >= 0)
        ? payment.balanceDue!
        : (resolvedFee != null && resolvedFee.remaining >= 0
            ? resolvedFee.remaining
            : (totalDemand - totalPaidAfter).clamp(0.0, double.infinity));

    final String dueDateLabel = resolvedFee?.dueDate != null
        ? fmtDate(resolvedFee!.dueDate!)
        : (structure != null ? '${structure.dueDay}th of month' : '10th of month');
    final String sessionLabel = student.session?.isNotEmpty == true
        ? student.session!
        : (settings.currentSession.isNotEmpty ? settings.currentSession : '2026-27');
    final int dueDay = structure?.dueDay ?? 10;
    final int lateFinePerDay = (structure?.finePerDay != null && structure!.finePerDay > 0)
        ? structure.finePerDay.toInt()
        : 5;

    pw.Widget makeInfoCell(String label, String value, {bool alignRight = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        child: pw.Row(
          mainAxisAlignment: alignRight ? pw.MainAxisAlignment.end : pw.MainAxisAlignment.start,
          children: [
            pw.Text('$label: ', style: pw.TextStyle(font: regular, fontSize: 7.5, color: darkText)),
            pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 7.5, color: darkText)),
          ],
        ),
      );
    }

    pw.Widget tableCell(String text, pw.Font font, {bool center = false, bool right = false, PdfColor? color}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: pw.Align(
          alignment: center ? pw.Alignment.center : right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
          child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 6.8, color: color ?? darkText)),
        ),
      );
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(8),
        build: (_) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: darkText, width: 0.8),
            ),
            padding: const pw.EdgeInsets.all(8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // ─── Header ─────────────────────────────────────────
                pw.Center(
                  child: pw.Text(
                    'OFFICIAL FEE RECEIPT VOUCHER',
                    style: pw.TextStyle(font: bold, fontSize: 8, color: darkText, letterSpacing: 1.2),
                  ),
                ),
                pw.SizedBox(height: 2),
                if (logoImage != null) ...[
                  pw.Center(
                    child: pw.Image(logoImage, width: 36, height: 36, fit: pw.BoxFit.contain),
                  ),
                  pw.SizedBox(height: 2),
                ],
                pw.Center(
                  child: pw.Text(
                    (settings.instituteName.isNotEmpty ? settings.instituteName : 'Mission Navodaya Public School').toUpperCase(),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: bold, fontSize: 12, color: darkText),
                  ),
                ),
                if (settings.address.isNotEmpty)
                  pw.Center(
                    child: pw.Text(
                      'Add- ${settings.address}',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(font: regular, fontSize: 7, color: darkText),
                    ),
                  ),
                if (settings.mobile.isNotEmpty)
                  pw.Center(
                    child: pw.Text(
                      'Mob- ${settings.mobile}',
                      style: pw.TextStyle(font: regular, fontSize: 7, color: darkText),
                    ),
                  ),
                pw.SizedBox(height: 3),
                pw.Divider(color: darkText, thickness: 0.6),
                pw.SizedBox(height: 3),

                // ─── Meta Details Grid + Student QR Code ───────────
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              makeInfoCell('Receipt No', payment.receiptNumber),
                              makeInfoCell('Payment Date', '${fmtDate(payment.paymentDate)} ${fmtTime(payment.paymentDate)}', alignRight: true),
                            ],
                          ),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              makeInfoCell("Student's Name", student.name.toUpperCase()),
                              makeInfoCell('Student ID', student.studentId.isNotEmpty ? student.studentId : '-', alignRight: true),
                            ],
                          ),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              makeInfoCell('Admission No', student.admissionNumber.isNotEmpty ? student.admissionNumber : '-'),
                              makeInfoCell("Father's Name", student.fatherName.isNotEmpty ? student.fatherName : '-', alignRight: true),
                            ],
                          ),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              makeInfoCell('Class / Course', student.displayClass),
                              makeInfoCell('Roll No', student.rollNumber?.isNotEmpty == true ? student.rollNumber! : '-', alignRight: true),
                            ],
                          ),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              makeInfoCell('Fees For Period', feeMonthLabel),
                              makeInfoCell('Payment Mode', payment.paymentMode, alignRight: true),
                            ],
                          ),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              makeInfoCell('Due Date', dueDateLabel),
                              makeInfoCell('Session', sessionLabel, alignRight: true),
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Column(
                      children: [
                        pw.Container(
                          width: 48,
                          height: 48,
                          padding: const pw.EdgeInsets.all(2),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: darkText, width: 0.5),
                          ),
                          child: pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: 'ID:${student.id}|ADM:${student.admissionNumber}',
                          ),
                        ),
                        pw.SizedBox(height: 1),
                        pw.Text('PORTAL QR', style: pw.TextStyle(font: bold, fontSize: 5, color: darkText)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 3),

                // ─── 13 Particulars Table ───────────────────────────
                pw.Table(
                  border: pw.TableBorder.all(color: darkText, width: 0.4),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(22),
                    1: const pw.FlexColumnWidth(5),
                    2: const pw.FixedColumnWidth(54),
                    3: const pw.FixedColumnWidth(16),
                  },
                  children: [
                    // Table Header
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: lightGrey),
                      children: [
                        tableCell('S.N.', bold, center: true),
                        tableCell('Particulars', bold),
                        tableCell('Amount (Rs)', bold, right: true),
                        tableCell('P.', bold, center: true),
                      ],
                    ),
                    // 13 rows
                    ...List.generate(13, (i) {
                      final p = particulars[i];
                      final amt = p.value;
                      final isLate = i == 12;
                      final sn = isLate ? '★' : '${i + 1}';
                      return pw.TableRow(children: [
                        tableCell(sn, isLate ? bold : regular, center: true),
                        tableCell(p.key, isLate ? bold : regular),
                        tableCell(amt > 0 ? amt.toStringAsFixed(2) : '', regular, right: true),
                        tableCell(amt > 0 ? '00' : '', regular, center: true),
                      ]);
                    }),
                    // Summary Row 1: Total Fee Demand
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: lightGrey),
                      children: [
                        tableCell('', bold),
                        tableCell('Total Fee Demand', bold, right: true),
                        tableCell(totalDemand.toStringAsFixed(2), bold, right: true),
                        tableCell('00', bold, center: true),
                      ],
                    ),
                    if (previousPaid > 0)
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: carryBg),
                        children: [
                          tableCell('', bold),
                          tableCell(
                            'Previous Payment ${lastPaidDate != null ? "(Last Paid: ${fmtDate(lastPaidDate)})" : ""}',
                            bold,
                            right: true,
                            color: carryColor,
                          ),
                          tableCell(previousPaid.toStringAsFixed(2), bold, right: true, color: carryColor),
                          tableCell('00', bold, center: true, color: carryColor),
                        ],
                      ),
                    // Summary Row 2: Current Payment (Voucher)
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: greenBg),
                      children: [
                        tableCell('', bold),
                        tableCell('Current Payment (Paid Now)', bold, right: true, color: greenColor),
                        tableCell(amountPaid.toStringAsFixed(2), bold, right: true, color: greenColor),
                        tableCell('00', bold, center: true, color: greenColor),
                      ],
                    ),
                    if (previousPaid > 0)
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E3F2FD')),
                        children: [
                          tableCell('', bold),
                          tableCell('Total Amount Paid', bold, right: true, color: PdfColor.fromHex('#0D47A1')),
                          tableCell(totalPaidAfter.toStringAsFixed(2), bold, right: true, color: PdfColor.fromHex('#0D47A1')),
                          tableCell('00', bold, center: true, color: PdfColor.fromHex('#0D47A1')),
                        ],
                      ),
                    // Summary Row 3: Remaining Balance Due
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: remainingDue > 0 ? redBg : greenBg),
                      children: [
                        tableCell('', bold),
                        tableCell(
                          remainingDue <= 0 ? 'Month Balance (FULL PAID)' : 'Month Pending Balance Due',
                          bold,
                          right: true,
                          color: remainingDue > 0 ? redColor : greenColor,
                        ),
                        tableCell(remainingDue.toStringAsFixed(2), bold, right: true, color: remainingDue > 0 ? redColor : greenColor),
                        tableCell('00', bold, center: true, color: remainingDue > 0 ? redColor : greenColor),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 3),

                // ─── Amount in Words ─────────────────────────────────
                pw.Row(children: [
                  pw.Text('Amount in Words: ', style: pw.TextStyle(font: bold, fontSize: 7.2, color: darkText)),
                  pw.Text('${numberToWords(amountPaid)} Rupees Only', style: pw.TextStyle(font: regular, fontSize: 7.2, color: darkText)),
                ]),
                pw.SizedBox(height: 3),
                pw.Divider(color: darkText, thickness: 0.5),
                pw.SizedBox(height: 3),

                // ─── Paid Stamp Badge ────────────────────────────────
                pw.Center(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 2.5),
                    decoration: pw.BoxDecoration(
                      color: remainingDue <= 0 ? greenBg : redBg,
                      borderRadius: pw.BorderRadius.circular(4),
                      border: pw.Border.all(color: remainingDue <= 0 ? greenColor : redColor, width: 0.6),
                    ),
                    child: pw.Text(
                      remainingDue <= 0
                          ? 'FULL PAID: Rs. ${totalPaidAfter.toInt()} Cleared (Paid: Rs. ${amountPaid.toInt()} on ${fmtDateLong(payment.paymentDate)} via ${payment.paymentMode})'
                          : 'PARTIAL PAYMENT: Rs. ${amountPaid.toInt()} Received | Balance Due: Rs. ${remainingDue.toInt()} (${fmtDateLong(payment.paymentDate)} via ${payment.paymentMode})',
                      style: pw.TextStyle(font: bold, fontSize: 7.2, color: remainingDue <= 0 ? greenColor : redColor),
                    ),
                  ),
                ),
                pw.Spacer(),

                // ─── Signatures ──────────────────────────────────────
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(width: 80, height: 0.6, color: darkText),
                        pw.SizedBox(height: 2),
                        pw.Text('Class Teacher Sign.', style: pw.TextStyle(font: bold, fontSize: 7, color: darkText)),
                      ],
                    ),
                    // Stamp & Director Signature Area (Signature overlaid over stamp)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(
                          width: 100,
                          height: 38,
                          child: pw.Stack(
                            alignment: pw.Alignment.center,
                            children: [
                              if (stampImage != null)
                                pw.Opacity(
                                  opacity: 0.88,
                                  child: pw.Image(stampImage, width: 36, height: 36, fit: pw.BoxFit.contain),
                                ),
                              if (sigImage != null)
                                pw.Image(sigImage, width: 56, height: 22, fit: pw.BoxFit.contain),
                            ],
                          ),
                        ),
                        pw.Container(width: 100, height: 0.6, color: darkText),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Director Sign',
                          style: pw.TextStyle(font: bold, fontSize: 7.5, color: darkText),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Divider(color: darkText, thickness: 0.4),
                pw.SizedBox(height: 2),

                // ─── Rules ───────────────────────────────────────────
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Rules:-', style: pw.TextStyle(font: bold, fontSize: 6.5, color: darkText)),
                    pw.Text('1. Last date of fee is ${dueDay}th of the month', style: pw.TextStyle(font: regular, fontSize: 6.2, color: darkText)),
                    pw.Text('2. A fine of Rs $lateFinePerDay/- per day will be charged if the dues are paid after the due date', style: pw.TextStyle(font: regular, fontSize: 6.2, color: darkText)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return doc;
  }

  Future<String> createPdfFile({
    required StudentModel student,
    required PaymentModel payment,
    required SettingsModel settings,
    MonthlyFeeModel? fee,
  }) async {
    final doc = await generateDocument(
      student: student,
      payment: payment,
      settings: settings,
      fee: fee,
    );
    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/receipt_${payment.receiptNumber}.pdf');
    await file.writeAsBytes(bytes);
    try {
      await FileSaver.saveCategorizedFile(
        bytes: bytes,
        filename: 'Receipt_${payment.receiptNumber}_${student.name.replaceAll(' ', '_')}.pdf',
        category: FileCategory.feeReceipts,
        schoolName: settings.instituteName,
      );
    } catch (_) {}
    return file.path;
  }
}
