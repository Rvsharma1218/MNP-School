import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentModel {
  final String id;
  final String studentId;
  final String? studentName;
  final String? admissionNumber;
  final String? className;
  final double amount;
  final DateTime paymentDate;
  final String paymentMode;
  final String? remarks;
  final String receiptNumber;
  final String? feeMonth;
  final String? monthKey;
  final int? feeYear;
  final int? feeMonthNum;
  final double? previousDue;
  final double? totalDemand;
  final double? previousPaid;
  final double? totalPaidAfter;
  final double? balanceDue;
  final Map<String, dynamic>? particularsSnapshot;
  final String? receivedBy;
  final String? feeStatus;

  PaymentModel({
    required this.id,
    required this.studentId,
    this.studentName,
    this.admissionNumber,
    this.className,
    required this.amount,
    required this.paymentDate,
    required this.paymentMode,
    this.remarks,
    required this.receiptNumber,
    this.feeMonth,
    this.monthKey,
    this.feeYear,
    this.feeMonthNum,
    this.previousDue,
    this.totalDemand,
    this.previousPaid,
    this.totalPaidAfter,
    this.balanceDue,
    this.particularsSnapshot,
    this.receivedBy,
    this.feeStatus,
  });

  static String toMonthKey(String? feeMonth, [DateTime? date, String? rawDateStr]) {
    if (feeMonth != null && feeMonth.trim().isNotEmpty) {
      final trimmed = feeMonth.trim();
      if (RegExp(r'^\d{4}-\d{2}$').hasMatch(trimmed)) return trimmed;
      if (RegExp(r'^\d{4}-\d{1}$').hasMatch(trimmed)) {
        final parts = trimmed.split('-');
        return '${parts[0]}-${parts[1].padLeft(2, '0')}';
      }
      if (RegExp(r'^\d{2}/\d{4}$').hasMatch(trimmed)) {
        final parts = trimmed.split('/');
        return '${parts[1]}-${parts[0]}';
      }
      if (RegExp(r'^\d{4}/\d{2}$').hasMatch(trimmed)) {
        final parts = trimmed.split('/');
        return '${parts[0]}-${parts[1]}';
      }
      const fullNames = [
        'january', 'february', 'march', 'april', 'may', 'june',
        'july', 'august', 'september', 'october', 'november', 'december'
      ];
      const shortNames = [
        'jan', 'feb', 'mar', 'apr', 'may', 'jun',
        'jul', 'aug', 'sep', 'oct', 'nov', 'dec'
      ];
      final parts = trimmed.split(RegExp(r'[\s\-_/]+'));
      if (parts.length >= 2) {
        final p0 = parts[0].toLowerCase();
        final p1 = parts[1].toLowerCase();
        var nameIdx = fullNames.indexOf(p0);
        if (nameIdx == -1) nameIdx = shortNames.indexOf(p0);
        var yr = int.tryParse(parts[1]);
        if (nameIdx != -1 && yr != null && yr > 2000) {
          return '$yr-${(nameIdx + 1).toString().padLeft(2, '0')}';
        }
        nameIdx = fullNames.indexOf(p1);
        if (nameIdx == -1) nameIdx = shortNames.indexOf(p1);
        yr = int.tryParse(parts[0]);
        if (nameIdx != -1 && yr != null && yr > 2000) {
          return '$yr-${(nameIdx + 1).toString().padLeft(2, '0')}';
        }
      }
    }
    if (date != null) {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}';
    }
    if (rawDateStr != null && rawDateStr.length >= 7 && RegExp(r'^\d{4}-\d{2}').hasMatch(rawDateStr)) {
      return rawDateStr.substring(0, 7);
    }
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  static String toFeeMonthLabel(String? monthKeyOrLabel, [DateTime? date]) {
    final mKey = toMonthKey(monthKeyOrLabel, date);
    final parts = mKey.split('-');
    if (parts.length != 2) return monthKeyOrLabel ?? '';
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (y == null || m == null || m < 1 || m > 12) return monthKeyOrLabel ?? '';
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${names[m - 1]} $y';
  }

  Map<String, dynamic> toMap() {
    final resolvedMonthKey = toMonthKey(monthKey ?? feeMonth, paymentDate);
    final resolvedFeeMonth = toFeeMonthLabel(feeMonth ?? monthKey, paymentDate);
    return {
      'id': id,
      'studentId': studentId,
      'amount': amount,
      'paymentDate': paymentDate.toIso8601String(),
      'paymentMode': paymentMode,
      'remarks': remarks,
      'receiptNumber': receiptNumber,
      'feeMonth': resolvedFeeMonth,
      'monthKey': resolvedMonthKey,
    };
  }

  Map<String, dynamic> toFirestoreMap() {
    final resolvedMonthKey = toMonthKey(monthKey ?? feeMonth, paymentDate);
    final resolvedFeeMonth = toFeeMonthLabel(feeMonth ?? monthKey, paymentDate);
    final parts = resolvedMonthKey.split('-');
    final y = int.tryParse(parts[0]) ?? paymentDate.year;
    final m = int.tryParse(parts[1]) ?? paymentDate.month;

    return {
      'id': id,
      'receiptId': id,
      'studentId': studentId,
      if (studentName != null && studentName!.isNotEmpty) 'studentName': studentName,
      if (admissionNumber != null && admissionNumber!.isNotEmpty) 'admissionNumber': admissionNumber,
      if (className != null && className!.isNotEmpty) 'className': className,
      'amount': amount,
      'amountPaid': amount,
      'paymentDate': paymentDate.toIso8601String(),
      'paymentMode': paymentMode,
      'remarks': remarks,
      'note': remarks,
      'receiptNumber': receiptNumber,
      'receiptNo': receiptNumber,
      'feeMonth': resolvedFeeMonth,
      'monthKey': resolvedMonthKey,
      'feeYear': y,
      'feeMonthNum': m,
      'year': y,
      'month': m,
      if (previousDue != null) 'previousDue': previousDue,
      if (previousDue != null) 'previousDues': previousDue,
      if (totalDemand != null) 'totalMonthDemand': totalDemand,
      if (totalDemand != null) 'totalDemand': totalDemand,
      if (totalDemand != null) 'totalDue': totalDemand,
      if (previousPaid != null) 'previousPaid': previousPaid,
      if (previousPaid != null) 'alreadyPaid': previousPaid,
      if (previousPaid != null) 'paidBefore': previousPaid,
      if (totalPaidAfter != null) 'totalPaidAfter': totalPaidAfter,
      if (totalPaidAfter != null) 'totalPaid': totalPaidAfter,
      if (balanceDue != null) 'balanceDue': balanceDue,
      if (balanceDue != null) 'balance': balanceDue,
      if (balanceDue != null) 'remainingDue': balanceDue,
      if (particularsSnapshot != null) 'particularsSnapshot': particularsSnapshot,
      if (receivedBy != null) 'receivedBy': receivedBy,
      if (feeStatus != null) 'feeStatus': feeStatus,
    };
  }

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    DateTime date;
    final rawDate = map['paymentDate'] ?? map['date'] ?? map['createdAt'];
    if (rawDate is Timestamp) {
      date = rawDate.toDate().toLocal();
    } else if (rawDate is DateTime) {
      date = rawDate.toLocal();
    } else if (rawDate is int) {
      date = DateTime.fromMillisecondsSinceEpoch(rawDate).toLocal();
    } else if (rawDate is String && rawDate.isNotEmpty) {
      final parsed = DateTime.tryParse(rawDate);
      date = parsed != null ? parsed.toLocal() : DateTime.now();
    } else {
      date = DateTime.now();
    }

    final rawFeeMonth = map['feeMonth']?.toString();
    final rawMonthKey = map['monthKey']?.toString();
    final rawFeeYear = (map['feeYear'] ?? map['year'] as num?)?.toInt();
    final rawFeeMonthNum = (map['feeMonthNum'] ?? map['month'] as num?)?.toInt();

    String candidate = rawMonthKey ?? rawFeeMonth ?? '';
    if (candidate.isEmpty && rawFeeYear != null && rawFeeMonthNum != null && rawFeeYear > 2000 && rawFeeMonthNum >= 1 && rawFeeMonthNum <= 12) {
      candidate = '$rawFeeYear-${rawFeeMonthNum.toString().padLeft(2, '0')}';
    }

    final finalMonthKey = toMonthKey(candidate.isNotEmpty ? candidate : null, date);
    final finalFeeMonth = toFeeMonthLabel(rawFeeMonth ?? finalMonthKey, date);
    final parts = finalMonthKey.split('-');
    final finalYear = rawFeeYear ?? (int.tryParse(parts[0]) ?? date.year);
    final finalMonth = rawFeeMonthNum ?? (int.tryParse(parts[1]) ?? date.month);

    return PaymentModel(
      id: map['id']?.toString() ?? map['receiptId']?.toString() ?? '',
      studentId: map['studentId']?.toString() ?? '',
      studentName: map['studentName']?.toString(),
      admissionNumber: map['admissionNumber']?.toString(),
      className: map['className']?.toString(),
      amount: (map['amount'] ?? map['amountPaid'] as num?)?.toDouble() ?? 0.0,
      paymentDate: date,
      paymentMode: map['paymentMode']?.toString() ?? 'Cash',
      remarks: map['remarks']?.toString() ?? map['note']?.toString(),
      receiptNumber: map['receiptNumber']?.toString() ?? map['receiptNo']?.toString() ?? '',
      feeMonth: finalFeeMonth,
      monthKey: finalMonthKey,
      feeYear: finalYear,
      feeMonthNum: finalMonth,
      previousDue: (map['previousDue'] ?? map['previousDues'] as num?)?.toDouble(),
      totalDemand: (map['totalMonthDemand'] ?? map['totalDemand'] ?? map['totalDue'] ?? map['totalAmount'] as num?)?.toDouble(),
      previousPaid: (map['previousPaid'] ?? map['alreadyPaid'] ?? map['paidBefore'] as num?)?.toDouble(),
      totalPaidAfter: (map['totalPaidAfter'] ?? map['totalPaid'] as num?)?.toDouble(),
      balanceDue: (map['balanceDue'] ?? map['balance'] ?? map['remainingDue'] as num?)?.toDouble(),
      particularsSnapshot: map['particularsSnapshot'] is Map ? Map<String, dynamic>.from(map['particularsSnapshot'] as Map) : null,
      receivedBy: map['receivedBy']?.toString(),
      feeStatus: map['feeStatus']?.toString(),
    );
  }
}

class FeeModel {
  final String studentId;
  final double totalFees;
  final double paidFees;
  final List<PaymentModel> payments;
  final double? explicitRemaining;
  final DateTime? dueDate;
  final DateTime? lastPaidDate;

  FeeModel({
    required this.studentId,
    required this.totalFees,
    required this.paidFees,
    this.explicitRemaining,
    required this.payments,
    this.dueDate,
    this.lastPaidDate,
  });

  double get remainingFees {
    if (explicitRemaining != null && explicitRemaining! > 0) {
      return explicitRemaining!;
    }
    if (totalFees > 0) {
      return (totalFees - paidFees).clamp(0.0, double.infinity).toDouble();
    }
    return 0.0;
  }

  double get totalPaid => paidFees;

  double get remaining => remainingFees;

  bool get isOverdue {
    if (dueDate == null || remainingFees <= 0) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  int get overdueDays {
    if (!isOverdue || dueDate == null) return 0;
    return DateTime.now().difference(dueDate!).inDays;
  }

  String get feeStatus {
    if (totalFees <= 0 && remainingFees <= 0) return 'Not Set';
    if (remainingFees <= 0) return 'Paid';
    if (isOverdue) return 'Overdue';
    if (paidFees <= 0) return 'Unpaid';
    return 'Pending';
  }

  Map<String, dynamic> toMap() => {
    'studentId': studentId,
    'totalFees': totalFees,
    'paidFees': paidFees,
    if (explicitRemaining != null) 'remainingFees': explicitRemaining,
    if (explicitRemaining != null) 'totalPending': explicitRemaining,
    'dueDate': dueDate?.toIso8601String(),
    'lastPaidDate': lastPaidDate?.toIso8601String(),
  };

  static double _parseNum(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString().trim()) ?? fallback;
  }

  factory FeeModel.fromMap(Map<String, dynamic> map, {List<PaymentModel> payments = const []}) {
    final explicitRem = _parseNum(map['remainingFees'] ?? map['totalPending'] ?? map['balanceDue'], -1.0);
    return FeeModel(
      studentId: map['studentId']?.toString() ?? '',
      totalFees: _parseNum(map['totalFees'] ?? map['totalFee']),
      paidFees: _parseNum(map['paidFees'] ?? map['totalPaid']),
      explicitRemaining: explicitRem >= 0 ? explicitRem : null,
      payments: payments,
      dueDate: DateTime.tryParse(map['dueDate']?.toString() ?? ''),
      lastPaidDate: DateTime.tryParse(map['lastPaidDate']?.toString() ?? ''),
    );
  }
}

class FeeLineItem {
  final String key;
  final String label;
  final double amount;

  const FeeLineItem({
    String? key,
    String? label,
    String? name,
    required this.amount,
  })  : key = key ?? name ?? '',
        label = label ?? name ?? '';

  String get name => label;

  Map<String, dynamic> toMap() => {
    'key': key,
    'label': label,
    'name': label,
    'amount': amount,
  };

  factory FeeLineItem.fromMap(Map<String, dynamic> map) {
    return FeeLineItem(
      key: map['key']?.toString(),
      label: map['label']?.toString(),
      name: map['name']?.toString(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Monthly fee ledger.
///
/// 12 demand-slip particulars:
/// 1. Admission Fee
/// 2. Tuition Fee / Set Monthly Amount
/// 3. Examination Fee
/// 4. Previous Dues
/// 5. Game Fee
/// 6. Re-Admission Fee
/// 7. Development Fee
/// 8. School ID
/// 9. Tie, Bag, Belt
/// 10. Back Dues
/// 11. Transport Fee
/// 12. Other Fee
class MonthlyFeeModel {
  final String id;
  final String studentId;
  final String month;

  final double admissionFee;
  final double tuitionFee;
  final double examinationFee;
  final double previousDue;
  final double gameFee;
  final double reAdmissionFee;
  final double developmentFee;
  final double schoolIdFee;
  final double tieBagBeltFee;
  final double backDues;
  final double transportFee;
  final double otherFee;

  final double paidAmount;

  // Auto-calculated from the student's Fee Structure (dueDay + finePerDay)
  // — see StudentFeeStructureModel below. Recomputed whenever the fee
  // record is loaded/created; NOT user-typed (shown read-only in the UI).
  final double lateFine;

  final DateTime? dueDate;
  final DateTime? lastPaymentDate;

  final DateTime createdAt;
  final DateTime updatedAt;
  final String? remarks;

  const MonthlyFeeModel({
    required this.id,
    required this.studentId,
    required this.month,

    this.admissionFee = 0.0,
    this.tuitionFee = 0.0,
    this.examinationFee = 0.0,
    this.previousDue = 0.0,
    this.gameFee = 0.0,
    this.reAdmissionFee = 0.0,
    this.developmentFee = 0.0,
    this.schoolIdFee = 0.0,
    this.tieBagBeltFee = 0.0,
    this.backDues = 0.0,
    this.transportFee = 0.0,
    this.otherFee = 0.0,

    this.paidAmount = 0.0,
    this.lateFine = 0.0,

    this.dueDate,
    this.lastPaymentDate,

    required this.createdAt,
    required this.updatedAt,
    this.remarks,
  });

  // ------------------------------------------------------------
  // Compatibility getters
  // ------------------------------------------------------------

  double get monthlyFee => tuitionFee;

  String get status {
    if (totalDue <= 0) return 'Not Set';
    if (remaining <= 0) return 'Paid';
    if (isOverdue) return 'Overdue';
    if (paidAmount <= 0) return 'Unpaid';
    return 'Pending';
  }

  String get feeStatus => status;

  bool get isPaid => totalDue > 0 && remaining <= 0;

  bool get isOverdue {
    if (dueDate == null || remaining <= 0) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  String get monthLabel {
    final parts = month.split('-');

    if (parts.length != 2) {
      return month;
    }

    final year = int.tryParse(parts[0]);
    final monthNumber = int.tryParse(parts[1]);

    if (year == null ||
        monthNumber == null ||
        monthNumber < 1 ||
        monthNumber > 12) {
      return month;
    }

    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${monthNames[monthNumber - 1]} $year';
  }

  // ------------------------------------------------------------
  // Additional fee compatibility
  // ------------------------------------------------------------

  List<FeeLineItem> get additionalFees => [
    FeeLineItem(
      key: 'admissionFee',
      label: 'Admission Fee',
      amount: admissionFee,
    ),
    FeeLineItem(
      key: 'tuitionFee',
      label: 'Tuition Fee',
      amount: tuitionFee,
    ),
    FeeLineItem(
      key: 'examinationFee',
      label: 'Examination Fee',
      amount: examinationFee,
    ),
    FeeLineItem(
      key: 'previousDue',
      label: 'Previous Dues',
      amount: previousDue,
    ),
    FeeLineItem(
      key: 'gameFee',
      label: 'Game Fee',
      amount: gameFee,
    ),
    FeeLineItem(
      key: 'reAdmissionFee',
      label: 'Re-Admission Fee',
      amount: reAdmissionFee,
    ),
    FeeLineItem(
      key: 'developmentFee',
      label: 'Development Fee',
      amount: developmentFee,
    ),
    FeeLineItem(
      key: 'schoolIdFee',
      label: 'School ID',
      amount: schoolIdFee,
    ),
    FeeLineItem(
      key: 'tieBagBeltFee',
      label: 'Tie, Bag, Belt',
      amount: tieBagBeltFee,
    ),
    FeeLineItem(
      key: 'backDues',
      label: 'Back Dues',
      amount: backDues,
    ),
    FeeLineItem(
      key: 'transportFee',
      label: 'Transport Fee',
      amount: transportFee,
    ),
    FeeLineItem(
      key: 'otherFee',
      label: 'Other Fee',
      amount: otherFee,
    ),
    FeeLineItem(
      key: 'lateFine',
      label: 'Late Fine',
      amount: lateFine,
    ),
  ];

  List<FeeLineItem> get additionalItems => additionalFees;

  double get additionalTotal =>
      admissionFee +
          examinationFee +
          gameFee +
          reAdmissionFee +
          developmentFee +
          schoolIdFee +
          tieBagBeltFee +
          backDues +
          transportFee +
          otherFee;

  double get monthlyCharge =>
      admissionFee +
      tuitionFee +
      examinationFee +
      gameFee +
      reAdmissionFee +
      developmentFee +
      schoolIdFee +
      tieBagBeltFee +
      backDues +
      transportFee +
      otherFee +
      lateFine;

  double get totalDue => previousDue + monthlyCharge;

  double get remaining =>
      (totalDue - paidAmount).clamp(0.0, double.infinity).toDouble();

  // ------------------------------------------------------------
  // Database / Firestore
  // ------------------------------------------------------------

  Map<String, dynamic> toMap() => {
    'id': id,
    'studentId': studentId,
    'month': month,

    'admissionFee': admissionFee,
    'tuitionFee': tuitionFee,
    'monthlyFee': tuitionFee,
    'examinationFee': examinationFee,
    'previousDue': previousDue,
    'gameFee': gameFee,
    'reAdmissionFee': reAdmissionFee,
    'developmentFee': developmentFee,
    'schoolIdFee': schoolIdFee,
    'tieBagBeltFee': tieBagBeltFee,
    'backDues': backDues,
    'transportFee': transportFee,
    'otherFee': otherFee,

    'paidAmount': paidAmount,
    'lateFine': lateFine,

    'dueDate': dueDate?.toIso8601String(),
    'lastPaymentDate': lastPaymentDate?.toIso8601String(),

    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'remarks': remarks,
  };

  Map<String, dynamic> toFirestoreMap() => {
    ...toMap(),
    'monthKey': month,
    'monthName': monthLabel,
    'feeMonth': monthLabel,
    'previousDues': previousDue,
    'schoolId': schoolIdFee,
    'tieBagBelt': tieBagBeltFee,
    'totalPaid': paidAmount,
    'additionalTotal': additionalTotal,
    'additionalFee': additionalTotal,
    'totalDue': totalDue,
    'totalDemand': totalDue,
    'totalMonthDemand': totalDue,
    'remaining': remaining,
    'balanceDue': remaining,
    'remainingFees': remaining,
    'status': status,
    'feeStatus': status,
  };

  factory MonthlyFeeModel.fromMap(Map<String, dynamic> map) {
    double number(String key) {
      final value = map[key];

      if (value is num) {
        return value.toDouble();
      }

      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    }

    DateTime? nullableDate(String key) {
      final value = map[key];

      if (value == null) {
        return null;
      }

      if (value is DateTime) {
        return value;
      }

      return DateTime.tryParse(value.toString());
    }

    DateTime dateOrNow(String key) {
      return nullableDate(key) ?? DateTime.now();
    }

    final prevDue = map.containsKey('previousDue')
        ? number('previousDue')
        : number('previousDues');
    final sIdFee = map.containsKey('schoolIdFee')
        ? number('schoolIdFee')
        : number('schoolId');
    final tbFee = map.containsKey('tieBagBeltFee')
        ? number('tieBagBeltFee')
        : number('tieBagBelt');
    final paid = map.containsKey('paidAmount')
        ? number('paidAmount')
        : (map.containsKey('totalPaid')
            ? number('totalPaid')
            : number('totalPaidAfter'));

    return MonthlyFeeModel(
      id: map['id']?.toString() ?? '',
      studentId: map['studentId']?.toString() ?? '',
      month: map['month']?.toString() ?? map['monthKey']?.toString() ?? '',

      admissionFee: number('admissionFee'),
      tuitionFee: number(
        map.containsKey('tuitionFee') ? 'tuitionFee' : 'monthlyFee',
      ),
      examinationFee: number('examinationFee'),
      previousDue: prevDue,
      gameFee: number('gameFee'),
      reAdmissionFee: number('reAdmissionFee'),
      developmentFee: number('developmentFee'),
      schoolIdFee: sIdFee,
      tieBagBeltFee: tbFee,
      backDues: number('backDues'),
      transportFee: number('transportFee'),
      otherFee: number('otherFee'),

      paidAmount: paid,
      lateFine: number('lateFine'),

      dueDate: nullableDate('dueDate'),
      lastPaymentDate: nullableDate('lastPaymentDate'),

      createdAt: dateOrNow('createdAt'),
      updatedAt: dateOrNow('updatedAt'),

      remarks: map['remarks']?.toString(),
    );
  }

  // ------------------------------------------------------------
  // copyWith
  // ------------------------------------------------------------

  MonthlyFeeModel copyWith({
    String? id,
    String? studentId,
    String? month,

    double? admissionFee,
    double? tuitionFee,
    double? examinationFee,
    double? previousDue,
    double? gameFee,
    double? reAdmissionFee,
    double? developmentFee,
    double? schoolIdFee,
    double? tieBagBeltFee,
    double? backDues,
    double? transportFee,
    double? otherFee,

    double? paidAmount,
    double? lateFine,

    DateTime? dueDate,
    DateTime? lastPaymentDate,

    DateTime? createdAt,
    DateTime? updatedAt,

    String? remarks,

    List<FeeLineItem>? additionalFees,
  }) {
    return MonthlyFeeModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      month: month ?? this.month,

      admissionFee: admissionFee ?? this.admissionFee,
      tuitionFee: tuitionFee ?? this.tuitionFee,
      examinationFee: examinationFee ?? this.examinationFee,
      previousDue: previousDue ?? this.previousDue,
      gameFee: gameFee ?? this.gameFee,
      reAdmissionFee: reAdmissionFee ?? this.reAdmissionFee,
      developmentFee: developmentFee ?? this.developmentFee,
      schoolIdFee: schoolIdFee ?? this.schoolIdFee,
      tieBagBeltFee: tieBagBeltFee ?? this.tieBagBeltFee,
      backDues: backDues ?? this.backDues,
      transportFee: transportFee ?? this.transportFee,
      otherFee: otherFee ?? this.otherFee,

      paidAmount: paidAmount ?? this.paidAmount,
      lateFine: lateFine ?? this.lateFine,

      dueDate: dueDate ?? this.dueDate,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,

      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,

      remarks: remarks ?? this.remarks,
    );
  }
}

/// Receipt ke additional fee fields.
const List<String> schoolReceiptAdditionalFeeNames = [
  'Admission Fee',
  'Examination Fee',
  'Game Fee',
  'Re-Admission Fee',
  'Development Fee',
  'School Id',
  'Tie, Bag, Belt',
  'Back Dues',
  'Transport Fee',
  'Other Fee',
];

/// A student's recurring monthly Fee Structure — set once, then reused
/// every month so the Principal doesn't have to retype Tuition/Transport/
/// Game fee each time. Also drives the automatic Due Date and Late Fine
/// for each month's [MonthlyFeeModel] (see DatabaseService.ensureMonthlyFee).
///
/// One row per student (studentId is the primary key) — there's no
/// "history" of structures; changing it only affects months created AFTER
/// the change, exactly like the existing tuition-fee-carry-forward
/// behaviour already in the app.
class StudentFeeStructureModel {
  final String studentId;
  final double tuitionFee;
  final double transportFee;
  final double gameFee;
  final int dueDay; // day-of-month the fee is due, e.g. 10
  final double finePerDay; // ₹ charged per day past the due date
  final String? startMonth; // e.g. '2026-10' - month from which recurring fees start
  final DateTime updatedAt;

  const StudentFeeStructureModel({
    required this.studentId,
    this.tuitionFee = 0.0,
    this.transportFee = 0.0,
    this.gameFee = 0.0,
    this.dueDay = 10,
    this.finePerDay = 0.0,
    this.startMonth,
    required this.updatedAt,
  });

  double get monthlyTotal => tuitionFee + transportFee + gameFee;

  bool get isSet => tuitionFee > 0;

  Map<String, dynamic> toMap() => {
    'studentId': studentId,
    'tuitionFee': tuitionFee,
    'transportFee': transportFee,
    'gameFee': gameFee,
    'dueDay': dueDay,
    'finePerDay': finePerDay,
    if (startMonth != null) 'startMonth': startMonth,
    'updatedAt': updatedAt.toIso8601String(),
  };

  Map<String, dynamic> toFirestoreMap() => {
    ...toMap(),
    'lateFinePerDay': finePerDay,
  };

  factory StudentFeeStructureModel.fromMap(Map<String, dynamic> map) {
    double number(String key) {
      final value = map[key];
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    }

    final fine = map.containsKey('finePerDay')
        ? number('finePerDay')
        : number('lateFinePerDay');

    return StudentFeeStructureModel(
      studentId: map['studentId']?.toString() ?? '',
      tuitionFee: number('tuitionFee'),
      transportFee: number('transportFee'),
      gameFee: number('gameFee'),
      dueDay: int.tryParse(map['dueDay']?.toString() ?? '') ?? 10,
      finePerDay: fine,
      startMonth: map['startMonth']?.toString(),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  StudentFeeStructureModel copyWith({
    double? tuitionFee,
    double? transportFee,
    double? gameFee,
    int? dueDay,
    double? finePerDay,
    String? startMonth,
    DateTime? updatedAt,
  }) {
    return StudentFeeStructureModel(
      studentId: studentId,
      tuitionFee: tuitionFee ?? this.tuitionFee,
      transportFee: transportFee ?? this.transportFee,
      gameFee: gameFee ?? this.gameFee,
      dueDay: dueDay ?? this.dueDay,
      finePerDay: finePerDay ?? this.finePerDay,
      startMonth: startMonth ?? this.startMonth,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}