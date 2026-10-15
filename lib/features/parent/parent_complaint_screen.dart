import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/student_model.dart';
import '../../data/models/settings_model.dart';
import '../../data/services/session_service.dart';

class ParentComplaintScreen extends StatefulWidget {
  final StudentModel student;
  final SettingsModel? settings;
  final bool isDarkMode;

  const ParentComplaintScreen({
    super.key,
    required this.student,
    this.settings,
    this.isDarkMode = false,
  });

  @override
  State<ParentComplaintScreen> createState() => _ParentComplaintScreenState();
}

class _ParentComplaintScreenState extends State<ParentComplaintScreen> {
  String _selectedFilter = 'all'; // 'all', 'pending', 'resolved'
  List<Map<String, dynamic>> _localComplaints = [];

  @override
  void initState() {
    super.initState();
    _loadLocalComplaints();
  }

  String get _localPrefsKey => 'parent_complaints_${widget.student.id}';

  Future<void> _loadLocalComplaints() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localPrefsKey);
      if (raw != null) {
        final List list = jsonDecode(raw);
        setState(() {
          _localComplaints = list.map((e) => Map<String, dynamic>.from(e)).toList();
        });
        return;
      }
    } catch (_) {}
  }

  Future<void> _saveLocalComplaint(Map<String, dynamic> item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _localComplaints.insert(0, item);
      await prefs.setString(_localPrefsKey, jsonEncode(_localComplaints));
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _openNewComplaintSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NewComplaintBottomSheet(
        student: widget.student,
        settings: widget.settings,
        isDarkMode: widget.isDarkMode,
        onSubmitted: (data) {
          _saveLocalComplaint(data);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Message sent to Principal successfully!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Message to Principal',
              style: TextStyle(
                color: textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Direct desk of Principal / Administration',
              style: TextStyle(
                color: textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_rounded, color: AppColors.primary),
            tooltip: 'New Complaint / Message',
            onPressed: _openNewComplaintSheet,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewComplaintSheet,
        backgroundColor: const Color(0xFF1E3A8A),
        icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
        label: const Text(
          'New Complaint',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('feedbacks')
            .where('studentId', isEqualTo: widget.student.id)
            .snapshots(),
        builder: (context, snapshot) {
          // Merge Firestore docs and local cache
          final Map<String, Map<String, dynamic>> combined = {};

          // Add local ones first
          for (final item in _localComplaints) {
            final id = item['docId'] ?? item['id'] ?? '';
            if (id.isNotEmpty) combined[id] = item;
          }

          // Merge Firestore data
          if (snapshot.hasData) {
            for (final doc in snapshot.data!.docs) {
              final d = Map<String, dynamic>.from(doc.data() as Map);
              d['docId'] = doc.id;
              combined[doc.id] = d;
            }
          }

          final allList = combined.values.toList();
          allList.sort((a, b) {
            final tA = a['createdAt']?.toString() ?? a['date']?.toString() ?? '';
            final tB = b['createdAt']?.toString() ?? b['date']?.toString() ?? '';
            return tB.compareTo(tA);
          });

          // Apply filter
          final filtered = allList.where((item) {
            final st = (item['status'] ?? 'new').toString().toLowerCase();
            if (_selectedFilter == 'pending') return st != 'resolved';
            if (_selectedFilter == 'resolved') return st == 'resolved';
            return true;
          }).toList();

          final pendingCount = allList.where((e) => (e['status'] ?? 'new') != 'resolved').length;
          final resolvedCount = allList.where((e) => (e['status'] ?? 'new') == 'resolved').length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              // Hero Info Banner
              _buildTopBanner(cardBg, cardBorder, textPrimary, textSecondary),
              const SizedBox(height: 14),

              // Filter Tabs
              _buildFilterChips(allList.length, pendingCount, resolvedCount, isDark),
              const SizedBox(height: 14),

              if (filtered.isEmpty)
                _buildEmptyState(textPrimary, textSecondary, cardBg, cardBorder)
              else
                ...filtered.map((item) => _buildComplaintCard(
                      item,
                      cardBg,
                      cardBorder,
                      textPrimary,
                      textSecondary,
                    )),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopBanner(Color cardBg, Color cardBorder, Color textPrimary, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.isDarkMode
              ? [const Color(0xFF1E1B4B), const Color(0xFF1E3A8A)]
              : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.isDarkMode ? const Color(0xFF3B82F6).withValues(alpha: 0.3) : const Color(0xFFBFDBFE),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Principal Help & Complaint Desk',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: widget.isDarkMode ? Colors.white : const Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Send complaints or inquiries directly to the Principal. Your message is private and official.',
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isDarkMode ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(int total, int pending, int resolved, bool isDark) {
    if (total <= 1) return const SizedBox.shrink();
    final filters = [
      {'id': 'all', 'label': 'All Messages ($total)'},
      {'id': 'pending', 'label': 'Pending ($pending)'},
      {'id': 'resolved', 'label': 'Resolved ($resolved)'},
    ];

    return Row(
      children: filters.map((f) {
        final isSel = _selectedFilter == f['id'];
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            onTap: () => setState(() => _selectedFilter = f['id'] as String),
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isSel
                    ? AppColors.primary
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSel
                      ? AppColors.primary
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Text(
                f['label'] as String,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSel ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState(Color textPrimary, Color textSecondary, Color cardBg, Color cardBorder) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            'No Messages or Complaints Yet',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'If you have any feedback, concern about studies, fee, or bus service, tap "New Complaint" below.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openNewComplaintSheet,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Send Message to Principal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintCard(
    Map<String, dynamic> item,
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
  ) {
    final category = item['category'] ?? 'General Inquiry';
    final subject = item['subject'] ?? 'Message to Principal';
    final message = item['message'] ?? '';
    final status = (item['status'] ?? 'new').toString().toLowerCase();
    final isResolved = status == 'resolved';
    final reply = item['reply'] ?? item['adminReply'] ?? '';
    final dateStr = item['date'] ?? item['createdAt']?.toString() ?? 'Recent';
    final isUrgent = item['priority'] == 'urgent' || item['urgent'] == true;

    Color catColor = const Color(0xFF3B82F6);
    if (category.toString().contains('Academic') || category.toString().contains('पढ़ाई')) {
      catColor = const Color(0xFF8B5CF6);
    } else if (category.toString().contains('Fee') || category.toString().contains('फीस')) {
      catColor = const Color(0xFF10B981);
    } else if (category.toString().contains('Bus') || category.toString().contains('Transport')) {
      catColor = const Color(0xFFF59E0B);
    } else if (category.toString().contains('Discipline')) {
      catColor = const Color(0xFFEF4444);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isResolved ? const Color(0xFF10B981).withValues(alpha: 0.4) : cardBorder,
          width: isResolved ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDarkMode ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Badge + Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: catColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(color: catColor, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (isUrgent) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'URGENT',
                        style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isResolved
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isResolved ? Icons.check_circle_rounded : Icons.schedule_rounded,
                      size: 11,
                      color: isResolved ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isResolved ? 'Resolved' : 'Under Review',
                      style: TextStyle(
                        color: isResolved ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Subject Title
          Text(
            subject,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textPrimary),
          ),
          const SizedBox(height: 5),

          // Message Body
          Text(
            message,
            style: TextStyle(fontSize: 12, color: textSecondary, height: 1.4),
          ),
          const SizedBox(height: 10),

          // Date & Time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sent: $dateStr',
                style: TextStyle(fontSize: 10, color: textSecondary.withValues(alpha: 0.7)),
              ),
              Text(
                'Student: ${widget.student.name} (Class ${widget.student.className})',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textSecondary),
              ),
            ],
          ),

          // Principal's Official Reply Banner
          if (reply.toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isDarkMode ? const Color(0xFF0F2B5C) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified_rounded, color: Color(0xFF3B82F6), size: 14),
                      SizedBox(width: 5),
                      Text(
                        'Principal Office Reply',
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reply.toString(),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: widget.isDarkMode ? Colors.white : const Color(0xFF1E3A8A),
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── NEW COMPLAINT BOTTOM SHEET ──────────────────────────────────────────────

class _NewComplaintBottomSheet extends StatefulWidget {
  final StudentModel student;
  final SettingsModel? settings;
  final bool isDarkMode;
  final ValueChanged<Map<String, dynamic>> onSubmitted;

  const _NewComplaintBottomSheet({
    required this.student,
    this.settings,
    required this.isDarkMode,
    required this.onSubmitted,
  });

  @override
  State<_NewComplaintBottomSheet> createState() => _NewComplaintBottomSheetState();
}

class _NewComplaintBottomSheetState extends State<_NewComplaintBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  String _selectedCategory = 'Academic & Studies (पढ़ाई संबंधी)';
  bool _isUrgent = false;
  bool _submitting = false;

  final List<String> _categories = [
    'Academic & Studies (पढ़ाई संबंधी)',
    'Fees & Accounts (फीस व रसीद संबंधी)',
    'Bus & Transport (बस व वाहन संबंधी)',
    'Discipline & Behavior (अनुशासन संबंधी)',
    'School Facilities & Hygiene (व्यवस्था व स्वच्छता)',
    'Direct Message to Principal (प्रधानाचार्य को सीधा संदेश)',
    'Other Concern (अन्य शिकायत या सुझाव)',
  ];

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final now = DateTime.now();
      final dateFormatted = DateFormat('dd MMM yyyy, hh:mm a').format(now);
      final docId = 'complaint_${now.millisecondsSinceEpoch}_${widget.student.admissionNumber}';
      final schoolId = SessionService.instance.activeSchoolId;
      final schoolName = widget.settings?.instituteName ?? 'Mission Navodaya Public School';

      final parentName = widget.student.fatherName.isNotEmpty
          ? widget.student.fatherName
          : (widget.student.motherName?.isNotEmpty == true ? widget.student.motherName! : 'Parent');
      final parentMobile = widget.student.mobile;

      final payload = {
        'docId': docId,
        'id': docId,
        'category': _selectedCategory,
        'subject': _subjectCtrl.text.trim(),
        'message': _messageCtrl.text.trim(),
        'priority': _isUrgent ? 'urgent' : 'normal',
        'urgent': _isUrgent,
        'status': 'new',
        'type': 'parent_complaint',
        'device': 'android',
        'studentId': widget.student.id,
        'studentName': widget.student.name,
        'className': widget.student.className,
        'section': widget.student.section ?? 'A',
        'rollNo': widget.student.rollNumber ?? '',
        'admissionNo': widget.student.admissionNumber,
        'senderName': '$parentName (Parent of ${widget.student.name})',
        'senderPhone': parentMobile,
        'senderEmail': 'parent_${widget.student.admissionNumber}@mnpschool.edu',
        'parentMobile': parentMobile,
        'schoolId': schoolId,
        'schoolName': schoolName,
        'date': dateFormatted,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 1. Write to global feedbacks (consumed by school-admin live stream)
      await FirebaseFirestore.instance
          .collection('feedbacks')
          .doc(docId)
          .set(payload)
          .catchError((_) {});

      // 2. Dual write to system_feedbacks items
      await FirebaseFirestore.instance
          .collection('schoolDirectory')
          .doc('system_feedbacks')
          .collection('items')
          .doc(docId)
          .set(payload)
          .catchError((_) {});

      // 3. Write to school complaints collection
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('complaints')
          .doc(docId)
          .set(payload)
          .catchError((_) {});

      if (mounted) {
        widget.onSubmitted(payload);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission notice: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final inputBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Drag Bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.mark_email_unread_rounded, color: AppColors.primary, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Send Message to Principal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textSecondary, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              Text(
                'Student: ${widget.student.name} • Class ${widget.student.className} (Adm: ${widget.student.admissionNumber})',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(height: 16),

              // Category Dropdown
              Text(
                'Select Topic / Category',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: inputBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    dropdownColor: bg,
                    style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedCategory = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Subject Field
              Text(
                'Subject / विषय',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _subjectCtrl,
                style: TextStyle(color: textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g. Inquiry regarding bus timing / Fee issue',
                  hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 12),
                  filled: true,
                  fillColor: inputBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: inputBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: inputBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter subject';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Message Details Field
              Text(
                'Detailed Complaint / Message',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _messageCtrl,
                maxLines: 4,
                style: TextStyle(color: textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Type your message or complaint in detail here. The Principal office will review and take appropriate action.',
                  hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 12),
                  filled: true,
                  fillColor: inputBg,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: inputBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: inputBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 5) {
                    return 'Please enter at least 5 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Urgent Switch
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.priority_high_rounded, color: _isUrgent ? Colors.redAccent : textSecondary, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Mark as Urgent Priority',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _isUrgent ? Colors.redAccent : textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isUrgent,
                    activeThumbColor: Colors.redAccent,
                    onChanged: (v) => setState(() => _isUrgent = v),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submitComplaint,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _submitting ? 'Submitting to Principal...' : 'Send to Principal Desk',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
