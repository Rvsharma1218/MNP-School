import 'package:cloud_firestore/cloud_firestore.dart';

class StudentModel {
  final String id;
  final String admissionNumber;
  final String studentId;
  final String name;
  final String fatherName;
  final String? motherName;
  final String mobile;
  final String? alternateMobile;
  final String? email; // optional
  final DateTime dob;
  final String gender;
  final String address;
  final String? photoPath;
  final String? aadhaarNumber; // Document ID / Aadhaar Number
  final String? aadhaarDocPath; // Aadhaar card photo / document image
  final String studentType; // 'school' | 'computer'

  // School fields
  final String? className;
  final String? section;
  final String? rollNumber;

  // Computer fields
  final String? course;
  final String? batch;
  final int? courseDurationMonths; // e.g. 6, 12
  final DateTime? expectedCompletionDate;

  // Status & Session
  final String status; // 'active' | 'completed' | 'left' | 'suspended'
  final String? session; // e.g. '2026-27'
  final DateTime admissionDate;
  final DateTime createdAt;

  // Optional fee metadata embedded by web/cloud
  final double? initialTotalFees;
  final double? initialPaidFees;
  final double? monthlyFee;
  final double? remainingFees;
  final double? totalPending;
  final double? previousDue;
  final String? feeStatus;
  final Map<String, dynamic>? feeStructure;
  final Map<String, dynamic>? monthlyParticulars;

  StudentModel({
    required this.id,
    required this.admissionNumber,
    required this.studentId,
    required this.name,
    required this.fatherName,
    this.motherName,
    required this.mobile,
    this.alternateMobile,
    this.email,
    required this.dob,
    required this.gender,
    required this.address,
    this.photoPath,
    this.aadhaarNumber,
    this.aadhaarDocPath,
    required this.studentType,
    this.className,
    this.section,
    this.rollNumber,
    this.course,
    this.batch,
    this.courseDurationMonths,
    this.expectedCompletionDate,
    this.status = 'active',
    this.session,
    required this.admissionDate,
    required this.createdAt,
    this.initialTotalFees,
    this.initialPaidFees,
    this.monthlyFee,
    this.remainingFees,
    this.totalPending,
    this.previousDue,
    this.feeStatus,
    this.feeStructure,
    this.monthlyParticulars,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'admissionNumber': admissionNumber,
      'studentId': studentId,
      'name': name,
      'fatherName': fatherName,
      'motherName': motherName,
      'mobile': mobile,
      'alternateMobile': alternateMobile,
      'email': email,
      'dob': dob.toIso8601String(),
      'gender': gender,
      'address': address,
      'photoPath': photoPath,
      'aadhaarNumber': aadhaarNumber,
      'aadhaarDocPath': aadhaarDocPath,
      'aadhaarDocUrl': aadhaarDocPath,
      'aadhaarCardUrl': aadhaarDocPath,
      'studentType': studentType,
      'className': className,
      'section': section,
      'rollNumber': rollNumber,
      'course': course,
      'batch': batch,
      'courseDurationMonths': courseDurationMonths,
      'expectedCompletionDate': expectedCompletionDate?.toIso8601String(),
      'status': status,
      'session': session,
      'admissionDate': admissionDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      if (monthlyFee != null) 'monthlyFee': monthlyFee,
      if (initialTotalFees != null) 'totalFees': initialTotalFees,
      if (initialPaidFees != null) 'paidFees': initialPaidFees,
      if (remainingFees != null) 'remainingFees': remainingFees,
      if (totalPending != null) 'totalPending': totalPending,
      if (previousDue != null) 'previousDue': previousDue,
      if (feeStatus != null) 'feeStatus': feeStatus,
    };
  }

  /// Explicit SQLite table mapping containing ONLY valid students table columns
  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'admissionNumber': admissionNumber,
      'studentId': studentId,
      'name': name,
      'fatherName': fatherName,
      if (motherName != null) 'motherName': motherName,
      'mobile': mobile,
      if (alternateMobile != null) 'alternateMobile': alternateMobile,
      if (email != null) 'email': email,
      'dob': dob.toIso8601String(),
      'gender': gender,
      'address': address,
      if (photoPath != null) 'photoPath': photoPath,
      if (aadhaarNumber != null) 'aadhaarNumber': aadhaarNumber,
      if (aadhaarDocPath != null) 'aadhaarDocPath': aadhaarDocPath,
      if (aadhaarDocPath != null) 'aadhaarDocUrl': aadhaarDocPath,
      if (aadhaarDocPath != null) 'aadhaarCardUrl': aadhaarDocPath,
      'studentType': studentType,
      if (className != null) 'className': className,
      if (section != null) 'section': section,
      if (rollNumber != null) 'rollNumber': rollNumber,
      if (course != null) 'course': course,
      if (batch != null) 'batch': batch,
      if (courseDurationMonths != null) 'courseDurationMonths': courseDurationMonths,
      if (expectedCompletionDate != null) 'expectedCompletionDate': expectedCompletionDate!.toIso8601String(),
      'status': status,
      if (session != null) 'session': session,
      'admissionDate': admissionDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      if (monthlyFee != null) 'monthlyFee': monthlyFee,
      if (initialTotalFees != null) 'totalFees': initialTotalFees,
      if (initialPaidFees != null) 'paidFees': initialPaidFees,
      if (remainingFees != null) 'remainingFees': remainingFees,
      if (totalPending != null) 'totalPending': totalPending,
      if (previousDue != null) 'previousDue': previousDue,
      if (feeStatus != null) 'feeStatus': feeStatus,
    };
  }

  Map<String, dynamic> toFirestoreMap() {
    final map = toMap();
    map['admissionNo'] = admissionNumber;
    map['admissionNumber'] = admissionNumber;
    map['photoUrl'] = photoPath ?? '';
    map['photoPath'] = photoPath ?? '';
    map['aadhaarNumber'] = aadhaarNumber ?? '';
    map['aadharNumber'] = aadhaarNumber ?? '';
    map['aadhaarDocPath'] = aadhaarDocPath ?? '';
    map['aadhaarDocUrl'] = aadhaarDocPath ?? '';
    map['aadhaarCardUrl'] = aadhaarDocPath ?? '';
    if (feeStructure != null) map['feeStructure'] = feeStructure;
    if (monthlyParticulars != null) map['monthlyParticulars'] = monthlyParticulars;
    return map;
  }

  static DateTime _parseDate(dynamic val, DateTime fallback) {
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String && val.isNotEmpty) {
      return DateTime.tryParse(val) ?? fallback;
    }
    return fallback;
  }

  static double? _safeDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString().trim());
  }

  factory StudentModel.fromMap(Map<String, dynamic> map) {
    final rawPhoto = map['photoPath']?.toString() ?? map['photoUrl']?.toString();
    final resolvedPhoto = (rawPhoto == null || rawPhoto.trim().isEmpty) ? null : rawPhoto.trim();
    final rawAadhaar = map['aadhaarNumber']?.toString() ?? map['aadharNumber']?.toString();
    final resolvedAadhaar = (rawAadhaar == null || rawAadhaar.trim().isEmpty) ? null : rawAadhaar.trim();
    final rawAadhaarDoc = map['aadhaarDocPath']?.toString() ?? map['aadhaarDocUrl']?.toString() ?? map['aadhaarCardUrl']?.toString();
    final resolvedAadhaarDoc = (rawAadhaarDoc == null || rawAadhaarDoc.trim().isEmpty) ? null : rawAadhaarDoc.trim();

    final resolvedFeeStructure = <String, dynamic>{};
    if (map['feeStructure'] is Map) {
      resolvedFeeStructure.addAll(Map<String, dynamic>.from(map['feeStructure'] as Map));
    }
    for (final entry in map.entries) {
      if (entry.key.startsWith('feeStructure.')) {
        final subKey = entry.key.substring('feeStructure.'.length);
        resolvedFeeStructure[subKey] = entry.value;
      }
    }

    final resolvedMonthlyParticulars = <String, dynamic>{};
    if (map['monthlyParticulars'] is Map) {
      resolvedMonthlyParticulars.addAll(Map<String, dynamic>.from(map['monthlyParticulars'] as Map));
    }
    for (final entry in map.entries) {
      if (entry.key.startsWith('monthlyParticulars.')) {
        final mKey = entry.key.substring('monthlyParticulars.'.length);
        if (entry.value is Map) {
          resolvedMonthlyParticulars[mKey] = Map<String, dynamic>.from(entry.value as Map);
        }
      }
    }

    final resolvedMonthlyFee = _safeDouble(map['monthlyFee']) ??
        _safeDouble(resolvedFeeStructure['tuitionFee']) ??
        _safeDouble(map['feeStructure.tuitionFee']);

    return StudentModel(
      id: map['id']?.toString() ?? '',
      admissionNumber: map['admissionNumber']?.toString() ?? map['admissionNo']?.toString() ?? '',
      studentId: map['studentId']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      fatherName: map['fatherName']?.toString() ?? '',
      motherName: map['motherName']?.toString(),
      mobile: map['mobile']?.toString() ?? '',
      alternateMobile: map['alternateMobile']?.toString(),
      email: map['email']?.toString(),
      dob: _parseDate(map['dob'], DateTime(2015, 1, 1)),
      gender: map['gender']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      photoPath: resolvedPhoto,
      aadhaarNumber: resolvedAadhaar,
      aadhaarDocPath: resolvedAadhaarDoc,
      studentType: map['studentType']?.toString() ?? 'school',
      className: map['className']?.toString(),
      section: map['section']?.toString(),
      rollNumber: map['rollNumber']?.toString(),
      course: map['course']?.toString(),
      batch: map['batch']?.toString(),
      courseDurationMonths: (map['courseDurationMonths'] as num?)?.toInt(),
      expectedCompletionDate: map['expectedCompletionDate'] != null
          ? _parseDate(map['expectedCompletionDate'], DateTime.now())
          : null,
      status: map['status']?.toString() ?? 'active',
      session: map['session']?.toString(),
      admissionDate: _parseDate(map['admissionDate'] ?? map['joiningDate'], DateTime.now()),
      createdAt: _parseDate(map['createdAt'], DateTime.now()),
      initialTotalFees: _safeDouble(map['totalFees'] ?? map['totalFee']),
      initialPaidFees: _safeDouble(map['paidFees'] ?? map['totalPaid']),
      monthlyFee: resolvedMonthlyFee,
      remainingFees: _safeDouble(map['remainingFees'] ?? map['totalPending'] ?? map['balanceDue']),
      totalPending: _safeDouble(map['totalPending'] ?? map['remainingFees'] ?? map['balanceDue']),
      previousDue: _safeDouble(map['previousDue'] ?? map['previousDues']),
      feeStatus: map['feeStatus']?.toString(),
      feeStructure: resolvedFeeStructure.isNotEmpty ? resolvedFeeStructure : null,
      monthlyParticulars: resolvedMonthlyParticulars.isNotEmpty ? resolvedMonthlyParticulars : null,
    );
  }

  StudentModel copyWith({
    String? id,
    String? admissionNumber,
    String? studentId,
    String? name,
    String? fatherName,
    String? motherName,
    String? mobile,
    String? alternateMobile,
    String? email,
    DateTime? dob,
    String? gender,
    String? address,
    String? photoPath,
    bool clearPhoto = false,
    String? aadhaarNumber,
    String? aadhaarDocPath,
    bool clearAadhaarDoc = false,
    String? studentType,
    String? className,
    String? section,
    String? rollNumber,
    String? course,
    String? batch,
    int? courseDurationMonths,
    DateTime? expectedCompletionDate,
    String? status,
    String? session,
    DateTime? admissionDate,
    DateTime? createdAt,
    double? initialTotalFees,
    double? initialPaidFees,
    double? monthlyFee,
    double? remainingFees,
    double? totalPending,
    double? previousDue,
    String? feeStatus,
    Map<String, dynamic>? feeStructure,
    Map<String, dynamic>? monthlyParticulars,
  }) {
    return StudentModel(
      id: id ?? this.id,
      admissionNumber: admissionNumber ?? this.admissionNumber,
      studentId: studentId ?? this.studentId,
      name: name ?? this.name,
      fatherName: fatherName ?? this.fatherName,
      motherName: motherName ?? this.motherName,
      mobile: mobile ?? this.mobile,
      alternateMobile: alternateMobile ?? this.alternateMobile,
      email: email ?? this.email,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      aadhaarDocPath: clearAadhaarDoc ? null : (aadhaarDocPath ?? this.aadhaarDocPath),
      studentType: studentType ?? this.studentType,
      className: className ?? this.className,
      section: section ?? this.section,
      rollNumber: rollNumber ?? this.rollNumber,
      course: course ?? this.course,
      batch: batch ?? this.batch,
      courseDurationMonths: courseDurationMonths ?? this.courseDurationMonths,
      expectedCompletionDate: expectedCompletionDate ?? this.expectedCompletionDate,
      status: status ?? this.status,
      session: session ?? this.session,
      admissionDate: admissionDate ?? this.admissionDate,
      createdAt: createdAt ?? this.createdAt,
      initialTotalFees: initialTotalFees ?? this.initialTotalFees,
      initialPaidFees: initialPaidFees ?? this.initialPaidFees,
      monthlyFee: monthlyFee ?? this.monthlyFee,
      remainingFees: remainingFees ?? this.remainingFees,
      totalPending: totalPending ?? this.totalPending,
      previousDue: previousDue ?? this.previousDue,
      feeStatus: feeStatus ?? this.feeStatus,
      feeStructure: feeStructure ?? this.feeStructure,
      monthlyParticulars: monthlyParticulars ?? this.monthlyParticulars,
    );
  }

  String get displayClass {
    if (studentType == 'school') {
      final cls = className ?? '';
      final sec = section ?? '';
      if (cls.isEmpty) return 'School Student';
      return 'Class $cls${sec.isNotEmpty ? ' - $sec' : ''}';
    }
    return course ?? 'Computer Student';
  }

  String get statusLabel {
    switch (status) {
      case 'completed': return 'Completed';
      case 'left': return 'Left';
      case 'suspended': return 'Suspended';
      default: return 'Active';
    }
  }

  // Status color helper
  static const statusColors = {
    'active': 0xFF2E7D32,     // green
    'completed': 0xFF1565C0,  // blue
    'left': 0xFFF57F17,       // orange
    'suspended': 0xFFC62828,  // red
  };

  double get totalFees => initialTotalFees ?? 0.0;
  double get paidFees => initialPaidFees ?? 0.0;

  int get statusColor => statusColors[status] ?? statusColors['active']!;
}
