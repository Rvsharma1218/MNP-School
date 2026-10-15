import '../results/result_screen.dart';
import '../results/screens/student_mark_entry_screen.dart';
import '../results/screens/student_result_detail_screen.dart';
import '../../data/services/result_pdf_service.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/fee_model.dart';
import '../../data/models/student_model.dart';
import '../../data/models/settings_model.dart';
import '../../data/models/result_model.dart';
import '../../data/services/database_service.dart';
import '../../data/services/providers.dart';
import '../../data/services/session_service.dart';
import '../attendance/attendance_report_service.dart';
import '../whatsapp/whatsapp_service.dart';
import '../../widgets/common_widgets.dart';
import '../../data/services/receipt_pdf_service.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../data/services/student_full_report_service.dart';
import '../admit_card/admit_card_screen.dart';

class StudentProfileScreen extends ConsumerStatefulWidget {
  final String studentId;
  const StudentProfileScreen({super.key, required this.studentId});

  @override
  ConsumerState<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends ConsumerState<StudentProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final isPrincipal = SessionService.instance.isPrincipal;
    _tabController = TabController(length: isPrincipal ? 4 : 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<StudentModel?> _getStudent() =>
      DatabaseService.instance.getStudentById(widget.studentId);

  Future<void> _deleteStudent(BuildContext context, StudentModel student) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text('Are you sure you want to delete ${student.name}? This will remove all their records.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(studentsProvider.notifier).deleteStudent(student.id);
      ref.invalidate(dashboardStatsProvider);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student deleted'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StudentModel?>(
      future: _getStudent(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: LoadingWidget());
        }
        final student = snap.data;
        if (student == null) {
          return const Scaffold(body: Center(child: Text('Student not found')));
        }
        return _buildProfile(context, student);
      },
    );
  }

  Widget _buildProfile(BuildContext context, StudentModel student) {
    final isPrincipal = SessionService.instance.isPrincipal;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, innerScrolled) => [
          SliverAppBar(
            expandedHeight: 350,
            pinned: true,
            floating: false,
            backgroundColor: AppColors.primary,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
                onPressed: () async {
                  await Navigator.pushNamed(ctx, AppRoutes.editStudent, arguments: student.id);
                  setState(() {});
                },
              ),
              if (isPrincipal)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  onPressed: () => _deleteStudent(context, student),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 52, bottom: 56),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12)],
                          ),
                          child: CircleAvatar(
                            radius: 42,
                            backgroundColor: Colors.white,
                            child: ClipOval(
                              child: AppUtils.buildAppImageWidget(
                                student.photoPath,
                                width: 84,
                                height: 84,
                                fit: BoxFit.cover,
                                placeholder: Center(
                                  child: Text(
                                    AppUtils.getInitials(student.name),
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(student.name,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(student.studentId,
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _headerChip(
                                student.studentType == 'school' ? 'School' : 'Computer',
                                student.studentType == 'school' ? Icons.school : Icons.computer,
                              ),
                              if (student.studentType == 'school' &&
                                  (student.className?.isNotEmpty == true ||
                                      student.section?.isNotEmpty == true)) ...[
                                const SizedBox(width: 6),
                                _headerChip(
                                  'Class ${student.className ?? ''}'
                                      '${student.section?.isNotEmpty == true ? ' - ${student.section}' : ''}',
                                  Icons.class_,
                                ),
                              ] else if (student.studentType == 'computer' &&
                                  student.course?.isNotEmpty == true) ...[
                                const SizedBox(width: 6),
                                _headerChip(student.course!, Icons.laptop_outlined),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _headerChip(student.statusLabel, Icons.circle,
                                  color: Color(student.statusColor)),
                              if (student.session?.isNotEmpty == true) ...[
                                const SizedBox(width: 6),
                                _headerChip('${student.session}', Icons.calendar_today),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.accent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.6),
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.2),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.2),
              labelPadding: const EdgeInsets.symmetric(horizontal: 6),
              tabs: [
                const Tab(height: 44, text: 'Info'),
                if (isPrincipal) const Tab(height: 44, text: 'Fees'), // Hide Fee Tab for Teachers
                const Tab(height: 44, text: 'Attendance'),
                const Tab(height: 44, text: 'Results'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _InfoTab(student: student),
            if (isPrincipal) _FeesTab(student: student), // Hide Fee Tab View for Teachers
            _AttendanceTab(student: student),
            _ResultsTab(studentId: student.id),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context, student),
    );
  }

  Widget _headerChip(String label, IconData icon, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color?.withOpacity(0.3) ?? Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, StudentModel student) {
    final cs = Theme.of(context).colorScheme;
    final isPrincipal = SessionService.instance.isPrincipal;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12,
          MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08),
              blurRadius: 12, offset: const Offset(0, -3)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _BottomActionButton(
              icon: Icons.badge_outlined,
              label: 'ID Card',
              onTap: () => Navigator.pushNamed(
                  context, AppRoutes.idCard, arguments: student.id),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _BottomActionButton(
              icon: Icons.confirmation_number_outlined,
              label: 'Admit Card',
              highlightColor: const Color(0xFFF97316),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdmitCardScreen(studentId: student.id),
                ),
              ),
            ),
          ),
          if (isPrincipal) ...[
            const SizedBox(width: 6),
            Expanded(
              child: _BottomActionButton(
                icon: Icons.receipt_long_outlined,
                label: 'Fee Receipt',
                onTap: () => Navigator.pushNamed(
                    context, AppRoutes.fees, arguments: student.id),
              ),
            ),
          ],
          const SizedBox(width: 6),
          Expanded(
            child: _BottomActionButton(
              icon: Icons.assessment_rounded,
              label: 'Full Report',
              highlightColor: AppColors.primary,
              onTap: () => _showFullReportSheet(context, student),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullReportSheet(BuildContext context, StudentModel student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FullReportModal(student: student, ref: ref),
    );
  }
}

class _InfoTab extends StatelessWidget {
  final StudentModel student;
  const _InfoTab({required this.student});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard(context, 'Personal Details', [
          _buildRow(context, Icons.badge_outlined, 'Student ID', student.studentId),
          _buildRow(context, Icons.numbers, 'Admission No.', student.admissionNumber),
          _buildRow(context, Icons.credit_card_outlined, 'Aadhaar / Document ID', student.aadhaarNumber ?? '—'),
          _buildAadhaarCard(context, student),
          _buildRow(context, Icons.person_outline, "Father's Name", student.fatherName),
          if (student.motherName != null)
            _buildRow(context, Icons.person_outline, "Mother's Name", student.motherName!),
          _buildRow(context, Icons.cake_outlined, 'Date of Birth', AppUtils.formatDate(student.dob)),
          _buildRow(context, Icons.people_outline, 'Gender', student.gender),
          _buildRow(context, Icons.phone_outlined, 'Mobile', student.mobile),
          if (student.alternateMobile != null)
            _buildRow(context, Icons.phone_outlined, 'Alt. Mobile', student.alternateMobile!),
          if (student.email != null)
            _buildRow(context, Icons.email_outlined, 'Email', student.email!),
          _buildRow(context, Icons.location_on_outlined, 'Address', student.address),
          _buildRow(context, Icons.event_outlined, 'Admission Date', AppUtils.formatDate(student.admissionDate)),
        ]),
        const SizedBox(height: 16),
        if (student.studentType == 'school')
          _buildInfoCard(context, 'School Details', [
            _buildRow(context, Icons.class_, 'Class',
                '${student.className ?? ''}${student.section?.isNotEmpty == true ? ' - ${student.section}' : ''}'),
            if (student.rollNumber != null)
              _buildRow(context, Icons.format_list_numbered, 'Roll Number', student.rollNumber!),
            _buildRow(context, Icons.circle, 'Status', student.statusLabel),
            if (student.session?.isNotEmpty == true)
              _buildRow(context, Icons.calendar_today, 'Session', student.session!),
          ]),
        if (student.studentType == 'computer')
          _buildInfoCard(context, 'Computer Institute Details', [
            _buildRow(context, Icons.computer_outlined, 'Course', student.course ?? ''),
            if (student.batch != null)
              _buildRow(context, Icons.group_outlined, 'Batch', student.batch!),
            _buildRow(context, Icons.circle, 'Status', student.statusLabel),
            if (student.session?.isNotEmpty == true)
              _buildRow(context, Icons.calendar_today, 'Session', student.session!),
            if (student.courseDurationMonths != null)
              _buildRow(context, Icons.timer_outlined, 'Duration',
                  '${student.courseDurationMonths} months'),
          ]),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildRow(BuildContext context, IconData icon, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? '—' : value,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAadhaarCard(BuildContext context, StudentModel student) {
    final cs = Theme.of(context).colorScheme;
    final hasDoc = student.aadhaarDocPath != null && student.aadhaarDocPath!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: hasDoc ? () => _showFullImage(context, student.aadhaarDocPath!, 'Aadhaar Card Document') : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 60,
                height: 46,
                color: cs.surfaceContainerHighest,
                child: hasDoc
                    ? AppUtils.buildAppImageWidget(
                        student.aadhaarDocPath!,
                        width: 60,
                        height: 46,
                        fit: BoxFit.cover,
                        placeholder: const Center(child: Icon(Icons.badge_outlined, size: 22)),
                      )
                    : Icon(Icons.badge_outlined, color: cs.onSurfaceVariant, size: 26),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Aadhaar / ID Card',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: cs.onSurface),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: hasDoc ? AppColors.success.withValues(alpha: 0.15) : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        hasDoc ? 'DOCUMENT ATTACHED' : 'NO DOCUMENT',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: hasDoc ? AppColors.success : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  hasDoc ? 'Tap image or preview button to view full card' : 'No ID document photo uploaded yet',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (hasDoc)
            IconButton(
              icon: const Icon(Icons.visibility_outlined, size: 20),
              tooltip: 'View Document',
              onPressed: () => _showFullImage(context, student.aadhaarDocPath!, 'Aadhaar Card Document'),
            ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String path, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            Flexible(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: AppUtils.buildAppImageWidget(
                  path,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String title, List<Widget> children) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 4, height: 18,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: cs.onSurface,
                ),
              ),
            ]),
            Divider(height: 20, color: cs.outlineVariant),
            ...children,
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _FeesTab extends ConsumerWidget {
  final StudentModel student;

  const _FeesTab({
    required this.student,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentId = student.id;
    final feeAsync = ref.watch(feeProvider(studentId));

    return feeAsync.when(
      data: (FeeModel? fee) {
        if (fee == null) {
          return const Center(
            child: Text('No fee record'),
          );
        }

        final payments = [...fee.payments];

        payments.sort(
              (a, b) => b.paymentDate.compareTo(a.paymentDate),
        );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GradientCard(
              gradient: fee.remainingFees <= 0
                  ? AppColors.gradientGreen
                  : AppColors.gradientOrange,

              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _feeItem(
                        'Total',
                        AppUtils.formatCurrency(
                          fee.totalFees,
                        ),
                      ),
                      _feeItem(
                        'Paid',
                        AppUtils.formatCurrency(
                          fee.paidFees,
                        ),
                      ),
                      _feeItem(
                        'Remaining',
                        AppUtils.formatCurrency(
                          fee.remainingFees,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: fee.totalFees > 0
                        ? (fee.paidFees / fee.totalFees).clamp(0.0, 1.0)
                        : 0,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fee.feeStatus,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.fees,
                      arguments: studentId,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text(
                      'Manage Fees',
                    ),
                  ),
                ),
                if (fee.remainingFees > 0) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final settings = ref.read(settingsProvider).value ?? SettingsModel.defaultSettings();
                        WhatsAppService.showFeeReminderDialog(
                          context,
                          student: student,
                          settings: settings,
                          dueAmount: fee.remainingFees,
                          totalFee: fee.totalFees,
                          paidFee: fee.paidFees,
                        );
                      },
                      icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 18),
                      label: const Text(
                        'Fee Reminder',
                        style: TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF25D366), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 4,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.receipt_long,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Receipt History',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (payments.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: const [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 48,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'No Receipt History',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Payment receipts will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...payments.map(
                    (payment) => _ReceiptHistoryCard(
                  studentId: studentId,
                  payment: payment,
                ),
              ),
            const SizedBox(height: 30),
          ],
        );
      },
      loading: () => const LoadingWidget(),
      error: (e, _) => Center(
        child: Text('Error: $e'),
      ),
    );
  }

  Widget _feeItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ReceiptHistoryCard extends StatelessWidget {
  final String studentId;
  final PaymentModel payment;

  const _ReceiptHistoryCard({
    required this.studentId,
    required this.payment,
  });

  String _formatDate(DateTime date) {
    final d = date.toLocal();
    return '${d.day.toString().padLeft(2, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.year}';
  }

  String _formatTime(DateTime date) {
    final d = date.toLocal();
    final hour = d.hour == 0
        ? 12
        : d.hour > 12
        ? d.hour - 12
        : d.hour;
    final minute = d.minute.toString().padLeft(2, '0');
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppUtils.formatCurrency(payment.amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Receipt: ${payment.receiptNumber}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    payment.paymentMode,
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 15, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(payment.paymentDate),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, size: 15, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        _formatTime(payment.paymentDate),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Send Receipt on WhatsApp',
                  onPressed: () async {
                    await _sendReceiptWhatsApp(context, payment);
                  },
                  icon: const Icon(
                    Icons.chat_rounded,
                    color: Color(0xFF25D366),
                  ),
                ),
                IconButton(
                  tooltip: 'Generate Receipt PDF',
                  onPressed: () async {
                    await _generateReceiptPdf(context, payment);
                  },
                  icon: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendReceiptWhatsApp(BuildContext context, PaymentModel payment) async {
    try {
      final student = await DatabaseService.instance.getStudentById(studentId);
      if (student == null) return;

      final file = await _createReceiptPdf(student, payment);

      await WhatsAppService.sendPdf(
        context: context,
        phone: student.mobile,
        message: 'Dear ${student.name},\n\n'
            'Please find your fee payment receipt.\n\n'
            'Receipt No: ${payment.receiptNumber}\n'
            'Amount: ${AppUtils.formatCurrency(payment.amount)}\n'
            'Date: ${_formatDate(payment.paymentDate)}\n'
            'Time: ${_formatTime(payment.paymentDate)}\n'
            'Payment Mode: ${payment.paymentMode}\n\n'
            'Thank you.',
        filePath: file,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send receipt: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _generateReceiptPdf(BuildContext context, PaymentModel payment) async {
    try {
      final student = await DatabaseService.instance.getStudentById(studentId);
      if (student == null) return;

      final file = await _createReceiptPdf(student, payment);

      await Printing.layoutPdf(
        onLayout: (format) async {
          return File(file).readAsBytes();
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not generate receipt: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<String> _createReceiptPdf(StudentModel student, PaymentModel payment) async {
    final settings = await DatabaseService.instance.getSettings();
    final feeMonthRaw = payment.feeMonth ?? payment.monthKey ?? '';
    final mKey = PaymentModel.toMonthKey(feeMonthRaw, payment.paymentDate);
    MonthlyFeeModel? fee;
    if (mKey.isNotEmpty) {
      try {
        fee = await DatabaseService.instance.getMonthlyFee(student.id, mKey) ??
            await DatabaseService.instance.getMonthlyFee(student.studentId, mKey) ??
            await DatabaseService.instance.getMonthlyFee(studentId, mKey);
      } catch (_) {}
    }

    return ReceiptPdfService.instance.createPdfFile(
      student: student,
      payment: payment,
      settings: settings,
      fee: fee,
    );
  }
}

class _AttendanceTab extends ConsumerStatefulWidget {
  final StudentModel student;
  const _AttendanceTab({required this.student});

  @override
  ConsumerState<_AttendanceTab> createState() => _AttendanceTabState();
}

enum _ReportRange { today, allDays, custom }

class _AttendanceTabState extends ConsumerState<_AttendanceTab> {
  bool _sending = false;

  Future<void> _sendAttendanceReport() async {
    final cs = Theme.of(context).colorScheme;

    final selectedRange = await showModalBottomSheet<_ReportRange>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share Attendance Report',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Select date range to send via WhatsApp',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _optionRow(
                context: ctx,
                icon: Icons.today_rounded,
                iconColor: AppColors.primary,
                title: 'Today',
                subtitle: "Only today's attendance status",
                onTap: () => Navigator.pop(ctx, _ReportRange.today),
              ),
              const SizedBox(height: 10),
              _optionRow(
                context: ctx,
                icon: Icons.all_inclusive_rounded,
                iconColor: AppColors.success,
                title: 'All Days',
                subtitle: 'Full history from first record to today',
                onTap: () => Navigator.pop(ctx, _ReportRange.allDays),
              ),
              const SizedBox(height: 10),
              _optionRow(
                context: ctx,
                icon: Icons.date_range_rounded,
                iconColor: AppColors.warning,
                title: 'Custom Date Range',
                subtitle: 'Select specific From and To dates',
                onTap: () => Navigator.pop(ctx, _ReportRange.custom),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  style: TextButton.styleFrom(
                    foregroundColor: cs.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selectedRange == null || !mounted) return;

    DateTime fromDate;
    DateTime toDate = DateTime.now();

    if (selectedRange == _ReportRange.today) {
      fromDate = DateTime(toDate.year, toDate.month, toDate.day);
    } else if (selectedRange == _ReportRange.allDays) {
      final records = await DatabaseService.instance.getAttendanceByStudentId(widget.student.id);
      if (records.isNotEmpty) {
        fromDate = records.map((r) => r.date).reduce((a, b) => a.isBefore(b) ? a : b);
      } else {
        fromDate = DateTime(toDate.year, toDate.month, 1);
      }
    } else {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(toDate.year - 5),
        lastDate: toDate,
        initialDateRange: DateTimeRange(
          start: DateTime(toDate.year, toDate.month, 1),
          end: toDate,
        ),
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: cs.brightness == Brightness.dark
                ? ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: cs.surface,
              onSurface: cs.onSurface,
            )
                : ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: cs.surface,
              onSurface: cs.onSurface,
            ),
          ),
          child: child!,
        ),
      );

      if (range == null || !mounted) return;
      fromDate = range.start;
      toDate = range.end;
    }

    setState(() => _sending = true);
    try {
      final settings = await DatabaseService.instance.getSettings();
      final file = await AttendanceReportService.generateStudentAttendancePdf(
        student: widget.student,
        fromDate: fromDate,
        toDate: toDate,
        instituteName: settings.instituteName,
      );
      if (!mounted) return;
      await WhatsAppService.sendPdf(
        context: context,
        phone: widget.student.mobile,
        message: AttendanceReportService.whatsappMessage(
          student: widget.student,
          fromDate: fromDate,
          toDate: toDate,
          instituteName: settings.instituteName,
        ),
        filePath: file.path,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate report: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _optionRow({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outline.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
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
                      fontSize: 14.5,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studentId = widget.student.id;
    final attAsync = ref.watch(studentAttendanceProvider(studentId));
    final cs = Theme.of(context).colorScheme;

    return attAsync.when(
      data: (records) {
        final total = records.length;
        final present = records.where((r) => r.status == 'present').length;
        final absent = records.where((r) => r.status == 'absent').length;
        final leave = records.where((r) => r.status == 'leave').length;
        final pct = total > 0 ? (present / total * 100).toStringAsFixed(1) : '0.0';

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GradientCard(
              gradient: double.parse(pct) >= 75 ? AppColors.gradientGreen : AppColors.gradientOrange,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _attItem('$pct%', 'Overall'),
                  _attItem('$present', 'Present'),
                  _attItem('$absent', 'Absent'),
                  _attItem('$leave', 'Leave'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _sending ? null : _sendAttendanceReport,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF25D366).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _sending
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : const Icon(Icons.chat_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      _sending ? 'Preparing report…' : 'Send Attendance Report via WhatsApp',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            if (records.isEmpty)
              const EmptyState(icon: Icons.event_busy, title: 'No Attendance Records')
            else ...[
              Text(
                'Recent Records',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              ...records.take(30).map((r) => Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: _statusIcon(r.status),
                  title: Text(
                    AppUtils.formatDateLong(r.date),
                    style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
                  ),
                  trailing: _statusChip(r.status),
                  dense: true,
                ),
              )),
            ],
          ],
        );
      },
      loading: () => const LoadingWidget(),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _attItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
      ],
    );
  }

  Widget _statusIcon(String status) {
    Color c;
    IconData i;
    switch (status) {
      case 'present': c = AppColors.success; i = Icons.check_circle; break;
      case 'absent': c = AppColors.error; i = Icons.cancel; break;
      default: c = AppColors.warning; i = Icons.watch_later;
    }
    return Icon(i, color: c);
  }

  Widget _statusChip(String status) {
    Color bg, fg;
    switch (status) {
      case 'present': bg = AppColors.successLight; fg = AppColors.success; break;
      case 'absent': bg = AppColors.errorLight; fg = AppColors.error; break;
      default: bg = AppColors.warningLight; fg = AppColors.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class _ResultsTab extends ConsumerStatefulWidget {
  final String studentId;
  const _ResultsTab({required this.studentId});

  @override
  ConsumerState<_ResultsTab> createState() => _ResultsTabState();
}

class _ResultsTabState extends ConsumerState<_ResultsTab> {
  int _refreshKey = 0;

  void _refresh() {
    setState(() => _refreshKey++);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();

    return FutureBuilder<List<dynamic>>(
      key: ValueKey(_refreshKey),
      future: Future.wait([
        DatabaseService.instance.getResultsByStudentId(widget.studentId),
        DatabaseService.instance.getStudentById(widget.studentId),
      ]),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const LoadingWidget();
        final results = (snap.data?[0] as List<ResultModel>?) ?? [];
        final student = snap.data?[1] as StudentModel?;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      if (student != null) {
                        final saved = await Navigator.push<ResultModel>(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) => StudentMarkEntryScreen(student: student),
                          ),
                        );
                        if (saved != null) {
                          _refresh();
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).clearSnackBars();
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                margin: const EdgeInsets.all(16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                content: Text('✓ Marksheet saved for ${student.name}!'),
                                backgroundColor: Colors.green.shade700,
                              ),
                            );
                          }
                        }
                      } else {
                        await Navigator.push(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) => ResultScreen(studentId: widget.studentId),
                          ),
                        );
                        _refresh();
                      }
                    },
                    icon: const Icon(Icons.add_chart_rounded, size: 20),
                    label: const Text('Enter / Edit Marksheet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1E3A8A),
                    side: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      ctx,
                      MaterialPageRoute(
                        builder: (_) => AdmitCardScreen(studentId: widget.studentId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.confirmation_number_outlined, size: 18),
                  label: const Text('Admit Card', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (results.isEmpty)
              const EmptyState(icon: Icons.assignment_outlined, title: 'No Results Yet Recorded')
            else
              ...results.map((r) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                elevation: 1,
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                    child: const Icon(Icons.military_tech_rounded, color: Color(0xFF1E3A8A), size: 22),
                  ),
                  title: Text(r.examName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                  subtitle: Text(
                    '${r.obtainedMarks.toInt()}/${r.totalMarks.toInt()} • ${r.overallPercentage.toStringAsFixed(1)}% • Grade: ${r.overallGrade}',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700, fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Save PDF to Device',
                        icon: const Icon(Icons.download_rounded, color: Color(0xFF0D9488)),
                        onPressed: () async {
                          if (student != null) {
                            try {
                              final path = await ResultPdfService.instance.saveResultPdfToDevice(
                                result: r,
                                student: student,
                                settings: settings,
                              );
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).clearSnackBars();
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                    margin: const EdgeInsets.all(16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    content: Text('✓ Saved: ${path.split(RegExp(r"[/\\]")).last}'),
                                    backgroundColor: Colors.green.shade700,
                                    action: SnackBarAction(
                                      label: 'Share',
                                      textColor: Colors.white,
                                      onPressed: () {
                                        ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
                                        Share.shareXFiles([XFile(path)], text: 'Marksheet - ${student.name}');
                                      },
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('Error saving PDF: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          }
                        },
                      ),
                      IconButton(
                        tooltip: 'Delete Result',
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: ctx,
                            builder: (dCtx) => AlertDialog(
                              title: const Text('Delete Result?'),
                              content: Text('Are you sure you want to delete the result for "${r.examName}"?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(dCtx, true),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await DatabaseService.instance.deleteResult(r.id);
                            _refresh();
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Result deleted successfully'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                      ),
                      const Icon(Icons.expand_more_rounded),
                    ],
                  ),
                  children: [
                    const Divider(height: 1),
                    ...r.subjects.map((s) => ListTile(
                      title: Text(s.subjectName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      trailing: Text('${s.marks.toInt()}/${s.totalMarks.toInt()} (${s.grade})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E3A8A))),
                      dense: true,
                    )),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (student != null)
                              TextButton.icon(
                                onPressed: () async {
                                  await Navigator.push(
                                    ctx,
                                    MaterialPageRoute(
                                      builder: (_) => StudentResultDetailScreen(
                                        student: student,
                                        result: r,
                                      ),
                                    ),
                                  );
                                  _refresh();
                                },
                                icon: const Icon(Icons.visibility_outlined, size: 18),
                                label: const Text('View Report'),
                              ),
                            const SizedBox(width: 6),
                            TextButton.icon(
                              onPressed: () async {
                                if (student != null) {
                                  final saved = await Navigator.push<ResultModel>(
                                    ctx,
                                    MaterialPageRoute(
                                      builder: (_) => StudentMarkEntryScreen(
                                        student: student,
                                        editResult: r,
                                      ),
                                    ),
                                  );
                                  if (saved != null) {
                                    _refresh();
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).clearSnackBars();
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          duration: const Duration(seconds: 2),
                                          behavior: SnackBarBehavior.floating,
                                          margin: const EdgeInsets.all(16),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          content: Text('✓ Marksheet updated for ${student.name}!'),
                                          backgroundColor: Colors.green.shade700,
                                        ),
                                      );
                                    }
                                  }
                                } else {
                                  await Navigator.push(
                                    ctx,
                                    MaterialPageRoute(
                                      builder: (_) => ResultScreen(studentId: widget.studentId),
                                    ),
                                  );
                                  _refresh();
                                }
                              },
                              icon: const Icon(Icons.edit_note_rounded, size: 18),
                              label: const Text('Edit Marks'),
                            ),
                            const SizedBox(width: 6),
                            TextButton.icon(
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: ctx,
                                  builder: (dCtx) => AlertDialog(
                                    title: const Text('Delete Result?'),
                                    content: Text('Are you sure you want to delete the result for "${r.examName}"?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(dCtx, true),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await DatabaseService.instance.deleteResult(r.id);
                                  _refresh();
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(content: Text('Result deleted successfully'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              label: const Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                            const SizedBox(width: 6),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D9488),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () async {
                                if (student != null) {
                                  try {
                                    final path = await ResultPdfService.instance.saveResultPdfToDevice(
                                      result: r,
                                      student: student,
                                      settings: settings,
                                    );
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).clearSnackBars();
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          duration: const Duration(seconds: 2),
                                          behavior: SnackBarBehavior.floating,
                                          margin: const EdgeInsets.all(16),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          content: Text('✓ Saved: '),
                                          backgroundColor: Colors.green.shade700,
                                          action: SnackBarAction(
                                            label: 'Share',
                                            textColor: Colors.white,
                                            onPressed: () {
                                              ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
                                              Share.shareXFiles([XFile(path)], text: 'Marksheet - ');
                                            },
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(content: Text('Error saving PDF: $e'), backgroundColor: Colors.red),
                                      );
                                    }
                                  }
                                }
                              },
                              icon: const Icon(Icons.download_rounded, size: 15),
                              label: const Text('Save PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 6),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E3A8A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () async {
                                if (student != null) {
                                  await ResultPdfService.instance.printOrShareResultPdf(
                                    result: r,
                                    student: student,
                                    settings: settings,
                                  );
                                }
                              },
                              icon: const Icon(Icons.print_rounded, size: 15),
                              label: const Text('Print', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          ],
        );
      },
    );
  }
}

class _BottomActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? highlightColor;

  const _BottomActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final isCustom = highlightColor != null;
    final bgColor = isCustom ? highlightColor!.withOpacity(0.12) : cs.surface;
    final fgColor = isCustom ? highlightColor! : cs.onSurface;
    final borderColor = isCustom ? highlightColor!.withOpacity(0.35) : cs.outline;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: isCustom ? 1.4 : 1.2),
          boxShadow: isCustom
              ? [BoxShadow(color: highlightColor!.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fgColor, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: fgColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── FULL REPORT BOTTOM SHEET MODAL ──────────────────────────────────────────

class _FullReportModal extends StatefulWidget {
  final StudentModel student;
  final WidgetRef ref;

  const _FullReportModal({required this.student, required this.ref});

  @override
  State<_FullReportModal> createState() => _FullReportModalState();
}

class _FullReportModalState extends State<_FullReportModal> {
  bool _isLoading = true;
  bool _isActionRunning = false;
  String _actionMessage = '';

  String _selectedMonth = 'all'; // 'all' or 'yyyy-MM'
  FeeModel? _fee;
  List<PaymentModel> _payments = [];
  Map<String, dynamic> _attendance = {};
  List<ResultModel> _results = [];
  SettingsModel _settings = SettingsModel.defaultSettings();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final fee = await DatabaseService.instance.getFeeByStudentId(widget.student.id);
      final attList = await DatabaseService.instance.getAttendanceByStudentId(widget.student.id);
      final attMap = <String, dynamic>{};
      for (final a in attList) {
        final key = DateFormat('yyyy-MM-dd').format(a.date);
        attMap[key] = a.status;
      }
      final res = await DatabaseService.instance.getResultsByStudentId(widget.student.id);
      final sett = widget.ref.read(settingsProvider).value ?? SettingsModel.defaultSettings();

      if (mounted) {
        setState(() {
          _fee = fee;
          _payments = fee?.payments ?? [];
          _attendance = attMap;
          _results = res;
          _settings = sett;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<({String key, String label})> _getMonthOptions() {
    final list = <({String key, String label})>[
      (key: 'all', label: 'All Time (Lifetime)'),
    ];

    final now = DateTime.now();
    for (int i = 0; i < 6; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      final key = DateFormat('yyyy-MM').format(d);
      final label = DateFormat('MMM yyyy').format(d);
      list.add((key: key, label: label));
    }
    return list;
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _handlePdfPrint() async {
    setState(() {
      _isActionRunning = true;
      _actionMessage = 'Generating official PDF statement...';
    });
    try {
      await StudentFullReportService.instance.printReport(
        student: widget.student,
        payments: _payments,
        attendance: _attendance,
        results: _results,
        settings: _settings,
        monthFilter: _selectedMonth,
      );
    } catch (e) {
      _showError('PDF Error: $e');
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  Future<void> _handleExcelExport() async {
    setState(() {
      _isActionRunning = true;
      _actionMessage = 'Exporting complete Excel sheet...';
    });
    try {
      await StudentFullReportService.instance.exportExcel(
        context,
        student: widget.student,
        payments: _payments,
        attendance: _attendance,
        results: _results,
        settings: _settings,
        monthFilter: _selectedMonth,
      );
    } catch (e) {
      _showError('Excel Error: $e');
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  Future<void> _handleWhatsAppShare() async {
    setState(() {
      _isActionRunning = true;
      _actionMessage = 'Preparing WhatsApp statement...';
    });
    try {
      await StudentFullReportService.instance.shareWhatsApp(
        context,
        student: widget.student,
        payments: _payments,
        attendance: _attendance,
        results: _results,
        settings: _settings,
        monthFilter: _selectedMonth,
      );
    } catch (e) {
      _showError('WhatsApp Error: $e');
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  Future<void> _handlePdfShare() async {
    setState(() {
      _isActionRunning = true;
      _actionMessage = 'Sharing PDF document...';
    });
    try {
      await StudentFullReportService.instance.shareReport(
        student: widget.student,
        payments: _payments,
        attendance: _attendance,
        results: _results,
        settings: _settings,
        monthFilter: _selectedMonth,
      );
    } catch (e) {
      _showError('Share Error: $e');
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Container(
        height: 280,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: const Center(
          child: LoadingWidget(message: 'Loading student statement data...'),
        ),
      );
    }

    final filtered = StudentFullReportService.instance.filterData(
      allPayments: _payments,
      allAttendance: _attendance,
      allResults: _results,
      monthFilter: _selectedMonth,
    );

    final totalFee = (_fee != null && _fee!.totalFees > 0)
        ? _fee!.totalFees
        : (widget.student.totalFees > 0 ? widget.student.totalFees : 0.0);
    double paidFee = 0.0;
    for (final p in filtered.payments) {
      paidFee += (p as PaymentModel).amount;
    }
    final remainingDue = (totalFee - paidFee).clamp(0.0, double.infinity);

    int totalMarked = 0, present = 0;
    filtered.attendance.forEach((_, val) {
      String status = '';
      if (val is Map) {
        status = (val[widget.student.id] ?? val[widget.student.studentId] ?? '').toString().toLowerCase();
      } else if (val is String) {
        status = val.toLowerCase();
      }
      if (status.isNotEmpty) {
        totalMarked++;
        if (status == 'present') present++;
      }
    });
    final attPct = totalMarked > 0 ? ((present / totalMarked) * 100).toStringAsFixed(1) : '0.0';

    final monthOptions = _getMonthOptions();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: cs.outlineVariant.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),

            // Header title
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 12, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.assessment_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Student Full Report Statement',
                          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${widget.student.name} (${widget.student.studentId})',
                          style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content body
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  // Month Filter Section
                  Row(
                    children: [
                      const Icon(Icons.filter_list_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Select Statement Period:',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: monthOptions.map((opt) {
                        final isSel = _selectedMonth == opt.key;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(opt.label),
                            selected: isSel,
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: isSel ? Colors.white : cs.onSurface,
                              fontSize: 12,
                              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                            ),
                            backgroundColor: cs.surfaceVariant.withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSel ? AppColors.primary : cs.outlineVariant,
                              ),
                            ),
                            onSelected: (val) {
                              if (val) {
                                setState(() => _selectedMonth = opt.key);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Metrics Summary Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surfaceVariant.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          filtered.filterLabel,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary.withOpacity(0.85),
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _summaryStat(
                                'Total Fees',
                                '₹${totalFee.toStringAsFixed(0)}',
                                Colors.indigo,
                              ),
                            ),
                            Expanded(
                              child: _summaryStat(
                                'Paid Fees',
                                '₹${paidFee.toStringAsFixed(0)}',
                                Colors.green.shade700,
                              ),
                            ),
                            Expanded(
                              child: _summaryStat(
                                'Remaining Due',
                                '₹${remainingDue.toStringAsFixed(0)}',
                                remainingDue > 0 ? Colors.red.shade700 : Colors.green.shade700,
                                isBold: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _summaryStat(
                                'Attendance',
                                '$attPct% ($present/$totalMarked)',
                                Colors.teal.shade700,
                              ),
                            ),
                            Expanded(
                              child: _summaryStat(
                                'Receipts',
                                '${filtered.payments.length}',
                                Colors.blueGrey,
                              ),
                            ),
                            Expanded(
                              child: _summaryStat(
                                'Results',
                                '${filtered.results.length}',
                                Colors.purple.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  if (_isActionRunning) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              _actionMessage,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Action Buttons Grid / List
                  // 1. PDF Print / Download
                  _ReportActionTile(
                    icon: Icons.print_rounded,
                    title: 'Print / Save Official PDF',
                    subtitle: 'Full marksheet, ledger table, digital signature & logo',
                    color: AppColors.primary,
                    enabled: !_isActionRunning,
                    onTap: _handlePdfPrint,
                  ),
                  const SizedBox(height: 10),

                  // 2. Excel Export
                  _ReportActionTile(
                    icon: Icons.table_chart_rounded,
                    title: 'Export Excel Workbook (.xlsx)',
                    subtitle: 'Multi-sheet export with Summary, Ledger, Attendance & Results',
                    color: const Color(0xFF0D9488),
                    enabled: !_isActionRunning,
                    onTap: _handleExcelExport,
                  ),
                  const SizedBox(height: 10),

                  // 3. WhatsApp Share
                  _ReportActionTile(
                    icon: Icons.chat_rounded,
                    title: 'Share via WhatsApp',
                    subtitle: 'Send formatted performance & fee summary to parent phone',
                    color: const Color(0xFF25D366),
                    enabled: !_isActionRunning,
                    onTap: _handleWhatsAppShare,
                  ),
                  const SizedBox(height: 10),

                  // 4. Share PDF Document
                  _ReportActionTile(
                    icon: Icons.share_rounded,
                    title: 'Share PDF File',
                    subtitle: 'Send generated statement file via Bluetooth, Email or Drive',
                    color: Colors.blueGrey.shade800,
                    enabled: !_isActionRunning,
                    onTap: _handlePdfShare,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryStat(String label, String value, Color color, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ReportActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _ReportActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.35), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}