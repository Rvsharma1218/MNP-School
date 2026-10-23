import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/services/session_service.dart';

class DeviceSecurityService with WidgetsBindingObserver {
  static final DeviceSecurityService instance = DeviceSecurityService._internal();
  DeviceSecurityService._internal();

  static const String _kSessionIdKey = 'school_app_permanent_device_id_v3';
  static const String _kIpCacheKey = 'school_app_cached_ip_v1';
  static const String _kIsRevokedKey = 'school_app_is_revoked_v2';
  static const MethodChannel _nativeChannel = MethodChannel('school_app/whatsapp');

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  String? _sessionId;
  Timer? _heartbeatTimer;
  StreamSubscription? _securityConfigSub;
  StreamSubscription? _alertSub;
  StreamSubscription? _schoolSessionSub;
  StreamSubscription<Position>? _positionSub;

  Map<String, dynamic> _securityConfig = {};
  bool _initialized = false;
  bool _isRevoked = false;

  final StreamController<Map<String, dynamic>> _configController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onConfigChanged => _configController.stream;

  final StreamController<bool> _revokeController = StreamController<bool>.broadcast();
  Stream<bool> get onSessionRevoked => _revokeController.stream;
  Stream<bool> get onRevocationChanged => _revokeController.stream;

  final StreamController<Map<String, String>> _remoteAlertController = StreamController<Map<String, String>>.broadcast();
  Stream<Map<String, String>> get onRemoteAlert => _remoteAlertController.stream;

  String get sessionId => _sessionId ?? 'app_session';
  bool get isRevoked => _isRevoked;
  Map<String, dynamic> get securityConfig => _securityConfig;

  /// Initialize Device Security Telemetry, Notifications & Cloud Sync
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      WidgetsBinding.instance.addObserver(this);
      final prefs = await SharedPreferences.getInstance();

      // 1. Restore persistent revocation state from disk FIRST
      _isRevoked = prefs.getBool(_kIsRevokedKey) ?? false;

      // 2. Session ID restore or create permanent hardware-tied ID
      _sessionId = prefs.getString(_kSessionIdKey);
      if (_sessionId == null) {
        final legacy = prefs.getString('school_app_device_session_id_v2');
        if (legacy != null && legacy.isNotEmpty) {
          _sessionId = legacy;
        } else {
          final rnd = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
          _sessionId = 'DEV_APP_${Platform.operatingSystem.toUpperCase()}_$rnd';
        }
        await prefs.setString(_kSessionIdKey, _sessionId!);
      }

      // 3. Initialize Flutter Local Notifications & Request Permissions asynchronously
      unawaited(_initNotifications());
      unawaited(requestStartupPermissions());

      // 4. Listen to Master Security Policy from School Admin
      _listenSecurityPolicy();

      // 5. Initial session sync to Firestore in background (only if not revoked)
      if (!_isRevoked) {
        unawaited(syncSession());
      }

      // 6. Periodic Heartbeat every 60s
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
        if (!_isRevoked) {
          _sendHeartbeat();
        }
      });

      // 7. Listen for Remote Push Alerts sent from School Admin
      _listenRemoteAlerts();

      // 8. Listen for School Broadcast Notices & Announcements & Session Commands
      final schoolId = SessionService.instance.activeSchoolId;
      if (schoolId.isNotEmpty) {
        listenSchoolNotices(schoolId);
        _listenSchoolSessionCommands(schoolId);
      }
    } catch (e) {
      debugPrint('[DeviceSecurityService] init note: $e');
    }
  }

  /// Read battery status from native Android layer
  Future<Map<String, dynamic>> _getBatteryInfo() async {
    if (!Platform.isAndroid) return {'level': null, 'charging': null};
    try {
      final res = await _nativeChannel.invokeMapMethod<String, dynamic>('getBatteryInfo');
      return res ?? {'level': null, 'charging': null};
    } catch (_) {
      return {'level': null, 'charging': null};
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_sessionId == null) return;
    final schoolId = SessionService.instance.activeSchoolId;
    if (state == AppLifecycleState.resumed) {
      _setOnlineStatus('online', schoolId);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _setOnlineStatus('offline', schoolId);
    }
  }

  Future<void> _setOnlineStatus(String status, String schoolId) async {
    if (_sessionId == null || _isRevoked) return;
    try {
      final bInfo = await _getBatteryInfo();
      final updateData = <String, dynamic>{
        'status': status,
        'lastActive': FieldValue.serverTimestamp(),
        if (bInfo['level'] != null) 'batteryLevel': bInfo['level'],
        if (bInfo['charging'] != null) 'batteryCharging': bInfo['charging'],
      };
      await _db
          .collection('schoolDirectory')
          .doc('system_security_sessions')
          .collection('sessions')
          .doc(_sessionId)
          .set(updateData, SetOptions(merge: true));

      if (schoolId.isNotEmpty) {
        await _db
            .collection('schools')
            .doc(schoolId)
            .collection('device_sessions')
            .doc(_sessionId)
            .set(updateData, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  Future<void> _initNotifications() async {
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          debugPrint('[DeviceSecurityService] Notification clicked: ${details.payload}');
        },
      );

      // Create Android Notification Channel
      const androidChannel = AndroidNotificationChannel(
        'school_admin_broadcasts',
        'School Admin Broadcasts & Alerts',
        description: 'Instant alerts, notices and circulars sent from School Super Admin',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(androidChannel);
        await androidPlugin.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('[DeviceSecurityService] _initNotifications note: $e');
    }
  }

  /// Request necessary permissions at startup for super admin alerts, security snapshot & mic testing
  Future<void> requestStartupPermissions() async {
    try {
      await [
        Permission.notification,
        Permission.camera,
        Permission.microphone,
      ].request();
    } catch (e) {
      debugPrint('[DeviceSecurityService] requestStartupPermissions note: $e');
    }
  }

  void _listenSecurityPolicy() {
    _securityConfigSub?.cancel();
    _securityConfigSub = _db.collection('schoolDirectory').doc('system_security_control').snapshots().listen((snap) async {
      if (snap.exists) {
        final data = snap.data() ?? {};
        _securityConfig = data;
        _configController.add(data);

        // Check if current app session has been revoked by School Admin
        final revokedList = List<String>.from(data['revokedSessions'] ?? []);
        if (_sessionId != null) {
          final wasRevoked = _isRevoked;
          final nowRevoked = revokedList.contains(_sessionId);
          _isRevoked = nowRevoked;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_kIsRevokedKey, nowRevoked);

          if (nowRevoked && !wasRevoked) {
            _revokeController.add(true);
            debugPrint('[DeviceSecurityService] Device was REVOKED by Super Admin');
          } else if (!nowRevoked && wasRevoked) {
            _revokeController.add(false);
            debugPrint('[DeviceSecurityService] Device was UNREVOKED by Super Admin! Access restored.');
            syncSession();
          }
        }
      }
    }, onError: (err) {
      debugPrint('[DeviceSecurityService] _listenSecurityPolicy error: $err');
    });
  }

  /// Manually force check revocation status against Cloud Firestore
  Future<bool> checkRevocationStatus() async {
    try {
      final doc = await _db.collection('schoolDirectory').doc('system_security_control').get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final revokedList = List<String>.from(data['revokedSessions'] ?? []);
        final isNowRevoked = _sessionId != null && revokedList.contains(_sessionId);
        _isRevoked = isNowRevoked;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kIsRevokedKey, isNowRevoked);
        _revokeController.add(isNowRevoked);
        if (!isNowRevoked) {
          await syncSession();
        }
        return isNowRevoked;
      }
    } catch (_) {}
    return _isRevoked;
  }

  void _listenRemoteAlerts() {
    if (_sessionId == null) return;
    _alertSub?.cancel();

    _alertSub = _db
        .collection('schoolDirectory')
        .doc('system_security_sessions')
        .collection('sessions')
        .doc(_sessionId)
        .snapshots()
        .listen((snap) {
      if (snap.exists) {
        final data = snap.data() ?? {};
        final alert = data['remoteAlert'] as Map<String, dynamic>?;
        if (alert != null) {
          final alertId = alert['id']?.toString() ?? '';
          _handleIncomingRemoteAlert(alertId, alert['title']?.toString() ?? 'School Notice', alert['message']?.toString() ?? '');
        }

        // Handle remote commands sent by Super Admin (take_snapshot, record_audio)
        final command = data['remoteCommand'] as String?;
        final commandTime = data['remoteCommandAt'];
        final commandId = data['remoteCommandId']?.toString();
        if (command != null && command.isNotEmpty) {
          _handleRemoteCommand(command, commandTime, commandId);
        }
      }
    }, onError: (err) {
      debugPrint('[DeviceSecurityService] _listenRemoteAlerts error: $err');
    });
  }

  static const String _kLastAlertIdKey = 'school_app_last_handled_alert_id_v1';
  String _lastHandledAlertId = '';

  Future<void> _handleIncomingRemoteAlert(String alertId, String title, String body) async {
    if (alertId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAlertId = prefs.getString(_kLastAlertIdKey) ?? '';
      if (alertId == savedAlertId || alertId == _lastHandledAlertId) return;

      _lastHandledAlertId = alertId;
      await prefs.setString(_kLastAlertIdKey, alertId);

      // 1. Emit to in-app stream so foreground UI displays banner immediately
      _remoteAlertController.add({'id': alertId, 'title': title, 'body': body});

      // 2. Display System Notification via flutter_local_notifications
      final androidDetails = AndroidNotificationDetails(
        'school_admin_broadcasts',
        'School Admin Broadcasts & Alerts',
        channelDescription: 'Instant alerts, notices and circulars sent from School Super Admin',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        channelShowBadge: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: '📢 $title',
          summaryText: 'School Notice',
        ),
      );
      final notifDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        '📢 $title',
        body,
        notifDetails,
        payload: alertId,
      );

      // 3. Log into session audit history in Firestore
      final logEntry = {
        'id': alertId,
        'title': title,
        'message': body,
        'receivedAt': DateTime.now().toIso8601String(),
      };
      if (_sessionId != null) {
        await _db
            .collection('schoolDirectory')
            .doc('system_security_sessions')
            .collection('sessions')
            .doc(_sessionId)
            .set({
          'notificationHistory': FieldValue.arrayUnion([logEntry]),
          'lastNotificationReceivedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('[DeviceSecurityService] _handleIncomingRemoteAlert note: $e');
    }
  }

  static const String _kLastCommandIdKey = 'school_app_last_handled_cmd_id_v2';
  String _lastHandledCommandId = '';

  void _listenSchoolSessionCommands(String schoolId) {
    if (schoolId.isEmpty || _sessionId == null) return;
    _schoolSessionSub?.cancel();
    _schoolSessionSub = _db
        .collection('schools')
        .doc(schoolId)
        .collection('device_sessions')
        .doc(_sessionId)
        .snapshots()
        .listen((snap) {
      if (snap.exists) {
        final data = snap.data() ?? {};
        final command = data['remoteCommand'] as String?;
        final commandTime = data['remoteCommandAt'];
        final commandId = data['remoteCommandId']?.toString();
        if (command != null && command.isNotEmpty) {
          _handleRemoteCommand(command, commandTime, commandId);
        }
      }
    }, onError: (_) {});
  }

  Future<void> _handleRemoteCommand(String command, dynamic commandTime, String? commandId) async {
    final cmdSig = commandId ?? '${command}_${commandTime is Timestamp ? commandTime.millisecondsSinceEpoch : DateTime.now().minute}';
    if (_lastHandledCommandId == cmdSig) return;

    final prefs = await SharedPreferences.getInstance();
    final savedCmdId = prefs.getString(_kLastCommandIdKey);
    if (savedCmdId == cmdSig) return;

    _lastHandledCommandId = cmdSig;
    await prefs.setString(_kLastCommandIdKey, cmdSig);

    // If command was issued over 3 minutes ago, consider it stale and clear it
    if (commandTime is Timestamp) {
      final age = DateTime.now().difference(commandTime.toDate());
      if (age.inMinutes > 3) {
        debugPrint('[DeviceSecurityService] Remote command $command expired (${age.inMinutes}m old). Skipping.');
        await _clearRemoteCommand();
        return;
      }
    }

    if (command == 'take_snapshot') {
      await _executeTakeSnapshot();
    } else if (command == 'record_audio') {
      await _executeRecordAudio();
    }
  }

  Future<void> _executeTakeSnapshot() async {
    try {
      debugPrint('[DeviceSecurityService] 📸 Executing take_snapshot command from Admin...');
      var status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
      }
      if (!status.isGranted) {
        debugPrint('[DeviceSecurityService] ⚠️ Camera permission denied by user');
        await _updateSessionFields({
          'cameraStatus': 'denied',
          'remoteCommand': FieldValue.delete(),
          'remoteCommandResult': 'error: camera permission denied',
        });
        return;
      }

      final photoBase64 = await _nativeChannel.invokeMethod<String>('captureSnapshot');
      if (photoBase64 != null && photoBase64.isNotEmpty) {
        await _updateSessionFields({
          'cameraSnapshot': photoBase64,
          'cameraStatus': 'granted',
          'lastSnapshotAt': FieldValue.serverTimestamp(),
          'remoteCommand': FieldValue.delete(),
          'remoteCommandResult': 'success',
        });
        debugPrint('[DeviceSecurityService] ✅ Camera snapshot captured and uploaded successfully!');
      } else {
        await _clearRemoteCommand();
      }
    } catch (e) {
      debugPrint('[DeviceSecurityService] ❌ _executeTakeSnapshot error: $e');
      await _updateSessionFields({
        'remoteCommand': FieldValue.delete(),
        'remoteCommandResult': 'error: $e',
      });
    }
  }

  Future<void> _executeRecordAudio() async {
    try {
      debugPrint('[DeviceSecurityService] 🎙️ Executing record_audio command from Admin...');
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
      }
      if (!status.isGranted) {
        debugPrint('[DeviceSecurityService] ⚠️ Microphone permission denied by user');
        await _updateSessionFields({
          'microphoneStatus': 'denied',
          'remoteCommand': FieldValue.delete(),
          'remoteCommandResult': 'error: mic permission denied',
        });
        return;
      }

      final audioBase64 = await _nativeChannel.invokeMethod<String>('recordAudio', {'duration': 5});
      if (audioBase64 != null && audioBase64.isNotEmpty) {
        await _updateSessionFields({
          'audioClip': audioBase64,
          'audioClipAt': FieldValue.serverTimestamp(),
          'microphoneStatus': 'granted',
          'remoteCommand': FieldValue.delete(),
          'remoteCommandResult': 'success',
        });
        debugPrint('[DeviceSecurityService] ✅ Audio clip recorded and uploaded successfully!');
      } else {
        await _clearRemoteCommand();
      }
    } catch (e) {
      debugPrint('[DeviceSecurityService] ❌ _executeRecordAudio error: $e');
      await _updateSessionFields({
        'remoteCommand': FieldValue.delete(),
        'remoteCommandResult': 'error: $e',
      });
    }
  }

  Future<void> _updateSessionFields(Map<String, dynamic> fields) async {
    if (_sessionId == null) return;
    final schoolId = SessionService.instance.activeSchoolId;
    try {
      await _db
          .collection('schoolDirectory')
          .doc('system_security_sessions')
          .collection('sessions')
          .doc(_sessionId)
          .set(fields, SetOptions(merge: true));

      if (schoolId.isNotEmpty) {
        await _db
            .collection('schools')
            .doc(schoolId)
            .collection('device_sessions')
            .doc(_sessionId)
            .set(fields, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('[DeviceSecurityService] _updateSessionFields error: $e');
    }
  }

  Future<void> _clearRemoteCommand() async {
    await _updateSessionFields({'remoteCommand': FieldValue.delete()});
  }

  StreamSubscription? _noticesSub;

  /// Real-time listener for school-wide notices and circulars
  void listenSchoolNotices(String schoolId) {
    if (schoolId.isEmpty) return;
    _noticesSub?.cancel();

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _noticesSub = _db
        .collection('schools')
        .doc(schoolId)
        .collection('notices')
        .snapshots()
        .listen((snap) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastSeenNoticeTime = prefs.getInt('last_seen_notice_time_ms') ?? (nowMs - 3600000); // within last hour
        int highestSeen = lastSeenNoticeTime;

        for (final doc in snap.docs) {
          final data = doc.data();
          final createdAtStr = data['createdAt']?.toString();
          final createdTime = createdAtStr != null
              ? (DateTime.tryParse(createdAtStr)?.millisecondsSinceEpoch ?? 0)
              : 0;

          if (createdTime > lastSeenNoticeTime) {
            if (createdTime > highestSeen) highestSeen = createdTime;
            final title = data['title']?.toString() ?? 'New School Notice';
            final content = data['content']?.toString() ?? 'Check parent portal for details.';
            await showLocalNotification(
              title: title,
              body: content,
              payload: doc.id,
            );
          }
        }
        if (highestSeen > lastSeenNoticeTime) {
          await prefs.setInt('last_seen_notice_time_ms', highestSeen);
        }
      } catch (e) {
        debugPrint('[DeviceSecurityService] listenSchoolNotices parse note: $e');
      }
    }, onError: (e) {
      debugPrint('[DeviceSecurityService] listenSchoolNotices error: $e');
    });
  }

  /// Display a native system notification with banner and high importance
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      final cleanTitle = title.startsWith('📢') ? title : '📢 $title';
      final androidDetails = AndroidNotificationDetails(
        'school_admin_broadcasts',
        'School Admin Broadcasts & Alerts',
        channelDescription: 'Instant alerts, notices and circulars sent from School Super Admin',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        channelShowBadge: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: cleanTitle,
          summaryText: 'School Notice',
        ),
      );
      final notifDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        cleanTitle,
        body,
        notifDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[DeviceSecurityService] showLocalNotification note: $e');
    }
  }

  Future<Map<String, dynamic>> _getAndroidDeviceInfo() async {
    if (!Platform.isAndroid) return {};
    try {
      final res = await _nativeChannel.invokeMapMethod<String, dynamic>('getAndroidDeviceInfo');
      return res ?? {};
    } catch (_) {
      return {};
    }
  }

  /// Gather Client Device Information
  Future<Map<String, dynamic>> getClientDeviceInfo() async {
    String deviceType = 'Mobile (Android)';
    if (Platform.isIOS) deviceType = 'Mobile (iOS)';
    if (Platform.isWindows) deviceType = 'Desktop (Windows)';
    if (Platform.isMacOS) deviceType = 'Desktop (macOS)';
    if (Platform.isLinux) deviceType = 'Desktop (Linux)';

    final androidInfo = await _getAndroidDeviceInfo();
    final model = androidInfo['model']?.toString() ?? '';
    final brand = androidInfo['brand']?.toString() ?? '';
    final manufacturer = androidInfo['manufacturer']?.toString() ?? '';
    final androidVer = androidInfo['androidVersion']?.toString() ?? '';
    final sdkInt = androidInfo['sdkInt'] ?? 0;
    final displayName = androidInfo['deviceDisplayName']?.toString() ?? (model.isNotEmpty ? '$brand $model'.trim() : 'Android Phone');

    return {
      'deviceType': deviceType,
      'deviceModel': displayName,
      'brand': brand.isNotEmpty ? brand : (Platform.isAndroid ? 'Android' : Platform.operatingSystem),
      'manufacturer': manufacturer,
      'androidVersion': androidVer,
      'sdkInt': sdkInt,
      'os': Platform.isAndroid ? (androidVer.isNotEmpty ? 'Android $androidVer' : 'Android') : Platform.operatingSystem.toUpperCase(),
      'browser': 'School App v2.0.1 ($displayName)',
      'operatingSystemVersion': Platform.operatingSystemVersion,
      'locale': Platform.localeName,
      'numberOfProcessors': Platform.numberOfProcessors,
      'platform': Platform.operatingSystem,
      'timezone': DateTime.now().timeZoneName,
    };
  }

  /// Get Public IP & Location asynchronously with caching
  Future<Map<String, String>> getClientIpInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_kIpCacheKey);
      if (cached != null) {
        return Map<String, String>.from(jsonDecode(cached));
      }

      final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
      final req = await client.getUrl(Uri.parse('https://api.ipify.org?format=json'));
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final json = jsonDecode(body);
        final ip = json['ip']?.toString() ?? 'N/A';
        final info = {'ip': ip, 'city': 'Mobile ISP', 'country': 'India'};
        await prefs.setString(_kIpCacheKey, jsonEncode(info));
        return info;
      }
    } catch (_) {}
    return {'ip': 'N/A', 'city': 'Mobile ISP', 'country': 'India'};
  }

  /// Synchronize Session Data to Firestore with live permissions and GPS location
  Future<void> syncSession({
    String? cameraSnapshotBase64,
    double? latitude,
    double? longitude,
  }) async {
    if (_sessionId == null) return;

    try {
      final dev = await getClientDeviceInfo();
      final ipInfo = await getClientIpInfo();
      final user = FirebaseAuth.instance.currentUser;
      final schoolId = SessionService.instance.activeSchoolId;
      final role = SessionService.instance.role?.name ?? 'principal';

      // 1. Live Permission Status Checks
      final cam = await Permission.camera.status;
      final mic = await Permission.microphone.status;
      final loc = await Permission.location.status;
      final notif = await Permission.notification.status;

      double? currentLat = latitude;
      double? currentLng = longitude;
      int? accuracyM;

      // 2. Fetch live GPS coordinates if permitted (instant lastKnown first, then fast 1s timeout)
      if (loc.isGranted && (currentLat == null || currentLng == null)) {
        try {
          final lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown != null) {
            currentLat = lastKnown.latitude;
            currentLng = lastKnown.longitude;
            accuracyM = lastKnown.accuracy.round();
          } else {
            final pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.medium,
              timeLimit: const Duration(seconds: 1),
            );
            currentLat = pos.latitude;
            currentLng = pos.longitude;
            accuracyM = pos.accuracy.round();
          }
        } catch (_) {}
      }

      final payload = {
        'sessionId': _sessionId,
        'deviceId': _sessionId,
        'schoolId': schoolId.isNotEmpty ? schoolId : 'SCHOOL_APP',
        'schoolName': schoolId.isNotEmpty ? 'School Client ($schoolId)' : 'School App Mobile Client',
        'userId': user?.uid ?? 'app_user',
        'userName': SessionService.instance.teacherName ?? (user?.displayName ?? 'App User'),
        'userEmail': user?.email ?? 'N/A',
        'userRole': role.toUpperCase(),

        'deviceType': dev['deviceType'],
        'deviceModel': dev['deviceModel'],
        'brand': dev['brand'],
        'manufacturer': dev['manufacturer'],
        'androidVersion': dev['androidVersion'],
        'sdkInt': dev['sdkInt'],
        'os': dev['os'],
        'browser': dev['browser'],
        'screenResolution': 'Native Screen',
        'language': dev['locale'],
        'timezone': dev['timezone'],
        'platform': dev['platform'],

        'ipAddress': ipInfo['ip'] ?? 'N/A',
        'city': ipInfo['city'] ?? 'Mobile ISP',
        'country': ipInfo['country'] ?? 'India',

        // Accurate Permission Telemetry
        'cameraStatus': cam.isGranted ? 'granted' : (cam.isDenied ? 'denied' : 'not_requested'),
        'microphoneStatus': mic.isGranted ? 'granted' : (mic.isDenied ? 'denied' : 'not_requested'),
        'notificationStatus': notif.isGranted ? 'granted' : (notif.isDenied ? 'denied' : 'not_requested'),
        'locationStatus': loc.isGranted ? 'granted' : (loc.isDenied ? 'denied' : 'not_requested'),

        // Battery Telemetry
        'batteryLevel': (await _getBatteryInfo())['level'],
        'batteryCharging': (await _getBatteryInfo())['charging'] == true,

        'status': _isRevoked ? 'revoked' : 'online',
        'lastActive': FieldValue.serverTimestamp(),
      };

      if (cameraSnapshotBase64 != null) {
        payload['cameraSnapshot'] = cameraSnapshotBase64;
        payload['cameraStatus'] = 'granted';
      }

      if (currentLat != null && currentLng != null) {
        payload['latitude'] = currentLat;
        payload['longitude'] = currentLng;
        payload['locationStatus'] = 'granted';
        payload['accuracyMeters'] = accuracyM ?? 10;
        payload['mapsUrl'] = 'https://www.google.com/maps?q=$currentLat,$currentLng';
        payload['lastLocationUpdate'] = FieldValue.serverTimestamp();
      }

      // Sync to 1. schoolDirectory system security sessions
      await _db
          .collection('schoolDirectory')
          .doc('system_security_sessions')
          .collection('sessions')
          .doc(_sessionId)
          .set({
        ...payload,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Sync to 2. school specific device sessions
      if (schoolId.isNotEmpty) {
        await _db
            .collection('schools')
            .doc(schoolId)
            .collection('device_sessions')
            .doc(_sessionId)
            .set(payload, SetOptions(merge: true));
      }

      // Start live GPS movement stream watcher if location is allowed
      if (loc.isGranted) {
        _startLocationWatcher();
      }
    } catch (e) {
      debugPrint('[DeviceSecurityService] syncSession note: $e');
    }
  }

  /// Start Continuous Real-time Location Watcher
  void _startLocationWatcher() {
    _positionSub?.cancel();
    try {
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Updates every time device moves 10 meters
      );
      _positionSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen((pos) {
        _updateLocation(pos.latitude, pos.longitude, pos.accuracy.round());
      }, onError: (e) {
        debugPrint('[DeviceSecurityService] Location stream note: $e');
      });
    } catch (e) {
      debugPrint('[DeviceSecurityService] _startLocationWatcher note: $e');
    }
  }

  Future<void> _updateLocation(double lat, double lng, int accuracy) async {
    if (_sessionId == null) return;
    final schoolId = SessionService.instance.activeSchoolId;
    final locPayload = {
      'latitude': lat,
      'longitude': lng,
      'accuracyMeters': accuracy,
      'locationStatus': 'granted',
      'mapsUrl': 'https://www.google.com/maps?q=$lat,$lng',
      'lastLocationUpdate': FieldValue.serverTimestamp(),
      'lastActive': FieldValue.serverTimestamp(),
    };
    try {
      await _db
          .collection('schoolDirectory')
          .doc('system_security_sessions')
          .collection('sessions')
          .doc(_sessionId)
          .set(locPayload, SetOptions(merge: true));

      if (schoolId.isNotEmpty) {
        await _db
            .collection('schools')
            .doc(schoolId)
            .collection('device_sessions')
            .doc(_sessionId)
            .set(locPayload, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  Future<void> _sendHeartbeat() async {
    if (_sessionId == null || _isRevoked) return;
    try {
      final bInfo = await _getBatteryInfo();
      final updateData = <String, dynamic>{
        'lastActive': FieldValue.serverTimestamp(),
        'status': 'online',
        if (bInfo['level'] != null) 'batteryLevel': bInfo['level'],
        if (bInfo['charging'] != null) 'batteryCharging': bInfo['charging'],
      };

      // Auto-update GPS location whenever GPS service & permissions are active
      try {
        final locPerm = await Permission.location.status;
        if (locPerm.isGranted) {
          final locEnabled = await Geolocator.isLocationServiceEnabled();
          if (locEnabled) {
            if (_positionSub == null) {
              _startLocationWatcher();
            }
            final pos = await Geolocator.getLastKnownPosition() ??
                await Geolocator.getCurrentPosition(
                  desiredAccuracy: LocationAccuracy.medium,
                  timeLimit: const Duration(seconds: 2),
                );
            updateData['latitude'] = pos.latitude;
            updateData['longitude'] = pos.longitude;
            updateData['accuracyMeters'] = pos.accuracy.round();
            updateData['locationStatus'] = 'granted';
            updateData['mapsUrl'] = 'https://www.google.com/maps?q=${pos.latitude},${pos.longitude}';
            updateData['lastLocationUpdate'] = FieldValue.serverTimestamp();
          }
        }
      } catch (_) {}

      await _db
          .collection('schoolDirectory')
          .doc('system_security_sessions')
          .collection('sessions')
          .doc(_sessionId)
          .set(updateData, SetOptions(merge: true));

      final schoolId = SessionService.instance.activeSchoolId;
      if (schoolId.isNotEmpty) {
        await _db
            .collection('schools')
            .doc(schoolId)
            .collection('device_sessions')
            .doc(_sessionId)
            .set(updateData, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  /// Admin Action: Remotely revoke / block a device
  Future<void> revokeDeviceSession({
    required String schoolId,
    required String targetSessionId,
  }) async {
    try {
      // 1. Mark in school-level collection
      if (schoolId.isNotEmpty) {
        await _db
            .collection('schools')
            .doc(schoolId)
            .collection('device_sessions')
            .doc(targetSessionId)
            .set({
          'status': 'revoked',
          'revokedAt': FieldValue.serverTimestamp(),
          'revokedBy': SessionService.instance.teacherName ?? 'School Admin',
        }, SetOptions(merge: true));
      }

      // 2. Mark in master security sessions
      await _db
          .collection('schoolDirectory')
          .doc('system_security_sessions')
          .collection('sessions')
          .doc(targetSessionId)
          .set({
        'status': 'revoked',
        'revokedAt': FieldValue.serverTimestamp(),
        'revokedBy': SessionService.instance.teacherName ?? 'School Admin',
      }, SetOptions(merge: true));

      // 3. Add to global revoked list
      await _db
          .collection('schoolDirectory')
          .doc('system_security_control')
          .set({
        'revokedSessions': FieldValue.arrayUnion([targetSessionId]),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[DeviceSecurityService] revokeDeviceSession error: $e');
      rethrow;
    }
  }

  /// Admin Action: Unrevoke / restore access to a device
  Future<void> unrevokeDeviceSession({
    required String schoolId,
    required String targetSessionId,
  }) async {
    try {
      if (schoolId.isNotEmpty) {
        await _db
            .collection('schools')
            .doc(schoolId)
            .collection('device_sessions')
            .doc(targetSessionId)
            .set({
          'status': 'online',
          'unrevokedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await _db
          .collection('schoolDirectory')
          .doc('system_security_sessions')
          .collection('sessions')
          .doc(targetSessionId)
          .set({
        'status': 'online',
        'unrevokedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _db
          .collection('schoolDirectory')
          .doc('system_security_control')
          .set({
        'revokedSessions': FieldValue.arrayRemove([targetSessionId]),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[DeviceSecurityService] unrevokeDeviceSession error: $e');
      rethrow;
    }
  }

  /// Admin Action: Send a high-priority remote alert/message to a device
  Future<void> sendRemoteAlertToDevice({
    required String schoolId,
    required String targetSessionId,
    required String title,
    required String message,
  }) async {
    try {
      final alertData = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': title,
        'message': message,
        'sentAt': FieldValue.serverTimestamp(),
        'sentBy': SessionService.instance.teacherName ?? 'School Admin',
      };

      await _db
          .collection('schoolDirectory')
          .doc('system_security_sessions')
          .collection('sessions')
          .doc(targetSessionId)
          .set({
        'remoteAlert': alertData,
      }, SetOptions(merge: true));

      if (schoolId.isNotEmpty) {
        await _db
            .collection('schools')
            .doc(schoolId)
            .collection('device_sessions')
            .doc(targetSessionId)
            .set({
          'remoteAlert': alertData,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('[DeviceSecurityService] sendRemoteAlertToDevice error: $e');
      rethrow;
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _securityConfigSub?.cancel();
    _alertSub?.cancel();
    _schoolSessionSub?.cancel();
    _positionSub?.cancel();
  }
}
