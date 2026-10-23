import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/session_service.dart';

class CampusGeofenceConfig {
  final double? latitude;
  final double? longitude;
  final double radiusMeters;
  final String campusName;
  final bool geofenceEnabled;

  const CampusGeofenceConfig({
    this.latitude,
    this.longitude,
    this.radiusMeters = 300.0,
    this.campusName = 'School Campus',
    this.geofenceEnabled = true,
  });

  bool get isConfigured => latitude != null && longitude != null;

  /// Returns clean decimal string e.g. "26.065489, 84.371769"
  String get coordinatesString {
    if (!isConfigured) return '';
    return '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}';
  }

  /// Returns formatted display with cardinal directions e.g. "26.065489° N, 84.371769° E"
  String get formattedDisplay {
    if (!isConfigured) return 'Not Configured';
    final latDir = latitude! >= 0 ? 'N' : 'S';
    final lngDir = longitude! >= 0 ? 'E' : 'W';
    return '${latitude!.abs().toStringAsFixed(6)}° $latDir, ${longitude!.abs().toStringAsFixed(6)}° $lngDir';
  }
}

class PunchResult {
  final bool isSuccess;
  final String message;
  final double? distanceMeters;
  final double? radiusMeters;
  final Position? position;

  const PunchResult({
    required this.isSuccess,
    required this.message,
    this.distanceMeters,
    this.radiusMeters,
    this.position,
  });
}

class TeacherGeofenceService {
  TeacherGeofenceService._();
  static final TeacherGeofenceService instance = TeacherGeofenceService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _getSchoolUid() {
    final active = SessionService.instance.activeSchoolUid;
    if (active.isNotEmpty) return active;
    final user = AuthService.instance.currentUser;
    return user?.uid ?? '';
  }

  /// Get school campus coordinates and allowed radius (in meters)
  Future<CampusGeofenceConfig> getCampusConfig([String? schoolUid]) async {
    final sUid = schoolUid ?? _getSchoolUid();

    // 1. First try reading from local SharedPreferences cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final cLat = prefs.getDouble('school_campus_lat');
      final cLng = prefs.getDouble('school_campus_lng');
      final cRadius = prefs.getDouble('school_campus_radius') ?? 300.0;
      final cName = prefs.getString('school_campus_name') ?? 'School Campus';
      final cEnabled = prefs.getBool('school_campus_geofence_enabled') ?? true;
      if (cLat != null && cLng != null) {
        _refreshRemoteCampusConfig(sUid);
        return CampusGeofenceConfig(
          latitude: cLat,
          longitude: cLng,
          radiusMeters: cRadius,
          campusName: cName,
          geofenceEnabled: cEnabled,
        );
      }
    } catch (_) {}

    if (sUid.isEmpty) return const CampusGeofenceConfig();

    try {
      final doc = await _db.collection('schools').doc(sUid).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final lat = (data['campusLatitude'] ?? data['latitude'] ?? data['geofenceLatitude']) as num?;
        final lng = (data['campusLongitude'] ?? data['longitude'] ?? data['geofenceLongitude']) as num?;
        final radius = (data['geofenceRadiusMeters'] ?? data['radiusMeters'] ?? 300.0) as num;
        final name = (data['schoolName'] ?? data['instituteName'] ?? 'School Campus').toString();
        final enabled = (data['geofenceEnabled'] ?? true) as bool;

        if (lat != null && lng != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble('school_campus_lat', lat.toDouble());
          await prefs.setDouble('school_campus_lng', lng.toDouble());
          await prefs.setDouble('school_campus_radius', radius.toDouble());
          await prefs.setString('school_campus_name', name);
          await prefs.setBool('school_campus_geofence_enabled', enabled);
        }

        return CampusGeofenceConfig(
          latitude: lat?.toDouble(),
          longitude: lng?.toDouble(),
          radiusMeters: radius.toDouble(),
          campusName: name,
          geofenceEnabled: enabled,
        );
      }
    } catch (e) {
      debugPrint('[TeacherGeofenceService] Error fetching campus config: $e');
    }
    return const CampusGeofenceConfig();
  }

  void _refreshRemoteCampusConfig(String sUid) async {
    if (sUid.isEmpty) return;
    try {
      final doc = await _db.collection('schools').doc(sUid).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final lat = (data['campusLatitude'] ?? data['latitude'] ?? data['geofenceLatitude']) as num?;
        final lng = (data['campusLongitude'] ?? data['longitude'] ?? data['geofenceLongitude']) as num?;
        final radius = (data['geofenceRadiusMeters'] ?? data['radiusMeters'] ?? 300.0) as num;
        final name = (data['schoolName'] ?? data['instituteName'] ?? 'School Campus').toString();
        final enabled = (data['geofenceEnabled'] ?? true) as bool;
        if (lat != null && lng != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble('school_campus_lat', lat.toDouble());
          await prefs.setDouble('school_campus_lng', lng.toDouble());
          await prefs.setDouble('school_campus_radius', radius.toDouble());
          await prefs.setString('school_campus_name', name);
          await prefs.setBool('school_campus_geofence_enabled', enabled);
        }
      }
    } catch (_) {}
  }

  /// Principal / Admin can set or update current location as School Campus Geofence
  Future<bool> setCampusLocation({
    required double latitude,
    required double longitude,
    double radiusMeters = 300.0,
    bool geofenceEnabled = true,
    String? schoolUid,
  }) async {
    // 1. Immediately save to local SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('school_campus_lat', latitude);
      await prefs.setDouble('school_campus_lng', longitude);
      await prefs.setDouble('school_campus_radius', radiusMeters);
      await prefs.setBool('school_campus_geofence_enabled', geofenceEnabled);
    } catch (_) {}

    final sUid = schoolUid ?? _getSchoolUid();
    if (sUid.isNotEmpty) {
      try {
        await _db.collection('schools').doc(sUid).set({
          'campusLatitude': latitude,
          'campusLongitude': longitude,
          'latitude': latitude,
          'longitude': longitude,
          'geofenceLatitude': latitude,
          'geofenceLongitude': longitude,
          'geofenceRadiusMeters': radiusMeters,
          'geofenceEnabled': geofenceEnabled,
          'geofenceUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[TeacherGeofenceService] Remote save error: $e');
      }
    }
    return true;
  }

  /// Check whether today's attendance has already been punched in
  Future<Map<String, dynamic>?> getTodayPunchIn({
    required String teacherId,
    String? schoolUid,
  }) async {
    final sUid = schoolUid ?? _getSchoolUid();
    if (sUid.isEmpty || teacherId.trim().isEmpty) return null;
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      final doc = await _db
          .collection('schools')
          .doc(sUid)
          .collection('teacher_attendance')
          .doc(todayStr)
          .get();

      if (doc.exists) {
        final data = doc.data() ?? {};
        final punchIns = (data['punchIns'] as Map<String, dynamic>?) ?? {};
        if (punchIns.containsKey(teacherId.trim())) {
          return Map<String, dynamic>.from(punchIns[teacherId.trim()] as Map);
        }
      }
    } catch (e) {
      debugPrint('[TeacherGeofenceService] Error checking today punch-in: $e');
    }
    return null;
  }

  /// Punch In Teacher Attendance with Live GPS Geofence Verification
  Future<PunchResult> punchIn({
    required String teacherId,
    required String teacherName,
    String? schoolUid,
  }) async {
    final cleanId = teacherId.trim();
    if (cleanId.isEmpty) {
      return const PunchResult(
        isSuccess: false,
        message: 'Invalid Teacher ID. Please log out and sign in again.',
      );
    }

    final sUid = schoolUid ?? _getSchoolUid();
    if (sUid.isEmpty) {
      return const PunchResult(isSuccess: false, message: 'School session not found. Please re-login.');
    }

    // 1. Verify Location Service is enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const PunchResult(
        isSuccess: false,
        message: 'GPS / Location is turned OFF. Please turn on Device Location (GPS) and try again.',
      );
    }

    // 2. Check & Request Location Permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return const PunchResult(
          isSuccess: false,
          message: 'Location permission denied. Please allow location access to mark attendance.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return const PunchResult(
        isSuccess: false,
        message: 'Location permission permanently denied. Please enable location permissions in App Settings.',
      );
    }

    // 3. Obtain precise current position
    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
    } catch (e) {
      // Fallback to last known position if timeout
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        position = last;
      } else {
        return PunchResult(isSuccess: false, message: 'Could not fetch current GPS location: $e');
      }
    }

    // 4. Fetch School Campus Geofence Coordinates
    final campusConfig = await getCampusConfig(sUid);

    // If campus coordinates are not configured yet, auto-configure them on first punch
    if (!campusConfig.isConfigured) {
      await setCampusLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        radiusMeters: 300.0,
        geofenceEnabled: true,
        schoolUid: sUid,
      );
    }

    final double targetLat = campusConfig.latitude ?? position.latitude;
    final double targetLng = campusConfig.longitude ?? position.longitude;
    final double allowedRadius = campusConfig.radiusMeters;

    // 5. Calculate Distance between Teacher and Campus
    final double distanceInMeters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      targetLat,
      targetLng,
    );

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final timeStr = DateFormat('hh:mm a').format(DateTime.now());

    // 6. Check Geofence Condition if geofence is enabled
    if (campusConfig.geofenceEnabled && campusConfig.isConfigured) {
      final accuracyMargin = (position.accuracy > 0 && position.accuracy <= 150) ? position.accuracy : 0.0;
      final effectiveDistance = (distanceInMeters - accuracyMargin).clamp(0.0, double.infinity);

      if (effectiveDistance > allowedRadius) {
        return PunchResult(
          isSuccess: false,
          message: 'Outside School Campus! You are ${distanceInMeters.round()}m away from school. Attendance must be marked within ${allowedRadius.round()}m of the campus.',
          distanceMeters: distanceInMeters,
          radiusMeters: allowedRadius,
          position: position,
        );
      }
    }

    // 7. Inside Geofence (or enforcement disabled) -> Save Present Attendance
    try {
      final punchData = {
        'time': FieldValue.serverTimestamp(),
        'timeStr': timeStr,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'distanceMeters': distanceInMeters.round(),
        'teacherName': teacherName,
      };

      await _db
          .collection('schools')
          .doc(sUid)
          .collection('teacher_attendance')
          .doc(todayStr)
          .set({
        'date': todayStr,
        'records': {
          cleanId: 'present',
        },
        'punchIns': {
          cleanId: punchData,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update teacher doc with last punch only if it's an existing teacher (never create phantom principal docs)
      if (!cleanId.startsWith('Pwfqg')) {
        _db.collection('schools').doc(sUid).collection('teachers').doc(cleanId).update({
          'lastPunchIn': FieldValue.serverTimestamp(),
          'lastPunchInTime': timeStr,
          'lastPunchInDate': todayStr,
        }).catchError((_) {});
      }

      return PunchResult(
        isSuccess: true,
        message: 'Punch-In Successful! Verified inside ${campusConfig.campusName} (${distanceInMeters.round()}m from center).',
        distanceMeters: distanceInMeters,
        radiusMeters: allowedRadius,
        position: position,
      );
    } catch (e) {
      return PunchResult(isSuccess: false, message: 'Error saving attendance record: $e');
    }
  }
}
