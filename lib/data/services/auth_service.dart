import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'database_service.dart';
import 'session_service.dart';

/// Wraps Firebase Auth for email/password login and manages user profile in users/{authUid}.
class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─── School ID Generator ────────────────────────────────────────────────────

  /// Generates the next sequential school ID: SCHOOL_001, SCHOOL_002, SCHOOL_003, SCHOOL_004...
  Future<String> generateNextSequentialSchoolId() async {
    try {
      final maxNum = await _scanMaxSchoolNum();
      final next = maxNum + 1;
      final newId = 'SCHOOL_${next.toString().padLeft(3, '0')}';
      debugPrint('[AuthService] ✅ Generated next sequential schoolId: $newId (after max $maxNum)');
      return newId;
    } catch (e) {
      debugPrint('[AuthService] Error scanning max school num: $e');
      return 'SCHOOL_001';
    }
  }

  /// Scans schoolDirectory, schools, and users to find the highest existing school number.
  Future<int> _scanMaxSchoolNum() async {
    int maxNum = 0;

    // 1. Scan schoolDirectory (publicly accessible)
    try {
      final dirSnap = await _db.collection('schoolDirectory').get()
          .timeout(const Duration(seconds: 6));
      for (final doc in dirSnap.docs) {
        final data = doc.data();
        final sId = (data['schoolId'] as String?) ?? (data['schoolUid'] as String?) ?? '';
        final n = _parseSchoolNum(sId);
        if (n > maxNum) maxNum = n;
      }
    } catch (e) {
      debugPrint('[AuthService] schoolDirectory scan: $e');
    }

    // 2. Scan schools collection
    try {
      final snap = await _db.collection('schools').get()
          .timeout(const Duration(seconds: 6));
      for (final doc in snap.docs) {
        final n = _parseSchoolNum(doc.id);
        if (n > maxNum) maxNum = n;
      }
    } catch (e) {
      debugPrint('[AuthService] schools scan: $e');
    }

    // 3. Scan users collection
    try {
      final userSnap = await _db.collection('users').get()
          .timeout(const Duration(seconds: 6));
      for (final doc in userSnap.docs) {
        final data = doc.data();
        final sId = (data['schoolId'] as String?) ?? '';
        final n = _parseSchoolNum(sId);
        if (n > maxNum) maxNum = n;
      }
    } catch (e) {
      debugPrint('[AuthService] users scan: $e');
    }

    return maxNum;
  }

  /// Parses the numeric portion from any school ID format (SCHOOL_001, school004, etc.)
  int _parseSchoolNum(String id) {
    if (id.isEmpty) return 0;
    final match = RegExp(r'(\d+)').firstMatch(id.trim());
    if (match == null) return 0;
    return int.tryParse(match.group(1)!) ?? 0;
  }

  // ─── Sign In ────────────────────────────────────────────────────────────────

  /// Signs in with email/password. FirebaseAuthException propagates so the
  /// login screen can show "wrong password", "no account", etc.
  Future<String> signIn(
      {required String email, required String password}) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user;
    if (user == null) throw Exception('Sign-in returned no user.');
    return _ensureUserProfile(user, email.trim(), password: password);
  }

  // ─── Sign Up ────────────────────────────────────────────────────────────────

  /// Creates a new account. FirebaseAuthException propagates for weak password,
  /// email already in use, etc.
  Future<String> signUp(
      {required String email, required String password}) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user;
    if (user == null) throw Exception('Sign-up returned no user.');
    return _ensureUserProfile(user, email.trim(), password: password);
  }

  // ─── Profile Setup ──────────────────────────────────────────────────────────

  Future<String> _ensureUserProfile(User user, String email, {String? password}) async {
    final cleanEmail = email.trim().toLowerCase();
    String schoolId;

    try {
      schoolId = await _resolveSchoolId(user, cleanEmail, password: password);
    } catch (e) {
      debugPrint('[AuthService] ⚠️ Firestore profile error: $e');
      schoolId = _fallbackSchoolId(user.uid);
    }

    await SessionService.instance.setPrincipalSession(schoolId);
    debugPrint('[AuthService] ✅ Session: $cleanEmail → $schoolId');
    return schoolId;
  }

  /// Reads existing schoolId from Firestore or creates a new sequential one.
  Future<String> _resolveSchoolId(User user, String cleanEmail, {String? password}) async {
    // 1. Returning user check — read their existing profile in users/{uid}
    try {
      final userSnap = await _db
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 6));

      if (userSnap.exists && userSnap.data() != null) {
        final existing = userSnap.data()!['schoolId'] as String?;
        if (password != null && password.isNotEmpty) {
          // Update password in existing profile
          await _db.collection('users').doc(user.uid).set({
            'password': password,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        if (existing != null && existing.isNotEmpty) {
          debugPrint('[AuthService] Returning user, existing schoolId: $existing');
          return existing;
        }
      }
    } catch (e) {
      debugPrint('[AuthService] users lookup note: $e');
    }

    // 2. Check schoolDirectory by email
    String schoolId = '';
    try {
      final dirSnap = await _db
          .collection('schoolDirectory')
          .doc(cleanEmail)
          .get()
          .timeout(const Duration(seconds: 6));

      if (dirSnap.exists && dirSnap.data() != null) {
        final dir = dirSnap.data()!;
        final fromDir = (dir['schoolId'] as String?) ??
            (dir['schoolUid'] as String?) ??
            '';
        if (fromDir.isNotEmpty) {
          schoolId = fromDir;
        }
      }
    } catch (e) {
      debugPrint('[AuthService] schoolDirectory lookup note: $e');
    }

    if (schoolId.isEmpty) {
      // Brand-new email → assign next available sequential school number
      schoolId = await generateNextSequentialSchoolId();
    }

    // 3. Write user profile
    try {
      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': user.displayName ?? cleanEmail.split('@')[0],
        'email': cleanEmail,
        if (password != null && password.isNotEmpty) 'password': password,
        'role': 'principal',
        'schoolId': schoolId,
        'active': true,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[AuthService] write user note: $e');
    }

    // 4. Write school directory entry
    try {
      await _db.collection('schoolDirectory').doc(cleanEmail).set({
        'schoolId': schoolId,
        'schoolUid': schoolId,
        'email': cleanEmail,
        if (password != null && password.isNotEmpty) 'password': password,
        'role': 'principal',
        'instituteName': 'Smart School',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[AuthService] write schoolDirectory note: $e');
    }

    // 5. Create schools/{schoolId} root document if not present
    try {
      final schoolDoc = await _db
          .collection('schools')
          .doc(schoolId)
          .get()
          .timeout(const Duration(seconds: 6));
      if (!schoolDoc.exists) {
        await _db.collection('schools').doc(schoolId).set({
          'schoolName': 'Smart School',
          'email': cleanEmail,
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('[AuthService] write schoolDoc note: $e');
    }

    return schoolId;
  }

  String _fallbackSchoolId(String uid) {
    final cached = SessionService.instance.activeSchoolUidOrNull;
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    return 'SCHOOL_001';
  }

  // ─── Other Auth Methods ─────────────────────────────────────────────────────

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    try {
      await DatabaseService.instance.clearAllLocalData();
      await SessionService.instance.clear();
      debugPrint('[AuthService] ✅ Local data cleared on logout');
    } catch (e) {
      debugPrint('[AuthService] ⚠️ clearAllLocalData failed: $e');
    }
    await _auth.signOut();
  }

  /// Converts a FirebaseAuthException to a human-readable message.
  String friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No account found for this email.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect password. Please check and try again.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'teacher-disabled':
        case 'user-disabled':
          return 'This teacher account has been disabled. Contact your Principal.';
        case 'teacher-not-found':
          return 'This teacher account is not linked to a school. Contact your Principal.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'network-request-failed':
          return 'Network error. Check your internet connection.';
        case 'email-already-in-use':
          return 'An account already exists for this email. Try signing in instead.';
        case 'weak-password':
          return 'Password is too weak. Use at least 6 characters.';
        case 'operation-not-allowed':
          return 'Email/password sign-in is not enabled. Contact the app admin.';
        default:
          return e.message ?? 'Authentication failed. Please try again.';
      }
    }
    if (e is Exception) {
      final msg = e.toString().replaceFirst('Exception: ', '').trim();
      if (msg.isNotEmpty && !msg.startsWith('Instance of')) return msg;
    }
    return 'Login failed. Please check your credentials and try again.';
  }
}