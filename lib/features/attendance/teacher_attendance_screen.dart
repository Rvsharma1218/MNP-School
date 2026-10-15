import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/teacher_model.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/session_service.dart';
import '../../data/services/teacher_service.dart';

class TeacherAttendanceScreen extends ConsumerStatefulWidget {
  const TeacherAttendanceScreen({super.key});

  @override
  ConsumerState<TeacherAttendanceScreen> createState() => _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends ConsumerState<TeacherAttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  List<TeacherModel> _teachers = [];
  Map<String, String> _statusMap = {}; // teacherId -> 'present' | 'absent' | 'half_day' | 'leave'
  bool _loading = true;
  bool _saving = false;
  String? _schoolUid;

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  @override
  void initState() {
    super.initState();
    final cached = TeacherService.instance.cachedTeachers;
    if (cached.isNotEmpty) {
      _teachers = List.from(cached);
      for (final t in _teachers) {
        _statusMap[t.teacherId] = 'present';
      }
      _loading = false;
    }
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    setState(() => _loading = true);
    _schoolUid = SessionService.instance.activeSchoolUid;
    if (_schoolUid == null || _schoolUid!.isEmpty) {
      final user = AuthService.instance.currentUser;
      _schoolUid = user?.uid;
    }

    if (_schoolUid != null && _schoolUid!.isNotEmpty) {
      try {
        final list = await TeacherService.instance.listAllTeachers(_schoolUid!);
        if (mounted) {
          setState(() {
            _teachers = list;
            for (final t in list) {
              _statusMap[t.teacherId] = 'present';
            }
            _loading = false;
          });
          await _loadAttendanceForDate();
          return;
        }
      } catch (e) {
        debugPrint('Error loading teachers: $e');
      }
    }

    if (mounted) {
      setState(() {
        _teachers = [];
        _loading = false;
      });
    }
  }

  Future<void> _loadAttendanceForDate() async {
    if (_schoolUid == null || _schoolUid!.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('schools')
          .doc(_schoolUid)
          .collection('teacher_attendance')
          .doc(_dateStr)
          .get();

      if (snap.exists && snap.data()?['records'] != null) {
        final records = Map<String, dynamic>.from(snap.data()!['records']);
        final map = <String, String>{};
        for (final t in _teachers) {
          final k = t.teacherId.isNotEmpty ? t.teacherId : t.authUid;
          map[t.teacherId] = records[k]?.toString() ?? records[t.teacherId]?.toString() ?? 'present';
        }
        if (mounted) {
          setState(() {
            _statusMap = map;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            for (final t in _teachers) {
              _statusMap[t.teacherId] = 'present';
            }
          });
        }
      }
    } catch (e) {
      debugPrint('[TeacherAttendanceScreen] Error fetching date attendance: $e');
    }
  }

  void _setAll(String status) {
    setState(() {
      for (final t in _teachers) {
        _statusMap[t.teacherId] = status;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      await _loadAttendanceForDate();
    }
  }

  Future<void> _saveAttendance() async {
    if (_schoolUid == null || _schoolUid!.isEmpty) {
      _schoolUid = SessionService.instance.activeSchoolUid ?? AuthService.instance.currentUser?.uid;
    }
    if (_schoolUid == null || _schoolUid!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: School session not found'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final fullMap = <String, String>{};
      for (final t in _teachers) {
        final status = _statusMap[t.teacherId] ?? 'present';
        fullMap[t.teacherId] = status;
        if (t.authUid.isNotEmpty && t.authUid != t.teacherId) {
          fullMap[t.authUid] = status;
        }
      }

      await FirebaseFirestore.instance
          .collection('schools')
          .doc(_schoolUid)
          .collection('teacher_attendance')
          .doc(_dateStr)
          .set({
        'date': _dateStr,
        'records': fullMap,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attendance for $_dateStr saved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('[TeacherAttendanceScreen] Error saving attendance: $e');
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save attendance: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final presentCount = _teachers.where((t) => _statusMap[t.teacherId] == 'present').length;
    final absentCount = _teachers.where((t) => _statusMap[t.teacherId] == 'absent').length;
    final halfDayCount = _teachers.where((t) => _statusMap[t.teacherId] == 'half_day').length;
    final leaveCount = _teachers.where((t) => _statusMap[t.teacherId] == 'leave').length;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Teacher Attendance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded),
            onPressed: _pickDate,
            tooltip: 'Select Date',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 📅 Date & Summary Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  child: Row(
                    children: [
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF2563EB)),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat('dd MMM yyyy').format(_selectedDate),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2563EB)),
                            ),
                            const Icon(Icons.arrow_drop_down, color: Color(0xFF2563EB)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      _buildCountBadge('P', presentCount, const Color(0xFF10B981)),
                      const SizedBox(width: 4),
                      _buildCountBadge('A', absentCount, const Color(0xFFEF4444)),
                      const SizedBox(width: 4),
                      _buildCountBadge('HD', halfDayCount, Colors.purple),
                      const SizedBox(width: 4),
                      _buildCountBadge('L', leaveCount, const Color(0xFFF59E0B)),
                    ],
                  ),
                ),

                // Quick Action All
                if (_teachers.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    child: Row(
                      children: [
                        Text('Mark All:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary)),
                        const SizedBox(width: 10),
                        _buildQuickBtn('✓ Present', const Color(0xFF10B981), () => _setAll('present')),
                        const SizedBox(width: 6),
                        _buildQuickBtn('✗ Absent', const Color(0xFFEF4444), () => _setAll('absent')),
                        const SizedBox(width: 6),
                        _buildQuickBtn('½ Half Day', Colors.purple, () => _setAll('half_day')),
                        const SizedBox(width: 6),
                        _buildQuickBtn('L Leave', const Color(0xFFF59E0B), () => _setAll('leave')),
                      ],
                    ),
                  ),

                // Teachers List
                Expanded(
                  child: _teachers.isEmpty
                      ? Center(
                          child: Text(
                            'No teachers found. Add teachers first.',
                            style: TextStyle(color: textSecondary, fontSize: 14),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                          itemCount: _teachers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final t = _teachers[i];
                            final status = _statusMap[t.teacherId] ?? 'present';

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  ClipOval(
                                    child: SizedBox(
                                      width: 38,
                                      height: 38,
                                      child: (t.photoUrl != null && t.photoUrl!.isNotEmpty)
                                          ? AppUtils.buildAppImageWidget(
                                              t.photoUrl,
                                              width: 38,
                                              height: 38,
                                              fit: BoxFit.cover,
                                              placeholder: CircleAvatar(
                                                backgroundColor: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                                                child: Text(
                                                  t.name.isNotEmpty ? t.name[0].toUpperCase() : 'T',
                                                  style: const TextStyle(
                                                    color: Color(0xFF0D9488),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : CircleAvatar(
                                              backgroundColor: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                                              child: Text(
                                                t.name.isNotEmpty ? t.name[0].toUpperCase() : 'T',
                                                style: const TextStyle(
                                                  color: Color(0xFF0D9488),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t.name,
                                          style: TextStyle(
                                            color: textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          'ID: ${t.teacherId} • ${(t.assignedClass?.isNotEmpty == true ? t.assignedClass! : 'Staff')}',
                                          style: TextStyle(color: textSecondary, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildStatusBtn('P', 'present', status, const Color(0xFF10B981), t.teacherId),
                                      const SizedBox(width: 4),
                                      _buildStatusBtn('A', 'absent', status, const Color(0xFFEF4444), t.teacherId),
                                      const SizedBox(width: 4),
                                      _buildStatusBtn('HD', 'half_day', status, Colors.purple, t.teacherId),
                                      const SizedBox(width: 4),
                                      _buildStatusBtn('L', 'leave', status, const Color(0xFFF59E0B), t.teacherId),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _saveAttendance,
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        icon: _saving
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.check_circle_outline),
        label: const Text('Save Attendance', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCountBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildQuickBtn(String text, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStatusBtn(String label, String value, String current, Color color, String teacherId) {
    final isSelected = current == value;
    return InkWell(
      onTap: () => setState(() => _statusMap[teacherId] = value),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.bold,
            fontSize: label == 'HD' ? 9 : 11,
          ),
        ),
      ),
    );
  }
}
