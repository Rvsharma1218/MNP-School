import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/student_model.dart';
import '../../data/models/settings_model.dart';
import '../../data/services/providers.dart';

class PromoteStudentsScreen extends ConsumerStatefulWidget {
  const PromoteStudentsScreen({super.key});

  @override
  ConsumerState<PromoteStudentsScreen> createState() => _PromoteStudentsScreenState();
}

class _PromoteStudentsScreenState extends ConsumerState<PromoteStudentsScreen> {
  final _classes = SettingsModel.defaultClasses;
  final _sections = ['Same as current', 'A', 'B', 'C', 'D', 'E'];
  final _sessions = SettingsModel.getSessions();

  String _sourceClass = '1';
  String _sourceSession = '2026-27';

  String _targetClass = '2';
  String _targetSection = 'Same as current';
  String _targetSession = '2027-28';

  final Set<String> _selectedStudentIds = {};
  String _searchQuery = '';
  bool _isPromoting = false;

  // Optional Fee Overrides
  bool _updateFees = false;
  final _totalFeeCtrl = TextEditingController();
  final _monthlyFeeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _autoMapTarget();
  }

  @override
  void dispose() {
    _totalFeeCtrl.dispose();
    _monthlyFeeCtrl.dispose();
    super.dispose();
  }

  void _autoMapTarget() {
    // 1. Auto map next class
    final progression = {
      'Nursery': 'LKG',
      'LKG': 'UKG',
      'UKG': '1',
      '1': '2',
      '2': '3',
      '3': '4',
      '4': '5',
      '5': '6',
      '6': '7',
      '7': '8',
      '8': '9',
      '9': '10',
      '10': 'Passout / Alumni',
      '11': '12',
      '12': 'Passout / Alumni',
    };
    final nextCls = progression[_sourceClass] ?? _sourceClass;
    _targetClass = nextCls;

    // 2. Auto map next session
    final sessIdx = _sessions.indexOf(_sourceSession);
    if (sessIdx != -1 && sessIdx + 1 < _sessions.length) {
      _targetSession = _sessions[sessIdx + 1];
    } else {
      _targetSession = _sourceSession;
    }
  }

  List<StudentModel> _getSourceStudents(List<StudentModel> allStudents) {
    return allStudents.where((s) {
      if (s.studentType != 'school') return false;
      if (s.status != 'active') return false;
      if (s.className != _sourceClass) return false;
      if (s.session != null && s.session!.isNotEmpty && s.session != _sourceSession) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = s.name.toLowerCase();
        final adm = s.admissionNumber.toLowerCase();
        final roll = (s.rollNumber ?? '').toLowerCase();
        if (!name.contains(q) && !adm.contains(q) && !roll.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  void _toggleSelectAll(List<StudentModel> list) {
    setState(() {
      final allSelected = list.every((s) => _selectedStudentIds.contains(s.id));
      if (allSelected) {
        for (final s in list) {
          _selectedStudentIds.remove(s.id);
        }
      } else {
        for (final s in list) {
          _selectedStudentIds.add(s.id);
        }
      }
    });
  }

  Future<void> _confirmAndPromote(List<StudentModel> allStudents) async {
    if (_selectedStudentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 1 student to promote!'), backgroundColor: AppColors.error),
      );
      return;
    }

    final isPassout = _targetClass == 'Passout / Alumni';
    final targetLabel = isPassout ? 'Passout / Alumni' : 'Class $_targetClass ($_targetSession)';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.school_rounded, color: Color(0xFF1F108E), size: 24),
            SizedBox(width: 10),
            Text('Confirm Promotion', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to promote ${_selectedStudentIds.length} student(s) to $targetLabel?',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1F108E).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• From: Class $_sourceClass ($_sourceSession)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('• To: $targetLabel', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1F108E))),
                  if (_updateFees) ...[
                    const SizedBox(height: 4),
                    if (_monthlyFeeCtrl.text.isNotEmpty)
                      Text('• New Monthly Fee: ₹${_monthlyFeeCtrl.text}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F108E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Promote Now', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isPromoting = true);
    try {
      final monthlyFee = _updateFees ? double.tryParse(_monthlyFeeCtrl.text.trim()) : null;
      final totalFee = _updateFees ? double.tryParse(_totalFeeCtrl.text.trim()) : null;

      final count = await ref.read(studentsProvider.notifier).promoteStudents(
        studentIds: _selectedStudentIds.toList(),
        targetClass: isPassout ? _sourceClass : _targetClass,
        targetSection: _targetSection == 'Same as current' ? null : _targetSection,
        targetSession: _targetSession,
        isPassout: isPassout,
        newMonthlyFee: monthlyFee,
        newTotalFee: totalFee,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Successfully promoted $count student(s) to $targetLabel!'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error promoting students: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isPromoting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allStudentsAsync = ref.watch(studentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '1-Click Student Promotion',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1F108E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: allStudentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allStudents) {
          final studentsList = _getSourceStudents(allStudents);
          final allSelected = studentsList.isNotEmpty && studentsList.every((s) => _selectedStudentIds.contains(s.id));

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Header Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF1F108E).withValues(alpha: 0.08), const Color(0xFF1F108E).withValues(alpha: 0.02)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF1F108E).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F108E),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.school_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Annual Class Promotion Engine',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1F108E)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Promote active students from one class/session to the next grade.',
                                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Configuration Card
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: cs.surface,
                      elevation: 0.5,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '1. Select Source & Target Classes',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                            ),
                            const SizedBox(height: 14),

                            // Source
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _sourceClass,
                                    decoration: InputDecoration(
                                      labelText: 'Current Class',
                                      filled: true,
                                      fillColor: cs.surfaceContainerHighest,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    items: _classes.map((c) => DropdownMenuItem(value: c, child: Text('Class $c'))).toList(),
                                    onChanged: (v) {
                                      if (v == null) return;
                                      setState(() {
                                        _sourceClass = v;
                                        _selectedStudentIds.clear();
                                        _autoMapTarget();
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _sourceSession,
                                    decoration: InputDecoration(
                                      labelText: 'Current Session',
                                      filled: true,
                                      fillColor: cs.surfaceContainerHighest,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    items: _sessions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                    onChanged: (v) {
                                      if (v == null) return;
                                      setState(() {
                                        _sourceSession = v;
                                        _selectedStudentIds.clear();
                                        _autoMapTarget();
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Arrow Indicator
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1F108E).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.arrow_downward_rounded, size: 14, color: Color(0xFF1F108E)),
                                    SizedBox(width: 4),
                                    Text(
                                      'PROMOTES TO',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF1F108E)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Target
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _targetClass,
                                    decoration: InputDecoration(
                                      labelText: 'Next Class / Status',
                                      filled: true,
                                      fillColor: cs.surfaceContainerHighest,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    items: [
                                      ..._classes.map((c) => DropdownMenuItem(value: c, child: Text('Class $c'))),
                                      const DropdownMenuItem(value: 'Passout / Alumni', child: Text('🎓 Passout / Alumni')),
                                    ],
                                    onChanged: (v) => setState(() => _targetClass = v ?? _targetClass),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _targetSession,
                                    decoration: InputDecoration(
                                      labelText: 'Target Session',
                                      filled: true,
                                      fillColor: cs.surfaceContainerHighest,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    items: _sessions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                    onChanged: (v) => setState(() => _targetSession = v ?? _targetSession),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            DropdownButtonFormField<String>(
                              value: _targetSection,
                              decoration: InputDecoration(
                                labelText: 'Target Section',
                                filled: true,
                                fillColor: cs.surfaceContainerHighest,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: _sections.map((sec) => DropdownMenuItem(value: sec, child: Text(sec))).toList(),
                              onChanged: (v) => setState(() => _targetSection = v ?? _targetSection),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Optional Fee Configuration Accordion
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: cs.surface,
                      elevation: 0.5,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '2. New Session Fee Structure (Optional)',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                ),
                                Switch(
                                  value: _updateFees,
                                  onChanged: (v) => setState(() => _updateFees = v),
                                  activeColor: const Color(0xFF1F108E),
                                ),
                              ],
                            ),
                            if (_updateFees) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _monthlyFeeCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Monthly Tuition Fee (₹)',
                                        filled: true,
                                        fillColor: cs.surfaceContainerHighest,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _totalFeeCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Total Annual Fee (₹)',
                                        filled: true,
                                        fillColor: cs.surfaceContainerHighest,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Student Selection Header
                    Row(
                      children: [
                        Text(
                          '3. Select Students (${studentsList.length} Available)',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Search & Select All Bar
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (v) => setState(() => _searchQuery = v),
                            decoration: InputDecoration(
                              hintText: 'Search by name, roll, ID…',
                              prefixIcon: const Icon(Icons.search, size: 18),
                              filled: true,
                              fillColor: cs.surfaceContainerHighest,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: studentsList.isEmpty ? null : () => _toggleSelectAll(studentsList),
                          icon: Icon(allSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 18),
                          label: Text(allSelected ? 'Deselect All' : 'Select All', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Student Cards List
                    if (studentsList.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            const Icon(Icons.people_outline_rounded, size: 40, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(
                              'No active students found in Class $_sourceClass ($_sourceSession)',
                              style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )
                    else
                      ...studentsList.map((s) {
                        final isSelected = _selectedStudentIds.contains(s.id);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: isSelected ? const Color(0xFF1F108E) : cs.outlineVariant.withValues(alpha: 0.4),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          color: isSelected ? const Color(0xFF1F108E).withValues(alpha: 0.04) : cs.surface,
                          child: CheckboxListTile(
                            value: isSelected,
                            activeColor: const Color(0xFF1F108E),
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedStudentIds.add(s.id);
                                } else {
                                  _selectedStudentIds.remove(s.id);
                                }
                              });
                            },
                            secondary: CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFF1F108E).withValues(alpha: 0.1),
                              child: Text(
                                s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1F108E)),
                              ),
                            ),
                            title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                            subtitle: Text(
                              'Adm No: ${s.admissionNumber} · Roll: ${s.rollNumber ?? '—'} · Sec: ${s.section ?? 'A'}',
                              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),

              // Bottom Sticky Promotion Action Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_selectedStudentIds.length} Selected',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                          ),
                          Text(
                            'To: ${_targetClass == 'Passout / Alumni' ? 'Passout' : 'Class $_targetClass'} ($_targetSession)',
                            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: (_selectedStudentIds.isEmpty || _isPromoting) ? null : () => _confirmAndPromote(allStudents),
                      icon: _isPromoting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.school_rounded, color: Colors.white, size: 18),
                      label: Text(
                        _isPromoting ? 'Promoting…' : 'Promote Class',
                        style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F108E),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
