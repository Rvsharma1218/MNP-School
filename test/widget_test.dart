import 'package:flutter_test/flutter_test.dart';
import 'package:mnp_school/data/models/fee_model.dart';
import 'package:mnp_school/data/models/result_model.dart';

void main() {
  group('FeeModel Tests', () {
    test('remaining fee calculation', () {
      final fee = FeeModel(
        studentId: 'test',
        totalFees: 10000,
        paidFees: 6000,
        payments: [],
      );
      expect(fee.remainingFees, 4000);
      expect(fee.feeStatus, 'Pending');
    });

    test('fee status - fully paid', () {
      final fee = FeeModel(
        studentId: 'test',
        totalFees: 5000,
        paidFees: 5000,
        payments: [],
      );
      expect(fee.feeStatus, 'Paid');
      expect(fee.remainingFees, 0);
    });

    test('fee status - unpaid', () {
      final fee = FeeModel(
        studentId: 'test',
        totalFees: 5000,
        paidFees: 0,
        payments: [],
      );
      expect(fee.feeStatus, 'Unpaid');
    });
  });

  group('SubjectResult Grade Tests', () {
    test('A+ grade for >= 90%', () {
      final subject = SubjectResult(subjectName: 'Math', marks: 95, totalMarks: 100);
      expect(subject.grade, 'A+');
      expect(subject.percentage, 95);
    });

    test('F grade for < 40%', () {
      final subject = SubjectResult(subjectName: 'Science', marks: 30, totalMarks: 100);
      expect(subject.grade, 'F');
    });

    test('Overall percentage calculation', () {
      final result = ResultModel(
        id: '1',
        studentId: 'stu1',
        examName: 'Midterm',
        subjects: [
          SubjectResult(subjectName: 'Math', marks: 80, totalMarks: 100),
          SubjectResult(subjectName: 'English', marks: 70, totalMarks: 100),
        ],
        createdAt: DateTime.now(),
      );
      expect(result.obtainedMarks, 150);
      expect(result.totalMarks, 200);
      expect(result.overallPercentage, 75);
    });
  });
}
