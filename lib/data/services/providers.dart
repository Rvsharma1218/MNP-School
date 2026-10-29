import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fee_model.dart';
import '../models/student_model.dart';
import '../models/attendance_model.dart';
import '../models/result_model.dart';
import '../models/settings_model.dart';
import 'database_service.dart';
import 'firestore_service.dart';
import 'session_service.dart';

// ─── SEARCH & FILTER PROVIDERS ─────────────────────────────────────────────

final studentSearchProvider = StateProvider<String>((ref) => '');
final studentFilterProvider = StateProvider<String>((ref) => 'all');
final studentStatusFilterProvider = StateProvider<String>((ref) => 'all');
final classFilterProvider = StateProvider<String>((ref) => '');
final studentSortProvider = StateProvider<String>((ref) => 'none'); // 'none' | 'name_asc' | 'name_desc' | 'roll_asc'
final admissionTypeFilterProvider = StateProvider<String>((ref) => 'all'); // 'all' | 'new' | 'old'
final rollNumberFilterProvider = StateProvider<String>((ref) => ''); // '' | specific roll number

// ─── FIRESTORE SYNC STATUS PROVIDER ──────────────────────────────────────────
// Values: 'syncing' | 'synced' | 'error' | 'offline'
// Updated by firestoreRealtimeSyncProvider when streams connect/disconnect.
// Used by DashboardScreen to show a live sync badge.
final syncStatusProvider = StateProvider<String>((ref) => 'syncing');
final sectionFilterProvider = StateProvider<String>((ref) => '');
final courseFilterProvider = StateProvider<String>((ref) => '');
final batchFilterProvider = StateProvider<String>((ref) => '');
final feeStatusFilterProvider = StateProvider<String>((ref) => 'all');

// ─── TEACHER WORKING CONTEXT ───────────────────────────────────────────────
// These hold the teacher's selected class/section that persists across
// Dashboard → Students → Attendance → Results navigation.

// Teacher class/section — default to session-assigned class so that after
// app restart the teacher immediately sees their assigned class data
// without waiting for initState to set it via addPostFrameCallback.
final teacherSelectedClassProvider = StateProvider<String>((ref) {
  return SessionService.instance.assignedClass ?? '';
});
final teacherSelectedSectionProvider = StateProvider<String>((ref) {
  return SessionService.instance.assignedSection ?? '';
});

// ─── STUDENT PROVIDERS ─────────────────────────────────────────────────────

final studentsProvider = StateNotifierProvider<StudentsNotifier, AsyncValue<List<StudentModel>>>((ref) {
  return StudentsNotifier(ref);
});

class StudentsNotifier extends StateNotifier<AsyncValue<List<StudentModel>>> {
  final Ref _ref;
  StudentsNotifier(this._ref) : super(const AsyncLoading()) {
    loadStudents();
  }

  Future<void> loadStudents() async {
    try {
      final students = await DatabaseService.instance.getAllStudents();
      state = AsyncData(students);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> addStudent(StudentModel student) async {
    await DatabaseService.instance.insertStudent(student);
    await loadStudents();
    _ref.invalidate(dashboardStatsProvider);
    // FIXED: insertStudent() above already fires the Firestore sync in the
    // background (non-blocking, with its own catchError). Awaiting a SECOND
    // syncStudent() call here was the bug — SQLite (the actual save) finished
    // instantly, but this redundant network call kept addStudent()'s Future
    // pending, so the Save button stayed on "Saving…" until the slow/hung
    // Firestore call finally resolved. That's why the student was already
    // added the moment you navigated back (SQLite had it all along) even
    // though the button never seemed to finish.
  }

  Future<void> updateStudent(StudentModel student) async {
    await DatabaseService.instance.updateStudent(student);
    await loadStudents();
    _ref.invalidate(dashboardStatsProvider);
    // See note in addStudent() above — updateStudent() already
    // fire-and-forgets its own Firestore sync internally.
  }

  Future<int> promoteStudents({
    required List<String> studentIds,
    required String targetClass,
    String? targetSection,
    required String targetSession,
    bool isPassout = false,
    double? newMonthlyFee,
    double? newTotalFee,
  }) async {
    final count = await DatabaseService.instance.promoteStudents(
      studentIds: studentIds,
      targetClass: targetClass,
      targetSection: targetSection,
      targetSession: targetSession,
      isPassout: isPassout,
      newMonthlyFee: newMonthlyFee,
      newTotalFee: newTotalFee,
    );
    await loadStudents();
    _ref.invalidate(dashboardStatsProvider);
    return count;
  }

  Future<void> deleteStudent(String id) async {
    await DatabaseService.instance.deleteStudent(id);
    await loadStudents();
    _ref.invalidate(dashboardStatsProvider);
    _ref.invalidate(feeProvider(id));
    _ref.invalidate(studentAttendanceProvider(id));
    // See note in addStudent() above — deleteStudent() already
    // fire-and-forgets its own Firestore sync internally.
  }
}

final filteredStudentsProvider = Provider<AsyncValue<List<StudentModel>>>((ref) {
  final studentsAsync = ref.watch(studentsProvider);
  final search = ref.watch(studentSearchProvider).toLowerCase().trim();
  final typeFilter = ref.watch(studentFilterProvider);
  final statusFilter = ref.watch(studentStatusFilterProvider);
  final classFilter = ref.watch(classFilterProvider);
  final sectionFilter = ref.watch(sectionFilterProvider);
  final courseFilter = ref.watch(courseFilterProvider);
  final batchFilter = ref.watch(batchFilterProvider);
  final rollFilter = ref.watch(rollNumberFilterProvider).trim().toLowerCase();
  final admissionType = ref.watch(admissionTypeFilterProvider);
  final sortOrder = ref.watch(studentSortProvider);
  final settings = ref.watch(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
  final currentSession = settings.currentSession.trim().toLowerCase();

  return studentsAsync.whenData((students) {
    var list = students.where((s) {
      if (SessionService.instance.isTeacher && !SessionService.instance.hasAllClassesAccess) {
        if (!SessionService.instance.canAccessClass(s.className)) return false;
      }
      if (typeFilter != 'all' && s.studentType != typeFilter) return false;
      if (statusFilter != 'all' && s.status != statusFilter) return false;
      if (classFilter.isNotEmpty && classFilter.toLowerCase() != 'all' && classFilter.toLowerCase() != 'none') {
        final fList = classFilter
            .split(RegExp(r'[,|]'))
            .map((c) => c.trim().toLowerCase().replaceAll(RegExp(r'^class\s*', caseSensitive: false), ''))
            .where((c) => c.isNotEmpty)
            .toList();
        final sCls = (s.className ?? '').trim().toLowerCase().replaceAll(RegExp(r'^class\s*', caseSensitive: false), '');
        if (fList.isNotEmpty && !fList.contains(sCls)) return false;
      }
      if (sectionFilter.isNotEmpty && sectionFilter.toLowerCase() != 'all' && sectionFilter.toLowerCase() != 'none' && s.section != sectionFilter) return false;
      if (courseFilter.isNotEmpty && courseFilter.toLowerCase() != 'all' && s.course != courseFilter) return false;
      if (batchFilter.isNotEmpty && batchFilter.toLowerCase() != 'all' && s.batch != batchFilter) return false;

      // Roll Number filter (active especially when class is selected)
      if (rollFilter.isNotEmpty && rollFilter != 'all') {
        final sRoll = (s.rollNumber ?? '').trim().toLowerCase();
        if (sRoll != rollFilter) return false;
      }

      // New vs Old Admission filter
      if (admissionType != 'all') {
        final sSession = (s.session ?? '').trim().toLowerCase();
        final isNew = (currentSession.isNotEmpty && sSession == currentSession) ||
            s.admissionDate.isAfter(DateTime.now().subtract(const Duration(days: 365)));
        if (admissionType == 'new' && !isNew) return false;
        if (admissionType == 'old' && isNew) return false;
      }

      if (search.isNotEmpty) {
        final match = s.name.toLowerCase().contains(search) ||
            s.admissionNumber.toLowerCase().contains(search) ||
            s.studentId.toLowerCase().contains(search) ||
            s.mobile.contains(search) ||
            s.fatherName.toLowerCase().contains(search) ||
            (s.rollNumber != null && s.rollNumber!.toLowerCase().contains(search));
        if (!match) return false;
      }
      return true;
    }).toList();

    // Apply sorting
    if (sortOrder == 'name_asc') {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (sortOrder == 'name_desc') {
      list.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
    } else if (sortOrder == 'roll_asc') {
      list.sort((a, b) {
        final rA = a.rollNumber?.trim() ?? '';
        final rB = b.rollNumber?.trim() ?? '';
        final nA = int.tryParse(rA);
        final nB = int.tryParse(rB);
        if (nA != null && nB != null) return nA.compareTo(nB);
        if (rA.isNotEmpty && rB.isNotEmpty) return rA.compareTo(rB);
        if (rA.isNotEmpty) return -1;
        if (rB.isNotEmpty) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    }

    return list;
  });
});

// ─── FEE PROVIDERS ─────────────────────────────────────────────────────────

final feeProvider = StateNotifierProvider.family<FeeNotifier, AsyncValue<FeeModel?>, String>((ref, studentId) {
  return FeeNotifier(ref, studentId);
});

class FeeNotifier extends StateNotifier<AsyncValue<FeeModel?>> {
  final Ref _ref;
  final String studentId;

  FeeNotifier(this._ref, this.studentId) : super(const AsyncLoading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final fee = await DatabaseService.instance.getFeeByStudentId(studentId);
      state = AsyncData(fee);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> updateTotal(double amount) async {
    await DatabaseService.instance.updateFeeTotal(studentId, amount);
    await _load();
    _ref.invalidate(dashboardStatsProvider);
    final fee = await DatabaseService.instance.getFeeByStudentId(studentId);
    // FIXED: await Firestore write
    if (fee != null) {
      try {
        await FirestoreService.instance.syncFee(fee);
      } catch (e) {
        debugPrint('[FeeNotifier] ❌ Firestore syncFee failed (updateTotal): $e');
      }
    }
  }

  Future<void> updateDueDate(DateTime? dueDate) async {
    await DatabaseService.instance.updateFeeDueDate(studentId, dueDate);
    await _load();
    _ref.invalidate(dashboardStatsProvider);
    final fee = await DatabaseService.instance.getFeeByStudentId(studentId);
    // FIXED: await Firestore write
    if (fee != null) {
      try {
        await FirestoreService.instance.syncFee(fee);
      } catch (e) {
        debugPrint('[FeeNotifier] ❌ Firestore syncFee failed (updateDueDate): $e');
      }
    }
  }

  Future<void> addPayment(PaymentModel payment) async {
    await DatabaseService.instance.addPayment(payment);
    await _load();
    _ref.invalidate(dashboardStatsProvider);
    // FIXED: await both Firestore writes so payment persists before app close
    try {
      await FirestoreService.instance.syncPayment(payment);
    } catch (e) {
      debugPrint('[FeeNotifier] ❌ Firestore syncPayment failed: $e');
    }
    final fee = await DatabaseService.instance.getFeeByStudentId(studentId);
    if (fee != null) {
      try {
        await FirestoreService.instance.syncFee(fee);
      } catch (e) {
        debugPrint('[FeeNotifier] ❌ Firestore syncFee failed (addPayment): $e');
      }
    }
  }
}

// ─── ATTENDANCE PROVIDERS ──────────────────────────────────────────────────

final attendanceDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final attendanceProvider = StateNotifierProvider.family<AttendanceNotifier, AsyncValue<List<AttendanceModel>>, DateTime>((ref, date) {
  return AttendanceNotifier(ref, date);
});

class AttendanceNotifier extends StateNotifier<AsyncValue<List<AttendanceModel>>> {
  final Ref _ref;
  final DateTime date;
  AttendanceNotifier(this._ref, this.date) : super(const AsyncLoading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final records = await DatabaseService.instance.getAttendanceByDate(date);
      state = AsyncData(records);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> mark(AttendanceModel attendance) async {
    // Step 1: SQLite save — instant, never fails due to network.
    await DatabaseService.instance.markAttendance(attendance);
    await _load();
    _ref.invalidate(dashboardStatsProvider);
    _ref.invalidate(studentAttendanceProvider(attendance.studentId));
    // Step 2: Firestore sync — background, fire-and-forget.
    // Do NOT await: quota exceeded / offline must not block local save.
    FirestoreService.instance.syncAttendance(attendance).catchError((e) {
      debugPrint('[AttendanceNotifier] Firestore sync skipped: $e');
      return null;
    });
  }
}

final studentAttendanceProvider = FutureProvider.family<List<AttendanceModel>, String>((ref, studentId) {
  return DatabaseService.instance.getAttendanceByStudentId(studentId);
});

// ─── RESULT PROVIDER ──────────────────────────────────────────────────────

final resultsProvider = FutureProvider.family<List<ResultModel>, String>((ref, studentId) {
  return DatabaseService.instance.getResultsByStudentId(studentId);
});

final resultNotifierProvider = StateNotifierProvider.family<ResultNotifier, void, String>((ref, studentId) {
  return ResultNotifier(ref, studentId);
});

class ResultNotifier extends StateNotifier<void> {
  final Ref _ref;
  final String studentId;

  ResultNotifier(this._ref, this.studentId) : super(null);

  // FIX: Explicitly defined parameter 'ResultModel result'
  Future<void> add(ResultModel result) async {
    await DatabaseService.instance.insertResult(result);
    _ref.invalidate(resultsProvider(studentId));
    // FIXED: await Firestore write
    try {
      await FirestoreService.instance.syncResult(result);
    } catch (e) {
      debugPrint('[ResultNotifier] ❌ Firestore syncResult failed: $e');
    }
  }

  Future<void> remove(String resultId) async {
    await DatabaseService.instance.deleteResult(resultId);
    _ref.invalidate(resultsProvider(studentId));
    // FIXED: await Firestore delete
    try {
      await FirestoreService.instance.deleteResultRemote(resultId);
    } catch (e) {
      debugPrint('[ResultNotifier] ❌ Firestore deleteResult failed: $e');
    }
  }
}

// ─── DASHBOARD PROVIDER ───────────────────────────────────────────────────

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  // Watch students so dashboard rebuilds after any add/edit/delete.
  ref.watch(studentsProvider);

  // Watch teacher class/section selection — when teacher changes class,
  // this FutureProvider automatically re-runs with the new values.
  final teacherClass   = ref.watch(teacherSelectedClassProvider);
  final teacherSection = ref.watch(teacherSelectedSectionProvider);

  final isTeacher = SessionService.instance.isTeacher;

  // ── Teacher with NO class/section selected ("All" mode) ─────────────────
  if (isTeacher && teacherClass.isEmpty) {
    if (!SessionService.instance.hasAllClassesAccess) {
      // Teacher without "All Classes" access: query all students & calculate real stats for authorized classes
      final db = DatabaseService.instance;
      final allStudents = (await db.getAllStudents())
          .where((s) => SessionService.instance.canAccessClass(s.className ?? s.course))
          .toList();
      final todayAttList = await db.getAttendanceByDate(DateTime.now());
      final attMap = {for (final a in todayAttList) a.studentId: a.status};

      int present = 0;
      int absent = 0;
      int leave = 0;
      for (final s in allStudents) {
        final st = attMap[s.id];
        if (st == 'present') {
          present++;
        } else if (st == 'absent') {
          absent++;
        } else if (st == 'leave') {
          leave++;
        }
      }

      final byClass = <String, int>{};
      for (final s in allStudents) {
        if (s.className?.isNotEmpty == true) {
          byClass[s.className!] = (byClass[s.className!] ?? 0) + 1;
        }
      }
      return DashboardStats(
        totalStudents: allStudents.length,
        schoolStudents: allStudents.length,
        computerStudents: 0,
        totalCollected: 0.0,
        totalPending: 0.0,
        presentToday: present,
        absentToday: absent,
        leaveToday: leave,
        overdueCount: 0,
        studentsByClass: byClass,
        studentsByCourse: const {},
        monthlyCollection: const [],
        isFiltered: true,
        filterLabel: 'All Assigned Classes',
      );
    }
    final db = DatabaseService.instance;
    final results = await Future.wait([
      db.getStudentCount(),           // 0
      db.getTodayAttendanceSummary(), // 1
      db.getAllFeesMap(),              // 2 — reused for pending + overdue
      db.getTotalCollected(),         // 3
      db.getStudentsByClass(),        // 4
      db.getStudentsByCourse(),       // 5
    ]);
    final total    = results[0] as int;
    final todayAtt = results[1] as Map<String, int>;
    final feesMap  = results[2] as Map<String, FeeModel>;
    final collected = results[3] as double;
    final byClass  = results[4] as Map<String, int>;
    final byCourse = results[5] as Map<String, int>;
    final seen = <String>{};
    double pending = 0.0;
    int overdueCount = 0;
    for (final fee in feesMap.values) {
      if (seen.add(fee.studentId)) {
        if (fee.remaining > 0) pending += fee.remaining;
        if (fee.isOverdue) overdueCount++;
      }
    }
    return DashboardStats(
      totalStudents: total,
      schoolStudents: total,
      computerStudents: 0,
      totalCollected: collected,
      totalPending: pending,
      presentToday: todayAtt['present'] ?? 0,
      absentToday: todayAtt['absent'] ?? 0,
      leaveToday: todayAtt['leave'] ?? 0,
      overdueCount: overdueCount,
      studentsByClass: byClass,
      studentsByCourse: byCourse,
      monthlyCollection: const [],
      isFiltered: false,
      filterLabel: 'All Classes',
    );
  }

  // ── Teacher with class/section selected ────────────────────────────────
  // Use filtered queries so stats only cover the selected class+section.
  if (isTeacher && teacherClass.isNotEmpty) {
    final db = DatabaseService.instance;
    final sec = teacherSection.isEmpty ? null : teacherSection;
    final results = await Future.wait([
      db.getStudentCountFiltered(className: teacherClass, section: sec),
      db.getTodayAttendanceSummaryFiltered(className: teacherClass, section: sec),
      db.getTotalPendingFeesFiltered(className: teacherClass, section: sec),
      db.getTotalCollectedFiltered(className: teacherClass, section: sec),
      db.getOverdueFeeCountFiltered(className: teacherClass, section: sec),
      db.getStudentsByClass(),
      db.getStudentsByCourse(),
    ]);

    final label = teacherSection.isNotEmpty
        ? 'Class $teacherClass - Section $teacherSection'
        : 'Class $teacherClass';

    return DashboardStats(
      totalStudents: results[0] as int,
      schoolStudents: results[0] as int,
      computerStudents: 0,
      totalCollected: results[3] as double,
      totalPending: results[2] as double,
      presentToday: (results[1] as Map<String, int>)['present'] ?? 0,
      absentToday: (results[1] as Map<String, int>)['absent'] ?? 0,
      leaveToday: (results[1] as Map<String, int>)['leave'] ?? 0,
      overdueCount: results[4] as int,
      studentsByClass: results[5] as Map<String, int>,
      studentsByCourse: results[6] as Map<String, int>,
      monthlyCollection: const [],
      isFiltered: true,
      filterLabel: label,
    );
  }

  // ── Principal (or teacher with no role set) ────────────────────────────
  // Run all independent DB queries in parallel instead of sequentially.
  // Also: getTodayPresentCount internally calls getTodayAttendanceSummary,
  // so we call the summary once; and getAllFeesMap is expensive (loads all
  // students+fees+payments), but both getTotalPendingFees and
  // getOverdueFeeCount call it — so we call it once and compute both here.
  final db = DatabaseService.instance;
  final results = await Future.wait([
    db.getStudentCount(),           // 0: int
    db.getStudentCountByType('school'),  // 1: int
    db.getStudentCountByType('computer'),// 2: int
    db.getTotalCollected(),         // 3: double
    db.getAllFeesMap(),              // 4: Map<String, FeeModel> — reused for pending + overdue
    db.getTodayAttendanceSummary(), // 5: Map<String, int> — reused for present count
    db.getStudentsByClass(),        // 6: Map<String, int>
    db.getStudentsByCourse(),       // 7: Map<String, int>
    db.getMonthlyCollection(),      // 8: List<Map<String, dynamic>>
  ]);

  final total     = results[0] as int;
  final school    = results[1] as int;
  final computer  = results[2] as int;
  final collected = results[3] as double;
  final feesMap   = results[4] as Map<String, FeeModel>;
  final todayAtt  = results[5] as Map<String, int>;
  final byClass   = results[6] as Map<String, int>;
  final byCourse  = results[7] as Map<String, int>;
  final monthly   = results[8] as List<Map<String, dynamic>>;

  // Compute pending + overdue from the single feesMap load
  final seen = <String>{};
  double pending = 0.0;
  int overdueCount = 0;
  for (final fee in feesMap.values) {
    if (seen.add(fee.studentId)) {
      if (fee.remaining > 0) pending += fee.remaining;
      if (fee.isOverdue) overdueCount++;
    }
  }

  return DashboardStats(
    totalStudents: total,
    schoolStudents: school,
    computerStudents: computer,
    totalCollected: collected,
    totalPending: pending,
    presentToday: todayAtt['present'] ?? 0,
    absentToday: todayAtt['absent'] ?? 0,
    leaveToday: todayAtt['leave'] ?? 0,
    overdueCount: overdueCount,
    studentsByClass: byClass,
    studentsByCourse: byCourse,
    monthlyCollection: monthly,
    isFiltered: false,
    filterLabel: '',
  );
});

class DashboardStats {
  final int totalStudents;
  final int schoolStudents;
  final int computerStudents;
  final double totalCollected;
  final double totalPending;
  final int presentToday;
  /// Absent count for today — populated for both Principal (whole-school)
  /// and Teacher (filtered to their class/section).
  final int absentToday;
  /// Leave count for today — same scoping as [absentToday].
  final int leaveToday;
  final int overdueCount;
  final Map<String, int> studentsByClass;
  final Map<String, int> studentsByCourse;
  final List<Map<String, dynamic>> monthlyCollection;
  /// True when stats are filtered to a specific class+section.
  /// False for Principal (whole-school) and Teacher with no selection.
  final bool isFiltered;
  /// Human-readable label of the active filter, e.g. "Class 8 - Section A".
  final String filterLabel;

  DashboardStats({
    required this.totalStudents,
    required this.schoolStudents,
    required this.computerStudents,
    required this.totalCollected,
    required this.totalPending,
    required this.presentToday,
    required this.absentToday,
    required this.leaveToday,
    required this.overdueCount,
    required this.studentsByClass,
    required this.studentsByCourse,
    required this.monthlyCollection,
    required this.isFiltered,
    required this.filterLabel,
  });
}

// ─── SETTINGS PROVIDER ────────────────────────────────────────────────────

final settingsProvider = StateNotifierProvider<SettingsNotifier, AsyncValue<SettingsModel>>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends StateNotifier<AsyncValue<SettingsModel>> {
  SettingsNotifier() : super(const AsyncLoading()) {
    load();
  }

  Future<void> load() async {
    try {
      final local = await DatabaseService.instance.getSettings();
      state = AsyncData(local);

      // Also immediately fetch remote settings from Firestore (vital for teachers on new/separate devices)
      final remote = await FirestoreService.instance.fetchSettings();
      if (remote != null) {
        final resolvedLogo = (remote.logoPath != null && remote.logoPath!.isNotEmpty)
            ? remote.logoPath
            : local.logoPath;
        final resolvedStamp = (remote.schoolStamp != null && remote.schoolStamp!.isNotEmpty)
            ? remote.schoolStamp
            : local.schoolStamp;
        final resolvedSig = (remote.principalSignature != null && remote.principalSignature!.isNotEmpty)
            ? remote.principalSignature
            : local.principalSignature;
        final merged = remote.copyWith(
          logoPath: resolvedLogo,
          schoolStamp: resolvedStamp,
          principalSignature: resolvedSig,
        );
        await DatabaseService.instance.saveSettingsLocalOnly(merged);
        state = AsyncData(merged);
      }
    } catch (e, st) {
      if (state.valueOrNull == null) {
        state = AsyncError(e, st);
      }
    }
  }

  void updateState(SettingsModel settings) {
    state = AsyncData(settings);
  }

  Future<void> save(SettingsModel settings) async {
    // Instant zero-flicker local state update
    state = AsyncData(settings);
    await DatabaseService.instance.saveSettings(settings);
  }
}

// ─── THEME PROVIDER ───────────────────────────────────────────────────────

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final settings = ref.watch(settingsProvider).valueOrNull;
  final initialMode = settings?.themeMode ?? 'light';
  return ThemeModeNotifier(ref, initialMode);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final Ref _ref;
  ThemeModeNotifier(this._ref, String initialMode) : super(_parseMode(initialMode));

  static ThemeMode _parseMode(String mode) {
    switch (mode.toLowerCase()) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  Future<void> setMode(String mode) async {
    state = _parseMode(mode);
    final current = _ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
    await _ref.read(settingsProvider.notifier).save(current.copyWith(themeMode: mode));
  }
}

// ─── APP LANGUAGE PROVIDER ────────────────────────────────────────────────

final appLanguageProvider = StateNotifierProvider<AppLanguageNotifier, String>((ref) {
  final settings = ref.watch(settingsProvider).valueOrNull;
  final initialLang = settings?.appLanguage ?? 'en';
  return AppLanguageNotifier(ref, initialLang);
});

class AppLanguageNotifier extends StateNotifier<String> {
  final Ref _ref;
  AppLanguageNotifier(this._ref, String initialLang) : super(initialLang);

  Future<void> setLanguage(String lang) async {
    state = lang;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', lang);
    } catch (_) {}
    final current = _ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
    await _ref.read(settingsProvider.notifier).save(current.copyWith(appLanguage: lang));
  }
}

// ─── FIRESTORE REAL-TIME SYNC + ACCOUNT SWITCHING ─────────────────────────

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final firestoreRealtimeSyncProvider = Provider<void>((ref) {
  StreamSubscription<User?>? authSub;
  StreamSubscription<String?>? sessionSub; // listens for post-login session set
  final dataSubs = <StreamSubscription>[];
  String? subscribedUid;
  bool switching = false;

  Timer? syncDebounceTimer;
  bool studentsDirty = false;
  bool statsDirty = false;

  Future<void> cancelDataSubscriptions() async {
    syncDebounceTimer?.cancel();
    studentsDirty = false;
    statsDirty = false;
    for (final sub in dataSubs) {
      await sub.cancel();
    }
    dataSubs.clear();
    subscribedUid = null;
  }

  Future<void> startForUser(User user) async {
    if (switching) return;

    // FIXED: Always use SessionService schoolId — never fall back to user.uid.
    // Falling back to user.uid for a Teacher would scope Firestore to the
    // teacher's own UID instead of the school's UID, causing a PERMISSION_DENIED
    // error (their teacher doc lives under the principal's schoolId, not their uid).
    //
    // SessionService.restore() is called in main() before Firebase init,
    // so the session should already be loaded. But restore() is idempotent, so
    // calling it again here is safe and ensures correctness.
    await SessionService.instance.restore();
    // FIXED: was reading the non-nullable `activeSchoolUid` (which always
    // falls back to the 'default_school' placeholder and is therefore NEVER
    // null), so the "no session yet, wait for login" guard below could
    // never trigger. That let a phony 'default_school' scope flow into
    // Firestore path resolution, which then silently failed every write —
    // this was the main reason new data wasn't reaching Firebase.
    final activeSchoolUid = SessionService.instance.activeSchoolUidOrNull;

    if (activeSchoolUid == null) {
      // No session stored yet — this happens on the very first app launch
      // before the user has logged in. Do nothing; auth will call us again
      // after login completes and setPrincipalSession/setTeacherSession runs.
      debugPrint('[FirestoreSync] No schoolId in session for ${user.uid} — waiting for login');
      return;
    }

    if (subscribedUid == activeSchoolUid) {
      // Already subscribed to this school context — return immediately to avoid redundant UI re-renders
      return;
    }
    switching = true;

    try {
      await cancelDataSubscriptions();

      // switchLocalUser records active school context without wiping SQLite
      await DatabaseService.instance.switchLocalUser(activeSchoolUid);

      ref.read(syncStatusProvider.notifier).state = 'synced';

      // Debounced students & dashboard refresh: consolidates initial bursts from all
      // Firestore streams (students, fees, payments, attendance) into a single coordinated data update.
      // Waiting 2500ms after the last Firestore stream event guarantees all initial
      // collections are fully inserted into SQLite before recalculating dashboard stats.
      void triggerSyncSettled({bool students = false, bool stats = true}) {
        if (students) studentsDirty = true;
        if (stats) statsDirty = true;

        syncDebounceTimer?.cancel();
        syncDebounceTimer = Timer(const Duration(milliseconds: 2500), () {
          if (studentsDirty) {
            studentsDirty = false;
            ref.read(studentsProvider.notifier).loadStudents();
          }
          if (statsDirty) {
            statsDirty = false;
            ref.invalidate(dashboardStatsProvider);
          }
        });
      }

      // ── Students stream ─────────────────────────────────────────────────
      final studentsStream = FirestoreService.instance.watchStudents();
      if (studentsStream != null) {
        dataSubs.add(studentsStream.listen((remoteStudents) async {
          final remoteIds = remoteStudents.map((s) => s.id).toSet();
          final localStudents = await DatabaseService.instance.getAllStudents();

          // Remove any local student that has been deleted on Firestore
          for (final local in localStudents) {
            if (!remoteIds.contains(local.id)) {
              await DatabaseService.instance.deleteStudentLocalOnly(local.id);
            }
          }

          // Fast batch upsert all remote students in single SQLite transaction
          await DatabaseService.instance.bulkUpsertStudentsFromRemote(remoteStudents);
          triggerSyncSettled(students: true, stats: true);
          // Update sync status — data is live!
          ref.read(syncStatusProvider.notifier).state = 'synced';
        }, onError: (e) {
          debugPrint('[FirestoreSync] students error: $e');
          final msg = e.toString();
          if (msg.contains('PERMISSION_DENIED') || msg.contains('permission-denied')) {
            ref.read(syncStatusProvider.notifier).state = 'error';
          }
        }));
      }

      // ── Fees stream (legacy aggregate fees table) ───────────────────────
      final feesStream = FirestoreService.instance.watchFees();
      if (feesStream != null) {
        dataSubs.add(feesStream.listen((remoteFees) async {
          for (final entry in remoteFees.entries) {
            await DatabaseService.instance.upsertFeeFromRemote(entry.key, entry.value);
          }
          triggerSyncSettled(stats: true);
          for (final id in remoteFees.keys) {
            ref.invalidate(feeProvider(id));
          }
        }, onError: (e) => debugPrint('[FirestoreSync] fees error: $e')));
      }

      // ── Student Fees stream (schools/{schoolId}/studentFees) ────────────
      final studentFeesStream = FirestoreService.instance.watchStudentFees();
      if (studentFeesStream != null) {
        dataSubs.add(studentFeesStream.listen((remoteFees) async {
          for (final entry in remoteFees.entries) {
            await DatabaseService.instance.upsertFeeFromRemote(entry.key, entry.value);
          }
          triggerSyncSettled(stats: true);
          for (final id in remoteFees.keys) {
            ref.invalidate(feeProvider(id));
          }
        }, onError: (e) => debugPrint('[FirestoreSync] studentFees error: $e')));
      }

      // ── Results stream (schools/{schoolId}/results) ─────────────────────
      final resultsStream = FirestoreService.instance.watchResults();
      if (resultsStream != null) {
        dataSubs.add(resultsStream.listen((results) async {
          for (final res in results) {
            await DatabaseService.instance.upsertResultFromRemote(res);
          }
        }, onError: (e) => debugPrint('[FirestoreSync] results error: $e')));
      }

      // ── Monthly Fees stream ─────────────────────────────────────────────
      final monthlyFeesStream = FirestoreService.instance.watchMonthlyFees();
      if (monthlyFeesStream != null) {
        dataSubs.add(monthlyFeesStream.listen((remoteMonthlyFees) async {
          final affectedStudentIds = <String>{};
          for (final entry in remoteMonthlyFees.entries) {
            final data = entry.value;
            final studentId = data['studentId']?.toString() ?? '';
            if (studentId.isNotEmpty) {
              await DatabaseService.instance.upsertMonthlyFeeFromRemote(studentId, data);
              affectedStudentIds.add(studentId);
            }
          }
          triggerSyncSettled(stats: true);
          for (final id in affectedStudentIds) {
            ref.invalidate(feeProvider(id));
          }
        }, onError: (e) => debugPrint('[FirestoreSync] monthly_fees error: $e')));
      }

      // ── Payments stream ─────────────────────────────────────────────────
      final paymentsStream = FirestoreService.instance.watchPayments();
      if (paymentsStream != null) {
        dataSubs.add(paymentsStream.listen((payments) async {
          for (final p in payments) {
            await DatabaseService.instance.upsertPaymentFromRemote(p.toMap());
          }
          triggerSyncSettled(stats: true);
          final ids = payments.map((p) => p.studentId).toSet();
          for (final id in ids) {
            ref.invalidate(feeProvider(id));
          }
        }, onError: (e) => debugPrint('[FirestoreSync] payments error: $e')));
      }

      // ── Attendance stream ───────────────────────────────────────────────
      final attendanceStream = FirestoreService.instance.watchAttendance();
      if (attendanceStream != null) {
        dataSubs.add(attendanceStream.listen((records) async {
          for (final record in records) {
            await DatabaseService.instance.upsertAttendanceFromRemote(record);
          }
          triggerSyncSettled(stats: true);
          final dates = records.map((r) => DateTime(r.date.year, r.date.month, r.date.day)).toSet();
          final ids = records.map((r) => r.studentId).toSet();
          for (final date in dates) {
            ref.invalidate(attendanceProvider(date));
          }
          for (final id in ids) {
            ref.invalidate(studentAttendanceProvider(id));
          }
        }, onError: (e) => debugPrint('[FirestoreSync] attendance error: $e')));
      }

      // ── Settings stream ─────────────────────────────────────────────────
      final settingsStream = FirestoreService.instance.watchSettings();
      if (settingsStream != null) {
        dataSubs.add(settingsStream.listen((remote) async {
          if (remote == null) return;
          final local = await DatabaseService.instance.getSettings();
          final resolvedLogo = (remote.logoPath != null && remote.logoPath!.isNotEmpty)
              ? remote.logoPath
              : local.logoPath;
          final resolvedStamp = (remote.schoolStamp != null && remote.schoolStamp!.isNotEmpty)
              ? remote.schoolStamp
              : local.schoolStamp;
          final resolvedSig = (remote.principalSignature != null && remote.principalSignature!.isNotEmpty)
              ? remote.principalSignature
              : local.principalSignature;
          final resolvedRawSig = (remote.rawSignature != null && remote.rawSignature!.isNotEmpty)
              ? remote.rawSignature
              : local.rawSignature;
          final resolvedColorMode = remote.signatureColorMode.isNotEmpty
              ? remote.signatureColorMode
              : local.signatureColorMode;
          final merged = remote.copyWith(
            logoPath: resolvedLogo,
            schoolStamp: resolvedStamp,
            principalSignature: resolvedSig,
            rawSignature: resolvedRawSig,
            signatureColorMode: resolvedColorMode,
          );
          // Save locally WITHOUT echo-syncing to Firestore to prevent loop
          await DatabaseService.instance.saveSettingsLocalOnly(merged);
          ref.read(settingsProvider.notifier).updateState(merged);
        }, onError: (e) => debugPrint('[FirestoreSync] settings error: $e')));
      }

      subscribedUid = activeSchoolUid;
      debugPrint('[FirestoreSync] ✅ Subscribed to school: $activeSchoolUid (role: ${SessionService.instance.role?.name})');
    } catch (e, st) {
      debugPrint('[FirestoreSync] ❌ startForUser failed: $e');
      debugPrint('$st');
    } finally {
      switching = false;
    }
  }

  Future<void> handleAuth(User? user) async {
    if (user == null) {
      // User logged out — cancel streams but do NOT wipe SQLite here.
      // clearAllLocalData() is called explicitly from the logout button/flow
      // so data is only cleared when the user intentionally signs out.
      await cancelDataSubscriptions();
      await DatabaseService.instance.switchLocalUser(null);
      ref.invalidate(studentsProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(settingsProvider);
      return;
    }
    await startForUser(user);
  }

  // ── Auth state listener ─────────────────────────────────────────────────
  // Fires on app start (session restore) and on explicit login/logout.
  authSub = FirebaseAuth.instance.authStateChanges().listen(
        (user) => handleAuth(user),
    onError: (e) => debugPrint('[AuthSync] $e'),
  );

  // ── Session change listener ────────────────────────────────────────────
  // CRITICAL FIX: authStateChanges fires BEFORE setPrincipalSession() or
  // setTeacherSession() is called in login_screen.dart. At that point,
  // SessionService.activeSchoolUid is still null, so startForUser() returns
  // early and NO Firestore streams are subscribed.
  //
  // This listener fires when setPrincipalSession/setTeacherSession emits on
  // onSchoolUidChanged. At that point the current Firebase user is available
  // and activeSchoolUid is correctly set, so we reset subscribedUid and
  // re-run startForUser() to actually subscribe all data streams.
  //
  // This means: login → data loads automatically, NO restart needed.
  sessionSub = SessionService.instance.onSchoolUidChanged.listen(
        (newSchoolUid) async {
      if (newSchoolUid == null) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      // Reset so startForUser() doesn't skip due to subscribedUid == newSchoolUid
      subscribedUid = null;
      debugPrint('[FirestoreSync] Session set → re-triggering startForUser() for $newSchoolUid');
      await startForUser(user);
    },
    onError: (e) => debugPrint('[SessionSync] $e'),
  );

  ref.onDispose(() async {
    syncDebounceTimer?.cancel();
    await authSub?.cancel();
    await sessionSub?.cancel();
    await cancelDataSubscriptions();
  });
});