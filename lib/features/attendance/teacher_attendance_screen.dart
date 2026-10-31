import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../core/utils/holiday_utils.dart';
import '../../data/models/teacher_model.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/firestore_service.dart';
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
  Map<String, dynamic> _customHolidays = {};
  bool _loading = true;
  bool _saving = false;
  String? _schoolUid;

  HolidayInfo? get _currentHoliday =>
      HolidayUtils.getHolidayInfo(_selectedDate, _customHolidays);

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  @override
  void initState() {
    super.initState();
    TeacherService.instance.clearCache();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    setState(() => _loading = true);
    TeacherService.instance.clearCache();
    _schoolUid = SessionService.instance.activeSchoolUid;
    if (_schoolUid == null || _schoolUid!.isEmpty) {
      final user = AuthService.instance.currentUser;
      _schoolUid = user?.uid;
    }

    try {
      final holidays = await FirestoreService.instance.fetchHolidays();
      if (mounted) _customHolidays = holidays;
    } catch (_) {}

    if (_schoolUid != null && _schoolUid!.isNotEmpty) {
      try {
        final list = await TeacherService.instance.listAllTeachers(_schoolUid!, forceRefresh: false);
        final validTeachers = list
            .where((t) => t.name.trim().isNotEmpty && (t.teacherId.trim().isNotEmpty || t.id.trim().isNotEmpty))
            .toList();
        if (mounted) {
          setState(() {
            _teachers = validTeachers;
            for (final t in validTeachers) {
              final key = t.teacherId.trim().isNotEmpty ? t.teacherId.trim() : t.id.trim();
              _statusMap[key] = 'present';
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
    try {
      final holidays = await FirestoreService.instance.fetchHolidays();
      if (mounted) setState(() => _customHolidays = holidays);
    } catch (_) {}

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
          final k = t.teacherId.trim().isNotEmpty ? t.teacherId.trim() : t.id.trim();
          final val = records[k] ?? records[t.teacherId] ?? records[t.authUid] ?? 'present';
          map[k] = val.toString();
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
              final k = t.teacherId.trim().isNotEmpty ? t.teacherId.trim() : t.id.trim();
              _statusMap[k] = 'present';
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
        final k = t.teacherId.trim().isNotEmpty ? t.teacherId.trim() : t.id.trim();
        _statusMap[k] = status;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      await _loadAttendanceForDate();
    }
  }

  Future<void> _saveAttendance() async {
    if (_currentHoliday != null) return;
    if (_schoolUid == null || _schoolUid!.isEmpty) {
      _schoolUid = SessionService.instance.activeSchoolUid;
      if (_schoolUid!.isEmpty) {
        _schoolUid = AuthService.instance.currentUser?.uid;
      }
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
        final key = t.teacherId.trim().isNotEmpty ? t.teacherId.trim() : t.id.trim();
        if (key.isEmpty) continue;
        final status = _statusMap[key] ?? _statusMap[t.teacherId] ?? 'present';
        fullMap[key] = status;
        if (t.authUid.trim().isNotEmpty && t.authUid.trim() != key) {
          fullMap[t.authUid.trim()] = status;
        }
      }

      if (fullMap.isEmpty) {
        if (mounted) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid teachers found to save attendance.'), backgroundColor: AppColors.error),
          );
        }
        return;
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

  void _showHolidayDialog() {
    final cur = _currentHoliday;
    final isCustom = cur?.isCustom == true;
    final titleCtrl = TextEditingController(text: isCustom ? cur!.title : '');
    final reasonCtrl = TextEditingController(text: isCustom ? cur!.reason : '');
    final dateStr = AppUtils.formatDate(_selectedDate);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Text('🏖️ ', style: TextStyle(fontSize: 22)),
              Expanded(
                child: Text(
                  cur != null ? 'अवकाश विवरण (Holiday Info)' : 'स्कूल अवकाश दर्ज करें (Declare Holiday)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'दिनांक: $dateStr',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (cur != null && !isCustom) ...[
                  Text(
                    cur.title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'कारण: ${cur.reason}',
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'नोट: यह दिन स्वतः अवकाश (Weekly Off / Calendar Holiday) है। छात्र व शिक्षक दोनों की उपस्थिति प्रभावित नहीं होगी।',
                    style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                ] else ...[
                  const Text('अवकाश का नाम / शीर्षक:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      hintText: 'उदा. भारी बारिश / DM आदेश',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      'भारी बारिश (Heavy Rain)',
                      'DM आदेश (District Order)',
                      'शीतकालीन अवकाश (Winter Break)',
                      'स्थानीय त्योहार (Local Festival)',
                    ].map((opt) => ActionChip(
                      label: Text(opt, style: const TextStyle(fontSize: 10)),
                      onPressed: () {
                        setDlgState(() {
                          titleCtrl.text = opt;
                          reasonCtrl.text = 'Declared due to $opt';
                        });
                      },
                    )).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text('कारण / Cause (Reason):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'अवकाश का कारण लिखें (जैसे: जलभराव या प्रशासनिक आदेश)',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (isCustom)
              TextButton(
                onPressed: () async {
                  final key = DateFormat('yyyy-MM-dd').format(_selectedDate);
                  Navigator.pop(ctx);
                  await FirestoreService.instance.deleteHoliday(key);
                  final holidays = await FirestoreService.instance.fetchHolidays();
                  if (mounted) {
                    setState(() => _customHolidays = holidays);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('छुट्टी हटा दी गई है')),
                    );
                  }
                },
                child: const Text('छुट्टी हटाएं', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('बंद करें'),
            ),
            if (cur == null || isCustom)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final title = titleCtrl.text.trim();
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('कृपया अवकाश का शीर्षक लिखें')),
                    );
                    return;
                  }
                  final key = DateFormat('yyyy-MM-dd').format(_selectedDate);
                  final reason = reasonCtrl.text.trim().isNotEmpty
                      ? reasonCtrl.text.trim()
                      : 'School Holiday';
                  Navigator.pop(ctx);
                  await FirestoreService.instance.declareHoliday(
                    date: key,
                    title: title,
                    reason: reason,
                  );
                  final holidays = await FirestoreService.instance.fetchHolidays();
                  if (mounted) {
                    setState(() => _customHolidays = holidays);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('छुट्टी दर्ज की गई: $title (छात्र व शिक्षक दोनों उपस्थिति में लागू)'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
                child: const Text('सेव करें (Save)'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHolidayBanner(HolidayInfo holiday) {
    final isSunday = holiday.isSunday;
    final bg = isSunday ? const Color(0xFFFFFBEB) : const Color(0xFFEEF2FF);
    final border = isSunday ? const Color(0xFFFDE68A) : const Color(0xFFC7D2FE);
    final textCol = isSunday ? const Color(0xFF92400E) : const Color(0xFF3730A3);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Text(isSunday ? '☀️' : '🏖️', style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  holiday.title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: textCol),
                ),
                const SizedBox(height: 2),
                Text(
                  'कारण (Cause): ${holiday.reason} • आज स्कूल बंद है (Working day नहीं गिना जाएगा)',
                  style: TextStyle(fontSize: 11, color: textCol.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ),
          if (holiday.isCustom && SessionService.instance.isPrincipal)
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('छुट्टी हटाएं?'),
                    content: Text('क्या आप ${holiday.dateKey} की छुट्टी हटाना चाहते हैं?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('नहीं')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('हटाएं', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await FirestoreService.instance.deleteHoliday(holiday.dateKey);
                  final holidays = await FirestoreService.instance.fetchHolidays();
                  if (mounted) setState(() => _customHolidays = holidays);
                }
              },
              child: const Text('हटाएं', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final presentCount = _teachers.where((t) => (_statusMap[t.teacherId] ?? _statusMap[t.id]) == 'present').length;
    final absentCount = _teachers.where((t) => (_statusMap[t.teacherId] ?? _statusMap[t.id]) == 'absent').length;
    final halfDayCount = _teachers.where((t) => (_statusMap[t.teacherId] ?? _statusMap[t.id]) == 'half_day').length;
    final leaveCount = _teachers.where((t) => (_statusMap[t.teacherId] ?? _statusMap[t.id]) == 'leave').length;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Teacher Attendance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _currentHoliday != null ? Icons.beach_access_rounded : Icons.event_busy_outlined,
              color: _currentHoliday != null ? Colors.amberAccent : Colors.white,
            ),
            tooltip: _currentHoliday != null ? 'Holiday Active: ${_currentHoliday!.title}' : 'Note Holiday / अवकाश दर्ज करें',
            onPressed: _showHolidayDialog,
          ),
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

                // 🏖️ Holiday Banner
                if (_currentHoliday != null) _buildHolidayBanner(_currentHoliday!),

                // Quick Action All / Holiday Status
                if (_currentHoliday != null)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _currentHoliday!.isSunday ? const Color(0xFFFEF3C7) : const Color(0xFFE0E7FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _currentHoliday!.isSunday ? Icons.wb_sunny_rounded : Icons.beach_access_rounded,
                          size: 16,
                          color: _currentHoliday!.isSunday ? const Color(0xFF92400E) : const Color(0xFF3730A3),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _currentHoliday!.isSunday
                                ? 'आज रविवार (साप्ताहिक अवकाश) है — उपस्थिति दर्ज करने की आवश्यकता नहीं है।'
                                : 'आज ${_currentHoliday!.title} है — स्कूल बंद है। स्टाफ व छात्रों दोनों के लिए अवकाश मान्य है।',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: _currentHoliday!.isSunday ? const Color(0xFF92400E) : const Color(0xFF3730A3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_teachers.isNotEmpty)
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
                            final key = t.teacherId.trim().isNotEmpty ? t.teacherId.trim() : t.id.trim();
                            final status = _statusMap[key] ?? _statusMap[t.teacherId] ?? 'present';

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
                                  if (_currentHoliday != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _currentHoliday!.isSunday ? const Color(0xFFFEF3C7) : const Color(0xFFE0E7FF),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _currentHoliday!.isSunday ? '☀️ Sunday Off' : '🏖️ Holiday Off',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: _currentHoliday!.isSunday ? const Color(0xFF92400E) : const Color(0xFF3730A3),
                                        ),
                                      ),
                                    )
                                  else
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildStatusBtn('P', 'present', status, const Color(0xFF10B981), key),
                                        const SizedBox(width: 4),
                                        _buildStatusBtn('A', 'absent', status, const Color(0xFFEF4444), key),
                                        const SizedBox(width: 4),
                                        _buildStatusBtn('HD', 'half_day', status, Colors.purple, key),
                                        const SizedBox(width: 4),
                                        _buildStatusBtn('L', 'leave', status, const Color(0xFFF59E0B), key),
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
      floatingActionButton: _currentHoliday != null
          ? null
          : FloatingActionButton.extended(
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
