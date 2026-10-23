import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/student_model.dart';
import '../models/fee_model.dart';
import '../models/attendance_model.dart';
import '../models/settings_model.dart';
import '../models/result_model.dart';
import '../models/exam_model.dart';
import 'database_service.dart';
import 'session_service.dart';

/// FirestoreService — SQLite is the source of truth on-device.
/// Syncs data to Firestore scoped to schools/{schoolId}/... for true multi-school isolation.
class FirestoreService {
  static final FirestoreService instance = FirestoreService._internal();
  FirestoreService._internal();

  FirebaseFirestore? _firestore;
  bool _enabled = true;
  bool _initialized = false;

  void disable() {
    _enabled = false;
    debugPrint('[Firestore] ⛔ Disabled');
  }

  void enable() {
    _enabled = true;
    debugPrint('[Firestore] ✅ Enabled');
  }

  /// Call this after Firebase.initializeApp() succeeds
  void init() {
    try {
      _firestore = FirebaseFirestore.instance;
      try {
        _firestore!.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      } catch (settingsError) {
        debugPrint('[Firestore] Settings note: $settingsError');
      }
      _initialized = true;
      _enabled = true;
      debugPrint('[Firestore] ✅ Service initialized successfully');
    } catch (e) {
      debugPrint('[Firestore] ❌ Init failed: $e');
      _enabled = false;
    }
  }

  FirebaseFirestore? get _db {
    if (!_initialized || !_enabled) return null;
    return _firestore;
  }

  /// The active school ID (e.g. SCHOOL_001).
  String get _schoolId => SessionService.instance.activeSchoolId;

  /// Root: schools/{schoolId}
  DocumentReference? get _root {
    if (_db == null) return null;
    return _db!.collection('schools').doc(_schoolId);
  }

  CollectionReference? get _students => _root?.collection('students');
  CollectionReference? get _fees => _root?.collection('fees');
  CollectionReference? get _studentFees => _root?.collection('studentFees');
  CollectionReference? get _monthlyFees => _root?.collection('monthly_fees');
  CollectionReference? get _payments => _root?.collection('payments');
  CollectionReference? get _attendance => _root?.collection('attendance');
  CollectionReference? get _results => _root?.collection('results');
  DocumentReference? get _schoolSettings => _root?.collection('settings').doc('school');
  DocumentReference? get _configSettings => _root?.collection('settings').doc('config');

  // ─── Real-time Streams (Firestore → App) ────────────────────────────────

  Stream<List<StudentModel>>? watchStudents() {
    if (!_enabled || _students == null) return null;
    return _students!.snapshots().map(
          (snap) => snap.docs
          .map((d) {
            final data = Map<String, dynamic>.from(d.data() as Map);
            if (data['id'] == null || data['id'].toString().isEmpty) {
              data['id'] = d.id;
            }
            if (data['studentId'] == null || data['studentId'].toString().isEmpty) {
              data['studentId'] = d.id;
            }
            return StudentModel.fromMap(data);
          })
          .toList(),
    );
  }

  Stream<SettingsModel?>? watchSettings() {
    if (!_enabled || _configSettings == null) return null;
    return _configSettings!.snapshots().map((snap) {
      if (snap.exists && snap.data() != null) {
        return SettingsModel.fromMap(snap.data() as Map<String, dynamic>);
      }
      return null;
    });
  }

  Stream<Map<String, Map<String, dynamic>>>? watchFees() {
    if (!_enabled || _fees == null) return null;
    return _fees!.snapshots().map(
          (snap) => {for (final d in snap.docs) d.id: d.data() as Map<String, dynamic>},
    );
  }

  Stream<Map<String, Map<String, dynamic>>>? watchStudentFees() {
    if (!_enabled || _studentFees == null) return null;
    return _studentFees!.snapshots().map(
          (snap) => {for (final d in snap.docs) d.id: d.data() as Map<String, dynamic>},
    );
  }

  Stream<Map<String, Map<String, dynamic>>>? watchMonthlyFees() {
    if (!_enabled || _monthlyFees == null) return null;
    return _monthlyFees!.snapshots().map(
          (snap) => {for (final d in snap.docs) d.id: d.data() as Map<String, dynamic>},
    );
  }

  Stream<List<PaymentModel>>? watchPayments() {
    if (!_enabled || _payments == null) return null;
    return _payments!.snapshots().map((snap) => snap.docs
        .map((d) {
          final data = Map<String, dynamic>.from(d.data() as Map);
          final recNo = (data['receiptNumber'] ?? data['receiptNo'] ?? d.id).toString().trim();
          final canonicalId = recNo.isNotEmpty ? recNo : (data['id']?.toString() ?? d.id);
          data['id'] = canonicalId;
          data['receiptNumber'] = canonicalId;
          data['receiptNo'] = canonicalId;
          return PaymentModel.fromMap(data);
        })
        .toList());
  }

  Stream<List<AttendanceModel>>? watchAttendance() {
    if (!_enabled || _root == null) return null;
    final flatCol = _root!.collection('attendance_flat');
    return flatCol.snapshots().map((snap) => snap.docs
        .map((d) => AttendanceModel.fromMap(d.data()))
        .toList());
  }

  Stream<List<ResultModel>>? watchResults() {
    if (!_enabled || _results == null) return null;
    return _results!.snapshots().map((snap) => snap.docs
        .map((d) => ResultModel.fromMap(d.data() as Map<String, dynamic>))
        .toList());
  }

  // ─── Online Admission Enquiries & Teacher Applications ─────────────────

  Stream<List<Map<String, dynamic>>>? watchAdmissionEnquiries() {
    if (!_enabled || _db == null) return null;
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    final Map<String, Map<String, dynamic>> combined = {};

    void emitMerged() {
      final list = combined.values.toList();
      list.sort((a, b) {
        final tA = a['submittedAt']?.toString() ?? '';
        final tB = b['submittedAt']?.toString() ?? '';
        return tB.compareTo(tA);
      });
      if (!controller.isClosed) {
        controller.add(list);
      }
    }

    final targetSchools = <String>{_schoolId, 'SCHOOL_007', 'SCHOOL_001'};
    final subscriptions = <StreamSubscription>[];

    for (final sId in targetSchools) {
      if (sId.isEmpty) continue;
      final sub = _db!
          .collection('schoolDirectory')
          .doc(sId)
          .collection('admissionEnquiries')
          .snapshots()
          .listen(
        (snap) {
          for (final d in snap.docs) {
            final data = Map<String, dynamic>.from(d.data());
            data['refNo'] = d.id;
            combined[d.id] = data;
          }
          emitMerged();
        },
        onError: (e) {
          debugPrint('[Firestore] watchAdmissionEnquiries note: $e');
        },
      );
      subscriptions.add(sub);
    }

    controller.onCancel = () {
      for (final s in subscriptions) {
        s.cancel();
      }
    };

    return controller.stream;
  }

  Stream<List<Map<String, dynamic>>>? watchTeacherApplications() {
    if (!_enabled || _db == null) return null;
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    final Map<String, Map<String, dynamic>> combined = {};

    void emitMerged() {
      final list = combined.values.toList();
      list.sort((a, b) {
        final tA = a['submittedAt']?.toString() ?? '';
        final tB = b['submittedAt']?.toString() ?? '';
        return tB.compareTo(tA);
      });
      if (!controller.isClosed) {
        controller.add(list);
      }
    }

    final targetSchools = <String>{_schoolId, 'SCHOOL_007', 'SCHOOL_001'};
    final subscriptions = <StreamSubscription>[];

    for (final sId in targetSchools) {
      if (sId.isEmpty) continue;
      final sub = _db!
          .collection('schoolDirectory')
          .doc(sId)
          .collection('teacherApplications')
          .snapshots()
          .listen(
        (snap) {
          for (final d in snap.docs) {
            final data = Map<String, dynamic>.from(d.data());
            data['refNo'] = d.id;
            combined[d.id] = data;
          }
          emitMerged();
        },
        onError: (e) {
          debugPrint('[Firestore] watchTeacherApplications note: $e');
        },
      );
      subscriptions.add(sub);
    }

    controller.onCancel = () {
      for (final s in subscriptions) {
        s.cancel();
      }
    };

    return controller.stream;
  }

  Future<void> updateAdmissionEnquiryStatus(String refNo, String status) async {
    if (!_enabled || _db == null) return;
    try {
      await _db!
          .collection('schoolDirectory')
          .doc(_schoolId)
          .collection('admissionEnquiries')
          .doc(refNo)
          .update({'status': status, 'updatedAt': DateTime.now().toIso8601String()});
      if (_schoolId != 'SCHOOL_007') {
        try {
          await _db!
              .collection('schoolDirectory')
              .doc('SCHOOL_007')
              .collection('admissionEnquiries')
              .doc(refNo)
              .update({'status': status, 'updatedAt': DateTime.now().toIso8601String()});
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[Firestore] updateAdmissionEnquiryStatus error: $e');
    }
  }

  Future<void> deleteAdmissionEnquiry(String refNo) async {
    if (!_enabled || _db == null) return;
    try {
      await _db!
          .collection('schoolDirectory')
          .doc(_schoolId)
          .collection('admissionEnquiries')
          .doc(refNo)
          .delete();
      if (_schoolId != 'SCHOOL_007') {
        try {
          await _db!
              .collection('schoolDirectory')
              .doc('SCHOOL_007')
              .collection('admissionEnquiries')
              .doc(refNo)
              .delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[Firestore] deleteAdmissionEnquiry error: $e');
    }
  }

  Future<void> updateTeacherApplicationStatus(String refNo, String status) async {
    if (!_enabled || _db == null) return;
    try {
      await _db!
          .collection('schoolDirectory')
          .doc(_schoolId)
          .collection('teacherApplications')
          .doc(refNo)
          .update({'status': status, 'updatedAt': DateTime.now().toIso8601String()});
      if (_schoolId != 'SCHOOL_007') {
        try {
          await _db!
              .collection('schoolDirectory')
              .doc('SCHOOL_007')
              .collection('teacherApplications')
              .doc(refNo)
              .update({'status': status, 'updatedAt': DateTime.now().toIso8601String()});
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[Firestore] updateTeacherApplicationStatus error: $e');
    }
  }

  Future<void> deleteTeacherApplication(String refNo) async {
    if (!_enabled || _db == null) return;
    try {
      await _db!
          .collection('schoolDirectory')
          .doc(_schoolId)
          .collection('teacherApplications')
          .doc(refNo)
          .delete();
      if (_schoolId != 'SCHOOL_007') {
        try {
          await _db!
              .collection('schoolDirectory')
              .doc('SCHOOL_007')
              .collection('teacherApplications')
              .doc(refNo)
              .delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[Firestore] deleteTeacherApplication error: $e');
    }
  }

  // ─── Student Sync (schools/{schoolId}/students) ─────────────────────────

  Future<void> syncStudent(StudentModel student) async {
    if (!_enabled || _students == null) {
      debugPrint('[Firestore] ⚠️ Skipped syncStudent — disabled or not initialized');
      return;
    }
    try {
      final data = student.toFirestoreMap();
      data.remove('schoolId'); // Ensure no schoolId inside student document
      data['syncedAt'] = FieldValue.serverTimestamp();
      final docId = student.studentId.isNotEmpty ? student.studentId : student.id;

      // Attach complete Fee snapshot (structure, monthly particulars, dues, and status)
      try {
        final struct = await DatabaseService.instance.getFeeStructure(student.id);
        final monthlyFees = await DatabaseService.instance.getMonthlyFees(student.id);
        final fee = await DatabaseService.instance.getFeeByStudentId(student.id);

        if (struct != null) {
          data['feeStructure'] = {
            'dueDay': struct.dueDay,
            'finePerDay': struct.finePerDay,
            'lateFinePerDay': struct.finePerDay,
            'gameFee': struct.gameFee,
            'transportFee': struct.transportFee,
            'tuitionFee': struct.tuitionFee,
          };
          data['monthlyFee'] = struct.tuitionFee + struct.transportFee + struct.gameFee;
        } else if (student.monthlyFee != null && student.monthlyFee! > 0) {
          data['feeStructure'] = {
            'dueDay': 10,
            'finePerDay': 0.0,
            'lateFinePerDay': 0.0,
            'gameFee': 0.0,
            'transportFee': 0.0,
            'tuitionFee': student.monthlyFee,
          };
          data['monthlyFee'] = student.monthlyFee;
        }

        if (monthlyFees.isNotEmpty) {
          final particulars = <String, dynamic>{};
          for (final mf in monthlyFees) {
            particulars[mf.month] = {
              'admissionFee': mf.admissionFee,
              'backDues': mf.backDues,
              'developmentFee': mf.developmentFee,
              'dueDate': mf.dueDate != null ? mf.dueDate!.toIso8601String().substring(0, 10) : '${mf.month}-10',
              'examinationFee': mf.examinationFee,
              'gameFee': mf.gameFee,
              'lateFine': mf.lateFine,
              'monthName': PaymentModel.toFeeMonthLabel(mf.month, mf.dueDate),
              'otherFee': mf.otherFee,
              'previousDues': mf.previousDue,
              'reAdmissionFee': mf.reAdmissionFee,
              'schoolId': mf.schoolIdFee,
              'tieBagBelt': mf.tieBagBeltFee,
              'totalDue': mf.totalDue,
              'transportFee': mf.transportFee,
              'tuitionFee': mf.tuitionFee,
            };
          }
          data['monthlyParticulars'] = particulars;
        }

        if (fee != null) {
          data['totalFee'] = fee.totalFees;
          data['totalFees'] = fee.totalFees;
          data['totalPaid'] = fee.paidFees;
          data['paidFees'] = fee.paidFees;
          data['totalPending'] = fee.remainingFees;
          data['remainingFees'] = fee.remainingFees;
          data['feeStatus'] = fee.feeStatus;
          if (fee.lastPaidDate != null) {
            data['lastPaidDate'] = fee.lastPaidDate!.toIso8601String();
          }
        }
      } catch (err) {
        debugPrint('[Firestore] Note: Could not attach fee snapshot during student sync: $err');
      }

      await _students!.doc(docId).set(data, SetOptions(merge: true));
      debugPrint('[Firestore] ✅ Student synced under school $_schoolId: ${student.name} ($docId)');
    } catch (e, st) {
      debugPrint('[Firestore] ❌ Student sync failed: $e');
      debugPrint('[Firestore] Stack: $st');
    }
  }

  Future<void> deleteStudent(String studentId) async {
    if (!_enabled || _students == null) return;
    try {
      await _students!.doc(studentId).delete();
      await _fees?.doc(studentId).delete();
      await _studentFees?.doc(studentId).delete();

      final monthlyDocs = await _monthlyFees?.where('studentId', isEqualTo: studentId).get();
      if (monthlyDocs != null && monthlyDocs.docs.isNotEmpty) {
        final batch = _db!.batch();
        for (final doc in monthlyDocs.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      final paymentDocs = await _payments?.where('studentId', isEqualTo: studentId).get();
      if (paymentDocs != null && paymentDocs.docs.isNotEmpty) {
        final batch = _db!.batch();
        for (final doc in paymentDocs.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      final receiptDocs = await _root?.collection('receipts').where('studentId', isEqualTo: studentId).get();
      if (receiptDocs != null && receiptDocs.docs.isNotEmpty) {
        final batch = _db!.batch();
        for (final doc in receiptDocs.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      final flatDocs = await _root?.collection('attendance_flat').where('studentId', isEqualTo: studentId).get();
      if (flatDocs != null && flatDocs.docs.isNotEmpty) {
        final batch = _db!.batch();
        for (final doc in flatDocs.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      final attDocs = await _attendance?.get();
      if (attDocs != null && attDocs.docs.isNotEmpty) {
        final batch = _db!.batch();
        for (final doc in attDocs.docs) {
          if (doc.id.contains(studentId)) {
            batch.delete(doc.reference);
          }
        }
        await batch.commit();
      }

      final resultDocs = await _results?.where('studentId', isEqualTo: studentId).get();
      if (resultDocs != null && resultDocs.docs.isNotEmpty) {
        final batch = _db!.batch();
        for (final doc in resultDocs.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      debugPrint('[Firestore] ✅ Student and all related data deleted from school $_schoolId: $studentId');
    } catch (e) {
      debugPrint('[Firestore] ❌ Student delete failed: $e');
    }
  }

  // ─── Fee Sync (schools/{schoolId}/fees & studentFees) ───────────────────

  Future<void> syncFee(FeeModel fee) async {
    if (!_enabled || _fees == null) return;
    try {
      final rem = (fee.remaining <= 0 || fee.totalFees <= fee.paidFees) ? 0.0 : fee.remaining;
      final status = rem <= 0 ? 'Paid' : fee.feeStatus;
      final data = fee.toMap();
      data.remove('schoolId');
      data['remainingFees'] = rem;
      data['totalPending'] = rem;
      data['feeStatus'] = status;
      data['status'] = status;
      data['updatedAt'] = FieldValue.serverTimestamp();
      data['syncedAt'] = FieldValue.serverTimestamp();

      final studentDocUpdates = {
        'totalFee': fee.totalFees,
        'totalFees': fee.totalFees,
        'totalPaid': fee.paidFees,
        'paidFees': fee.paidFees,
        'totalPending': rem,
        'remainingFees': rem,
        'feeStatus': status,
        if (fee.lastPaidDate != null) 'lastPaidDate': fee.lastPaidDate!.toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await Future.wait([
        _fees!.doc(fee.studentId).set(data, SetOptions(merge: true)),
        _studentFees?.doc(fee.studentId).set({
          'studentId': fee.studentId,
          'totalFee': fee.totalFees,
          'totalFees': fee.totalFees,
          'totalPaid': fee.paidFees,
          'paidFees': fee.paidFees,
          'totalPending': rem,
          'remainingFees': rem,
          'status': status,
          'feeStatus': status,
          'dueDate': fee.dueDate?.toIso8601String() ?? '2026-10-10T00:00:00.000',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)) ?? Future.value(),
        _students?.doc(fee.studentId).set(studentDocUpdates, SetOptions(merge: true)) ?? Future.value(),
      ]);
      debugPrint('[Firestore] ✅ Fee synced for student in $_schoolId: ${fee.studentId}');
    } catch (e, st) {
      debugPrint('[Firestore] ❌ Fee sync failed: $e');
      debugPrint('[Firestore] Stack: $st');
    }
  }

  Future<void> syncMonthlyFee(MonthlyFeeModel fee) async {
    if (!_enabled || _monthlyFees == null) return;

    try {
      final data = fee.toFirestoreMap();
      data.remove('schoolId');
      data['additionalItems'] = fee.additionalItems.map((e) => e.toMap()).toList();
      data['additionalFee'] = fee.additionalTotal;
      data['totalDue'] = fee.totalDue;
      data['remaining'] = fee.remaining;
      data['isOverdue'] = fee.isOverdue;
      data['syncedAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();

      final docId = '${fee.studentId}_${fee.month}';

      final studentDocUpdates = {
        'monthlyParticulars.${fee.month}': {
          'admissionFee': fee.admissionFee,
          'backDues': fee.backDues,
          'developmentFee': fee.developmentFee,
          'dueDate': fee.dueDate != null ? fee.dueDate!.toIso8601String().substring(0, 10) : '${fee.month}-10',
          'examinationFee': fee.examinationFee,
          'gameFee': fee.gameFee,
          'lateFine': fee.lateFine,
          'monthName': PaymentModel.toFeeMonthLabel(fee.month, fee.dueDate),
          'otherFee': fee.otherFee,
          'previousDues': fee.previousDue,
          'reAdmissionFee': fee.reAdmissionFee,
          'schoolId': fee.schoolIdFee,
          'tieBagBelt': fee.tieBagBeltFee,
          'totalDue': fee.totalDue,
          'transportFee': fee.transportFee,
          'tuitionFee': fee.tuitionFee,
        },
        'monthlyFee': fee.monthlyFee > 0 ? fee.monthlyFee : (fee.tuitionFee + fee.transportFee + fee.gameFee),
        'feeStructure.tuitionFee': fee.tuitionFee,
        'feeStructure.transportFee': fee.transportFee,
        'feeStructure.gameFee': fee.gameFee,
        'feeStructure.dueDay': fee.dueDate?.day ?? 10,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await Future.wait([
        _monthlyFees!.doc(docId).set(data, SetOptions(merge: true)),
        _students?.doc(fee.studentId).set(studentDocUpdates, SetOptions(merge: true)) ?? Future.value(),
      ]);
      debugPrint('[Firestore] Monthly fee synced: $docId');
    } catch (e, st) {
      debugPrint('[Firestore] Monthly fee sync failed: $e');
      debugPrint('$st');
    }
  }

  Future<void> syncFeeStructure(StudentFeeStructureModel structure) async {
    if (!_enabled || _students == null) return;
    try {
      final docId = structure.studentId;
      final monthlyFee = structure.tuitionFee + structure.transportFee + structure.gameFee;
      await _students!.doc(docId).set({
        'feeStructure': {
          'dueDay': structure.dueDay,
          'finePerDay': structure.finePerDay,
          'lateFinePerDay': structure.finePerDay,
          'gameFee': structure.gameFee,
          'transportFee': structure.transportFee,
          'tuitionFee': structure.tuitionFee,
        },
        'monthlyFee': monthlyFee,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[Firestore] ✅ Fee structure synced for student $docId');
    } catch (e) {
      debugPrint('[Firestore] ❌ Fee structure sync failed: $e');
    }
  }

  Future<void> syncPayment(PaymentModel payment) async {
    if (!_enabled || _payments == null) {
      debugPrint('[Firestore] ⚠️ Skipped syncPayment — disabled or not initialized');
      return;
    }
    try {
      final data = payment.toFirestoreMap();
      data.remove('schoolId');
      data['receiptNo'] = payment.receiptNumber;
      final resolvedMonthKey = PaymentModel.toMonthKey(payment.monthKey ?? payment.feeMonth, payment.paymentDate);
      final resolvedFeeMonth = PaymentModel.toFeeMonthLabel(payment.feeMonth ?? payment.monthKey, payment.paymentDate);
      final parts = resolvedMonthKey.split('-');
      final y = int.tryParse(parts[0]) ?? payment.paymentDate.year;
      final m = int.tryParse(parts[1]) ?? payment.paymentDate.month;

      data['monthKey'] = resolvedMonthKey;
      data['feeMonth'] = resolvedFeeMonth;
      data['feeYear'] = y;
      data['feeMonthNum'] = m;
      data['year'] = y;
      data['month'] = m;
      data['syncedAt'] = FieldValue.serverTimestamp();
      final cleanReceiptNo = payment.receiptNumber.trim();
      final docId = cleanReceiptNo.isNotEmpty ? cleanReceiptNo : payment.id;
      data['id'] = docId;
      data['receiptId'] = docId;
      data['receiptNumber'] = docId;
      data['receiptNo'] = docId;
      await _payments!.doc(docId).set(data, SetOptions(merge: true));
      if (_students != null && payment.studentId.isNotEmpty) {
        _students!.doc(payment.studentId).set({
          'lastPaidDate': payment.paymentDate.toIso8601String(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).catchError((_) => null);
      }
      debugPrint('[Firestore] ✅ Payment synced under $_schoolId: $docId');
    } catch (e, st) {
      debugPrint('[Firestore] ❌ Payment sync failed: $e');
      debugPrint('[Firestore] Stack: $st');
      rethrow;
    }
  }

  Future<void> syncReceipt({
    required PaymentModel payment,
    required MonthlyFeeModel fee,
    required String studentName,
    required String admissionNumber,
    required String className,
    required double paidBefore,
    String mobile = '',
    String alternateMobile = '',
  }) async {
    if (!_enabled || _root == null) return;
    try {
      final receiptsCol = _root!.collection('receipts');
      final paymentsCol = _root!.collection('payments');
      final monthKey = PaymentModel.toMonthKey(fee.month.isNotEmpty ? fee.month : payment.feeMonth, payment.paymentDate);
      final feeMonthLabel = PaymentModel.toFeeMonthLabel(payment.feeMonth ?? fee.month, payment.paymentDate);
      final parts = monthKey.split('-');
      final y = int.tryParse(parts[0]) ?? payment.paymentDate.year;
      final m = int.tryParse(parts[1]) ?? payment.paymentDate.month;

      final particularsSnapshot = {
        'admissionFee': fee.admissionFee,
        'tuitionFee': fee.tuitionFee,
        'examinationFee': fee.examinationFee,
        'previousDues': fee.previousDue,
        'gameFee': fee.gameFee,
        'reAdmissionFee': fee.reAdmissionFee,
        'developmentFee': fee.developmentFee,
        'schoolId': fee.schoolIdFee,
        'schoolIdFee': fee.schoolIdFee,
        'tieBagBelt': fee.tieBagBeltFee,
        'tieBagBeltFee': fee.tieBagBeltFee,
        'backDues': fee.backDues,
        'transportFee': fee.transportFee,
        'otherFee': fee.otherFee,
        'lateFine': fee.lateFine,
      };

      final data = {
        'id': payment.id,
        'receiptId': payment.id,
        'receiptNumber': payment.receiptNumber,
        'receiptNo': payment.receiptNumber,
        'studentId': payment.studentId,
        'studentName': studentName,
        'admissionNumber': admissionNumber,
        'className': className,
        'mobile': mobile,
        'alternateMobile': alternateMobile,
        'feeMonth': feeMonthLabel,
        'monthKey': monthKey,
        'feeYear': y,
        'feeMonthNum': m,
        'year': y,
        'month': m,
        'paymentDate': payment.paymentDate.toIso8601String(),
        'paymentMode': payment.paymentMode,
        'amountPaid': payment.amount,
        'amount': payment.amount,
        'paidBefore': paidBefore,
        'alreadyPaid': paidBefore,
        'remarks': payment.remarks,
        'note': payment.remarks,
        'previousDue': fee.previousDue,
        'previousDues': fee.previousDue,
        'totalMonthDemand': fee.totalDue,
        'totalDemand': fee.totalDue,
        'totalDue': fee.totalDue,
        'totalPaidAfter': fee.paidAmount,
        'totalPaid': fee.paidAmount,
        'balanceDue': fee.remaining,
        'balance': fee.remaining,
        'remainingDue': fee.remaining,
        'feeStatus': fee.feeStatus,
        'particularsSnapshot': particularsSnapshot,
        'admissionFee': fee.admissionFee,
        'tuitionFee': fee.tuitionFee,
        'examinationFee': fee.examinationFee,
        'gameFee': fee.gameFee,
        'reAdmissionFee': fee.reAdmissionFee,
        'developmentFee': fee.developmentFee,
        'schoolIdFee': fee.schoolIdFee,
        'tieBagBeltFee': fee.tieBagBeltFee,
        'backDues': fee.backDues,
        'transportFee': fee.transportFee,
        'otherFee': fee.otherFee,
        'lateFine': fee.lateFine,
        'createdAt': FieldValue.serverTimestamp(),
        'syncedAt': FieldValue.serverTimestamp(),
      };
      final docId = payment.receiptNumber.isNotEmpty ? payment.receiptNumber : payment.id;

      final studentDocUpdates = {
        'totalFee': fee.totalDue,
        'totalFees': fee.totalDue,
        'totalPaid': fee.paidAmount,
        'paidFees': fee.paidAmount,
        'totalPending': fee.remaining,
        'remainingFees': fee.remaining,
        'feeStatus': fee.feeStatus,
        'lastPaidDate': payment.paymentDate.toIso8601String(),
        'monthlyParticulars.${fee.month}': particularsSnapshot,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await Future.wait([
        receiptsCol.doc(docId).set(data, SetOptions(merge: true)),
        paymentsCol.doc(docId).set(data, SetOptions(merge: true)),
        _students?.doc(payment.studentId).set(studentDocUpdates, SetOptions(merge: true)) ?? Future.value(),
      ]);
      debugPrint('[Firestore] ✅ Receipt & Payment synced: $docId');
    } catch (e) {
      debugPrint('[Firestore] ❌ Receipt sync failed: $e');
    }
  }

  // ─── Attendance Sync (schools/{schoolId}/attendance & attendance_flat) ──

  Future<void> syncAttendance(AttendanceModel record) async {
    if (!_enabled || _attendance == null) return;
    try {
      final dateKey =
          '${record.date.year}-${record.date.month.toString().padLeft(2, '0')}-${record.date.day.toString().padLeft(2, '0')}';
      final docId = '${record.studentId}_$dateKey';

      await _attendance!.doc(docId).set(record.toMap(), SetOptions(merge: true));

      final flatData = record.toMap();
      flatData['dateKey'] = dateKey;
      flatData['syncedAt'] = FieldValue.serverTimestamp();
      await _root!.collection('attendance_flat').doc(docId).set(
        flatData,
        SetOptions(merge: true),
      );

      debugPrint('[Firestore] ✅ Attendance synced in $_schoolId: $docId');
    } catch (e, st) {
      debugPrint('[Firestore] ❌ Attendance sync failed: $e');
      debugPrint('[Firestore] Stack: $st');
    }
  }

  // ─── Result Sync (schools/{schoolId}/results) ───────────────────────────

  Future<void> syncResult(ResultModel result) async {
    if (!_enabled || _results == null) return;
    try {
      final data = result.toMap();
      data.remove('schoolId');
      data['subjects'] = result.subjects.map((s) => s.toMap()).toList();
      data['syncedAt'] = FieldValue.serverTimestamp();
      await _results!.doc(result.id).set(data, SetOptions(merge: true));
      debugPrint('[Firestore] ✅ Result synced in $_schoolId: ${result.examName} (${result.studentId})');
    } catch (e) {
      debugPrint('[Firestore] ❌ Result sync failed: $e');
    }
  }

  Future<void> deleteResultRemote(String resultId) async {
    if (!_enabled || _results == null) return;
    try {
      await _results!.doc(resultId).delete();
      debugPrint('[Firestore] ✅ Result deleted: $resultId');
    } catch (e) {
      debugPrint('[Firestore] ❌ Result delete failed: $e');
    }
  }

  Future<List<ResultModel>> fetchResults() async {
    if (!_enabled || _results == null) return [];
    try {
      final snap = await _results!.get();
      return snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data() as Map);
        if (data['id'] == null || data['id'].toString().isEmpty) data['id'] = d.id;
        return ResultModel.fromMap(data);
      }).toList();
    } catch (e) {
      debugPrint('[Firestore] ❌ fetchResults failed: $e');
      return [];
    }
  }

  // ─── Settings Sync (schools/{schoolId}/settings/school & config & root doc) ──

  Future<void> syncSettings(SettingsModel settings) async {
    if (!_enabled || _db == null) return;
    try {
      final map = settings.toMap();

      // Auto-convert local logo file to base64 Data URL so Web can display it seamlessly
      String? resolvedLogo = settings.logoPath;
      if (resolvedLogo != null && resolvedLogo.isNotEmpty) {
        if (!resolvedLogo.startsWith('http') && !resolvedLogo.startsWith('data:image')) {
          try {
            final f = File(resolvedLogo);
            if (f.existsSync()) {
              final bytes = f.readAsBytesSync();
              resolvedLogo = 'data:image/png;base64,${base64Encode(bytes)}';
            }
          } catch (_) {}
        }
      }

      // Auto-convert local principal signature to base64 Data URL
      String? resolvedSig = settings.principalSignature;
      if (resolvedSig != null && resolvedSig.isNotEmpty) {
        if (!resolvedSig.startsWith('http') && !resolvedSig.startsWith('data:image')) {
          try {
            final f = File(resolvedSig);
            if (f.existsSync()) {
              final bytes = f.readAsBytesSync();
              resolvedSig = 'data:image/png;base64,${base64Encode(bytes)}';
            }
          } catch (_) {}
        }
      }

      if (resolvedLogo != null && resolvedLogo.isNotEmpty) {
        map['logoPath'] = resolvedLogo;
        map['logoUrl'] = resolvedLogo;
        map['logo'] = resolvedLogo;
      }
      if (resolvedSig != null && resolvedSig.isNotEmpty) {
        map['principalSignature'] = resolvedSig;
        map['signatureUrl'] = resolvedSig;
        map['signature'] = resolvedSig;
      }
      if (settings.rawSignature != null && settings.rawSignature!.isNotEmpty) {
        map['rawSignature'] = settings.rawSignature;
      }
      map['signatureColorMode'] = settings.signatureColorMode;

      // Auto-convert local school stamp to base64 Data URL
      String? resolvedStamp = settings.schoolStamp;
      if (resolvedStamp != null && resolvedStamp.isNotEmpty) {
        if (!resolvedStamp.startsWith('http') && !resolvedStamp.startsWith('data:image')) {
          try {
            final f = File(resolvedStamp);
            if (f.existsSync()) {
              final bytes = f.readAsBytesSync();
              resolvedStamp = 'data:image/png;base64,${base64Encode(bytes)}';
            }
          } catch (_) {}
        }
      }

      map['schoolStamp'] = resolvedStamp ?? '';
      map['stampUrl'] = resolvedStamp ?? '';
      map['sealUrl'] = resolvedStamp ?? '';

      map['schoolName'] = settings.instituteName;
      map['instituteName'] = settings.instituteName;
      map['address'] = settings.address;
      map['phone'] = settings.phone;
      map['mobile'] = settings.mobile;
      map['email'] = settings.email;
      map['academicYear'] = settings.currentSession;
      map['currentSession'] = settings.currentSession;
      map['receiptPrefix'] = settings.receiptPrefix;
      map['schoolClasses'] = settings.schoolClasses;
      map['computerCourses'] = settings.computerCourses;
      map['sections'] = settings.sections;
      map['batches'] = settings.batches;
      map['updatedAt'] = FieldValue.serverTimestamp();

      final futures = <Future>[];
      if (_schoolSettings != null) futures.add(_schoolSettings!.set(map, SetOptions(merge: true)));
      if (_configSettings != null) futures.add(_configSettings!.set(map, SetOptions(merge: true)));
      if (_root != null) {
        futures.add(_root!.set({
          'schoolName': settings.instituteName,
          'instituteName': settings.instituteName,
          'address': settings.address,
          'phone': settings.phone,
          'mobile': settings.mobile,
          'email': settings.email,
          'academicYear': settings.currentSession,
          'currentSession': settings.currentSession,
          'schoolClasses': settings.schoolClasses,
          'computerCourses': settings.computerCourses,
          'sections': settings.sections,
          'batches': settings.batches,
          'logo': resolvedLogo,
          'logoUrl': resolvedLogo,
          'schoolStamp': resolvedStamp,
          'stampUrl': resolvedStamp,
          'sealUrl': resolvedStamp,
          'signature': resolvedSig,
          'signatureUrl': resolvedSig,
          'principalSignature': resolvedSig,
          'active': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)));
      }
      await Future.wait(futures);
      debugPrint('[Firestore] Settings synced across school $_schoolId with base64 Data URLs');
    } catch (e) {
      debugPrint('[Firestore] Settings sync failed: $e');
    }
  }

  // ─── Bulk Sync ──────────────────────────────────────────────────────────

  Future<void> bulkSyncStudents(List<StudentModel> students) async {
    if (!_enabled || _db == null || _students == null || students.isEmpty) return;
    debugPrint('[Firestore] 🔄 Bulk sync: ${students.length} students to $_schoolId...');
    const batchSize = 400;
    for (int i = 0; i < students.length; i += batchSize) {
      final chunk = students.sublist(i,
          i + batchSize > students.length ? students.length : i + batchSize);
      final batch = _db!.batch();
      for (final s in chunk) {
        final data = s.toFirestoreMap();
        data.remove('schoolId');
        data['syncedAt'] = FieldValue.serverTimestamp();
        final docId = s.studentId.isNotEmpty ? s.studentId : s.id;
        batch.set(_students!.doc(docId), data, SetOptions(merge: true));
      }
      try {
        await batch.commit();
        debugPrint('[Firestore] ✅ Bulk sync batch committed (${chunk.length} students)');
      } catch (e) {
        debugPrint('[Firestore] ❌ Bulk sync batch failed: $e');
        break;
      }
    }
  }

  Future<void> syncAllLocalData() async {
    if (!_enabled || _db == null) {
      debugPrint('[Firestore] ⚠️ syncAllLocalData skipped: enabled=$_enabled');
      return;
    }
    debugPrint('[Firestore] 🔄 Starting full local data sync for school: $_schoolId');
    try {
      final localSettings = await DatabaseService.instance.getSettings();
      await _root?.set({
        'schoolName': localSettings.instituteName,
        'address': localSettings.address,
        'phone': localSettings.phone,
        'email': localSettings.email,
        'active': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final students = await DatabaseService.instance.getAllStudents();
      if (students.isNotEmpty) {
        await bulkSyncStudents(students);
      }

      final fees = await DatabaseService.instance.getAllFeesMap();
      for (final fee in fees.values) {
        await syncFee(fee);
      }

      final db = await DatabaseService.instance.database;

      try {
        final monthlyFeeRows = await db.query('monthly_fees');
        for (final row in monthlyFeeRows) {
          await syncMonthlyFee(MonthlyFeeModel.fromMap(row));
        }
      } catch (e) {
        debugPrint('[Firestore] monthly_fees sync note: $e');
      }

      try {
        final paymentRows = await db.query('payments');
        for (final row in paymentRows) {
          await syncPayment(PaymentModel.fromMap(row));
        }
      } catch (e) {
        debugPrint('[Firestore] payments sync note: $e');
      }

      try {
        final attendanceRows = await db.query('attendance');
        for (final row in attendanceRows) {
          await syncAttendance(AttendanceModel.fromMap(row));
        }
      } catch (e) {
        debugPrint('[Firestore] attendance sync note: $e');
      }

      try {
        for (final s in students) {
          final results = await DatabaseService.instance.getResultsByStudentId(s.id);
          for (final result in results) {
            await syncResult(result);
          }
        }
      } catch (e) {
        debugPrint('[Firestore] results sync note: $e');
      }

      final settings = await DatabaseService.instance.getSettings();
      await syncSettings(settings);

      debugPrint('[Firestore] ✅ Full local data sync completed successfully for $_schoolId');
    } catch (e, st) {
      debugPrint('[Firestore] ❌ Full local data sync failed: $e');
      debugPrint('$st');
    }
  }

  // ─── Query Helpers ──────────────────────────────────────────────────────

  Future<List<StudentModel>> fetchStudents() async {
    if (!_enabled || _students == null) return [];
    try {
      final snap = await _students!.get();
      final list = snap.docs
          .map((d) {
            final data = Map<String, dynamic>.from(d.data() as Map);
            if (data['id'] == null || data['id'].toString().isEmpty) {
              data['id'] = d.id;
            }
            if (data['studentId'] == null || data['studentId'].toString().isEmpty) {
              data['studentId'] = d.id;
            }
            return StudentModel.fromMap(data);
          })
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      debugPrint('[Firestore] ❌ fetchStudents failed: $e');
      return [];
    }
  }

  Future<List<PaymentModel>> fetchPayments() async {
    if (!_enabled || _payments == null) return [];
    try {
      final snap = await _payments!.get();
      final list = snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data() as Map);
        if (data['id'] == null || data['id'].toString().isEmpty) {
          data['id'] = d.id;
        }
        if (data['receiptNumber'] == null || data['receiptNumber'].toString().isEmpty) {
          data['receiptNumber'] = data['receiptNo'] ?? d.id;
        }
        if (data['receiptNo'] == null || data['receiptNo'].toString().isEmpty) {
          data['receiptNo'] = data['receiptNumber'];
        }
        return PaymentModel.fromMap(data);
      }).toList();
      list.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
      return list;
    } catch (e) {
      debugPrint('[Firestore] ❌ fetchPayments failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchFees() async {
    if (!_enabled || _fees == null) return [];
    try {
      final snap = await _fees!.get();
      return snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data() as Map);
        if (data['studentId'] == null || data['studentId'].toString().isEmpty) {
          data['studentId'] = d.id;
        }
        return data;
      }).toList();
    } catch (e) {
      debugPrint('[Firestore] ❌ fetchFees failed: $e');
      return [];
    }
  }

  Future<List<MonthlyFeeModel>> fetchMonthlyFees() async {
    if (!_enabled || _monthlyFees == null) return [];
    try {
      final snap = await _monthlyFees!.get();
      return snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data() as Map);
        if (data['id'] == null || data['id'].toString().isEmpty) {
          data['id'] = d.id;
        }
        return MonthlyFeeModel.fromMap(data);
      }).toList();
    } catch (e) {
      debugPrint('[Firestore] ❌ fetchMonthlyFees failed: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchStudentRaw(String studentId) async {
    if (!_enabled || _students == null) return null;
    try {
      final doc = await _students!.doc(studentId).get();
      if (doc.exists && doc.data() != null) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        if (data['id'] == null || data['id'].toString().isEmpty) data['id'] = doc.id;
        return data;
      }
      final q = await _students!.where('studentId', isEqualTo: studentId).limit(1).get();
      if (q.docs.isNotEmpty && q.docs.first.data() != null) {
        final data = Map<String, dynamic>.from(q.docs.first.data() as Map);
        if (data['id'] == null || data['id'].toString().isEmpty) data['id'] = q.docs.first.id;
        return data;
      }
    } catch (e) {
      debugPrint('[Firestore] ❌ fetchStudentRaw failed: $e');
    }
    return null;
  }

  Future<SettingsModel?> fetchSettings() async {
    if (!_enabled || _schoolSettings == null) return null;
    try {
      // Read settings/config FIRST — this is what the website writes to.
      // settings/school is a legacy path; fall back to root document if both are empty.
      var snap = await _configSettings!.get();
      if (!snap.exists || snap.data() == null) {
        snap = await _schoolSettings!.get();
      }
      if ((!snap.exists || snap.data() == null) && _root != null) {
        snap = await _root!.get();
      }
      if (!snap.exists || snap.data() == null) return null;
      return SettingsModel.fromMap(snap.data() as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[Firestore] ❌ fetchSettings failed: $e');
      return null;
    }
  }

  Future<List<AttendanceModel>> fetchAttendanceByDate(DateTime date) async {
    if (!_enabled || _attendance == null) return [];
    try {
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final snap = await _attendance!.doc(dateKey).collection('records').get();
      return snap.docs
          .map((d) => AttendanceModel.fromMap(d.data()))
          .toList();
    } catch (e) {
      debugPrint('[Firestore] ❌ fetchAttendanceByDate failed: $e');
      return [];
    }
  }

  /// Generate next sequential receipt number from payments count
  Future<String> nextReceiptNumber() async {
    if (!_enabled || _payments == null) {
      return 'REC${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    }
    try {
      final snap = await _payments!.get();
      final nextCount = snap.docs.length + 1;
      return 'REC${nextCount.toString().padLeft(6, '0')}';
    } catch (e) {
      return 'REC${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    }
  }

  /// Fetch all attendance summaries keyed by student ID
  Future<Map<String, Map<String, int>>> fetchAllAttendanceSummaries() async {
    if (!_enabled || _root == null) return {};
    try {
      final flatSnap = await _root!.collection('attendance_flat').get();
      final result = <String, Map<String, int>>{};
      for (final doc in flatSnap.docs) {
        final data = doc.data();
        final studentId = data['studentId']?.toString();
        final status = (data['status']?.toString() ?? 'present').toLowerCase();
        if (studentId == null || studentId.isEmpty) continue;

        result.putIfAbsent(studentId, () => {'total': 0, 'present': 0, 'absent': 0, 'leave': 0});
        result[studentId]!['total'] = (result[studentId]!['total'] ?? 0) + 1;
        if (status == 'present') {
          result[studentId]!['present'] = (result[studentId]!['present'] ?? 0) + 1;
        } else if (status == 'absent') {
          result[studentId]!['absent'] = (result[studentId]!['absent'] ?? 0) + 1;
        } else if (status == 'leave' || status == 'halfday') {
          result[studentId]!['leave'] = (result[studentId]!['leave'] ?? 0) + 1;
        }
      }
      return result;
    } catch (e) {
      debugPrint('[Firestore] ❌ fetchAllAttendanceSummaries failed: $e');
      return {};
    }
  }

  // ─── Results & Exams Sync ───────────────────────────────────────────────

  Future<void> syncExam(ExamModel exam) async {
    if (!_enabled || _root == null) return;
    try {
      await _root!.collection('exams').doc(exam.id).set(exam.toMap());
      debugPrint('[Firestore] ✅ Synced exam: ${exam.id}');
    } catch (e) {
      debugPrint('[Firestore] ❌ syncExam error: $e');
    }
  }

  Future<void> deleteExamRemote(String id) async {
    if (!_enabled || _root == null) return;
    try {
      await _root!.collection('exams').doc(id).delete();
      debugPrint('[Firestore] 🗑️ Deleted exam remote: $id');
    } catch (e) {
      debugPrint('[Firestore] ❌ deleteExamRemote error: $e');
    }
  }

  Future<List<ExamModel>> fetchExamsRemote() async {
    if (!_enabled || _root == null) return [];
    try {
      final snap = await _root!.collection('exams').get();
      return snap.docs
          .map((d) => ExamModel.fromMap(d.data()))
          .toList();
    } catch (e) {
      debugPrint('[Firestore] ❌ fetchExamsRemote error: $e');
      return [];
    }
  }
}