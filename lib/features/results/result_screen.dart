import 'package:flutter/material.dart';
import 'screens/result_dashboard_screen.dart';

class ResultScreen extends StatelessWidget {
  final String? studentId;
  const ResultScreen({super.key, this.studentId});

  @override
  Widget build(BuildContext context) {
    return ResultDashboardScreen(initialStudentId: studentId);
  }
}
