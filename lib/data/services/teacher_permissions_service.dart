import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/teacher_permissions.dart';
import 'session_service.dart';

class TeacherPermissionsService {
  static final TeacherPermissionsService instance = TeacherPermissionsService._internal();
  TeacherPermissionsService._internal() {
    _listenToSchoolChanges();
  }

  static const _kPrefKey = 'teacher_permissions_config';
  TeacherPermissions _permissions = const TeacherPermissions();
  final ValueNotifier<TeacherPermissions> permissionsNotifier =
      ValueNotifier<TeacherPermissions>(const TeacherPermissions());

  TeacherPermissions get permissions => _permissions;
  StreamSubscription? _remoteSub;
  StreamSubscription? _schoolSub;
  String? _currentSchoolId;

  void _listenToSchoolChanges() {
    _schoolSub?.cancel();
    _schoolSub = SessionService.instance.onSchoolUidChanged.listen((newSchoolId) {
      if (newSchoolId != null && newSchoolId.isNotEmpty) {
        unawaited(syncWithSchool(newSchoolId));
      }
    });
  }

  Future<void> init() async {
    final schoolId = SessionService.instance.activeSchoolId;
    await syncWithSchool(schoolId);
  }

  Future<void> syncWithSchool(String schoolId) async {
    if (schoolId.isEmpty) return;
    if (_currentSchoolId == schoolId && _remoteSub != null) return;
    _currentSchoolId = schoolId;

    // 1. Load school-specific local cache first
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '${_kPrefKey}_$schoolId';
      final raw = prefs.getString(cacheKey) ?? prefs.getString(_kPrefKey);
      if (raw != null && raw.isNotEmpty) {
        _permissions = TeacherPermissions.fromJson(raw);
        permissionsNotifier.value = _permissions;
      }
    } catch (e) {
      debugPrint('[TeacherPermissionsService] Local load error: $e');
    }

    // 2. Attach real-time Firestore listener
    try {
      await _remoteSub?.cancel();
      _remoteSub = FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('settings')
          .doc('teacher_permissions')
          .snapshots()
          .listen((doc) async {
        if (doc.exists && doc.data() != null) {
          _permissions = TeacherPermissions.fromMap(doc.data()!);
          permissionsNotifier.value = _permissions;
          final prefs = await SharedPreferences.getInstance();
          final cacheKey = '${_kPrefKey}_$schoolId';
          await prefs.setString(cacheKey, _permissions.toJson());
          await prefs.setString(_kPrefKey, _permissions.toJson());
        }
      }, onError: (e) {
        debugPrint('[TeacherPermissionsService] Remote sync note: $e');
      });
    } catch (e) {
      debugPrint('[TeacherPermissionsService] Remote sync listener error: $e');
    }
  }

  Future<void> savePermissions(TeacherPermissions newPermissions) async {
    _permissions = newPermissions;
    permissionsNotifier.value = newPermissions;

    final schoolId = SessionService.instance.activeSchoolId;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '${_kPrefKey}_$schoolId';
      await prefs.setString(cacheKey, newPermissions.toJson());
      await prefs.setString(_kPrefKey, newPermissions.toJson());
    } catch (e) {
      debugPrint('[TeacherPermissionsService] Pref save error: $e');
    }

    if (schoolId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('settings')
            .doc('teacher_permissions')
            .set(newPermissions.toMap(), SetOptions(merge: true));
      } catch (e) {
        debugPrint('[TeacherPermissionsService] Firestore save error: $e');
      }
    }
  }

  /// Check if the currently logged in role is allowed to access a specific module.
  /// If logged in as Principal/Admin, access is ALWAYS granted.
  /// If logged in as Teacher, checks the specific permission flag.
  bool isAllowed(bool Function(TeacherPermissions p) checker) {
    if (SessionService.instance.isPrincipal) {
      return true; // Principal always has full access
    }
    return checker(_permissions);
  }
}

final teacherPermissionsProvider = StateNotifierProvider<TeacherPermissionsNotifier, TeacherPermissions>((ref) {
  return TeacherPermissionsNotifier();
});

class TeacherPermissionsNotifier extends StateNotifier<TeacherPermissions> {
  TeacherPermissionsNotifier() : super(TeacherPermissionsService.instance.permissions) {
    TeacherPermissionsService.instance.permissionsNotifier.addListener(_listener);
    TeacherPermissionsService.instance.init().then((_) {
      if (mounted) {
        state = TeacherPermissionsService.instance.permissions;
      }
    });
  }

  void _listener() {
    if (mounted) {
      state = TeacherPermissionsService.instance.permissions;
    }
  }

  Future<void> update(TeacherPermissions newPermissions) async {
    await TeacherPermissionsService.instance.savePermissions(newPermissions);
    if (mounted) {
      state = newPermissions;
    }
  }

  @override
  void dispose() {
    TeacherPermissionsService.instance.permissionsNotifier.removeListener(_listener);
    super.dispose();
  }
}
