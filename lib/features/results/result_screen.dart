import 'package:flutter/material.dart';
import '../../data/models/student_model.dart';
import 'screens/result_dashboard_screen.dart';

class ResultScreen extends StatelessWidget {
  final String? studentId;
  final StudentModel? student;
  const ResultScreen({super.key, this.studentId, this.student});

  @override
  Widget build(BuildContext context) {
    return ResultDashboardScreen(
      initialStudentId: student?.id ?? studentId,
      initialStudent: student,
    );
  }
}

