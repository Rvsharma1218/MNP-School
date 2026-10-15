import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/student_model.dart';
import '../../data/models/settings_model.dart';
import '../../data/services/database_service.dart';
import '../../data/services/providers.dart';
import '../../data/services/session_service.dart';
import '../../data/services/teacher_permissions_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/responsive_web_layout.dart';

class StudentListScreen extends ConsumerStatefulWidget {
  const StudentListScreen({super.key});

  @override
  ConsumerState<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends ConsumerState<StudentListScreen>
    with RouteAware {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool get _isTeacher => SessionService.instance.isTeacher;
  bool get _canAddStudent =>
      !_isTeacher || ref.watch(teacherPermissionsProvider).canAddStudents;

  @override
  void initState() {
    super.initState();
    // Sync controller with provider state
    _searchCtrl.addListener(() {
      ref.read(studentSearchProvider.notifier).state = _searchCtrl.text;
    });
    // For teacher role, sync global filter from teacher's assigned class/section.
    // Prefer SessionService (set at login) over provider state which may be empty.
    if (_isTeacher) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final sessionClass = SessionService.instance.assignedClass ?? '';
        final sessionSection = SessionService.instance.assignedSection ?? '';
        final tc = sessionClass.isNotEmpty
            ? sessionClass
            : ref.read(teacherSelectedClassProvider);
        final ts = sessionSection.isNotEmpty
            ? sessionSection
            : ref.read(teacherSelectedSectionProvider);
        if (tc.isNotEmpty && tc.toLowerCase() != 'all' && tc.toLowerCase() != 'none') {
          ref.read(classFilterProvider.notifier).state = tc;
          ref.read(teacherSelectedClassProvider.notifier).state = tc;
        } else {
          ref.read(classFilterProvider.notifier).state = '';
        }
        if (ts.isNotEmpty && ts.toLowerCase() != 'all' && ts.toLowerCase() != 'none') {
          ref.read(sectionFilterProvider.notifier).state = ts;
          ref.read(teacherSelectedSectionProvider.notifier).state = ts;
        } else {
          ref.read(sectionFilterProvider.notifier).state = '';
        }
      });
    }

    // AUTO-REFRESH: Firestore data may arrive slightly after screen renders.
    // These delayed reloads ensure data is visible without a restart.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        ref.read(studentsProvider.notifier).loadStudents();
      });
    });
  }

  @override
  void dispose() {
    _clearSearch();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchCtrl.clear();
    ref.read(studentSearchProvider.notifier).state = '';
  }

  void _resetAllFilters() {
    _clearSearch();
    ref.read(studentFilterProvider.notifier).state = 'all';
    ref.read(studentStatusFilterProvider.notifier).state = 'all';
    ref.read(classFilterProvider.notifier).state = '';
    ref.read(sectionFilterProvider.notifier).state = '';
    ref.read(courseFilterProvider.notifier).state = '';
    ref.read(batchFilterProvider.notifier).state = '';
    // Re-apply teacher's working class/section
    if (_isTeacher) {
      final tc = ref.read(teacherSelectedClassProvider);
      final ts = ref.read(teacherSelectedSectionProvider);
      if (tc.isNotEmpty) ref.read(classFilterProvider.notifier).state = tc;
      if (ts.isNotEmpty) ref.read(sectionFilterProvider.notifier).state = ts;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filteredAsync = ref.watch(filteredStudentsProvider);
    final typeFilter = ref.watch(studentFilterProvider);
    final statusFilter = ref.watch(studentStatusFilterProvider);

    final int activeFilters = [
      if (typeFilter != 'all') 1,
      if (statusFilter != 'all') 1,
      if (ref.watch(classFilterProvider).isNotEmpty) 1,
      if (ref.watch(courseFilterProvider).isNotEmpty) 1,
    ].length;

    final isDesktop = MediaQuery.of(context).size.width >= 850;

    final content = PopScope(
      // Reset search when pressing back
      onPopInvoked: (_) => _resetAllFilters(),
      child: Scaffold(
        backgroundColor: cs.background,
        appBar: isDesktop ? null : AppBar(
          title: filteredAsync.when(
            data: (list) => Text('Students (${list.length})'),
            loading: () => const Text('Students'),
            error: (_, __) => const Text('Students'),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: [
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: () => _showFilterBottomSheet(context),
                  tooltip: 'Filters',
                ),
                if (activeFilters > 0)
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      width: 16, height: 16,
                      decoration: const BoxDecoration(
                          color: AppColors.accent, shape: BoxShape.circle),
                      child: Center(
                        child: Text('$activeFilters',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                      ),
                    ),
                  ),
              ],
            ),
            if (!_isTeacher)
              IconButton(
                icon: const Icon(Icons.school_rounded),
                onPressed: () => Navigator.pushNamed(context, AppRoutes.promoteStudents),
                tooltip: '1-Click Student Promotion',
              ),
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () => Navigator.pushNamed(context, AppRoutes.qrScanner),
              tooltip: 'Scan QR',
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by name, ID, mobile, father...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  prefixIcon:
                      Icon(Icons.search, color: Colors.white.withOpacity(0.8)),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white70),
                          onPressed: _clearSearch,
                          tooltip: 'Clear search',
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.15),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            _clearSearch();
            await ref.read(studentsProvider.notifier).loadStudents();
            ref.invalidate(dashboardStatsProvider);
          },
          child: filteredAsync.when(
            data: (students) {
              if (students.isEmpty) {
                final isSearching = _searchCtrl.text.isNotEmpty || activeFilters > 0;
                return isSearching
                    ? _emptySearch()
                    : EmptyState(
                        icon: Icons.people_outline,
                        title: 'No Students Yet',
                        subtitle: 'Add your first student to get started',
                        buttonLabel: _canAddStudent ? 'Add Student' : null,
                        onButtonTap: _canAddStudent
                            ? () async {
                                await Navigator.pushNamed(context, AppRoutes.addStudent);
                                // Auto-refresh after add
                                ref.read(studentsProvider.notifier).loadStudents();
                                ref.invalidate(dashboardStatsProvider);
                              }
                            : null,
                      );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: students.length,
                itemBuilder: (ctx, i) => _StudentCard(student: students[i]),
              );
            },
            loading: () => const LoadingWidget(message: 'Loading students...'),
            error: (e, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text('Error: $e', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () =>
                        ref.read(studentsProvider.notifier).loadStudents(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: _canAddStudent
            ? FloatingActionButton(
                heroTag: 'add_student_fab',
                tooltip: 'Add Student',
                onPressed: () async {
                  await Navigator.pushNamed(context, AppRoutes.addStudent);
                  // Auto-refresh list + dashboard after returning
                  _clearSearch();
                  ref.read(studentsProvider.notifier).loadStudents();
                  ref.invalidate(dashboardStatsProvider);
                },
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 4,
                child: const Icon(Icons.person_add_alt_1_rounded, size: 24),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );

    if (isDesktop) {
      return ResponsiveWebLayout(
        title: 'Students Directory',
        currentRoute: AppRoutes.studentList,
        floatingActionButton: _canAddStudent
            ? FloatingActionButton(
                heroTag: 'desktop_add_student_fab',
                tooltip: 'Add Student',
                onPressed: () async {
                  await Navigator.pushNamed(context, AppRoutes.addStudent);
                  _clearSearch();
                  ref.read(studentsProvider.notifier).loadStudents();
                  ref.invalidate(dashboardStatsProvider);
                },
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 4,
                child: const Icon(Icons.person_add_alt_1_rounded, size: 24),
              )
            : null,
        body: content,
      );
    }

    return content;
  }

  Widget _emptySearch() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 56, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('No students match your search',
              style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.filter_list_off),
            label: const Text('Clear All Filters'),
            onPressed: _resetAllFilters,
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _FilterBottomSheet(
        onApply: () {
          Navigator.pop(ctx);
          setState(() {});
        },
        onClear: () {
          _resetAllFilters();
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

// ─── Filter Bottom Sheet ──────────────────────────────────────────────────────

class _FilterBottomSheet extends ConsumerStatefulWidget {
  final VoidCallback onApply;
  final VoidCallback onClear;
  const _FilterBottomSheet({required this.onApply, required this.onClear});

  @override
  ConsumerState<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<_FilterBottomSheet> {
  String _type = 'all';
  String _status = 'all';
  String _class = '';
  String _course = '';
  String _section = '';

  @override
  void initState() {
    super.initState();
    _type = ref.read(studentFilterProvider);
    _status = ref.read(studentStatusFilterProvider);
    _class = ref.read(classFilterProvider);
    _course = ref.read(courseFilterProvider);
    _section = ref.read(sectionFilterProvider);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.valueOrNull ?? SettingsModel.defaultSettings();
    final schoolClasses = settings.schoolClasses.isNotEmpty ? settings.schoolClasses : SettingsModel.defaultClasses;
    final computerCourses = settings.computerCourses.isNotEmpty ? settings.computerCourses : SettingsModel.defaultCourses;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filter Students',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: cs.onSurface,
                      )),
                  Icon(Icons.filter_list, color: AppColors.primary),
                ],
              ),
              const SizedBox(height: 18),

              // ── Student Type ─────────────────────────────────────────────
              _sheetLabel('Student Type', cs),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _typeChip('All', 'all', cs),
                    const SizedBox(width: 8),
                    _typeChip('🏫 School', 'school', cs),
                    const SizedBox(width: 8),
                    _typeChip('💻 Computer', 'computer', cs),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── 🏫 School Classes Filter List ───────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _sheetLabel('🏫 School Classes', cs),
                  if (_class.isNotEmpty)
                    InkWell(
                      onTap: () => setState(() => _class = ''),
                      child: const Text('Clear', style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _class.isEmpty ? '' : (schoolClasses.contains(_class) ? _class : ''),
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('All Classes (Show All)')),
                      ...schoolClasses.map((cls) => DropdownMenuItem(value: cls, child: Text('Class $cls'))),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _class = val ?? '';
                        if (_class.isNotEmpty) {
                          _course = '';
                          _type = 'school';
                        }
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── 💻 Computer Courses Filter List ──────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _sheetLabel('💻 Computer Courses', cs),
                  if (_course.isNotEmpty)
                    InkWell(
                      onTap: () => setState(() => _course = ''),
                      child: const Text('Clear', style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _course.isEmpty ? '' : (computerCourses.any((c) => c.toLowerCase() == _course.toLowerCase()) ? computerCourses.firstWhere((c) => c.toLowerCase() == _course.toLowerCase()) : ''),
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('All Computer Courses (Show All)')),
                      ...computerCourses.map((crs) => DropdownMenuItem(value: crs, child: Text(crs))),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _course = val ?? '';
                        if (_course.isNotEmpty) {
                          _class = '';
                          _type = 'computer';
                        }
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Section Filter ───────────────────────────────────────────
              _sheetLabel('Section', cs),
              const SizedBox(height: 8),
              Row(
                children: [
                  ...['All', 'A', 'B', 'C', 'D'].map((sec) {
                    final isSel = (sec == 'All' && _section.isEmpty) || (_section.toUpperCase() == sec);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _selectableBadge(
                        label: sec == 'All' ? 'All' : 'Sec $sec',
                        isSelected: isSel,
                        onTap: () => setState(() => _section = sec == 'All' ? '' : sec),
                        cs: cs,
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 16),

              // ── Student Status ───────────────────────────────────────────
              _sheetLabel('Status', cs),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _statusChip('All', 'all', cs),
                    const SizedBox(width: 8),
                    _statusChip('🟢 Active', 'active', cs),
                    const SizedBox(width: 8),
                    _statusChip('🔵 Completed', 'completed', cs),
                    const SizedBox(width: 8),
                    _statusChip('🟠 Left', 'left', cs),
                    const SizedBox(width: 8),
                    _statusChip('🔴 Suspended', 'suspended', cs),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Apply / Clear buttons ────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.filter_list_off),
                      label: const Text('Clear All'),
                      onPressed: () {
                        setState(() {
                          _type = 'all';
                          _status = 'all';
                          _class = '';
                          _course = '';
                          _section = '';
                        });
                        widget.onClear();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Apply Filter'),
                      onPressed: () {
                        ref.read(studentFilterProvider.notifier).state = _type;
                        ref.read(studentStatusFilterProvider.notifier).state = _status;
                        ref.read(classFilterProvider.notifier).state = _class.trim();
                        ref.read(courseFilterProvider.notifier).state = _course.trim();
                        ref.read(sectionFilterProvider.notifier).state = _section.trim();
                        widget.onApply();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectableBadge({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ColorScheme cs,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : cs.surfaceVariant.withOpacity(0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : cs.outlineVariant.withOpacity(0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : cs.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _sheetLabel(String text, ColorScheme cs) {
    return Text(text,
        style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: cs.onSurfaceVariant));
  }

  Widget _typeChip(String label, String value, ColorScheme cs) {
    final sel = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : cs.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: sel ? Colors.white : cs.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ),
    );
  }

  Widget _statusChip(String label, String value, ColorScheme cs) {
    final sel = _status == value;
    return GestureDetector(
      onTap: () => setState(() => _status = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? AppColors.secondary : cs.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: sel ? Colors.white : cs.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ),
    );
  }
}

// ─── Student Card ────────────────────────────────────────────────────────────

class _StudentCard extends ConsumerStatefulWidget {
  final StudentModel student;
  const _StudentCard({required this.student});

  @override
  ConsumerState<_StudentCard> createState() => _StudentCardState();
}

class _StudentCardState extends ConsumerState<_StudentCard> {
  String _feeStatus = '...';
  Color _feeColor = AppColors.textSecondary;

  @override
  void initState() {
    super.initState();
    _loadFeeStatus();
  }

  Future<void> _loadFeeStatus() async {
    try {
      final fee =
          await DatabaseService.instance.getFeeByStudentId(widget.student.id);
      if (mounted) {
        final status = fee?.feeStatus ?? 'Not Set';
        Color color;
        switch (status) {
          case 'Paid':
            color = AppColors.success;
            break;
          case 'Overdue':
            color = AppColors.error;
            break;
          case 'Pending':
            color = AppColors.warning;
            break;
          case 'Partial':
            color = Colors.orange;
            break;
          default:
            color = AppColors.textSecondary;
        }
        setState(() {
          _feeStatus = status;
          _feeColor = color;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: cs.surface,
      child: InkWell(
        onTap: () async {
          await Navigator.pushNamed(context, AppRoutes.studentProfile,
              arguments: s.id);
          // Refresh fee status when returning from profile
          _loadFeeStatus();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildPhoto(s),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(s.name,
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface),
                              overflow: TextOverflow.ellipsis),
                        ),
                        _typeChip(s, cs),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(children: [
                      Icon(Icons.numbers, size: 11, color: cs.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(s.admissionNumber,
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Icon(Icons.badge_outlined, size: 11, color: cs.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(s.studentId,
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    ]),
                    const SizedBox(height: 3),
                    Row(children: [
                      Icon(Icons.school_outlined, size: 11, color: cs.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(s.displayClass,
                            style: TextStyle(fontSize: 11, color: cs.onSurface),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                    const SizedBox(height: 3),
                    Row(children: [
                      Icon(Icons.person_2_outlined, size: 11, color: cs.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(s.fatherName,
                            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Icon(Icons.phone_outlined, size: 11, color: cs.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(s.mobile,
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      _statusChip(s.statusLabel, Color(s.statusColor)),
                      const SizedBox(width: 6),
                      _feeStatusChip(),
                    ]),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoto(StudentModel s) {
    final initials = s.name
        .trim()
        .split(' ')
        .map((p) => p.isNotEmpty ? p[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return CircleAvatar(
      radius: 28,
      backgroundColor: AppColors.primary.withOpacity(0.15),
      child: ClipOval(
        child: AppUtils.buildAppImageWidget(
          s.photoPath,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          placeholder: Text(
            initials.isNotEmpty ? initials : '?',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeChip(StudentModel s, ColorScheme cs) {
    final isSchool = s.studentType == 'school';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isSchool
            ? AppColors.infoLight
            : AppColors.successLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isSchool ? 'School' : 'Computer',
        style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: isSchool ? AppColors.info : AppColors.success),
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _feeStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: _feeColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.currency_rupee, size: 8, color: _feeColor),
          Text(_feeStatus,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: _feeColor)),
        ],
      ),
    );
  }
}
