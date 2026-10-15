import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/student_model.dart';
import '../../data/services/database_service.dart';

class AttendanceReportService {
  static Future<File> generateStudentAttendancePdf({
    required StudentModel student,
    required DateTime fromDate,
    required DateTime toDate,
    required String instituteName,
  }) async {
    final all =
    await DatabaseService.instance.getAttendanceByStudentId(student.id);

    final from = DateTime(fromDate.year, fromDate.month, fromDate.day);
    final to = DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59);

    final records = all.where((a) {
      return !a.date.isBefore(from) && !a.date.isAfter(to);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final present = records.where((a) => a.status == 'present').length;
    final absent = records.where((a) => a.status == 'absent').length;
    final leave = records.where((a) => a.status == 'leave').length;
    final total = records.length;
    final percentage = total == 0 ? 0.0 : present * 100 / total;

    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              color: PdfColor.fromHex('#1F108E'),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    instituteName.toUpperCase(),
                    style: pw.TextStyle(font: bold, fontSize: 13, color: PdfColors.amber),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'STUDENT ATTENDANCE REPORT — ${_formatDate(fromDate)} to ${_formatDate(toDate)}',
                    style: pw.TextStyle(font: regular, fontSize: 8.5, color: PdfColors.indigo100),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} / ${context.pagesCount}',
            style: pw.TextStyle(font: regular, fontSize: 8),
          ),
        ),
        build: (context) => [
          pw.Text(
            'Student Information',
            style: pw.TextStyle(font: bold, fontSize: 12),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(
              color: PdfColors.grey400,
              width: .5,
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(2),
            },
            children: [
              _infoRow(
                'Student Name',
                student.name,
                'Admission No.',
                student.admissionNumber,
                regular,
                bold,
              ),
              _infoRow(
                'Father\'s Name',
                student.fatherName,
                'Roll No.',
                (student.rollNumber?.isNotEmpty == true) ? student.rollNumber! : '—',
                regular,
                bold,
              ),
              _infoRow(
                'Student ID',
                student.studentId,
                'Mobile',
                student.mobile,
                regular,
                bold,
              ),
              _infoRow(
                'Class/Section',
                student.displayClass,
                'Student Type',
                student.studentType,
                regular,
                bold,
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Report Period',
            style: pw.TextStyle(font: bold, fontSize: 12),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            '${_formatDate(from)} to ${_formatDate(toDate)}',
            style: pw.TextStyle(font: regular, fontSize: 10),
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            children: [
              _summaryBox('Total', total.toString(), regular, bold),
              pw.SizedBox(width: 8),
              _summaryBox('Present', present.toString(), regular, bold),
              pw.SizedBox(width: 8),
              _summaryBox('Absent', absent.toString(), regular, bold),
              pw.SizedBox(width: 8),
              _summaryBox('Leave', leave.toString(), regular, bold),
              pw.SizedBox(width: 8),
              _summaryBox(
                'Attendance',
                '${percentage.toStringAsFixed(1)}%',
                regular,
                bold,
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Daily Attendance',
            style: pw.TextStyle(font: bold, fontSize: 12),
          ),
          pw.SizedBox(height: 7),
          if (records.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
              ),
              child: pw.Text(
                'No attendance records found for the selected date range.',
                style: pw.TextStyle(font: regular, fontSize: 10),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: const ['S.No.', 'Date', 'Day', 'Status'],
              data: [
                for (var i = 0; i < records.length; i++)
                  [
                    '${i + 1}',
                    _formatDate(records[i].date),
                    _dayName(records[i].date),
                    _statusLabel(records[i].status),
                  ],
              ],
              headerStyle: pw.TextStyle(font: bold, fontSize: 9),
              cellStyle: pw.TextStyle(font: regular, fontSize: 8.5),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 5,
              ),
              border: pw.TableBorder.all(
                color: PdfColors.grey400,
                width: .5,
              ),
            ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final safeName = student.name
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    final file = File(
      '${dir.path}/attendance_${safeName}_${_fileDate(from)}_${_fileDate(toDate)}.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> printPdf(File file) async {
    final bytes = await file.readAsBytes();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static String whatsappMessage({
    required StudentModel student,
    required DateTime fromDate,
    required DateTime toDate,
    required String instituteName,
  }) {
    return 'Dear Parent,\n\n'
        'Please find the attendance report of ${student.name} attached.\n\n'
        'Student: ${student.name}\n'
        'Admission No: ${student.admissionNumber}\n'
        'Period: ${_formatDate(fromDate)} to ${_formatDate(toDate)}\n\n'
        'Regards,\n$instituteName';
  }

  static pw.TableRow _infoRow(
      String label1,
      String value1,
      String label2,
      String value2,
      pw.Font regular,
      pw.Font bold,
      ) {
    return pw.TableRow(
      children: [
        _cell(label1, bold),
        _cell(value1, regular),
        _cell(label2, bold),
        _cell(value2, regular),
      ],
    );
  }

  static pw.Widget _cell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 8.5),
      ),
    );
  }

  static pw.Widget _summaryBox(
      String title,
      String value,
      pw.Font regular,
      pw.Font bold,
      ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(
          horizontal: 5,
          vertical: 8,
        ),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(font: regular, fontSize: 7),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              value,
              style: pw.TextStyle(font: bold, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'present':
        return 'Present';
      case 'absent':
        return 'Absent';
      case 'leave':
        return 'Leave';
      default:
        return status;
    }
  }

  static String _dayName(DateTime date) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[date.weekday - 1];
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.year}';
  }

  static String _fileDate(DateTime date) {
    return '${date.year}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }
}