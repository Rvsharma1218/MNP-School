import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExamSubjectConfig {
  final String subjectName; // Clean subject name only (no subject codes)
  final bool isCompulsory;
  final double theoryPassing;
  final double theoryMax;
  final double practicalPassing;
  final double practicalMax;
  final double internalPassing;
  final double internalMax;
  final double passingMarks; // Used when Direct Mode is active
  final double totalMarks;   // Used when Direct Mode is active

  ExamSubjectConfig({
    required this.subjectName,
    this.isCompulsory = true,
    this.theoryPassing = 33.0,
    this.theoryMax = 100.0,
    this.practicalPassing = 0.0,
    this.practicalMax = 0.0,
    this.internalPassing = 0.0,
    this.internalMax = 0.0,
    this.passingMarks = 33.0,
    this.totalMarks = 100.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'subjectName': subjectName,
      'isCompulsory': isCompulsory,
      'theoryPassing': theoryPassing,
      'theoryMax': theoryMax,
      'practicalPassing': practicalPassing,
      'practicalMax': practicalMax,
      'internalPassing': internalPassing,
      'internalMax': internalMax,
      'passingMarks': passingMarks,
      'totalMarks': totalMarks,
    };
  }

  factory ExamSubjectConfig.fromMap(Map<String, dynamic> map) {
    return ExamSubjectConfig(
      subjectName: map['subjectName']?.toString() ?? '',
      isCompulsory: map['isCompulsory'] != false,
      theoryPassing: (map['theoryPassing'] as num?)?.toDouble() ?? 33.0,
      theoryMax: (map['theoryMax'] as num?)?.toDouble() ?? 100.0,
      practicalPassing: (map['practicalPassing'] as num?)?.toDouble() ?? 0.0,
      practicalMax: (map['practicalMax'] as num?)?.toDouble() ?? 0.0,
      internalPassing: (map['internalPassing'] as num?)?.toDouble() ?? 0.0,
      internalMax: (map['internalMax'] as num?)?.toDouble() ?? 0.0,
      passingMarks: (map['passingMarks'] as num?)?.toDouble() ?? 33.0,
      totalMarks: (map['totalMarks'] as num?)?.toDouble() ?? 100.0,
    );
  }
}

class ExamModel {
  final String id;
  final String title;
  final String term;
  final String className;
  final String academicYear;
  final DateTime examDate;
  final String status; // 'Published', 'In Progress', 'Draft', 'Not Published'
  final bool isDetailedMode; // Direct Marks vs Detailed Breakdown
  final List<ExamSubjectConfig> subjects;
  final DateTime createdAt;

  ExamModel({
    required this.id,
    required this.title,
    this.term = 'Annual',
    required this.className,
    this.academicYear = '2026 - 2027',
    required this.examDate,
    this.status = 'In Progress',
    this.isDetailedMode = false,
    required this.subjects,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'term': term,
      'className': className,
      'academicYear': academicYear,
      'examDate': examDate.toIso8601String(),
      'status': status,
      'isDetailedMode': isDetailedMode,
      'subjects': subjects.map((s) => s.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ExamModel.fromMap(Map<String, dynamic> map) {
    List<ExamSubjectConfig> subs = [];
    if (map['subjects'] is List) {
      subs = (map['subjects'] as List)
          .map((s) => ExamSubjectConfig.fromMap(
              s is Map<String, dynamic> ? s : Map<String, dynamic>.from(s as Map)))
          .toList();
    } else if (map['subjects'] is String) {
      try {
        final decoded = jsonDecode(map['subjects'] as String);
        if (decoded is List) {
          subs = decoded
              .map((s) => ExamSubjectConfig.fromMap(
                  s is Map<String, dynamic> ? s : Map<String, dynamic>.from(s as Map)))
              .toList();
        }
      } catch (_) {}
    }

    DateTime parsedDate;
    final rawDate = map['examDate'];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String && rawDate.isNotEmpty) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else {
      parsedDate = DateTime.now();
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

    return ExamModel(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      term: map['term']?.toString() ?? 'Annual',
      className: map['className']?.toString() ?? '',
      academicYear: map['academicYear']?.toString() ?? '2026 - 2027',
      examDate: parsedDate,
      status: map['status']?.toString() ?? 'In Progress',
      isDetailedMode: map['isDetailedMode'] == true,
      subjects: subs,
      createdAt: created,
    );
  }
}
