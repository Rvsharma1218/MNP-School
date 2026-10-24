import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/student_model.dart';
import '../models/fee_model.dart';
import '../models/attendance_model.dart';
import '../models/result_model.dart';
import '../models/exam_model.dart';
import '../models/settings_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/image_compress_util.dart';
import 'firestore_service.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();

  Database? _db;

  Future<void> initialize() async {
    if (kIsWeb) return; // SQLite not supported on web — Firestore is used directly
    _db = await _openDatabase();
    // Silently optimize heavy past student photos in background
    optimizeExistingStudentPhotos();
  }

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite database cannot be accessed directly on Web.');
    }
    _db ??= await _openDatabase();
    return _db!;
  }

  Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'school_app.db');

    return openDatabase(
      path,
      version: 14,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        try {
          await db.execute('ALTER TABLE payments ADD COLUMN monthKey TEXT');
        } catch (_) {}
        // Auto-heal known corrupt double-accrual for MD Arshalan
        try {
          await db.rawUpdate("UPDATE students SET remainingFees = 0, totalPending = 0, feeStatus = 'Paid', totalFees = 800 WHERE id = 'STU2026040' OR studentId = 'STU2026040'");
          await db.rawUpdate("UPDATE fees SET remainingFees = 0, totalPending = 0, feeStatus = 'Paid', totalFees = 800 WHERE studentId = 'STU2026040' OR id = 'STU2026040'");
        } catch (_) {}
        for (final col in [
          'aadhaarNumber TEXT',
          'aadhaarDocPath TEXT',
          'aadhaarDocUrl TEXT',
          'aadhaarCardUrl TEXT',
        ]) {
          try {
            await db.execute('ALTER TABLE students ADD COLUMN $col');
          } catch (_) {}
        }
        try {
          await db.execute('ALTER TABLE fee_structures ADD COLUMN startMonth TEXT');
        } catch (_) {}
        for (final col in [
          'schoolStamp TEXT',
          'rawSignature TEXT',
          'signatureColorMode TEXT DEFAULT "white"',
          'tagline TEXT',
          'sections TEXT',
          'batches TEXT',
          'schoolClasses TEXT',
          'computerCourses TEXT',
          'principalSignature TEXT',
          'appLanguage TEXT DEFAULT "en"',
        ]) {
          try {
            await db.execute('ALTER TABLE settings ADD COLUMN $col');
          } catch (_) {}
        }
        for (final col in [
          'theoryMarks REAL DEFAULT 0',
          'practicalMarks REAL DEFAULT 0',
          'internalMarks REAL DEFAULT 0',
        ]) {
          try {
            await db.execute('ALTER TABLE subject_results ADD COLUMN $col');
          } catch (_) {}
        for (final col in [
          'status TEXT',
          'subjects TEXT',
        ]) {
          try {
            await db.execute('ALTER TABLE results ADD COLUMN $col');
          } catch (_) {}
        }
        for (final col in [
          'passingMarks REAL DEFAULT 33',
        ]) {
          try {
            await db.execute('ALTER TABLE subject_results ADD COLUMN $col');
          } catch (_) {}
        }
        }
        for (final col in [
          'monthlyFee REAL DEFAULT 0',
          'totalFees REAL DEFAULT 0',
          'paidFees REAL DEFAULT 0',
          'remainingFees REAL DEFAULT 0',
          'totalPending REAL DEFAULT 0',
          'previousDue REAL DEFAULT 0',
          'feeStatus TEXT',
        ]) {
          try {
            await db.execute('ALTER TABLE students ADD COLUMN $col');
          } catch (_) {}
        }
        for (final col in [
          'remainingFees REAL DEFAULT 0',
          'totalPending REAL DEFAULT 0',
          'monthlyFee REAL DEFAULT 0',
          'feeStatus TEXT',
        ]) {
          try {
            await db.execute('ALTER TABLE fees ADD COLUMN $col');
          } catch (_) {}
        }

        try {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS exams (
              id TEXT PRIMARY KEY,
              title TEXT,
              term TEXT,
              className TEXT,
              academicYear TEXT,
              examDate TEXT,
              status TEXT,
              isDetailedMode INTEGER DEFAULT 0,
              subjects TEXT,
              createdAt TEXT
            )
          ''');
        } catch (_) {}

        try {
          await db.execute('ALTER TABLE results ADD COLUMN isDetailedMode INTEGER DEFAULT 0');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE results ADD COLUMN remarks TEXT');
        } catch (_) {}

        // Auto-heal duplicate payments (keep 1 row per receiptNumber)
        try {
          await db.execute('''
            DELETE FROM payments 
            WHERE id NOT IN (
              SELECT MIN(id) FROM payments GROUP BY receiptNumber
            ) AND receiptNumber IS NOT NULL AND TRIM(receiptNumber) != ''
          ''');
        } catch (_) {}

        // Auto-heal orphan fees (remove fees for students not in students table)
        try {
          await db.execute('''
            DELETE FROM fees 
            WHERE studentId NOT IN (SELECT id FROM students) 
              AND studentId NOT IN (SELECT studentId FROM students WHERE studentId IS NOT NULL AND studentId != '')
          ''');
        } catch (_) {}
      },
    );
  }

  Future<void> _onUpgrade(
      Database db,
      int oldVersion,
      int newVersion,
      ) async {
    if (oldVersion < 2) {
      try {
        await db.execute(
          'ALTER TABLE monthly_fees '
              'ADD COLUMN monthlyFee REAL NOT NULL DEFAULT 0',
        );
      } catch (_) {}
    }

    if (oldVersion < 3) {
      final columns = <String>[
        'admissionFee',
        'examinationFee',
        'previousDue',
        'gameFee',
        'reAdmissionFee',
        'developmentFee',
        'schoolIdFee',
        'tieBagBeltFee',
        'backDues',
        'transportFee',
        'otherFee',
      ];

      for (final column in columns) {
        try {
          await db.execute(
            'ALTER TABLE monthly_fees '
                'ADD COLUMN $column REAL NOT NULL DEFAULT 0',
          );
        } catch (_) {}
      }

      try {
        await db.execute(
          'ALTER TABLE monthly_fees ADD COLUMN remarks TEXT',
        );
      } catch (_) {}

      try {
        await db.execute(
          'ALTER TABLE monthly_fees ADD COLUMN createdAt TEXT',
        );
      } catch (_) {}

      try {
        await db.execute(
          'ALTER TABLE monthly_fees ADD COLUMN updatedAt TEXT',
        );
      } catch (_) {}
    }

    if (oldVersion < 6) {
      try {
        await db.execute(
          'ALTER TABLE monthly_fees '
              'ADD COLUMN monthlyFee REAL NOT NULL DEFAULT 0',
        );
      } catch (_) {}
    }

    if (oldVersion < 7) {
      try {
        await db.execute(
          'ALTER TABLE monthly_fees '
              'ADD COLUMN lateFine REAL NOT NULL DEFAULT 0',
        );
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS fee_structures (
            studentId TEXT PRIMARY KEY,
            tuitionFee REAL NOT NULL DEFAULT 0,
            transportFee REAL NOT NULL DEFAULT 0,
            gameFee REAL NOT NULL DEFAULT 0,
            dueDay INTEGER NOT NULL DEFAULT 10,
            finePerDay REAL NOT NULL DEFAULT 0,
            updatedAt TEXT NOT NULL,
            FOREIGN KEY (studentId) REFERENCES students(id)
          )
        ''');
      } catch (_) {}
    }

    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE settings ADD COLUMN schoolClasses TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE settings ADD COLUMN computerCourses TEXT');
      } catch (_) {}
    }

    if (oldVersion < 9) {
      try {
        await db.execute('ALTER TABLE settings ADD COLUMN tagline TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE settings ADD COLUMN sections TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE settings ADD COLUMN batches TEXT');
      } catch (_) {}
    }

    if (oldVersion < 10) {
      try {
        await db.execute('ALTER TABLE settings ADD COLUMN principalSignature TEXT');
      } catch (_) {}
    }

    if (oldVersion < 11) {
      try {
        await db.execute('ALTER TABLE payments ADD COLUMN monthKey TEXT');
      } catch (_) {}
    }

    if (oldVersion < 12) {
      try {
        await db.execute('ALTER TABLE students ADD COLUMN aadhaarNumber TEXT');
      } catch (_) {}
    }

    if (oldVersion < 13) {
      for (final col in [
        'schoolStamp TEXT',
        'rawSignature TEXT',
        'signatureColorMode TEXT DEFAULT "white"',
        'tagline TEXT',
        'sections TEXT',
        'batches TEXT',
        'schoolClasses TEXT',
        'computerCourses TEXT',
        'principalSignature TEXT',
        'appLanguage TEXT DEFAULT "en"',
      ]) {
        try {
          await db.execute('ALTER TABLE settings ADD COLUMN $col');
        } catch (_) {}
      }
    }

    if (oldVersion < 14) {
      for (final col in [
        'aadhaarNumber TEXT',
        'aadhaarDocPath TEXT',
        'aadhaarDocUrl TEXT',
        'aadhaarCardUrl TEXT',
      ]) {
        try {
          await db.execute('ALTER TABLE students ADD COLUMN $col');
        } catch (_) {}
      }
    }
  }

  Future<void> _createTables(Database db, int version) async {
    // ============================================================
    // STUDENTS
    // ============================================================
    await db.execute('''
    CREATE TABLE students (
      id TEXT PRIMARY KEY,
      admissionNumber TEXT UNIQUE NOT NULL,
      studentId TEXT UNIQUE NOT NULL,
      name TEXT NOT NULL,
      fatherName TEXT NOT NULL,
      motherName TEXT,
      mobile TEXT NOT NULL,
      alternateMobile TEXT,
      dob TEXT NOT NULL,
      gender TEXT NOT NULL,
      address TEXT NOT NULL,
      photoPath TEXT,
      aadhaarNumber TEXT,
      aadhaarDocPath TEXT,
      aadhaarDocUrl TEXT,
      aadhaarCardUrl TEXT,
      studentType TEXT NOT NULL,
      className TEXT,
      section TEXT,
      rollNumber TEXT,
      course TEXT,
      batch TEXT,
      courseDurationMonths INTEGER,
      expectedCompletionDate TEXT,
      status TEXT NOT NULL DEFAULT "active",
      session TEXT,
      email TEXT,
      admissionDate TEXT NOT NULL,
      createdAt TEXT NOT NULL,
      monthlyFee REAL DEFAULT 0,
      totalFees REAL DEFAULT 0,
      paidFees REAL DEFAULT 0,
      remainingFees REAL DEFAULT 0,
      totalPending REAL DEFAULT 0,
      previousDue REAL DEFAULT 0,
      feeStatus TEXT
    )
  ''');

    // ============================================================
    // OLD FEES TABLE
    // ============================================================
    await db.execute('''
    CREATE TABLE fees (
      studentId TEXT PRIMARY KEY,
      totalFees REAL NOT NULL DEFAULT 0,
      paidFees REAL NOT NULL DEFAULT 0,
      remainingFees REAL NOT NULL DEFAULT 0,
      totalPending REAL NOT NULL DEFAULT 0,
      monthlyFee REAL NOT NULL DEFAULT 0,
      feeStatus TEXT,
      dueDate TEXT,
      lastPaidDate TEXT
    )
  ''');

    // ============================================================
    // MONTHLY FEES
    // ============================================================
    await db.execute('''
CREATE TABLE monthly_fees (
  id TEXT PRIMARY KEY,
  studentId TEXT NOT NULL,
  month TEXT NOT NULL,
  monthlyFee REAL NOT NULL DEFAULT 0,
  admissionFee REAL NOT NULL DEFAULT 0,
  tuitionFee REAL NOT NULL DEFAULT 0,
  examinationFee REAL NOT NULL DEFAULT 0,
  previousDue REAL NOT NULL DEFAULT 0,
  gameFee REAL NOT NULL DEFAULT 0,
  reAdmissionFee REAL NOT NULL DEFAULT 0,
  developmentFee REAL NOT NULL DEFAULT 0,
  schoolIdFee REAL NOT NULL DEFAULT 0,
  tieBagBeltFee REAL NOT NULL DEFAULT 0,
  backDues REAL NOT NULL DEFAULT 0,
  transportFee REAL NOT NULL DEFAULT 0,
  otherFee REAL NOT NULL DEFAULT 0,
  paidAmount REAL NOT NULL DEFAULT 0,
  lateFine REAL NOT NULL DEFAULT 0,
  dueDate TEXT,
  lastPaymentDate TEXT,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  remarks TEXT,
  UNIQUE(studentId, month),
  FOREIGN KEY (studentId) REFERENCES students(id)
)
''');

    // ============================================================
    // FEE STRUCTURES (per-student recurring monthly template)
    // ============================================================
    await db.execute('''
    CREATE TABLE fee_structures (
      studentId TEXT PRIMARY KEY,
      tuitionFee REAL NOT NULL DEFAULT 0,
      transportFee REAL NOT NULL DEFAULT 0,
      gameFee REAL NOT NULL DEFAULT 0,
      dueDay INTEGER NOT NULL DEFAULT 10,
      finePerDay REAL NOT NULL DEFAULT 0,
      updatedAt TEXT NOT NULL,
      FOREIGN KEY (studentId) REFERENCES students(id)
    )
  ''');

    // ============================================================
    // PAYMENTS
    // ============================================================
    await db.execute('''
    CREATE TABLE payments (
      id TEXT PRIMARY KEY,
      studentId TEXT NOT NULL,
      amount REAL NOT NULL,
      paymentDate TEXT NOT NULL,
      paymentMode TEXT NOT NULL,
      remarks TEXT,
      receiptNumber TEXT NOT NULL,
      feeMonth TEXT,
      monthKey TEXT,
      FOREIGN KEY (studentId) REFERENCES students(id)
    )
  ''');

    // ============================================================
    // ATTENDANCE
    // ============================================================
    await db.execute('''
    CREATE TABLE attendance (
      id TEXT PRIMARY KEY,
      studentId TEXT NOT NULL,
      date TEXT NOT NULL,
      status TEXT NOT NULL,
      FOREIGN KEY (studentId) REFERENCES students(id),
      UNIQUE(studentId, date)
    )
  ''');

    // ============================================================
    // RESULTS
    // ============================================================
    await db.execute('''
    CREATE TABLE results (
      id TEXT PRIMARY KEY,
      studentId TEXT NOT NULL,
      examName TEXT NOT NULL,
      status TEXT,
      subjects TEXT,
      createdAt TEXT NOT NULL,
      FOREIGN KEY (studentId) REFERENCES students(id)
    )
  ''');

    // ============================================================
    // SUBJECT RESULTS
    // ============================================================
    await db.execute('''
    CREATE TABLE subject_results (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      resultId TEXT NOT NULL,
      subjectName TEXT NOT NULL,
      marks REAL NOT NULL,
      totalMarks REAL NOT NULL,
      theoryMarks REAL DEFAULT 0,
      practicalMarks REAL DEFAULT 0,
      internalMarks REAL DEFAULT 0,
      FOREIGN KEY (resultId) REFERENCES results(id)
    )
  ''');

    // ============================================================
    // SETTINGS
    // ============================================================
    await db.execute('''
    CREATE TABLE settings (
      id INTEGER PRIMARY KEY,
      instituteName TEXT NOT NULL,
      tagline TEXT,
      logoPath TEXT,
      address TEXT NOT NULL,
      mobile TEXT NOT NULL,
      email TEXT,
      website TEXT,
      principalName TEXT,
      affiliationNumber TEXT,
      principalSignature TEXT,
      schoolStamp TEXT,
      rawSignature TEXT,
      signatureColorMode TEXT DEFAULT "white",
      currentSession TEXT DEFAULT "2026-27",
      themeMode TEXT DEFAULT "light",
      schoolClasses TEXT,
      computerCourses TEXT,
      sections TEXT,
      batches TEXT
    )
  ''');

    // ============================================================
    // RECEIPT COUNTER
    // ============================================================
    await db.execute('''
    CREATE TABLE receipt_counter (
      id INTEGER PRIMARY KEY,
      counter INTEGER NOT NULL DEFAULT 0
    )
  ''');

    // ============================================================
    // DEFAULT DATA
    // ============================================================
    await db.insert('settings', {
      'id': 1,
      'instituteName': 'My School & Computer Institute',
      'address': 'Enter Your Address Here',
      'mobile': '9876543210',
      'currentSession': '2026-27',
      'themeMode': 'light',
      'principalSignature': null,
    });

    await db.insert(
      'receipt_counter',
      {
        'id': 1,
        'counter': 0,
      },
    );
  }


  String? _activeUserUid;

  /// Switches the active school user context WITHOUT wiping local SQLite data.
  ///
  /// IMPORTANT: We intentionally do NOT delete any tables here.
  /// SQLite is the local cache / offline-first database. Wiping it on every
  /// app restart or role switch causes the exact data-loss bugs described in
  /// the issue (students/fees/payments disappearing after restart).
  ///
  /// Correct flow:
  ///   App start → Firebase Auth restores session → SessionService.restore()
  ///   → switchLocalUser(schoolId) [just sets the active context]
  ///   → Firestore realtime streams UPSERT new/updated records into SQLite
  ///   → Riverpod providers invalidate → UI rebuilds with fresh data
  ///
  /// For explicit user logout, call clearAllLocalData() separately.
  Future<void> switchLocalUser(String? uid) async {
    if (_activeUserUid == uid) return;
    final oldUid = _activeUserUid;
    _activeUserUid = uid;
    debugPrint('[DB] switchLocalUser → $uid (previous: $oldUid)');
    if (oldUid != null && uid != null && oldUid != uid) {
      debugPrint('[DB] School changed from $oldUid to $uid — clearing local SQLite cache');
      await clearAllLocalData();
    }
  }

  /// Explicitly clears all local school data.
  /// Call this ONLY during a real user logout (sign-out button), never on
  /// restart or role switch. This allows a different school account to start
  /// fresh on the same device without seeing the previous school's data.
  Future<void> clearAllLocalData() async {
    if (kIsWeb) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final table in [
        'subject_results', 'results', 'attendance', 'payments',
        'monthly_fees', 'fee_structures', 'fees', 'students'
      ]) {
        await txn.delete(table);
      }
      await txn.delete('settings');
      await txn.delete('receipt_counter');
      await txn.insert('settings', {
        'id': 1,
        'instituteName': 'My School & Computer Institute',
        'address': 'Enter Your Address Here',
        'mobile': '9876543210',
        'currentSession': '2026-27',
        'themeMode': 'light',
        'principalSignature': null,
      });
      await txn.insert('receipt_counter', {'id': 1, 'counter': 0});
    });
    _activeUserUid = null;
    debugPrint('[DB] clearAllLocalData — all tables cleared');
  }

  String? get activeUserUid => _activeUserUid;

  Future<void> upsertPaymentFromRemote(Map<String, dynamic> data) async {
    final db = await database;
    final studentId = data['studentId']?.toString() ?? '';
    final admissionNo = data['admissionNumber']?.toString() ?? data['admissionNo']?.toString();
    final studentName = data['studentName']?.toString();

    List<Map<String, dynamic>> matching = [];
    if (studentId.isNotEmpty) {
      matching = await db.query(
        'students',
        where: 'id = ? OR studentId = ?',
        whereArgs: [studentId, studentId],
      );
    }
    if (matching.isEmpty && admissionNo != null && admissionNo.isNotEmpty) {
      matching = await db.query(
        'students',
        where: 'admissionNumber = ?',
        whereArgs: [admissionNo],
      );
    }
    if (matching.isEmpty && studentName != null && studentName.isNotEmpty) {
      matching = await db.query(
        'students',
        where: 'LOWER(name) = ?',
        whereArgs: [studentName.trim().toLowerCase()],
      );
    }
    final resolvedStudentId = matching.isNotEmpty ? (matching.first['id'] as String) : studentId;
    if (resolvedStudentId.isEmpty) return;

    final monthKey = data['monthKey']?.toString() ?? '';
    final feeMonthRaw = data['feeMonth']?.toString() ?? '';

    DateTime paymentDateTime;
    final rawDate = data['paymentDate'] ?? data['date'] ?? data['createdAt'];
    if (rawDate is DateTime) {
      paymentDateTime = rawDate.toLocal();
    } else if (rawDate != null && rawDate.toString().isNotEmpty) {
      final parsed = DateTime.tryParse(rawDate.toString());
      paymentDateTime = parsed != null ? parsed.toLocal() : DateTime.now();
    } else {
      paymentDateTime = DateTime.now();
    }
    final paymentDateStr = paymentDateTime.toIso8601String();

    final resolvedMonthKey = PaymentModel.toMonthKey(monthKey.isNotEmpty ? monthKey : feeMonthRaw, null, paymentDateStr);
    final resolvedFeeMonth = PaymentModel.toFeeMonthLabel(feeMonthRaw.isNotEmpty ? feeMonthRaw : resolvedMonthKey, null);

    final rawAmount = data['amount'] ?? data['amountPaid'];
    final amount = (rawAmount as num?)?.toDouble() ?? (double.tryParse(rawAmount?.toString() ?? '') ?? 0.0);

    final receiptNo = (data['receiptNumber'] ?? data['receiptNo'] ?? '').toString().trim();
    final cleanId = receiptNo.isNotEmpty
        ? receiptNo
        : ((data['id'] != null && data['id'].toString().isNotEmpty)
            ? data['id'].toString()
            : const Uuid().v4());

    if (receiptNo.isNotEmpty) {
      await db.delete('payments', where: 'receiptNumber = ? AND id != ?', whereArgs: [receiptNo, cleanId]);
    }

    final paymentRow = <String, dynamic>{
      'id': cleanId,
      'studentId': resolvedStudentId,
      'amount': amount,
      'paymentDate': paymentDateStr,
      'paymentMode': data['paymentMode']?.toString() ?? 'Cash',
      'remarks': data['remarks']?.toString() ?? data['note']?.toString(),
      'receiptNumber': receiptNo.isNotEmpty ? receiptNo : cleanId,
      'feeMonth': resolvedFeeMonth,
      'monthKey': resolvedMonthKey,
    };

    try {
      await db.insert('payments', paymentRow, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {
      try {
        await db.execute('ALTER TABLE payments ADD COLUMN monthKey TEXT');
        await db.insert('payments', paymentRow, conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (_) {
        paymentRow.remove('monthKey');
        await db.insert('payments', paymentRow, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }

    if (data['monthlyParticulars'] is Map) {
      await upsertFeeFromRemote(resolvedStudentId, {
        'monthlyParticulars': data['monthlyParticulars'],
        'monthlyFee': data['monthlyFee'],
      });
    }

    await refreshLegacyFeeAggregate(resolvedStudentId);
  }

  Future<void> upsertAttendanceFromRemote(AttendanceModel record) async {
    final db = await database;
    final matching = await db.query(
      'students',
      where: 'id = ? OR studentId = ?',
      whereArgs: [record.studentId, record.studentId],
    );
    final resolvedStudentId = matching.isNotEmpty ? (matching.first['id'] as String) : record.studentId;

    final dateStr = record.date.toIso8601String().substring(0, 10);
    await db.delete(
      'attendance',
      where: "studentId = ? AND date LIKE ?",
      whereArgs: [resolvedStudentId, '$dateStr%'],
    );

    final map = record.toMap();
    map['studentId'] = resolvedStudentId;
    map['date'] = '$dateStr 00:00:00.000';
    await db.insert('attendance', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> upsertResultFromRemote(ResultModel result) async {
    if (kIsWeb) return;
    final db = await database;
    final matching = await db.query(
      'students',
      where: 'id = ? OR studentId = ?',
      whereArgs: [result.studentId, result.studentId],
    );
    final resolvedStudentId = matching.isNotEmpty ? (matching.first['id'] as String) : result.studentId;

    final resMap = {
      'id': result.id,
      'studentId': resolvedStudentId,
      'examName': result.examName,
      'createdAt': result.createdAt.toIso8601String(),
    };
    await db.insert('results', resMap, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.delete('subject_results', where: 'resultId = ?', whereArgs: [result.id]);
    for (final subject in result.subjects) {
      await db.insert('subject_results', {
        'resultId': result.id,
        'subjectName': subject.subjectName,
        'marks': subject.marks,
        'totalMarks': subject.totalMarks,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> replaceRemotePayments(List<PaymentModel> payments) async {
    final db = await database;
    await db.delete('payments');
    for (final payment in payments) {
      final matching = await db.query(
        'students',
        where: 'id = ? OR studentId = ?',
        whereArgs: [payment.studentId, payment.studentId],
      );
      if (matching.isNotEmpty) {
        final resolvedStudentId = matching.first['id'] as String;
        final map = payment.toMap();
        map['studentId'] = resolvedStudentId;
        await db.insert('payments', map, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
  }

  Future<void> replaceRemoteAttendance(List<AttendanceModel> records) async {
    final db = await database;
    await db.delete('attendance');
    for (final record in records) {
      final matching = await db.query(
        'students',
        where: 'id = ? OR studentId = ?',
        whereArgs: [record.studentId, record.studentId],
      );
      if (matching.isNotEmpty) {
        final resolvedStudentId = matching.first['id'] as String;
        final map = record.toMap();
        map['studentId'] = resolvedStudentId;
        await db.insert('attendance', map, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
  }

  // ─── RECEIPT COUNTER ──────────────────────────────────────────────────────

  Future<String> generateReceiptNumber([int? year]) async {
    final y = year ?? DateTime.now().year;
    if (kIsWeb) return FirestoreService.instance.nextReceiptNumber();
    final db = await database;
    final rows = await db.query('payments');
    final regExp = RegExp('REC-$y-(\\d+)', caseSensitive: false);
    final altRegExp = RegExp('REC(\\d+)', caseSensitive: false);
    int maxSeq = 0;
    for (final row in rows) {
      final rec = row['receiptNumber']?.toString() ?? '';
      final match = regExp.firstMatch(rec);
      if (match != null) {
        final n = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (n > maxSeq) maxSeq = n;
      } else {
        final matchAlt = altRegExp.firstMatch(rec);
        if (matchAlt != null) {
          final n = int.tryParse(matchAlt.group(1) ?? '0') ?? 0;
          if (n > maxSeq) maxSeq = n;
        }
      }
    }
    final nextSeq = maxSeq + 1;
    return 'REC-$y-${nextSeq.toString().padLeft(3, '0')}';
  }

  // ─── STUDENT CRUD ─────────────────────────────────────────────────────────

  static bool _studentColumnsVerified = false;
  Future<void> _ensureStudentColumns(Database db) async {
    if (_studentColumnsVerified) return;
    for (final col in [
      'aadhaarNumber TEXT',
      'aadhaarDocPath TEXT',
      'aadhaarDocUrl TEXT',
      'aadhaarCardUrl TEXT',
    ]) {
      try {
        await db.execute('ALTER TABLE students ADD COLUMN $col');
      } catch (_) {}
    }
    _studentColumnsVerified = true;
  }

  Future<void> insertStudent(StudentModel student) async {
    final db = await database;
    await _ensureStudentColumns(db);
    await db.insert('students', student.toDbMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('fees', {
      'studentId': student.id,
      'totalFees': 0.0,
      'paidFees': 0.0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // Background sync to Firestore — non-blocking so SQLite save is instant
    FirestoreService.instance.syncStudent(student).catchError((e) {
      debugPrint('[DatabaseService] Firestore syncStudent note: $e');
      return null;
    });
  }

  /// Upserts a student that arrived from a Firestore real-time snapshot into SQLite ONLY.
  /// Does NOT trigger a syncStudent back to Firestore to avoid infinite round-trips.
  Future<void> upsertStudentFromRemote(StudentModel student) async {
    final db = await database;
    await _ensureStudentColumns(db);
    await db.insert('students', student.toDbMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    
    // Upsert fee metadata if embedded in student document from website
    final total = student.initialTotalFees ?? 0.0;
    final paid = student.initialPaidFees ?? 0.0;
    if (total > 0 || paid > 0) {
      await db.insert('fees', {
        'studentId': student.id,
        'totalFees': total,
        'paidFees': paid,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await db.insert('fees', {
        'studentId': student.id,
        'totalFees': 0.0,
        'paidFees': 0.0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    if (student.monthlyFee != null && student.monthlyFee! > 0) {
      await saveFeeStructure(
        studentId: student.id,
        tuitionFee: student.monthlyFee!,
      );
    }
  }

  /// Bulk upserts remote students using a fast SQLite batch
  Future<void> bulkUpsertStudentsFromRemote(List<StudentModel> students) async {
    if (students.isEmpty) return;
    final db = await database;
    await _ensureStudentColumns(db);
    final batch = db.batch();
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final currentMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final existingPaidMap = <String, double>{};
    try {
      final existingRows = await db.query('monthly_fees', columns: ['id', 'paidAmount']);
      for (final r in existingRows) {
        final rId = r['id']?.toString() ?? '';
        final amt = (r['paidAmount'] as num?)?.toDouble() ?? 0.0;
        if (rId.isNotEmpty && amt > 0) existingPaidMap[rId] = amt;
      }
    } catch (_) {}

    final seenAdmissionNumbers = <String>{};
    final seenStudentIds = <String>{};

    for (final student in students) {
      final fs = student.feeStructure;
      double mFee = student.monthlyFee ?? 0.0;
      if (fs != null && fs['tuitionFee'] != null && (fs['tuitionFee'] as num) > 0) {
        mFee = (fs['tuitionFee'] as num).toDouble();
      }
      final dbMap = student.toDbMap();
      if (mFee > 0) {
        dbMap['monthlyFee'] = mFee;
      }

      // Safeguard against duplicate admissionNumber / studentId replacing other rows in SQLite
      var adm = (dbMap['admissionNumber']?.toString() ?? '').trim();
      if (adm.isEmpty) {
        adm = 'ADM-${student.id}';
        dbMap['admissionNumber'] = adm;
      }
      if (seenAdmissionNumbers.contains(adm)) {
        adm = '${adm}_${student.id}';
        dbMap['admissionNumber'] = adm;
      }
      seenAdmissionNumbers.add(adm);

      var sId = (dbMap['studentId']?.toString() ?? '').trim();
      if (sId.isEmpty) {
        sId = student.id;
        dbMap['studentId'] = sId;
      }
      if (seenStudentIds.contains(sId)) {
        sId = '${sId}_${student.id}';
        dbMap['studentId'] = sId;
      }
      seenStudentIds.add(sId);

      batch.insert('students', dbMap, conflictAlgorithm: ConflictAlgorithm.replace);
      final total = student.initialTotalFees ?? 0.0;
      final paid = student.initialPaidFees ?? 0.0;
      final isExplicitPaid = student.feeStatus == 'Paid' || (total > 0 && paid >= total);
      final hasExplicitRemaining = !isExplicitPaid &&
          ((student.remainingFees != null && student.remainingFees! > 0) ||
           (student.totalPending != null && student.totalPending! > 0));

      // Determine real dynamic monthly demand if particulars are available for current month
      double computedTotal = total;
      double computedRemaining = isExplicitPaid
          ? 0.0
          : (student.remainingFees ?? student.totalPending ?? (total > paid ? total - paid : (mFee > 0 ? mFee : 0.0)));

      if (!hasExplicitRemaining && !isExplicitPaid && student.studentType != 'computer') {
        final tFee = (fs != null ? (fs['tuitionFee'] as num?)?.toDouble() : null) ?? mFee;
        if (student.monthlyParticulars != null && student.monthlyParticulars!.containsKey(currentMonthKey)) {
          final currP = student.monthlyParticulars![currentMonthKey];
          if (currP is Map) {
            final tDue = (currP['totalDue'] as num?)?.toDouble() ?? 0.0;
            if (tDue > 0) {
              computedTotal = tDue;
              computedRemaining = (tDue - paid).clamp(0.0, double.infinity);
            }
          }
        } else if (tFee > 0 || (student.previousDue ?? 0.0) > 0) {
          final prevDue = student.previousDue ?? 0.0;
          computedTotal = prevDue + tFee;
          computedRemaining = (computedTotal - paid).clamp(0.0, double.infinity);
        }
      }

      if (isExplicitPaid) {
        computedRemaining = 0.0;
      } else if (hasExplicitRemaining) {
        computedRemaining = student.remainingFees ?? student.totalPending!;
        if (computedTotal < paid + computedRemaining) {
          computedTotal = paid + computedRemaining;
        }
      }

      final status = isExplicitPaid
          ? 'Paid'
          : (student.feeStatus ?? (computedRemaining <= 0 && (computedTotal > 0 || paid > 0) ? 'Paid' : (paid > 0 ? 'Pending' : 'Unpaid')));

      final feeMap = {
        'studentId': student.id,
        'totalFees': computedTotal > 0 ? computedTotal : (mFee > 0 ? mFee : computedRemaining),
        'paidFees': paid,
        'remainingFees': computedRemaining,
        'totalPending': computedRemaining,
        'monthlyFee': mFee,
        'feeStatus': status,
      };
      batch.insert('fees', feeMap, conflictAlgorithm: ConflictAlgorithm.replace);

      if (fs != null) {
        final tuition = (fs['tuitionFee'] as num?)?.toDouble() ?? mFee;
        final fsMap = {
          'studentId': student.id,
          'tuitionFee': tuition,
          'transportFee': (fs['transportFee'] as num?)?.toDouble() ?? 0.0,
          'gameFee': (fs['gameFee'] as num?)?.toDouble() ?? 0.0,
          'dueDay': (fs['dueDay'] as num?)?.toInt() ?? 10,
          'finePerDay': (fs['finePerDay'] ?? fs['lateFinePerDay'] as num?)?.toDouble() ?? 0.0,
          'updatedAt': nowIso,
        };
        batch.insert('fee_structures', fsMap, conflictAlgorithm: ConflictAlgorithm.replace);
        if (student.studentId.isNotEmpty && student.studentId != student.id) {
          batch.insert('fee_structures', {
            ...fsMap,
            'studentId': student.studentId,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      } else if (mFee > 0) {
        final fsMap = {
          'studentId': student.id,
          'tuitionFee': mFee,
          'transportFee': 0.0,
          'gameFee': 0.0,
          'dueDay': 10,
          'finePerDay': 0.0,
          'updatedAt': nowIso,
        };
        batch.insert('fee_structures', fsMap, conflictAlgorithm: ConflictAlgorithm.replace);
        if (student.studentId.isNotEmpty && student.studentId != student.id) {
          batch.insert('fee_structures', {
            ...fsMap,
            'studentId': student.studentId,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      if (student.monthlyParticulars != null) {
        for (final entry in student.monthlyParticulars!.entries) {
          final mKey = entry.key.toString();
          if (entry.value is Map) {
            final p = entry.value as Map;
            final tFee = (p['tuitionFee'] as num?)?.toDouble() ?? (mFee > 0 ? mFee : (fs != null ? (fs['tuitionFee'] as num?)?.toDouble() ?? 0.0 : 0.0));
            final prevDue = (p['previousDues'] ?? p['previousDue'] as num?)?.toDouble() ?? 0.0;
            final rawIncomingPaid = (p['paidAmount'] ?? p['paidFees'] ?? p['totalPaid'] ?? p['paidInMonth'] as num?)?.toDouble() ?? 0.0;
            final primaryId = '${student.id}_$mKey';
            final altId = student.studentId.isNotEmpty ? '${student.studentId}_$mKey' : '';
            final existingPaid = existingPaidMap[primaryId] ?? (altId.isNotEmpty ? existingPaidMap[altId] : null) ?? 0.0;
            final effectivePaid = rawIncomingPaid > existingPaid ? rawIncomingPaid : existingPaid;

            final mFeeRow = {
              'id': primaryId,
              'studentId': student.id,
              'month': mKey,
              'admissionFee': (p['admissionFee'] as num?)?.toDouble() ?? 0.0,
              'tuitionFee': tFee,
              'monthlyFee': tFee,
              'examinationFee': (p['examinationFee'] as num?)?.toDouble() ?? 0.0,
              'previousDue': prevDue,
              'gameFee': (p['gameFee'] as num?)?.toDouble() ?? 0.0,
              'reAdmissionFee': (p['reAdmissionFee'] as num?)?.toDouble() ?? 0.0,
              'developmentFee': (p['developmentFee'] as num?)?.toDouble() ?? 0.0,
              'schoolIdFee': (p['schoolId'] ?? p['schoolIdFee'] as num?)?.toDouble() ?? 0.0,
              'tieBagBeltFee': (p['tieBagBelt'] ?? p['tieBagBeltFee'] as num?)?.toDouble() ?? 0.0,
              'backDues': (p['backDues'] as num?)?.toDouble() ?? 0.0,
              'transportFee': (p['transportFee'] as num?)?.toDouble() ?? 0.0,
              'otherFee': (p['otherFee'] as num?)?.toDouble() ?? 0.0,
              'paidAmount': effectivePaid,
              'lateFine': (p['lateFine'] as num?)?.toDouble() ?? 0.0,
              'dueDate': p['dueDate']?.toString(),
              'createdAt': nowIso,
              'updatedAt': nowIso,
            };
            batch.insert('monthly_fees', mFeeRow, conflictAlgorithm: ConflictAlgorithm.replace);
            if (altId.isNotEmpty && student.studentId != student.id) {
              batch.insert('monthly_fees', {
                ...mFeeRow,
                'id': altId,
                'studentId': student.studentId,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }
        }
      }
    }
    await batch.commit(noResult: true);
  }

  /// Bulk upserts remote payments using a fast SQLite batch with deduplication and canonical student mapping
  Future<void> bulkUpsertPaymentsFromRemote(List<PaymentModel> payments) async {
    if (payments.isEmpty) return;
    final db = await database;
    final students = await db.query('students', columns: ['id', 'studentId', 'admissionNumber']);
    final idMap = <String, String>{};
    for (final s in students) {
      final canonical = s['id']?.toString() ?? '';
      if (canonical.isEmpty) continue;
      idMap[canonical] = canonical;
      final sId = s['studentId']?.toString() ?? '';
      if (sId.isNotEmpty) idMap[sId] = canonical;
      final adm = s['admissionNumber']?.toString() ?? '';
      if (adm.isNotEmpty) idMap[adm] = canonical;
    }

    // Load existing payments once to guard against Firestore overwriting local data
    // with a stale/lower amount (which caused dashboard collected to drop).
    final existingRows = await db.query('payments', columns: ['id', 'amount']);
    final existingAmounts = <String, double>{};
    for (final r in existingRows) {
      final rid = r['id']?.toString() ?? '';
      if (rid.isNotEmpty) existingAmounts[rid] = (r['amount'] as num?)?.toDouble() ?? 0.0;
    }

    final batch = db.batch();
    for (final p in payments) {
      final map = p.toMap();
      final canonicalStudentId = idMap[p.studentId] ?? p.studentId;
      final cleanId = p.receiptNumber.trim().isNotEmpty ? p.receiptNumber.trim() : p.id;
      map['id'] = cleanId;
      map['studentId'] = canonicalStudentId;

      // Never let Firestore downgrade a payment amount that exists locally.
      final localAmt = existingAmounts[cleanId];
      if (localAmt != null && localAmt > (p.amount)) {
        map['amount'] = localAmt; // keep the higher local value
      }

      // Only delete duplicates with a DIFFERENT id but same receiptNumber
      if (p.receiptNumber.trim().isNotEmpty) {
        batch.delete('payments', where: 'receiptNumber = ? AND id != ?', whereArgs: [p.receiptNumber.trim(), cleanId]);
      }
      // ignore: local record already exists and is correct; replace only for new/same records
      batch.insert('payments', map, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Bulk upserts remote fees into local SQLite
  Future<void> bulkUpsertFeesFromRemote(List<Map<String, dynamic>> feesList) async {
    for (final f in feesList) {
      final sId = f['studentId']?.toString() ?? f['id']?.toString() ?? '';
      if (sId.isNotEmpty) {
        await upsertFeeFromRemote(sId, f);
      }
    }
  }

  /// Bulk upserts remote monthly fees into local SQLite
  Future<void> bulkUpsertMonthlyFeesFromRemote(List<MonthlyFeeModel> monthlyFees) async {
    if (monthlyFees.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    final existingPaidMap = <String, double>{};
    try {
      final existingRows = await db.query('monthly_fees', columns: ['id', 'paidAmount']);
      for (final r in existingRows) {
        final rId = r['id']?.toString() ?? '';
        final amt = (r['paidAmount'] as num?)?.toDouble() ?? 0.0;
        if (rId.isNotEmpty && amt > 0) existingPaidMap[rId] = amt;
      }
    } catch (_) {}

    for (final mf in monthlyFees) {
      final map = mf.toMap();
      final existingPaid = existingPaidMap[mf.id] ?? 0.0;
      if (existingPaid > mf.paidAmount) {
        map['paidAmount'] = existingPaid;
      }
      batch.insert('monthly_fees', map, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Upserts fee fields (totalFees/paidFees/dueDate/lastPaidDate) that
  /// arrived from a Firestore real-time snapshot, keyed by studentId or docId.
  Future<void> upsertFeeFromRemote(String studentId, Map<String, dynamic> data) async {
    final db = await database;
    final matching = await db.query(
      'students',
      where: 'id = ? OR studentId = ?',
      whereArgs: [studentId, studentId],
    );
    final resolvedStudentId = matching.isNotEmpty ? (matching.first['id'] as String) : studentId;

    double safeNum(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString().trim()) ?? 0.0;
    }

    double? safeNumNullable(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString().trim());
    }

    final rawTotal = safeNum(data['totalFees']);
    final rawTotalAlt = safeNum(data['totalFee']);
    final totalFees = rawTotal > 0 ? rawTotal : rawTotalAlt;

    final rawPaid = safeNum(data['paidFees']);
    final rawPaidAlt = safeNum(data['totalPaid']);
    final paidFees = rawPaid > 0 ? rawPaid : rawPaidAlt;

    final rem1 = safeNumNullable(data['remainingFees']);
    final rem2 = safeNumNullable(data['totalPending']);
    final rem3 = safeNumNullable(data['balanceDue']);
    final double? remainingFees = (rem1 != null && rem1 > 0)
        ? rem1
        : ((rem2 != null && rem2 > 0)
            ? rem2
            : ((rem3 != null && rem3 > 0) ? rem3 : (rem1 ?? rem2 ?? rem3)));

    final feeStatus = data['feeStatus']?.toString() ?? data['status']?.toString();
    var dueDate = data['dueDate']?.toString();
    if (dueDate == null || dueDate.isEmpty || dueDate == 'null') {
      final now = DateTime.now();
      dueDate = DateTime(now.year, now.month, 10).toIso8601String();
    }
    final lastPaidDate = data['lastPaidDate']?.toString();
    final monthlyFee = safeNum(data['monthlyFee']);

    // Reconcile with actual recorded payments so paidFees is never downgraded
    final paymentRows = await db.query(
      'payments',
      columns: ['amount'],
      where: 'studentId = ?',
      whereArgs: [resolvedStudentId],
    );
    final paymentsSum = paymentRows.fold<double>(0.0, (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0.0));
    final finalPaid = paymentsSum > paidFees ? paymentsSum : paidFees;
    final studentTotalFees = matching.isNotEmpty ? safeNum(matching.first['totalFees']) : 0.0;
    final effectiveTotal = studentTotalFees > 0 ? studentTotalFees : (totalFees > 0 ? totalFees : (finalPaid + (remainingFees ?? 0.0)));
    final finalTotal = effectiveTotal < finalPaid ? finalPaid : effectiveTotal;
    final isExplicitPaid = feeStatus == 'Paid' || (finalTotal > 0 && finalPaid >= finalTotal);
    final computedRemaining = (finalTotal - finalPaid).clamp(0.0, double.infinity).toDouble();
    final finalRemaining = isExplicitPaid ? 0.0 : (remainingFees != null ? (computedRemaining == 0.0 ? 0.0 : remainingFees) : computedRemaining);

    await db.insert(
      'fees',
      {
        'studentId': resolvedStudentId,
        'totalFees': finalTotal,
        'paidFees': finalPaid,
        'remainingFees': finalRemaining,
        'totalPending': finalRemaining,
        'monthlyFee': monthlyFee,
        'feeStatus': feeStatus,
        'dueDate': dueDate,
        'lastPaidDate': lastPaidDate,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // If recurring structure / monthlyFee is present in fee doc, sync it
    if (data['feeStructure'] is Map) {
      final fs = data['feeStructure'] as Map;
      await saveFeeStructure(
        studentId: resolvedStudentId,
        tuitionFee: (fs['tuitionFee'] as num?)?.toDouble() ?? monthlyFee,
        transportFee: (fs['transportFee'] as num?)?.toDouble() ?? 0.0,
        gameFee: (fs['gameFee'] as num?)?.toDouble() ?? 0.0,
        dueDay: (fs['dueDay'] as num?)?.toInt() ?? 10,
        finePerDay: (fs['finePerDay'] as num?)?.toDouble() ?? 0.0,
      );
    } else if (monthlyFee > 0) {
      await saveFeeStructure(
        studentId: resolvedStudentId,
        tuitionFee: monthlyFee,
      );
    }

    // Sync monthly particulars if present in fee doc
    if (data['monthlyParticulars'] is Map) {
      final mpMap = data['monthlyParticulars'] as Map;
      for (final entry in mpMap.entries) {
        final monthKey = entry.key.toString();
        if (entry.value is Map) {
          final p = entry.value as Map;
          final existing = await getMonthlyFee(resolvedStudentId, monthKey);
          final paidForMonth = await getMonthlyPaidAmount(resolvedStudentId, monthKey);
          final now = DateTime.now();

          final fee = MonthlyFeeModel(
            id: existing?.id ?? const Uuid().v4(),
            studentId: resolvedStudentId,
            month: monthKey,
            admissionFee: (p['admissionFee'] as num?)?.toDouble() ?? (existing?.admissionFee ?? 0.0),
            tuitionFee: (p['tuitionFee'] as num?)?.toDouble() ?? (existing?.tuitionFee ?? monthlyFee),
            examinationFee: (p['examinationFee'] as num?)?.toDouble() ?? (existing?.examinationFee ?? 0.0),
            previousDue: (p['previousDues'] ?? p['previousDue'] as num?)?.toDouble() ?? 0.0,
            gameFee: (p['gameFee'] as num?)?.toDouble() ?? (existing?.gameFee ?? 0.0),
            reAdmissionFee: (p['reAdmissionFee'] as num?)?.toDouble() ?? (existing?.reAdmissionFee ?? 0.0),
            developmentFee: (p['developmentFee'] as num?)?.toDouble() ?? (existing?.developmentFee ?? 0.0),
            schoolIdFee: (p['schoolId'] ?? p['schoolIdFee'] as num?)?.toDouble() ?? (existing?.schoolIdFee ?? 0.0),
            tieBagBeltFee: (p['tieBagBelt'] ?? p['tieBagBeltFee'] as num?)?.toDouble() ?? (existing?.tieBagBeltFee ?? 0.0),
            backDues: (p['backDues'] as num?)?.toDouble() ?? (existing?.backDues ?? 0.0),
            transportFee: (p['transportFee'] as num?)?.toDouble() ?? (existing?.transportFee ?? 0.0),
            otherFee: (p['otherFee'] as num?)?.toDouble() ?? (existing?.otherFee ?? 0.0),
            paidAmount: paidForMonth > (existing?.paidAmount ?? 0.0) ? paidForMonth : (existing?.paidAmount ?? 0.0),
            lateFine: (p['lateFine'] as num?)?.toDouble() ?? (existing?.lateFine ?? 0.0),
            dueDate: DateTime.tryParse(p['dueDate']?.toString() ?? '') ?? existing?.dueDate,
            lastPaymentDate: existing?.lastPaymentDate,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
            remarks: p['remarks']?.toString() ?? existing?.remarks,
          );
          await _saveMonthlyFeeRow(fee);
        }
      }
    }
  }

  Future<bool> isAdmissionNumberExists(String admissionNumber, {String? excludeId}) async {
    if (admissionNumber.trim().isEmpty) return false;
    if (kIsWeb) {
      final list = await getAllStudents();
      return list.any((s) => s.admissionNumber == admissionNumber && s.id != excludeId);
    }
    final db = await database;
    final result = await db.query(
      'students',
      where: excludeId != null
          ? 'admissionNumber = ? AND id != ?'
          : 'admissionNumber = ?',
      whereArgs: excludeId != null ? [admissionNumber, excludeId] : [admissionNumber],
    );
    return result.isNotEmpty;
  }

  Future<bool> isStudentIdExists(String studentId, {String? excludeId}) async {
    if (studentId.trim().isEmpty) return false;
    if (kIsWeb) {
      final list = await getAllStudents();
      return list.any((s) => s.studentId == studentId && s.id != excludeId);
    }
    final db = await database;
    final result = await db.query(
      'students',
      where: excludeId != null
          ? 'studentId = ? AND id != ?'
          : 'studentId = ?',
      whereArgs: excludeId != null ? [studentId, excludeId] : [studentId],
    );
    return result.isNotEmpty;
  }


  Future<List<StudentModel>> getAllStudents() async {
    if (kIsWeb) {
      return FirestoreService.instance.fetchStudents();
    }
    final db = await database;
    final maps = await db.query('students', orderBy: 'createdAt DESC');
    final fsMaps = await db.query('fee_structures');
    final fsByStudent = <String, Map<String, dynamic>>{};
    for (final row in fsMaps) {
      final sId = row['studentId']?.toString() ?? '';
      if (sId.isNotEmpty) fsByStudent[sId] = row;
    }

    return maps.map((m) {
      final sId = m['id']?.toString() ?? '';
      final altId = m['studentId']?.toString() ?? '';
      final structRow = fsByStudent[sId] ?? (altId.isNotEmpty ? fsByStudent[altId] : null);
      if (structRow != null) {
        final mutable = Map<String, dynamic>.from(m);
        final tuition = (structRow['tuitionFee'] as num?)?.toDouble() ?? 0.0;
        final currMonthly = (m['monthlyFee'] as num?)?.toDouble() ?? 0.0;
        mutable['feeStructure'] = {
          'tuitionFee': tuition > 0 ? tuition : currMonthly,
          'transportFee': structRow['transportFee'],
          'gameFee': structRow['gameFee'],
          'dueDay': structRow['dueDay'],
          'finePerDay': structRow['finePerDay'],
        };
        if (tuition > 0 && currMonthly == 0) {
          mutable['monthlyFee'] = tuition;
        }
        return StudentModel.fromMap(mutable);
      }
      return StudentModel.fromMap(m);
    }).toList();
  }

  Future<StudentModel?> getStudentById(String id) async {
    final clean = id.trim();
    if (clean.isEmpty) return null;
    if (kIsWeb) {
      final list = await getAllStudents();
      try {
        return list.firstWhere((s) =>
            s.id == clean ||
            s.studentId.toLowerCase() == clean.toLowerCase() ||
            s.admissionNumber.toLowerCase() == clean.toLowerCase());
      } catch (_) {
        return null;
      }
    }
    final db = await database;
    final maps = await db.query(
      'students',
      where: 'id = ? OR studentId = ? OR admissionNumber = ?',
      whereArgs: [clean, clean, clean],
    );
    if (maps.isEmpty) return null;
    return StudentModel.fromMap(maps.first);
  }

  Future<StudentModel?> getStudentByQrId(String lookup) async {
    final clean = lookup.trim();
    if (clean.isEmpty) return null;
    if (kIsWeb) {
      final list = await getAllStudents();
      try {
        return list.firstWhere((s) =>
            s.studentId.toLowerCase() == clean.toLowerCase() ||
            s.id.toLowerCase() == clean.toLowerCase() ||
            s.admissionNumber.toLowerCase() == clean.toLowerCase());
      } catch (_) {
        return null;
      }
    }
    final db = await database;
    final maps = await db.query(
      'students',
      where: 'studentId = ? OR id = ? OR LOWER(admissionNumber) = ?',
      whereArgs: [clean, clean, clean.toLowerCase()],
      limit: 1,
    );
    if (maps.isNotEmpty) return StudentModel.fromMap(maps.first);

    // Also check numeric match on admission number
    final digits = clean.replaceAll(RegExp(r'\D'), '');
    if (digits.isNotEmpty) {
      final all = await getAllStudents();
      for (final s in all) {
        if (s.admissionNumber.replaceAll(RegExp(r'\D'), '') == digits ||
            s.studentId.replaceAll(RegExp(r'\D'), '') == digits) {
          return s;
        }
      }
    }
    return null;
  }

  Future<List<StudentModel>> searchStudents(String query) async {
    if (kIsWeb) {
      final list = await getAllStudents();
      final q = query.toLowerCase();
      return list.where((s) =>
      s.name.toLowerCase().contains(q) ||
          s.admissionNumber.toLowerCase().contains(q) ||
          s.studentId.toLowerCase().contains(q) ||
          s.mobile.contains(q) ||
          s.fatherName.toLowerCase().contains(q)
      ).toList();
    }
    final db = await database;
    final q = '%$query%';
    final maps = await db.query(
      'students',
      where: 'name LIKE ? OR admissionNumber LIKE ? OR studentId LIKE ? OR mobile LIKE ? OR fatherName LIKE ?',
      whereArgs: [q, q, q, q, q],
      orderBy: 'name ASC',
    );
    return maps.map(StudentModel.fromMap).toList();
  }

  Future<List<StudentModel>> getStudentsByFilter({
    String? type, // school | computer
    String? status, // active | completed | left | suspended
    String? className,
    String? section,
    String? course,
    String? batch,
    String? session,
  }) async {
    if (kIsWeb) {
      final list = await getAllStudents();
      return list.where((s) {
        if (type != null && type != 'all' && s.studentType != type) return false;
        if (status != null && status != 'all' && s.status != status) return false;
        if (className != null && className.isNotEmpty && s.className != className) return false;
        if (section != null && section.isNotEmpty && s.section != section) return false;
        if (course != null && course.isNotEmpty && s.course != course) return false;
        if (batch != null && batch.isNotEmpty && s.batch != batch) return false;
        if (session != null && session.isNotEmpty && s.session != session) return false;
        return true;
      }).toList();
    }
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (type != null && type != 'all') { conditions.add('studentType = ?'); args.add(type); }
    if (status != null && status != 'all') { conditions.add('status = ?'); args.add(status); }
    if (className != null && className.isNotEmpty) { conditions.add('className = ?'); args.add(className); }
    if (section != null && section.isNotEmpty) { conditions.add('section = ?'); args.add(section); }
    if (course != null && course.isNotEmpty) { conditions.add('course = ?'); args.add(course); }
    if (batch != null && batch.isNotEmpty) { conditions.add('batch = ?'); args.add(batch); }
    if (session != null && session.isNotEmpty) { conditions.add('session = ?'); args.add(session); }

    final where = conditions.isEmpty ? null : conditions.join(' AND ');
    final maps = await db.query('students', where: where, whereArgs: args.isEmpty ? null : args, orderBy: 'name ASC');
    return maps.map(StudentModel.fromMap).toList();
  }

  Future<void> updateStudent(StudentModel student) async {
    final db = await database;
    await _ensureStudentColumns(db);
    await db.update('students', student.toDbMap(), where: 'id = ?', whereArgs: [student.id]);
    FirestoreService.instance.syncStudent(student).catchError((e) {
      debugPrint('[DatabaseService] Firestore updateStudent note: $e');
      return null;
    });
  }

  /// Batch promotes students to the next academic class and session
  Future<int> promoteStudents({
    required List<String> studentIds,
    required String targetClass,
    String? targetSection,
    required String targetSession,
    bool isPassout = false,
    double? newMonthlyFee,
    double? newTotalFee,
  }) async {
    final db = await database;
    int count = 0;
    for (final id in studentIds) {
      final student = await getStudentById(id);
      if (student == null) continue;

      final updated = student.copyWith(
        className: isPassout ? student.className : targetClass,
        section: (targetSection != null && targetSection.isNotEmpty) ? targetSection : student.section,
        session: targetSession,
        status: isPassout ? 'completed' : 'active',
      );

      await db.update('students', updated.toMap(), where: 'id = ?', whereArgs: [id]);
      FirestoreService.instance.syncStudent(updated).catchError((e) {
        debugPrint('[DatabaseService] Firestore promote syncStudent note: $e');
        return null;
      });

      if (newMonthlyFee != null && newMonthlyFee > 0) {
        await saveFeeStructure(studentId: id, tuitionFee: newMonthlyFee);
      }
      if (newTotalFee != null && newTotalFee > 0) {
        await db.update('fees', {'totalFees': newTotalFee}, where: 'studentId = ?', whereArgs: [id]);
      }
      count++;
    }
    return count;
  }

  Future<void> deleteStudent(String id) async {
    final s = await getStudentById(id) ?? await getStudentByQrId(id);
    final altIds = <String>{
      if (s != null && s.studentId.isNotEmpty) s.studentId,
      if (s != null && s.admissionNumber.isNotEmpty) s.admissionNumber,
    };
    await deleteStudentLocalOnly(id);
    if (s != null && s.studentId.isNotEmpty && s.studentId != id) {
      await deleteStudentLocalOnly(s.studentId);
    }
    FirestoreService.instance.deleteStudent(id, altIds: altIds).catchError((e) {
      debugPrint('[DatabaseService] Firestore deleteStudent note: $e');
      return null;
    });
  }

  /// Deletes a student and all related tables in SQLite ONLY (used during Firestore stream reconciliation)
  Future<void> deleteStudentLocalOnly(String id) async {
    final db = await database;
    final resultRows = await db.query('results', columns: ['id'], where: 'studentId = ?', whereArgs: [id]);
    await db.transaction((txn) async {
      await txn.delete('students', where: 'id = ?', whereArgs: [id]);
      await txn.delete('fees', where: 'studentId = ?', whereArgs: [id]);
      await txn.delete('payments', where: 'studentId = ?', whereArgs: [id]);
      await txn.delete('attendance', where: 'studentId = ?', whereArgs: [id]);
      await txn.delete('monthly_fees', where: 'studentId = ?', whereArgs: [id]);
      await txn.delete('fee_structures', where: 'studentId = ?', whereArgs: [id]);
      for (final row in resultRows) {
        await txn.delete('subject_results', where: 'resultId = ?', whereArgs: [row['id']]);
      }
      await txn.delete('results', where: 'studentId = ?', whereArgs: [id]);
    });
  }

  Future<int> getStudentCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM students');
    return result.first['count'] as int;
  }

  Future<int> getStudentCountByType(String type) async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM students WHERE studentType = ?', [type]);
    return result.first['count'] as int;
  }

  Future<Map<String, int>> getStudentsByClass() async {
    final db = await database;
    final result = await db.rawQuery(
        "SELECT className, COUNT(*) as count FROM students WHERE studentType = 'school' AND className IS NOT NULL GROUP BY className ORDER BY CAST(className AS INTEGER)");
    return {for (var row in result) (row['className'] as String): row['count'] as int};
  }

  Future<Map<String, int>> getStudentsByCourse() async {
    final db = await database;
    final result = await db.rawQuery(
        "SELECT course, COUNT(*) as count FROM students WHERE studentType = 'computer' AND course IS NOT NULL GROUP BY course");
    return {for (var row in result) (row['course'] as String): row['count'] as int};
  }

  // ─── FEE CRUD ─────────────────────────────────────────────────────────────

  Future<FeeModel?> getFeeByStudentId(String studentId) async {
    final map = await getAllFeesMap();
    return map[studentId];
  }

  /// Batch-load all fees with payments — avoids N+1 queries during export and computes dynamic monthly fee demand.
  Future<Map<String, FeeModel>> getAllFeesMap() async {
    final db = await database;
    final students = await db.query('students');
    final feeStructures = await db.query('fee_structures');
    final monthlyFees = await db.query('monthly_fees');
    final fees = await db.query('fees');
    final payments = await db.query('payments', orderBy: 'paymentDate DESC');

    final allPaymentsList = payments.map(PaymentModel.fromMap).toList();
    final paymentsByStudent = <String, List<PaymentModel>>{};
    for (final payment in allPaymentsList) {
      paymentsByStudent.putIfAbsent(payment.studentId, () => []).add(payment);
    }

    final feeStructuresByStudent = <String, StudentFeeStructureModel>{};
    for (final row in feeStructures) {
      final s = _feeStructureFromRow(row);
      feeStructuresByStudent[s.studentId] = s;
    }

    final feesByStudent = <String, Map<String, dynamic>>{};
    for (final row in fees) {
      final sId = row['studentId']?.toString() ?? '';
      if (sId.isNotEmpty) feesByStudent[sId] = row;
    }

    final now = DateTime.now();
    final currentMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final monthlyFeesByStudent = <String, Map<String, MonthlyFeeModel>>{};
    for (final row in monthlyFees) {
      final f = _monthlyFeeFromRow(row);
      monthlyFeesByStudent.putIfAbsent(f.studentId, () => {})[f.month] = f;
    }

    final result = <String, FeeModel>{};

    // Process all students
    for (final sRow in students) {
      final studentId = sRow['id'] as String? ?? '';
      final studentAltId = sRow['studentId'] as String? ?? '';
      final studentAdmNo = sRow['admissionNumber'] as String? ?? '';
      final studentName = (sRow['name'] as String? ?? '').trim().toLowerCase();
      if (studentId.isEmpty && studentAltId.isEmpty) continue;

      final keyId = studentId.isNotEmpty ? studentId : studentAltId;

      final rawStudentPayments = allPaymentsList.where((p) {
        return p.studentId == studentId ||
            (studentAltId.isNotEmpty && p.studentId == studentAltId) ||
            (studentAdmNo.isNotEmpty && p.admissionNumber == studentAdmNo) ||
            (studentName.isNotEmpty && p.studentName?.trim().toLowerCase() == studentName);
      }).toList();

      // Deduplicate student payments by receiptNumber
      final seenRec = <String>{};
      final studentPayments = <PaymentModel>[];
      for (final p in rawStudentPayments) {
        final key = p.receiptNumber.trim().isNotEmpty ? p.receiptNumber.trim() : p.id;
        if (seenRec.add(key)) {
          studentPayments.add(p);
        }
      }
      final paymentsSum = studentPayments.fold<double>(0.0, (sum, p) => sum + p.amount);

      double safeNum(dynamic v) {
        if (v == null) return 0.0;
        if (v is num) return v.toDouble();
        return double.tryParse(v.toString().trim()) ?? 0.0;
      }

      double? safeNumNullable(dynamic v) {
        if (v == null) return null;
        if (v is num) return v.toDouble();
        return double.tryParse(v.toString().trim());
      }

      final struct = feeStructuresByStudent[studentId] ?? (studentAltId.isNotEmpty ? feeStructuresByStudent[studentAltId] : null);
      final rawMonthly = safeNum(sRow['monthlyFee']);
      final monthlyFee = rawMonthly > 0 ? rawMonthly : (struct?.tuitionFee ?? 0.0);
      final recurringMonthly = (struct?.tuitionFee ?? monthlyFee) + (struct?.transportFee ?? 0.0) + (struct?.gameFee ?? 0.0);

      final sMonthlyMap = monthlyFeesByStudent[studentId] ?? (studentAltId.isNotEmpty ? monthlyFeesByStudent[studentAltId] ?? {} : {});
      final currMonthFee = sMonthlyMap[currentMonthKey];

      final feeRow = feesByStudent[studentId] ?? (studentAltId.isNotEmpty ? feesByStudent[studentAltId] : null);
      final flatTotalFromFeesTable = safeNum(feeRow?['totalFees']);
      final studentTotalFees = safeNum(sRow['totalFees']);

      final explicitRemaining = safeNumNullable(feeRow?['remainingFees']) ??
          safeNumNullable(feeRow?['totalPending']) ??
          safeNumNullable(sRow['remainingFees']) ??
          safeNumNullable(sRow['totalPending']);
      final studentType = sRow['studentType']?.toString() ?? 'school';
      final feeStatus = (sRow['feeStatus'] ?? feeRow?['feeStatus'] ?? feeRow?['status'])?.toString();
      final hasExplicitRemaining = explicitRemaining != null && explicitRemaining > 0;
      final isExplicitPaid = feeStatus == 'Paid' && !hasExplicitRemaining;

      double totalDemand = 0.0;
      DateTime? dueDate;
      DateTime? lastPaymentDate = DateTime.tryParse(feeRow?['lastPaidDate']?.toString() ?? '') ??
          (studentPayments.isNotEmpty ? studentPayments.first.paymentDate : null);
      double currentDue = 0.0;

      final feeRowPaid = safeNum(feeRow?['paidFees']);
      final sRowPaid = safeNum(sRow['paidFees']);
      final recordedPaid = feeRowPaid > sRowPaid ? feeRowPaid : sRowPaid;
      // Single source of truth for paid: if payments exist in payments table, trust paymentsSum!
      final double finalPaid = paymentsSum > 0 ? paymentsSum : recordedPaid;

      if (currMonthFee != null) {
        // Current month's fee from monthly_fees:
        final currMonthPaymentsPaid = studentPayments
            .where((p) {
              final mKey = PaymentModel.toMonthKey(p.feeMonth ?? p.monthKey, p.paymentDate);
              return mKey == currentMonthKey;
            })
            .fold<double>(0.0, (sum, p) => sum + p.amount);
        final effPaid = currMonthPaymentsPaid > currMonthFee.paidAmount ? currMonthPaymentsPaid : currMonthFee.paidAmount;
        currentDue = (currMonthFee.totalDue - effPaid).clamp(0.0, double.infinity);
        totalDemand = finalPaid + currentDue;
        dueDate = currMonthFee.dueDate ?? _dueDateFromStructure(currentMonthKey, struct);
      } else if (isExplicitPaid) {
        final rawTotal = studentTotalFees > 0 ? studentTotalFees : flatTotalFromFeesTable;
        totalDemand = rawTotal > 0 ? (rawTotal < finalPaid ? finalPaid : rawTotal) : finalPaid;
        currentDue = 0.0;
        dueDate = DateTime.tryParse(feeRow?['dueDate']?.toString() ?? '');
      } else if (hasExplicitRemaining) {
        final rawTotal = studentTotalFees > 0 ? studentTotalFees : flatTotalFromFeesTable;
        if (rawTotal > 0) {
          totalDemand = rawTotal < finalPaid ? finalPaid : rawTotal;
          currentDue = (totalDemand - finalPaid).clamp(0.0, double.infinity);
        } else {
          currentDue = explicitRemaining;
          totalDemand = finalPaid + currentDue;
        }
        dueDate = DateTime.tryParse(feeRow?['dueDate']?.toString() ?? '') ?? _dueDateFromStructure(currentMonthKey, struct);
      } else if (studentType == 'computer') {
        final rawTotal = studentTotalFees > 0 ? studentTotalFees : flatTotalFromFeesTable;
        totalDemand = rawTotal < finalPaid ? finalPaid : rawTotal;
        currentDue = (totalDemand - finalPaid).clamp(0.0, double.infinity);
        dueDate = DateTime.tryParse(feeRow?['dueDate']?.toString() ?? '') ?? _dueDateFromStructure(currentMonthKey, struct);
      } else if (studentType != 'computer' && recurringMonthly > 0) {
        final monthDue = safeNum(sRow['previousDue']) + recurringMonthly;
        totalDemand = monthDue < finalPaid ? finalPaid : monthDue;
        currentDue = (totalDemand - finalPaid).clamp(0.0, double.infinity);
        dueDate = _dueDateFromStructure(currentMonthKey, struct);
      } else if (flatTotalFromFeesTable > 0 || studentTotalFees > 0) {
        final rawTotal = studentTotalFees > 0 ? studentTotalFees : flatTotalFromFeesTable;
        totalDemand = rawTotal < finalPaid ? finalPaid : rawTotal;
        currentDue = (totalDemand - finalPaid).clamp(0.0, double.infinity);
        dueDate = DateTime.tryParse(feeRow?['dueDate']?.toString() ?? '') ?? _dueDateFromStructure(currentMonthKey, struct);
      } else {
        totalDemand = finalPaid;
        currentDue = 0.0;
      }

      final feeModel = FeeModel(
        studentId: keyId,
        totalFees: totalDemand,
        paidFees: finalPaid,
        explicitRemaining: currentDue,
        payments: studentPayments,
        dueDate: dueDate ?? DateTime.tryParse(feeRow?['dueDate']?.toString() ?? '') ?? (currentDue > 0 ? _dueDateFromStructure(currentMonthKey, struct) : null),
        lastPaidDate: lastPaymentDate,
      );

      result[keyId] = feeModel;
      if (studentId.isNotEmpty) result[studentId] = feeModel;
      if (studentAltId.isNotEmpty) result[studentAltId] = feeModel;
      if (studentAdmNo.isNotEmpty) result[studentAdmNo] = feeModel;
    }

    return result;
  }

  Future<void> updateFeeTotal(String studentId, double totalFees) async {
    final db = await database;
    await db.update('fees', {'totalFees': totalFees}, where: 'studentId = ?', whereArgs: [studentId]);
  }

  /// Directly SETS (not increments) fee values — used by Excel/PDF import.
  /// Unlike addPayment(), this never adds to paidFees, so re-importing the
  /// same file (Update Existing) can't double-count what was already
  /// imported. A payment history row is still created here (if paidFees >
  /// 0 and none exists yet from a prior import) so "Payment Mode" /
  /// "Last Payment Date" from the file are preserved and getTotalCollected()
  /// stays consistent with what the fees table shows.
  Future<void> setFeeFromImport(
      String studentId, {
        double? totalFees,
        double? paidFees,
        DateTime? lastPaymentDate,
        String? paymentMode,
      }) async {
    final db = await database;
    final updates = <String, Object?>{};
    if (totalFees != null) updates['totalFees'] = totalFees;
    if (paidFees != null) {
      updates['paidFees'] = paidFees;
      if (lastPaymentDate != null) updates['lastPaidDate'] = lastPaymentDate.toIso8601String();
    }
    if (updates.isNotEmpty) {
      await db.update('fees', updates, where: 'studentId = ?', whereArgs: [studentId]);
    }

    if (paidFees != null && paidFees > 0) {
      // Only record a payment history row the first time we import a paid
      // amount for this student — avoids piling up duplicate payment rows
      // if the same file is imported more than once.
      final existingPayments = await db.query('payments',
          where: 'studentId = ? AND remarks = ?',
          whereArgs: [studentId, 'Imported from file']);
      if (existingPayments.isEmpty) {
        final receipt = await generateReceiptNumber();
        await db.insert('payments', {
          'id': const Uuid().v4(),
          'studentId': studentId,
          'amount': paidFees,
          'paymentDate': (lastPaymentDate ?? DateTime.now()).toIso8601String(),
          'paymentMode': (paymentMode == null || paymentMode.isEmpty) ? 'Cash' : paymentMode,
          'remarks': 'Imported from file',
          'receiptNumber': receipt,
        });
      }
    }
  }

  Future<void> updateFeeDueDate(String studentId, DateTime? dueDate) async {
    final db = await database;
    await db.update('fees', {'dueDate': dueDate?.toIso8601String()},
        where: 'studentId = ?', whereArgs: [studentId]);
  }

  /// Imports the 12 fee particulars from an Excel row into the actual
  /// monthly-fee ledger (the one fee_screen.dart / the receipt / the
  /// demand slip all read from) — NOT the old flat totalFees/paidFees
  /// aggregate that setFeeFromImport() above writes to. Without this, an
  /// imported "Tuition Fee: 3000, Transport Fee: 800, ..." row never
  /// showed up anywhere the Principal actually looks.
  ///
  /// Target month is taken from the row's due date (YYYY-MM) when present,
  /// otherwise defaults to the current month — the import template has no
  /// separate "Month" column, so the due date doubles as the anchor.
  Future<void> importMonthlyFeeParticulars(
      String studentId, {
        required String month,
        double? admissionFee,
        double? tuitionFee,
        double? examinationFee,
        double? gameFee,
        double? reAdmissionFee,
        double? developmentFee,
        double? schoolIdFee,
        double? tieBagBeltFee,
        double? backDues,
        double? transportFee,
        double? otherFee,
        double? paidAmount,
        DateTime? dueDate,
      }) async {
    final hasAnyParticular = [
      admissionFee, tuitionFee, examinationFee, gameFee, reAdmissionFee,
      developmentFee, schoolIdFee, tieBagBeltFee, backDues, transportFee, otherFee,
    ].any((v) => v != null);
    if (!hasAnyParticular && paidAmount == null) return; // nothing to import for this row

    final additionalFees = <FeeLineItem>[
      FeeLineItem(key: 'admissionFee', label: 'Admission Fee', amount: admissionFee ?? 0),
      FeeLineItem(key: 'examinationFee', label: 'Examination Fee', amount: examinationFee ?? 0),
      FeeLineItem(key: 'gameFee', label: 'Game Fee', amount: gameFee ?? 0),
      FeeLineItem(key: 'reAdmissionFee', label: 'Re-Admission Fee', amount: reAdmissionFee ?? 0),
      FeeLineItem(key: 'developmentFee', label: 'Development Fee', amount: developmentFee ?? 0),
      FeeLineItem(key: 'schoolIdFee', label: 'School ID', amount: schoolIdFee ?? 0),
      FeeLineItem(key: 'tieBagBeltFee', label: 'Tie, Bag, Belt', amount: tieBagBeltFee ?? 0),
      FeeLineItem(key: 'backDues', label: 'Back Dues', amount: backDues ?? 0),
      FeeLineItem(key: 'transportFee', label: 'Transport Fee', amount: transportFee ?? 0),
      FeeLineItem(key: 'otherFee', label: 'Other Fee', amount: otherFee ?? 0),
    ];

    final saved = await saveMonthlyFeeStructure(
      studentId: studentId,
      month: month,
      tuitionFee: tuitionFee ?? 0,
      additionalFees: additionalFees,
      dueDate: dueDate,
      remarks: 'Imported from file',
    );

    if (paidAmount != null && paidAmount > 0 && paidAmount != saved.paidAmount) {
      await _saveMonthlyFeeRow(saved.copyWith(paidAmount: paidAmount, updatedAt: DateTime.now()));
      await _propagatePreviousDueForward(studentId, month);
      await refreshLegacyFeeAggregate(studentId);
    }
  }

  Future<void> addPayment(PaymentModel payment) async {
    final db = await database;
    final map = payment.toMap();
    final recNo = payment.receiptNumber.trim();
    final cleanId = recNo.isNotEmpty ? recNo : payment.id;
    map['id'] = cleanId;
    if (recNo.isNotEmpty) {
      await db.delete('payments', where: 'receiptNumber = ? AND id != ?', whereArgs: [recNo, cleanId]);
    }
    await db.insert('payments', map, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.rawUpdate(
      'UPDATE fees SET paidFees = paidFees + ?, lastPaidDate = ? WHERE studentId = ?',
      [payment.amount, payment.paymentDate.toIso8601String(), payment.studentId],
    );
  }

  Future<double> getTotalCollected() async {
    final db = await database;
    // Deduplicate by receiptNumber and only count payments belonging to existing students
    final students = await db.query('students', columns: ['id', 'studentId', 'admissionNumber']);
    final validStudentIds = <String>{};
    for (final s in students) {
      if (s['id'] != null) validStudentIds.add(s['id'].toString());
      if (s['studentId'] != null) validStudentIds.add(s['studentId'].toString());
      if (s['admissionNumber'] != null) validStudentIds.add(s['admissionNumber'].toString());
    }

    final rows = await db.query('payments');
    final seenReceipts = <String>{};
    double total = 0.0;

    for (final r in rows) {
      final sId = r['studentId']?.toString() ?? '';
      if (validStudentIds.isNotEmpty && !validStudentIds.contains(sId)) continue;

      final rec = (r['receiptNumber']?.toString() ?? '').trim();
      final dedupKey = rec.isNotEmpty ? rec : (r['id']?.toString() ?? '');
      if (dedupKey.isNotEmpty && !seenReceipts.add(dedupKey)) continue;

      total += (r['amount'] as num?)?.toDouble() ?? 0.0;
    }
    if (total == 0.0) {
      final sRows = await db.rawQuery('SELECT SUM(paidFees) as sumPaid FROM students');
      if (sRows.isNotEmpty) {
        total = (sRows.first['sumPaid'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return total;
  }

  Future<double> getTotalPendingFees() async {
    final feesMap = await getAllFeesMap();
    final seen = <String>{};
    double sum = 0.0;
    for (final fee in feesMap.values) {
      if (seen.add(fee.studentId) && fee.remaining > 0) {
        sum += fee.remaining;
      }
    }
    return sum;
  }

  Future<int> getOverdueFeeCount() async {
    final feesMap = await getAllFeesMap();
    final seen = <String>{};
    int count = 0;
    for (final fee in feesMap.values) {
      if (seen.add(fee.studentId) && fee.isOverdue) {
        count++;
      }
    }
    return count;
  }

  Future<List<Map<String, dynamic>>> getMonthlyCollection({int months = 6}) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT strftime('%Y-%m', p.paymentDate) as month, SUM(p.amount) as total
      FROM payments p
      INNER JOIN students s ON s.id = p.studentId
      WHERE p.paymentDate >= date('now', '-$months months')
      GROUP BY month
      ORDER BY month ASC
    ''');
    return result.map((r) => {'month': r['month'], 'total': (r['total'] as num?)?.toDouble() ?? 0.0}).toList();
  }


  // ─── MONTHLY FEE LEDGER ────────────────────────────────────────────────────

  String _nextMonthKey(String month) {
    final parts = month.split('-');
    var year = int.parse(parts[0]);
    var m = int.parse(parts[1]);
    m++;
    if (m == 13) {
      year++;
      m = 1;
    }
    return '$year-${m.toString().padLeft(2, '0')}';
  }

  String _toMonthKey(String? monthStr, [String? dateStr]) {
    return PaymentModel.toMonthKey(monthStr, null, dateStr);
  }

  Future<String> getFeeStartMonth(String studentId) async {
    final structure = await getFeeStructure(studentId);
    if (structure?.startMonth != null && structure!.startMonth!.isNotEmpty) {
      return structure.startMonth!;
    }

    final db = await database;
    final activeRows = await db.query(
      'monthly_fees',
      columns: ['month', 'paidAmount', 'tuitionFee', 'transportFee', 'admissionFee', 'examinationFee', 'previousDue', 'tieBagBeltFee'],
      where: 'studentId = ?',
      whereArgs: [studentId],
      orderBy: 'month ASC',
    );
    for (final row in activeRows) {
      final paid = (row['paidAmount'] as num?)?.toDouble() ?? 0.0;
      final tuition = (row['tuitionFee'] as num?)?.toDouble() ?? 0.0;
      final prev = (row['previousDue'] as num?)?.toDouble() ?? 0.0;
      final trans = (row['transportFee'] as num?)?.toDouble() ?? 0.0;
      final tie = (row['tieBagBeltFee'] as num?)?.toDouble() ?? 0.0;
      final adm = (row['admissionFee'] as num?)?.toDouble() ?? 0.0;
      if (paid > 0 || tuition > 0 || prev > 0 || trans > 0 || tie > 0 || adm > 0) {
        final m = row['month']?.toString();
        if (m != null && m.length >= 7) return m;
      }
    }

    final studentRows = await db.query(
      'students',
      where: 'id = ? OR studentId = ?',
      whereArgs: [studentId, studentId],
      limit: 1,
    );
    if (studentRows.isNotEmpty) {
      final admStr = (studentRows.first['admissionDate'] ?? studentRows.first['createdAt'])?.toString();
      if (admStr != null && admStr.length >= 7) {
        return admStr.substring(0, 7);
      }
    }

    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  Future<double> getRollingPreviousDue(String studentId, String targetMonth) async {
    final startMonth = await getFeeStartMonth(studentId);

    // If targetMonth is strictly before the student's fee start month, no previous due
    if (targetMonth.compareTo(startMonth) < 0) {
      return 0.0;
    }

    final db = await database;
    final studentRows = await db.query(
      'students',
      where: 'id = ? OR studentId = ?',
      whereArgs: [studentId, studentId],
      limit: 1,
    );
    final initialDue = studentRows.isNotEmpty ? ((studentRows.first['previousDue'] as num?)?.toDouble() ?? 0.0) : 0.0;
    final structure = await getFeeStructure(studentId);
    final recurringTotal = (structure?.tuitionFee ?? 0.0) + (structure?.transportFee ?? 0.0) + (structure?.gameFee ?? 0.0);

    final feeRows = await db.query('monthly_fees', where: 'studentId = ?', whereArgs: [studentId], orderBy: 'month ASC');
    final feeMap = <String, MonthlyFeeModel>{};
    for (final row in feeRows) {
      final f = _monthlyFeeFromRow(row);
      feeMap[f.month] = f;
    }

    final payRows = await db.query('payments', where: 'studentId = ?', whereArgs: [studentId]);
    final payMap = <String, double>{};
    for (final r in payRows) {
      final feeMonth = r['feeMonth']?.toString() ?? '';
      final pDate = r['paymentDate']?.toString() ?? '';
      final amt = (r['amount'] as num?)?.toDouble() ?? 0.0;

      final mKey = _toMonthKey(feeMonth, pDate);
      if (mKey.isNotEmpty) {
        payMap[mKey] = (payMap[mKey] ?? 0.0) + amt;
      }
    }

    if (targetMonth == startMonth) {
      final firstFee = feeMap[startMonth];
      if (firstFee != null && firstFee.previousDue > 0) {
        return firstFee.previousDue;
      }
      return initialDue;
    }

    double rollingDue = initialDue;
    var curr = startMonth;

    while (curr.compareTo(targetMonth) < 0) {
      final existingFee = feeMap[curr];
      double effectivePrevDue = rollingDue;
      if (curr == startMonth && existingFee != null && existingFee.previousDue > 0) {
        effectivePrevDue = existingFee.previousDue;
      }

      double monthCharge = recurringTotal;
      if (existingFee != null) {
        monthCharge = existingFee.monthlyCharge;
      }

      final paid = payMap[curr] ?? (existingFee?.paidAmount ?? 0.0);
      final totalDemand = effectivePrevDue + monthCharge;
      final closing = (totalDemand - paid).clamp(0.0, double.infinity);
      rollingDue = closing;

      curr = _nextMonthKey(curr);
    }

    return rollingDue;
  }

  MonthlyFeeModel _monthlyFeeFromRow(Map<String, dynamic> row) {
    return MonthlyFeeModel.fromMap(
      Map<String, dynamic>.from(row),
    );
  }

  // ─── Fee Structure (recurring per-student monthly template) ─────────────

  StudentFeeStructureModel _feeStructureFromRow(Map<String, dynamic> row) {
    return StudentFeeStructureModel.fromMap(Map<String, dynamic>.from(row));
  }

  Future<StudentFeeStructureModel?> getFeeStructure(String studentId) async {
    final db = await database;
    final rows = await db.query(
      'fee_structures',
      where: 'studentId = ?',
      whereArgs: [studentId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _feeStructureFromRow(rows.first);
  }

  /// Sets/updates the student's recurring Fee Structure. This does NOT
  /// retroactively touch any already-created month (same behaviour as the
  /// existing tuition-fee-carry-forward logic below) — it only affects
  /// months created from now on via [ensureMonthlyFee].
  Future<StudentFeeStructureModel> saveFeeStructure({
    required String studentId,
    required double tuitionFee,
    double transportFee = 0,
    double gameFee = 0,
    int dueDay = 10,
    double finePerDay = 0,
    String? startMonth,
  }) async {
    final db = await database;
    try {
      await db.execute('ALTER TABLE fee_structures ADD COLUMN startMonth TEXT');
    } catch (_) {}
    final existing = await getFeeStructure(studentId);
    final resolvedStart = startMonth ?? existing?.startMonth;
    final structure = StudentFeeStructureModel(
      studentId: studentId,
      tuitionFee: tuitionFee,
      transportFee: transportFee,
      gameFee: gameFee,
      dueDay: dueDay,
      finePerDay: finePerDay,
      startMonth: resolvedStart,
      updatedAt: DateTime.now(),
    );
    await db.insert('fee_structures', structure.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return structure;
  }

  /// Due date for [month] ('YYYY-MM') from the structure's dueDay, clamped
  /// to that month's real last day (e.g. dueDay=30 in February -> 28/29).
  DateTime? _dueDateFromStructure(
      String month, StudentFeeStructureModel? structure) {
    if (structure == null) return null;
    final parts = month.split('-');
    if (parts.length != 2) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (y == null || m == null) return null;
    final lastDayOfMonth = DateTime(y, m + 1, 0).day;
    final day = structure.dueDay.clamp(1, lastDayOfMonth);
    return DateTime(y, m, day);
  }

  /// ₹ fine for being overdue as of today — days-late × finePerDay, same
  /// formula as the reference fee-structure design. Zero once the balance
  /// for this month (excluding any already-applied fine) is cleared.
  double _computeLateFine(
      DateTime? dueDate, double finePerDay, double remainingExcludingFine) {
    if (dueDate == null || finePerDay <= 0 || remainingExcludingFine <= 0) {
      return 0;
    }
    final now = DateTime.now();
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final today = DateTime(now.year, now.month, now.day);
    if (!today.isAfter(due)) return 0;
    final daysLate = today.difference(due).inDays;
    return daysLate * finePerDay;
  }

  /// Recomputes lateFine on [fee] against the student's current Fee
  /// Structure. Returns [fee] unchanged if there's nothing to update.
  MonthlyFeeModel _withRecalculatedLateFine(
      MonthlyFeeModel fee, StudentFeeStructureModel? structure) {
    if (structure == null) {
      return fee.lateFine == 0 ? fee : fee.copyWith(lateFine: 0);
    }
    final remainingExcludingFine =
    (fee.totalDue - fee.lateFine - fee.paidAmount)
        .clamp(0.0, double.infinity);
    final fine = _computeLateFine(
        fee.dueDate, structure.finePerDay, remainingExcludingFine);
    if (fine == fee.lateFine) return fee;
    return fee.copyWith(lateFine: fine, updatedAt: DateTime.now());
  }

  Future<double> getMonthlyPaidAmount(String studentId, String month) async {
    final db = await database;
    final rows = await db.query(
      'payments',
      where: 'studentId = ?',
      whereArgs: [studentId],
    );
    double total = 0.0;
    for (final row in rows) {
      final feeMonth = row['feeMonth']?.toString() ?? '';
      final paymentDateStr = row['paymentDate']?.toString() ?? '';
      final amt = (row['amount'] as num?)?.toDouble() ?? 0.0;

      if (feeMonth == month ||
          feeMonth == _formatMonthKey(month) ||
          paymentDateStr.startsWith(month)) {
        total += amt;
      }
    }
    return total;
  }

  static String _formatMonthKey(String month) {
    final parts = month.split('-');
    if (parts.length != 2) return month;
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final m = int.tryParse(parts[1]);
    if (m == null || m < 1 || m > 12) return month;
    return '${names[m - 1]} ${parts[0]}';
  }

  Future<MonthlyFeeModel?> getMonthlyFee(
      String studentId,
      String month,
      ) async {
    final db = await database;
    final rows = await db.query(
      'monthly_fees',
      where: 'studentId = ? AND month = ?',
      whereArgs: [studentId, month],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    var fee = _monthlyFeeFromRow(rows.first);
    final paid = await getMonthlyPaidAmount(studentId, month);
    if (paid > fee.paidAmount) {
      fee = fee.copyWith(paidAmount: paid);
    }
    if (fee.previousDue == 0) {
      final rolling = await getRollingPreviousDue(studentId, month);
      if (rolling > 0) {
        fee = fee.copyWith(previousDue: rolling);
      }
    }
    return fee;
  }

  Future<List<MonthlyFeeModel>> getMonthlyFees(String studentId) async {
    final db = await database;
    final rows = await db.query(
      'monthly_fees',
      where: 'studentId = ?',
      whereArgs: [studentId],
      orderBy: 'month DESC',
    );
    return rows.map(_monthlyFeeFromRow).toList();
  }

  Future<void> _saveMonthlyFeeRow(MonthlyFeeModel fee) async {
    final db = await database;
    // MonthlyFeeModel.toMap() also includes computed/denormalized fields
    // (additionalTotal, totalDue, remaining, status) — those exist so the
    // Firestore document is self-describing for other consumers (e.g. a
    // web dashboard) without them needing to reimplement the Dart getters.
    // SQLite's monthly_fees table only stores the raw source columns, so
    // strip the computed ones before inserting or SQLite throws "table
    // monthly_fees has no column named additionalTotal".
    final map = fee.toMap()
      ..remove('additionalTotal')
      ..remove('totalDue')
      ..remove('remaining')
      ..remove('status');
    await db.insert('monthly_fees', map,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// After a payment/fee update, carry the new remaining amount
  /// into the next already-created month's Previous Due, then continue
  /// through the existing chain.
  Future<void> _propagatePreviousDueForward(
      String studentId,
      String fromMonth,
      ) async {
    var previousMonth = fromMonth;
    var previous = await getMonthlyFee(studentId, previousMonth);

    if (previous == null) return;

    while (true) {
      final nextMonth = _nextMonthKey(previousMonth);
      final next = await getMonthlyFee(studentId, nextMonth);

      if (next == null) break;

      final updatedNext = next.copyWith(
        previousDue: previous!.remaining,
        updatedAt: DateTime.now(),
      );

      await _saveMonthlyFeeRow(updatedNext);
      FirestoreService.instance.syncMonthlyFee(updatedNext).catchError((_) => null);

      previousMonth = nextMonth;
      previous = updatedNext;
    }
  }

  Future<MonthlyFeeModel> saveMonthlyFeeStructure({
    required String studentId,
    required String month,
    required double tuitionFee,
    required List<FeeLineItem> additionalFees,
    DateTime? dueDate,
    String? remarks,
  }) async {
    final existing = await getMonthlyFee(studentId, month);
    final now = DateTime.now();

    double amount(String key) => additionalFees
        .where((e) => e.key == key)
        .fold<double>(0, (sum, e) => sum + e.amount);

    final paidForThisMonth = await getMonthlyPaidAmount(studentId, month);
    final effectivePaid = paidForThisMonth > (existing?.paidAmount ?? 0)
        ? paidForThisMonth
        : (existing?.paidAmount ?? 0);

    final rollingPrev = await getRollingPreviousDue(studentId, month);
    final prevDueVal = amount('previousDue') > 0
        ? amount('previousDue')
        : (existing?.previousDue != 0 ? (existing?.previousDue ?? rollingPrev) : rollingPrev);

    final fee = MonthlyFeeModel(
      id: existing?.id ?? const Uuid().v4(),
      studentId: studentId,
      month: month,
      admissionFee: amount('admissionFee'),
      tuitionFee: tuitionFee,
      examinationFee: amount('examinationFee'),
      previousDue: prevDueVal,
      gameFee: amount('gameFee'),
      reAdmissionFee: amount('reAdmissionFee'),
      developmentFee: amount('developmentFee'),
      schoolIdFee: amount('schoolIdFee'),
      tieBagBeltFee: amount('tieBagBeltFee'),
      backDues: amount('backDues'),
      transportFee: amount('transportFee'),
      otherFee: amount('otherFee'),
      paidAmount: effectivePaid,
      lateFine: existing?.lateFine ?? 0,
      dueDate: dueDate ?? existing?.dueDate,
      lastPaymentDate: existing?.lastPaymentDate,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      remarks: remarks ?? existing?.remarks,
    );
    await _saveMonthlyFeeRow(fee);

    final db = await database;
    if (amount('previousDue') > 0) {
      try {
        await db.rawUpdate('UPDATE students SET previousDue = ? WHERE id = ? OR studentId = ?', [amount('previousDue'), studentId, studentId]);
      } catch (_) {}
    }

    // Ensure fee_structures has this month recorded as startMonth if earlier or not set
    final structure = await getFeeStructure(studentId);
    if (structure != null && (structure.startMonth == null || structure.startMonth!.isEmpty || month.compareTo(structure.startMonth!) < 0)) {
      await saveFeeStructure(
        studentId: studentId,
        tuitionFee: structure.tuitionFee > 0 ? structure.tuitionFee : tuitionFee,
        transportFee: structure.transportFee > 0 ? structure.transportFee : amount('transportFee'),
        gameFee: structure.gameFee > 0 ? structure.gameFee : amount('gameFee'),
        dueDay: structure.dueDay,
        finePerDay: structure.finePerDay,
        startMonth: month,
      );
    }

    await _propagatePreviousDueForward(studentId, month);
    await refreshLegacyFeeAggregate(studentId);
    return fee;
  }

  /// Saves an already-built monthly fee record (for example when only the
  /// due date or another field is changed from the UI).
  Future<void> saveMonthlyFee(MonthlyFeeModel fee) async {
    await _saveMonthlyFeeRow(fee);
    await refreshLegacyFeeAggregate(fee.studentId);
  }

  Future<List<MonthlyFeeModel>> generateMissingMonthlyFees({
    required String studentId,
    required String startMonth,
    required String endMonth,
    required double monthlyFee,
  }) async {
    final created = <MonthlyFeeModel>[];
    var month = startMonth;
    while (true) {
      var fee = await getMonthlyFee(studentId, month);
      if (fee == null) {
        final rolling = await getRollingPreviousDue(studentId, month);
        fee = MonthlyFeeModel(
          id: const Uuid().v4(),
          studentId: studentId,
          month: month,
          tuitionFee: monthlyFee,
          previousDue: rolling,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dueDate: null,
          admissionFee: 0,
          examinationFee: 0,
          gameFee: 0,
          reAdmissionFee: 0,
          developmentFee: 0,
          schoolIdFee: 0,
          tieBagBeltFee: 0,
          backDues: 0,
          transportFee: 0,
          otherFee: 0,
          paidAmount: 0,
          lastPaymentDate: null,
          remarks: null,
        );
        await _saveMonthlyFeeRow(fee);
        created.add(fee);
      }
      if (month == endMonth) break;
      month = _nextMonthKey(month);
    }
    await refreshLegacyFeeAggregate(studentId);
    return created;
  }

  Future<MonthlyFeeModel> addMonthlyFeePayment({
    required String studentId,
    required String month,
    required double amount,
    required String paymentMode,
    String? remarks,
  }) async {
    if (amount <= 0) throw Exception('Payment amount must be greater than zero.');
    final fee = await getMonthlyFee(studentId, month) ?? await ensureMonthlyFee(
      studentId: studentId,
      month: month,
      autoCreate: true,
    );
    final now = DateTime.now();
    final receiptNumber = await generateReceiptNumber(now.year);
    final newPaid = fee.paidAmount + amount;
    final formattedFeeMonth = _formatMonthKey(month);
    final monthKey = _toMonthKey(month, now.toIso8601String());
    final updated = fee.copyWith(
      paidAmount: newPaid,
      lastPaymentDate: now, updatedAt: now, remarks: remarks ?? fee.remarks,
    );
    await _saveMonthlyFeeRow(updated);
    await dbInsertMonthlyPayment(
      studentId: studentId, amount: amount, paymentDate: now,
      paymentMode: paymentMode, remarks: remarks ?? 'Monthly fee: $formattedFeeMonth',
      receiptNumber: receiptNumber, feeMonth: formattedFeeMonth,
      monthKey: monthKey,
    );
    await _propagatePreviousDueForward(studentId, month);
    await refreshLegacyFeeAggregate(studentId);
    return updated;
  }

  Future<MonthlyFeeModel> ensureMonthlyFee({
    required String studentId,
    required String month,
    double tuitionFee = 0,
    double monthlyFee = 0,
    double admissionFee = 0,
    double examinationFee = 0,
    double gameFee = 0,
    double reAdmissionFee = 0,
    double developmentFee = 0,
    double schoolIdFee = 0,
    double tieBagBeltFee = 0,
    double backDues = 0,
    double transportFee = 0,
    double otherFee = 0,
    DateTime? dueDate,
    String? remarks,
    bool autoCreate = true,
  }) async {
    final startMonth = await getFeeStartMonth(studentId);
    final isPreStart = month.compareTo(startMonth) < 0;
    final structure = await getFeeStructure(studentId);
    final db = await database;

    final existing = await getMonthlyFee(studentId, month);
    if (existing != null) {
      if (isPreStart && existing.paidAmount == 0) {
        // Clean phantom auto-created row for pre-start month
        await db.delete('monthly_fees', where: 'id = ?', whereArgs: [existing.id]);
        await refreshLegacyFeeAggregate(studentId);
      } else {
        var updatedExisting = existing;
        if (existing.paidAmount == 0 && structure != null && structure.tuitionFee > 0 && !isPreStart) {
          if (existing.tuitionFee == 0 || existing.tuitionFee != structure.tuitionFee) {
            final recalculatedPrevDue = await getRollingPreviousDue(studentId, month);
            updatedExisting = updatedExisting.copyWith(
              tuitionFee: structure.tuitionFee,
              previousDue: recalculatedPrevDue,
              transportFee: structure.transportFee,
              gameFee: structure.gameFee,
            );
          }
        }

        final refreshed = _withRecalculatedLateFine(updatedExisting, structure);
        if (refreshed != existing) {
          await _saveMonthlyFeeRow(refreshed);
          await refreshLegacyFeeAggregate(studentId);
          return refreshed;
        }
        return existing;
      }
    }

    final now = DateTime.now();

    if (isPreStart) {
      // Pre-start month: strictly 0 fees, never auto-create
      return MonthlyFeeModel(
        id: const Uuid().v4(),
        studentId: studentId,
        month: month,
        admissionFee: 0,
        tuitionFee: 0,
        examinationFee: 0,
        previousDue: 0,
        gameFee: 0,
        reAdmissionFee: 0,
        developmentFee: 0,
        schoolIdFee: 0,
        tieBagBeltFee: 0,
        backDues: 0,
        transportFee: 0,
        otherFee: 0,
        dueDate: null,
        createdAt: now,
        updatedAt: now,
        remarks: 'Pre-admission month',
        paidAmount: 0,
        lastPaymentDate: null,
      );
    }

    final effectiveTuition = tuitionFee != 0
        ? tuitionFee
        : (monthlyFee != 0
        ? monthlyFee
        : (structure?.tuitionFee ?? 0));
    final effectiveTransport =
    transportFee != 0 ? transportFee : (structure?.transportFee ?? 0);
    final effectiveGame = gameFee != 0 ? gameFee : (structure?.gameFee ?? 0);
    final effectiveDueDate =
        dueDate ?? _dueDateFromStructure(month, structure);

    final paidForThisMonth = await getMonthlyPaidAmount(studentId, month);
    final rollingPrevDue = await getRollingPreviousDue(studentId, month);

    var fee = MonthlyFeeModel(
      id: const Uuid().v4(),
      studentId: studentId,
      month: month,
      admissionFee: admissionFee,
      tuitionFee: effectiveTuition,
      examinationFee: examinationFee,
      previousDue: rollingPrevDue,
      gameFee: effectiveGame,
      reAdmissionFee: reAdmissionFee,
      developmentFee: developmentFee,
      schoolIdFee: schoolIdFee,
      tieBagBeltFee: tieBagBeltFee,
      backDues: backDues,
      transportFee: effectiveTransport,
      otherFee: otherFee,
      dueDate: effectiveDueDate,
      createdAt: now,
      updatedAt: now,
      remarks: remarks,
      paidAmount: paidForThisMonth,
      lastPaymentDate: null,
    );
    fee = _withRecalculatedLateFine(fee, structure);
    if (autoCreate) {
      await _saveMonthlyFeeRow(fee);
      await refreshLegacyFeeAggregate(studentId);
    }
    return fee;
  }

  Future<Map<String, Map<String, int>>> getAttendanceSummaryByDateRange(DateTime from, DateTime to) async {
    if (kIsWeb) return getAllAttendanceSummaries();
    final db = await database;
    final fromStr = from.toIso8601String().substring(0, 10);
    final toStr = to.toIso8601String().substring(0, 10);
    final rows = await db.rawQuery('''
      SELECT studentId,
        COUNT(*) as total,
        SUM(CASE WHEN status = 'present' THEN 1 ELSE 0 END) as present,
        SUM(CASE WHEN status = 'absent' THEN 1 ELSE 0 END) as absent,
        SUM(CASE WHEN status = 'leave' THEN 1 ELSE 0 END) as leaveCount
      FROM attendance
      WHERE substr(date, 1, 10) >= ? AND substr(date, 1, 10) <= ?
      GROUP BY studentId
    ''', [fromStr, toStr]);

    final result = <String, Map<String, int>>{};
    for (final row in rows) {
      final studentId = row['studentId'] as String? ?? '';
      if (studentId.isEmpty) continue;
      final total = (row['total'] as num?)?.toInt() ?? 0;
      final present = (row['present'] as num?)?.toInt() ?? 0;
      final absent = (row['absent'] as num?)?.toInt() ?? 0;
      final leave = (row['leaveCount'] as num?)?.toInt() ?? 0;
      result[studentId] = {
        'total': total,
        'present': present,
        'absent': absent,
        'leave': leave > 0 ? leave : (total - present - absent).clamp(0, 999999),
      };
    }
    return result;
  }

  Future<void> updateMonthlyFeeDueDate({
    required String studentId,
    required String month,
    required DateTime? dueDate,
  }) async {
    final fee = await getMonthlyFee(studentId, month);
    if (fee == null) return;

    final updated = fee.copyWith(
      dueDate: dueDate,
      updatedAt: DateTime.now(),
    );

    await _saveMonthlyFeeRow(updated);
    await refreshLegacyFeeAggregate(studentId);
  }

  Future<MonthlyFeeModel> addMonthlyPayment({
    required String studentId,
    required String month,
    required double amount,
    required String paymentMode,
    String? remarks,
  }) => addMonthlyFeePayment(
    studentId: studentId, month: month, amount: amount,
    paymentMode: paymentMode, remarks: remarks,
  );

  Future<double> getPaidBeforePayment(String studentId, String month, [String? paymentId, DateTime? paymentDate]) async {
    final db = await database;
    final rows = await db.query(
      'payments',
      where: 'studentId = ?',
      whereArgs: [studentId],
    );
    final formattedMonth = _formatMonthKey(month);
    var total = 0.0;
    for (final row in rows) {
      if (paymentId != null && row['id']?.toString() == paymentId) continue;
      final fm = row['feeMonth']?.toString() ?? '';
      final pDateStr = row['paymentDate']?.toString() ?? '';
      final isMonth = fm == month || fm == formattedMonth || pDateStr.startsWith(month) || _toMonthKey(fm, pDateStr) == month;
      if (!isMonth) continue;

      final d = DateTime.tryParse(pDateStr);
      if (paymentDate != null && d != null && !d.isBefore(paymentDate)) continue;
      total += (row['amount'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  Future<List<PaymentModel>> getMonthlyPaymentHistory(String studentId, String month) async {
    final db = await database;
    final rows = await db.query(
      'payments',
      where: 'studentId = ?',
      whereArgs: [studentId],
      orderBy: 'paymentDate DESC',
    );
    final formattedMonth = _formatMonthKey(month);
    final result = <PaymentModel>[];
    for (final row in rows) {
      final p = PaymentModel.fromMap(row);
      final fm = p.feeMonth ?? '';
      final pd = p.paymentDate.toIso8601String();
      if (fm == month || fm == formattedMonth || pd.startsWith(month) || _toMonthKey(fm, pd) == month) {
        result.add(p);
      }
    }
    return result;
  }

  Future<List<PaymentModel>> getStudentPaymentHistory(
      String studentId,
      ) async {
    final db = await database;

    final rows = await db.query(
      'payments',
      where: 'studentId = ?',
      whereArgs: [studentId],
      orderBy: 'paymentDate DESC',
    );

    return rows
        .map((row) => PaymentModel.fromMap(row))
        .toList();
  }

  Future<List<PaymentModel>> getPayments(String studentId) =>
      getStudentPaymentHistory(studentId);

  Future<List<PaymentModel>> getAllPayments() async {
    final db = await database;
    final rows = await db.query(
      'payments',
      orderBy: 'paymentDate DESC',
    );
    return rows.map((row) => PaymentModel.fromMap(row)).toList();
  }


  Future<void> dbInsertMonthlyPayment({
    required String studentId, required double amount, required DateTime paymentDate,
    required String paymentMode, required String remarks, required String receiptNumber,
    required String feeMonth, String? monthKey,
  }) async {
    final db = await database;
    final resolvedMonthKey = monthKey ?? PaymentModel.toMonthKey(feeMonth, paymentDate);
    final resolvedFeeMonth = PaymentModel.toFeeMonthLabel(feeMonth, paymentDate);
    // Use receiptNumber as primary ID so Firestore sync never creates a duplicate row
    final cleanId = receiptNumber.trim().isNotEmpty ? receiptNumber.trim() : const Uuid().v4();

    // Remove any old UUID-based duplicate of the same receiptNumber before inserting
    await db.delete('payments', where: 'receiptNumber = ? AND id != ?', whereArgs: [receiptNumber, cleanId]);

    final paymentRow = <String, dynamic>{
      'id': cleanId,
      'studentId': studentId,
      'amount': amount,
      'paymentDate': paymentDate.toIso8601String(),
      'paymentMode': paymentMode,
      'remarks': remarks,
      'receiptNumber': receiptNumber,
      'feeMonth': resolvedFeeMonth,
      'monthKey': resolvedMonthKey,
    };

    try {
      await db.insert('payments', paymentRow, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {
      try {
        await db.execute('ALTER TABLE payments ADD COLUMN monthKey TEXT');
        await db.insert('payments', paymentRow, conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (_) {
        paymentRow.remove('monthKey');
        await db.insert('payments', paymentRow, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
  }

  Future<void> upsertMonthlyFeeFromRemote(
      String studentId,
      Map<String, dynamic> data,
      ) async {
    final db = await database;

    final exists = await db.query(
      'students',
      where: 'id = ?',
      whereArgs: [studentId],
      limit: 1,
    );
    if (exists.isEmpty) return;

    final fee = MonthlyFeeModel.fromMap({
      ...data,
      'studentId': studentId,
    });

    await _saveMonthlyFeeRow(fee);
    await refreshLegacyFeeAggregate(studentId);
  }

  Future<void> refreshLegacyFeeAggregate(String studentId) async {
    final db = await database;
    final studentRows = await db.query(
      'students',
      where: 'id = ? OR studentId = ?',
      whereArgs: [studentId, studentId],
      limit: 1,
    );
    final structure = await getFeeStructure(studentId);

    final rows = await db.query(
      'monthly_fees',
      where: 'studentId = ?',
      whereArgs: [studentId],
    );

    // Sort rows ascending by month to get earliest initial previousDue
    final sortedRows = rows.map(_monthlyFeeFromRow).toList()
      ..sort((a, b) => a.month.compareTo(b.month));

    final now = DateTime.now();
    final currentMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final paymentRows = await db.query(
      'payments',
      where: 'studentId = ?',
      whereArgs: [studentId],
      orderBy: 'paymentDate DESC',
    );
    double paymentsTotal = 0;
    DateTime? latestPayment;
    for (final p in paymentRows) {
      paymentsTotal += (p['amount'] as num?)?.toDouble() ?? 0.0;
      final pDate = DateTime.tryParse(p['paymentDate']?.toString() ?? '');
      if (pDate != null && (latestPayment == null || pDate.isAfter(latestPayment))) {
        latestPayment = pDate;
      }
    }

    double totalFees = 0.0;
    double remainingFees = 0.0;
    DateTime? latestDueDate;
    MonthlyFeeModel? currMonthFee;

    final studentTotalFees = studentRows.isNotEmpty ? ((studentRows.first['totalFees'] as num?)?.toDouble() ?? 0.0) : 0.0;
    final studentRemaining = studentRows.isNotEmpty
        ? ((studentRows.first['remainingFees'] as num?)?.toDouble() ??
            (studentRows.first['totalPending'] as num?)?.toDouble())
        : null;
    final studentFeeStatus = studentRows.isNotEmpty ? studentRows.first['feeStatus']?.toString() : null;

    final existingFeeRows = await db.query('fees', where: 'studentId = ?', whereArgs: [studentId]);
    final existingFeeRow = existingFeeRows.isNotEmpty ? existingFeeRows.first : null;
    final existingTotalFees = (existingFeeRow?['totalFees'] as num?)?.toDouble() ?? 0.0;
    final existingRemaining = (existingFeeRow?['remainingFees'] as num?)?.toDouble() ??
        (existingFeeRow?['totalPending'] as num?)?.toDouble();

    // Paid fees is ALWAYS total recorded payments of this student across the database
    double paidFees = paymentsTotal;
    final recPaid = (existingFeeRow?['paidFees'] as num?)?.toDouble() ?? 0.0;
    if (recPaid > paidFees) paidFees = recPaid;

    final hasExplicitRem = (studentRemaining != null && studentRemaining > 0) || (existingRemaining != null && existingRemaining > 0);
    final explicitRem = studentRemaining ?? existingRemaining;

    // Find current month's fee model first
    for (final f in sortedRows) {
      if (f.month == currentMonthKey) {
        currMonthFee = f;
        break;
      }
    }

    final recurringTotal = (structure?.tuitionFee ?? 0.0) + (structure?.transportFee ?? 0.0) + (structure?.gameFee ?? 0.0);

    if (currMonthFee != null || recurringTotal > 0) {
      double currentMonthDue = 0.0;
      if (currMonthFee != null) {
        final currMonthPaid = paymentRows
            .where((r) => r['monthKey'] == currentMonthKey || r['feeMonth'] == _formatMonthKey(currentMonthKey))
            .fold<double>(0.0, (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0.0));
        final effPaid = currMonthPaid > currMonthFee.paidAmount ? currMonthPaid : currMonthFee.paidAmount;
        currentMonthDue = (currMonthFee.totalDue - effPaid).clamp(0.0, double.infinity);
        latestDueDate = currMonthFee.dueDate;
      } else {
        final rollingDue = await getRollingPreviousDue(studentId, currentMonthKey);
        final currMonthPaid = paymentRows
            .where((r) => r['monthKey'] == currentMonthKey || r['feeMonth'] == _formatMonthKey(currentMonthKey))
            .fold<double>(0.0, (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0.0));
        currentMonthDue = (rollingDue + recurringTotal - currMonthPaid).clamp(0.0, double.infinity);
        latestDueDate = _dueDateFromStructure(currentMonthKey, structure);
      }
      remainingFees = currentMonthDue;
      totalFees = paidFees + remainingFees;
    } else if (studentFeeStatus == 'Paid' && !hasExplicitRem) {
      final rawTotal = studentTotalFees > 0 ? studentTotalFees : existingTotalFees;
      totalFees = rawTotal > 0 ? (rawTotal < paidFees ? paidFees : rawTotal) : paidFees;
      remainingFees = 0.0;
      latestDueDate = DateTime.tryParse(existingFeeRow?['dueDate']?.toString() ?? '');
    } else if (studentTotalFees > 0 || existingTotalFees > 0) {
      final rawTotal = studentTotalFees > 0 ? studentTotalFees : existingTotalFees;
      totalFees = rawTotal < paidFees ? paidFees : rawTotal;
      remainingFees = (totalFees - paidFees).clamp(0.0, double.infinity);
      latestDueDate = DateTime.tryParse(existingFeeRow?['dueDate']?.toString() ?? '');
    } else if (hasExplicitRem && explicitRem != null) {
      remainingFees = explicitRem;
      totalFees = paidFees + remainingFees;
      latestDueDate = DateTime.tryParse(existingFeeRow?['dueDate']?.toString() ?? '');
    }

    final feeStatus = remainingFees <= 0 ? 'Paid' : (paidFees <= 0 ? 'Unpaid' : 'Pending');
    final monthlyFee = structure?.tuitionFee ?? (studentRows.isNotEmpty ? ((studentRows.first['monthlyFee'] as num?)?.toDouble() ?? 0.0) : 0.0);

    await db.insert(
      'fees',
      {
        'studentId': studentId,
        'totalFees': totalFees,
        'paidFees': paidFees,
        'remainingFees': remainingFees,
        'totalPending': remainingFees,
        'monthlyFee': monthlyFee,
        'feeStatus': feeStatus,
        'dueDate': latestDueDate?.toIso8601String(),
        'lastPaidDate': latestPayment?.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Background sync to Firestore
    final feeModel = FeeModel(
      studentId: studentId,
      totalFees: totalFees,
      paidFees: paidFees,
      explicitRemaining: remainingFees,
      dueDate: latestDueDate,
      lastPaidDate: latestPayment,
      payments: paymentRows.map(PaymentModel.fromMap).toList(),
    );
    FirestoreService.instance.syncFee(feeModel).catchError((e) {
      debugPrint('[DatabaseService] Firestore syncFee note: $e');
      return null;
    });
  }

  // ─── ATTENDANCE CRUD ──────────────────────────────────────────────────────

  /// Upsert attendance — if record for same student+date exists, clean and replace it.
  /// This prevents duplicate counts every time attendance is re-saved or status is modified.
  Future<void> markAttendance(AttendanceModel attendance) async {
    if (kIsWeb) {
      await FirestoreService.instance.syncAttendance(attendance);
      return;
    }
    final db = await database;
    final dateStr = attendance.date.toIso8601String().substring(0, 10);
    // Delete any existing record for this student on this calendar day
    await db.delete(
      'attendance',
      where: "studentId = ? AND date LIKE ?",
      whereArgs: [attendance.studentId, '$dateStr%'],
    );
    final map = attendance.toMap();
    map['date'] = '$dateStr 00:00:00.000';
    await db.insert('attendance', map);
  }

  /// Imports a historical attendance SUMMARY from Excel/PDF (total/present/
  /// absent/leave counts) as synthetic per-day records, so the existing
  /// COUNT/SUM-based getAttendanceSummary() shows the same numbers the file
  /// contained. Records are dated on distinct days going backwards from
  /// YESTERDAY — today is deliberately never touched, so an import can never
  /// mark a student Absent/Present for today; "today" stays "Not Marked"
  /// until someone actually takes attendance.
  ///
  /// Any existing imported/real attendance rows for this student are left
  /// alone except where they'd collide with a synthetic date — the UNIQUE
  /// (studentId, date) constraint plus ConflictAlgorithm.replace keeps this
  /// safe to re-run.
  Future<void> importAttendanceSummary(
      String studentId, {
        required int total,
        required int present,
        required int absent,
        required int leave,
      }) async {
    if (total <= 0) return;
    if (kIsWeb) return;
    final db = await database;
    // FIXED: Changed 'final' to 'const' for constant value
    const uuid = Uuid();

    // Build a status list of exactly `total` entries matching the requested
    // present/absent/leave split (clamped so it never exceeds `total`).
    final p = present.clamp(0, total);
    final remaining1 = total - p;
    final a = absent.clamp(0, remaining1);
    final remaining2 = remaining1 - a;
    final l = leave.clamp(0, remaining2);
    // Any leftover (e.g. counts didn't add up exactly) is filled as present
    // so the total always matches what was imported.
    final leftover = total - p - a - l;

    final statuses = <String>[
      ...List.filled(p + leftover, 'present'),
      ...List.filled(a, 'absent'),
      ...List.filled(l, 'leave'),
    ];

    final batch = db.batch();
    var dayOffset = 1; // start from yesterday, never today
    for (final status in statuses) {
      final date = DateTime.now().subtract(Duration(days: dayOffset));
      dayOffset++;
      batch.insert(
        'attendance',
        {
          'id': uuid.v4(),
          'studentId': studentId,
          'date': date.toIso8601String(),
          'status': status,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<AttendanceModel>> getAttendanceByDate(DateTime date) async {
    if (kIsWeb) return FirestoreService.instance.fetchAttendanceByDate(date);
    final db = await database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final maps = await db.query('attendance', where: "date LIKE ?", whereArgs: ['$dateStr%']);
    return maps.map(AttendanceModel.fromMap).toList();
  }

  Future<List<AttendanceModel>> getAttendanceByStudentId(String studentId) async {
    if (kIsWeb) {
      final list = await getAttendanceByDate(DateTime.now());
      return list.where((a) => a.studentId == studentId).toList();
    }
    final db = await database;
    final maps = await db.query('attendance',
        where: 'studentId = ?', whereArgs: [studentId], orderBy: 'date DESC');
    return maps.map(AttendanceModel.fromMap).toList();
  }

  Future<Map<String, int>> getAttendanceSummary(String studentId) async {
    final map = await getAllAttendanceSummaries();
    return map[studentId] ?? {'total': 0, 'present': 0, 'absent': 0, 'leave': 0};
  }

  /// Batch-load attendance summaries keyed by student ID.
  Future<Map<String, Map<String, int>>> getAllAttendanceSummaries() async {
    if (kIsWeb) return FirestoreService.instance.fetchAllAttendanceSummaries();
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT studentId,
        COUNT(*) as total,
        SUM(CASE WHEN status = 'present' THEN 1 ELSE 0 END) as present,
        SUM(CASE WHEN status = 'absent' THEN 1 ELSE 0 END) as absent,
        SUM(CASE WHEN status = 'leave' THEN 1 ELSE 0 END) as leaveCount
      FROM attendance
      GROUP BY studentId
    ''');

    final result = <String, Map<String, int>>{};
    for (final row in rows) {
      final studentId = row['studentId'] as String? ?? '';
      if (studentId.isEmpty) continue;
      final total = (row['total'] as num?)?.toInt() ?? 0;
      final present = (row['present'] as num?)?.toInt() ?? 0;
      final absent = (row['absent'] as num?)?.toInt() ?? 0;
      final leave = (row['leaveCount'] as num?)?.toInt() ?? 0;
      result[studentId] = {
        'total': total,
        'present': present,
        'absent': absent,
        'leave': leave > 0 ? leave : (total - present - absent).clamp(0, 999999),
      };
    }
    return result;
  }

  /// Returns count of students with 'present' status on today's date.
  /// Calculated dynamically based on latest status per student — never duplicate.
  Future<int> getTodayPresentCount() async {
    final summary = await getTodayAttendanceSummary();
    return summary['present'] ?? 0;
  }

  /// Returns today's full attendance summary {present, absent, leave}.
  /// Uses latest status per active student so changing present to absent updates instantly without counting deleted/orphan records.
  Future<Map<String, int>> getTodayAttendanceSummary() async {
    final activeStudents = await getAllStudents();
    if (activeStudents.isEmpty) {
      return {'present': 0, 'absent': 0, 'leave': 0};
    }

    final idToCanonical = <String, String>{};
    for (final s in activeStudents) {
      idToCanonical[s.id] = s.id;
      if (s.studentId.isNotEmpty) idToCanonical[s.studentId] = s.id;
      if (s.admissionNumber.isNotEmpty) idToCanonical[s.admissionNumber] = s.id;
    }

    if (!kIsWeb) {
      try {
        final db = await database;
        final validKeys = idToCanonical.keys.map((k) => "'$k'").join(',');
        if (validKeys.isNotEmpty) {
          await db.rawDelete('DELETE FROM attendance WHERE studentId NOT IN ($validKeys)');
        }
      } catch (_) {}
    }

    final records = await getAttendanceByDate(DateTime.now());
    final summary = {'present': 0, 'absent': 0, 'leave': 0};
    final latestByStudent = <String, String>{};
    for (final r in records) {
      final canonicalId = idToCanonical[r.studentId];
      if (canonicalId != null) {
        latestByStudent[canonicalId] = r.status;
      }
    }
    for (final status in latestByStudent.values) {
      if (summary.containsKey(status)) {
        summary[status] = (summary[status] ?? 0) + 1;
      }
    }
    return summary;
  }

  // ─── FILTERED STAT QUERIES (class/section scoped) ─────────────────────────
  //
  // These are used by dashboardStatsProvider when a Teacher has selected a
  // class and section. They JOIN the students table so every count/sum only
  // covers students in the specified class+section. Existing methods above
  // remain untouched — Principal still uses those whole-school versions.

  /// Build a WHERE clause + args list for class/section filtering on `students`.
  /// Returns an empty string and empty list when no filter is needed.
  (String, List<dynamic>) _classFilter({String? className, String? section}) {
    final conditions = <String>[];
    final args = <dynamic>[];
    if (className != null && className.isNotEmpty) {
      conditions.add("students.className = ?");
      args.add(className);
    }
    if (section != null && section.isNotEmpty) {
      conditions.add("students.section = ?");
      args.add(section);
    }
    if (conditions.isEmpty) return ('', []);
    return ('AND ${conditions.join(' AND ')}', args);
  }

  /// Total student count for a specific class and/or section.
  Future<int> getStudentCountFiltered({String? className, String? section}) async {
    if (kIsWeb) {
      final list = await getStudentsByFilter(className: className, section: section);
      return list.length;
    }
    final db = await database;
    final (filterClause, filterArgs) = _classFilter(className: className, section: section);
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM students WHERE 1=1 ${filterClause.replaceAll('AND students.', 'AND ')}',
      filterArgs,
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Today's attendance summary {present, absent, leave} for a specific class/section.
  Future<Map<String, int>> getTodayAttendanceSummaryFiltered({
    String? className,
    String? section,
  }) async {
    final students = await getStudentsByFilter(className: className, section: section);
    if (students.isEmpty) {
      return {'present': 0, 'absent': 0, 'leave': 0};
    }

    final idToCanonical = <String, String>{};
    for (final s in students) {
      idToCanonical[s.id] = s.id;
      if (s.studentId.isNotEmpty) idToCanonical[s.studentId] = s.id;
      if (s.admissionNumber.isNotEmpty) idToCanonical[s.admissionNumber] = s.id;
    }

    final records = await getAttendanceByDate(DateTime.now());
    final summary = {'present': 0, 'absent': 0, 'leave': 0};
    final latestByStudent = <String, String>{};
    for (final r in records) {
      final canonicalId = idToCanonical[r.studentId];
      if (canonicalId != null) {
        latestByStudent[canonicalId] = r.status;
      }
    }
    for (final status in latestByStudent.values) {
      if (summary.containsKey(status)) {
        summary[status] = (summary[status] ?? 0) + 1;
      }
    }
    return summary;
  }

  /// Total pending fees for students in a specific class/section.
  Future<double> getTotalPendingFeesFiltered({String? className, String? section}) async {
    if (kIsWeb) return 0.0;
    final students = await getStudentsByFilter(className: className, section: section);
    final validIds = students.map((s) => s.id).toSet();
    final feesMap = await getAllFeesMap();
    final seen = <String>{};
    double sum = 0.0;
    for (final entry in feesMap.entries) {
      if (validIds.contains(entry.key) && seen.add(entry.value.studentId) && entry.value.remaining > 0) {
        sum += entry.value.remaining;
      }
    }
    return sum;
  }

  /// Total collected fees for students in a specific class/section.
  Future<double> getTotalCollectedFiltered({String? className, String? section}) async {
    if (kIsWeb) return 0.0;
    final students = await getStudentsByFilter(className: className, section: section);
    final validIds = students.map((s) => s.id).toSet();
    final validAltIds = students.map((s) => s.studentId).where((id) => id.isNotEmpty).toSet();
    final validAdmNos = students.map((s) => s.admissionNumber).where((adm) => adm.isNotEmpty).toSet();
    final allValid = {...validIds, ...validAltIds, ...validAdmNos};

    final db = await database;
    final rows = await db.query('payments');
    final seenReceipts = <String>{};
    double total = 0.0;

    for (final r in rows) {
      final sId = r['studentId']?.toString() ?? '';
      if (!allValid.contains(sId)) continue;

      final rec = (r['receiptNumber']?.toString() ?? '').trim();
      final dedupKey = rec.isNotEmpty ? rec : (r['id']?.toString() ?? '');
      if (dedupKey.isNotEmpty && !seenReceipts.add(dedupKey)) continue;

      total += (r['amount'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  /// Overdue fee count for students in a specific class/section.
  Future<int> getOverdueFeeCountFiltered({String? className, String? section}) async {
    if (kIsWeb) return 0;
    final students = await getStudentsByFilter(className: className, section: section);
    final validIds = students.map((s) => s.id).toSet();
    final feesMap = await getAllFeesMap();
    final seen = <String>{};
    int count = 0;
    for (final entry in feesMap.entries) {
      if (validIds.contains(entry.key) && seen.add(entry.value.studentId) && entry.value.isOverdue) {
        count++;
      }
    }
    return count;
  }

  // ─── RESULT CRUD ──────────────────────────────────────────────────────────

  Future<void> saveResult(ResultModel result) async {
    if (kIsWeb) {
      await FirestoreService.instance.syncResult(result);
      return;
    }
    final db = await database;
    try { await db.execute('ALTER TABLE results ADD COLUMN isDetailedMode INTEGER DEFAULT 0'); } catch (_) {}
    try { await db.execute('ALTER TABLE results ADD COLUMN remarks TEXT'); } catch (_) {}

    final resMap = {
      'id': result.id,
      'studentId': result.studentId,
      'examName': result.examName,
      'status': result.status ?? result.finalResultStatus,
      'isDetailedMode': result.isDetailedMode ? 1 : 0,
      'remarks': result.remarks,
      'subjects': jsonEncode(result.subjects.map((s) => s.toMap()).toList()),
      'createdAt': result.createdAt.toIso8601String(),
    };
    await db.insert('results', resMap, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.delete('subject_results', where: 'resultId = ?', whereArgs: [result.id]);
    for (final subject in result.subjects) {
      await db.insert('subject_results', {
        'resultId': result.id,
        'subjectName': subject.subjectName,
        'marks': subject.marks,
        'totalMarks': subject.totalMarks,
        'theoryMarks': subject.theoryMarks,
        'practicalMarks': subject.practicalMarks,
        'internalMarks': subject.internalMarks,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    try {
      await FirestoreService.instance.syncResult(result);
    } catch (_) {}
  }

  Future<void> insertResult(ResultModel result) => saveResult(result);

  Future<List<ResultModel>> getAllResults() async {
    if (kIsWeb) {
      return FirestoreService.instance.fetchResults();
    }
    final db = await database;
    try {
      final results = await db.query('results', orderBy: 'createdAt DESC');
      List<ResultModel> models = [];
      for (final result in results) {
        final subjects = await db.query('subject_results', where: 'resultId = ?', whereArgs: [result['id']]);
        models.add(ResultModel.fromMap(result, subjects.map(SubjectResult.fromMap).toList()));
      }
      return models;
    } catch (_) {
      return [];
    }
  }

  Future<List<ResultModel>> getResultsByStudentId(String studentId) async {
    final student = await getStudentById(studentId) ?? await getStudentByQrId(studentId);
    final targetIds = <String>{studentId};
    if (student != null) {
      if (student.id.isNotEmpty) targetIds.add(student.id);
      if (student.studentId.isNotEmpty) targetIds.add(student.studentId);
    }

    if (kIsWeb) {
      final all = await getAllResults();
      return all.where((r) => targetIds.contains(r.studentId)).toList();
    }

    final db = await database;
    try {
      final placeholders = targetIds.map((_) => '?').join(', ');
      final results = await db.query(
        'results',
        where: 'studentId IN ($placeholders)',
        whereArgs: targetIds.toList(),
        orderBy: 'createdAt DESC',
      );
      List<ResultModel> models = [];
      for (final result in results) {
        final subjects = await db.query('subject_results', where: 'resultId = ?', whereArgs: [result['id']]);
        models.add(ResultModel.fromMap(result, subjects.map(SubjectResult.fromMap).toList()));
      }
      return models;
    } catch (e) {
      debugPrint('[DB] getResultsByStudentId error: $e');
      return [];
    }
  }

  Future<void> deleteResult(String id) async {
    if (kIsWeb) {
      await FirestoreService.instance.deleteResultRemote(id);
      return;
    }
    final db = await database;
    try {
      await db.delete('results', where: 'id = ?', whereArgs: [id]);
      await db.delete('subject_results', where: 'resultId = ?', whereArgs: [id]);
    } catch (_) {}
    try {
      await FirestoreService.instance.deleteResultRemote(id);
    } catch (_) {}
  }

  // ─── EXAMS CRUD ────────────────────────────────────────────────────────────

  Future<void> _ensureExamsTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS exams (
          id TEXT PRIMARY KEY,
          title TEXT,
          term TEXT,
          className TEXT,
          academicYear TEXT,
          examDate TEXT,
          status TEXT,
          isDetailedMode INTEGER DEFAULT 0,
          subjects TEXT,
          createdAt TEXT
        )
      ''');
    } catch (_) {}
  }

  Future<void> saveExam(ExamModel exam) async {
    if (kIsWeb) {
      await FirestoreService.instance.syncExam(exam);
      return;
    }
    final db = await database;
    await _ensureExamsTable(db);
    await db.insert('exams', {
      'id': exam.id,
      'title': exam.title,
      'term': exam.term,
      'className': exam.className,
      'academicYear': exam.academicYear,
      'examDate': exam.examDate.toIso8601String(),
      'status': exam.status,
      'isDetailedMode': exam.isDetailedMode ? 1 : 0,
      'subjects': jsonEncode(exam.subjects.map((s) => s.toMap()).toList()),
      'createdAt': exam.createdAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    try {
      await FirestoreService.instance.syncExam(exam);
    } catch (_) {}
  }

  Future<List<ExamModel>> getAllExams() async {
    if (kIsWeb) {
      return await FirestoreService.instance.fetchExamsRemote();
    }
    final db = await database;
    await _ensureExamsTable(db);
    try {
      final rows = await db.query('exams', orderBy: 'createdAt DESC');
      final local = rows.map(ExamModel.fromMap).toList();
      if (local.isNotEmpty) return local;

      // Fallback: try remote
      final remote = await FirestoreService.instance.fetchExamsRemote();
      for (final ex in remote) {
        await saveExam(ex);
      }
      return remote;
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteExam(String id) async {
    if (kIsWeb) {
      await FirestoreService.instance.deleteExamRemote(id);
      return;
    }
    final db = await database;
    await _ensureExamsTable(db);
    try {
      await db.delete('exams', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
    try {
      await FirestoreService.instance.deleteExamRemote(id);
    } catch (_) {}
  }

  // ─── SETTINGS ─────────────────────────────────────────────────────────────

  Future<SettingsModel> getSettings() async {
    if (kIsWeb) {
      final remote = await FirestoreService.instance.fetchSettings();
      if (remote != null) return remote;
      return SettingsModel.defaultSettings();
    }
    final db = await database;
    final maps = await db.query('settings', where: 'id = 1');
    if (maps.isEmpty) return SettingsModel.defaultSettings();
    return SettingsModel.fromMap(maps.first);
  }

  Future<void> saveSettings(SettingsModel settings) async {
    // 1. Save to local SQLite FIRST (instant < 5ms)
    if (!kIsWeb) {
      await saveSettingsLocalOnly(settings);
    }

    // 2. Sync to Firestore in background without blocking UI
    FirestoreService.instance.syncSettings(settings).catchError((e) {
      debugPrint('[Firestore] Settings sync error: $e');
    });
  }

  /// Save settings directly to local SQLite without re-broadcasting to Firestore.
  /// Used when receiving inbound updates from Firestore streams to prevent infinite sync loops.
  Future<void> saveSettingsLocalOnly(SettingsModel settings) async {
    if (kIsWeb) return;
    final db = await database;
    final map = <String, dynamic>{
      'id': 1,
      'instituteName': settings.instituteName,
      'tagline': settings.tagline,
      'logoPath': settings.logoPath,
      'address': settings.address,
      'mobile': settings.mobile,
      'email': settings.email,
      'website': settings.website,
      'principalName': settings.principalName,
      'affiliationNumber': settings.affiliationNumber,
      'principalSignature': settings.principalSignature,
      'schoolStamp': settings.schoolStamp,
      'rawSignature': settings.rawSignature,
      'signatureColorMode': settings.signatureColorMode,
      'currentSession': settings.currentSession,
      'themeMode': settings.themeMode,
      'schoolClasses': jsonEncode(settings.schoolClasses),
      'computerCourses': jsonEncode(settings.computerCourses),
      'sections': jsonEncode(settings.sections),
      'batches': jsonEncode(settings.batches),
    };
    await db.insert('settings', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ─── BACKUP & RESTORE ─────────────────────────────────────────────────────

  Future<String> getDbPath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'school_app.db');
  }

  Future<String> exportDatabase() async {
    final srcPath = await getDbPath();
    final dir = await getExternalStorageDirectory();
    final destDir = dir?.path ?? (await getApplicationDocumentsDirectory()).path;
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 16);
    final destPath = '$destDir/school_backup_$timestamp.db';
    await File(srcPath).copy(destPath);
    return destPath;
  }

  Future<void> importDatabase(String backupPath) async {
    await _db?.close();
    _db = null;
    final destPath = await getDbPath();
    await File(backupPath).copy(destPath);
    _db = await _openDatabase();
  }

  /// One-time background optimization for existing students who have heavy DPs (> 35 KB).
  /// Runs automatically once on startup, or manually on demand.
  Future<int> optimizeExistingStudentPhotos({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyDone = prefs.getBool('photos_optimized_v1') ?? false;
      if (alreadyDone && !force) return 0;

      final students = await getAllStudents();
      int optimizedCount = 0;

      for (final s in students) {
        if (s.photoPath != null && s.photoPath!.trim().isNotEmpty) {
          final optimized = await ImageCompressUtil.compressExistingPhotoString(s.photoPath);
          if (optimized != null && optimized != s.photoPath) {
            final updated = s.copyWith(photoPath: optimized);
            await updateStudent(updated);
            optimizedCount++;
          }
        }
      }

      await prefs.setBool('photos_optimized_v1', true);
      debugPrint('[DatabaseService] Optimized $optimizedCount existing student photos to 20-30 KB.');
      return optimizedCount;
    } catch (e) {
      debugPrint('[DatabaseService] Photo optimization note: $e');
      return 0;
    }
  }

}
