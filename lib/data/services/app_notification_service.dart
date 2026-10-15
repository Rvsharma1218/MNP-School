import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
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

  // Keys for tracking latest processed timestamps to prevent duplicate alerts on re-launch
  static const _kLastNoticeTimeKey = 'notif_last_notice_time';
  static const _kLastComplaintTimeKey = 'notif_last_complaint_time';

  int _lastNoticeTimestamp = 0;
  int _lastComplaintTimestamp = 0;

  Future<void> init() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      // If never recorded before, default to current time so app open does NOT spam old notices
      _lastNoticeTimestamp = prefs.getInt(_kLastNoticeTimeKey) ?? nowMs;
      _lastComplaintTimestamp = prefs.getInt(_kLastComplaintTimeKey) ?? nowMs;

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('[Notification] User tapped: ${response.payload}');
        },
      );

      // Create high-priority notification channels
      const androidNoticeChannel = AndroidNotificationChannel(
        'school_notices_channel',
        'School Notices & Circulars',
        description: 'Instant alerts for school notices, exams, holidays and circulars',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      const androidComplaintChannel = AndroidNotificationChannel(
        'parent_complaints_channel',
        'Parent Complaints & Replies',
        description: 'Instant messages and replies between Parents and School Administration',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(androidNoticeChannel);
        await androidPlugin.createNotificationChannel(androidComplaintChannel);
        // Request runtime permission for Android 13+
        await androidPlugin.requestNotificationsPermission();
      }

      // Initialize WorkManager for background execution when the app is completely CLOSED
      try {
        await Workmanager().initialize(
          backgroundNotificationDispatcher,
        );
        await Workmanager().registerPeriodicTask(
          'mnp_bg_sync_job',
          'mnp_bg_sync_task',
          frequency: const Duration(minutes: 15),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
          constraints: Constraints(
            networkType: NetworkType.connected,
          ),
        );
        debugPrint('[NotificationService] ✅ WorkManager background sync registered (15m interval)');
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
        // Swallow initial burst upon opening app so we never disturb the user upon launch
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

        // Only alert on genuinely new notices posted while app is active or minimized
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
              channelId: 'school_notices_channel',
              channelName: 'School Notices & Circulars',
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
        // Swallow initial burst on open
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

        // Live changes
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
              channelId: 'parent_complaints_channel',
              channelName: 'Parent Complaints & Replies',
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

  void _listenForParentReplies(String studentId) {
    try {
      bool isInitial = true;
      final sub = FirebaseFirestore.instance
          .collection('feedbacks')
          .where('studentId', isEqualTo: studentId)
          .snapshots()
          .listen((snap) async {
        final prefs = await SharedPreferences.getInstance();

        // Swallow initial batch
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

          // Unique key per complaint reply to prevent duplicates
          final notifKey = 'notif_reply_${doc.id}_${reply.hashCode}';
          if (prefs.getBool(notifKey) == true) {
            continue; // Already notified the parent
          }

          // Mark notified
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
            channelId: 'parent_complaints_channel',
            channelName: 'Parent Complaints & Replies',
            payload: 'reply_${doc.id}',
          );
          debugPrint('[NotificationService] 🔔 Parent notification shown for doc: ${doc.id}');
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
              channelId: 'school_notices_channel',
              channelName: 'School Notices & Circulars',
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

      // 2. Check for New Parent Complaints (If role is Principal)
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
                channelId: 'parent_complaints_channel',
                channelName: 'Parent Complaints & Replies',
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
      }

      // 3. Check for Principal Replies to Complaints (If role is Parent)
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
              channelId: 'parent_complaints_channel',
              channelName: 'Parent Complaints & Replies',
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
