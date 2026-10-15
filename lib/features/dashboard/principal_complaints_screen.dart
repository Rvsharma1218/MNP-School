import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../data/services/session_service.dart';

class PrincipalComplaintsScreen extends StatefulWidget {
  const PrincipalComplaintsScreen({super.key});

  @override
  State<PrincipalComplaintsScreen> createState() => _PrincipalComplaintsScreenState();
}

class _PrincipalComplaintsScreenState extends State<PrincipalComplaintsScreen> {
  String _selectedFilter = 'all'; // 'all', 'pending', 'urgent', 'resolved'
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  void _callParent(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot dial phone: $clean')),
        );
      }
    }
  }

  void _showReplyDialog(Map<String, dynamic> item) {
    final docId = item['docId']?.toString() ?? item['id']?.toString() ?? '';
    final studentName = item['studentName'] ?? 'Student';
    final existingReply = item['reply'] ?? item['adminReply'] ?? '';
    final replyCtrl = TextEditingController(text: existingReply);
    bool markResolved = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.reply_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Reply to Parent ($studentName)',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Complaint: "${item['subject'] ?? ''}"',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: replyCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Type your official response to the parent here. They will see this response directly in their Parent App.',
                  hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Checkbox(
                    value: markResolved,
                    activeColor: const Color(0xFF10B981),
                    onChanged: (v) => setDlgState(() => markResolved = v ?? false),
                  ),
                  const Text('Mark complaint as Resolved', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final replyText = replyCtrl.text.trim();
                if (replyText.isEmpty) return;

                Navigator.pop(ctx);
                final now = DateTime.now();
                final updateData = {
                  'reply': replyText,
                  'adminReply': replyText,
                  'repliedAt': DateFormat('dd MMM yyyy, hh:mm a').format(now),
                  'repliedAtMs': now.millisecondsSinceEpoch,
                  'repliedAtIso': now.toIso8601String(),
                  'lastReplyTimestamp': now.millisecondsSinceEpoch,
                  'status': markResolved ? 'resolved' : 'in_progress',
                  'resolved': markResolved,
                  'unreadByParent': true,
                };

                try {
                  if (docId.isNotEmpty) {
                    await _db.collection('feedbacks').doc(docId).update(updateData).catchError((_) {});
                    await _db.collection('schoolDirectory').doc('system_feedbacks').collection('items').doc(docId).update(updateData).catchError((_) {});
                    final schoolId = SessionService.instance.activeSchoolId;
                    await _db.collection('schools').doc(schoolId).collection('complaints').doc(docId).update(updateData).catchError((_) {});
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✓ Reply sent to parent successfully!'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Send Reply'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleStatus(Map<String, dynamic> item) async {
    final docId = item['docId']?.toString() ?? item['id']?.toString() ?? '';
    final isResolved = (item['status'] ?? 'new').toString().toLowerCase() == 'resolved' || item['resolved'] == true;
    final newStatus = isResolved ? 'new' : 'resolved';
    final isNowResolved = newStatus == 'resolved';

    if (docId.isNotEmpty) {
      final statusMap = {
        'status': newStatus,
        'resolved': isNowResolved,
        'resolvedAt': isNowResolved ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()) : null,
      };
      await _db.collection('feedbacks').doc(docId).update(statusMap).catchError((_) {});
      await _db.collection('schoolDirectory').doc('system_feedbacks').collection('items').doc(docId).update(statusMap).catchError((_) {});
      final schoolId = SessionService.instance.activeSchoolId;
      await _db.collection('schools').doc(schoolId).collection('complaints').doc(docId).update(statusMap).catchError((_) {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'resolved' ? 'Marked as Resolved' : 'Marked as Pending'),
            backgroundColor: newStatus == 'resolved' ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Stream<List<Map<String, dynamic>>> _getComplaintsStream() {
    return _db.collection('feedbacks').snapshots().map((snap) {
      final activeSchool = SessionService.instance.activeSchoolId.toLowerCase();
      final list = <Map<String, dynamic>>[];

      for (final doc in snap.docs) {
        final d = Map<String, dynamic>.from(doc.data());
        d['docId'] = doc.id;
        final sId = (d['schoolId'] ?? '').toString().toLowerCase();

        // Include if matches this school or is generic parent complaint
        final isParentComplaint = d['type'] == 'parent_complaint' || d['studentId'] != null || d['senderPhone'] != null;
        if (isParentComplaint) {
          if (sId.isEmpty || sId == activeSchool || sId.contains('school_') || activeSchool.contains('007')) {
            list.add(d);
          }
        }
      }

      list.sort((a, b) {
        final tA = a['createdAt']?.toString() ?? a['date']?.toString() ?? '';
        final tB = b['createdAt']?.toString() ?? b['date']?.toString() ?? '';
        return tB.compareTo(tA);
      });

      return list;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Parent Complaints Desk',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              'Direct desk of Principal / Admin',
              style: TextStyle(fontSize: 11, color: Color(0xFFBFDBFE)),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getComplaintsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final allItems = snapshot.data ?? [];
          final pendingCount = allItems.where((e) => (e['status'] ?? 'new').toString().toLowerCase() != 'resolved').length;
          final urgentCount = allItems.where((e) => e['priority'] == 'urgent' || e['urgent'] == true).length;
          final resolvedCount = allItems.where((e) => (e['status'] ?? 'new').toString().toLowerCase() == 'resolved').length;

          final filtered = allItems.where((item) {
            final st = (item['status'] ?? 'new').toString().toLowerCase();
            final isUrgent = item['priority'] == 'urgent' || item['urgent'] == true;

            if (_selectedFilter == 'pending') return st != 'resolved';
            if (_selectedFilter == 'urgent') return isUrgent;
            if (_selectedFilter == 'resolved') return st == 'resolved';
            return true;
          }).toList();

          return Column(
            children: [
              // 1. Metric Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E3A8A),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    _buildMetricPill('Total', '${allItems.length}', Colors.white, Colors.white24),
                    const SizedBox(width: 8),
                    _buildMetricPill('Pending', '$pendingCount', const Color(0xFFFDE68A), const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                    const SizedBox(width: 8),
                    _buildMetricPill('Urgent', '$urgentCount', const Color(0xFFFECACA), const Color(0xFFEF4444).withValues(alpha: 0.3)),
                    const SizedBox(width: 8),
                    _buildMetricPill('Resolved', '$resolvedCount', const Color(0xFFA7F3D0), const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ],
                ),
              ),

              // 2. Filter Tabs
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    _buildFilterChip('all', 'All (${allItems.length})'),
                    const SizedBox(width: 6),
                    _buildFilterChip('pending', 'Pending ($pendingCount)'),
                    const SizedBox(width: 6),
                    _buildFilterChip('urgent', 'Urgent ($urgentCount)'),
                    const SizedBox(width: 6),
                    _buildFilterChip('resolved', 'Resolved ($resolvedCount)'),
                  ],
                ),
              ),

              // 3. Complaints List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox_rounded, size: 56, color: Colors.grey.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            const Text(
                              'No Complaints Found',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF475569)),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Messages and complaints submitted by parents will stream here live.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, idx) => _buildComplaintCard(filtered[idx]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricPill(String label, String value, Color textColor, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 1),
            Text(label, style: TextStyle(color: textColor.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String id, String label) {
    final isSel = _selectedFilter == id;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedFilter = id),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSel ? const Color(0xFF1E3A8A) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSel ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: isSel ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComplaintCard(Map<String, dynamic> item) {
    final category = item['category'] ?? 'Complaint';
    final subject = item['subject'] ?? 'Parent Message';
    final message = item['message'] ?? '';
    final studentName = item['studentName'] ?? 'Student';
    final className = item['className'] ?? '';
    final section = item['section'] ?? '';
    final admissionNo = item['admissionNo'] ?? '';
    final senderName = item['senderName'] ?? 'Parent';
    final senderPhone = item['senderPhone'] ?? item['parentMobile'] ?? '';
    final status = (item['status'] ?? 'new').toString().toLowerCase();
    final isResolved = status == 'resolved';
    final isUrgent = item['priority'] == 'urgent' || item['urgent'] == true;
    final reply = item['reply'] ?? item['adminReply'] ?? '';
    final dateStr = item['date'] ?? 'Recent';

    Color badgeColor = const Color(0xFF2563EB);
    if (category.toString().contains('Academic') || category.toString().contains('पढ़ाई')) {
      badgeColor = const Color(0xFF7C3AED);
    } else if (category.toString().contains('Fee') || category.toString().contains('फीस')) {
      badgeColor = const Color(0xFF10B981);
    } else if (category.toString().contains('Bus') || category.toString().contains('Transport')) {
      badgeColor = const Color(0xFFD97706);
    } else if (category.toString().contains('Discipline')) {
      badgeColor = const Color(0xFFDC2626);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isResolved ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
          width: isResolved ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Badges & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      category.toString().toUpperCase(),
                      style: TextStyle(color: badgeColor, fontSize: 9.5, fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (isUrgent) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 10),
                          SizedBox(width: 2),
                          Text('URGENT', style: TextStyle(color: Color(0xFFDC2626), fontSize: 9, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              InkWell(
                onTap: () => _toggleStatus(item),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isResolved ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isResolved ? Icons.check_circle_rounded : Icons.schedule_rounded,
                        size: 12,
                        color: isResolved ? const Color(0xFF059669) : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isResolved ? 'RESOLVED' : 'PENDING REVIEW',
                        style: TextStyle(
                          color: isResolved ? const Color(0xFF059669) : const Color(0xFFD97706),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Student & Parent Profile Line
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_pin_rounded, color: Color(0xFF1E3A8A), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$studentName  •  Class $className ${section.isNotEmpty ? "($section)" : ""}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Parent: $senderName • Adm No: $admissionNo',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                if (senderPhone.toString().isNotEmpty)
                  InkWell(
                    onTap: () => _callParent(senderPhone.toString()),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.phone_rounded, color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Subject
          Text(
            subject,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),

          // Message
          Text(
            message,
            style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.4),
          ),
          const SizedBox(height: 10),

          // Timestamp
          Text(
            'Received: $dateStr',
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
          ),

          // Principal's Reply Box if already sent
          if (reply.toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF93C5FD)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified_rounded, color: Color(0xFF2563EB), size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Principal Office Response Sent to Parent:',
                        style: TextStyle(color: Color(0xFF1E40AF), fontSize: 10.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    reply.toString(),
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF1E3A8A), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Action Buttons: Reply to Parent & Toggle Status
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showReplyDialog(item),
                  icon: const Icon(Icons.reply_rounded, size: 15),
                  label: Text(reply.toString().isNotEmpty ? 'Edit Reply' : 'Reply to Parent'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _toggleStatus(item),
                icon: Icon(
                  isResolved ? Icons.restart_alt_rounded : Icons.check_circle_outline_rounded,
                  size: 15,
                  color: isResolved ? const Color(0xFFD97706) : const Color(0xFF059669),
                ),
                label: Text(isResolved ? 'Reopen' : 'Mark Done'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isResolved ? const Color(0xFFD97706) : const Color(0xFF059669),
                  side: BorderSide(color: isResolved ? const Color(0xFFD97706) : const Color(0xFF059669)),
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
