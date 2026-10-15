import 'package:flutter/material.dart';
import '../../core/constants/app_routes.dart';
import '../../data/services/session_service.dart';
import '../../data/services/teacher_permissions_service.dart';
import '../teachers/teacher_management_screen.dart';
import '../teachers/teacher_role_access_screen.dart';
import '../attendance/teacher_attendance_screen.dart';
import '../admit_card/admit_card_screen.dart';
import '../notice/notice_screen.dart';
import '../id_card/id_card_screen.dart';
import '../results/result_screen.dart';
import '../timetable/timetable_screen.dart';
import '../classes/classes_screen.dart';
import 'school_status_screen.dart';
import '../transport/transport_screen.dart';
import 'principal_complaints_screen.dart';

class AllModulesScreen extends StatelessWidget {
  final bool isEmbedded;
  const AllModulesScreen({super.key, this.isEmbedded = false});

  void _showRestrictedDialog(BuildContext context, String moduleName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_rounded, color: Color(0xFFDC2626), size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Access Restricted',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(
          'The "$moduleName" module is restricted for teacher accounts by the administrator.',
          style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF475569)),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx),
 child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w700)),
 ),
 ],
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 final isPrincipal = SessionService.instance.isPrincipal;
 final isTeacher = SessionService.instance.isTeacher;

 return ValueListenableBuilder(
 valueListenable: TeacherPermissionsService.instance.permissionsNotifier,
 builder: (context, perms, _) {
 return Scaffold(
 backgroundColor: const Color(0xFF1E3A8A),
 body: SafeArea(
 bottom: false,
 child: Column(
 children: [
 // Top Bar
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 if (!isEmbedded)
 IconButton(
 icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
 onPressed: () => Navigator.pop(context),
 ),
 const Expanded(
 child: Center(
 child: Text(
 'All School Modules',
 style: TextStyle(
 color: Colors.white,
 fontWeight: FontWeight.w800,
 fontSize: 18,
 letterSpacing: 0.3,
 ),
 ),
 ),
 ),
 if (!isEmbedded) const SizedBox(width: 40),
 ],
 ),
 ),
 const SizedBox(height: 8),

 // Curved White Sheet Container
 Expanded(
 child: Container(
 width: double.infinity,
 decoration: const BoxDecoration(
 color: Color(0xFFF8FAFC),
 borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
 ),
 child: SingleChildScrollView(
 padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
 child: GridView.count(
 crossAxisCount: 2,
 crossAxisSpacing: 12,
 mainAxisSpacing: 12,
 childAspectRatio: 1.65,
 shrinkWrap: true,
 physics: const NeverScrollableScrollPhysics(),
 children: [
 // 1. Students
 _buildModuleCard(
 context: context,
 title: 'Students',
 icon: Icons.people_alt_rounded,
 iconColor: const Color(0xFF2563EB),
 iconBg: const Color(0xFFDBEAFE),
 isLocked: isTeacher && !perms.canViewStudents,
 onTap: () {
 if (isTeacher && !perms.canViewStudents) {
 _showRestrictedDialog(context, 'Students');
 } else {
 Navigator.pushNamed(context, AppRoutes.studentList);
 }
 },
 ),

 // 2. Teachers (Staff Directory)
 if (isPrincipal)
 _buildModuleCard(
 context: context,
 title: 'Teachers',
 icon: Icons.school_rounded,
 iconColor: const Color(0xFF059669),
 iconBg: const Color(0xFFD1FAE5),
 onTap: () => Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const TeacherManagementScreen()),
 ),
 ),

 // 3. Teacher Attendance (RESTORED / ADDED AS REQUESTED)
 _buildModuleCard(
 context: context,
 title: 'Teacher Att.',
 icon: Icons.co_present_rounded,
 iconColor: const Color(0xFF0284C7),
 iconBg: const Color(0xFFE0F2FE),
 isLocked: isTeacher && !perms.canMarkTeacherAtt,
 onTap: () {
 if (isTeacher && !perms.canMarkTeacherAtt) {
 _showRestrictedDialog(context, 'Teacher Attendance');
 } else {
 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const TeacherAttendanceScreen()),
 );
 }
 },
 ),

 // 4. Teacher Login Role Access / Permissions (NEW CARD AS REQUESTED)
 if (isPrincipal)
 _buildModuleCard(
 context: context,
 title: 'Teacher Access',
 icon: Icons.admin_panel_settings_rounded,
 iconColor: const Color(0xFF8B5CF6),
 iconBg: const Color(0xFFEDE9FE),
 onTap: () => Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const TeacherRoleAccessScreen()),
 ),
 ),

 // 5. Classes
 _buildModuleCard(
 context: context,
 title: 'Classes',
 icon: Icons.school_outlined,
 iconColor: const Color(0xFF0D9488),
 iconBg: const Color(0xFFCCFBF1),
 isLocked: isTeacher && !perms.canManageClasses,
 onTap: () {
 if (isTeacher && !perms.canManageClasses) {
 _showRestrictedDialog(context, 'Classes');
 } else {
 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const ClassesScreen()),
 );
 }
 },
 ),

 // 6. Student Attendance
 _buildModuleCard(
 context: context,
 title: 'Student Att.',
 icon: Icons.calendar_month_rounded,
 iconColor: const Color(0xFF7C3AED),
 iconBg: const Color(0xFFEDE9FE),
 isLocked: isTeacher && !perms.canMarkAttendance,
 onTap: () {
 if (isTeacher && !perms.canMarkAttendance) {
 _showRestrictedDialog(context, 'Attendance');
 } else {
 Navigator.pushNamed(context, AppRoutes.attendance);
 }
 },
 ),

 // 7. Fees
 _buildModuleCard(
 context: context,
 title: 'Fees',
 icon: Icons.account_balance_wallet_rounded,
 iconColor: const Color(0xFFD946EF),
 iconBg: const Color(0xFFFAE8FF),
 isLocked: isTeacher && !perms.canCollectFees,
 onTap: () {
 if (isTeacher && !perms.canCollectFees) {
 _showRestrictedDialog(context, 'Fees');
 } else {
 Navigator.pushNamed(context, AppRoutes.feesCollected);
 }
 },
 ),

 // 8. Promote Class (Highlighted Gradient Card)
 if (isPrincipal)
 _buildPromoteClassCard(
 context: context,
 onTap: () => Navigator.pushNamed(context, AppRoutes.promoteStudents),
 ),

 // 9. ID Cards
 _buildModuleCard(
 context: context,
 title: 'ID Cards',
 icon: Icons.badge_rounded,
 iconColor: const Color(0xFF06B6D4),
 iconBg: const Color(0xFFCFFAFE),
 isLocked: isTeacher && !perms.canViewIdCards,
 onTap: () {
 if (isTeacher && !perms.canViewIdCards) {
 _showRestrictedDialog(context, 'ID Cards');
 } else {
 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const IdCardScreen()),
 );
 }
 },
 ),

 // 10. Results
 _buildModuleCard(
 context: context,
 title: 'Results',
 icon: Icons.description_rounded,
 iconColor: const Color(0xFFEA580C),
 iconBg: const Color(0xFFFFEDD5),
 isLocked: isTeacher && !perms.canEnterResults,
 onTap: () {
 if (isTeacher && !perms.canEnterResults) {
 _showRestrictedDialog(context, 'Results');
 } else {
 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const ResultScreen()),
 );
 }
 },
 ),

 // 11. Time Table
 _buildModuleCard(
 context: context,
 title: 'Time Table',
 icon: Icons.schedule_rounded,
 iconColor: const Color(0xFFF59E0B),
 iconBg: const Color(0xFFFEF3C7),
 isLocked: isTeacher && !perms.canManageTimetable,
 onTap: () {
 if (isTeacher && !perms.canManageTimetable) {
 _showRestrictedDialog(context, 'Time Table');
 } else {
 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const TimetableScreen()),
 );
 }
 },
 ),

 // 12. Admit Cards
 _buildModuleCard(
 context: context,
 title: 'Admit Cards',
 icon: Icons.credit_card_rounded,
 iconColor: const Color(0xFF4F46E5),
 iconBg: const Color(0xFFEEF2FF),
 isLocked: isTeacher && !perms.canViewAdmitCards,
 onTap: () {
 if (isTeacher && !perms.canViewAdmitCards) {
 _showRestrictedDialog(context, 'Admit Cards');
 } else {
 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const AdmitCardScreen()),
 );
 }
 },
 ),

 // 13. School Status
 _buildModuleCard(
 context: context,
 title: 'School Status',
 icon: Icons.sensors_rounded,
 iconColor: const Color(0xFF10B981),
 iconBg: const Color(0xFFD1FAE5),
 isLocked: isTeacher && !perms.canViewSchoolStatus,
 onTap: () {
 if (isTeacher && !perms.canViewSchoolStatus) {
 _showRestrictedDialog(context, 'School Status');
 } else {
 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const SchoolStatusScreen()),
 );
 }
 },
 ),

 // 14. Notice
 _buildModuleCard(
 context: context,
 title: 'Notice',
 icon: Icons.notifications_rounded,
 iconColor: const Color(0xFFEAB308),
 iconBg: const Color(0xFFFEF9C3),
 isLocked: isTeacher && !perms.canPostNotices,
 onTap: () {
 if (isTeacher && !perms.canPostNotices) {
 _showRestrictedDialog(context, 'Notice');
 } else {
 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const NoticeScreen()),
 );
 }
 },
 ),

 // 15. Transport
 _buildModuleCard(
 context: context,
 title: 'Transport',
 icon: Icons.directions_bus_rounded,
 iconColor: const Color(0xFF0D9488),
 iconBg: const Color(0xFFCCFBF1),
 isLocked: isTeacher && !perms.canViewTransport,
 onTap: () {
 if (isTeacher && !perms.canViewTransport) {
 _showRestrictedDialog(context, 'Transport');
 } else {
 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const TransportScreen()),
 );
 }
 },
 ),

 // 16. Reports
 _buildModuleCard(
 context: context,
 title: 'Reports',
 icon: Icons.bar_chart_rounded,
 iconColor: const Color(0xFF0284C7),
 iconBg: const Color(0xFFE0F2FE),
 isLocked: isTeacher && !perms.canExportReports,
 onTap: () {
 if (isTeacher && !perms.canExportReports) {
 _showRestrictedDialog(context, 'Reports');
 } else {
 Navigator.pushNamed(context, AppRoutes.reports);
 }
 },
 ),

 // 17. Parent Desk / Complaints
 _buildModuleCard(
 context: context,
 title: 'Parent Desk',
 icon: Icons.mark_chat_unread_rounded,
 iconColor: const Color(0xFFE11D48),
 iconBg: const Color(0xFFFFE4E6),
 isLocked: isTeacher,
 onTap: () {
 if (isTeacher) {
 _showRestrictedDialog(context, 'Parent Desk');
 } else {
 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const PrincipalComplaintsScreen()),
 );
 }
 },
 ),
 ],
 ),
 ),
 ),
 ),
 ],
 ),
 ),
 );
 },
 );
 }

 Widget _buildModuleCard({
 required BuildContext context,
 required String title,
 required IconData icon,
 required Color iconColor,
 required Color iconBg,
 required VoidCallback onTap,
 bool isLocked = false,
 }) {
 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(14),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: isLocked ? const Color(0xFFF1F5F9) : const Color(0xFFE2E8F0)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.02),
 blurRadius: 4,
 offset: const Offset(0, 2),
 ),
 ],
 ),
 child: Row(
 children: [
 Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: isLocked ? const Color(0xFFF1F5F9) : iconBg,
 borderRadius: BorderRadius.circular(10),
 ),
 child: Center(
 child: Icon(
 isLocked ? Icons.lock_outline_rounded : icon,
 color: isLocked ? const Color(0xFF94A3B8) : iconColor,
 size: 19,
 ),
 ),
 ),
 const SizedBox(width: 9),
 Expanded(
 child: Text(
 title,
 style: TextStyle(
 fontWeight: FontWeight.w700,
 fontSize: 13,
 color: isLocked ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 if (isLocked)
 const Icon(Icons.lock_rounded, size: 14, color: Color(0xFFCBD5E1)),
 ],
 ),
 ),
 );
 }

 Widget _buildPromoteClassCard({
 required BuildContext context,
 required VoidCallback onTap,
 }) {
 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(16),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
 decoration: BoxDecoration(
 gradient: const LinearGradient(
 colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 ),
 borderRadius: BorderRadius.circular(16),
 boxShadow: [
 BoxShadow(
 color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
 blurRadius: 8,
 offset: const Offset(0, 3),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Container(
 width: 42,
 height: 42,
 decoration: BoxDecoration(
 color: Colors.white.withValues(alpha: 0.2),
 shape: BoxShape.circle,
 ),
 child: const Center(
 child: Icon(Icons.school_rounded, color: Colors.white, size: 22),
 ),
 ),
 const Icon(Icons.north_east_rounded, color: Colors.white, size: 20),
 ],
 ),
 const SizedBox(height: 10),
 const Text(
 'Promote Class',
 style: TextStyle(
 fontWeight: FontWeight.w700,
 fontSize: 14,
 color: Colors.white,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ],
 ),
 ),
 );
 }
}
