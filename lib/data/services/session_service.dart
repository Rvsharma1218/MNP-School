import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/teacher_model.dart';
import 'teacher_permissions_service.dart';
import 'app_notification_service.dart';

enum AppRole { principal, teacher, parent }

class SessionService {
  static final SessionService instance = SessionService._internal();
  SessionService._internal();

  static const _kRole = 'session_role';
  static const _kSchoolUid = 'session_school_uid';
  static const _kSchoolId = 'session_school_id';
  static const _kTeacherId = 'session_teacher_id';
  static const _kTeacherName = 'session_teacher_name';
  static const _kAssignedClass = 'session_assigned_class';
  static const _kAssignedSection = 'session_assigned_section';
  static const _kParentStudentId = 'session_parent_student_id';
  static const _kParentStudentName = 'session_parent_student_name';
  static const _kParentStudentClass = 'session_parent_student_class';
  static const _kParentRollNo = 'session_parent_roll_no';
  static const _kParentMobile = 'session_parent_mobile';

  AppRole? _role;
  String? _schoolId;
  String? _teacherId;
  String? _teacherName;
  String? _assignedClass;
  String? _assignedSection;
  String? _parentStudentId;
  String? _parentStudentName;
  String? _parentStudentClass;
  String? _parentRollNo;
  String? _parentMobile;
  bool _loaded = false;

  final _schoolUidController = StreamController<String?>.broadcast();
  Stream<String?> get onSchoolUidChanged => _schoolUidController.stream;

  AppRole? get role => _role;
  
  /// Active school ID for MNP School (default to SCHOOL_007 from backup)
  String get activeSchoolId => _schoolId ?? 'SCHOOL_007';
  String get activeSchoolUid => activeSchoolId;

  String? get activeSchoolUidOrNull => _schoolId;
  String? get teacherId => _teacherId;
  String? get teacherName => _teacherName;
  String? get assignedClass => _assignedClass;
  String? get assignedSection => _assignedSection;
  String? get parentStudentId => _parentStudentId;
  String? get parentStudentName => _parentStudentName;
  String? get parentStudentClass => _parentStudentClass;
  String? get parentRollNo => _parentRollNo;
  String? get parentMobile => _parentMobile;

  bool get isPrincipal => _role == AppRole.principal;
  bool get isTeacher => _role == AppRole.teacher;
  bool get isParent => _role == AppRole.parent;
  bool get hasSession => _role != null && _schoolId != null;

  bool get hasAllClassesAccess {
    if (isPrincipal) return true;
    if (!isTeacher) return true;
    final cls = _assignedClass?.trim().toLowerCase() ?? '';
    return cls == 'all' || cls == 'all classes' || cls.contains('all classes');
  }

  bool canAccessClass(String? targetClass) {
    if (isPrincipal) return true;
    if (!isTeacher) return true;
    final cls = _assignedClass?.trim() ?? '';
    if (cls.toLowerCase() == 'all' || cls.toLowerCase() == 'all classes' || cls.toLowerCase().contains('all classes')) {
      return true;
    }
    if (cls.isEmpty || cls.toLowerCase() == 'none' || cls.toLowerCase() == 'null') {
      return false; // Not assigned -> strictly unauthorized
    }
    if (targetClass == null || targetClass.trim().isEmpty) return false;
    String norm(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'^class\s*', caseSensitive: false), '').trim();
    final targetNorm = norm(targetClass);
    final allowedList = cls.split(RegExp(r'[,|]')).map(norm).where((c) => c.isNotEmpty).toList();
    if (allowedList.any((a) => a == 'all' || a == 'all classes')) return true;
    return allowedList.any((a) {
      if (a == targetNorm) return true;
      final numA = RegExp(r'\d+').firstMatch(a)?.group(0);
      final numTarget = RegExp(r'\d+').firstMatch(targetNorm)?.group(0);
      if (numA != null && numTarget != null) {
        return numA == numTarget;
      }
      return a == targetNorm;
    });
  }

  List<String> filterAllowedClasses(List<String> classes) {
    if (isPrincipal || hasAllClassesAccess) return classes;
    return classes.where((c) => canAccessClass(c)).toList();
  }

  String get assignedClassLabel {
    final cls = _assignedClass?.trim() ?? '';
    final sec = _assignedSection?.trim() ?? '';
    if (cls.toLowerCase() == 'all' || cls.toLowerCase() == 'all classes') {
      return 'All Classes (Full Access)';
    }
    if (cls.isEmpty || cls.toLowerCase() == 'none' || cls.toLowerCase() == 'null') {
      return 'No Classes Assigned';
    }
    return '$cls${sec.isNotEmpty ? ' - Sec $sec' : ''}';
  }

  Future<void> restore() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final roleStr = prefs.getString(_kRole);
    _role = roleStr == 'principal'
        ? AppRole.principal
        : roleStr == 'teacher'
        ? AppRole.teacher
        : roleStr == 'parent'
        ? AppRole.parent
        : null;
    if (_role == AppRole.parent) {
      _parentStudentId = prefs.getString(_kParentStudentId);
      _parentStudentName = prefs.getString(_kParentStudentName);
      _parentStudentClass = prefs.getString(_kParentStudentClass);
      _parentRollNo = prefs.getString(_kParentRollNo);
      _parentMobile = prefs.getString(_kParentMobile);
    }
    // Only restore a schoolId if one was actually stored (i.e., user was previously logged in).
    // Do NOT default to SCHOOL_001 here — that causes data from other schools to bleed in.
    final stored = prefs.getString(_kSchoolId) ?? prefs.getString(_kSchoolUid);
    if (stored != null && stored.isNotEmpty) {
      // Normalize: if it's a raw Firebase UID (>20 chars, not SCHOOL_xxx) ignore it
      if (stored.length > 20 && !stored.startsWith('SCHOOL_')) {
        _schoolId = null; // invalid stored value — treat as no session
        await prefs.remove(_kSchoolId);
        await prefs.remove(_kSchoolUid);
      } else {
        _schoolId = stored;
      }
    } else {
      _schoolId = null; // No session stored — force login before any data access
    }
    _teacherId = prefs.getString(_kTeacherId);
    _teacherName = prefs.getString(_kTeacherName);
    _assignedClass = prefs.getString(_kAssignedClass);
    _assignedSection = prefs.getString(_kAssignedSection);
    _loaded = true;

    // Resolve user profile from Firestore in background (non-blocking)
    _refreshRemoteUserProfile();
  }

  void _refreshRemoteUserProfile() {
    unawaited(() async {
      try {
        final currentAuthUser = FirebaseAuth.instance.currentUser;
        if (currentAuthUser != null) {
          final docSnap = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentAuthUser.uid)
              .get()
              .timeout(const Duration(seconds: 4));
          if (docSnap.exists) {
            final data = docSnap.data();
            if (data != null && data['schoolId'] != null) {
              var newSchoolId = data['schoolId'] as String;
              if (newSchoolId.length > 20 && !newSchoolId.startsWith('SCHOOL_')) {
                newSchoolId = 'SCHOOL_001';
              }
              if (newSchoolId != _schoolId) {
                _schoolId = newSchoolId;
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString(_kSchoolId, _schoolId!);
                await prefs.setString(_kSchoolUid, _schoolId!);
                _schoolUidController.add(_schoolId);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[SessionService] Note on user profile restore: $e');
      }
    }());
  }

  Future<void> setPrincipalSession(String schoolId) async {
    _role = AppRole.principal;
    final validSchoolId = (schoolId.length > 20 && !schoolId.startsWith('SCHOOL_'))
        ? 'SCHOOL_001'
        : (schoolId.isNotEmpty ? schoolId : 'SCHOOL_001');
    _schoolId = validSchoolId;
    _teacherId = null;
    _teacherName = null;
    _assignedClass = null;
    _assignedSection = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRole, 'principal');
    await prefs.setString(_kSchoolId, _schoolId!);
    await prefs.setString(_kSchoolUid, _schoolId!);
    await prefs.remove(_kTeacherId);
    await prefs.remove(_kTeacherName);
    await prefs.remove(_kAssignedClass);
    await prefs.remove(_kAssignedSection);
    _schoolUidController.add(_schoolId);
    unawaited(TeacherPermissionsService.instance.syncWithSchool(_schoolId!));
    AppNotificationService.instance.startListening();
  }

  Future<void> setTeacherSession({
    required String schoolUid,
    TeacherModel? teacher,
    String? teacherId,
    String? teacherName,
    String? assignedClass,
    String? assignedSection,
  }) async {
    _role = AppRole.teacher;
    _schoolId = schoolUid.isNotEmpty ? schoolUid : 'SCHOOL_001';
    _teacherId = teacher?.teacherId ?? teacherId;
    _teacherName = teacher?.name ?? teacherName;
    _assignedClass = teacher?.assignedClass ?? assignedClass;
    _assignedSection = teacher?.assignedSection ?? assignedSection;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRole, 'teacher');
    await prefs.setString(_kSchoolId, _schoolId!);
    await prefs.setString(_kSchoolUid, _schoolId!);
    if (_teacherId != null) await prefs.setString(_kTeacherId, _teacherId!);
    if (_teacherName != null) await prefs.setString(_kTeacherName, _teacherName!);

    if (_assignedClass != null && _assignedClass!.isNotEmpty) {
      await prefs.setString(_kAssignedClass, _assignedClass!);
    } else {
      await prefs.remove(_kAssignedClass);
    }

    if (_assignedSection != null && _assignedSection!.isNotEmpty) {
      await prefs.setString(_kAssignedSection, _assignedSection!);
    } else {
      await prefs.remove(_kAssignedSection);
    }
    _schoolUidController.add(_schoolId);
    unawaited(TeacherPermissionsService.instance.syncWithSchool(_schoolId!));
    AppNotificationService.instance.startListening();
  }

  Future<void> updateTeacherAssignedClass(String newClass, {String? newName}) async {
    final trimmed = newClass.trim();
    if (trimmed.isNotEmpty) {
      _assignedClass = trimmed;
    }
    if (newName != null && newName.trim().isNotEmpty) _teacherName = newName.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (trimmed.isNotEmpty) {
        await prefs.setString(_kAssignedClass, trimmed);
      }
      if (newName != null && newName.trim().isNotEmpty) {
        await prefs.setString(_kTeacherName, newName.trim());
      }
    } catch (_) {}
  }

  Future<void> setParentSession({
    required String schoolUid,
    required String studentId,
    required String studentName,
    String? className,
    String? rollNo,
    String? mobile,
  }) async {
    _role = AppRole.parent;
    _schoolId = schoolUid.isNotEmpty ? schoolUid : 'SCHOOL_007';
    _parentStudentId = studentId;
    _parentStudentName = studentName;
    _parentStudentClass = className;
    _parentRollNo = rollNo;
    _parentMobile = mobile;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRole, 'parent');
    await prefs.setString(_kSchoolId, _schoolId!);
    await prefs.setString(_kSchoolUid, _schoolId!);
    await prefs.setString(_kParentStudentId, studentId);
    await prefs.setString(_kParentStudentName, studentName);
    if (className != null) await prefs.setString(_kParentStudentClass, className);
    if (rollNo != null) await prefs.setString(_kParentRollNo, rollNo);
    if (mobile != null) await prefs.setString(_kParentMobile, mobile);
    _schoolUidController.add(_schoolId);
    AppNotificationService.instance.startListening(studentId: studentId);
  }

  Future<void> clear() async {
    _role = null;
    _schoolId = null;
    _teacherId = null;
    _teacherName = null;
    _assignedClass = null;
    _assignedSection = null;
    _parentStudentId = null;
    _parentStudentName = null;
    _parentStudentClass = null;
    _parentRollNo = null;
    _parentMobile = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRole);
    await prefs.remove(_kSchoolId);
    await prefs.remove(_kSchoolUid);
    await prefs.remove(_kTeacherId);
    await prefs.remove(_kTeacherName);
    await prefs.remove(_kAssignedClass);
    await prefs.remove(_kAssignedSection);
    await prefs.remove(_kParentStudentId);
    await prefs.remove(_kParentStudentName);
    await prefs.remove(_kParentStudentClass);
    await prefs.remove(_kParentRollNo);
    await prefs.remove(_kParentMobile);
  }
}