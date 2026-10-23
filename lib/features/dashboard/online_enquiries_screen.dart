import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/settings_model.dart';
import '../../data/services/firestore_service.dart';
import '../../data/services/providers.dart';
import '../students/add_student_screen.dart';
import '../whatsapp/whatsapp_service.dart';

class OnlineEnquiriesScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  const OnlineEnquiriesScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<OnlineEnquiriesScreen> createState() => _OnlineEnquiriesScreenState();
}

class _OnlineEnquiriesScreenState extends ConsumerState<OnlineEnquiriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedStatus = 'all'; // 'all', 'pending', 'contacted', 'enrolled', 'approved'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── Launcher Helpers ──────────────────────────────────────────────────

  Future<void> _makePhoneCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number available')),
      );
      return;
    }
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot dial: $clean')),
        );
      }
    }
  }

  Future<void> _openWhatsAppChat(String phone, String studentOrTeacherName, bool isTeacher, String refNo) async {
    final formattedPhone = WhatsAppService.formatPhone(phone);
    if (formattedPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid phone number for WhatsApp')),
      );
      return;
    }

    final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
    final schoolName = settings.instituteName.isNotEmpty ? settings.instituteName : 'MNP School';

    final message = isTeacher
        ? 'Hello $studentOrTeacherName,\n\nWe received your job application (Ref: $refNo) for teaching at $schoolName. We would like to schedule an interview with you. Please let us know your availability.\n\nRegards,\n$schoolName Administration'
        : 'Namaste,\n\nRegarding the online admission enquiry (Ref: $refNo) for your child "$studentOrTeacherName" at $schoolName. We are glad to inform you that seats are currently open. Please visit the school office or contact us for completing admission formalities.\n\nRegards,\n$schoolName Admissions Desk';

    final uri = Uri.parse('https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open WhatsApp: $e')),
        );
      }
    }
  }

  // ─── Build Method ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Online Enquiries Desk',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Text(
              'Website Admissions & Recruitment',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(105),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() {}),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search by student, teacher, class, mobile, ref...',
                      hintStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                      prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 18),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white70, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),

              // Tab Bar with Live Stream Counters
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.amberAccent,
                indicatorWeight: 3.5,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.school_rounded, size: 18),
                        const SizedBox(width: 8),
                        const Text('Admissions'),
                        const SizedBox(width: 6),
                        _buildBadge(isTeacher: false),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.badge_rounded, size: 18),
                        const SizedBox(width: 8),
                        const Text('Faculty'),
                        const SizedBox(width: 6),
                        _buildBadge(isTeacher: true),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Container(
            color: cs.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('All Status', _selectedStatus == 'all', () {
                    setState(() => _selectedStatus = 'all');
                  }),
                  const SizedBox(width: 8),
                  _filterChip('Pending Only', _selectedStatus == 'pending', () {
                    setState(() => _selectedStatus = _selectedStatus == 'pending' ? 'all' : 'pending');
                  }, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  _filterChip('Contacted', _selectedStatus == 'contacted', () {
                    setState(() => _selectedStatus = _selectedStatus == 'contacted' ? 'all' : 'contacted');
                  }, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  _filterChip('Enrolled / Approved', _selectedStatus == 'approved' || _selectedStatus == 'enrolled', () {
                    setState(() => _selectedStatus = (_selectedStatus == 'approved' || _selectedStatus == 'enrolled') ? 'all' : 'approved');
                  }, color: Colors.green.shade700),
                ],
              ),
            ),
          ),

          // Tab Bar Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAdmissionsList(),
                _buildFacultyList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Live Count Badge in Tab ───────────────────────────────────────────

  Widget _buildBadge({required bool isTeacher}) {
    final stream = isTeacher
        ? FirestoreService.instance.watchTeacherApplications()
        : FirestoreService.instance.watchAdmissionEnquiries();

    if (stream == null) return const SizedBox.shrink();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final count = snapshot.data!.where((item) {
          final s = (item['status'] ?? 'pending').toString().toLowerCase();
          return s == 'pending';
        }).length;

        if (count == 0) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }

  Widget _filterChip(String label, bool isSelected, VoidCallback onTap, {Color? color}) {
    final activeColor = color ?? AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.12) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? activeColor : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  // ─── TAB 1: Student Admissions List ────────────────────────────────────

  Widget _buildAdmissionsList() {
    final stream = FirestoreService.instance.watchAdmissionEnquiries();
    if (stream == null) {
      return const Center(child: Text('Firestore is offline or not configured'));
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final rawList = snapshot.data ?? [];
        final query = _searchCtrl.text.toLowerCase().trim();

        final filtered = rawList.where((item) {
          final status = (item['status'] ?? 'pending').toString().toLowerCase();
          if (_selectedStatus != 'all') {
            if (_selectedStatus == 'approved' && status != 'approved' && status != 'enrolled') {
              return false;
            } else if (_selectedStatus != 'approved' && status != _selectedStatus) {
              return false;
            }
          }

          if (query.isNotEmpty) {
            final name = (item['studentName'] ?? '').toString().toLowerCase();
            final father = (item['fatherName'] ?? '').toString().toLowerCase();
            final phone = (item['mobile'] ?? '').toString().toLowerCase();
            final cls = (item['admissionClass'] ?? '').toString().toLowerCase();
            final refNo = (item['refNo'] ?? '').toString().toLowerCase();
            return name.contains(query) ||
                father.contains(query) ||
                phone.contains(query) ||
                cls.contains(query) ||
                refNo.contains(query);
          }
          return true;
        }).toList();

        if (filtered.isEmpty) {
          return _buildEmptyState(
            icon: Icons.school_outlined,
            title: 'No Admission Enquiries Found',
            subtitle: query.isNotEmpty || _selectedStatus != 'all'
                ? 'Try clearing the search query or status filter.'
                : 'All admission enquiries submitted through the school website will appear here in real-time.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = filtered[index];
            return _buildAdmissionCard(item);
          },
        );
      },
    );
  }

  Widget _buildAdmissionCard(Map<String, dynamic> item) {
    final refNo = item['refNo'] ?? 'MNP-ADM';
    final studentName = item['studentName'] ?? item['name'] ?? 'Candidate';
    final fatherName = item['fatherName'] ?? '';
    final admClass = item['admissionClass'] ?? 'N/A';
    final mobile = item['mobile'] ?? '';
    final address = item['address'] ?? '';
    final gender = item['gender'] ?? 'Male';
    final busRequired = item['transportRequired'] == 'Yes';
    final status = (item['status'] ?? 'pending').toString().toLowerCase();
    final submittedAtStr = item['submittedAt']?.toString() ?? '';

    String dateDisplay = 'Recently';
    if (submittedAtStr.isNotEmpty) {
      try {
        final dt = DateTime.parse(submittedAtStr);
        dateDisplay = DateFormat('dd MMM yyyy, hh:mm a').format(dt);
      } catch (_) {}
    }

    Color statusColor = Colors.amber.shade700;
    Color statusBg = Colors.amber.shade50;
    String statusLabel = 'PENDING';
    if (status == 'contacted') {
      statusColor = Colors.blue.shade700;
      statusBg = Colors.blue.shade50;
      statusLabel = 'CONTACTED';
    } else if (status == 'approved' || status == 'enrolled') {
      statusColor = Colors.green.shade700;
      statusBg = Colors.green.shade50;
      statusLabel = 'ENROLLED';
    } else if (status == 'rejected') {
      statusColor = Colors.red.shade700;
      statusBg = Colors.red.shade50;
      statusLabel = 'REJECTED';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Ref No, Status Chip, Date, and Menu
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    refNo,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: statusColor),
                  ),
                ),
                if (busRequired) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_bus_rounded, size: 12, color: Colors.orange.shade800),
                        const SizedBox(width: 3),
                        Text(
                          'Bus',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  dateDisplay,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (val) {
                    if (val == 'delete') {
                      _confirmDelete(refNo, isTeacher: false);
                    } else {
                      FirestoreService.instance.updateAdmissionEnquiryStatus(refNo, val);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'pending', child: Text('Mark Pending')),
                    const PopupMenuItem(value: 'contacted', child: Text('Mark Contacted')),
                    const PopupMenuItem(value: 'enrolled', child: Text('Mark Enrolled')),
                    const PopupMenuItem(value: 'rejected', child: Text('Mark Rejected')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete Enquiry', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Middle: Student Info
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.person, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Class: $admClass · Gender: $gender',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                      ),
                      if (fatherName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Father: $fatherName',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Address: $address',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Bottom Actions: Call, WhatsApp, Enroll
            Row(
              children: [
                // Call Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _makePhoneCall(mobile),
                    icon: const Icon(Icons.phone_rounded, size: 16),
                    label: const Text('Call', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // WhatsApp Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openWhatsAppChat(mobile, studentName, false, refNo),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                    label: const Text('WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Enroll Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _enrollStudent(item),
                    icon: const Icon(Icons.how_to_reg_rounded, size: 16),
                    label: const Text('Enroll', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── TAB 2: Faculty Applications List ──────────────────────────────────

  Widget _buildFacultyList() {
    final stream = FirestoreService.instance.watchTeacherApplications();
    if (stream == null) {
      return const Center(child: Text('Firestore is offline or not configured'));
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final rawList = snapshot.data ?? [];
        final query = _searchCtrl.text.toLowerCase().trim();

        final filtered = rawList.where((item) {
          final status = (item['status'] ?? 'pending').toString().toLowerCase();
          if (_selectedStatus != 'all') {
            if (_selectedStatus == 'approved' && status != 'approved') {
              return false;
            } else if (_selectedStatus != 'approved' && status != _selectedStatus) {
              return false;
            }
          }

          if (query.isNotEmpty) {
            final name = (item['teacherName'] ?? item['name'] ?? '').toString().toLowerCase();
            final subject = (item['subjectSpecialization'] ?? '').toString().toLowerCase();
            final phone = (item['mobile'] ?? '').toString().toLowerCase();
            final qual = (item['highestDegree'] ?? '').toString().toLowerCase();
            final refNo = (item['refNo'] ?? '').toString().toLowerCase();
            return name.contains(query) ||
                subject.contains(query) ||
                phone.contains(query) ||
                qual.contains(query) ||
                refNo.contains(query);
          }
          return true;
        }).toList();

        if (filtered.isEmpty) {
          return _buildEmptyState(
            icon: Icons.badge_outlined,
            title: 'No Teacher Applications Found',
            subtitle: query.isNotEmpty || _selectedStatus != 'all'
                ? 'Try clearing the search query or status filter.'
                : 'All job applications submitted through the "Join as Faculty" form on the website will appear here in real-time.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = filtered[index];
            return _buildTeacherCard(item);
          },
        );
      },
    );
  }

  Widget _buildTeacherCard(Map<String, dynamic> item) {
    final refNo = item['refNo'] ?? 'MNP-FAC';
    final teacherName = item['teacherName'] ?? item['name'] ?? 'Faculty Candidate';
    final subject = item['subjectSpecialization'] ?? 'All Subjects';
    final wing = item['preferredWing'] ?? 'PRT';
    final degree = item['highestDegree'] ?? 'Graduate';
    final experience = item['experience'] ?? 'Fresher';
    final passingYear = item['passingYear'] ?? '';
    final tetStatus = item['tetStatus'];
    final mobile = item['mobile'] ?? '';
    final gender = item['gender'] ?? 'Female';
    final status = (item['status'] ?? 'pending').toString().toLowerCase();
    final submittedAtStr = item['submittedAt']?.toString() ?? '';

    String dateDisplay = 'Recently';
    if (submittedAtStr.isNotEmpty) {
      try {
        final dt = DateTime.parse(submittedAtStr);
        dateDisplay = DateFormat('dd MMM yyyy, hh:mm a').format(dt);
      } catch (_) {}
    }

    Color statusColor = Colors.amber.shade700;
    Color statusBg = Colors.amber.shade50;
    String statusLabel = 'PENDING';
    if (status == 'contacted') {
      statusColor = Colors.blue.shade700;
      statusBg = Colors.blue.shade50;
      statusLabel = 'INTERVIEWED';
    } else if (status == 'approved') {
      statusColor = Colors.green.shade700;
      statusBg = Colors.green.shade50;
      statusLabel = 'APPROVED';
    } else if (status == 'rejected') {
      statusColor = Colors.red.shade700;
      statusBg = Colors.red.shade50;
      statusLabel = 'REJECTED';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    refNo,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: statusColor),
                  ),
                ),
                if (tetStatus != null && tetStatus.toString().isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF6EE7B7)),
                    ),
                    child: Text(
                      tetStatus.toString(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF065F46)),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  dateDisplay,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (val) {
                    if (val == 'delete') {
                      _confirmDelete(refNo, isTeacher: true);
                    } else {
                      FirestoreService.instance.updateTeacherApplicationStatus(refNo, val);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'pending', child: Text('Mark Pending')),
                    const PopupMenuItem(value: 'contacted', child: Text('Mark Interviewed')),
                    const PopupMenuItem(value: 'approved', child: Text('Mark Approved')),
                    const PopupMenuItem(value: 'rejected', child: Text('Mark Rejected')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete Application', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Middle: Teacher Info
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.indigo.shade50,
                  child: Icon(Icons.school, color: Colors.indigo.shade700, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacherName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Subject: $subject ($wing) · $gender',
                        style: TextStyle(fontSize: 12, color: Colors.indigo.shade800, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Qualification: $degree ${passingYear.isNotEmpty ? "($passingYear)" : ""} · $experience',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      if (mobile.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Mobile: $mobile',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'monospace'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Bottom Actions: Call, WhatsApp, Add to Faculty
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _makePhoneCall(mobile),
                    icon: const Icon(Icons.phone_rounded, size: 16),
                    label: const Text('Call', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openWhatsAppChat(mobile, teacherName, true, refNo),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                    label: const Text('WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                        text: 'Teacher: $teacherName\nSubject: $subject\nQualification: $degree\nMobile: $mobile\nExperience: $experience',
                      ));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Candidate details copied! Open Faculty directory to register.')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy Info', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade700,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Enroll Student Action ─────────────────────────────────────────────

  void _enrollStudent(Map<String, dynamic> item) async {
    final refNo = item['refNo']?.toString() ?? '';
    final studentName = item['studentName']?.toString() ?? 'Candidate';

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddStudentScreen(initialData: item),
      ),
    );

    // Prompt user to update status if enrolled
    if (mounted && refNo.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Mark Enquiry as Enrolled?'),
          content: Text('Would you like to update the online enquiry for "$studentName" ($refNo) to "Enrolled"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep Pending'),
            ),
            ElevatedButton(
              onPressed: () {
                FirestoreService.instance.updateAdmissionEnquiryStatus(refNo, 'enrolled');
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Enquiry $refNo marked as Enrolled!')),
                );
              },
              child: const Text('Mark Enrolled'),
            ),
          ],
        ),
      );
    }
  }

  // ─── Delete Confirmation ───────────────────────────────────────────────

  void _confirmDelete(String refNo, {required bool isTeacher}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text('Are you sure you want to delete enquiry "$refNo"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              if (isTeacher) {
                FirestoreService.instance.deleteTeacherApplication(refNo);
              } else {
                FirestoreService.instance.deleteAdmissionEnquiry(refNo);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Deleted successfully')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
