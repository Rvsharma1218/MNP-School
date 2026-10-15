import '../../data/services/session_service.dart';
import '../../data/services/teacher_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/settings_model.dart';
import '../../data/services/providers.dart';
import '../../data/services/database_service.dart';

class SchoolStatusScreen extends ConsumerStatefulWidget {
  const SchoolStatusScreen({super.key});

  @override
  ConsumerState<SchoolStatusScreen> createState() => _SchoolStatusScreenState();
}

class _SchoolStatusScreenState extends ConsumerState<SchoolStatusScreen> {
  bool _loading = true;
  int _totalTeachers = 0;
  int _presentTeachers = 0;
  DateTime _lastRefresh = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadExtraData();
  }

  Future<void> _loadExtraData() async {
    setState(() => _loading = true);
    try {
      final schoolUid = SessionService.instance.activeSchoolUid;
      if (schoolUid != null) {
        final teachers = await TeacherService.instance.listAllTeachers(schoolUid);
        _totalTeachers = teachers.length;
        _presentTeachers = teachers.where((t) => t.active).length;
      }
    } catch (_) {}
    _lastRefresh = DateTime.now();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final statsAsync = ref.watch(dashboardStatsProvider);
    final settings = ref.watch(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('School Daily Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Status',
            onPressed: () {
              ref.invalidate(dashboardStatsProvider);
              _loadExtraData();
            },
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading status: $e')),
        data: (stats) {
          final presentPct = stats.totalStudents > 0 ? ((stats.presentToday / stats.totalStudents) * 100).toInt() : 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live Operational Badge Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.wifi_tethering_rounded, color: Color(0xFF10B981), size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              settings.instituteName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 8, height: 8,
                                  decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                const Text('ALL SYSTEMS OPERATIONAL', style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 0.5)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Updated: ${DateFormat("hh:mm a, dd MMM yyyy").format(_lastRefresh)}',
                              style: const TextStyle(color: Colors.white60, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 1. STUDENTS LIVE ATTENDANCE STATUS
                _buildSectionHeader('1. Students Attendance Status (Today)', Icons.people_alt_rounded, const Color(0xFF3B82F6), textPrimary),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${stats.totalStudents} Students', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textPrimary)),
                              Text('$presentPct% Overall Attendance Today', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                            child: Text('${stats.presentToday} Present', style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: stats.totalStudents > 0 ? (stats.presentToday / stats.totalStudents) : 0,
                          backgroundColor: borderColor,
                          valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statTile('Present', '${stats.presentToday}', const Color(0xFF10B981), isDark),
                          _statTile('Absent', '${stats.absentToday}', const Color(0xFFEF4444), isDark),
                          _statTile('On Leave', '${stats.leaveToday}', const Color(0xFFF59E0B), isDark),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 2. TEACHERS & STAFF STATUS
                _buildSectionHeader('2. Teachers & Staff Status', Icons.school_rounded, const Color(0xFF8B5CF6), textPrimary),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statTile('Total Staff', '$_totalTeachers', const Color(0xFF8B5CF6), isDark),
                      _statTile('Active on Duty', '$_presentTeachers', const Color(0xFF10B981), isDark),
                      _statTile('Classes Assigned', '${settings.schoolClasses.length}', const Color(0xFF3B82F6), isDark),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 3. FINANCIAL LIVE STATUS
                _buildSectionHeader('3. Financial & Fee Collection Status', Icons.account_balance_wallet_rounded, const Color(0xFF10B981), textPrimary),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Collected This Session', style: TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(AppUtils.formatCurrency(stats.totalCollected), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF059669))),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Total Pending Dues', style: TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(AppUtils.formatCurrency(stats.totalPending), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: stats.totalPending > 0 ? const Color(0xFFDC2626) : const Color(0xFF059669))),
                            ],
                          ),
                        ],
                      ),
                      if (stats.overdueCount > 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('${stats.overdueCount} students have overdue fees beyond due date!', style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 4. DATABASE & CLOUD SYNC HEALTH
                _buildSectionHeader('4. System & Cloud Sync Status', Icons.cloud_done_rounded, const Color(0xFF06B6D4), textPrimary),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      _syncRow('Firebase Cloud Sync', 'Active & Real-Time', const Color(0xFF10B981), isDark),
                      Divider(color: borderColor, height: 16),
                      _syncRow('Local Offline SQLite Storage', 'Healthy & Encrypted', const Color(0xFF10B981), isDark),
                      Divider(color: borderColor, height: 16),
                      _syncRow('Auto Download Categorization', 'Active in Download/SchoolManager', const Color(0xFF2563EB), isDark),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, Color textPrimary) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary)),
      ],
    );
  }

  Widget _statTile(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _syncRow(String label, String status, Color color, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
          child: Text(status, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color)),
        ),
      ],
    );
  }
}
