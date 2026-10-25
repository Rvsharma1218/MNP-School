import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../../firebase_options.dart';
import 'session_service.dart';

/// Top-level background callback dispatcher for Android WorkManager.
/// Runs in an isolated background Dart thread even when the app is completely CLOSED/KILLED.
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
      // CRITICAL: Initialize local notifications plugin inside this background isolate
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
    description: 'Real-time alerts for new student admission applications',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  // Keys for tracking latest processed timestamps to prevent duplicate alerts
  static const _kLastNoticeTimeKey = 'notif_last_notice_time';
  static const _kLastComplaintTimeKey = 'notif_last_complaint_time';

  int _lastNoticeTimestamp = 0;
  int _lastComplaintTimestamp = 0;

  /// Background Isolate initialization helper (used when app is closed / killed)
  Future<void> initBackgroundIsolate() async {
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _notificationsPlugin.initialize(initSettings);

      final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(androidNoticeChannel);
        await androidPlugin.createNotificationChannel(androidComplaintChannel);
        await androidPlugin.createNotificationChannel(androidEnquiryChannel);
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
      // Default to 1 hour ago on initial run to avoid missing recent background events
      _lastNoticeTimestamp = prefs.getInt(_kLastNoticeTimeKey) ?? (nowMs - 60 * 60 * 1000);
      _lastComplaintTimestamp = prefs.getInt(_kLastComplaintTimeKey) ?? (nowMs - 60 * 60 * 1000);

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
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
        await androidPlugin.requestNotificationsPermission();
      }

      // Explicitly request notification permission for Android 13+ (Tiramisu, API 33+)
      try {
        final permStatus = await Permission.notification.status;
        if (!permStatus.isGranted) {
          await Permission.notification.request();
        }
      } catch (permErr) {
        debugPrint('[NotificationService] Permission request note: $permErr');
      }

      // Initialize WorkManager for background execution when the app is completely CLOSED
      try {
        await Workmanager().initialize(
          backgroundNotificationDispatcher,
          isInDebugMode: false,
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
        // One-off sync task to run immediately in background
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
    } catch (e) {
      debugPrint('[NotificationService] ⚠️ Init error: $e');
    }
  }

  void startListening({String? studentId}) {
    _cancelSubscriptions();

    final schoolId = SessionService.instance.activeSchoolId;
    if (schoolId.isEmpty) return;

    debugPrint('[NotificationService] Starting realtime listeners for school: $schoolId');

    // 1. Listen for Notices (Parent, Teacher, Principal)
    _listenForNotices(schoolId);

    // 2. Role-specific listeners
    if (SessionService.instance.isPrincipal) {
      _listenForPrincipalComplaints(schoolId);
      _listenForPrincipalEnquiries(schoolId);
    } else if (SessionService.instance.isParent || (studentId != null && studentId.isNotEmpty)) {
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
      bool isInitial = true;
      final sub = FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('notices')
          .snapshots()
          .listen((snap) async {
        if (isInitial) {
          isInitial = false;
          for (final doc in snap.docs) {
            final t = _extractTimestamp(doc.data()['createdAt']);
            if (t > _lastNoticeTimestamp) _lastNoticeTimestamp = t;
          }
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(_kLastNoticeTimeKey, _lastNoticeTimestamp);
          return;
        }

        for (final change in snap.docChanges) {
          if (change.type != DocumentChangeType.added) continue;
          final doc = change.doc;
          final data = doc.data() ?? {};
          final itemTime = _extractTimestamp(data['createdAt']);

          if (itemTime > _lastNoticeTimestamp) {
            _lastNoticeTimestamp = itemTime;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt(_kLastNoticeTimeKey, itemTime);

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
      }, onError: (e) => debugPrint('[NotificationService] Notice error: $e'));

      _subscriptions.add(sub);
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
        if (isInitial) {
          isInitial = false;
          for (final doc in snap.docs) {
            final t = _extractTimestamp(doc.data()['createdAt']);
            if (t > _lastComplaintTimestamp) _lastComplaintTimestamp = t;
          }
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(_kLastComplaintTimeKey, _lastComplaintTimestamp);
          return;
        }

        for (final change in snap.docChanges) {
          if (change.type != DocumentChangeType.added) continue;
          final doc = change.doc;
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
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt(_kLastComplaintTimeKey, itemTime);

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
      }, onError: (e) => debugPrint('[NotificationService] Principal complaints error: $e'));

      _subscriptions.add(sub);
    } catch (e) {
      debugPrint('[NotificationService] Principal complaint listen error: $e');
    }
  }

  void _listenForPrincipalEnquiries(String schoolId) {
    try {
      bool isInitial = true;
      final sub = FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('enquiries')
          .snapshots()
          .listen((snap) async {
        final prefs = await SharedPreferences.getInstance();
        if (isInitial) {
          isInitial = false;
          for (final doc in snap.docs) {
            await prefs.setBool('notif_enq_${doc.id}', true);
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
          final refNo = data['refNo'] ?? '';

          await showNotification(
            id: doc.id.hashCode,
            title: '🎓 New Admission Application ($admClass)',
            body: '$studentName applied for Class $admClass (Ref: $refNo)',
            channelId: androidEnquiryChannel.id,
            channelName: androidEnquiryChannel.name,
            payload: 'enquiry_${doc.id}',
          );
        }
      }, onError: (e) => debugPrint('[NotificationService] Principal enquiry error: $e'));

      _subscriptions.add(sub);
    } catch (e) {
      debugPrint('[NotificationService] Principal enquiry listen error: $e');
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

      debugPrint('[NotificationService] 🔄 WorkManager background check executing for $schoolId');

      // 1. Check for New School Notices
      try {
        final noticesSnap = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
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
      } catch (noticeError) {
        debugPrint('[NotificationService] Background notices check error: $noticeError');
      }

      // 2. Check for New Parent Complaints (If Principal)
      if (role == 'principal') {
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

        // Check for New Admission Enquiries (If Principal)
        try {
          final enquiriesSnap = await FirebaseFirestore.instance
              .collection('schools')
              .doc(schoolId)
              .collection('enquiries')
              .get();

          for (final doc in enquiriesSnap.docs) {
            final data = doc.data();
            final notifKey = 'notif_enq_${doc.id}';
            if (prefs.getBool(notifKey) == true) continue;

            final itemTime = _extractTimestamp(data['createdAt'] ?? data['timestamp']);
            if (itemTime > lastComplaintTime) {
              await prefs.setBool(notifKey, true);
              final studentName = data['studentName'] ?? data['name'] ?? 'New Student';
              final admClass = data['admissionClass'] ?? data['class'] ?? '';
              final refNo = data['refNo'] ?? '';

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
        } catch (enqError) {
          debugPrint('[NotificationService] Background enquiry check error: $enqError');
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
        icon: '@mipmap/ic_launcher',
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
