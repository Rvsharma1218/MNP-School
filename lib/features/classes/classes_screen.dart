import '../attendance/attendance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../data/models/student_model.dart';
import '../../data/models/settings_model.dart';
import '../../data/services/database_service.dart';
import '../../data/services/providers.dart';
import '../timetable/timetable_screen.dart';
import '../admit_card/admit_card_screen.dart';
import '../id_card/id_card_screen.dart';

class ClassesScreen extends ConsumerStatefulWidget {
  const ClassesScreen({super.key});

  @override
  ConsumerState<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends ConsumerState<ClassesScreen> {
  bool _loading = true;
  List<String> _classes = [];
  Map<String, List<StudentModel>> _studentsByClass = {};
  Map<String, Map<String, int>> _attendanceTodayByClass = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final db = DatabaseService.instance;
    final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
    final allStudents = await db.getAllStudents();

    // Group students by class
    final Map<String, List<StudentModel>> grouped = {};
    for (final c in settings.schoolClasses) {
      grouped[c] = allStudents.where((s) => s.className == c).toList();
    }

    if (mounted) {
      setState(() {
        _classes = settings.schoolClasses;
        _studentsByClass = grouped;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Classes & Sections', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _classes.isEmpty
              ? Center(child: Text('No classes found in School Settings.', style: TextStyle(color: textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _classes.length,
                  itemBuilder: (context, i) {
                    final className = _classes[i];
                    final students = _studentsByClass[className] ?? [];
                    final boys = students.where((s) => s.gender?.toLowerCase() == 'male').length;
                    final girls = students.where((s) => s.gender?.toLowerCase() == 'female').length;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Class Header with badge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.school_rounded, color: Color(0xFF2563EB), size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Class $className',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary),
                                        ),
                                        Text(
                                          '${students.length} Students Enrolled',
                                          style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Active',
                                    style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // Metrics Grid
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _metricItem('Boys', '$boys', Icons.boy_rounded, const Color(0xFF3B82F6), isDark),
                                  Container(width: 1, height: 28, color: borderColor),
                                  _metricItem('Girls', '$girls', Icons.girl_rounded, const Color(0xFFEC4899), isDark),
                                  Container(width: 1, height: 28, color: borderColor),
                                  _metricItem('Sections', 'A, B', Icons.grid_view_rounded, const Color(0xFF8B5CF6), isDark),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Quick Action Buttons
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _actionChip(
                                    label: 'View Students',
                                    icon: Icons.people_outline_rounded,
                                    color: const Color(0xFF2563EB),
                                    onTap: () {
                                      ref.read(classFilterProvider.notifier).state = className;
                                      Navigator.pushNamed(context, AppRoutes.studentList);
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _actionChip(
                                    label: 'Attendance',
                                    icon: Icons.calendar_today_outlined,
                                    color: const Color(0xFF8B5CF6),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AttendanceScreen(initialClass: className),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _actionChip(
                                    label: 'Timetable',
                                    icon: Icons.schedule_rounded,
                                    color: const Color(0xFFF59E0B),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const TimetableScreen()),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _actionChip(
                                    label: 'ID Cards',
                                    icon: Icons.badge_outlined,
                                    color: const Color(0xFF0284C7),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const IdCardScreen()),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _actionChip(
                                    label: 'Admit Cards',
                                    icon: Icons.confirmation_number_outlined,
                                    color: const Color(0xFFF97316),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const AdmitCardScreen()),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _metricItem(String label, String value, IconData icon, Color color, bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A))),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _actionChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
