import 'features/dashboard/online_enquiries_screen.dart';
import 'dart:async';
import 'features/notice/notice_screen.dart';
import 'features/admit_card/admit_card_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/constants/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'data/models/student_model.dart';
import 'data/services/auth_service.dart';
import 'data/services/firestore_service.dart';
import 'data/services/session_service.dart';
import 'data/services/teacher_permissions_service.dart';
import 'data/services/providers.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/pin_lock_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/students/add_student_screen.dart';
import 'features/students/student_list_screen.dart';
import 'features/students/student_profile_screen.dart';
import 'features/students/edit_student_screen.dart';
import 'features/fees/fee_screen.dart';
import 'features/attendance/attendance_screen.dart';
import 'features/attendance/attendance_report_screen.dart';
import 'features/attendance/attendance_report_options_screen.dart';
import 'features/results/result_screen.dart';
import 'features/id_card/id_card_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/backup/backup_restore_screen.dart';
import 'features/qr/qr_scanner_screen.dart';
import 'features/students/promote_students_screen.dart';
import 'features/fees/fees_overview_screen.dart';

import 'features/security/device_security_service.dart';
import 'features/security/device_security_gate.dart';
import 'features/parent/parent_dashboard_screen.dart';
import 'data/services/app_notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // 1. Initialize Firebase Cloud Services FIRST (synchronous and fast)
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    FirestoreService.instance.init();
    debugPrint('[Firebase] ✅ Cloud Services Initialized');
  } catch (e) {
    debugPrint('[Firebase] ⚠️ Firebase init note: $e');
  }

  // 2. Restore role/school session from local cache (fast)
  try {
    await SessionService.instance.restore();
    await TeacherPermissionsService.instance.init();
  } catch (e) {
    debugPrint('[Session] ⚠️ Session restore note: $e');
  }

  // 3. Launch UI immediately for instant startup!
  runApp(const ProviderScope(child: SchoolApp()));

  // 4. Run background services post-launch so they never block UI
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(DeviceSecurityService.instance.init());
    unawaited(AppNotificationService.instance.init());
  });
}

class SchoolApp extends ConsumerWidget {
  const SchoolApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    // Starts the Firestore → SQLite → Riverpod real-time sync (PART 13).
    // Watching it here means it's alive for the whole app session; no
    // return value is needed, we just need the provider to be built.
    ref.watch(firestoreRealtimeSyncProvider);
    return MaterialApp(
      title: 'MNP School',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      builder: (context, child) => DeviceSecurityGate(child: child ?? const SizedBox()),
      // If user is already authenticated → show PIN lock directly, if Parent → show Parent Dashboard, else Login
      home: SessionService.instance.role == AppRole.parent
          ? const ParentDashboardScreen()
          : (AuthService.instance.isLoggedIn
              ? const PinLockScreen()
              : const LoginScreen()),
      routes: {
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.dashboard: (_) => const DashboardScreen(),
        AppRoutes.addStudent: (_) => const AddStudentScreen(),
        AppRoutes.studentList: (_) => const StudentListScreen(),
        AppRoutes.attendance: (_) => const AttendanceScreen(),
        AppRoutes.attendanceReport: (_) => const AttendanceReportScreen(),
        AppRoutes.reports: (_) => const ReportsScreen(),
        AppRoutes.settings: (_) => const SettingsScreen(),
        AppRoutes.backup: (_) => const BackupRestoreScreen(),
        AppRoutes.qrScanner: (_) => const QrScannerScreen(),
        AppRoutes.feesCollected: (_) => const FeesCollectedScreen(),
        AppRoutes.feesPending: (_) => const FeesPendingScreen(),
        AppRoutes.promoteStudents: (_) => const PromoteStudentsScreen(),
        AppRoutes.parentDashboard: (_) => const ParentDashboardScreen(),
        AppRoutes.onlineEnquiries: (_) => const OnlineEnquiriesScreen(),
      },
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case AppRoutes.studentProfile:
            return MaterialPageRoute(
              builder: (_) => StudentProfileScreen(studentId: settings.arguments as String),
            );
          case AppRoutes.editStudent:
            return MaterialPageRoute(
              builder: (_) => EditStudentScreen(studentId: settings.arguments as String),
            );
          case AppRoutes.fees:
            if (settings.arguments is String) {
              return MaterialPageRoute(
                builder: (_) => FeeScreen(studentId: settings.arguments as String),
              );
            }
            return MaterialPageRoute(builder: (_) => const FeesCollectedScreen());
          case AppRoutes.result:
            if (settings.arguments is StudentModel) {
              return MaterialPageRoute(
                builder: (_) => ResultScreen(student: settings.arguments as StudentModel),
              );
            } else if (settings.arguments is String) {
              return MaterialPageRoute(
                builder: (_) => ResultScreen(studentId: settings.arguments as String),
              );
            }
            return MaterialPageRoute(builder: (_) => const ResultScreen());
          case AppRoutes.idCard:
            if (settings.arguments is String) {
              return MaterialPageRoute(
                builder: (_) => IdCardScreen(studentId: settings.arguments as String),
              );
            }
            return MaterialPageRoute(builder: (_) => const StudentListScreen());
          case '/admit-card':
            final sId = settings.arguments is String ? settings.arguments as String : null;
            return MaterialPageRoute(builder: (_) => AdmitCardScreen(studentId: sId));
          case '/notice':
            return MaterialPageRoute(builder: (_) => const NoticeScreen());
          case AppRoutes.parentDashboard:
            return MaterialPageRoute(builder: (_) => const ParentDashboardScreen());
          case AppRoutes.attendanceReportOptions:
            return MaterialPageRoute(
              builder: (_) => AttendanceReportOptionsScreen(studentId: settings.arguments as String),
            );
          default:
            return MaterialPageRoute(builder: (_) => const DashboardScreen());
        }
      },
    );
  }
}