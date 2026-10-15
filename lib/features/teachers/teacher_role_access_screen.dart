import 'package:flutter/material.dart';
import '../../data/models/teacher_permissions.dart';
import '../../data/services/teacher_permissions_service.dart';

class TeacherRoleAccessScreen extends StatefulWidget {
  const TeacherRoleAccessScreen({super.key});

  @override
  State<TeacherRoleAccessScreen> createState() => _TeacherRoleAccessScreenState();
}

class _TeacherRoleAccessScreenState extends State<TeacherRoleAccessScreen> {
  late TeacherPermissions _perms;
  bool _isLoading = false; // Opens immediately using local/cached permissions
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _perms = TeacherPermissionsService.instance.permissions;
    _load();
  }

  Future<void> _load() async {
    // Non-blocking background sync with Firestore
    await TeacherPermissionsService.instance.init();
    if (mounted) {
      setState(() {
        _perms = TeacherPermissionsService.instance.permissions;
      });
    }
  }

  Future<void> _updatePerm(TeacherPermissions newPerms) async {
    setState(() => _perms = newPerms);
    await TeacherPermissionsService.instance.savePermissions(newPerms);
  }

  void _applyPreset(String preset) {
    TeacherPermissions updated;
    switch (preset) {
      case 'all':
        updated = const TeacherPermissions(
          canViewStudents: true,
          canAddStudents: true,
          canEditStudents: true,
          canDeleteStudents: true,
          canMarkAttendance: true,
          canCollectFees: true,
          canViewFeeStatus: true,
          canEnterResults: true,
          canViewAdmitCards: true,
          canViewIdCards: true,
          canPrintCards: true,
          canManageTimetable: true,
          canPostNotices: true,
          canSendWhatsApp: true,
          canViewTransport: true,
          canExportReports: true,
          canManageClasses: true,
          canMarkTeacherAtt: true,
          canViewSchoolStatus: true,
          canViewFacultyList: true,
        );
        break;
      case 'standard':
        updated = const TeacherPermissions(
          canViewStudents: true,
          canAddStudents: true,
          canEditStudents: true,
          canDeleteStudents: true,
          canMarkAttendance: true,
          canCollectFees: false,
          canViewFeeStatus: false,
          canEnterResults: true,
          canViewAdmitCards: true,
          canViewIdCards: true,
          canPrintCards: true,
          canManageTimetable: true,
          canPostNotices: true,
          canSendWhatsApp: true,
          canViewTransport: false,
          canExportReports: false,
          canManageClasses: false,
          canMarkTeacherAtt: false,
          canViewSchoolStatus: false,
          canViewFacultyList: false,
        );
        break;
      case 'minimal':
        updated = const TeacherPermissions(
          canViewStudents: true,
          canAddStudents: false,
          canEditStudents: false,
          canDeleteStudents: false,
          canMarkAttendance: true,
          canCollectFees: false,
          canViewFeeStatus: false,
          canEnterResults: false,
          canViewAdmitCards: false,
          canViewIdCards: false,
          canPrintCards: false,
          canManageTimetable: false,
          canPostNotices: false,
          canSendWhatsApp: false,
          canViewTransport: false,
          canExportReports: false,
          canManageClasses: false,
          canMarkTeacherAtt: false,
          canViewSchoolStatus: false,
          canViewFacultyList: false,
        );
        break;
      default:
        return;
    }
    _updatePerm(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Preset "$preset" applied successfully'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveAll() async {
    setState(() => _isSaving = true);
    await TeacherPermissionsService.instance.savePermissions(_perms);
    setState(() => _isSaving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Teacher permissions saved & synced successfully!'),
        backgroundColor: Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Teacher Role Access',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white),
            ),
            Text(
              'Manage permission access for teacher logins',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                // Top Info Header Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.shield_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Permissions & Role Access',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Configure feature access for teacher logins. Teachers will only see the modules and actions enabled below.',
                        style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.35),
                      ),
                      const SizedBox(height: 14),
                      // Preset Chips
                      Row(
                        children: [
                          _buildPresetChip('Standard', () => _applyPreset('standard')),
                          const SizedBox(width: 8),
                          _buildPresetChip('Grant All', () => _applyPreset('all')),
                          const SizedBox(width: 8),
                          _buildPresetChip('Minimal', () => _applyPreset('minimal')),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Section 1: Students & Classes
                _buildSectionHeader('STUDENTS & CLASSES'),
                _buildCard([
                  _buildToggleTile(
                    title: 'Student Directory',
                    subtitle: 'View student lists and profiles',
                    icon: Icons.people_rounded,
                    iconColor: const Color(0xFF2563EB),
                    iconBg: const Color(0xFFDBEAFE),
                    value: _perms.canViewStudents,
                    onChanged: (v) => _updatePerm(_perms.copyWith(canViewStudents: v)),
                  ),
                  Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  _buildToggleTile(
                    title: 'Add New Students',
                    subtitle: 'Enroll and register new students into the school',
                    icon: Icons.person_add_rounded,
                    iconColor: const Color(0xFF0284C7),
                    iconBg: const Color(0xFFE0F2FE),
                    value: _perms.canAddStudents,
                    onChanged: (v) => _updatePerm(_perms.copyWith(canAddStudents: v)),
                  ),
                  Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  _buildToggleTile(
                    title: 'Edit Student Details',
                    subtitle: 'Modify existing student profile, photos, and contact info',
                    icon: Icons.edit_note_rounded,
                    iconColor: const Color(0xFF4F46E5),
                    iconBg: const Color(0xFFEEF2FF),
                    value: _perms.canEditStudents,
                    onChanged: (v) => _updatePerm(_perms.copyWith(canEditStudents: v)),
                  ),
                  Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  _buildToggleTile(
                    title: 'Delete Student Records',
                    subtitle: 'Permanently remove student profiles from the school database',
                    icon: Icons.delete_outline_rounded,
                    iconColor: const Color(0xFFDC2626),
                    iconBg: const Color(0xFFFEE2E2),
                    value: _perms.canDeleteStudents,
                    onChanged: (v) => _updatePerm(_perms.copyWith(canDeleteStudents: v)),
                  ),
                  Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  _buildToggleTile(
                    title: 'Classes & Sections',
                    subtitle: 'Manage classes, sections, and class roster',
                    icon: Icons.meeting_room_rounded,
                    iconColor: const Color(0xFF059669),
                    iconBg: const Color(0xFFD1FAE5),
                    value: _perms.canManageClasses,
                    onChanged: (v) => _updatePerm(_perms.copyWith(canManageClasses: v)),
                  ),
                ]),

                const SizedBox(height: 16),

                // Section 2: Attendance
                _buildSectionHeader('ATTENDANCE'),
                _buildCard([
                  _buildToggleTile(
                    title: 'Student Attendance',
                    subtitle: 'Mark daily attendance for students in assigned classes',
                    icon: Icons.calendar_month_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    iconBg: const Color(0xFFEDE9FE),
                    value: _perms.canMarkAttendance,
                    onChanged: (v) => _updatePerm(_perms.copyWith(canMarkAttendance: v)),
                  ),
                  Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  _buildToggleTile(
                    title: 'Teacher Attendance Module',
                    subtitle: 'Allow teachers to log their daily check-in attendance',
                    icon: Icons.co_present_rounded,
                    iconColor: const Color(0xFF9333EA),
                    iconBg: const Color(0xFFF3E8FF),
                    value: _perms.canMarkTeacherAtt,
                    onChanged: (v) => _updatePerm(_perms.copyWith(canMarkTeacherAtt: v)),
                  ),
                ]),

                const SizedBox(height: 16),

                // Section 3: Exams & Cards
                _buildSectionHeader('EXAMS & CARDS'),
                _buildCard([
                  _buildToggleTile(
                    title: 'Exam Results Entry',
                    subtitle: 'Enter exam marks and generate report cards',
                    icon: Icons.grade_rounded,
                    iconColor: const Color(0xFFEA580C),
                    iconBg: const Color(0xFFFFEDD5),
                    value: _perms.canEnterResults,
                    onChanged: (v) => _updatePerm(_perms.copyWith(canEnterResults: v)),
                  ),
                  Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  _buildToggleTile(
                    title: 'Admit Cards / Hall Tickets',
                    subtitle: 'View and download student exam admit cards',
                    icon: Icons.assignment_rounded,
                    iconColor: const Color(0xFF4F46E5),
                    iconBg: const Color(0xFFEEF2FF),
                    value: _perms.canViewAdmitCards,
                    onChanged: (v) => _updatePerm(_perms.copyWith(canViewAdmitCards: v)),
                  ),
                  Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  _buildToggleTile(
                    title: 'Student ID Cards',
                    subtitle: 'View and generate student identity cards',
                    icon: Icons.badge_rounded,
                    iconColor: const Color(0xFF06B6D4),
                    iconBg: const Color(0xFFCFFAFE),
                    value: _perms.canViewIdCards,
                    onChanged: (v) => _updatePerm(_perms.copyWith(canViewIdCards: v)),
                  ),
                  Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  _buildToggleTile(
                    title: 'Print & Download Cards',
                    subtitle: 'Download and print ID cards, admit cards, and marksheets',
                    icon: Icons.print_rounded,
                    iconColor: const Color(0xFF10B981),
                    iconBg: const Color(0xFFD1FAE5),
                    value: _perms.canPrintCards,
                    onChanged: (v) => _updatePerm(_perms.copyWith(canPrintCards: v)),
                  ),
                ]),

                const SizedBox(height: 16),

                // Section 4: Academic & Routine
                _buildSectionHeader('ACADEMIC & SCHEDULE'),
                _buildCard([
                  _buildToggleTile(
                    title: 'Time Table',
                    subtitle: 'View and manage school routine & timetable',
                    icon: Icons.schedule_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    iconBg: const Color(0xFFFEF3C7),
                    value: _perms.canManageTimetable,
                    onChanged: (v) => _updatePerm(_perms.copyWith(canManageTimetable: v)),
                  ),
                  Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  _buildToggleTile(
                    title: 'Notice Board',
                    subtitle: 'View announcements and post new school notices',
                    icon: Icons.notifications_rounded,
                    iconColor: const Color(0xFFEAB308),
                    iconBg: const Color(0xFFFEF9C3),
                    value: _perms.canPostNotices,
                    onChanged: (v) => _updatePerm(_perms.copyWith(canPostNotices: v)),
                  ),
                  Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  _buildToggleTile(
                    title: 'WhatsApp Alerts & Notifications',
                    subtitle: 'Send direct WhatsApp attendance alerts and updates to parents',
                    icon: Icons.message_rounded,
                    iconColor: const Color(0xFF16A34A),
                    iconBg: const Color(0xFFDCFCE7),
                    value: _perms.canSendWhatsApp,
                    onChanged: (v) => _updatePerm(_perms.copyWith(canSendWhatsApp: v)),
                  ),
                ]),

                const SizedBox(height: 16),

                // Section 5: Finance & Admin
                _buildSectionHeader('FINANCE, SCHOOL STATUS & ADMIN'),
                _buildCard([
                  _buildToggleTile(
                    title: 'School Live Status (Overview)',
                    subtitle: 'View live school status, attendance summary, and operations overview',
                    icon: Icons.analytics_rounded,
                    iconColor: const Color(0xFF1D4ED8),
                    iconBg: const Color(0xFFDBEAFE),
                    value: _perms.canViewSchoolStatus,
                    onChanged: (v) => _updatePerm(_perms.copyWith(canViewSchoolStatus: v)),
                  ),
                  Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  _buildToggleTile(
                    title: 'Fee Collection & Dues',
                    subtitle: 'Collect fees from students and generate receipts',
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: const Color(0xFFD946EF),
                    iconBg: const Color(0xFFFAE8FF),
                    value: _perms.canCollectFees,
                    onChanged: (v) => _updatePerm(_perms.copyWith(canCollectFees: v)),
                  ),
                  Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  _buildToggleTile(
                    title: 'View Fee Status & Dues',
                    subtitle: 'View student fee pending/clear status without permission to collect fees',
                    icon: Icons.monetization_on_outlined,
                    iconColor: const Color(0xFF7C3AED),
                    iconBg: const Color(0xFFEDE9FE),
                    value: _perms.canViewFeeStatus,
                    onChanged: (v) => _updatePerm(_perms.copyWith(canViewFeeStatus: v)),
                  ),
                  Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  _buildToggleTile(
                    title: 'Reports & Export',
                    subtitle: 'Export student lists, attendance & fees to Excel/PDF',
                    icon: Icons.bar_chart_rounded,
                    iconColor: const Color(0xFF0284C7),
                    iconBg: const Color(0xFFE0F2FE),
                    value: _perms.canExportReports,
                    onChanged: (v) => _updatePerm(_perms.copyWith(canExportReports: v)),
                  ),
                  Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  _buildToggleTile(
                    title: 'Faculty & Teacher Directory',
                    subtitle: 'Access other faculty members and teacher profile directory',
                    icon: Icons.badge_outlined,
                    iconColor: const Color(0xFF9333EA),
                    iconBg: const Color(0xFFF3E8FF),
                    value: _perms.canViewFacultyList,
                    onChanged: (v) => _updatePerm(_perms.copyWith(canViewFacultyList: v)),
                  ),
                  Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  _buildToggleTile(
                    title: 'Transport Module',
                    subtitle: 'View bus routes and transport allocations',
                    icon: Icons.directions_bus_rounded,
                    iconColor: const Color(0xFF0D9488),
                    iconBg: const Color(0xFFCCFBF1),
                    value: _perms.canViewTransport,
                    onChanged: (v) => _updatePerm(_perms.copyWith(canViewTransport: v)),
                  ),
                ]),
              ],
            ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveAll,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_rounded, color: Colors.white),
            label: Text(
              _isSaving ? 'Saving...' : 'Save Permissions',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white38),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: isDark ? Colors.white70 : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? iconColor.withValues(alpha: 0.2) : iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isDark ? iconColor : iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFF2563EB),
            activeTrackColor: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
            inactiveThumbColor: isDark ? Colors.white38 : const Color(0xFF94A3B8),
            inactiveTrackColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
