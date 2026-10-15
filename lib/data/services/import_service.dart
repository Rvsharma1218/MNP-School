import 'dart:developer' as developer;
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:uuid/uuid.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/import_models.dart';
import '../models/student_model.dart';
import '../../core/utils/excel_cell_reader.dart';
import '../../core/utils/file_saver.dart';
import 'database_service.dart';
import 'firestore_service.dart';

/// Service that handles all Excel and PDF import/export template operations.
/// Keeps import logic fully separated from UI.
class ImportService {
  static final ImportService instance = ImportService._internal();
  ImportService._internal();

  // ─── Excel Template Download ─────────────────────────────────────────────

  Future<List<int>> buildImportTemplateBytes() async {
    final excel = Excel.createExcel();
    // Remove default sheet
    excel.rename('Sheet1', 'Import Template');
    final sheet = excel['Import Template'];

    // Style helpers
    CellStyle headerStyle() {
      final style = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1A237E'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        textWrapping: TextWrapping.WrapText,
      );
      return style;
    }

    CellStyle requiredStyle() {
      final style = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#FFF9C4'),
        fontColorHex: ExcelColor.fromHexString('#B71C1C'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
      return style;
    }

    CellStyle exampleStyle() {
      final style = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#E8F5E9'),
        fontColorHex: ExcelColor.fromHexString('#1B5E20'),
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
        italic: true,
      );
      return style;
    }

    CellStyle exampleLabelStyle() {
      final style = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#F3E5F5'),
        fontColorHex: ExcelColor.fromHexString('#4A148C'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
      return style;
    }

    // Row 1: Header row
    final headers = kTemplateColumns.map((c) => c.header).toList();
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = kTemplateColumns[i].required ? requiredStyle() : headerStyle();
    }

    // Row 2: Example 1 (visible example)
    // First cell: label
    final labelCell1 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1));
    labelCell1.value = TextCellValue('EXAMPLE ROW 1 →');
    labelCell1.cellStyle = exampleLabelStyle();

    for (int i = 0; i < kTemplateColumns.length; i++) {
      if (i == 0) continue; // skip first cell (used for label) - add admission number separately
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1));
      cell.value = TextCellValue(kTemplateColumns[i].example1);
      cell.cellStyle = exampleStyle();
    }
    // Fix admission number on example row
    final admCell1 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1));
    admCell1.value = TextCellValue(kTemplateColumns[0].example1);
    admCell1.cellStyle = exampleStyle();

    // Row 3: Example 2
    for (int i = 0; i < kTemplateColumns.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2));
      cell.value = TextCellValue(kTemplateColumns[i].example2);
      cell.cellStyle = exampleStyle();
    }

    // Row 4: Empty — where user starts entering data
    final startCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3));
    startCell.value = TextCellValue('← Start entering your data here from row 4');

    // Set column widths
    for (int i = 0; i < kTemplateColumns.length; i++) {
      sheet.setColumnWidth(i, 20);
    }

    // Add instructions sheet
    final infoSheet = excel['Instructions'];
    infoSheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('IMPORT TEMPLATE INSTRUCTIONS');
    infoSheet.cell(CellIndex.indexByString('A3')).value = TextCellValue('1. Do NOT delete or rename the "Import Template" sheet.');
    infoSheet.cell(CellIndex.indexByString('A4')).value = TextCellValue('2. Do NOT modify the header row (Row 1).');
    infoSheet.cell(CellIndex.indexByString('A5')).value = TextCellValue('3. Example rows (2-3) are for reference only. They will be detected and NOT imported.');
    infoSheet.cell(CellIndex.indexByString('A6')).value = TextCellValue('4. Enter your data starting from Row 4.');
    infoSheet.cell(CellIndex.indexByString('A7')).value = TextCellValue('5. Columns marked in YELLOW/RED are REQUIRED.');
    infoSheet.cell(CellIndex.indexByString('A8')).value = TextCellValue('6. Date format: DD-MM-YYYY (e.g. 01-04-2025)');
    infoSheet.cell(CellIndex.indexByString('A9')).value = TextCellValue('7. Student Type: "school" or "computer" (lowercase)');
    infoSheet.cell(CellIndex.indexByString('A10')).value = TextCellValue('8. Status: active | completed | left | suspended');
    infoSheet.cell(CellIndex.indexByString('A11')).value = TextCellValue('9. Fees are optional — enter numbers only (no ₹ symbol)');
    infoSheet.setColumnWidth(0, 70);

    return excel.encode()!;
  }

  /// Saves the template to the device downloads folder.
  Future<void> downloadImportTemplate() async {
    final bytes = await buildImportTemplateBytes();
    final ts = DateTime.now().toIso8601String().substring(0, 10);
    await FileSaver.saveToDownloads(bytes, 'student_import_template_$ts.xlsx');
  }

  // ─── Excel Parse ─────────────────────────────────────────────────────────

  Future<ImportResult> parseExcelFile(String filePath) async {
    final fileName = filePath.split(Platform.pathSeparator).last;
    try {
      final bytes = await File(filePath).readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      Sheet? sheet;
      for (final name in excel.sheets.keys) {
        final s = excel.sheets[name];
        if (s == null) continue;
        if (s.rows.length > 1) {
          sheet = s;
          break;
        }
      }
      sheet ??= excel.sheets.values.firstOrNull;
      if (sheet == null || sheet.rows.isEmpty) {
        return ImportResult(totalRows: 0, rows: []);
      }

      final headerRowIndex = findExcelHeaderRowIndex(sheet);
      final headerRow = sheet.rows[headerRowIndex];

      final colIndex = <String, int>{};
      for (int ci = 0; ci < headerRow.length; ci++) {
        final h = normalizeExcelHeader(readExcelRowCell(headerRow, ci));
        if (h.isNotEmpty) colIndex[h] = ci;
      }

      int? findCol(List<String> names) {
        for (final name in names) {
          final key = normalizeExcelHeader(name);
          if (colIndex.containsKey(key)) return colIndex[key];
          for (final entry in colIndex.entries) {
            if (entry.key.contains(key) || key.contains(entry.key)) {
              return entry.value;
            }
          }
        }
        return null;
      }

      String getField(List<Data?> row, List<String> names) {
        final idx = findCol(names);
        if (idx == null) return '';
        return readExcelRowCell(row, idx);
      }

      String? getFieldNullable(List<Data?> row, List<String> names) {
        final v = getField(row, names);
        return v.isEmpty ? null : v;
      }

      double? getDoubleField(List<Data?> row, List<String> names) {
        final idx = findCol(names);
        if (idx == null) return null;
        if (idx < 0 || idx >= row.length) return null;
        return parseExcelDouble(row[idx]?.value);
      }

      int? getIntField(List<Data?> row, List<String> names) {
        final d = getDoubleField(row, names);
        return d?.round();
      }

      String? getDateField(List<Data?> row, List<String> names) {
        final idx = findCol(names);
        if (idx == null) return null;
        if (idx < 0 || idx >= row.length) return null;
        final dt = parseExcelDate(row[idx]?.value);
        if (dt != null) return _formatDate(dt);
        return getFieldNullable(row, names);
      }

      // Attendance % cells come in as literal text like "88%" — read the
      // raw cell text and strip the '%' before parsing, rather than
      // routing through parseExcelDouble (which expects a plain number and
      // would fail/return null on the trailing '%').
      double? getPercentField(List<Data?> row, List<String> names) {
        final idx = findCol(names);
        if (idx == null) return null;
        if (idx < 0 || idx >= row.length) return null;
        final raw = readExcelRowCell(row, idx).trim();
        if (raw.isEmpty) return null;
        return double.tryParse(raw.replaceAll('%', '').trim());
      }

      // Column-level check (independent of any single row's data) for
      // whether this file has attendance columns at all — used to decide
      // the "Attendance Data Found" vs "Attendance columns were not found"
      // banner. Previously this was never computed, so the warning showed
      // unconditionally even for files that DID have these columns.
      final hasAttendanceCols = findCol([
        'total attendance days', 'total days', 'totaldays', 'total attendance',
      ]) != null ||
          findCol(['present', 'present days', 'presentdays']) != null ||
          findCol(['absent', 'absent days', 'absentdays']) != null ||
          findCol(['leave', 'leave days', 'leavedays']) != null ||
          findCol([
            'attendance %', 'attendance percentage', 'attendancepercentage', 'attendance',
          ]) != null;

      final rows = <StudentImportRow>[];
      var totalDataRows = 0;

      for (int i = headerRowIndex + 1; i < sheet.rows.length; i++) {
        try {
          final row = sheet.rows[i];
          if (row.isEmpty) continue;

          final firstCellText = readExcelRowCell(row, 0).toLowerCase();
          if (firstCellText.contains('example') ||
              firstCellText.contains('start entering') ||
              firstCellText.contains('instruction') ||
              firstCellText.contains('basic information') ||
              firstCellText.contains('academic information')) {
            continue;
          }

          final admNo = getField(row, [
            'admission number', 'admission no', 'adm no', 'admno',
            'admission number', 'admissionnumber',
          ]);
          final name = getField(row, [
            'student name', 'name', 'studentname', 'full name', 'fullname',
          ]);

          if (admNo.isEmpty && name.isEmpty) continue;
          totalDataRows++;

          String? validationError;
          if (admNo.isEmpty) {
            validationError = 'Admission Number is required';
          } else if (name.isEmpty) {
            validationError = 'Student Name is required';
          }

          final stuId = getField(row, ['student id', 'studentid', 'id']);
          final classOrCourse = getFieldNullable(row, [
            'class', 'class course', 'class/course', 'grade', 'std', 'course',
          ]);
          final sectionOrBatch = getFieldNullable(row, [
            'section', 'section batch', 'section/batch', 'batch', 'sec',
          ]);
          final studentTypeRaw = getFieldNullable(row, [
            'student type', 'type', 'studenttype',
          ]) ?? 'school';
          final isComputer = studentTypeRaw.toLowerCase().contains('computer');

          rows.add(StudentImportRow(
            rowIndex: i + 1,
            admissionNumber: admNo,
            studentId: stuId.isNotEmpty ? stuId : admNo,
            name: name,
            fatherName: getField(row, [
              "father's name", 'father name', 'fathername', 'father',
            ]),
            motherName: getFieldNullable(row, [
              "mother's name", 'mother name', 'mothername', 'mother',
            ]),
            mobile: getField(row, [
              'mobile', 'phone', 'contact', 'mobile number', 'phone number',
            ]),
            alternateMobile: getFieldNullable(row, [
              'alternate mobile', 'alt mobile', 'alt. mobile', 'altmobile',
            ]),
            gender: getFieldNullable(row, ['gender', 'sex']),
            dob: getDateField(row, [
              'date of birth', 'dob', 'birth date', 'birthdate',
            ]),
            address: getFieldNullable(row, ['address', 'addr']),
            studentType: isComputer ? 'computer' : 'school',
            className: isComputer ? null : classOrCourse,
            section: isComputer ? null : sectionOrBatch,
            rollNumber: getFieldNullable(row, [
              'roll number', 'roll no', 'rollno', 'roll',
            ]),
            course: isComputer ? classOrCourse : getFieldNullable(row, ['course']),
            batch: isComputer ? sectionOrBatch : getFieldNullable(row, ['batch']),
            admissionDate: getDateField(row, [
              'admission date', 'admissiondate', 'join date', 'joining date',
            ]),
            session: getFieldNullable(row, [
              'academic session', 'session', 'year', 'academic year',
            ]),
            totalFees: getDoubleField(row, [
              'total fees',
              'totalfees',
              'total fee',
              'fees',
            ]),

            paidFees: getDoubleField(row, [
              'paid fees',
              'paidfees',
              'paid fee',
              'paid',
              'amount paid',
            ]),

            feeStatus: getFieldNullable(row, [
              'fee status',
              'feestatus',
              'payment status',
            ]),

            lastPaymentDate: getDateField(row, [
              'last payment date',
              'lastpaymentdate',
              'last paid',
              'last paid date',
            ]),

            paymentMode: getFieldNullable(row, [
              'payment mode',
              'paymentmode',
              'mode of payment',
              'mode',
            ]),

            admissionFee: getDoubleField(row, [
              'admission fee',
              'admissionfee',
            ]),

            tuitionFee: getDoubleField(row, [
              'tuition fee',
              'tuitionfee',
            ]),

            monthlyFee: getDoubleField(row, [
              'monthly fee',
              'monthlyfee',
            ]),

            examinationFee: getDoubleField(row, [
              'examination fee',
              'examinationfee',
              'exam fee',
              'examfee',
            ]),

            previousDues: getDoubleField(row, [
              'previous dues',
              'previous due',
              'previousdues',
            ]),

            gameFee: getDoubleField(row, [
              'game fee',
              'gamefee',
            ]),

            reAdmissionFee: getDoubleField(row, [
              're-admission fee',
              'readmission fee',
              're admission fee',
            ]),

            developmentFee: getDoubleField(row, [
              'development fee',
              'developmentfee',
            ]),

            schoolIdFee: getDoubleField(row, [
              'school id',
              'school id fee',
              'schoolid',
            ]),

            tieBagBeltFee: getDoubleField(row, [
              'tie, bag, belt',
              'tie bag belt',
              'tie bag belt fee',
            ]),

            backDues: getDoubleField(row, [
              'back dues',
              'back due',
              'backdues',
            ]),

            transportFee: getDoubleField(row, [
              'transport fee',
              'transportfee',
            ]),

            otherFee: getDoubleField(row, [
              'other fee',
              'otherfee',
            ]),

            dueDate: getDateField(row, [
              'due date',
              'duedate',
            ]),
            totalAttendanceDays: getIntField(row, [
              'total attendance days', 'total days', 'totaldays', 'total attendance',
            ]),
            presentDays: getIntField(row, [
              'present', 'present days', 'presentdays',
            ]),
            absentDays: getIntField(row, [
              'absent', 'absent days', 'absentdays',
            ]),
            leaveDays: getIntField(row, [
              'leave', 'leave days', 'leavedays',
            ]),
            attendancePercentage: getPercentField(row, [
              'attendance %', 'attendance percentage', 'attendancepercentage', 'attendance',
            ]),
            isValid: validationError == null,
            validationError: validationError,
          ));
        } catch (e, stackTrace) {
          developer.log(
            'Excel row parse failed',
            name: 'ImportService',
            error: e,
            stackTrace: stackTrace,
            sequenceNumber: i + 1,
          );
          totalDataRows++;
          rows.add(StudentImportRow(
            rowIndex: i + 1,
            admissionNumber: '',
            studentId: '',
            name: 'Row ${i + 1}',
            fatherName: '',
            mobile: '',
            isValid: false,
            validationError: 'Could not read row ${i + 1}',
          ));
        }
      }

      final validatedRows = await _markDuplicates(rows);
      final attendanceFoundCount = validatedRows.where((r) =>
      r.totalAttendanceDays != null ||
          r.presentDays != null ||
          r.absentDays != null ||
          r.leaveDays != null).length;
      return ImportResult(
        totalRows: totalDataRows,
        rows: validatedRows,
        hasAttendanceColumns: hasAttendanceCols,
        attendanceFoundCount: attendanceFoundCount,
      );
    } catch (e, stackTrace) {
      developer.log(
        'Excel parse failed',
        name: 'ImportService',
        error: e,
        stackTrace: stackTrace,
      );
      developer.log('File: $fileName', name: 'ImportService');
      throw Exception(userFriendlyExcelError(e));
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.year}';
  }

  Future<List<StudentImportRow>> _markDuplicates(List<StudentImportRow> rows) async {
    final validatedRows = <StudentImportRow>[];
    for (final r in rows) {
      if (!r.isValid) {
        validatedRows.add(r);
        continue;
      }
      try {
        var isDuplicate = false;
        if (r.admissionNumber.isNotEmpty) {
          isDuplicate = await DatabaseService.instance
              .isAdmissionNumberExists(r.admissionNumber);
        }
        if (!isDuplicate &&
            r.studentId.isNotEmpty &&
            r.studentId != r.admissionNumber) {
          isDuplicate =
          await DatabaseService.instance.isStudentIdExists(r.studentId);
        }
        validatedRows.add(r.copyWith(isDuplicate: isDuplicate));
      } catch (_) {
        validatedRows.add(r);
      }
    }
    return validatedRows;
  }

  // ─── PDF Parse ────────────────────────────────────────────────────────────


  Future<PdfImportResult> parsePdfFile(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final pageCount = document.pages.count;

      final fullText = StringBuffer();
      for (int i = 0; i < pageCount; i++) {
        final extractor = PdfTextExtractor(document);
        final text = extractor.extractText(startPageIndex: i, endPageIndex: i);
        fullText.write(text);
        fullText.write('\n---PAGE_BREAK---\n');
      }
      document.dispose();

      final text = fullText.toString();
      final isAppPdf = text.toLowerCase().contains('complete student data report');
      final isScanned = _isScannedPdf(text, pageCount);

      if (isScanned && !isAppPdf) {
        return PdfImportResult(
          pages: pageCount,
          detectedRecords: 0,
          rows: [],
          mappings: [],
          hasUnrecognizedData: true,
          warningMessage:
          'This PDF contains scanned images and cannot be imported automatically. '
              'Please use Excel import or an OCR-enabled PDF.',
        );
      }

      final rows = _parsePdfText(text);
      final mappings = _detectPdfMappings(text);
      final validatedRows = await _markDuplicates(rows);

      final hasUnrecognized = validatedRows.any((r) => !r.isValid);
      String? warning;
      if (validatedRows.isEmpty) {
        warning = isAppPdf
            ? 'No student records could be detected in this PDF. '
            'Please verify the file was exported from this app.'
            : 'No student records could be detected in this PDF. '
            'The PDF may be scanned/image-based or use an unsupported layout. '
            'Please use Excel import for best results.';
      } else if (hasUnrecognized) {
        warning = 'Some rows could not be recognized. '
            'Please review invalid rows before importing.';
      }

      return PdfImportResult(
        pages: pageCount,
        detectedRecords: validatedRows.length,
        rows: validatedRows,
        mappings: mappings,
        hasUnrecognizedData: hasUnrecognized || validatedRows.isEmpty,
        warningMessage: warning,
      );
    } catch (e, stackTrace) {
      developer.log('PDF parse failed', name: 'ImportService', error: e, stackTrace: stackTrace);
      return PdfImportResult(
        pages: 0,
        detectedRecords: 0,
        rows: [],
        mappings: [],
        hasUnrecognizedData: true,
        warningMessage:
        'Failed to read PDF. The file may be password-protected or corrupted. '
            'Please use Excel import instead.',
      );
    }
  }

  bool _isScannedPdf(String text, int pageCount) {
    if (pageCount <= 0) return true;
    final meaningfulLines = text
        .split('\n')
        .where((l) =>
    l.trim().length > 2 &&
        !l.contains('---PAGE_BREAK---') &&
        !RegExp(r'^page \d+ of \d+', caseSensitive: false).hasMatch(l.trim()))
        .length;
    if (meaningfulLines < pageCount * 4) return true;
    return text.trim().length < pageCount * 40;
  }

  List<StudentImportRow> _parsePdfText(String text) {
    final appRows = _parseAppCompleteStudentPdf(text);
    if (appRows.isNotEmpty) return appRows;
    return _parsePdfTableFormat(text);
  }

  List<StudentImportRow> _parseAppCompleteStudentPdf(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && l != '---PAGE_BREAK---')
        .toList();

    final lowerText = text.toLowerCase();
    final looksLikeAppExport = lowerText.contains('complete student data report') ||
        (lowerText.contains('student info') && lowerText.contains('fee info'));
    if (!looksLikeAppExport &&
        !lowerText.contains('adm no') &&
        !RegExp(r'^\d+\.\s+', multiLine: true).hasMatch(text)) {
      return [];
    }

    final records = <_PdfStudentRecord>[];
    _PdfStudentRecord? current;

    final headerWithStatus = RegExp(
      r'^(\d+)\.\s*(.+?)\s+(Active|Completed|Left|Suspended|Inactive|Unpaid|Pending|Paid|Not Set)\s*$',
      caseSensitive: false,
    );
    final headerSimple = RegExp(r'^(\d+)\.\s*(.+)$');
    final labelPattern = RegExp(r'^(.+?)\s*:\s*(.*)$');

    const skipExact = {
      'student info',
      'academic info',
      'fee info',
      'attendance',
      'attendance summary',
    };

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.contains('complete student data report')) continue;
      if (lower.startsWith('generated:')) continue;
      if (lower.startsWith('total students:')) continue;
      if (RegExp(r'^page \d+ of \d+', caseSensitive: false).hasMatch(lower)) {
        continue;
      }
      if (skipExact.contains(lower)) continue;

      final statusHeader = headerWithStatus.firstMatch(line);
      if (statusHeader != null) {
        if (current != null && current.hasMinimumData) records.add(current);
        current = _PdfStudentRecord(
          index: int.parse(statusHeader.group(1)!),
          name: statusHeader.group(2)!.trim(),
          status: statusHeader.group(3),
        );
        continue;
      }

      if (lower == 'student info') {
        current ??= _PdfStudentRecord(index: records.length + 1);
        continue;
      }

      final labelMatch = labelPattern.firstMatch(line);
      if (labelMatch != null && current != null) {
        final label = _normalizePdfLabel(labelMatch.group(1)!);
        final value = labelMatch.group(2)?.trim() ?? '';
        if (_isPdfLabel(label)) {
          current.setField(label, value);
        }
        continue;
      }

      final simpleHeader = headerSimple.firstMatch(line);
      if (simpleHeader != null && !line.contains(':')) {
        final candidate = simpleHeader.group(2)!.trim();
        if (candidate.isNotEmpty &&
            !candidate.toLowerCase().startsWith('adm') &&
            !skipExact.contains(candidate.toLowerCase())) {
          if (current != null && current.hasMinimumData) records.add(current);
          current = _PdfStudentRecord(
            index: int.parse(simpleHeader.group(1)!),
            name: candidate,
          );
        }
      }
    }

    if (current != null && current.hasMinimumData) records.add(current);
    return records.map((r) => r.toImportRow()).toList();
  }

  bool _isPdfLabel(String label) {
    const known = {
      'adm no', 'admission no', 'admission number', 'student id',
      "father's name", 'father name', "mother's name", 'mother name',
      'mobile', 'alt mobile', 'alternate mobile', 'gender',
      'date of birth', 'dob', 'address', 'student type',
      'class course', 'class/course', 'section batch', 'section/batch',
      'roll no', 'roll number', 'admission date', 'session',
      'total fees', 'paid fees', 'remaining', 'remaining fees',
      'fee status', 'last paid', 'last payment date', 'payment mode',
      'total days', 'present', 'absent', 'leave', 'attendance',
    };
    return known.any((k) => label.contains(k) || k.contains(label));
  }

  String _normalizePdfLabel(String raw) {
    return raw
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('/', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<StudentImportRow> _parsePdfTableFormat(String text) {
    final rows = <StudentImportRow>[];
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    // Try to detect tabular data: look for lines that have 3+ tab-separated or pipe-separated fields
    final tableRows = <List<String>>[];
    List<String>? headers;

    for (final line in lines) {
      if (line.startsWith('---PAGE_BREAK---')) continue;
      List<String> cells = [];
      if (line.contains('\t')) {
        cells = line.split('\t').map((c) => c.trim()).toList();
      } else if (line.contains('|')) {
        cells = line.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
      } else {
        continue;
      }
      if (cells.length < 3) continue;

      if (headers == null) {
        // Detect header row
        final firstCell = cells[0].toLowerCase();
        if (firstCell.contains('name') || firstCell.contains('adm') ||
            firstCell.contains('student') || firstCell.contains('no')) {
          headers = cells.map((h) => h.toLowerCase()).toList();
        }
        continue;
      }
      tableRows.add(cells);
    }

    if (headers != null && tableRows.isNotEmpty) {
      // Map headers
      int _idx(String key) {
        final variants = key.toLowerCase().split('|');
        for (int i = 0; i < headers!.length; i++) {
          for (final v in variants) {
            if (headers[i].contains(v)) return i;
          }
        }
        return -1;
      }

      String? _get(List<String> row, String key) {
        final idx = _idx(key);
        if (idx < 0 || idx >= row.length) return null;
        final v = row[idx].trim();
        return v.isEmpty ? null : v;
      }

      for (int i = 0; i < tableRows.length; i++) {
        final row = tableRows[i];
        final name = _get(row, 'name|student') ?? '';
        final admNo = _get(row, 'adm|admission') ?? '';
        final mobile = _get(row, 'mobile|phone') ?? '';

        if (name.isEmpty && admNo.isEmpty) continue;

        String? error;
        if (name.isEmpty) error = 'Student name not found';
        else if (admNo.isEmpty) error = 'Admission number not found';

        rows.add(StudentImportRow(
          rowIndex: i + 1,
          admissionNumber: admNo,
          studentId: _get(row, 'id|studentid') ?? admNo,
          name: name,
          fatherName: _get(row, 'father') ?? '',
          motherName: _get(row, 'mother'),
          mobile: mobile,
          gender: _get(row, 'gender'),
          dob: _get(row, 'dob|birth|born'),
          address: _get(row, 'address'),
          className: _get(row, 'class'),
          section: _get(row, 'section'),
          rollNumber: _get(row, 'roll'),
          course: _get(row, 'course'),
          status: _get(row, 'status'),
          session: _get(row, 'session'),
          admissionDate: _get(row, 'admission date'),
          studentType: _get(row, 'type'),
          totalFees: double.tryParse((_get(row, 'total fee') ?? '').replaceAll(RegExp(r'[₹,\s]'), '')),
          paidFees: double.tryParse((_get(row, 'paid fee') ?? '').replaceAll(RegExp(r'[₹,\s]'), '')),
          isValid: error == null,
          validationError: error,
        ));
      }
    }

    return rows;
  }

  List<PdfFieldMapping> _detectPdfMappings(String text) {
    final common = {
      'student name': 'Student Name',
      'name': 'Student Name',
      'adm no': 'Admission Number',
      'admission no': 'Admission Number',
      'admission number': 'Admission Number',
      'student id': 'Student ID',
      'id': 'Student ID',
      "father's name": "Father's Name",
      'father name': "Father's Name",
      'mobile': 'Mobile',
      'phone': 'Mobile',
      'class': 'Class',
      'section': 'Section',
      'roll no': 'Roll Number',
      'roll number': 'Roll Number',
      'dob': 'Date of Birth',
      'date of birth': 'Date of Birth',
      'address': 'Address',
      'gender': 'Gender',
      'status': 'Status',
      'course': 'Course',
      'session': 'Academic Session',
      'due': 'Remaining Fees',
      'remaining': 'Remaining Fees',
      'total fee': 'Total Fees',
      'paid fee': 'Paid Fees',
    };

    final detected = <PdfFieldMapping>[];
    final lines = text.toLowerCase().split('\n');
    final seenTargets = <String>{};

    for (final line in lines) {
      for (final entry in common.entries) {
        if (line.contains(entry.key) && !seenTargets.contains(entry.value)) {
          detected.add(PdfFieldMapping(pdfField: entry.key, targetField: entry.value));
          seenTargets.add(entry.value);
        }
      }
      if (detected.length >= 12) break;
    }

    return detected;
  }

  // ─── Batch Import ─────────────────────────────────────────────────────────

  Future<ImportSummary> importRows(
      List<StudentImportRow> rows, {
        ImportDuplicateAction globalAction = ImportDuplicateAction.skip,
        void Function(int current, int total)? onProgress,
      }) async {
    int imported = 0, skipped = 0, updated = 0, failed = 0;
    final errors = <ImportError>[];
    const uuid = Uuid();
    const batchSize = 50;

    final toProcess = rows.where((r) => r.isValid).toList();

    for (int i = 0; i < toProcess.length; i += batchSize) {
      final batch = toProcess.skip(i).take(batchSize);
      for (final row in batch) {
        try {
          final action = row.isDuplicate ? globalAction : ImportDuplicateAction.update;

          if (row.isDuplicate && action == ImportDuplicateAction.skip) {
            skipped++;
            continue;
          }

          final parsedDob = _parseDate(row.dob) ?? DateTime(2000, 1, 1);
          final parsedAdmDate = _parseDate(row.admissionDate) ?? DateTime.now();
          final type = (row.studentType?.toLowerCase().trim() ?? 'school');
          final studentType = (type == 'computer') ? 'computer' : 'school';

          if (row.isDuplicate && action == ImportDuplicateAction.update) {
            final db = await DatabaseService.instance.database;
            final existing = await db.query('students',
                where: 'admissionNumber = ?', whereArgs: [row.admissionNumber]);
            if (existing.isNotEmpty) {
              final existingId = existing.first['id'] as String;
              final updatedModel = StudentModel(
                id: existingId,
                admissionNumber: row.admissionNumber,
                studentId: row.studentId.isNotEmpty ? row.studentId : row.admissionNumber,
                name: row.name,
                fatherName: row.fatherName,
                motherName: row.motherName,
                mobile: row.mobile,
                alternateMobile: row.alternateMobile,
                dob: parsedDob,
                gender: row.gender ?? 'Male',
                address: row.address ?? '',
                studentType: studentType,
                className: studentType == 'school' ? row.className : null,
                section: studentType == 'school' ? row.section : null,
                rollNumber: studentType == 'school' ? row.rollNumber : null,
                course: studentType == 'computer' ? row.course : null,
                batch: studentType == 'computer' ? row.batch : null,
                status: row.status ?? 'active',
                session: row.session,
                admissionDate: parsedAdmDate,
                createdAt: DateTime.now(),
              );
              await DatabaseService.instance.updateStudent(updatedModel);
              if (row.totalFees != null || row.paidFees != null) {
                await DatabaseService.instance.setFeeFromImport(
                  existingId,
                  totalFees: row.totalFees,
                  paidFees: row.paidFees,
                  lastPaymentDate: _parseDate(row.lastPaymentDate),
                  paymentMode: row.paymentMode,
                );
              }
              await _importFeeParticularsIfAny(existingId, row);
              final attendance = _resolveAttendance(row);
              if (attendance != null) {
                await DatabaseService.instance.importAttendanceSummary(
                  existingId,
                  total: attendance.total,
                  present: attendance.present,
                  absent: attendance.absent,
                  leave: attendance.leave,
                );
              }
              updated++;
            } else {
              skipped++;
            }
          } else {
            final newId = uuid.v4();
            final studentId = row.studentId.isNotEmpty ? row.studentId : row.admissionNumber;
            final student = StudentModel(
              id: newId,
              admissionNumber: row.admissionNumber,
              studentId: studentId,
              name: row.name,
              fatherName: row.fatherName,
              motherName: row.motherName,
              mobile: row.mobile,
              alternateMobile: row.alternateMobile,
              dob: parsedDob,
              gender: row.gender ?? 'Male',
              address: row.address ?? '',
              studentType: studentType,
              className: studentType == 'school' ? row.className : null,
              section: studentType == 'school' ? row.section : null,
              rollNumber: studentType == 'school' ? row.rollNumber : null,
              course: studentType == 'computer' ? row.course : null,
              batch: studentType == 'computer' ? row.batch : null,
              status: row.status ?? 'active',
              session: row.session,
              admissionDate: parsedAdmDate,
              createdAt: DateTime.now(),
            );
            await DatabaseService.instance.insertStudent(student);
            if (row.totalFees != null || row.paidFees != null) {
              await DatabaseService.instance.setFeeFromImport(
                newId,
                totalFees: row.totalFees,
                paidFees: row.paidFees,
                lastPaymentDate: _parseDate(row.lastPaymentDate),
                paymentMode: row.paymentMode,
              );
            }
            await _importFeeParticularsIfAny(newId, row);
            final attendance = _resolveAttendance(row);
            if (attendance != null) {
              await DatabaseService.instance.importAttendanceSummary(
                newId,
                total: attendance.total,
                present: attendance.present,
                absent: attendance.absent,
                leave: attendance.leave,
              );
            }
            imported++;
          }
        } catch (e) {
          failed++;
          errors.add(ImportError(
            rowNumber: row.rowIndex,
            studentName: row.name,
            admissionNumber: row.admissionNumber,
            reason: e.toString(),
          ));
        }
      }
      onProgress?.call(
        i + batchSize < toProcess.length ? i + batchSize : toProcess.length,
        toProcess.length,
      );
      await Future.delayed(const Duration(milliseconds: 10));
    }

    // The import writes to SQLite first. Push the resulting complete local
    // dataset to the currently authenticated Firebase UID so imported fees,
    // payment/receipt history and attendance are available on every device.
    try {
      await FirestoreService.instance.syncAllLocalData();
    } catch (e) {
      developer.log('Firestore import sync failed', name: 'ImportService', error: e);
      // Do not mark an otherwise successful local import as failed just
      // because cloud sync is temporarily unavailable.
    }

    return ImportSummary(
      imported: imported,
      skipped: skipped,
      updated: updated,
      failed: failed,
      errors: errors,
    );
  }

  Future<void> downloadErrorReport(List<ImportError> errors) async {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Import Errors');
    final sheet = excel['Import Errors'];

    sheet.appendRow([
      TextCellValue('Row Number'),
      TextCellValue('Student Name'),
      TextCellValue('Admission Number'),
      TextCellValue('Error Reason'),
    ]);

    for (final e in errors) {
      sheet.appendRow([
        IntCellValue(e.rowNumber),
        TextCellValue(e.studentName),
        TextCellValue(e.admissionNumber),
        TextCellValue(e.reason),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) return;
    final ts = DateTime.now().toIso8601String().substring(0, 16).replaceAll(':', '-');
    await FileSaver.saveToDownloads(bytes, 'import_errors_$ts.xlsx');
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return parseExcelDate(raw);
  }

  /// Resolves the attendance summary to import for a row, handling the case
  /// where "Total Days" wasn't provided but Present/Absent/Leave were —
  /// previously this silently dropped the whole row (imported as 0/0/0/0).
  /// Returns null when there's nothing usable to import.
  ({int total, int present, int absent, int leave})? _resolveAttendance(
      StudentImportRow row) {
    final hasAnyCount = row.totalAttendanceDays != null ||
        row.presentDays != null ||
        row.absentDays != null ||
        row.leaveDays != null;
    if (!hasAnyCount) return null;

    final present = row.presentDays ?? 0;
    final absent = row.absentDays ?? 0;
    final leave = row.leaveDays ?? 0;

    final total = (row.totalAttendanceDays != null && row.totalAttendanceDays! > 0)
        ? row.totalAttendanceDays!
        : (present + absent + leave);

    if (total <= 0) return null;
    return (total: total, present: present, absent: absent, leave: leave);
  }

  /// Month key (YYYY-MM) for the monthly fee ledger this row's particulars
  /// should land in. Falls back to the current month when no parseable due
  /// date is given (the import template has no separate "Month" column).
  String _resolveFeeMonth(StudentImportRow row) {
    final due = _parseDate(row.dueDate);
    final anchor = due ?? DateTime.now();
    return '${anchor.year}-${anchor.month.toString().padLeft(2, '0')}';
  }

  Future<void> _importFeeParticularsIfAny(String studentId, StudentImportRow row) async {
    final hasAny = [
      row.admissionFee, row.tuitionFee, row.monthlyFee, row.examinationFee,
      row.gameFee, row.reAdmissionFee, row.developmentFee, row.schoolIdFee,
      row.tieBagBeltFee, row.backDues, row.transportFee, row.otherFee,
    ].any((v) => v != null) || row.paidFees != null;
    if (!hasAny) return;

    await DatabaseService.instance.importMonthlyFeeParticulars(
      studentId,
      month: _resolveFeeMonth(row),
      admissionFee: row.admissionFee,
      tuitionFee: row.tuitionFee ?? row.monthlyFee,
      examinationFee: row.examinationFee,
      gameFee: row.gameFee,
      reAdmissionFee: row.reAdmissionFee,
      developmentFee: row.developmentFee,
      schoolIdFee: row.schoolIdFee,
      tieBagBeltFee: row.tieBagBeltFee,
      backDues: row.backDues,
      transportFee: row.transportFee,
      otherFee: row.otherFee,
      paidAmount: row.paidFees,
      dueDate: _parseDate(row.dueDate),
    );
  }
}

double? _parsePdfCurrencyStatic(String? raw) {
  if (raw == null || raw.isEmpty || raw == '—' || raw == '-') return null;
  final cleaned = raw
      .replaceAll(RegExp(r'[₹Rs.INR\u20B9\s]', caseSensitive: false), '')
      .replaceAll(',', '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

class _PdfStudentRecord {
  final int index;
  String? name;
  String? status;
  String admissionNumber = '';
  String studentId = '';
  String fatherName = '';
  String? motherName;
  String mobile = '';
  String? alternateMobile;
  String? gender;
  String? dob;
  String? address;
  String? studentType;
  String? className;
  String? section;
  String? rollNumber;
  String? admissionDate;
  String? session;
  String? feeStatus;
  double? totalFees;
  double? paidFees;

  _PdfStudentRecord({required this.index, this.name, this.status});

  bool get hasMinimumData =>
      (name != null && name!.isNotEmpty) || admissionNumber.isNotEmpty;

  void setField(String label, String value) {
    if (value == '—' || value == '-') value = '';

    switch (label) {
      case 'adm no':
      case 'admission no':
      case 'admission number':
        admissionNumber = value;
      case 'student id':
        studentId = value;
      case "father's name":
      case 'father name':
        fatherName = value;
      case "mother's name":
      case 'mother name':
        motherName = value.isEmpty ? null : value;
      case 'mobile':
        mobile = value;
      case 'alt mobile':
      case 'alternate mobile':
        alternateMobile = value.isEmpty ? null : value;
      case 'gender':
        gender = value.isEmpty ? null : value;
      case 'date of birth':
      case 'dob':
        dob = value.isEmpty ? null : value;
      case 'address':
        address = value.isEmpty ? null : value;
      case 'student type':
        studentType = value.isEmpty ? null : value;
      case 'class course':
      case 'class/course':
        className = value.isEmpty ? null : value;
      case 'section batch':
      case 'section/batch':
        section = value.isEmpty ? null : value;
      case 'roll no':
      case 'roll number':
        rollNumber = value.isEmpty ? null : value;
      case 'admission date':
        admissionDate = value.isEmpty ? null : value;
      case 'session':
        session = value.isEmpty ? null : value;
      case 'total fees':
        totalFees = _parsePdfCurrencyStatic(value);
      case 'paid fees':
        paidFees = _parsePdfCurrencyStatic(value);
      case 'remaining':
      case 'remaining fees':
        break;
      case 'fee status':
        feeStatus = value.isEmpty ? null : value;
      case 'last paid':
      case 'last payment date':
        break;
      case 'payment mode':
        break;
      case 'total days':
      case 'present':
      case 'absent':
      case 'leave':
      case 'attendance':
        break;
    }
  }

  StudentImportRow toImportRow() {
    final displayName = name ?? 'Student $index';
    String? validationError;
    if (admissionNumber.isEmpty) {
      validationError = 'Admission Number is required';
    } else if (displayName.isEmpty) {
      validationError = 'Student Name is required';
    }

    final typeRaw = (studentType ?? 'school').toLowerCase();
    final isComputer = typeRaw.contains('computer');

    return StudentImportRow(
      rowIndex: index,
      admissionNumber: admissionNumber,
      studentId: studentId.isNotEmpty ? studentId : admissionNumber,
      name: displayName,
      fatherName: fatherName,
      motherName: motherName,
      mobile: mobile,
      alternateMobile: alternateMobile,
      gender: gender,
      dob: dob,
      address: address,
      studentType: isComputer ? 'computer' : 'school',
      className: isComputer ? null : className,
      section: isComputer ? null : section,
      rollNumber: rollNumber,
      course: isComputer ? className : null,
      batch: isComputer ? section : null,
      admissionDate: admissionDate,
      session: session,
      status: status?.toLowerCase(),
      totalFees: totalFees,
      paidFees: paidFees,
      feeStatus: feeStatus,
      isValid: validationError == null,
      validationError: validationError,
    );
  }
}