import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String id;
  final String studentId;
  final DateTime date;
  final String status; // 'present' | 'absent' | 'leave'

  AttendanceModel({
    required this.id,
    required this.studentId,
    required this.date,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'date': date.toIso8601String(),
      'status': status,
    };
  }

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate;
    final rawDate = map['date'] ?? map['dateKey'];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String && rawDate.isNotEmpty) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else {
      parsedDate = DateTime.now();
    }

    return AttendanceModel(
      id: map['id']?.toString() ?? '',
      studentId: map['studentId']?.toString() ?? '',
      date: parsedDate,
      status: map['status']?.toString() ?? 'present',
    );
  }
}
