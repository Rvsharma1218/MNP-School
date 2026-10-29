import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/student_model.dart';
import '../../data/services/database_service.dart';
import '../../data/services/firestore_service.dart';
import '../../data/services/providers.dart';
import '../../data/services/session_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/responsive_web_layout.dart';
import '../whatsapp/whatsapp_service.dart';
import 'teacher_attendance_screen.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  final String? initialClass;
  const AttendanceScreen({super.key, this.initialClass});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  List<StudentModel> _allStudents = [];
  List<StudentModel> _filteredStudents = [];
  Map<String, String> _statusMap = {};
  Map<String, Map<String, int>> _summaryMap = {};
  bool _loading = true;
  bool _saving = false;
  bool _showFilters = false;

  // ── Filter state ──────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _typeFilter = 'all';     // all | school | computer
  String _classFilter = '';
  String _sectionFilter = '';
  String _statusFilter = 'all';   // all | present | absent | leave

  @override
  void initState() {
    super.initState();
    if (widget.initialClass != null && widget.initialClass!.isNotEmpty) {
      _classFilter = widget.initialClass!;
    }
    _searchCtrl.addListener(_applyFilters);
    // Initialize filters: Teacher defaults to '' ('All Classes') so all assigned classes show
    _classFilter = '';
    _sectionFilter = '';
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to studentsProvider — when new students are added/edited,
    // re-load so the attendance list updates without restart.
    ref.listenManual(studentsProvider, (_, next) {
      next.whenData((students) {
        if (!mounted) return;
        final existingIds = _allStudents.map((s) => s.id).toSet();
        final newIds = students.map((s) => s.id).toSet();
        if (existingIds.length != newIds.length ||
            !existingIds.containsAll(newIds)) {
          _load();
        }
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = DatabaseService.instance;
    final results = await Future.wait([
      db.getAllStudents(),
      db.getAttendanceByDate(_selectedDate),
    ]);
    final students = results[0] as List<StudentModel>;
    final existing = results[1] as List<AttendanceModel>;
    final map = {for (final a in existing) a.studentId: a.status};

    if (mounted) {
      setState(() {
        _allStudents = students;
        _statusMap = map;
        _loading = false;
      });
      _applyFilters();
    }

    // Load full history summaries asynchronously in background without blocking screen opening
    db.getAllAttendanceSummaries().then((summaries) {
      if (mounted) {
        setState(() => _summaryMap = summaries);
      }
    }).catchError((_) {});
  }

  void _applyFilters() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filteredStudents = _allStudents.where((s) {
        // Teacher role check: only show authorized classes
        if (!SessionService.instance.isPrincipal && !SessionService.instance.hasAllClassesAccess) {
          if (!SessionService.instance.canAccessClass(s.className ?? s.course)) return false;
        }
        // Type filter
        if (_typeFilter != 'all' && s.studentType != _typeFilter) return false;
        // Class filter
        if (_classFilter.isNotEmpty && _classFilter.toLowerCase() != 'all' && _classFilter.toLowerCase() != 'none' && s.className != _classFilter) return false;
        // Section filter
        if (_sectionFilter.isNotEmpty && _sectionFilter.toLowerCase() != 'all' && _sectionFilter.toLowerCase() != 'none' && s.section != _sectionFilter) return false;
        // Status filter (based on today's marked status)
        if (_statusFilter != 'all') {
          final marked = _statusMap[s.id] ?? '';
          if (marked != _statusFilter) return false;
        }
        // Search
        if (q.isNotEmpty) {
          final match = s.name.toLowerCase().contains(q) ||
              s.admissionNumber.toLowerCase().contains(q) ||
              s.studentId.toLowerCase().contains(q) ||
              s.mobile.contains(q);
          if (!match) return false;
        }
        return true;
      }).toList();
    });
  }

  void _resetFilters() {
    _searchCtrl.clear();
    setState(() {
      _typeFilter = 'all';
      _classFilter = '';
      _sectionFilter = '';
      _statusFilter = 'all';
    });
    _applyFilters();
  }

  List<String> get _allClasses {
    final classes = _allStudents
        .where((s) => s.studentType == 'school' && (s.className?.isNotEmpty == true))
        .map((s) => s.className!)
        .toSet()
        .toList()
      ..sort();
    return SessionService.instance.filterAllowedClasses(classes);
  }

  List<String> get _allSections {
    final sections = _allStudents
        .where((s) => s.section?.isNotEmpty == true)
        .map((s) => s.section!)
        .toSet()
        .toList()
      ..sort();
    return sections;
  }

  int get _activeFilters {
    int count = 0;
    if (_typeFilter != 'all') count++;
    if (_classFilter.isNotEmpty) count++;
    if (_sectionFilter.isNotEmpty) count++;
    if (_statusFilter != 'all') count++;
    if (_searchCtrl.text.isNotEmpty) count++;
    return count;
  }

  void _setAll(String status) {
    setState(() {
      for (final s in _filteredStudents) {
        _statusMap[s.id] = status;
      }
    });
  }

  Future<void> _saveAttendance() async {
    setState(() => _saving = true);
    try {
      for (final s in _allStudents) {
        final status = _statusMap[s.id] ?? 'absent';
        final record = AttendanceModel(
          id: const Uuid().v4(),
          studentId: s.id,
          date: _selectedDate,
          status: status,
        );
        // Step 1: Save to SQLite FIRST — always succeeds, no Firestore dependency.
        await DatabaseService.instance.markAttendance(record);
        // Step 2: Sync to Firestore in BACKGROUND (fire-and-forget).
        // Do NOT await — if Firestore quota/network fails, SQLite data is safe.
        FirestoreService.instance.syncAttendance(record).catchError((e) {
          debugPrint('[AttendanceScreen] Firestore sync skipped for ${s.id}: $e');
          return null;
        });
        ref.invalidate(studentAttendanceProvider(s.id));
      }
      ref.invalidate(dashboardStatsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance saved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showWhatsAppAbsentDialog() async {
    final absentStudents = _allStudents.where((s) => _statusMap[s.id] == 'absent').toList();
    if (absentStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('आज कोई भी छात्र अनुपस्थित (Absent) नहीं है!'),
          backgroundColor: AppColors.success,
        ),
      );
      return;
    }

    final settings = await DatabaseService.instance.getSettings();
    final schoolName = settings.instituteName.isNotEmpty ? settings.instituteName : 'Mission Navodaya Public School';
    final dateStr = AppUtils.formatDate(_selectedDate);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'WhatsApp अनुपस्थित अलर्ट',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'आज ${absentStudents.length} बच्चे अनुपस्थित हैं • $dateStr',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                'संदेश: "आदरणीय अभिभावक, आपका बच्चा [नाम] (कक्षा [कक्षा]) आज दिनांक [दिनांक] को स्कूल में अनुपस्थित है।"',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: absentStudents.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (c, idx) {
                  final s = absentStudents[idx];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFFEE2E2),
                      child: Text(
                        s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                        style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('कक्षा: ${s.className ?? "-"} • मो: ${s.mobile.isNotEmpty ? s.mobile : "उपलब्ध नहीं"}', style: const TextStyle(fontSize: 12)),
                    trailing: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 14),
                      label: const Text('भेजें', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        final msg = '📢 *स्कूल उपस्थिति सूचना (Attendance Alert)*\n'
                            '━━━━━━━━━━━━━━━━━━━━\n'
                            'आदरणीय अभिभावक,\n'
                            'सूचित किया जाता है कि आपका बच्चा *${s.name}* (कक्षा: ${s.className ?? ""}, रोल: ${s.rollNumber ?? ""}) आज दिनांक *${dateStr}* को स्कूल में *अनुपस्थित (Absent)* है।\n\n'
                            'यदि कोई विशेष कारण हो तो कृपया स्कूल कार्यालय को सूचित करें।\n\n'
                            '- *${schoolName}*\n'
                            '━━━━━━━━━━━━━━━━━━━━';
                        WhatsAppService.sendMessage(
                          context: context,
                          phone: s.mobile,
                          message: msg,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final present = _allStudents.where((s) => _statusMap[s.id] == 'present').length;
    final absent = _allStudents.where((s) => _statusMap[s.id] == 'absent').length;
    final halfDay = _allStudents.where((s) => _statusMap[s.id] == 'half_day').length;
    final leave = _allStudents.where((s) => _statusMap[s.id] == 'leave').length;
    final unmarked = _allStudents.where((s) => _statusMap[s.id] == null).length;

    final isDesktop = MediaQuery.of(context).size.width >= 850;

    final content = Scaffold(
      backgroundColor: cs.background,
      appBar: isDesktop ? null : AppBar(
        title: Text('Attendance (${_filteredStudents.length}/${_allStudents.length})'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_chat_unread_rounded, color: Color(0xFF25D366)),
            tooltip: 'WhatsApp अनुपस्थित अलर्ट (Absent Alert)',
            onPressed: _showWhatsAppAbsentDialog,
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () => setState(() => _showFilters = !_showFilters),
              ),
              if (_activeFilters > 0)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    width: 15, height: 15,
                    decoration: const BoxDecoration(
                        color: AppColors.accent, shape: BoxShape.circle),
                    child: Center(
                      child: Text('$_activeFilters',
                          style: const TextStyle(
                              fontSize: 9, fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ),
                  ),
                ),
            ],
          ),
          if (!SessionService.instance.isTeacher)
            IconButton(
              icon: const Icon(Icons.co_present_outlined),
              tooltip: 'Teacher Attendance',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TeacherAttendanceScreen()),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDate,
            tooltip: 'Select Date',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_showFilters ? 220 : 54),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search name, ID, admission no, mobile...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                    prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.8)),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white70),
                      onPressed: () {
                        _searchCtrl.clear();
                        _applyFilters();
                      },
                    )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              // Filter panel
              if (_showFilters) _buildFilterPanel(),
            ],
          ),
        ),
      ),
      body: _loading
          ? const LoadingWidget(message: 'Loading students...')
          : Column(
        children: [
          // ── Date + summary bar ───────────────────────────────────
          _buildSummaryBar(present, absent, halfDay, leave, unmarked, cs),

          // ── Mark all row ─────────────────────────────────────────
          if (_filteredStudents.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: cs.surfaceVariant,
              child: Row(
                children: [
                  Text('Mark ${_filteredStudents.length} shown:',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  _quickMarkBtn('✓ All Present', AppColors.success,
                          () => _setAll('present')),
                  const SizedBox(width: 6),
                  _quickMarkBtn('✗ All Absent', AppColors.error,
                          () => _setAll('absent')),
                  const SizedBox(width: 6),
                  _quickMarkBtn('L Leave', AppColors.warning,
                          () => _setAll('leave')),
                ],
              ),
            ),

          // ── Student list ─────────────────────────────────────────
          Expanded(
            child: _filteredStudents.isEmpty
                ? EmptyState(
              icon: Icons.search_off,
              title: _activeFilters > 0
                  ? 'No matching students'
                  : 'No students found',
              subtitle: _activeFilters > 0
                  ? 'Try clearing filters'
                  : 'Add students first',
              buttonLabel: _activeFilters > 0 ? 'Clear Filters' : null,
              onButtonTap: _activeFilters > 0 ? _resetFilters : null,
            )
                : ListView.builder(
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: _filteredStudents.length,
              itemBuilder: (_, i) => _buildStudentTile(
                  _filteredStudents[i], cs),
            ),
          ),
        ],
      ),
      floatingActionButton: _saving
          ? const FloatingActionButton(
        onPressed: null,
        backgroundColor: AppColors.primary,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      )
          : FloatingActionButton.extended(
        onPressed: _allStudents.isEmpty ? null : _saveAttendance,
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.save_rounded),
        label: const Text('Save Attendance',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );

    if (isDesktop) {
      return ResponsiveWebLayout(
        title: 'Daily Attendance',
        currentRoute: AppRoutes.attendance,
        body: content,
      );
    }

    return content;
  }

  Widget _buildSummaryBar(int present, int absent, int halfDay, int leave, int unmarked, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: cs.surface,
      child: Row(
        children: [
          // Date
          GestureDetector(
            onTap: _pickDate,
            child: Row(children: [
              const Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                AppUtils.formatDate(_selectedDate),
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    fontSize: 13),
              ),
              const Icon(Icons.edit, size: 12, color: AppColors.primary),
            ]),
          ),
          const Spacer(),
          _summaryChip('P: $present', AppColors.success),
          const SizedBox(width: 3),
          InkWell(
            onTap: absent > 0 ? _showWhatsAppAbsentDialog : null,
            borderRadius: BorderRadius.circular(10),
            child: _summaryChip('A: $absent 💬', AppColors.error),
          ),
          const SizedBox(width: 3),
          _summaryChip('HD: $halfDay', Colors.purple),
          const SizedBox(width: 3),
          _summaryChip('L: $leave', AppColors.warning),
          if (unmarked > 0) ...[
            const SizedBox(width: 4),
            _summaryChip('?: $unmarked', AppColors.textSecondary),
          ],
        ],
      ),
    );
  }

  Widget _summaryChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _quickMarkBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildStudentTile(StudentModel s, ColorScheme cs) {
    final status = _statusMap[s.id] ?? 'absent';
    return Card(
      color: cs.surface,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: _statusColor(status).withOpacity(0.15),
              child: Text(
                s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                style: TextStyle(
                    color: _statusColor(status),
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: cs.onSurface),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text('${s.admissionNumber} | ${s.displayClass}',
                            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if ((_summaryMap[s.id]?['total'] ?? 0) > 0) ...[
                        Builder(builder: (_) {
                          final tot = _summaryMap[s.id]!['total']!;
                          final prs = _summaryMap[s.id]!['present']!;
                          final pct = (prs / tot * 100.0).toStringAsFixed(0);
                          final color = double.parse(pct) >= 75 ? AppColors.success : AppColors.warning;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$pct% Att.',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                            ),
                          );
                        }),
                        const SizedBox(width: 4),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Status buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _statusBtn('P', 'present', status, AppColors.success, s.id),
                const SizedBox(width: 3),
                _statusBtn('A', 'absent', status, AppColors.error, s.id),
                const SizedBox(width: 3),
                _statusBtn('HD', 'half_day', status, Colors.purple, s.id),
                const SizedBox(width: 3),
                _statusBtn('L', 'leave', status, AppColors.warning, s.id),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBtn(
      String label, String value, String current, Color color, String studentId) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => setState(() => _statusMap[studentId] = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.08),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? color : color.withOpacity(0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'present':
        return AppColors.success;
      case 'half_day':
        return Colors.purple;
      case 'leave':
        return AppColors.warning;
      default:
        return AppColors.error;
    }
  }

  Widget _buildFilterPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          // Type filter
          Row(children: [
            _filterBtn('All', 'all', 'type'),
            const SizedBox(width: 6),
            _filterBtn('School', 'school', 'type'),
            const SizedBox(width: 6),
            _filterBtn('Computer', 'computer', 'type'),
          ]),
          const SizedBox(height: 8),
          // Class + Section dropdowns
          Row(children: [
            Expanded(
              child: _filterDropdown(
                hint: 'Class',
                value: _classFilter.isEmpty ? null : _classFilter,
                items: _allClasses,
                onChanged: (v) {
                  setState(() => _classFilter = v ?? '');
                  _applyFilters();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _filterDropdown(
                hint: 'Section',
                value: _sectionFilter.isEmpty ? null : _sectionFilter,
                items: _allSections,
                onChanged: (v) {
                  setState(() => _sectionFilter = v ?? '');
                  _applyFilters();
                },
              ),
            ),
          ]),
          const SizedBox(height: 8),
          // Status filter + Reset
          Row(children: [
            _filterBtn('All Status', 'all', 'status'),
            const SizedBox(width: 4),
            _filterBtn('Present', 'present', 'status'),
            const SizedBox(width: 4),
            _filterBtn('Absent', 'absent', 'status'),
            const SizedBox(width: 4),
            _filterBtn('Leave', 'leave', 'status'),
            const Spacer(),
            GestureDetector(
              onTap: _resetFilters,
              child: Text('Reset',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                      decoration: TextDecoration.underline)),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _filterBtn(String label, String value, String key) {
    final bool sel = key == 'type'
        ? _typeFilter == value
        : _statusFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (key == 'type') _typeFilter = value;
          if (key == 'status') _statusFilter = value;
        });
        _applyFilters();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? Colors.white : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: sel ? AppColors.primary : Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _filterDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          isExpanded: true,
          dropdownColor: AppColors.primaryDark,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
          items: [
            DropdownMenuItem(
                value: '',
                child: Text('All $hint',
                    style: const TextStyle(color: Colors.white70, fontSize: 12))),
            ...items.map((c) => DropdownMenuItem(
                value: c,
                child: Text(c, style: const TextStyle(color: Colors.white, fontSize: 12)))),
          ],
          onChanged: (v) => onChanged(v == '' ? null : v),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null && date != _selectedDate) {
      setState(() => _selectedDate = date);
      _load();
    }
  }
}