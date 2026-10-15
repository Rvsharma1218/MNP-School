import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/teacher_model.dart';

class TeacherService {
  static final TeacherService instance = TeacherService._internal();
  TeacherService._internal();

  static const _secondaryAppName = 'teacherAdmin';

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference _schoolRoot(String schoolUid) =>
      _db.collection('schools').doc(schoolUid);

  CollectionReference _teachersCol(String schoolUid) =>
      _schoolRoot(schoolUid).collection('teachers');

  DocumentReference _directoryDoc(String schoolEmail) =>
      _db.collection('schoolDirectory').doc(_normalizeEmail(schoolEmail));

  CollectionReference _publicTeachersCol(String schoolEmail) =>
      _directoryDoc(schoolEmail).collection('teachersPublic');

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  Future<void> ensureSchoolDirectoryEntry({
    required String schoolEmail,
    required String schoolUid,
    required String instituteName,
  }) async {
    try {
      await _directoryDoc(schoolEmail).set({
        'schoolUid': schoolUid,
        'schoolId': schoolUid,
        'instituteName': instituteName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[TeacherService] ⚠️ Could not update school directory: $e');
    }
  }

  Future<Map<String, String>?> lookupSchoolByEmail(String schoolEmail) async {
    final snap = await _directoryDoc(schoolEmail).get();
    if (!snap.exists) return null;
    final data = snap.data() as Map<String, dynamic>;
    final uid = (data['schoolId'] as String?) ?? (data['schoolUid'] as String?);
    if (uid == null) return null;
    return {
      'schoolUid': uid,
      'schoolId': uid,
      'instituteName': (data['instituteName'] as String?) ?? '',
    };
  }

  Future<List<TeacherModel>> listPublicTeachers(String schoolEmail, {String? schoolUid}) async {
    final Map<String, TeacherModel> byId = {};
    try {
      final snap = await _publicTeachersCol(schoolEmail)
          .where('active', isEqualTo: true)
          .get();
      for (final d in snap.docs) {
        final t = TeacherModel.fromPublicMap(d.data() as Map<String, dynamic>);
        if (t.active) {
          final key = t.teacherId.isNotEmpty ? t.teacherId : t.authUid;
          byId[key] = t;
        }
      }
    } catch (e) {
      debugPrint('[TeacherService] Note on listPublicTeachers: $e');
    }

    if (schoolUid != null && schoolUid.isNotEmpty) {
      try {
        final snap = await _teachersCol(schoolUid).get();
        for (final d in snap.docs) {
          final t = TeacherModel.fromMap(d.data() as Map<String, dynamic>);
          if (t.active) {
            final key = t.teacherId.isNotEmpty ? t.teacherId : t.authUid;
            byId[key] = t;
          }
        }
      } catch (e) {
        debugPrint('[TeacherService] Note on fallback teachersCol: $e');
      }
    }

    final list = byId.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  List<TeacherModel> _cachedTeachers = [];
  List<TeacherModel> get cachedTeachers => List.unmodifiable(_cachedTeachers);

  void clearTeacherCache() {
    _cachedTeachers.clear();
  }

  Future<List<TeacherModel>> listAllTeachers(String schoolUid, {bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedTeachers.isNotEmpty) {
      _refreshTeachersBackground(schoolUid);
      return _cachedTeachers;
    }

    try {
      // 1. Try local cache first for sub-10ms response
      try {
        final cacheSnap = await _teachersCol(schoolUid).get(const GetOptions(source: Source.cache));
        if (cacheSnap.docs.isNotEmpty) {
          _cachedTeachers = cacheSnap.docs
              .map((d) => TeacherModel.fromMap(d.data() as Map<String, dynamic>))
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
          _refreshTeachersBackground(schoolUid);
          return _cachedTeachers;
        }
      } catch (_) {}

      // 2. Fetch from server and cache
      final snap = await _teachersCol(schoolUid).get().timeout(const Duration(seconds: 5));
      _cachedTeachers = snap.docs
          .map((d) => TeacherModel.fromMap(d.data() as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return _cachedTeachers;
    } catch (e) {
      if (_cachedTeachers.isNotEmpty) return _cachedTeachers;
      rethrow;
    }
  }

  void _refreshTeachersBackground(String schoolUid) {
    _teachersCol(schoolUid).get(const GetOptions(source: Source.server)).then((snap) {
      if (snap.docs.isNotEmpty) {
        _cachedTeachers = snap.docs
            .map((d) => TeacherModel.fromMap(d.data() as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
      }
    }).catchError((_) {});
  }

  String _randomSuffix() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random.secure();
    return List.generate(8, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<String> getNextSequentialTeacherId(String schoolUid) async {
    try {
      final snap = await _teachersCol(schoolUid).get();
      int maxSeq = 0;
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final docId = doc.id;
        final tId = (data['teacherId'] as String?) ?? (data['id'] as String?) ?? docId;
        
        final match = RegExp(r'T(?:CH)?(\d+)', caseSensitive: false).firstMatch(tId);
        if (match != null && match.group(1) != null) {
          final n = int.tryParse(match.group(1)!);
          if (n != null && n > maxSeq) {
            maxSeq = n;
          }
        }
      }
      return 'T${(maxSeq + 1).toString().padLeft(3, '0')}';
    } catch (_) {
      return 'T001';
    }
  }

  Future<UserCredential> _createAuthAccountViaSecondaryApp({
    required String email,
    required String password,
  }) async {
    final appName = '${_secondaryAppName}_${DateTime.now().millisecondsSinceEpoch}';
    final secondaryApp = await Firebase.initializeApp(
      name: appName,
      options: Firebase.app().options,
    );
    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await secondaryAuth.signOut();
      return cred;
    } finally {
      await secondaryApp.delete();
    }
  }

  Future<TeacherModel> createTeacher({
    required String schoolUid,
    required String schoolEmail,
    required String name,
    required String password,
    String? mobile,
    String? assignedClass,
    String? assignedSection,
    String? instituteName,
    String? fatherName,
    String? motherName,
    DateTime? dob,
    String? gender,
    String? address,
    String? alternateMobile,
    String? aadhaarNumber,
    String? qualification,
    String? designation,
    String? subject,
    DateTime? joiningDate,
    double? salary,
    String? photoUrl,
    String? aadhaarDocUrl,
  }) async {
    final teacherId = await getNextSequentialTeacherId(schoolUid);
    final effectiveSchoolEmail = schoolEmail.isNotEmpty ? schoolEmail : '${schoolUid.toLowerCase()}@school.com';
    
    // Format: firstname.teacherid@schoolid.teachers
    final cleanName = name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final namePart = cleanName.length > 12 ? cleanName.substring(0, 12) : cleanName;
    final schoolPart = schoolUid.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final syntheticEmail =
        '${namePart.isEmpty ? 'teacher' : namePart}.${teacherId.toLowerCase()}@${schoolPart.isEmpty ? 'school001' : schoolPart}.teachers';

    String authUid = teacherId;
    try {
      final cred = await _createAuthAccountViaSecondaryApp(
        email: syntheticEmail,
        password: password,
      );
      if (cred.user != null) {
        authUid = cred.user!.uid;
      }
    } catch (e) {
      debugPrint('[TeacherService] Secondary Auth create note: $e');
    }

    final teacher = TeacherModel(
      authUid: authUid,
      teacherId: teacherId,
      id: teacherId,
      name: name.trim(),
      authEmail: syntheticEmail,
      email: syntheticEmail,
      mobile: mobile?.trim() ?? '',
      password: password,
      schoolId: schoolUid,
      assignedClass: assignedClass?.trim().isEmpty == true ? null : assignedClass?.trim(),
      assignedSection: assignedSection?.trim().isEmpty == true ? null : assignedSection?.trim(),
      active: true,
      status: 'active',
      createdAt: DateTime.now(),
      fatherName: fatherName?.trim(),
      motherName: motherName?.trim(),
      dob: dob,
      gender: gender ?? 'Male',
      address: address?.trim(),
      alternateMobile: alternateMobile?.trim(),
      aadhaarNumber: aadhaarNumber?.trim(),
      qualification: qualification?.trim(),
      designation: designation?.trim(),
      subject: subject?.trim(),
      joiningDate: joiningDate,
      salary: salary ?? 25000.0,
      photoUrl: photoUrl,
      aadhaarDocUrl: aadhaarDocUrl,
    );

    final teacherDocData = {
      'active': true,
      'assignedClass': teacher.assignedClass,
      'assignedSection': teacher.assignedSection,
      'authEmail': syntheticEmail,
      'authUid': authUid,
      'createdAt': FieldValue.serverTimestamp(),
      'email': syntheticEmail,
      'id': teacherId,
      'mobile': teacher.mobile,
      'name': teacher.name,
      'password': password,
      'schoolId': schoolUid,
      'status': 'active',
      'teacherId': teacherId,
      'updatedAt': FieldValue.serverTimestamp(),
      'fatherName': teacher.fatherName,
      'motherName': teacher.motherName,
      'dob': teacher.dob?.toIso8601String(),
      'gender': teacher.gender,
      'address': teacher.address,
      'alternateMobile': teacher.alternateMobile,
      'aadhaarNumber': teacher.aadhaarNumber,
      'qualification': teacher.qualification,
      'designation': teacher.designation,
      'subject': teacher.subject,
      'joiningDate': teacher.joiningDate?.toIso8601String(),
      'salary': teacher.salary,
      'photoUrl': teacher.photoUrl,
      'aadhaarDocUrl': teacher.aadhaarDocUrl,
      'aadhaarDocPath': teacher.aadhaarDocUrl,
      'aadhaarCardUrl': teacher.aadhaarDocUrl,
    };

    // 1. Primary: Save in school's teachers subcollection by teacherId
    await _teachersCol(schoolUid).doc(teacherId).set(teacherDocData, SetOptions(merge: true));

    // 2. Auxiliary writes into public directory for login dropdown
    try {
      if (effectiveSchoolEmail.isNotEmpty) {
        await _publicTeachersCol(effectiveSchoolEmail).doc(teacherId).set({
          ...teacher.toPublicMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await _directoryDoc(effectiveSchoolEmail).set({
          'instituteName': instituteName ?? 'Smart School',
          'schoolId': schoolUid,
          'schoolName': instituteName ?? 'Smart School',
          'schoolUid': schoolUid,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('[TeacherService] Note on publicTeachersCol: $e');
    }

    // 3. Save in global users collection
    try {
      await _db.collection('users').doc(authUid).set({
        'id': authUid,
        'uid': authUid,
        'name': teacher.name,
        'email': syntheticEmail,
        'authEmail': syntheticEmail,
        'mobile': teacher.mobile,
        'password': password,
        'role': 'teacher',
        'schoolId': schoolUid,
        'active': true,
        'status': 'active',
        'assignedClass': teacher.assignedClass,
        'assignedSection': teacher.assignedSection,
        'instituteName': instituteName ?? 'Smart School',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'fatherName': teacher.fatherName,
        'qualification': teacher.qualification,
        'designation': teacher.designation,
        'salary': teacher.salary,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[TeacherService] Note on users collection write: $e');
    }

    // Update in-memory cache immediately for real-time list reflection
    _cachedTeachers = [
      teacher,
      ..._cachedTeachers.where((t) => t.teacherId != teacher.teacherId && t.authUid != teacher.authUid),
    ]..sort((a, b) => a.name.compareTo(b.name));

    return teacher;
  }

  Future<void> updateTeacherDetails({
    required String schoolUid,
    required String schoolEmail,
    required TeacherModel teacher,
    required String newName,
    String? assignedClass,
    String? assignedSection,
    String? mobile,
    String? password,
    String? fatherName,
    String? motherName,
    DateTime? dob,
    String? gender,
    String? address,
    String? alternateMobile,
    String? aadhaarNumber,
    String? qualification,
    String? designation,
    String? subject,
    DateTime? joiningDate,
    double? salary,
    String? photoUrl,
    String? aadhaarDocUrl,
  }) async {
    final effectiveSchoolEmail = schoolEmail.isNotEmpty ? schoolEmail : '${schoolUid.toLowerCase()}@school.com';
    final updates = <String, dynamic>{
      'name': newName.trim(),
      'assignedClass': assignedClass?.trim().isEmpty == true ? null : assignedClass?.trim(),
      'assignedSection': assignedSection?.trim().isEmpty == true ? null : assignedSection?.trim(),
      if (mobile != null) 'mobile': mobile.trim(),
      if (password != null && password.isNotEmpty) 'password': password.trim(),
      if (fatherName != null) 'fatherName': fatherName.trim(),
      if (motherName != null) 'motherName': motherName.trim(),
      if (dob != null) 'dob': dob.toIso8601String(),
      if (gender != null) 'gender': gender,
      if (address != null) 'address': address.trim(),
      if (alternateMobile != null) 'alternateMobile': alternateMobile.trim(),
      if (aadhaarNumber != null) 'aadhaarNumber': aadhaarNumber.trim(),
      if (qualification != null) 'qualification': qualification.trim(),
      if (designation != null) 'designation': designation.trim(),
      if (subject != null) 'subject': subject.trim(),
      if (joiningDate != null) 'joiningDate': joiningDate.toIso8601String(),
      if (salary != null) 'salary': salary,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (aadhaarDocUrl != null) ...{
        'aadhaarDocUrl': aadhaarDocUrl,
        'aadhaarDocPath': aadhaarDocUrl,
        'aadhaarCardUrl': aadhaarDocUrl,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _teachersCol(schoolUid).doc(teacher.teacherId).set(updates, SetOptions(merge: true));
    if (teacher.authUid != teacher.teacherId) {
      await _teachersCol(schoolUid).doc(teacher.authUid).set(updates, SetOptions(merge: true)).catchError((_) {});
    }
    try {
      if (effectiveSchoolEmail.isNotEmpty) {
        await _publicTeachersCol(effectiveSchoolEmail).doc(teacher.teacherId).set(updates, SetOptions(merge: true)).catchError((_) {});
        if (teacher.authUid != teacher.teacherId) {
          await _publicTeachersCol(effectiveSchoolEmail).doc(teacher.authUid).set(updates, SetOptions(merge: true)).catchError((_) {});
        }
      }
    } catch (_) {}
    try {
      await _db.collection('users').doc(teacher.authUid).set({
        'name': newName.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (mobile != null) 'mobile': mobile.trim(),
        if (password != null) 'password': password.trim(),
        if (salary != null) 'salary': salary,
      }, SetOptions(merge: true));
    } catch (_) {}

    // Update in-memory cache
    final updatedTeacher = teacher.copyWith(
      name: newName.trim(),
      mobile: mobile?.trim(),
      assignedClass: assignedClass?.trim(),
      assignedSection: assignedSection?.trim(),
      fatherName: fatherName?.trim(),
      motherName: motherName?.trim(),
      dob: dob,
      gender: gender,
      address: address?.trim(),
      alternateMobile: alternateMobile?.trim(),
      aadhaarNumber: aadhaarNumber?.trim(),
      qualification: qualification?.trim(),
      designation: designation?.trim(),
      subject: subject?.trim(),
      joiningDate: joiningDate,
      salary: salary,
      photoUrl: photoUrl,
      aadhaarDocUrl: aadhaarDocUrl,
    );
    final idx = _cachedTeachers.indexWhere((t) => t.teacherId == teacher.teacherId || (teacher.authUid.isNotEmpty && t.authUid == teacher.authUid));
    if (idx != -1) {
      _cachedTeachers[idx] = updatedTeacher;
    } else {
      _cachedTeachers.add(updatedTeacher);
    }
    _cachedTeachers.sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> setTeacherActive({
    required String schoolUid,
    required String schoolEmail,
    required TeacherModel teacher,
    required bool active,
  }) async {
    final updateData = {
      'active': active,
      'status': active ? 'active' : 'disabled',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _teachersCol(schoolUid).doc(teacher.teacherId).set(updateData, SetOptions(merge: true));
    if (teacher.id.isNotEmpty && teacher.id != teacher.teacherId) {
      await _teachersCol(schoolUid).doc(teacher.id).set(updateData, SetOptions(merge: true)).catchError((_) {});
    }
    if (teacher.authUid.isNotEmpty && teacher.authUid != teacher.teacherId) {
      await _teachersCol(schoolUid).doc(teacher.authUid).set(updateData, SetOptions(merge: true)).catchError((_) {});
    }
    try {
      if (schoolEmail.isNotEmpty) {
        await _publicTeachersCol(schoolEmail).doc(teacher.teacherId).set(updateData, SetOptions(merge: true)).catchError((_) {});
        if (teacher.authUid.isNotEmpty && teacher.authUid != teacher.teacherId) {
          await _publicTeachersCol(schoolEmail).doc(teacher.authUid).set(updateData, SetOptions(merge: true)).catchError((_) {});
        }
      }
    } catch (_) {}
    try {
      if (teacher.authUid.isNotEmpty) {
        await _db.collection('users').doc(teacher.authUid).set({
          'active': active,
          'status': active ? 'active' : 'disabled',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).catchError((_) {});
      }
    } catch (_) {}

    final idx = _cachedTeachers.indexWhere((t) => t.teacherId == teacher.teacherId || (teacher.authUid.isNotEmpty && t.authUid == teacher.authUid));
    if (idx != -1) {
      _cachedTeachers[idx] = _cachedTeachers[idx].copyWith(active: active, status: active ? 'active' : 'disabled');
    }
  }

  Future<TeacherModel> resetTeacherPassword({
    required String schoolUid,
    required String schoolEmail,
    required TeacherModel teacher,
    required String newPassword,
  }) async {
    final syntheticEmail =
        '${teacher.teacherId.toLowerCase()}.${_randomSuffix()}@teachers.internal';
    final cred = await _createAuthAccountViaSecondaryApp(
      email: syntheticEmail,
      password: newPassword,
    );
    final newAuthUid = cred.user!.uid;

    final migrated = TeacherModel(
      authUid: newAuthUid,
      teacherId: teacher.teacherId,
      name: teacher.name,
      authEmail: syntheticEmail,
      assignedClass: teacher.assignedClass,
      assignedSection: teacher.assignedSection,
      active: teacher.active,
      createdAt: teacher.createdAt,
    );

    final batch = _db.batch();
    batch.set(_teachersCol(schoolUid).doc(newAuthUid), migrated.toMap());
    batch.delete(_teachersCol(schoolUid).doc(teacher.authUid));
    batch.set(_publicTeachersCol(schoolEmail).doc(newAuthUid), migrated.toPublicMap());
    batch.delete(_publicTeachersCol(schoolEmail).doc(teacher.authUid));
    batch.delete(_db.collection('users').doc(teacher.authUid));
    batch.set(_db.collection('users').doc(newAuthUid), {
      'uid': newAuthUid,
      'name': teacher.name,
      'email': syntheticEmail,
      'role': 'teacher',
      'schoolId': schoolUid,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();

    return migrated;
  }

  Future<TeacherModel> signInTeacher({
    required String schoolUid,
    required String authEmail,
    required String password,
    String? teacherId,
    String? teacherName,
  }) async {
    // 1. Locate teacher document in Firestore first to get the authoritative authEmail & password
    DocumentSnapshot? docSnap;

    if (teacherId != null && teacherId.isNotEmpty) {
      try {
        final tDoc = await _teachersCol(schoolUid).doc(teacherId).get();
        if (tDoc.exists) docSnap = tDoc;
      } catch (_) {}
    }

    if (docSnap == null && authEmail.isNotEmpty) {
      try {
        final q = await _teachersCol(schoolUid).where('authEmail', isEqualTo: authEmail.trim()).limit(1).get();
        if (q.docs.isNotEmpty) docSnap = q.docs.first;
      } catch (_) {}
    }

    if (docSnap == null && authEmail.isNotEmpty) {
      try {
        final q = await _teachersCol(schoolUid).where('email', isEqualTo: authEmail.trim()).limit(1).get();
        if (q.docs.isNotEmpty) docSnap = q.docs.first;
      } catch (_) {}
    }

    if (docSnap == null && teacherName != null && teacherName.isNotEmpty) {
      try {
        final q = await _teachersCol(schoolUid).where('name', isEqualTo: teacherName.trim()).limit(1).get();
        if (q.docs.isNotEmpty) docSnap = q.docs.first;
      } catch (_) {}
    }

    // 2. Extract stored credentials from Firestore
    Map<String, dynamic> docData = {};
    String emailToUse = authEmail.trim();
    String storedPassword = '';

    if (docSnap != null && docSnap.exists) {
      docData = docSnap.data() as Map<String, dynamic>? ?? {};
      final savedEmail = (docData['authEmail'] as String?) ?? (docData['email'] as String?);
      if (savedEmail != null && savedEmail.trim().isNotEmpty) {
        emailToUse = savedEmail.trim();
      }
      storedPassword = (docData['password'] as String?)?.trim() ?? '';
    }

    if (emailToUse.isEmpty) {
      final nameClean = (teacherName ?? 'teacher').trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final tIdClean = (teacherId ?? 't001').toLowerCase();
      final sClean = schoolUid.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      emailToUse = '${nameClean.isEmpty ? 'teacher' : nameClean}.$tIdClean@${sClean.isEmpty ? 'school001' : sClean}.teachers';
    }

    // 3. Attempt Firebase Authentication
    UserCredential? cred;
    try {
      cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailToUse,
        password: password.trim(),
      );
    } catch (authError) {
      debugPrint('[TeacherService] Initial sign-in error for $emailToUse: $authError');
      
      // If password matches the stored Firestore password but Firebase Auth user is missing/mismatched:
      final passwordMatches = (storedPassword.isNotEmpty && storedPassword == password.trim()) ||
          storedPassword.isEmpty;

      if (passwordMatches) {
        try {
          // Auto-provision or update Firebase Auth account via secondary app
          final newCred = await _createAuthAccountViaSecondaryApp(
            email: emailToUse,
            password: password.trim(),
          );
          final newAuthUid = newCred.user!.uid;
          
          // Sign in with the freshly created credentials
          cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: emailToUse,
            password: password.trim(),
          );

          // Update authUid in Firestore so it's permanently synced
          if (docSnap != null && docSnap.exists) {
            await docSnap.reference.set({'authUid': newAuthUid, 'authEmail': emailToUse, 'email': emailToUse}, SetOptions(merge: true));
          }
        } catch (recoveryErr) {
          debugPrint('[TeacherService] Secondary Auth recovery error: $recoveryErr');
          // If secondary auth also had an error, rethrow the original authError or friendly message
          if (authError is FirebaseAuthException) {
            rethrow;
          }
          throw FirebaseAuthException(
            code: 'invalid-credential',
            message: 'Incorrect password for $emailToUse. Please check your credentials.',
          );
        }
      } else {
        // Password did not match stored password
        throw FirebaseAuthException(
          code: 'wrong-password',
          message: 'Incorrect password. Please try again.',
        );
      }
    }

    // 4. Verify active status
    if (docSnap != null && docSnap.exists) {
      final teacher = TeacherModel.fromMap(docData);
      if (!teacher.active) {
        await FirebaseAuth.instance.signOut();
        throw FirebaseAuthException(
          code: 'teacher-disabled',
          message: 'This teacher account has been disabled. Contact your Principal.',
        );
      }

      // Ensure global profile in users/{teacherUid}
      try {
        await _db.collection('users').doc(cred.user!.uid).set({
          'uid': cred.user!.uid,
          'name': teacher.name,
          'email': emailToUse,
          'authEmail': emailToUse,
          'password': password.trim(),
          'role': 'teacher',
          'schoolId': schoolUid,
          'active': true,
          'status': 'active',
          'assignedClass': teacher.assignedClass,
          'assignedSection': teacher.assignedSection,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Also ensure password is saved in the teacher document
        if (docSnap.exists) {
          await docSnap.reference.set({'password': password.trim(), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        } else if (teacher.teacherId.isNotEmpty) {
          await _teachersCol(schoolUid).doc(teacher.teacherId).set({'password': password.trim(), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        }
      } catch (_) {}

      return teacher;
    }

    // If teacher document was not pre-fetched, fetch or construct it now
    final finalTDoc = await _teachersCol(schoolUid).doc(teacherId ?? cred.user!.uid).get();
    if (finalTDoc.exists) {
      return TeacherModel.fromMap(finalTDoc.data() as Map<String, dynamic>);
    }

    return TeacherModel(
      authUid: cred.user!.uid,
      teacherId: teacherId ?? 'T001',
      name: teacherName ?? 'Teacher',
      authEmail: emailToUse,
      active: true,
      createdAt: DateTime.now(),
    );
  }

  Future<void> deleteTeacher({
    required String schoolUid,
    String? schoolEmail,
    required TeacherModel teacher,
  }) async {
    final idsToDelete = <String>{
      if (teacher.teacherId.isNotEmpty) teacher.teacherId,
      if (teacher.authUid.isNotEmpty) teacher.authUid,
    };

    // 1. Direct delete from school's teachers subcollection
    for (final id in idsToDelete) {
      try {
        await _teachersCol(schoolUid).doc(id).delete();
      } catch (e) {
        debugPrint('[TeacherService] Error deleting teacher doc $id: $e');
      }
    }

    // 2. Scan school's teachers subcollection to purge any duplicate or residual docs
    try {
      final snap = await _teachersCol(schoolUid).get();
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final tId = (data['teacherId'] as String?) ?? (data['id'] as String?) ?? '';
        final aUid = (data['authUid'] as String?) ?? '';
        final email = (data['authEmail'] as String?) ?? (data['email'] as String?) ?? '';

        if (idsToDelete.contains(doc.id) ||
            idsToDelete.contains(tId) ||
            idsToDelete.contains(aUid) ||
            (teacher.authEmail.isNotEmpty && email == teacher.authEmail)) {
          try {
            await doc.reference.delete();
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[TeacherService] Note on scanning teachers col delete: $e');
    }

    // 3. Clean up public directory
    if (schoolEmail != null && schoolEmail.isNotEmpty) {
      for (final id in idsToDelete) {
        try {
          await _publicTeachersCol(schoolEmail).doc(id).delete();
        } catch (_) {}
      }
    }

    // 4. Safely attempt to clean up global users
    if (teacher.authUid.isNotEmpty) {
      try {
        await _db.collection('users').doc(teacher.authUid).delete();
      } catch (_) {}
    }

    // 5. Purge from in-memory cache to ensure real-time UI reflection
    _cachedTeachers.removeWhere((t) =>
        idsToDelete.contains(t.teacherId) ||
        idsToDelete.contains(t.authUid) ||
        (teacher.authEmail.isNotEmpty && t.authEmail == teacher.authEmail));
  }
}