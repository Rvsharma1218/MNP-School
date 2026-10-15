/// Models used by ImportService for Excel and PDF import operations.

// ─── Student Import Row ───────────────────────────────────────────────────────

class StudentImportRow {
  final int rowIndex;
  final String admissionNumber;
  final String studentId;
  final String name;
  final String fatherName;
  final String? motherName;
  final String mobile;
  final String? alternateMobile;
  final String? gender;
  final String? dob; // raw string from file
  final String? address;
  final String? studentType;
  final String? className;
  final String? section;
  final String? rollNumber;
  final String? course;
  final String? batch;
  final String? admissionDate; // raw string
  final String? session;
  final String? status;
  final double? totalFees;
  final double? paidFees;
  final String? feeStatus;
  final String? lastPaymentDate; // raw string from file
  final String? paymentMode;
  final double? admissionFee;
  final double? tuitionFee;
  final double? monthlyFee;
  final double? examinationFee;
  final double? previousDues;
  final double? gameFee;
  final double? reAdmissionFee;
  final double? developmentFee;
  final double? schoolIdFee;
  final double? tieBagBeltFee;
  final double? backDues;
  final double? transportFee;
  final double? otherFee;
  final String? dueDate;

  // Attendance (imported as a historical summary, not per-day records)
  final int? totalAttendanceDays;
  final int? presentDays;
  final int? absentDays;
  final int? leaveDays;
  final double? attendancePercentage;

  // Validation
  final bool isValid;
  final bool isDuplicate;
  final String? validationError;
  final ImportDuplicateAction duplicateAction;

  StudentImportRow({
    required this.rowIndex,
    required this.admissionNumber,
    required this.studentId,
    required this.name,
    required this.fatherName,
    this.motherName,
    required this.mobile,
    this.alternateMobile,
    this.gender,
    this.dob,
    this.address,
    this.studentType,
    this.className,
    this.section,
    this.rollNumber,
    this.course,
    this.batch,
    this.admissionDate,
    this.session,
    this.status,
    this.totalFees,
    this.paidFees,
    this.feeStatus,
    this.lastPaymentDate,
    this.paymentMode,
    this.admissionFee,
    this.tuitionFee,
    this.monthlyFee,
    this.examinationFee,
    this.previousDues,
    this.gameFee,
    this.reAdmissionFee,
    this.developmentFee,
    this.schoolIdFee,
    this.tieBagBeltFee,
    this.backDues,
    this.transportFee,
    this.otherFee,
    this.dueDate,
    this.totalAttendanceDays,
    this.presentDays,
    this.absentDays,
    this.leaveDays,
    this.attendancePercentage,
    this.isValid = true,
    this.isDuplicate = false,
    this.validationError,
    this.duplicateAction = ImportDuplicateAction.skip,
  });

  StudentImportRow copyWith({
    bool? isValid,
    bool? isDuplicate,
    String? validationError,
    ImportDuplicateAction? duplicateAction,
  }) {
    return StudentImportRow(
      rowIndex: rowIndex,
      admissionNumber: admissionNumber,
      studentId: studentId,
      name: name,
      fatherName: fatherName,
      motherName: motherName,
      mobile: mobile,
      alternateMobile: alternateMobile,
      gender: gender,
      dob: dob,
      address: address,
      studentType: studentType,
      className: className,
      section: section,
      rollNumber: rollNumber,
      course: course,
      batch: batch,
      admissionDate: admissionDate,
      session: session,
      status: status,
      totalFees: totalFees,
      paidFees: paidFees,
      feeStatus: feeStatus,
      lastPaymentDate: lastPaymentDate,
      paymentMode: paymentMode,
      totalAttendanceDays: totalAttendanceDays,
      presentDays: presentDays,
      absentDays: absentDays,
      leaveDays: leaveDays,
      attendancePercentage: attendancePercentage,
      isValid: isValid ?? this.isValid,
      isDuplicate: isDuplicate ?? this.isDuplicate,
      validationError: validationError ?? this.validationError,
      duplicateAction: duplicateAction ?? this.duplicateAction,
    );
  }
}

// ─── Import Actions ───────────────────────────────────────────────────────────

enum ImportDuplicateAction { skip, update }

// ─── Import Result ────────────────────────────────────────────────────────────

class ImportResult {
  final int totalRows;
  final List<StudentImportRow> rows;
  final bool hasAttendanceColumns;
  final int attendanceFoundCount;

  ImportResult({
    required this.totalRows,
    required this.rows,
    this.hasAttendanceColumns = false,
    this.attendanceFoundCount = 0,
  });

  int get validCount => rows.where((r) => r.isValid && !r.isDuplicate).length;
  int get duplicateCount => rows.where((r) => r.isDuplicate).length;
  int get invalidCount => rows.where((r) => !r.isValid).length;
}

// ─── Import Error ─────────────────────────────────────────────────────────────

class ImportError {
  final int rowNumber;
  final String studentName;
  final String admissionNumber;
  final String reason;

  ImportError({
    required this.rowNumber,
    required this.studentName,
    required this.admissionNumber,
    required this.reason,
  });
}

// ─── Import Summary ───────────────────────────────────────────────────────────

class ImportSummary {
  final int imported;
  final int skipped;
  final int updated;
  final int failed;
  final List<ImportError> errors;

  ImportSummary({
    required this.imported,
    required this.skipped,
    required this.updated,
    required this.failed,
    required this.errors,
  });
}

// ─── PDF Import Models ────────────────────────────────────────────────────────

class PdfFieldMapping {
  final String pdfField;   // field name detected in PDF
  String targetField;      // mapped target field in StudentImportRow

  PdfFieldMapping({required this.pdfField, required this.targetField});
}

class PdfImportResult {
  final int pages;
  final int detectedRecords;
  final List<StudentImportRow> rows;
  final List<PdfFieldMapping> mappings;
  final bool hasUnrecognizedData;
  final String? warningMessage;

  PdfImportResult({
    required this.pages,
    required this.detectedRecords,
    required this.rows,
    required this.mappings,
    this.hasUnrecognizedData = false,
    this.warningMessage,
  });

  int get validCount => rows.where((r) => r.isValid && !r.isDuplicate).length;
  int get duplicateCount => rows.where((r) => r.isDuplicate).length;
  int get invalidCount => rows.where((r) => !r.isValid).length;
}

// ─── Template Column Config ───────────────────────────────────────────────────

class TemplateColumn {
  final String header;
  final String example1;
  final String example2;
  final bool required;

  const TemplateColumn({
    required this.header,
    required this.example1,
    required this.example2,
    this.required = false,
  });
}

const kTemplateColumns = [
  TemplateColumn(header: 'Admission Number', example1: 'ADM001', example2: 'ADM002', required: true),
  TemplateColumn(header: 'Student ID', example1: 'STU001', example2: 'STU002', required: true),
  TemplateColumn(header: 'Student Name', example1: 'Rahul Sharma', example2: 'Priya Singh', required: true),
  TemplateColumn(header: "Father's Name", example1: 'Rajesh Sharma', example2: 'Suresh Singh', required: true),
  TemplateColumn(header: "Mother's Name", example1: 'Sunita Sharma', example2: 'Kavita Singh'),
  TemplateColumn(header: 'Mobile', example1: '9876543210', example2: '9876543211', required: true),
  TemplateColumn(header: 'Alternate Mobile', example1: '9876543212', example2: ''),
  TemplateColumn(header: 'Gender', example1: 'Male', example2: 'Female'),
  TemplateColumn(header: 'Date of Birth', example1: '01-01-2010', example2: '15-06-2012'),
  TemplateColumn(header: 'Address', example1: 'Village Road, Delhi', example2: 'MG Road, Mumbai', required: true),
  TemplateColumn(header: 'Student Type', example1: 'school', example2: 'computer'),
  TemplateColumn(header: 'Class', example1: '10', example2: ''),
  TemplateColumn(header: 'Section', example1: 'A', example2: ''),
  TemplateColumn(header: 'Roll Number', example1: '15', example2: ''),
  TemplateColumn(header: 'Course', example1: '', example2: 'DCA'),
  TemplateColumn(header: 'Batch', example1: '', example2: '2026-Jan'),
  TemplateColumn(header: 'Admission Date', example1: '01-04-2025', example2: '15-07-2025'),
  TemplateColumn(header: 'Academic Session', example1: '2025-26', example2: '2026-27'),
  TemplateColumn(header: 'Status', example1: 'active', example2: 'active'),
  TemplateColumn(
    header: 'Admission Fee',
    example1: '2500',
    example2: '2000',
  ),

  TemplateColumn(
    header: 'Tuition Fee',
    example1: '3000',
    example2: '3500',
  ),

  TemplateColumn(
    header: 'Monthly Fee',
    example1: '1500',
    example2: '1800',
  ),

  TemplateColumn(
    header: 'Examination Fee',
    example1: '500',
    example2: '500',
  ),

  TemplateColumn(
    header: 'Previous Dues',
    example1: '1000',
    example2: '0',
  ),

  TemplateColumn(
    header: 'Game Fee',
    example1: '300',
    example2: '300',
  ),

  TemplateColumn(
    header: 'Re-Admission Fee',
    example1: '0',
    example2: '0',
  ),

  TemplateColumn(
    header: 'Development Fee',
    example1: '200',
    example2: '200',
  ),

  TemplateColumn(
    header: 'School ID',
    example1: '150',
    example2: '150',
  ),

  TemplateColumn(
    header: 'Tie, Bag, Belt',
    example1: '350',
    example2: '350',
  ),

  TemplateColumn(
    header: 'Back Dues',
    example1: '0',
    example2: '500',
  ),

  TemplateColumn(
    header: 'Transport Fee',
    example1: '800',
    example2: '0',
  ),

  TemplateColumn(
    header: 'Other Fee',
    example1: '100',
    example2: '100',
  ),

  TemplateColumn(
    header: 'Total Fees',
    example1: '10400',
    example2: '9400',
  ),

  TemplateColumn(
    header: 'Paid Fees',
    example1: '5000',
    example2: '4000',
  ),

  TemplateColumn(
    header: 'Fee Status',
    example1: 'Pending',
    example2: 'Pending',
  ),

  TemplateColumn(
    header: 'Due Date',
    example1: '10-08-2026',
    example2: '10-08-2026',
  ),

  TemplateColumn(
    header: 'Payment Mode',
    example1: 'Cash',
    example2: 'UPI',
  ),
  TemplateColumn(header: 'Total Days', example1: '25', example2: '25'),
  TemplateColumn(header: 'Present', example1: '22', example2: '20'),
  TemplateColumn(header: 'Absent', example1: '2', example2: '3'),
  TemplateColumn(header: 'Leave', example1: '1', example2: '2'),
  TemplateColumn(header: 'Attendance %', example1: '88%', example2: '80%'),
];

/// All importable field names for PDF mapping dropdowns
const kImportTargetFields = [
  'Admission Number',
  'Student ID',
  'Student Name',
  "Father's Name",
  "Mother's Name",
  'Mobile',
  'Alternate Mobile',
  'Gender',
  'Date of Birth',
  'Address',
  'Student Type',
  'Class',
  'Section',
  'Roll Number',
  'Course',
  'Batch',
  'Admission Date',
  'Academic Session',
  'Status',
  'Total Fees',
  'Paid Fees',
  'Fee Status',
  'Total Days',
  'Present',
  'Absent',
  'Leave',
  'Attendance %',
  '(Ignore this field)',
];