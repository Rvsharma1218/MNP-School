import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../../firebase_options.dart';
import 'session_service.dart';

/// Top-level background message handler for Firebase Cloud Messaging (FCM).
/// This runs in a background isolate even when the app is completely CLOSED/TERMINATED.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    await AppNotificationService.instance.initBackgroundIsolate();

    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ?? data['title'] ?? 'School Notification';
    final body = notification?.body ?? data['body'] ?? '';
    final channelId = data['channelId'] ?? AppNotificationService.androidNoticeChannel.id;
    final channelName = data['channelName'] ?? AppNotificationService.androidNoticeChannel.name;

    await AppNotificationService.instance.showNotification(
      id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch.hashCode,
      title: title,
      body: body,
      channelId: channelId,
      channelName: channelName,
      payload: data['payload'] ?? message.data.toString(),
    );
  } catch (e) {
    debugPrint('[FCM] Background handler error: $e');
  }
}

/// Top-level background callback dispatcher for Android WorkManager.
/// Runs in an isolated background Dart thread periodically (every 15 min) as safety net.
@pragma('vm:entry-point')
void backgroundNotificationDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      await AppNotificationService.instance.initBackgroundIsolate();
      await AppNotificationService.instance.checkBackgroundUpdates();
      return true;
    } catch (e) {
      debugPrint('[WorkManager] Background task error: $e');
      return true;
    }
  });
}

class AppNotificationService {
  AppNotificationService._();
  static final AppNotificationService instance = AppNotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  final List<StreamSubscription> _subscriptions = [];

  // Notification Channels
  static const androidNoticeChannel = AndroidNotificationChannel(
    'school_notices_channel',
    'School Notices & Circulars',
    description: 'Instant alerts for school notices, exams, holidays and circulars',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  static const androidComplaintChannel = AndroidNotificationChannel(
    'parent_complaints_channel',
    'Parent Complaints & Replies',
    description: 'Instant messages and replies between Parents and School Administration',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  static const androidEnquiryChannel = AndroidNotificationChannel(
    'admissions_enquiry_channel',
    'Online Admissions & Enquiries',
    description: 'Real-time alerts for new student admission applications and teacher enquiries',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  static const androidPaymentChannel = AndroidNotificationChannel(
    'fee_payments_channel',
    'Fee Collections & Receipts',
    description: 'Alerts when fee payments are collected or recorded',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  // Keys for tracking latest processed timestamps to prevent duplicate alerts
  static const _kLastNoticeTimeKey = 'notif_last_notice_time';
  static const _kLastComplaintTimeKey = 'notif_last_complaint_time';
  static const _kLastPaymentTimeKey = 'notif_last_payment_time';

  int _lastNoticeTimestamp = 0;
  int _lastComplaintTimestamp = 0;
  int _lastPaymentTimestamp = 0;

  /// Background Isolate initialization helper (used when app is closed / killed)
  Future<void> initBackgroundIsolate() async {
    try {
      const androidInit = AndroidInitializationSettings('@drawable/ic_notification');
      const initSettings = InitializationSettings(android: androidInit);
      await _notificationsPlugin.initialize(initSettings);

      final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(androidNoticeChannel);
        await androidPlugin.createNotificationChannel(androidComplaintChannel);
        await androidPlugin.createNotificationChannel(androidEnquiryChannel);
        await androidPlugin.createNotificationChannel(androidPaymentChannel);
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[NotificationService] Background isolate init error: $e');
    }
  }

  Future<void> init() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      // Default to 30 mins ago on initial run to avoid missing recent events
      _lastNoticeTimestamp = prefs.getInt(_kLastNoticeTimeKey) ?? (nowMs - 30 * 60 * 1000);
      _lastComplaintTimestamp = prefs.getInt(_kLastComplaintTimeKey) ?? (nowMs - 30 * 60 * 1000);
      _lastPaymentTimestamp = prefs.getInt(_kLastPaymentTimeKey) ?? (nowMs - 30 * 60 * 1000);

      const androidInit = AndroidInitializationSettings('@drawable/ic_notification');
      const initSettings = InitializationSettings(android: androidInit);

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('[Notification] User tapped notification: ${response.payload}');
        },
      );

      final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(androidNoticeChannel);
        await androidPlugin.createNotificationChannel(androidComplaintChannel);
        await androidPlugin.createNotificationChannel(androidEnquiryChannel);
        await androidPlugin.createNotificationChannel(androidPaymentChannel);
        await androidPlugin.requestNotificationsPermission();
      }

      // Explicitly request notification and background battery optimization permissions
      try {
        final permStatus = await Permission.notification.status;
        if (!permStatus.isGranted) {
          await Permission.notification.request();
        }
        // Request exemption from aggressive OEM battery killer so background pushes are never blocked
        final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
        if (!batteryStatus.isGranted) {
          await Permission.ignoreBatteryOptimizations.request();
        }
      } catch (permErr) {
        debugPrint('[NotificationService] Permission request note: $permErr');
      }

      // ─── Firebase Cloud Messaging (FCM) Integration ───────────────────
      try {
        final messaging = FirebaseMessaging.instance;
        final settings = await messaging.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
        debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        // Foreground push listener
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('[FCM] Foreground push received: ${message.messageId}');
          final notification = message.notification;
          final data = message.data;

          final title = notification?.title ?? data['title'] ?? 'School Alert';
          final body = notification?.body ?? data['body'] ?? '';
          final channelId = data['channelId'] ?? androidNoticeChannel.id;
          final channelName = data['channelName'] ?? androidNoticeChannel.name;

          showNotification(
            id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch.hashCode,
            title: title,
            body: body,
            channelId: channelId,
            channelName: channelName,
            payload: data['payload'] ?? message.data.toString(),
          );
        });

        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          debugPrint('[FCM] App opened from push: ${message.data}');
        });

        // Background token sync & topic subscription
        unawaited(_syncFcmTokenAndTopics());

        // Token refresh listener
        messaging.onTokenRefresh.listen((newToken) {
          debugPrint('[FCM] Token refreshed: $newToken');
          unawaited(_saveFcmTokenToFirestore(newToken));
        });
      } catch (fcmError) {
        debugPrint('[NotificationService] FCM init note: $fcmError');
      }

      // ─── WorkManager Background Polling Safety Net ─────────────────────
      try {
        await Workmanager().initialize(
          backgroundNotificationDispatcher,
        );
        // Periodic background task (15 min interval)
        await Workmanager().registerPeriodicTask(
          'mnp_bg_sync_job',
          'mnp_bg_sync_task',
          frequency: const Duration(minutes: 15),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
          constraints: Constraints(
            networkType: NetworkType.connected,
          ),
        );
        // One-off sync task to run shortly in background
        await Workmanager().registerOneOffTask(
          'mnp_oneoff_sync_job',
          'mnp_bg_sync_task',
          initialDelay: const Duration(seconds: 10),
          existingWorkPolicy: ExistingWorkPolicy.replace,
          constraints: Constraints(
            networkType: NetworkType.connected,
          ),
        );
        debugPrint('[NotificationService] ✅ WorkManager background sync registered');
      } catch (wmError) {
        debugPrint('[NotificationService] WorkManager note: $wmError');
      }

      _initialized = true;
      debugPrint('[NotificationService] ✅ Initialized successfully');

      // Start listening based on active session
      startListening();

      // Automatically re-bind listeners whenever session or schoolId changes
      SessionService.instance.onSchoolUidChanged.listen((newUid) {
        if (newUid != null && newUid.isNotEmpty) {
          debugPrint('[NotificationService] ⚡ School ID updated to $newUid -> Re-attaching notification listeners');
          startListening();
          unawaited(_syncFcmTokenAndTopics());
        }
      });
      SessionService.instance.onSessionChanged.listen((_) {
        debugPrint('[NotificationService] ⚡ Session updated -> Re-attaching notification listeners');
        startListening();
        unawaited(_syncFcmTokenAndTopics());
      });
    } catch (e) {
      debugPrint('[NotificationService] ⚠️ Init error: $e');
    }
  }

  /// Syncs FCM token to Firestore and subscribes device to appropriate topics
  Future<void> _syncFcmTokenAndTopics() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _saveFcmTokenToFirestore(token);
      }

      final schoolId = SessionService.instance.activeSchoolId.isNotEmpty
          ? SessionService.instance.activeSchoolId
          : 'SCHOOL_007';

      // Subscribe to general school notices topics
      await messaging.subscribeToTopic('school_${schoolId}_notices');
      await messaging.subscribeToTopic('school_all_notices');

      if (!SessionService.instance.isParent) {
        await messaging.subscribeToTopic('school_${schoolId}_principal');
        await messaging.subscribeToTopic('school_SCHOOL_007_principal');
      } else {
        final studentId = SessionService.instance.parentStudentId;
        if (studentId != null && studentId.isNotEmpty) {
          final sanitizedStudentId = studentId.replaceAll(RegExp(r'[^a-zA-Z0-9-_]'), '_');
          await messaging.subscribeToTopic('parent_$sanitizedStudentId');
        }
      }
      debugPrint('[FCM] ✅ Topics subscribed successfully for school: $schoolId');
    } catch (e) {
      debugPrint('[FCM] Topic subscription note: $e');
    }
  }

  /// Saves FCM token to Firestore under schools/{schoolId}/fcm_tokens/{token}
  Future<void> _saveFcmTokenToFirestore(String token) async {
    try {
      final schoolId = SessionService.instance.activeSchoolId.isNotEmpty
          ? SessionService.instance.activeSchoolId
          : 'SCHOOL_007';
      final roleStr = SessionService.instance.role?.name ?? 'principal';
      final studentId = SessionService.instance.parentStudentId;

      final targets = <String>{schoolId, 'SCHOOL_007', 'SCHOOL_001'};
      for (final sId in targets) {
        if (sId.isEmpty) continue;
        await FirebaseFirestore.instance
            .collection('schools')
            .doc(sId)
            .collection('fcm_tokens')
            .doc(token)
            .set({
          'token': token,
          'role': roleStr,
          'studentId': studentId,
          'platform': 'android',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      debugPrint('[FCM] ✅ Token synced to Firestore: $token');
    } catch (e) {
      debugPrint('[FCM] Save token note: $e');
    }
  }

  void startListening({String? studentId}) {
    _cancelSubscriptions();

    final schoolId = SessionService.instance.activeSchoolId;
    if (schoolId.isEmpty) return;

    debugPrint('[NotificationService] Starting realtime listeners for school: $schoolId');

    // 1. Listen for Notices (All users)
    _listenForNotices(schoolId);

    // 2. Role-specific listeners:
    // If not explicitly a Parent, user is School Admin / Staff -> Listen to enquiries, payments, complaints!
    final isParent = SessionService.instance.isParent || (studentId != null && studentId.isNotEmpty);
    if (!isParent) {
      _listenForPrincipalComplaints(schoolId);
      _listenForPrincipalEnquiries(schoolId);
      _listenForPrincipalPayments(schoolId);
    } else {
      final effectiveStudentId = (studentId != null && studentId.isNotEmpty)
          ? studentId
          : SessionService.instance.parentStudentId;
      if (effectiveStudentId != null && effectiveStudentId.isNotEmpty) {
        _listenForParentReplies(effectiveStudentId);
      }
    }
  }

  void _listenForNotices(String schoolId) {
    try {
      final targets = <String>{schoolId, 'SCHOOL_007', 'SCHOOL_001'};
      for (final sId in targets) {
        if (sId.isEmpty) continue;

        bool isInitial = true;
        final sub = FirebaseFirestore.instance
            .collection('schools')
            .doc(sId)
            .collection('notices')
            .snapshots()
            .listen((snap) async {
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          final prefs = await SharedPreferences.getInstance();

          if (isInitial) {
            isInitial = false;
            for (final doc in snap.docs) {
              final notifKey = 'notif_notice_${doc.id}';
              final t = _extractTimestamp(doc.data()['createdAt']);
              // If notice was posted in the last 30 minutes and not yet alerted, notify!
              if (t > 0 && (nowMs - t) < 30 * 60 * 1000 && prefs.getBool(notifKey) != true) {
                await prefs.setBool(notifKey, true);
                final title = doc.data()['title']?.toString() ?? 'New School Notice';
                final content = doc.data()['content']?.toString() ?? '';
                final category = doc.data()['category']?.toString() ?? 'General';
                await showNotification(
                  id: doc.id.hashCode,
                  title: '📢 Notice ($category): $title',
                  body: content,
                  channelId: androidNoticeChannel.id,
                  channelName: androidNoticeChannel.name,
                  payload: 'notice_${doc.id}',
                );
              } else {
                await prefs.setBool(notifKey, true);
              }
              if (t > _lastNoticeTimestamp) _lastNoticeTimestamp = t;
            }
            await prefs.setInt(_kLastNoticeTimeKey, _lastNoticeTimestamp);
            return;
          }

          for (final change in snap.docChanges) {
            if (change.type != DocumentChangeType.added) continue;
            final doc = change.doc;
            final data = doc.data() ?? {};
            final notifKey = 'notif_notice_${doc.id}';
            if (prefs.getBool(notifKey) == true) continue;
            await prefs.setBool(notifKey, true);

            final itemTime = _extractTimestamp(data['createdAt']);
            if (itemTime > _lastNoticeTimestamp) {
              _lastNoticeTimestamp = itemTime;
              await prefs.setInt(_kLastNoticeTimeKey, itemTime);
            }

            final title = data['title']?.toString() ?? 'New School Notice';
            final content = data['content']?.toString() ?? '';
            final category = data['category']?.toString() ?? 'General';

            await showNotification(
              id: doc.id.hashCode,
              title: '📢 Notice ($category): $title',
              body: content,
              channelId: androidNoticeChannel.id,
              channelName: androidNoticeChannel.name,
              payload: 'notice_${doc.id}',
            );
          }
        }, onError: (e) => debugPrint('[NotificationService] Notice error ($sId): $e'));

        _subscriptions.add(sub);
      }
    } catch (e) {
      debugPrint('[NotificationService] Notice listen error: $e');
    }
  }

  void _listenForPrincipalComplaints(String schoolId) {
    try {
      bool isInitial = true;
      final sub = FirebaseFirestore.instance
          .collection('feedbacks')
          .snapshots()
          .listen((snap) async {
        final prefs = await SharedPreferences.getInstance();
        final nowMs = DateTime.now().millisecondsSinceEpoch;

        if (isInitial) {
          isInitial = false;
          for (final doc in snap.docs) {
            final notifKey = 'notif_complaint_${doc.id}';
            final t = _extractTimestamp(doc.data()['createdAt']);
            if (t > 0 && (nowMs - t) < 30 * 60 * 1000 && prefs.getBool(notifKey) != true) {
              await prefs.setBool(notifKey, true);
              final data = doc.data();
              final subject = data['subject']?.toString() ?? 'New Parent Message';
              final studentName = data['studentName']?.toString() ?? 'Student';
              final category = data['category']?.toString() ?? 'Parent Complaint';
              final priority = (data['priority'] ?? '').toString().toLowerCase();
              final isUrgent = priority == 'urgent' || data['urgent'] == true;

              await showNotification(
                id: doc.id.hashCode,
                title: isUrgent ? '🚨 URGENT Parent Message ($category)' : '📩 Parent Message ($category)',
                body: 'From $studentName\'s Parent: $subject',
                channelId: androidComplaintChannel.id,
                channelName: androidComplaintChannel.name,
                payload: 'complaint_${doc.id}',
              );
            } else {
              await prefs.setBool(notifKey, true);
            }
            if (t > _lastComplaintTimestamp) _lastComplaintTimestamp = t;
          }
          await prefs.setInt(_kLastComplaintTimeKey, _lastComplaintTimestamp);
          return;
        }

        for (final change in snap.docChanges) {
          if (change.type != DocumentChangeType.added) continue;
          final doc = change.doc;
          final notifKey = 'notif_complaint_${doc.id}';
          if (prefs.getBool(notifKey) == true) continue;
          await prefs.setBool(notifKey, true);

          final data = doc.data() ?? {};
          final sId = (data['schoolId'] ?? '').toString().toLowerCase();
          final isParent = data['type'] == 'parent_complaint' || data['studentId'] != null;

          if (!isParent) continue;
          if (sId.isNotEmpty && sId != schoolId.toLowerCase() && !sId.contains('school_') && !schoolId.toLowerCase().contains('007')) {
            continue;
          }

          final itemTime = _extractTimestamp(data['createdAt']);
          if (itemTime > _lastComplaintTimestamp) {
            _lastComplaintTimestamp = itemTime;
            await prefs.setInt(_kLastComplaintTimeKey, itemTime);
          }

          final subject = data['subject']?.toString() ?? 'New Parent Message';
          final studentName = data['studentName']?.toString() ?? 'Student';
          final category = data['category']?.toString() ?? 'Parent Complaint';
          final priority = (data['priority'] ?? '').toString().toLowerCase();
          final isUrgent = priority == 'urgent' || data['urgent'] == true;

          await showNotification(
            id: doc.id.hashCode,
            title: isUrgent ? '🚨 URGENT Parent Message ($category)' : '📩 Parent Message ($category)',
            body: 'From $studentName\'s Parent: $subject',
            channelId: androidComplaintChannel.id,
            channelName: androidComplaintChannel.name,
            payload: 'complaint_${doc.id}',
          );
        }
      }, onError: (e) => debugPrint('[NotificationService] Principal complaints error: $e'));

      _subscriptions.add(sub);
    } catch (e) {
      debugPrint('[NotificationService] Principal complaint listen error: $e');
    }
  }

  void _listenForPrincipalEnquiries(String schoolId) {
    try {
      final targetSchools = <String>{schoolId, 'SCHOOL_007', 'SCHOOL_001'};
      for (final sId in targetSchools) {
        if (sId.isEmpty) continue;

        // 1. Admission Enquiries
        bool isInitialAdm = true;
        final subAdm = FirebaseFirestore.instance
            .collection('schoolDirectory')
            .doc(sId)
            .collection('admissionEnquiries')
            .snapshots()
            .listen((snap) async {
          final prefs = await SharedPreferences.getInstance();
          final nowMs = DateTime.now().millisecondsSinceEpoch;

          if (isInitialAdm) {
            isInitialAdm = false;
            for (final doc in snap.docs) {
              final notifKey = 'notif_enq_${doc.id}';
              final data = doc.data();
              final itemTime = _extractTimestamp(data['createdAt'] ?? data['timestamp']);

              // If submitted in the last 45 minutes and user hasn't seen the alert yet -> notify!
              if (itemTime > 0 && (nowMs - itemTime) < 45 * 60 * 1000 && prefs.getBool(notifKey) != true) {
                await prefs.setBool(notifKey, true);
                final studentName = data['studentName'] ?? data['name'] ?? 'New Student';
                final admClass = data['admissionClass'] ?? data['class'] ?? '';
                final refNo = data['refNo'] ?? doc.id;

                await showNotification(
                  id: doc.id.hashCode,
                  title: '🎓 New Admission Application ($admClass)',
                  body: '$studentName applied for Class $admClass (Ref: $refNo)',
                  channelId: androidEnquiryChannel.id,
                  channelName: androidEnquiryChannel.name,
                  payload: 'enquiry_${doc.id}',
                );
              } else {
                await prefs.setBool(notifKey, true);
              }
            }
            return;
          }

          for (final change in snap.docChanges) {
            if (change.type != DocumentChangeType.added) continue;
            final doc = change.doc;
            final notifKey = 'notif_enq_${doc.id}';
            if (prefs.getBool(notifKey) == true) continue;
            await prefs.setBool(notifKey, true);

            final data = doc.data() ?? {};
            final studentName = data['studentName'] ?? data['name'] ?? 'New Student';
            final admClass = data['admissionClass'] ?? data['class'] ?? '';
            final refNo = data['refNo'] ?? doc.id;

            await showNotification(
              id: doc.id.hashCode,
              title: '🎓 New Admission Application ($admClass)',
              body: '$studentName applied for Class $admClass (Ref: $refNo)',
              channelId: androidEnquiryChannel.id,
              channelName: androidEnquiryChannel.name,
              payload: 'enquiry_${doc.id}',
            );
          }
        }, onError: (e) => debugPrint('[NotificationService] Admission enquiry error ($sId): $e'));
        _subscriptions.add(subAdm);

        // 2. Teacher Applications
        bool isInitialTeacher = true;
        final subTeacher = FirebaseFirestore.instance
            .collection('schoolDirectory')
            .doc(sId)
            .collection('teacherApplications')
            .snapshots()
            .listen((snap) async {
          final prefs = await SharedPreferences.getInstance();
          final nowMs = DateTime.now().millisecondsSinceEpoch;

          if (isInitialTeacher) {
            isInitialTeacher = false;
            for (final doc in snap.docs) {
              final notifKey = 'notif_teacher_enq_${doc.id}';
              final data = doc.data();
              final itemTime = _extractTimestamp(data['createdAt'] ?? data['timestamp']);

              if (itemTime > 0 && (nowMs - itemTime) < 45 * 60 * 1000 && prefs.getBool(notifKey) != true) {
                await prefs.setBool(notifKey, true);
                final name = data['name'] ?? data['fullName'] ?? 'Applicant';
                final subject = data['subject'] ?? data['post'] ?? 'Teaching Post';
                final refNo = data['refNo'] ?? doc.id;

                await showNotification(
                  id: doc.id.hashCode,
                  title: '📝 New Teacher Application: $name',
                  body: '$name applied for $subject (Ref: $refNo)',
                  channelId: androidEnquiryChannel.id,
                  channelName: androidEnquiryChannel.name,
                  payload: 'teacher_enquiry_${doc.id}',
                );
              } else {
                await prefs.setBool(notifKey, true);
              }
            }
            return;
          }

          for (final change in snap.docChanges) {
            if (change.type != DocumentChangeType.added) continue;
            final doc = change.doc;
            final notifKey = 'notif_teacher_enq_${doc.id}';
            if (prefs.getBool(notifKey) == true) continue;
            await prefs.setBool(notifKey, true);

            final data = doc.data() ?? {};
            final name = data['name'] ?? data['fullName'] ?? 'Applicant';
            final subject = data['subject'] ?? data['post'] ?? 'Teaching Post';
            final refNo = data['refNo'] ?? doc.id;

            await showNotification(
              id: doc.id.hashCode,
              title: '📝 New Teacher Application: $name',
              body: '$name applied for $subject (Ref: $refNo)',
              channelId: androidEnquiryChannel.id,
              channelName: androidEnquiryChannel.name,
              payload: 'teacher_enquiry_${doc.id}',
            );
          }
        }, onError: (e) => debugPrint('[NotificationService] Teacher enquiry error ($sId): $e'));
        _subscriptions.add(subTeacher);
      }
    } catch (e) {
      debugPrint('[NotificationService] Principal enquiry listen error: $e');
    }
  }

  void _listenForPrincipalPayments(String schoolId) {
    try {
      final targets = <String>{schoolId, 'SCHOOL_007', 'SCHOOL_001'};
      for (final sId in targets) {
        if (sId.isEmpty) continue;

        bool isInitial = true;
        final sub = FirebaseFirestore.instance
            .collection('schools')
            .doc(sId)
            .collection('payments')
            .snapshots()
            .listen((snap) async {
          final prefs = await SharedPreferences.getInstance();
          final nowMs = DateTime.now().millisecondsSinceEpoch;

          if (isInitial) {
            isInitial = false;
            for (final doc in snap.docs) {
              final notifKey = 'notif_payment_${doc.id}';
              final t = _extractTimestamp(doc.data()['createdAt'] ?? doc.data()['date']);

              if (t > 0 && (nowMs - t) < 30 * 60 * 1000 && prefs.getBool(notifKey) != true) {
                await prefs.setBool(notifKey, true);
                final amount = doc.data()['amount']?.toString() ?? '0';
                final studentName = doc.data()['studentName']?.toString() ?? 'Student';
                final receiptNo = doc.data()['receiptNo']?.toString() ?? doc.id;
                final mode = doc.data()['mode']?.toString() ?? 'Cash';

                await showNotification(
                  id: doc.id.hashCode,
                  title: '💳 Fee Payment Received: ₹$amount ($mode)',
                  body: '$studentName | Receipt: #$receiptNo',
                  channelId: androidPaymentChannel.id,
                  channelName: androidPaymentChannel.name,
                  payload: 'payment_${doc.id}',
                );
              } else {
                await prefs.setBool(notifKey, true);
              }
              if (t > _lastPaymentTimestamp) _lastPaymentTimestamp = t;
            }
            await prefs.setInt(_kLastPaymentTimeKey, _lastPaymentTimestamp);
            return;
          }

          for (final change in snap.docChanges) {
            if (change.type != DocumentChangeType.added) continue;
            final doc = change.doc;
            final notifKey = 'notif_payment_${doc.id}';
            if (prefs.getBool(notifKey) == true) continue;
            await prefs.setBool(notifKey, true);

            final data = doc.data() ?? {};
            final itemTime = _extractTimestamp(data['createdAt'] ?? data['date']);
            if (itemTime > _lastPaymentTimestamp) {
              _lastPaymentTimestamp = itemTime;
              await prefs.setInt(_kLastPaymentTimeKey, itemTime);
            }

            final amount = data['amount']?.toString() ?? '0';
            final studentName = data['studentName']?.toString() ?? 'Student';
            final receiptNo = data['receiptNo']?.toString() ?? doc.id;
            final mode = data['mode']?.toString() ?? 'Cash';

            await showNotification(
              id: doc.id.hashCode,
              title: '💳 Fee Payment Received: ₹$amount ($mode)',
              body: '$studentName | Receipt: #$receiptNo',
              channelId: androidPaymentChannel.id,
              channelName: androidPaymentChannel.name,
              payload: 'payment_${doc.id}',
            );
          }
        }, onError: (e) => debugPrint('[NotificationService] Payment error ($sId): $e'));

        _subscriptions.add(sub);
      }
    } catch (e) {
      debugPrint('[NotificationService] Payment listen error: $e');
    }
  }

  void _listenForParentReplies(String studentId) {
    try {
      bool isInitial = true;
      final sub = FirebaseFirestore.instance
          .collection('feedbacks')
          .where('studentId', isEqualTo: studentId)
          .snapshots()
          .listen((snap) async {
        final prefs = await SharedPreferences.getInstance();

        if (isInitial) {
          isInitial = false;
          for (final doc in snap.docs) {
            final reply = (doc.data()['reply'] ?? doc.data()['adminReply'] ?? '').toString().trim();
            if (reply.isNotEmpty) {
              await prefs.setBool('notif_reply_${doc.id}_${reply.hashCode}', true);
            }
          }
          return;
        }

        for (final doc in snap.docs) {
          final data = doc.data();
          final reply = (data['reply'] ?? data['adminReply'] ?? '').toString().trim();
          if (reply.isEmpty) continue;

          final notifKey = 'notif_reply_${doc.id}_${reply.hashCode}';
          if (prefs.getBool(notifKey) == true) continue;

          await prefs.setBool(notifKey, true);

          final subject = data['subject']?.toString() ?? 'Complaint';
          final status = (data['status'] ?? '').toString().toLowerCase();
          final isResolved = status == 'resolved' || data['resolved'] == true;

          final title = isResolved
              ? '✅ Principal Office (Resolved): $subject'
              : '📩 Reply from Principal: $subject';

          await showNotification(
            id: doc.id.hashCode,
            title: title,
            body: reply,
            channelId: androidComplaintChannel.id,
            channelName: androidComplaintChannel.name,
            payload: 'reply_${doc.id}',
          );
        }
      }, onError: (e) => debugPrint('[NotificationService] Parent reply error: $e'));

      _subscriptions.add(sub);
    } catch (e) {
      debugPrint('[NotificationService] Parent reply listen error: $e');
    }
  }

  /// Sends an immediate test notification to verify device sound, vibration & channel setup
  Future<void> sendTestNotification() async {
    await showNotification(
      id: 99999,
      title: '🔔 MNP School: Notifications Active!',
      body: 'Your device is configured. Admission alerts, notices, and fee receipts will appear here.',
      channelId: androidNoticeChannel.id,
      channelName: androidNoticeChannel.name,
      payload: 'test_notification',
    );
  }

  /// Periodic background sync called by WorkManager when the app is completely CLOSED/TERMINATED.
  Future<void> checkBackgroundUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final schoolId = prefs.getString('session_school_id') ?? 'SCHOOL_007';
      final role = prefs.getString('session_role') ?? '';
      final parentStudentId = prefs.getString('session_parent_student_id');

      int lastNoticeTime = prefs.getInt(_kLastNoticeTimeKey) ?? (nowMs - 2 * 60 * 60 * 1000);
      int lastComplaintTime = prefs.getInt(_kLastComplaintTimeKey) ?? (nowMs - 2 * 60 * 60 * 1000);
      int lastPaymentTime = prefs.getInt(_kLastPaymentTimeKey) ?? (nowMs - 2 * 60 * 60 * 1000);

      debugPrint('[NotificationService] 🔄 WorkManager background check executing for $schoolId');

      // 1. Check for New School Notices
      try {
        final targets = <String>{schoolId, 'SCHOOL_007', 'SCHOOL_001'};
        for (final sId in targets) {
          final noticesSnap = await FirebaseFirestore.instance
              .collection('schools')
              .doc(sId)
              .collection('notices')
              .get();

          int maxNoticeTime = lastNoticeTime;
          for (final doc in noticesSnap.docs) {
            final data = doc.data();
            final itemTime = _extractTimestamp(data['createdAt']);

            if (itemTime > lastNoticeTime) {
              if (itemTime > maxNoticeTime) maxNoticeTime = itemTime;

              final title = data['title']?.toString() ?? 'New School Notice';
              final content = data['content']?.toString() ?? '';
              final category = data['category']?.toString() ?? 'General';

              await showNotification(
                id: doc.id.hashCode,
                title: '📢 Notice ($category): $title',
                body: content,
                channelId: androidNoticeChannel.id,
                channelName: androidNoticeChannel.name,
                payload: 'notice_${doc.id}',
              );
            }
          }
          if (maxNoticeTime > lastNoticeTime) {
            await prefs.setInt(_kLastNoticeTimeKey, maxNoticeTime);
          }
        }
      } catch (noticeError) {
        debugPrint('[NotificationService] Background notices check error: $noticeError');
      }

      // 2. Check for New Parent Complaints, Enquiries & Payments (For School Admin/Principal)
      if (role != 'parent') {
        try {
          final complaintsSnap = await FirebaseFirestore.instance
              .collection('feedbacks')
              .get();

          int maxComplaintTime = lastComplaintTime;
          for (final doc in complaintsSnap.docs) {
            final data = doc.data();
            final isParent = data['type'] == 'parent_complaint' || data['studentId'] != null;
            if (!isParent) continue;

            final sId = (data['schoolId'] ?? '').toString().toLowerCase();
            if (sId.isNotEmpty && sId != schoolId.toLowerCase() && !sId.contains('school_') && !schoolId.toLowerCase().contains('007')) {
              continue;
            }

            final itemTime = _extractTimestamp(data['createdAt']);
            if (itemTime > lastComplaintTime) {
              if (itemTime > maxComplaintTime) maxComplaintTime = itemTime;

              final subject = data['subject']?.toString() ?? 'New Parent Message';
              final studentName = data['studentName']?.toString() ?? 'Student';
              final category = data['category']?.toString() ?? 'Parent Complaint';
              final priority = (data['priority'] ?? '').toString().toLowerCase();
              final isUrgent = priority == 'urgent' || data['urgent'] == true;

              await showNotification(
                id: doc.id.hashCode,
                title: isUrgent ? '🚨 URGENT Parent Message ($category)' : '📩 Parent Message ($category)',
                body: 'From $studentName\'s Parent: $subject',
                channelId: androidComplaintChannel.id,
                channelName: androidComplaintChannel.name,
                payload: 'complaint_${doc.id}',
              );
            }
          }
          if (maxComplaintTime > lastComplaintTime) {
            await prefs.setInt(_kLastComplaintTimeKey, maxComplaintTime);
          }
        } catch (complaintError) {
          debugPrint('[NotificationService] Background complaints check error: $complaintError');
        }

        // Check for New Admission Enquiries (online admissions from website)
        try {
          final targetSchools = <String>{schoolId, 'SCHOOL_007', 'SCHOOL_001'};
          for (final sId in targetSchools) {
            final enquiriesSnap = await FirebaseFirestore.instance
                .collection('schoolDirectory')
                .doc(sId)
                .collection('admissionEnquiries')
                .get();

            for (final doc in enquiriesSnap.docs) {
              final data = doc.data();
              final notifKey = 'notif_enq_${doc.id}';
              if (prefs.getBool(notifKey) == true) continue;

              final itemTime = _extractTimestamp(data['createdAt'] ?? data['timestamp']);
              if (itemTime > lastComplaintTime || (nowMs - itemTime) < 45 * 60 * 1000) {
                await prefs.setBool(notifKey, true);
                final studentName = data['studentName'] ?? data['name'] ?? 'New Student';
                final admClass = data['admissionClass'] ?? data['class'] ?? '';
                final refNo = data['refNo'] ?? doc.id;

                await showNotification(
                  id: doc.id.hashCode,
                  title: '🎓 New Admission Application ($admClass)',
                  body: '$studentName applied for Class $admClass (Ref: $refNo)',
                  channelId: androidEnquiryChannel.id,
                  channelName: androidEnquiryChannel.name,
                  payload: 'enquiry_${doc.id}',
                );
              }
            }
          }
        } catch (enqError) {
          debugPrint('[NotificationService] Background enquiry check error: $enqError');
        }

        // Check for New Fee Payments
        try {
          final targetSchools = <String>{schoolId, 'SCHOOL_007', 'SCHOOL_001'};
          for (final sId in targetSchools) {
            final paymentsSnap = await FirebaseFirestore.instance
                .collection('schools')
                .doc(sId)
                .collection('payments')
                .get();

            int maxPaymentTime = lastPaymentTime;
            for (final doc in paymentsSnap.docs) {
              final data = doc.data();
              final itemTime = _extractTimestamp(data['createdAt'] ?? data['date']);
              if (itemTime > lastPaymentTime) {
                if (itemTime > maxPaymentTime) maxPaymentTime = itemTime;

                final amount = data['amount']?.toString() ?? '0';
                final studentName = data['studentName']?.toString() ?? 'Student';
                final receiptNo = data['receiptNo']?.toString() ?? doc.id;
                final mode = data['mode']?.toString() ?? 'Cash';

                await showNotification(
                  id: doc.id.hashCode,
                  title: '💳 Fee Payment Received: ₹$amount ($mode)',
                  body: '$studentName | Receipt: #$receiptNo',
                  channelId: androidPaymentChannel.id,
                  channelName: androidPaymentChannel.name,
                  payload: 'payment_${doc.id}',
                );
              }
            }
            if (maxPaymentTime > lastPaymentTime) {
              await prefs.setInt(_kLastPaymentTimeKey, maxPaymentTime);
            }
          }
        } catch (payErr) {
          debugPrint('[NotificationService] Background payments check error: $payErr');
        }
      }

      // 3. Check for Principal Replies to Complaints (If Parent)
      if (parentStudentId != null && parentStudentId.isNotEmpty) {
        try {
          final repliesSnap = await FirebaseFirestore.instance
              .collection('feedbacks')
              .where('studentId', isEqualTo: parentStudentId)
              .get();

          for (final doc in repliesSnap.docs) {
            final data = doc.data();
            final reply = (data['reply'] ?? data['adminReply'] ?? '').toString().trim();
            if (reply.isEmpty) continue;

            final notifKey = 'notif_reply_${doc.id}_${reply.hashCode}';
            if (prefs.getBool(notifKey) == true) continue;

            await prefs.setBool(notifKey, true);
            final subject = data['subject']?.toString() ?? 'Complaint';
            final status = (data['status'] ?? '').toString().toLowerCase();
            final isResolved = status == 'resolved' || data['resolved'] == true;

            final title = isResolved
                ? '✅ Principal Office (Resolved): $subject'
                : '📩 Reply from Principal: $subject';

            await showNotification(
              id: doc.id.hashCode,
              title: title,
              body: reply,
              channelId: androidComplaintChannel.id,
              channelName: androidComplaintChannel.name,
              payload: 'reply_${doc.id}',
            );
          }
        } catch (replyError) {
          debugPrint('[NotificationService] Background reply check error: $replyError');
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] checkBackgroundUpdates general error: $e');
    }
  }

  int _extractTimestamp(dynamic rawTime) {
    if (rawTime is Timestamp) {
      return rawTime.millisecondsSinceEpoch;
    } else if (rawTime is String) {
      return DateTime.tryParse(rawTime)?.millisecondsSinceEpoch ?? 0;
    } else if (rawTime is int) {
      return rawTime;
    }
    return 0;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    String? payload,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.message,
        icon: '@drawable/ic_notification',
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
        ),
      );

      final details = NotificationDetails(android: androidDetails);
      await _notificationsPlugin.show(id, title, body, details, payload: payload);
    } catch (e) {
      debugPrint('[NotificationService] showNotification error: $e');
    }
  }

  void _cancelSubscriptions() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
  }

  void dispose() {
    _cancelSubscriptions();
  }
}
