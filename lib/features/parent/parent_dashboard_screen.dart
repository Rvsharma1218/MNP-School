import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/student_model.dart';
import '../../data/models/fee_model.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/result_model.dart';
import '../../data/models/settings_model.dart';
import '../../data/services/database_service.dart';
import '../../data/services/session_service.dart';
import '../../data/services/receipt_pdf_service.dart';
import '../../data/services/app_notification_service.dart';
import '../id_card/id_card_screen.dart';
import '../admit_card/admit_card_screen.dart';
import '../notice/notice_screen.dart';
import 'parent_complaint_screen.dart';

class ParentDashboardScreen extends ConsumerStatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  ConsumerState<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends ConsumerState<ParentDashboardScreen> {
  int _currentTab = 0; // 0: Overview, 1: Profile, 2: Attendance, 3: Fees, 4: Results, 5: Notices, 6: Complaints
  bool _isDarkMode = false; // Default: Light Mode

  StudentModel? _student;
  List<PaymentModel> _payments = [];
  List<AttendanceModel> _attendanceLogs = [];
  List<ResultModel> _results = [];
  List<NoticeItem> _notices = [];
  SettingsModel? _settings;
  bool _loading = true;
  StreamSubscription? _noticesStreamSub;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    _loadData();
    _listenRealtimeNotices();
    AppNotificationService.instance.startListening();
  }

  @override
  void dispose() {
    _noticesStreamSub?.cancel();
    super.dispose();
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Default to Light Mode (false)
      final savedDark = prefs.getBool('parent_portal_is_dark') ?? false;
      if (mounted) setState(() => _isDarkMode = savedDark);
    } catch (_) {}
  }

  Future<void> _toggleTheme() async {
    final next = !_isDarkMode;
    setState(() => _isDarkMode = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('parent_portal_is_dark', next);
    } catch (_) {}
  }

  void _listenRealtimeNotices() {
    final schoolId = SessionService.instance.activeSchoolId;
    if (schoolId.isEmpty) return;

    _noticesStreamSub?.cancel();
    _noticesStreamSub = FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolId)
        .collection('notices')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final items = snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return NoticeItem.fromJson(data);
      }).toList();

      setState(() {
        _notices = items;
      });
    }, onError: (e) {
      debugPrint('[ParentDashboard] notices stream note: $e');
    });
  }

  Future<void> _loadData() async {
    final studentId = SessionService.instance.parentStudentId;
    final schoolId = SessionService.instance.activeSchoolId;

    if (studentId != null && studentId.isNotEmpty) {
      final db = DatabaseService.instance;

      // 1. Instant local SQLite load - zero waiting / zero spinner
      var s = await db.getStudentById(studentId);
      var p = await db.getPayments(studentId);
      var a = await db.getAttendanceByStudentId(studentId);
      var r = await db.getResultsByStudentId(studentId);
      final set = await db.getSettings();

      if (mounted) {
        setState(() {
          _student = s;
          _payments = p;
          _attendanceLogs = a;
          _results = r;
          _settings = set;
          _loading = (s == null); // Instant display if student already cached
        });
      }

      // 2. Background Firestore sync (non-blocking)
      unawaited(() async {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('schools')
              .doc(schoolId)
              .collection('students')
              .doc(studentId)
              .get()
              .timeout(const Duration(seconds: 5));

          if (doc.exists && doc.data() != null) {
            final cloudData = Map<String, dynamic>.from(doc.data()!);
            cloudData['id'] = doc.id;
            final cloudStudent = StudentModel.fromMap(cloudData);
            s = cloudStudent;
            await db.insertStudent(cloudStudent);
          }
        } catch (e) {
          debugPrint('[ParentDashboard] Cloud student sync note: $e');
        }

        try {
          final paySnap = await FirebaseFirestore.instance
              .collection('schools')
              .doc(schoolId)
              .collection('payments')
              .where('studentId', isEqualTo: studentId)
              .get()
              .timeout(const Duration(seconds: 5));

          for (final doc in paySnap.docs) {
            final pMap = doc.data();
            pMap['id'] = doc.id;
            await db.upsertPaymentFromRemote(pMap);
          }
          p = await db.getPayments(studentId);
        } catch (e) {
          debugPrint('[ParentDashboard] Cloud payments sync note: $e');
        }

        if (r.isEmpty) {
          try {
            final resSnap = await FirebaseFirestore.instance
                .collection('schools')
                .doc(schoolId)
                .collection('results')
                .where('studentId', isEqualTo: studentId)
                .get()
                .timeout(const Duration(seconds: 5));

            final fetchedResults = <ResultModel>[];
            for (final doc in resSnap.docs) {
              final data = doc.data();
              data['id'] = doc.id;
              final res = ResultModel(
                id: doc.id,
                studentId: data['studentId']?.toString() ?? studentId,
                examName: data['examName']?.toString() ?? 'Term Exam',
                status: data['status']?.toString(),
                createdAt: data['createdAt'] != null
                    ? (DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now())
                    : DateTime.now(),
                subjects: (data['subjects'] as List? ?? [])
                    .map((sub) => SubjectResult.fromMap(Map<String, dynamic>.from(sub)))
                    .toList(),
              );
              fetchedResults.add(res);
              await db.upsertResultFromRemote(res);
            }
            if (fetchedResults.isNotEmpty) r = fetchedResults;
          } catch (e) {
            debugPrint('[ParentDashboard] Cloud results sync note: $e');
          }
        }

        if (mounted) {
          setState(() {
            _student = s;
            _payments = p;
            _results = r;
            _loading = false;
          });
          if (s != null) {
            AppNotificationService.instance.startListening(studentId: s?.id);
          }
        }
      }());
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 8),
            Text(
              'Logout Parent Portal',
              style: TextStyle(
                color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out from MNP School Parent Portal?',
          style: TextStyle(
            color: _isDarkMode ? Colors.white70 : const Color(0xFF475569),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: _isDarkMode ? Colors.white60 : const Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await SessionService.instance.clear();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
      }
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open phone dialer for $phone')),
        );
      }
    }
  }

  void _showFullImageDialog(ImageProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image(image: provider, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                radius: 16,
                child: Icon(Icons.close_rounded, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studentName = _student?.name ?? SessionService.instance.parentStudentName ?? 'Student';
    final className = _student?.className ?? SessionService.instance.parentStudentClass ?? 'N/A';
    final rollNo = _student?.rollNumber ?? SessionService.instance.parentRollNo ?? 'N/A';
    final admNo = _student?.admissionNumber ?? '—';
    final schoolName = _settings?.instituteName.isNotEmpty == true ? _settings!.instituteName : 'Mission Navodaya Public School';

    // Theme tokens
    final bg = _isDarkMode ? const Color(0xFF0A0F1D) : const Color(0xFFF1F5F9);
    final cardBg = _isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = _isDarkMode ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);
    final textPrimary = _isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final dividerColor = _isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        titleSpacing: 10,
        backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFF0F2B5C),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: (_settings?.logoPath != null && _settings!.logoPath!.isNotEmpty)
                  ? AppUtils.buildAppImageWidget(
                      _settings!.logoPath,
                      fit: BoxFit.contain,
                      placeholder: const Center(
                        child: Text('MNP', style: TextStyle(color: Color(0xFF0F2B5C), fontWeight: FontWeight.w900, fontSize: 10)),
                      ),
                    )
                  : Image.asset(
                      'assets/icons/app_logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text('MNP', style: TextStyle(color: Color(0xFF0F2B5C), fontWeight: FontWeight.w900, fontSize: 10)),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    schoolName,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.2,
                      height: 1.18,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5.5,
                        height: 5.5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Flexible(
                        child: Text(
                          'Parent Portal • Student Dashboard',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: Color(0xFFCBD5E1),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // 1. Message to Principal Quick Action with live pending count badge
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('feedbacks')
                .where('studentId', isEqualTo: _student?.id ?? (SessionService.instance.parentStudentId ?? ''))
                .snapshots(),
            builder: (context, snap) {
              int pendingCount = 0;
              if (snap.hasData) {
                for (final d in snap.data!.docs) {
                  final m = d.data() as Map<String, dynamic>;
                  final status = (m['status'] ?? '').toString().toLowerCase();
                  final isResolved = status == 'resolved' || status == 'closed' || m['resolved'] == true;
                  // Only count complaints that are still open/pending review!
                  if (!isResolved) {
                    pendingCount++;
                  }
                }
              }

              final badgeNum = pendingCount;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 21),
                    tooltip: 'Message to Principal',
                    onPressed: () {
                      if (_student != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ParentComplaintScreen(
                              student: _student!,
                              settings: _settings,
                              isDarkMode: _isDarkMode,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  if (badgeNum > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          '$badgeNum',
                          style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          // 2. 3-Dots Overflow Menu: All top options consolidated into dots menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 22),
            tooltip: 'More Options',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            onSelected: (value) {
              if (value == 'theme') {
                _toggleTheme();
              } else if (value == 'refresh') {
                _loadData();
              } else if (value == 'call') {
                final phone = _settings?.mobile ?? '9334174023';
                _makePhoneCall(phone);
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem<String>(
                value: 'theme',
                child: Row(
                  children: [
                    Icon(
                      _isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: _isDarkMode ? Colors.amber : const Color(0xFF64748B),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isDarkMode ? 'Light Mode' : 'Dark Mode',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'refresh',
                child: Row(
                  children: [
                    const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB), size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Refresh Data',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'call',
                child: Row(
                  children: [
                    const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF10B981), size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Call School Office',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Logout Portal',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Premium Student Hero Card
                    _buildHeroStudentCard(studentName, className, rollNo, admNo),
                    const SizedBox(height: 14),

                    // 2. Quick Action Grid (ID Card, Admit Card, Fee Receipts, Marksheet, Contact)
                    _buildQuickActionGrid(cardBg, cardBorder, textPrimary),
                    const SizedBox(height: 14),

                    // 3. Navigation Tabs
                    _buildNavTabs(cardBg, cardBorder, textSecondary),
                    const SizedBox(height: 14),

                    // 4. Tab Content
                    if (_currentTab == 0) _buildOverviewTab(cardBg, cardBorder, textPrimary, textSecondary, dividerColor),
                    if (_currentTab == 1) _buildFullProfileTab(cardBg, cardBorder, textPrimary, textSecondary),
                    if (_currentTab == 2) _buildAttendanceTab(cardBg, cardBorder, textPrimary, textSecondary),
                    if (_currentTab == 3) _buildFeesTab(cardBg, cardBorder, textPrimary, textSecondary),
                    if (_currentTab == 4) _buildResultsTab(cardBg, cardBorder, textPrimary, textSecondary),
                    if (_currentTab == 5) _buildNoticesTab(cardBg, cardBorder, textPrimary, textSecondary),
                    if (_currentTab == 6) _buildComplaintsTab(cardBg, cardBorder, textPrimary, textSecondary, dividerColor),

                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
    );
  }

  // ── HERO STUDENT CARD ───────────────────────────────────────────────────

  Widget _buildHeroStudentCard(String studentName, String className, String rollNo, String admNo) {
    final status = (_student?.status ?? 'active').toUpperCase();
    final session = _student?.session ?? _settings?.currentSession ?? '2026-27';
    final section = _student?.section?.isNotEmpty == true ? ' - ${_student!.section}' : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isDarkMode
              ? [const Color(0xFF1E1B4B), const Color(0xFF312E81), const Color(0xFF1E3A8A)]
              : [const Color(0xFF0F2B5C), const Color(0xFF1E3A8A), const Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDarkMode ? 0.35 : 0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Student Avatar
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.8), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.amberAccent.withValues(alpha: 0.25),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 34,
              backgroundColor: const Color(0xFF1E293B),
              backgroundImage: (_student?.photoPath != null && _student!.photoPath!.isNotEmpty)
                  ? FileImage(File(_student!.photoPath!))
                  : null,
              child: (_student?.photoPath == null || _student!.photoPath!.isEmpty)
                  ? const Icon(Icons.person_rounded, size: 38, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 14),

          // Student Identity Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        studentName,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.6)),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Class: $className$section',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Roll: $rollNo',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amberAccent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Adm No: $admNo  •  Session: $session',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── QUICK ACTION BUTTONS ────────────────────────────────────────────────

  Widget _buildQuickActionGrid(Color cardBg, Color cardBorder, Color textPrimary) {
    return Row(
      children: [
        _buildActionTile(
          icon: Icons.badge_outlined,
          label: 'ID Card',
          color: const Color(0xFF3B82F6),
          cardBg: cardBg,
          cardBorder: cardBorder,
          textPrimary: textPrimary,
          onTap: () {
            if (_student != null) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => IdCardScreen(studentId: _student!.id)),
              );
            }
          },
        ),
        const SizedBox(width: 6),
        _buildActionTile(
          icon: Icons.assignment_turned_in_outlined,
          label: 'Admit Card',
          color: const Color(0xFF8B5CF6),
          cardBg: cardBg,
          cardBorder: cardBorder,
          textPrimary: textPrimary,
          onTap: () {
            if (_student != null) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AdmitCardScreen(studentId: _student!.id)),
              );
            }
          },
        ),
        const SizedBox(width: 6),
        _buildActionTile(
          icon: Icons.receipt_long_rounded,
          label: 'Fee Receipt',
          color: const Color(0xFF10B981),
          cardBg: cardBg,
          cardBorder: cardBorder,
          textPrimary: textPrimary,
          onTap: () => setState(() => _currentTab = 3),
        ),
        const SizedBox(width: 6),
        _buildActionTile(
          icon: Icons.phone_in_talk_rounded,
          label: 'Call School',
          color: const Color(0xFFF59E0B),
          cardBg: cardBg,
          cardBorder: cardBorder,
          textPrimary: textPrimary,
          onTap: () {
            final ph = _settings?.mobile ?? '9334174023';
            _makePhoneCall(ph);
          },
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isDarkMode ? 0.2 : 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── NAVIGATION TABS ─────────────────────────────────────────────────────

  Widget _buildNavTabs(Color cardBg, Color cardBorder, Color textSecondary) {
    final tabs = [
      {'title': 'Overview', 'icon': Icons.dashboard_rounded},
      {'title': 'Profile', 'icon': Icons.person_outline_rounded},
      {'title': 'Attendance', 'icon': Icons.calendar_today_rounded},
      {'title': 'Fees', 'icon': Icons.account_balance_wallet_outlined},
      {'title': 'Results', 'icon': Icons.grade_outlined},
      {'title': 'Notices', 'icon': Icons.campaign_outlined},
      {'title': 'Complaints', 'icon': Icons.chat_bubble_outline_rounded},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(tabs.length, (idx) {
          final t = tabs[idx];
          final isSel = _currentTab == idx;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () => setState(() => _currentTab = idx),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSel
                      ? AppColors.primary
                      : cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSel ? AppColors.primary : cardBorder,
                  ),
                  boxShadow: [
                    if (!_isDarkMode && isSel)
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      t['icon'] as IconData,
                      size: 16,
                      color: isSel ? Colors.white : textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      t['title'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                        color: isSel ? Colors.white : textSecondary,
                      ),
                    ),
                    if (idx == 5 && _notices.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                    if (idx == 6) ...[
                      const SizedBox(width: 4),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('feedbacks')
                            .where('studentId', isEqualTo: _student?.id ?? (SessionService.instance.parentStudentId ?? ''))
                            .snapshots(),
                        builder: (context, snap) {
                          final cnt = snap.hasData ? snap.data!.docs.length : 0;
                          if (cnt == 0) return const SizedBox.shrink();
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: isSel ? Colors.white : const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$cnt',
                              style: TextStyle(
                                color: isSel ? AppColors.primary : Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── TAB 0: OVERVIEW ─────────────────────────────────────────────────────

  Widget _buildOverviewTab(Color cardBg, Color cardBorder, Color textPrimary, Color textSecondary, Color dividerColor) {
    final now = DateTime.now();
    final todayAtt = _attendanceLogs.where((a) =>
      a.date.year == now.year && a.date.month == now.month && a.date.day == now.day
    ).toList();
    final todayStatus = todayAtt.isNotEmpty ? todayAtt.first.status.toUpperCase() : 'NOT MARKED YET';

    final totalAtt = _attendanceLogs.length;
    final presentCount = _attendanceLogs.where((a) => a.status.toLowerCase() == 'present').length;
    final absentCount = _attendanceLogs.where((a) => a.status.toLowerCase() == 'absent').length;
    final attPercent = totalAtt > 0 ? ((presentCount / totalAtt) * 100).round() : 100;

    // Accurate Fee calculations
    final paidFee = _payments.fold<double>(0, (acc, p) => acc + p.amount);

    // Monthly particulars for current/latest month
    final particulars = _student?.monthlyParticulars;
    Map<String, dynamic>? latestMonthData;
    if (particulars != null && particulars.isNotEmpty) {
      final sortedKeys = particulars.keys.toList()..sort();
      if (sortedKeys.isNotEmpty) {
        latestMonthData = particulars[sortedKeys.last] as Map<String, dynamic>?;
      }
    }

    final double effectiveTotalFee = (_student?.totalFees ?? 0.0) > 0
        ? _student!.totalFees
        : (paidFee + (_student?.remainingFees ?? 0.0));

    final double effectiveRemainingDue = (_student?.remainingFees != null && _student!.remainingFees! >= 0)
        ? _student!.remainingFees!
        : (effectiveTotalFee > paidFee ? (effectiveTotalFee - paidFee) : 0.0);

    // Latest notice
    final latestNotice = _notices.isNotEmpty ? _notices.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Complete Student Details Summary Card
        _buildStudentBioOverviewCard(cardBg, cardBorder, textPrimary, textSecondary, dividerColor),
        const SizedBox(height: 14),

        // 2. Live Attendance Card
        _buildAttendanceOverviewCard(cardBg, cardBorder, textPrimary, textSecondary, todayStatus, attPercent, presentCount, absentCount, totalAtt),
        const SizedBox(height: 14),

        // 3. Fee Ledger & Monthly Particulars Card
        _buildFeeOverviewCard(cardBg, cardBorder, textPrimary, textSecondary, dividerColor, effectiveTotalFee, paidFee, effectiveRemainingDue, latestMonthData),
        const SizedBox(height: 14),

        // 4. Latest School Notice Banner
        if (latestNotice != null) ...[
          _buildLatestNoticeBanner(cardBg, cardBorder, textPrimary, textSecondary, latestNotice),
          const SizedBox(height: 14),
        ],

        // 5. School Helpline & Information Card
        _buildSchoolHelplineCard(cardBg, cardBorder, textPrimary, textSecondary),
      ],
    );
  }

  // ── FULL STUDENT BIO OVERVIEW CARD ──────────────────────────────────────

  Widget _buildStudentBioOverviewCard(Color cardBg, Color cardBorder, Color textPrimary, Color textSecondary, Color dividerColor) {
    final dobStr = _student?.dob != null ? DateFormat('dd MMM yyyy').format(_student!.dob) : '—';
    final admDateStr = _student?.admissionDate != null ? DateFormat('dd MMM yyyy').format(_student!.admissionDate) : '—';
    final ageStr = _student?.dob != null ? '${DateTime.now().year - _student!.dob.year} Years' : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDarkMode ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment_ind_rounded, color: Color(0xFF0284C7), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Student Bio Data & Details',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary),
                  ),
                ],
              ),
              InkWell(
                onTap: () => setState(() => _currentTab = 1),
                child: const Text(
                  'View All ›',
                  style: TextStyle(color: Color(0xFF0284C7), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildDetailRow(Icons.person_outline_rounded, "Father's Name", _student?.fatherName ?? 'Not Specified', textPrimary, textSecondary),
          Divider(color: dividerColor, height: 16),
          _buildDetailRow(Icons.face_3_outlined, "Mother's Name", _student?.motherName ?? 'Not Specified', textPrimary, textSecondary),
          Divider(color: dividerColor, height: 16),
          _buildDetailRow(
            Icons.phone_android_rounded,
            'Registered Mobile',
            _student?.mobile ?? '—',
            textPrimary,
            textSecondary,
            isClickable: true,
            onTap: () => _makePhoneCall(_student?.mobile ?? ''),
          ),
          Divider(color: dividerColor, height: 16),
          _buildDetailRow(Icons.cake_outlined, 'Date of Birth', '$dobStr ${ageStr.isNotEmpty ? "($ageStr)" : ""}', textPrimary, textSecondary),
          Divider(color: dividerColor, height: 16),
          _buildDetailRow(Icons.pin_drop_outlined, 'Residential Address', _student?.address ?? '—', textPrimary, textSecondary),
          Divider(color: dividerColor, height: 16),
          _buildDetailRow(Icons.credit_card_outlined, 'Aadhaar Number', _student?.aadhaarNumber ?? '—', textPrimary, textSecondary),
          Divider(color: dividerColor, height: 16),
          _buildDetailRow(Icons.event_note_rounded, 'Admission Date', admDateStr, textPrimary, textSecondary),

          // Aadhaar Card Document Preview if uploaded
          if (_student?.aadhaarDocPath != null && _student!.aadhaarDocPath!.trim().isNotEmpty) ...[
            Divider(color: dividerColor, height: 16),
            _buildAadhaarDocPreview(_student!.aadhaarDocPath!, textPrimary, textSecondary),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color textPrimary, Color textSecondary, {bool isClickable = false, VoidCallback? onTap}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: textSecondary),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: onTap,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isClickable ? const Color(0xFF0284C7) : textPrimary,
                    ),
                  ),
                ),
                if (isClickable)
                  const Icon(Icons.call, size: 14, color: Color(0xFF0284C7)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── AADHAAR CARD PHOTO PREVIEW ──────────────────────────────────────────

  Widget _buildAadhaarDocPreview(String pathOrUrl, Color textPrimary, Color textSecondary) {
    if (pathOrUrl.trim().isEmpty) return const SizedBox.shrink();

    ImageProvider? provider;
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      provider = NetworkImage(pathOrUrl);
    } else if (pathOrUrl.startsWith('data:image')) {
      final base64Data = pathOrUrl.split(',').last;
      provider = MemoryImage(base64Decode(base64Data));
    } else {
      final file = File(pathOrUrl);
      if (file.existsSync()) {
        provider = FileImage(file);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.document_scanner_outlined, size: 16, color: Color(0xFF0284C7)),
            const SizedBox(width: 8),
            Text('Aadhaar Card Document', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary)),
          ],
        ),
        const SizedBox(height: 8),
        if (provider != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _showFullImageDialog(provider!),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Image(
                    image: provider,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 80,
                      color: Colors.grey.withValues(alpha: 0.2),
                      alignment: Alignment.center,
                      child: Text('Document Attached', style: TextStyle(color: textSecondary, fontSize: 12)),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Tap to Zoom', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Aadhaar Document path saved: $pathOrUrl', style: TextStyle(fontSize: 11, color: textSecondary)),
          ),
      ],
    );
  }

  // ── ATTENDANCE OVERVIEW CARD ────────────────────────────────────────────

  Widget _buildAttendanceOverviewCard(Color cardBg, Color cardBorder, Color textPrimary, Color textSecondary, String todayStatus, int attPercent, int presentCount, int absentCount, int totalAtt) {
    final isPresent = todayStatus == 'PRESENT';
    final isAbsent = todayStatus == 'ABSENT';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDarkMode ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.event_available_rounded, color: Color(0xFF0D9488), size: 20),
                  const SizedBox(width: 8),
                  Text('Live Attendance Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPresent
                      ? Colors.green.withValues(alpha: 0.15)
                      : (isAbsent ? Colors.red.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isPresent
                        ? Colors.green
                        : (isAbsent ? Colors.red : Colors.amber),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  todayStatus,
                  style: TextStyle(
                    color: isPresent
                        ? const Color(0xFF16A34A)
                        : (isAbsent ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Monthly Progress Bar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Monthly Attendance Rate', style: TextStyle(fontSize: 12, color: textSecondary)),
                        Text('$attPercent%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0D9488))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: attPercent / 100.0,
                        backgroundColor: _isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0D9488)),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(child: _buildMetricItem('Days Present', '$presentCount Days', const Color(0xFF16A34A), textSecondary)),
              Expanded(child: _buildMetricItem('Days Absent', '$absentCount Days', const Color(0xFFDC2626), textSecondary)),
              Expanded(child: _buildMetricItem('Days Logged', '$totalAtt Days', textPrimary, textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  // ── FEE OVERVIEW CARD ───────────────────────────────────────────────────

  Widget _buildFeeOverviewCard(
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
    Color dividerColor,
    double totalFee,
    double paidFee,
    double remainingDue,
    Map<String, dynamic>? latestMonthData,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDarkMode ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.currency_rupee_rounded, color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 8),
                  Text('Fee Ledger & Due Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary)),
                ],
              ),
              InkWell(
                onTap: () => setState(() => _currentTab = 3),
                child: const Text('View Receipts ›', style: TextStyle(color: Color(0xFFD97706), fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(child: _buildMetricItem('Total Fees', '₹${totalFee.toInt()}', textPrimary, textSecondary)),
              Expanded(child: _buildMetricItem('Paid Fees', '₹${paidFee.toInt()}', const Color(0xFF16A34A), textSecondary)),
              Expanded(child: _buildMetricItem('Remaining Due', '₹${remainingDue > 0 ? remainingDue.toInt() : 0}', remainingDue > 0 ? const Color(0xFFDC2626) : const Color(0xFF0D9488), textSecondary)),
            ],
          ),

          // Monthly Particulars itemized breakdown
          if (latestMonthData != null) ...[
            const SizedBox(height: 14),
            Divider(color: dividerColor),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.list_alt_rounded, size: 14, color: textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Fee Breakdown (${latestMonthData['monthName'] ?? 'Current Month'})',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isDarkMode ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                children: [
                  if ((latestMonthData['tuitionFee'] ?? 0) > 0)
                    _buildFeeLineItem('Monthly Tuition Fee', latestMonthData['tuitionFee'], textPrimary, textSecondary),
                  if ((latestMonthData['tieBagBelt'] ?? latestMonthData['tieBagBeltFee'] ?? 0) > 0)
                    _buildFeeLineItem('Tie / Bag / Belt', latestMonthData['tieBagBelt'] ?? latestMonthData['tieBagBeltFee'], textPrimary, textSecondary),
                  if ((latestMonthData['developmentFee'] ?? 0) > 0)
                    _buildFeeLineItem('Development Fee', latestMonthData['developmentFee'], textPrimary, textSecondary),
                  if ((latestMonthData['examinationFee'] ?? 0) > 0)
                    _buildFeeLineItem('Examination Fee', latestMonthData['examinationFee'], textPrimary, textSecondary),
                  if ((latestMonthData['otherFee'] ?? 0) > 0)
                    _buildFeeLineItem('Other Charges', latestMonthData['otherFee'], textPrimary, textSecondary),
                  if ((latestMonthData['transportFee'] ?? 0) > 0)
                    _buildFeeLineItem('Transport Fee', latestMonthData['transportFee'], textPrimary, textSecondary),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeeLineItem(String title, dynamic amount, Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 11, color: textSecondary)),
          Text('₹$amount', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary)),
        ],
      ),
    );
  }

  // ── LATEST NOTICE BANNER ────────────────────────────────────────────────

  Widget _buildLatestNoticeBanner(Color cardBg, Color cardBorder, Color textPrimary, Color textSecondary, NoticeItem notice) {
    final catColor = _getCategoryColor(notice.category);
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(notice.createdAt);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: catColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDarkMode ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: catColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  notice.category.toUpperCase(),
                  style: TextStyle(color: catColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Latest Announcement',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ),
              Text(dateStr, style: TextStyle(fontSize: 10, color: textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            notice.title,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          if (notice.content.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              notice.content,
              style: TextStyle(fontSize: 12, color: textSecondary, height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () => setState(() => _currentTab = 5),
              child: const Text('View All Notices ›', style: TextStyle(color: Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ── SCHOOL HELPLINE CARD ────────────────────────────────────────────────

  Widget _buildSchoolHelplineCard(Color cardBg, Color cardBorder, Color textPrimary, Color textSecondary) {
    final schoolName = _settings?.instituteName.isNotEmpty == true ? _settings!.instituteName : 'Mission Navodaya Public School';
    final address = _settings?.address.isNotEmpty == true ? _settings!.address : 'Ratauli, Bihar';
    final phone = _settings?.mobile ?? '9334174023';
    final principal = _settings?.principalName ?? 'School Administration';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDarkMode ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_rounded, color: Color(0xFF2563EB), size: 20),
              const SizedBox(width: 8),
              Text(schoolName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary)),
            ],
          ),
          const SizedBox(height: 10),
          Text('📍 $address', style: TextStyle(fontSize: 12, color: textSecondary)),
          const SizedBox(height: 4),
          Text('👨‍🏫 Principal / Office: $principal', style: TextStyle(fontSize: 12, color: textSecondary)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.call_rounded, size: 16, color: Color(0xFF16A34A)),
              label: Text('Call School Helpline ($phone)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF16A34A), width: 0.8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _makePhoneCall(phone),
            ),
          ),
        ],
      ),
    );
  }

  // ── TAB 1: FULL STUDENT PROFILE ─────────────────────────────────────────

  Widget _buildFullProfileTab(Color cardBg, Color cardBorder, Color textPrimary, Color textSecondary) {
    final dobStr = _student?.dob != null ? DateFormat('dd MMMM yyyy').format(_student!.dob) : '—';
    final admDateStr = _student?.admissionDate != null ? DateFormat('dd MMMM yyyy').format(_student!.admissionDate) : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isDarkMode ? 0.2 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_pin_rounded, color: Color(0xFF0284C7), size: 22),
                  const SizedBox(width: 8),
                  Text('Complete Student Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary)),
                ],
              ),
              const SizedBox(height: 16),

              _buildProfileTile('Full Name', _student?.name ?? '—', Icons.badge_outlined, textPrimary, textSecondary),
              _buildProfileTile('Admission Number', _student?.admissionNumber ?? '—', Icons.confirmation_number_outlined, textPrimary, textSecondary),
              _buildProfileTile('Student ID', _student?.id ?? '—', Icons.qr_code_rounded, textPrimary, textSecondary),
              _buildProfileTile('Class & Section', '${_student?.className ?? "—"}${_student?.section?.isNotEmpty == true ? " (Sec ${_student!.section})" : ""}', Icons.class_outlined, textPrimary, textSecondary),
              _buildProfileTile('Roll Number', _student?.rollNumber ?? '—', Icons.format_list_numbered_rounded, textPrimary, textSecondary),
              _buildProfileTile('Academic Session', _student?.session ?? '2026-27', Icons.calendar_month_outlined, textPrimary, textSecondary),
              _buildProfileTile("Father's Name", _student?.fatherName ?? 'Not Specified', Icons.person_rounded, textPrimary, textSecondary),
              _buildProfileTile("Mother's Name", _student?.motherName ?? 'Not Specified', Icons.face_3_rounded, textPrimary, textSecondary),
              _buildProfileTile('Contact Mobile', _student?.mobile ?? '—', Icons.phone_rounded, textPrimary, textSecondary, isPhone: true),
              if (_student?.alternateMobile?.isNotEmpty == true)
                _buildProfileTile('Alternate Phone', _student!.alternateMobile!, Icons.phone_android_rounded, textPrimary, textSecondary, isPhone: true),
              _buildProfileTile('Date of Birth', dobStr, Icons.cake_outlined, textPrimary, textSecondary),
              _buildProfileTile('Gender', _student?.gender ?? '—', Icons.transgender_rounded, textPrimary, textSecondary),
              _buildProfileTile('Aadhaar Number', _student?.aadhaarNumber ?? '—', Icons.credit_card_rounded, textPrimary, textSecondary),
              _buildProfileTile('Residential Address', _student?.address ?? '—', Icons.home_outlined, textPrimary, textSecondary),
              _buildProfileTile('Date of Admission', admDateStr, Icons.how_to_reg_outlined, textPrimary, textSecondary),
              _buildProfileTile('Student Status', (_student?.status ?? 'active').toUpperCase(), Icons.check_circle_outline_rounded, textPrimary, textSecondary),

              // Aadhaar Card Document Preview
              if (_student?.aadhaarDocPath != null && _student!.aadhaarDocPath!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildAadhaarDocPreview(_student!.aadhaarDocPath!, textPrimary, textSecondary),
              ] else ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Aadhaar document card has not been uploaded to the school record yet.',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Action Buttons: ID Card & Admit Card
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.badge_rounded, color: Colors.white, size: 18),
                label: const Text('Student ID Card', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  if (_student != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => IdCardScreen(studentId: _student!.id)),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.assignment_turned_in_rounded, color: Colors.white, size: 18),
                label: const Text('Admit Card', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  if (_student != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AdmitCardScreen(studentId: _student!.id)),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileTile(String label, String value, IconData icon, Color textPrimary, Color textSecondary, {bool isPhone = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _isDarkMode ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: textSecondary)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isPhone ? const Color(0xFF0284C7) : textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (isPhone && value != '—')
            IconButton(
              icon: const Icon(Icons.phone_forwarded_rounded, size: 18, color: Color(0xFF0284C7)),
              onPressed: () => _makePhoneCall(value),
            ),
        ],
      ),
    );
  }

  // ── TAB 2: ATTENDANCE ───────────────────────────────────────────────────

  Widget _buildAttendanceTab(Color cardBg, Color cardBorder, Color textPrimary, Color textSecondary) {
    if (_attendanceLogs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.event_busy_rounded, size: 48, color: textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('No attendance logs recorded yet for this student.', style: TextStyle(color: textSecondary)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Total Recorded Logs: ${_attendanceLogs.length} Days',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary),
        ),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _attendanceLogs.length,
          itemBuilder: (ctx, i) {
            final a = _attendanceLogs[i];
            final isPresent = a.status.toLowerCase() == 'present';
            final isAbsent = a.status.toLowerCase() == 'absent';
            final dayName = DateFormat('EEEE').format(a.date);
            final dateFormatted = DateFormat('dd MMMM yyyy').format(a.date);

            return Card(
              color: cardBg,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cardBorder)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isPresent
                      ? Colors.green.withValues(alpha: 0.15)
                      : (isAbsent ? Colors.red.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15)),
                  child: Icon(
                    isPresent ? Icons.check_circle_rounded : (isAbsent ? Icons.cancel_rounded : Icons.schedule_rounded),
                    color: isPresent ? const Color(0xFF16A34A) : (isAbsent ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
                    size: 22,
                  ),
                ),
                title: Text(dateFormatted, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary)),
                subtitle: Text(dayName, style: TextStyle(color: textSecondary, fontSize: 12)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPresent
                        ? Colors.green.withValues(alpha: 0.15)
                        : (isAbsent ? Colors.red.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    a.status.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: isPresent ? const Color(0xFF16A34A) : (isAbsent ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── TAB 3: FEES & RECEIPTS ──────────────────────────────────────────────

  Widget _buildFeesTab(Color cardBg, Color cardBorder, Color textPrimary, Color textSecondary) {
    final paidFee = _payments.fold<double>(0, (acc, p) => acc + p.amount);
    final double effectiveTotalFee = (_student?.totalFees ?? 0.0) > 0
        ? _student!.totalFees
        : (paidFee + (_student?.remainingFees ?? 0.0));
    final double effectiveRemainingDue = (_student?.remainingFees != null && _student!.remainingFees! >= 0)
        ? _student!.remainingFees!
        : (effectiveTotalFee > paidFee ? (effectiveTotalFee - paidFee) : 0.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fee Summary Card at Top of Fees Tab
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isDarkMode ? 0.2 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 8),
                  Text('Fee Summary & Due Balance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _buildMetricItem('Total Fees', '₹${effectiveTotalFee.toInt()}', textPrimary, textSecondary)),
                  Expanded(child: _buildMetricItem('Total Paid', '₹${paidFee.toInt()}', const Color(0xFF16A34A), textSecondary)),
                  Expanded(
                    child: _buildMetricItem(
                      'Remaining Due',
                      '₹${effectiveRemainingDue > 0 ? effectiveRemainingDue.toInt() : 0}',
                      effectiveRemainingDue > 0 ? const Color(0xFFDC2626) : const Color(0xFF0D9488),
                      textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text('Fee Payment Receipts & Invoices (${_payments.length})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary)),
        const SizedBox(height: 10),

        if (_payments.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.receipt_long_outlined, size: 48, color: textSecondary.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
                Text('No payment receipts recorded yet for this session.', style: TextStyle(color: textSecondary)),
              ],
            ),
          )
        else
          ..._payments.map((p) => Card(
            color: cardBg,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cardBorder)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.receipt_rounded, color: Color(0xFFD97706), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Receipt #${p.receiptNumber}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary)),
                        const SizedBox(height: 2),
                        Text(
                          '${DateFormat('dd/MM/yyyy').format(p.paymentDate)}  •  ${p.paymentMode}',
                          style: TextStyle(color: textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${p.amount.toInt()}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF16A34A)),
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () async {
                          if (_student != null) {
                            final settings = await DatabaseService.instance.getSettings();
                            final doc = await ReceiptPdfService.instance.generateDocument(
                              student: _student!,
                              payment: p,
                              settings: settings,
                            );
                            await Printing.layoutPdf(onLayout: (format) => doc.save());
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.download_rounded, size: 12, color: AppColors.primary),
                              SizedBox(width: 4),
                              Text('PDF', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )),
      ],
    );
  }

  // ── TAB 4: EXAM RESULTS & REPORT CARD ───────────────────────────────────

  Widget _buildResultsTab(Color cardBg, Color cardBorder, Color textPrimary, Color textSecondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Academic Performance & Results', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary)),
            // Admit Card launcher button
            ElevatedButton.icon(
              icon: const Icon(Icons.assignment_turned_in_rounded, size: 15, color: Colors.white),
              label: const Text('Admit Card', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (_student != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AdmitCardScreen(studentId: _student!.id)),
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_results.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.assessment_outlined, size: 48, color: textSecondary.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
                Text('No exam marks or results published yet for this student.', style: TextStyle(color: textSecondary)),
              ],
            ),
          )
        else
          ..._results.map((res) {
            final isPass = res.isPass;
            final pct = res.overallPercentage.toStringAsFixed(1);
            final grade = res.overallGrade;

            return Card(
              color: cardBg,
              margin: const EdgeInsets.only(bottom: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: cardBorder)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(res.examName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: isPass ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isPass ? Colors.green : Colors.red),
                          ),
                          child: Text(
                            isPass ? 'PASSED ($grade)' : 'FAILED ($grade)',
                            style: TextStyle(
                              color: isPass ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text('Obtained: ${res.obtainedMarks.toInt()} / ${res.totalMarks.toInt()}', style: TextStyle(fontSize: 13, color: textSecondary)),
                        const Spacer(),
                        Text('Percentage: $pct%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(color: _isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0)),

                    // Subject Breakdown Table
                    ...res.subjects.map((sub) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(sub.subjectName, style: TextStyle(fontSize: 12, color: textPrimary)),
                          ),
                          Text(
                            '${sub.marks.toInt()} / ${sub.totalMarks.toInt()}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 32,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            decoration: BoxDecoration(
                              color: sub.isPass ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              sub.grade,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: sub.isPass ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  // ── TAB 5: NOTICES ──────────────────────────────────────────────────────

  Widget _buildNoticesTab(Color cardBg, Color cardBorder, Color textPrimary, Color textSecondary) {
    if (_notices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.campaign_outlined, size: 48, color: textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('No active school notices or circulars right now.', style: TextStyle(color: textSecondary)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Notices & Circulars (${_notices.length})',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary),
        ),
        const SizedBox(height: 10),

        ..._notices.map((n) {
          final catColor = _getCategoryColor(n.category);
          final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(n.createdAt);

          return Card(
            color: cardBg,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cardBorder)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: catColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          n.category.toUpperCase(),
                          style: TextStyle(color: catColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (n.isPinned) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.push_pin_rounded, size: 14, color: Color(0xFFD97706)),
                      ],
                      const Spacer(),
                      Text(dateStr, style: TextStyle(fontSize: 10, color: textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(n.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
                  if (n.content.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(n.content, style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4)),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 14, color: textSecondary),
                      const SizedBox(width: 4),
                      Text('By ${n.authorName}', style: TextStyle(fontSize: 11, color: textSecondary)),
                      if (n.imageUrl?.isNotEmpty == true) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.attachment_rounded, size: 14, color: Color(0xFF0284C7)),
                              SizedBox(width: 4),
                              Text('Attachment Included', style: TextStyle(fontSize: 10, color: Color(0xFF0284C7))),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── COMPLAINTS & MESSAGE TAB ──────────────────────────────────────────

  Widget _buildComplaintsTab(
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
    Color dividerColor,
  ) {
    if (_student == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text('Student profile not loaded')),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('feedbacks')
          .where('studentId', isEqualTo: _student!.id)
          .snapshots(),
      builder: (context, snapshot) {
        final List<Map<String, dynamic>> items = [];
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final d = Map<String, dynamic>.from(doc.data() as Map);
            d['docId'] = doc.id;
            items.add(d);
          }
        }

        items.sort((a, b) {
          final tA = a['createdAt']?.toString() ?? a['date']?.toString() ?? '';
          final tB = b['createdAt']?.toString() ?? b['date']?.toString() ?? '';
          return tB.compareTo(tA);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Action Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isDarkMode
                      ? [const Color(0xFF1E1B4B), const Color(0xFF1E3A8A)]
                      : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _isDarkMode
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
                      : const Color(0xFFBFDBFE),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Principal Office Desk',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: _isDarkMode ? Colors.white : const Color(0xFF1E3A8A),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Direct Line',
                          style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Direct communication channel between parents and Principal. You can submit complaints about academics, transport, fee receipts, or school facilities.',
                    style: TextStyle(
                      fontSize: 11,
                      color: _isDarkMode ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ParentComplaintScreen(
                                  student: _student!,
                                  settings: _settings,
                                  isDarkMode: _isDarkMode,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add_comment_rounded, size: 16),
                          label: const Text('Send New Message / Complain'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Header for Sent Messages
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sent Messages & Complaints (${items.length})',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ParentComplaintScreen(
                          student: _student!,
                          settings: _settings,
                          isDarkMode: _isDarkMode,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('Full View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cardBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mark_email_read_outlined, size: 44, color: textSecondary.withValues(alpha: 0.4)),
                    const SizedBox(height: 10),
                    Text(
                      'No complaints or messages recorded',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your sent messages to the Principal and their official replies will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: textSecondary),
                    ),
                  ],
                ),
              )
            else
              ...items.map((item) {
                final category = item['category'] ?? 'Complaint';
                final subject = item['subject'] ?? 'Message';
                final message = item['message'] ?? '';
                final status = (item['status'] ?? 'new').toString().toLowerCase();
                final isResolved = status == 'resolved';
                final reply = item['reply'] ?? item['adminReply'] ?? '';
                final dateStr = item['date'] ?? 'Recent';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isResolved ? const Color(0xFF10B981).withValues(alpha: 0.4) : cardBorder,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              category.toString(),
                              style: const TextStyle(color: Color(0xFF2563EB), fontSize: 9.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isResolved
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isResolved ? 'Resolved' : 'Pending Review',
                              style: TextStyle(
                                color: isResolved ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subject,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: TextStyle(fontSize: 11.5, color: textSecondary, height: 1.35),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Date: $dateStr',
                        style: TextStyle(fontSize: 9.5, color: textSecondary.withValues(alpha: 0.7)),
                      ),
                      if (reply.toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _isDarkMode ? const Color(0xFF0F2B5C) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.verified_rounded, color: Color(0xFF3B82F6), size: 13),
                                  SizedBox(width: 4),
                                  Text(
                                    'Principal Reply',
                                    style: TextStyle(color: Color(0xFF2563EB), fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                reply.toString(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _isDarkMode ? Colors.white : const Color(0xFF1E3A8A),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  // ── HELPER METRICS ──────────────────────────────────────────────────────

  Color _getCategoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'urgent':
        return const Color(0xFFEF4444);
      case 'holiday':
        return const Color(0xFFA855F7);
      case 'academic':
        return const Color(0xFF3B82F6);
      case 'event':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF14B8A6);
    }
  }

  Widget _buildMetricItem(String label, String value, Color color, Color textSecondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
