import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';

/// Central helpers for safely reading Excel cell values during import.

// ─── XLSX Pre-Sanitizer ─────────────────────────────────────────────────────
//
// The `excel` package has a known upstream bug (justkawal/excel issues
// #428 and #433): when a cell references a shared-string index that is
// missing, out of range, or off-by-one (this happens with files exported
// from WPS Office, or Excel files re-saved after "Enable Editing"), the
// package's internal parser does:
//
//   value = TextCellValue.span(sharedString!.textSpan);
//
// ...which throws exactly "Null check operator used on a null value" —
// the crash reported for Complete Excel Import. We can't edit the
// installed package (it gets re-fetched by `flutter pub get`), so instead
// we defensively repair the .xlsx bytes *before* handing them to
// `Excel.decodeBytes`: we pad `xl/sharedStrings.xml` so every referenced
// index resolves to a real (possibly empty) string. If anything about this
// process fails, we silently fall back to the original bytes — the
// existing try/catch + userFriendlyExcelError() below still protects the
// user from a raw crash either way.
Future<Uint8List> sanitizeXlsxBytes(Uint8List bytes) async {
  try {
    final archive = ZipDecoder().decodeBytes(bytes);

    ArchiveFile? sharedStringsFile;
    final sheetFiles = <ArchiveFile>[];
    for (final file in archive.files) {
      if (!file.isFile) continue;
      if (file.name == 'xl/sharedStrings.xml') sharedStringsFile = file;
      if (file.name.startsWith('xl/worksheets/') && file.name.endsWith('.xml')) {
        sheetFiles.add(file);
      }
    }

    // Not a real xlsx, or no shared strings used at all — nothing to fix.
    if (sharedStringsFile == null || sheetFiles.isEmpty) return bytes;

    // Find the highest shared-string index referenced by ANY cell
    // (<c ... t="s"><v>INDEX</v></c>) across all worksheets.
    final cellRefPattern = RegExp(r't="s"[^>]*>\s*<v>\s*(\d+)\s*</v>', dotAll: true);
    int maxIndex = -1;
    for (final sheetFile in sheetFiles) {
      final content = utf8.decode(sheetFile.content as List<int>, allowMalformed: true);
      for (final match in cellRefPattern.allMatches(content)) {
        final idx = int.tryParse(match.group(1) ?? '');
        if (idx != null && idx > maxIndex) maxIndex = idx;
      }
    }
    if (maxIndex < 0) return bytes; // no shared-string cells found

    final sharedXml = utf8.decode(sharedStringsFile.content as List<int>, allowMalformed: true);
    final currentCount = RegExp(r'<si>').allMatches(sharedXml).length;

    // Every referenced index already resolves to a real entry — nothing to fix.
    if (maxIndex < currentCount) return bytes;
    if (!sharedXml.contains('</sst>')) return bytes; // malformed, bail out safely

    final missing = maxIndex - currentCount + 1;
    final padding = List.filled(missing, '<si><t></t></si>').join();

    var fixedXml = sharedXml.replaceFirst('</sst>', '$padding</sst>');
    fixedXml = fixedXml.replaceFirstMapped(
      RegExp(r'count="\d+"'),
          (_) => 'count="${maxIndex + 1}"',
    );
    fixedXml = fixedXml.replaceFirstMapped(
      RegExp(r'uniqueCount="\d+"'),
          (_) => 'uniqueCount="${maxIndex + 1}"',
    );

    final rebuilt = Archive();
    for (final file in archive.files) {
      if (!file.isFile) continue;
      if (file.name == 'xl/sharedStrings.xml') {
        final data = utf8.encode(fixedXml);
        rebuilt.addFile(ArchiveFile('xl/sharedStrings.xml', data.length, data));
      } else {
        rebuilt.addFile(ArchiveFile(file.name, file.size, file.content));
      }
    }

    final encoded = ZipEncoder().encode(rebuilt);
    return encoded != null ? Uint8List.fromList(encoded) : bytes;
  } catch (_) {
    // Sanitization itself failed — fall back to the original bytes.
    // Excel.decodeBytes() will either succeed anyway or throw, and the
    // caller's try/catch + userFriendlyExcelError() handles that safely.
    return bytes;
  }
}

String normalizeExcelHeader(String raw) {
  return raw
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'[^\w\s/]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String readExcelCell(dynamic value) {
  if (value == null) return '';

  if (value is CellValue) {
    return _cellValueToString(value).trim();
  }

  if (value is String) {
    return value.trim();
  }

  return value.toString().trim();
}

String? readNullableExcelCell(dynamic value) {
  final text = readExcelCell(value);
  return text.isEmpty ? null : text;
}

String _cellValueToString(CellValue value) {
  return switch (value) {
    TextCellValue() => value.value.toString(),
    IntCellValue() => value.value.toString(),
    DoubleCellValue() => _formatDouble(value.value),
    BoolCellValue() => value.value ? 'true' : 'false',
    DateCellValue() => _formatDateTime(value.asDateTimeLocal()),
    DateTimeCellValue() => _formatDateTime(value.asDateTimeLocal()),
    TimeCellValue() => value.toString(),
    FormulaCellValue() => value.formula,
  };
}

String _formatDouble(double d) {
  if (d == d.truncateToDouble()) return d.toInt().toString();
  return d.toString();
}

String _formatDateTime(DateTime dt) {
  return '${dt.day.toString().padLeft(2, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.year}';
}

/// Reads a cell from a row by index with bounds checking.
String readExcelRowCell(List<Data?> row, int index) {
  if (index < 0 || index >= row.length) return '';
  final cell = row[index];
  if (cell == null) return '';
  return readExcelCell(cell.value);
}

DateTime? parseExcelDate(dynamic value) {
  if (value == null) return null;

  if (value is DateCellValue) {
    try {
      return value.asDateTimeLocal();
    } catch (_) {
      return null;
    }
  }

  if (value is DateTimeCellValue) {
    try {
      return value.asDateTimeLocal();
    } catch (_) {
      return null;
    }
  }

  // Some spreadsheets (especially script-generated demo files) write dates
  // as a raw Excel serial number (days since 1899-12-30) without a proper
  // date cell format, so the `excel` package hands it to us as a plain
  // Int/DoubleCellValue instead of a DateCellValue. Detect that case before
  // falling through to string parsing.
  if (value is IntCellValue || value is DoubleCellValue) {
    final serial = value is IntCellValue
        ? value.value.toDouble()
        : (value as DoubleCellValue).value;
    // Reasonable bounds: Excel dates roughly between 1950 and 2100.
    if (serial > 18262 && serial < 73050) {
      final epoch = DateTime(1899, 12, 30);
      try {
        return epoch.add(Duration(days: serial.floor()));
      } catch (_) {
        // fall through to text parsing below
      }
    }
  }

  final text = readExcelCell(value);
  if (text.isEmpty) return null;

  final formats = [
    RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$'),
    RegExp(r'^(\d{4})[/-](\d{1,2})[/-](\d{1,2})$'),
  ];

  final m1 = formats[0].firstMatch(text);
  if (m1 != null) {
    return DateTime.tryParse(
      '${m1.group(3)}-${m1.group(2)!.padLeft(2, '0')}-${m1.group(1)!.padLeft(2, '0')}',
    );
  }

  final m2 = formats[1].firstMatch(text);
  if (m2 != null) {
    return DateTime.tryParse(
      '${m2.group(1)}-${m2.group(2)!.padLeft(2, '0')}-${m2.group(3)!.padLeft(2, '0')}',
    );
  }

  return DateTime.tryParse(text);
}

int? parseExcelInt(dynamic value) {
  if (value == null) return null;

  if (value is IntCellValue) return value.value;
  if (value is DoubleCellValue) return value.value.toInt();

  final text = readExcelCell(value).replaceAll(RegExp(r'[^\d-]'), '');
  if (text.isEmpty) return null;
  return int.tryParse(text);
}

double? parseExcelDouble(dynamic value) {
  if (value == null) return null;

  if (value is IntCellValue) return value.value.toDouble();
  if (value is DoubleCellValue) return value.value;

  final text = readExcelCell(value);
  if (text.isEmpty) return null;

  // Strips currency symbols/commas/spaces AND a trailing "%" so that
  // percentage cells like "85%" / "85.5 %" parse as 85.0 / 85.5 instead
  // of failing (they are NOT converted to a 0-1 fraction).
  final cleaned = text.replaceAll(RegExp(r'[₹Rs,\s%]'), '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

/// Finds the header row in sheets that may have section/title rows above headers.
int findExcelHeaderRowIndex(Sheet sheet) {
  final limit = sheet.rows.length < 12 ? sheet.rows.length : 12;

  for (int i = 0; i < limit; i++) {
    final row = sheet.rows[i];
    if (row.isEmpty) continue;

    final headers = <String>[];
    for (int ci = 0; ci < row.length; ci++) {
      headers.add(normalizeExcelHeader(readExcelRowCell(row, ci)));
    }

    final hasAdmission = headers.any((h) =>
    h.contains('admission') || h == 'adm no' || h.startsWith('adm '));
    final hasName = headers.any((h) =>
    h.contains('student name') || h == 'name' || h == 'student');

    if (hasAdmission && hasName) return i;
  }

  return 0;
}

String userFriendlyExcelError(Object error) {
  final message = error.toString();
  if (message.contains('Null check operator') ||
      message.contains('TextSpan') ||
      message.contains('CellValue')) {
    return 'Unable to read this Excel file. Please check that the columns match the import template.';
  }
  if (message.contains('Invalid') || message.contains('corrupt')) {
    return 'This Excel file appears to be corrupted or in an unsupported format.';
  }
  return 'Unable to read this Excel file. Please verify the file format and column headers.';
}