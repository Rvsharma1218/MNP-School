import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectResult {
  final String subjectName;
  final double marks; // Total marks obtained (theory + practical + internal + oral)
  final double totalMarks; // Maximum possible marks ("total kitne mai se", default 100)
  final double passingMarks; // Minimum marks to pass ("kitne number pe paas hai", default 33)
  final double theoryMarks;
  final double practicalMarks;
  final double internalMarks;
  final double oralMarks;
  final String? category; // 'Written', 'Oral', 'Practical', 'Activity'
  final String? gradeOverride; // Direct grade entry for Pre-Primary ('A+', 'A', 'B+', 'B', 'C', 'D', 'F')

  SubjectResult({
    required this.subjectName,
    required this.marks,
    required this.totalMarks,
    this.passingMarks = 33.0,
    this.theoryMarks = 0.0,
    this.practicalMarks = 0.0,
    this.internalMarks = 0.0,
    this.oralMarks = 0.0,
    this.category,
    this.gradeOverride,
  });

  double get percentage => totalMarks > 0 ? (marks / totalMarks) * 100 : 0;

  bool get isPass {
    if (totalMarks <= 0) return true;
    final threshold = (passingMarks > 0 && passingMarks <= totalMarks)
        ? passingMarks
        : (totalMarks * 0.33);
    return marks >= threshold;
  }

  String get grade {
    if (gradeOverride != null && gradeOverride!.trim().isNotEmpty) {
      return gradeOverride!.trim();
    }
    final p = percentage;
    if (p >= 90) return 'A+';
    if (p >= 80) return 'A';
    if (p >= 70) return 'B+';
    if (p >= 60) return 'B';
    if (p >= 50) return 'C';
    if (p >= 40) return 'D';
    return 'F';
  }

  Map<String, dynamic> toMap() {
    return {
      'subjectName': subjectName,
      'marks': marks,
      'totalMarks': totalMarks,
      'passingMarks': passingMarks,
      'theoryMarks': theoryMarks,
      'practicalMarks': practicalMarks,
      'internalMarks': internalMarks,
      'oralMarks': oralMarks,
      if (category != null) 'category': category,
      if (gradeOverride != null) 'gradeOverride': gradeOverride,
    };
  }

  factory SubjectResult.fromMap(Map<String, dynamic> map) {
    final obt = (map['marks'] as num?)?.toDouble() ?? 0.0;
    final maxM = (map['totalMarks'] as num?)?.toDouble() ?? 100.0;
    final defaultPass = maxM * 0.33;
    final rawPass = (map['passingMarks'] as num?)?.toDouble();
    final passM = (rawPass != null && rawPass > 0 && rawPass <= maxM) ? rawPass : defaultPass;
    final th = (map['theoryMarks'] as num?)?.toDouble() ?? 0.0;
    final pr = (map['practicalMarks'] as num?)?.toDouble() ?? 0.0;
    final inM = (map['internalMarks'] as num?)?.toDouble() ?? 0.0;
    final oral = (map['oralMarks'] as num?)?.toDouble() ?? 0.0;
    final cat = map['category']?.toString();
    final gradeOvr = map['gradeOverride']?.toString() ?? map['grade']?.toString();

    return SubjectResult(
      subjectName: map['subjectName']?.toString() ?? '',
      marks: obt,
      totalMarks: maxM,
      passingMarks: passM,
      theoryMarks: th,
      practicalMarks: pr,
      internalMarks: inM,
      oralMarks: oral,
      category: cat,
      gradeOverride: gradeOvr,
    );
  }
}

class ResultModel {
  final String id;
  final String studentId;
  final String? studentName;
  final String? className;
  final String? rollNumber;
  final String examName;
  final List<SubjectResult> subjects;
  final String? status; // 'PASS' | 'FAIL' | 'PROMOTED'
  final DateTime createdAt;
  final bool isDetailedMode;
  final String? remarks;

  ResultModel({
    required this.id,
    required this.studentId,
    this.studentName,
    this.className,
    this.rollNumber,
    required this.examName,
    required this.subjects,
    this.status,
    required this.createdAt,
    this.isDetailedMode = false,
    this.remarks,
  });

  double get totalMarks => subjects.fold(0, (acc, s) => acc + s.totalMarks);
  double get obtainedMarks => subjects.fold(0, (acc, s) => acc + s.marks);
  double get overallPercentage => totalMarks > 0 ? (obtainedMarks / totalMarks) * 100 : 0;

  int get failedSubjectsCount => subjects.where((s) => !s.isPass).length;

  /// Check if this result belongs to Pre-Primary (Nursery, LKG, UKG, Play, etc.)
  bool get isPrePrimary {
    final c = (className ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return c.contains('nursery') ||
        c.contains('lkg') ||
        c.contains('ukg') ||
        c.contains('kg') ||
        c.contains('prep') ||
        c.contains('play') ||
        c.contains('balvatika') ||
        c.contains('preprimary') ||
        c.contains('infant');
  }

  /// Strict Pass/Fail/Promoted calculation:
  /// Pre-primary students are always promoted without negative ranking.
  /// If status is explicitly set to 'PROMOTED', returns true (Passed with promotion).
  /// If all subjects are passed and percentage >= 33, student is PASS (auto-heals stale FAIL doc status).
  /// If status is 'FAIL', returns false.
  /// Otherwise, if any subject is failed, student is FAIL.
  bool get isPass {
    if (isPrePrimary) return true;
    final s = status?.toUpperCase().trim();
    if (s == 'PROMOTED') return true;
    if (failedSubjectsCount == 0 && overallPercentage >= 33.0) return true;
    if (s == 'FAIL') return false;
    if (s == 'PASS') return true;
    return failedSubjectsCount == 0 && overallPercentage >= 33.0;
  }

  /// Evaluated display status: 'PASS', 'FAIL', or 'PROMOTED'
  String get finalResultStatus {
    if (isPrePrimary) return 'PROMOTED';
    final s = status?.toUpperCase().trim();
    if (s == 'PROMOTED') return 'PROMOTED';
    if (failedSubjectsCount == 0 && overallPercentage >= 33.0) return 'PASS';
    if (failedSubjectsCount > 0 || overallPercentage < 33.0) return 'FAIL';
    if (s == 'FAIL') return 'FAIL';
    if (s == 'PASS') return 'PASS';
    return overallPercentage >= 33.0 ? 'PASS' : 'FAIL';
  }

  String get overallGrade {
    final p = overallPercentage;
    if (p >= 90) return 'A+';
    if (p >= 80) return 'A';
    if (p >= 70) return 'B+';
    if (p >= 60) return 'B';
    if (p >= 50) return 'C';
    if (p >= 40) return 'D';
    return 'F';
  }

  /// Official school division classification
  String get division {
    if (isPrePrimary) {
      final p = overallPercentage;
      if (p >= 85.0) return 'Promoted (Outstanding - A+)';
      if (p >= 70.0) return 'Promoted (Excellent - A)';
      if (p >= 50.0) return 'Promoted (Very Good - B)';
      return 'Promoted (Good - C)';
    }
    if (failedSubjectsCount > 0 || overallPercentage < 33.0) return 'FAIL';
    final p = overallPercentage;
    if (p >= 85.0) return '1st Division (Distinction)';
    if (p >= 65.0) return '1st Division';
    if (p >= 45.0) return '2nd Division';
    if (p >= 33.0) return '3rd Division';
    return 'FAIL';
  }

  String get shortDivision {
    if (isPrePrimary) {
      final p = overallPercentage;
      if (p >= 85.0) return 'A+ (Outst.)';
      if (p >= 70.0) return 'A (Excell.)';
      if (p >= 50.0) return 'B (V.Good)';
      return 'C (Good)';
    }
    if (failedSubjectsCount > 0 || overallPercentage < 33.0) return 'FAIL';
    final p = overallPercentage;
    if (p >= 85.0) return '1st (Dist.)';
    if (p >= 65.0) return '1st Div';
    if (p >= 45.0) return '2nd Div';
    if (p >= 33.0) return '3rd Div';
    return 'FAIL';
  }

  ResultModel copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? className,
    String? rollNumber,
    String? examName,
    List<SubjectResult>? subjects,
    String? status,
    DateTime? createdAt,
    bool? isDetailedMode,
    String? remarks,
  }) {
    return ResultModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      className: className ?? this.className,
      rollNumber: rollNumber ?? this.rollNumber,
      examName: examName ?? this.examName,
      subjects: subjects ?? this.subjects,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      isDetailedMode: isDetailedMode ?? this.isDetailedMode,
      remarks: remarks ?? this.remarks,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'className': className,
      'rollNumber': rollNumber,
      'examName': examName,
      'subjects': subjects.map((s) => s.toMap()).toList(),
      'status': status ?? finalResultStatus,
      'createdAt': createdAt.toIso8601String(),
      'isDetailedMode': isDetailedMode,
      'remarks': remarks,
    };
  }

  factory ResultModel.fromMap(Map<String, dynamic> map, [List<SubjectResult>? rawSubjects]) {
    List<SubjectResult> parsedSubjects = rawSubjects ?? [];
    if (parsedSubjects.isEmpty) {
      if (map['subjects'] is List) {
        parsedSubjects = (map['subjects'] as List)
            .map((s) => SubjectResult.fromMap(
                s is Map<String, dynamic> ? s : Map<String, dynamic>.from(s as Map)))
            .toList();
      } else if (map['subjects'] is String && (map['subjects'] as String).isNotEmpty) {
        try {
          final decoded = jsonDecode(map['subjects'] as String);
          if (decoded is List) {
            parsedSubjects = decoded
                .map((s) => SubjectResult.fromMap(
                    s is Map<String, dynamic> ? s : Map<String, dynamic>.from(s as Map)))
                .toList();
          }
        } catch (_) {}
      }
    }

    DateTime created;
    final rawCreated = map['createdAt'];
    if (rawCreated is Timestamp) {
      created = rawCreated.toDate();
    } else if (rawCreated is String && rawCreated.isNotEmpty) {
      created = DateTime.tryParse(rawCreated) ?? DateTime.now();
    } else if (rawCreated is DateTime) {
      created = rawCreated;
    } else {
      created = DateTime.now();
    }

    final rawDetailed = map['isDetailedMode'];
    bool isDetailed;
    if (rawDetailed != null) {
      isDetailed = rawDetailed == 1 ||
          rawDetailed == true ||
          rawDetailed == '1' ||
          rawDetailed == 'true';
    } else {
      isDetailed = parsedSubjects.any((s) =>
          s.practicalMarks > 0 ||
          s.internalMarks > 0 ||
          (s.theoryMarks > 0 && s.marks > 0 && s.theoryMarks != s.marks));
    }

    return ResultModel(
      id: map['id']?.toString() ?? '',
      studentId: map['studentId']?.toString() ?? '',
      studentName: map['studentName']?.toString() ?? map['name']?.toString(),
      className: map['className']?.toString() ?? map['class']?.toString() ?? map['course']?.toString(),
      rollNumber: map['rollNumber']?.toString() ?? map['roll']?.toString(),
      examName: map['examName']?.toString() ?? map['examType']?.toString() ?? 'Term Exam',
      subjects: parsedSubjects,
      status: map['status']?.toString(),
      createdAt: created,
      isDetailedMode: isDetailed,
      remarks: map['remarks']?.toString(),
    );
  }
}
