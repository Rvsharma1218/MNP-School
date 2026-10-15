import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/app_utils.dart';
import '../../core/utils/file_saver.dart';
import '../../data/models/settings_model.dart';
import '../../data/services/providers.dart';

class TimetablePeriod {
  final int periodNumber;
  final String time;
  final String subject;
  final String teacher;
  final String room;
  final String type; // 'regular' | 'prayer' | 'lunch'

  TimetablePeriod({
    required this.periodNumber,
    required this.time,
    required this.subject,
    required this.teacher,
    this.room = '',
    this.type = 'regular',
  });

  bool get isPrayer =>
      type == 'prayer' ||
      subject.toLowerCase().contains('prayer') ||
      subject.toLowerCase().contains('assembly') ||
      subject.toLowerCase().contains('prarthana');

  bool get isLunch =>
      type == 'lunch' ||
      subject.toLowerCase().contains('lunch') ||
      subject.toLowerCase().contains('recess') ||
      subject.toLowerCase().contains('tiffin') ||
      subject.toLowerCase().contains('break');

  Map<String, dynamic> toJson() => {
    'periodNumber': periodNumber,
    'time': time,
    'subject': subject,
    'teacher': teacher,
    'room': room,
    'type': type,
  };

  factory TimetablePeriod.fromJson(Map<String, dynamic> map) {
    final subj = (map['subject'] ?? 'General').toString();
    String inferredType = map['type'] ?? 'regular';
    if (map['type'] == null) {
      final s = subj.toLowerCase();
      if (s.contains('prayer') || s.contains('assembly') || s.contains('prarthana')) {
        inferredType = 'prayer';
      } else if (s.contains('lunch') || s.contains('recess') || s.contains('tiffin') || s.contains('break')) {
        inferredType = 'lunch';
      }
    }
    return TimetablePeriod(
      periodNumber: map['periodNumber'] ?? 1,
      time: map['time'] ?? '09:00 AM - 09:45 AM',
      subject: subj,
      teacher: map['teacher'] ?? 'Teacher',
      room: map['room'] ?? '',
      type: inferredType,
    );
  }
}

class TimetableScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  final String? initialClass;
  const TimetableScreen({super.key, this.isEmbedded = false, this.initialClass});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> with SingleTickerProviderStateMixin {
  late TabController _dayTabCtrl;
  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  String _selectedClass = '1st';
  List<String> _allClasses = [];
  bool _loading = true;
  bool _generating = false;

  // View Mode: 'class' | 'master' | 'teacher'
  String _viewMode = 'class';
  bool get _isTeacherMode => _viewMode == 'teacher';
  bool get _isMasterMode => _viewMode == 'master';

  String _selectedTeacher = '';
  List<String> _availableTeachers = [];
  Map<String, Map<String, List<TimetablePeriod>>> _allClassesCache = {};

  Map<String, List<TimetablePeriod>> _currentClassSchedule = {};

  @override
  void initState() {
    super.initState();
    _dayTabCtrl = TabController(length: _days.length, vsync: this);
    _dayTabCtrl.addListener(() => setState(() {}));
    _initClassesAndLoad();
  }

  @override
  void dispose() {
    _dayTabCtrl.dispose();
    super.dispose();
  }

  Future<void> _initClassesAndLoad() async {
    final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
    _allClasses = settings.schoolClasses.isNotEmpty ? settings.schoolClasses : SettingsModel.defaultClasses;
    if (widget.initialClass != null && widget.initialClass!.isNotEmpty && _allClasses.contains(widget.initialClass)) {
      _selectedClass = widget.initialClass!;
    } else if (_allClasses.isNotEmpty && !_allClasses.contains(_selectedClass)) {
      _selectedClass = _allClasses.first;
    }
    await _loadScheduleForClass(_selectedClass);
    await _loadAllClassesCache();
  }

  Future<void> _loadScheduleForClass(String className) async {
    setState(() => _loading = true);
    _selectedClass = className;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('timetable_$_selectedClass');
      if (raw != null) {
        final Map<String, dynamic> decoded = jsonDecode(raw);
        _currentClassSchedule = decoded.map((day, list) {
          final items = (list as List).map((i) => TimetablePeriod.fromJson(i)).toList();
          return MapEntry(day, items);
        });
      } else {
        _currentClassSchedule = _getDefaultSchedule(className);
      }
    } catch (_) {
      _currentClassSchedule = _getDefaultSchedule(className);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveSchedule() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mapToSave = _currentClassSchedule.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()));
      await prefs.setString('timetable_$_selectedClass', jsonEncode(mapToSave));
      _loadAllClassesCache();
    } catch (e) {
      debugPrint('Error saving timetable: $e');
    }
  }

  Future<void> _loadAllClassesCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, Map<String, List<TimetablePeriod>>> allData = {};
      final Set<String> teachers = {};

      for (final cls in _allClasses) {
        final raw = prefs.getString('timetable_$cls');
        Map<String, List<TimetablePeriod>> sched;
        if (raw != null) {
          try {
            final Map<String, dynamic> decoded = jsonDecode(raw);
            sched = decoded.map((day, list) {
              final items = (list as List).map((i) => TimetablePeriod.fromJson(i)).toList();
              return MapEntry(day, items);
            });
          } catch (_) {
            sched = _getDefaultSchedule(cls);
          }
        } else {
          sched = _getDefaultSchedule(cls);
        }
        allData[cls] = sched;
        for (final list in sched.values) {
          for (final p in list) {
            if (p.isPrayer || p.isLunch) continue;
            final t = p.teacher.trim();
            if (t.isNotEmpty && t.toLowerCase() != 'teacher' && t.toLowerCase() != 'faculty') {
              teachers.add(t);
            }
          }
        }
      }
      _allClassesCache = allData;
      _availableTeachers = teachers.toList()..sort();
      if (_availableTeachers.isNotEmpty && (_selectedTeacher.isEmpty || !_availableTeachers.contains(_selectedTeacher))) {
        _selectedTeacher = _availableTeachers.first;
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  List<Map<String, dynamic>> _getTeacherScheduleForDay(String teacherName, String day) {
    final List<Map<String, dynamic>> result = [];
    if (teacherName.isEmpty) return result;

    _allClassesCache.forEach((cls, dayMap) {
      final periods = dayMap[day] ?? [];
      for (final p in periods) {
        if (p.isPrayer || p.isLunch) continue;
        if (p.teacher.trim().toLowerCase() == teacherName.trim().toLowerCase()) {
          result.add({
            'className': cls,
            'period': p,
          });
        }
      }
    });

    result.sort((a, b) {
      final pA = a['period'] as TimetablePeriod;
      final pB = b['period'] as TimetablePeriod;
      return pA.periodNumber.compareTo(pB.periodNumber);
    });

    return result;
  }

  bool _hasTimeConflict(List<Map<String, dynamic>> schedule) {
    final times = <String>{};
    for (final item in schedule) {
      final p = item['period'] as TimetablePeriod;
      if (times.contains(p.time)) return true;
      times.add(p.time);
    }
    return false;
  }

  Map<String, List<Map<String, dynamic>>> _getMasterClashesForDay(String day) {
    final Map<String, List<Map<String, dynamic>>> map = {};
    _allClassesCache.forEach((cls, dayMap) {
      final list = dayMap[day] ?? [];
      for (final p in list) {
        if (p.isPrayer || p.isLunch) continue;
        final t = p.teacher.trim();
        if (t.isEmpty || t.toLowerCase() == 'teacher' || t.toLowerCase() == 'faculty') continue;
        final key = '${t.toLowerCase()}__${p.periodNumber}';
        map.putIfAbsent(key, () => []).add({'className': cls, 'period': p, 'teacher': t});
      }
    });
    return Map.fromEntries(map.entries.where((e) => e.value.length > 1));
  }

  TimeOfDay _parseTimeOfDay(String str, {TimeOfDay defaultTime = const TimeOfDay(hour: 9, minute: 0)}) {
    try {
      final clean = str.trim().toUpperCase();
      final isPM = clean.contains('PM');
      final isAM = clean.contains('AM');
      final numPart = clean.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = numPart.split(':');
      if (parts.length >= 2) {
        int h = int.parse(parts[0].trim());
        int m = int.parse(parts[1].trim());
        if (isPM && h < 12) h += 12;
        if (isAM && h == 12) h = 0;
        return TimeOfDay(hour: h, minute: m);
      }
    } catch (_) {}
    return defaultTime;
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final m = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    final hStr = h.toString().padLeft(2, '0');
    return '$hStr:$m $period';
  }

  TimeOfDay _addMinutes(TimeOfDay start, int mins) {
    int totalMin = (start.hour * 60 + start.minute + mins) % (24 * 60);
    if (totalMin < 0) totalMin += 24 * 60;
    return TimeOfDay(hour: totalMin ~/ 60, minute: totalMin % 60);
  }

  int _calcDurationMinutes(TimeOfDay start, TimeOfDay end) {
    int startMin = start.hour * 60 + start.minute;
    int endMin = end.hour * 60 + end.minute;
    if (endMin < startMin) endMin += 24 * 60;
    return endMin - startMin;
  }

  Map<String, List<TimetablePeriod>> _getDefaultSchedule(String cls) {
    return {
      for (final d in _days)
        d: [
          TimetablePeriod(periodNumber: 0, time: '08:30 AM - 09:00 AM', subject: 'Morning Prayer & Assembly', teacher: 'All Faculty', room: 'Ground', type: 'prayer'),
          TimetablePeriod(periodNumber: 1, time: '09:00 AM - 09:45 AM', subject: 'Hindi', teacher: 'Ramesh Sir', room: '101', type: 'regular'),
          TimetablePeriod(periodNumber: 2, time: '09:45 AM - 10:30 AM', subject: 'English', teacher: 'Pooja Ma\'am', room: '101', type: 'regular'),
          TimetablePeriod(periodNumber: 3, time: '10:45 AM - 11:30 AM', subject: 'Mathematics', teacher: 'Vikram Sir', room: '101', type: 'regular'),
          TimetablePeriod(periodNumber: 4, time: '11:30 AM - 12:15 PM', subject: 'Science', teacher: 'Anjali Ma\'am', room: '101', type: 'regular'),
          TimetablePeriod(periodNumber: 0, time: '12:15 PM - 01:00 PM', subject: 'Lunch Break & Recess', teacher: 'Duty Staff', room: 'Cafeteria', type: 'lunch'),
          TimetablePeriod(periodNumber: 5, time: '01:00 PM - 01:45 PM', subject: 'Social Studies', teacher: 'Sanjay Sir', room: '101', type: 'regular'),
          TimetablePeriod(periodNumber: 6, time: '01:45 PM - 02:30 PM', subject: 'Computer', teacher: 'Amit Sir', room: 'Lab 1', type: 'regular'),
        ],
    };
  }

  String get _currentDay => _days[_dayTabCtrl.index];

  Future<void> _openCopyScheduleDialog() async {
    final otherClasses = _allClasses.where((c) => c != _selectedClass).toList();
    if (otherClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other classes available to copy to.')),
      );
      return;
    }

    final selectedTargets = Set<String>.from(otherClasses);
    String scope = 'all_days';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.copy_all_rounded, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 10),
                const Text('Copy Timetable', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Copy Class $_selectedClass timetable to other classes in 1-click.',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF1E3A8A), fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('SCOPE TO COPY:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: 'all_days',
                      groupValue: scope,
                      title: const Text('Whole Week (All 6 Days)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: const Text('Replaces entire weekly schedule', style: TextStyle(fontSize: 11)),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => scope = val);
                      },
                    ),
                    RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: 'current_day',
                      groupValue: scope,
                      title: Text('Current Day Only ($_currentDay)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: Text('Replaces only $_currentDay for targets', style: const TextStyle(fontSize: 11)),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => scope = val);
                      },
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('TARGET CLASSES (${selectedTargets.length}):', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              if (selectedTargets.length == otherClasses.length) {
                                selectedTargets.clear();
                              } else {
                                selectedTargets.addAll(otherClasses);
                              }
                            });
                          },
                          child: Text(
                            selectedTargets.length == otherClasses.length ? 'Deselect All' : 'Select All',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: otherClasses.map((cls) {
                        final isSel = selectedTargets.contains(cls);
                        return FilterChip(
                          label: Text('Class $cls'),
                          selected: isSel,
                          selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                          checkmarkColor: const Color(0xFF2563EB),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSel ? const Color(0xFF1E3A8A) : const Color(0xFF334155),
                          ),
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedTargets.add(cls);
                              } else {
                                selectedTargets.remove(cls);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: selectedTargets.isEmpty
                    ? null
                    : () async {
                        final prefs = await SharedPreferences.getInstance();
                        for (final target in selectedTargets) {
                          if (scope == 'all_days') {
                            final mapToSave = _currentClassSchedule.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()));
                            await prefs.setString('timetable_$target', jsonEncode(mapToSave));
                          } else {
                            Map<String, dynamic> existingDecoded = {};
                            final raw = prefs.getString('timetable_$target');
                            if (raw != null) {
                              try { existingDecoded = jsonDecode(raw); } catch (_) {}
                            }
                            existingDecoded[_currentDay] = (_currentClassSchedule[_currentDay] ?? []).map((e) => e.toJson()).toList();
                            await prefs.setString('timetable_$target', jsonEncode(existingDecoded));
                          }
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Timetable copied to ${selectedTargets.length} classes successfully!'),
                              backgroundColor: const Color(0xFF059669),
                            ),
                          );
                          _loadAllClassesCache();
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Copy Schedule Now'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _addOrEditPeriodDialog({TimetablePeriod? existing, int? index, String presetType = 'regular'}) {
    String slotType = existing?.type ?? presetType;
    final periodNumCtrl = TextEditingController(
      text: existing != null
          ? '${existing.periodNumber}'
          : (slotType == 'prayer' || slotType == 'lunch' ? '0' : '${(_currentClassSchedule[_currentDay]?.where((p) => !p.isPrayer && !p.isLunch).length ?? 0) + 1}'),
    );

    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 9, minute: 45);

    if (existing != null && existing.time.contains('-')) {
      final parts = existing.time.split('-');
      startTime = _parseTimeOfDay(parts[0], defaultTime: const TimeOfDay(hour: 9, minute: 0));
      endTime = _parseTimeOfDay(parts[1], defaultTime: const TimeOfDay(hour: 9, minute: 45));
    } else if (slotType == 'prayer') {
      startTime = const TimeOfDay(hour: 8, minute: 30);
      endTime = const TimeOfDay(hour: 9, minute: 0);
    } else if (slotType == 'lunch') {
      startTime = const TimeOfDay(hour: 12, minute: 15);
      endTime = const TimeOfDay(hour: 13, minute: 0);
    } else {
      final existingPeriods = _currentClassSchedule[_currentDay] ?? [];
      if (existingPeriods.isNotEmpty) {
        final lastP = existingPeriods.last;
        if (lastP.time.contains('-')) {
          final parts = lastP.time.split('-');
          startTime = _parseTimeOfDay(parts[1], defaultTime: const TimeOfDay(hour: 9, minute: 45));
          endTime = _addMinutes(startTime, 45);
        }
      }
    }

    final subjectCtrl = TextEditingController(
      text: existing?.subject ?? (slotType == 'prayer' ? 'Morning Prayer & Assembly' : slotType == 'lunch' ? 'Lunch Break & Recess' : ''),
    );
    final teacherCtrl = TextEditingController(
      text: existing?.teacher ?? (slotType == 'prayer' ? 'All Faculty' : slotType == 'lunch' ? 'Duty Staff' : ''),
    );
    final roomCtrl = TextEditingController(
      text: existing?.room ?? (slotType == 'prayer' ? 'Ground' : slotType == 'lunch' ? 'Cafeteria' : '101'),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final durationMins = _calcDurationMinutes(startTime, endTime);
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: slotType == 'prayer'
                        ? const Color(0xFFD97706).withValues(alpha: 0.1)
                        : slotType == 'lunch'
                        ? const Color(0xFF059669).withValues(alpha: 0.1)
                        : const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    slotType == 'prayer'
                        ? Icons.wb_sunny_rounded
                        : slotType == 'lunch'
                        ? Icons.restaurant_rounded
                        : Icons.schedule_rounded,
                    color: slotType == 'prayer'
                        ? const Color(0xFFD97706)
                        : slotType == 'lunch'
                        ? const Color(0xFF059669)
                        : const Color(0xFF2563EB),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  existing != null ? 'Edit Slot' : 'Add Timetable Slot',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Class $_selectedClass | $_currentDay', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B), fontSize: 13)),
                  const SizedBox(height: 12),

                  // Slot Type Preset Selector Chips
                  const Text('SLOT TYPE:', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Regular'),
                          selected: slotType == 'regular',
                          selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: slotType == 'regular' ? const Color(0xFF1E3A8A) : const Color(0xFF475569),
                          ),
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() {
                                slotType = 'regular';
                                subjectCtrl.text = '';
                                teacherCtrl.text = '';
                                roomCtrl.text = '101';
                                startTime = const TimeOfDay(hour: 9, minute: 0);
                                endTime = const TimeOfDay(hour: 9, minute: 45);
                                periodNumCtrl.text = '${(_currentClassSchedule[_currentDay]?.where((p) => !p.isPrayer && !p.isLunch).length ?? 0) + 1}';
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('☀️ Prayer'),
                          selected: slotType == 'prayer',
                          selectedColor: const Color(0xFFD97706).withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: slotType == 'prayer' ? const Color(0xFF92400E) : const Color(0xFF475569),
                          ),
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() {
                                slotType = 'prayer';
                                subjectCtrl.text = 'Morning Prayer & Assembly';
                                teacherCtrl.text = 'All Faculty';
                                roomCtrl.text = 'Ground';
                                startTime = const TimeOfDay(hour: 8, minute: 30);
                                endTime = const TimeOfDay(hour: 9, minute: 0);
                                periodNumCtrl.text = '0';
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('🍱 Lunch'),
                          selected: slotType == 'lunch',
                          selectedColor: const Color(0xFF059669).withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: slotType == 'lunch' ? const Color(0xFF065F46) : const Color(0xFF475569),
                          ),
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() {
                                slotType = 'lunch';
                                subjectCtrl.text = 'Lunch Break & Recess';
                                teacherCtrl.text = 'Duty Staff';
                                roomCtrl.text = 'Cafeteria';
                                startTime = const TimeOfDay(hour: 12, minute: 15);
                                endTime = const TimeOfDay(hour: 13, minute: 0);
                                periodNumCtrl.text = '0';
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Native Time Dialer Box (Interactive Clock Picker)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('TIMING (CLOCK DIALER)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Text(
                                '$durationMins mins',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            // Start Time Tap target
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: dialogCtx,
                                    initialTime: startTime,
                                    helpText: 'SELECT START TIME',
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      final curDur = _calcDurationMinutes(startTime, endTime);
                                      startTime = picked;
                                      endTime = _addMinutes(startTime, curDur > 0 ? curDur : 45);
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.access_time_filled_rounded, size: 13, color: Color(0xFF2563EB)),
                                          SizedBox(width: 4),
                                          Text('START', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatTimeOfDay(startTime),
                                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.arrow_forward_rounded, color: Color(0xFF94A3B8), size: 16),
                            ),
                            // End Time Tap target
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: dialogCtx,
                                    initialTime: endTime,
                                    helpText: 'SELECT END TIME',
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      endTime = picked;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.access_time_filled_rounded, size: 13, color: Color(0xFF059669)),
                                          SizedBox(width: 4),
                                          Text('END', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatTimeOfDay(endTime),
                                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Quick duration adder buttons
                        Row(
                          children: [
                            const Text('ADD:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                            const SizedBox(width: 6),
                            ...[20, 30, 40, 45, 60].map((mins) {
                              final isCurrent = durationMins == mins;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () {
                                    setDialogState(() {
                                      endTime = _addMinutes(startTime, mins);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isCurrent ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '+${mins}m',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: isCurrent ? Colors.white : const Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  TextField(
                    controller: subjectCtrl,
                    decoration: InputDecoration(
                      labelText: 'Subject / Activity Name *',
                      prefixIcon: const Icon(Icons.book_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: teacherCtrl,
                    decoration: InputDecoration(
                      labelText: 'Teacher / Faculty Name',
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: roomCtrl,
                    decoration: InputDecoration(
                      labelText: 'Room / Ground (Optional)',
                      prefixIcon: const Icon(Icons.meeting_room_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (subjectCtrl.text.trim().isEmpty) return;
                  final formattedTime = '${_formatTimeOfDay(startTime)} - ${_formatTimeOfDay(endTime)}';
                  final p = TimetablePeriod(
                    periodNumber: int.tryParse(periodNumCtrl.text.trim()) ?? (slotType == 'prayer' || slotType == 'lunch' ? 0 : 1),
                    time: formattedTime,
                    subject: subjectCtrl.text.trim(),
                    teacher: teacherCtrl.text.trim().isNotEmpty
                        ? teacherCtrl.text.trim()
                        : (slotType == 'prayer' ? 'All Faculty' : slotType == 'lunch' ? 'Duty Staff' : 'Teacher'),
                    room: roomCtrl.text.trim(),
                    type: slotType,
                  );

                  setState(() {
                    final list = List<TimetablePeriod>.from(_currentClassSchedule[_currentDay] ?? []);
                    if (existing != null && index != null && index < list.length) {
                      list[index] = p;
                    } else {
                      list.add(p);
                    }
                    list.sort((a, b) {
                      if (a.isPrayer) return -1;
                      if (b.isPrayer) return 1;
                      if (a.isLunch && !b.isPrayer && b.periodNumber <= 4) return 1;
                      if (b.isLunch && !a.isPrayer && a.periodNumber <= 4) return -1;
                      return a.periodNumber.compareTo(b.periodNumber);
                    });
                    _currentClassSchedule[_currentDay] = list;
                  });

                  _saveSchedule();
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(existing != null ? 'Update' : 'Save Slot'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deletePeriod(int index) {
    setState(() {
      final list = List<TimetablePeriod>.from(_currentClassSchedule[_currentDay] ?? []);
      if (index < list.length) {
        list.removeAt(index);
        _currentClassSchedule[_currentDay] = list;
      }
    });
    _saveSchedule();
  }

  /// One-Tap Instant PDF Sharing via WhatsApp/Mail
  Future<void> _shareTimetablePDF({bool allSchoolClasses = false}) async {
    setState(() => _generating = true);
    final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
    final schoolName = settings.schoolName.isNotEmpty ? settings.schoolName : 'MISSION NAVODAYA PUBLIC SCHOOL';

    try {
      final bytes = await _buildPdfBytes(allSchoolClasses: allSchoolClasses, settings: settings, schoolName: schoolName);
      final filename = allSchoolClasses ? 'All_Classes_Timetable.pdf' : 'Timetable_Class_$_selectedClass.pdf';

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$filename')..writeAsBytesSync(bytes);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: '$schoolName - ${allSchoolClasses ? "All Classes Timetable Booklet" : "Class $_selectedClass Weekly Timetable"}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sharing PDF: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  /// Download and Save to Device Storage
  Future<void> _exportTimetablePDF({bool allSchoolClasses = false}) async {
    setState(() => _generating = true);
    final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
    final schoolName = settings.schoolName.isNotEmpty ? settings.schoolName : 'MISSION NAVODAYA PUBLIC SCHOOL';

    try {
      final bytes = await _buildPdfBytes(allSchoolClasses: allSchoolClasses, settings: settings, schoolName: schoolName);
      final filename = allSchoolClasses ? 'All_Classes_Timetable_Booklet.pdf' : 'Timetable_Class_$_selectedClass.pdf';

      if (mounted) {
        await FileSaver.showSaveShareSheet(
          context,
          bytes: bytes,
          filename: filename,
          subject: '$schoolName - Timetable',
          category: FileCategory.timetable,
          schoolName: schoolName,
          icon: Icons.schedule_rounded,
          color: const Color(0xFF2563EB),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  /// Export Master Timetable (All Classes on One Page/Document)
  Future<void> _exportMasterTimetablePDF({bool share = false}) async {
    setState(() => _generating = true);
    final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
    final schoolName = settings.schoolName.isNotEmpty ? settings.schoolName : 'MISSION NAVODAYA PUBLIC SCHOOL';

    try {
      final bytes = await _buildMasterGridPdfBytes(settings: settings, schoolName: schoolName);
      final filename = 'Master_Timetable_All_Classes_$_currentDay.pdf';

      if (share) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/$filename')..writeAsBytesSync(bytes);
        await Share.shareXFiles(
          [XFile(tempFile.path)],
          text: '$schoolName - Master Timetable All Classes ($_currentDay)',
        );
      } else {
        if (mounted) {
          await FileSaver.showSaveShareSheet(
            context,
            bytes: bytes,
            filename: filename,
            subject: '$schoolName - Master Timetable',
            category: FileCategory.timetable,
            schoolName: schoolName,
            icon: Icons.grid_view_rounded,
            color: const Color(0xFF1E3A8A),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error exporting Master PDF: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  String _getPeriodTimeLabel(int periodNum, [Map<String, List<TimetablePeriod>>? schedule]) {
    if (schedule != null) {
      for (final list in schedule.values) {
        for (final p in list) {
          if (!p.isPrayer && !p.isLunch && p.periodNumber == periodNum && p.time.isNotEmpty) {
            return p.time.replaceAll(' AM', '').replaceAll(' PM', '').trim();
          }
        }
      }
    }
    switch (periodNum) {
      case 1: return '09:00 - 09:45';
      case 2: return '09:45 - 10:30';
      case 3: return '10:45 - 11:30';
      case 4: return '11:30 - 12:15';
      case 5: return '01:00 - 01:45';
      case 6: return '01:45 - 02:30';
      default: return '';
    }
  }

  Future<List<int>> _buildPdfBytes({required bool allSchoolClasses, required SettingsModel settings, required String schoolName}) async {
    final nowStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final logoBytes = await AppUtils.loadAppImageBytes(settings.logoPath);
    final sigBytes = await AppUtils.loadAppImageBytes(settings.principalSignature);
    final stampBytes = await AppUtils.loadAppImageBytes(settings.schoolStamp);
    final pw.MemoryImage? logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;
    final pw.MemoryImage? sigImage = sigBytes != null ? pw.MemoryImage(sigBytes) : null;
    final pw.MemoryImage? stampImage = stampBytes != null ? pw.MemoryImage(stampBytes) : null;

    final pdf = pw.Document();

    if (allSchoolClasses) {
      final prefs = await SharedPreferences.getInstance();
      for (final cls in _allClasses) {
        Map<String, List<TimetablePeriod>> clsSchedule = {};
        final raw = prefs.getString('timetable_$cls');
        if (raw != null) {
          try {
            final Map<String, dynamic> decoded = jsonDecode(raw);
            clsSchedule = decoded.map((day, list) {
              final items = (list as List).map((i) => TimetablePeriod.fromJson(i)).toList();
              return MapEntry(day, items);
            });
          } catch (_) {
            clsSchedule = _getDefaultSchedule(cls);
          }
        } else {
          clsSchedule = _getDefaultSchedule(cls);
        }
        pdf.addPage(_buildTimetablePage(schoolName: schoolName, session: settings.currentSession, className: cls, schedule: clsSchedule, timestamp: nowStr, logo: logoImage, sig: sigImage, stamp: stampImage, stampScale: settings.stampScale, signatureScale: settings.signatureScale));
      }
    } else {
      pdf.addPage(_buildTimetablePage(schoolName: schoolName, session: settings.currentSession, className: _selectedClass, schedule: _currentClassSchedule, timestamp: nowStr, logo: logoImage, sig: sigImage, stamp: stampImage, stampScale: settings.stampScale, signatureScale: settings.signatureScale));
    }

    return await pdf.save();
  }

  pw.Page _buildTimetablePage({
    required String schoolName,
    required String session,
    required String className,
    required Map<String, List<TimetablePeriod>> schedule,
    required String timestamp,
    pw.MemoryImage? logo,
    pw.MemoryImage? sig,
    pw.MemoryImage? stamp,
    double stampScale = 1.0,
    double signatureScale = 1.0,
  }) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      build: (pw.Context ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header with Logo
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 14),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#1E3A8A'),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      if (logo != null) ...[
                        pw.Container(width: 32, height: 32, child: pw.Image(logo, fit: pw.BoxFit.contain)),
                        pw.SizedBox(width: 8),
                      ],
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(schoolName.toUpperCase(), style: pw.TextStyle(color: PdfColors.white, fontSize: 15, fontWeight: pw.FontWeight.bold)),
                          pw.Text('WEEKLY CLASS ROUTINE / TIME TABLE', style: pw.TextStyle(color: PdfColor.fromHex('#FDE047'), fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('CLASS: $className', style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Session: ${session.isNotEmpty ? session : "2026-27"}', style: const pw.TextStyle(color: PdfColors.white, fontSize: 8)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),

            // Timetable Table with Prayer and Lunch Columns
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#1E3A8A')),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('DAY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.white)),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 3),
                      color: PdfColor.fromHex('#D97706'),
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text('PRAYER', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: PdfColors.white)),
                          pw.SizedBox(height: 1),
                          pw.Text('08:30 - 09:00', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 6, color: PdfColors.white)),
                        ],
                      ),
                    ),
                    for (int p = 1; p <= 4; p++)
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 3),
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Text('PERIOD $p', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white)),
                            pw.SizedBox(height: 1),
                            pw.Text(_getPeriodTimeLabel(p, schedule), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 6, color: PdfColors.white)),
                          ],
                        ),
                      ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 3),
                      color: PdfColor.fromHex('#059669'),
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text('LUNCH', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: PdfColors.white)),
                          pw.SizedBox(height: 1),
                          pw.Text('12:15 - 01:00', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 6, color: PdfColors.white)),
                        ],
                      ),
                    ),
                    for (int p = 5; p <= 6; p++)
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 3),
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Text('PERIOD $p', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white)),
                            pw.SizedBox(height: 1),
                            pw.Text(_getPeriodTimeLabel(p, schedule), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 6, color: PdfColors.white)),
                          ],
                        ),
                      ),
                  ],
                ),
                for (final day in _days)
                  pw.TableRow(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(5),
                        color: PdfColors.grey100,
                        child: pw.Text(day, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                      ),
                      // Prayer Cell
                      pw.Container(
                        padding: const pw.EdgeInsets.all(3),
                        color: PdfColor.fromHex('#FEF3C7'),
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Text('Prayer', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColor.fromHex('#92400E'))),
                            pw.Text('Assembly', style: pw.TextStyle(fontSize: 6.5, color: PdfColor.fromHex('#B45309'))),
                          ],
                        ),
                      ),
                      for (int p = 1; p <= 4; p++)
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(3),
                          child: _buildPdfPeriodCell(schedule[day] ?? [], p),
                        ),
                      // Lunch Cell
                      pw.Container(
                        padding: const pw.EdgeInsets.all(3),
                        color: PdfColor.fromHex('#D1FAE5'),
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Text('Lunch', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColor.fromHex('#065F46'))),
                            pw.Text('Recess', style: pw.TextStyle(fontSize: 6.5, color: PdfColor.fromHex('#047857'))),
                          ],
                        ),
                      ),
                      for (int p = 5; p <= 6; p++)
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(3),
                          child: _buildPdfPeriodCell(schedule[day] ?? [], p),
                        ),
                    ],
                  ),
              ],
            ),
            pw.Spacer(),

            // Footer with Principal Signature and Timestamp
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Generated: $timestamp', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                // Director Sign & Official Stamp (Signature layered inside/over stamp)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      width: 130,
                      height: 42,
                      child: pw.Stack(
                        alignment: pw.Alignment.center,
                        children: [
                          if (stamp != null)
                            pw.Opacity(
                              opacity: 0.88,
                              child: pw.Image(stamp, width: 36 * stampScale, height: 36 * stampScale, fit: pw.BoxFit.contain),
                            ),
                          if (sig != null)
                            pw.Image(sig, width: 80 * signatureScale, height: 22 * signatureScale, fit: pw.BoxFit.contain),
                        ],
                      ),
                    ),
                    pw.Container(width: 120, height: 1, color: PdfColors.grey600),
                    pw.SizedBox(height: 2),
                    pw.Text('Director Sign', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E3A8A'))),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  pw.Widget _buildPdfPeriodCell(List<TimetablePeriod> list, int periodNum) {
    final matches = list.where((e) => !e.isPrayer && !e.isLunch && e.periodNumber == periodNum);
    if (matches.isEmpty) {
      return pw.Center(child: pw.Text('-', style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8.5)));
    }
    final p = matches.first;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Text(p.subject, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 1),
        pw.Text(p.teacher, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey800), textAlign: pw.TextAlign.center),
      ],
    );
  }

  Future<List<int>> _buildMasterGridPdfBytes({required SettingsModel settings, required String schoolName}) async {
    final nowStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final logoBytes = await AppUtils.loadAppImageBytes(settings.logoPath);
    final sigBytes = await AppUtils.loadAppImageBytes(settings.principalSignature);
    final stampBytes = await AppUtils.loadAppImageBytes(settings.schoolStamp);
    final pw.MemoryImage? logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;
    final pw.MemoryImage? sigImage = sigBytes != null ? pw.MemoryImage(sigBytes) : null;
    final pw.MemoryImage? stampImage = stampBytes != null ? pw.MemoryImage(stampBytes) : null;

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(18),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#1E3A8A'),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        if (logoImage != null) ...[
                          pw.Container(width: 28, height: 28, child: pw.Image(logoImage, fit: pw.BoxFit.contain)),
                          pw.SizedBox(width: 8),
                        ],
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(schoolName.toUpperCase(), style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                            pw.Text('MASTER SCHOOL TIMETABLE — ALL CLASSES ($_currentDay)', style: pw.TextStyle(color: PdfColor.fromHex('#FDE047'), fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    pw.Text('Session: ${settings.currentSession.isNotEmpty ? settings.currentSession : "2026-27"}', style: const pw.TextStyle(color: PdfColors.white, fontSize: 8)),
                  ],
                ),
              ),
              pw.SizedBox(height: 7),

              // Master Grid Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('#1E3A8A')),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text('CLASS', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: PdfColors.white)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                        color: PdfColor.fromHex('#D97706'),
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Text('PRAYER', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5, color: PdfColors.white)),
                            pw.SizedBox(height: 1),
                            pw.Text('08:30 - 09:00', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 5, color: PdfColors.white)),
                          ],
                        ),
                      ),
                      for (int p = 1; p <= 4; p++)
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                          child: pw.Column(
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.Text('PERIOD $p', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7, color: PdfColors.white)),
                              pw.SizedBox(height: 0.5),
                              pw.Text(_getPeriodTimeLabel(p), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.white)),
                            ],
                          ),
                        ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                        color: PdfColor.fromHex('#059669'),
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Text('LUNCH', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5, color: PdfColors.white)),
                            pw.SizedBox(height: 1),
                            pw.Text('12:15 - 01:00', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 5, color: PdfColors.white)),
                          ],
                        ),
                      ),
                      for (int p = 5; p <= 6; p++)
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                          child: pw.Column(
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.Text('PERIOD $p', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7, color: PdfColors.white)),
                              pw.SizedBox(height: 0.5),
                              pw.Text(_getPeriodTimeLabel(p), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.white)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  for (final cls in _allClasses)
                    _buildMasterPdfRow(cls, _allClassesCache[cls]?[_currentDay] ?? []),
                ],
              ),
              pw.Spacer(),

              // Footer with Director Sign and Stamp
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Generated: $nowStr', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 130,
                        height: 40,
                        child: pw.Stack(
                          alignment: pw.Alignment.center,
                          children: [
                            if (stampImage != null)
                              pw.Opacity(
                                opacity: 0.88,
                                child: pw.Image(stampImage, width: 34 * settings.stampScale, height: 34 * settings.stampScale, fit: pw.BoxFit.contain),
                              ),
                            if (sigImage != null)
                              pw.Image(sigImage, width: 78 * settings.signatureScale, height: 20 * settings.signatureScale, fit: pw.BoxFit.contain),
                          ],
                        ),
                      ),
                      pw.Container(width: 120, height: 0.8, color: PdfColors.grey600),
                      pw.SizedBox(height: 1.5),
                      pw.Text('Director Sign', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E3A8A'))),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  pw.TableRow _buildMasterPdfRow(String cls, List<TimetablePeriod> list) {
    return pw.TableRow(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 2),
          color: PdfColor.fromHex('#EEF2FF'),
          child: pw.Center(
            child: pw.Text('Class $cls', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7, color: PdfColor.fromHex('#1E3A8A'))),
          ),
        ),
        // Prayer
        pw.Container(
          padding: const pw.EdgeInsets.all(1.5),
          color: PdfColor.fromHex('#FEF3C7'),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('Prayer', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6, color: PdfColor.fromHex('#92400E'))),
              pw.Text('All Staff', style: pw.TextStyle(fontSize: 5, color: PdfColor.fromHex('#B45309'))),
            ],
          ),
        ),
        // Periods 1 to 4
        for (int p = 1; p <= 4; p++)
          pw.Padding(
            padding: const pw.EdgeInsets.all(1.5),
            child: _buildPdfPeriodCell(list, p),
          ),
        // Lunch
        pw.Container(
          padding: const pw.EdgeInsets.all(1.5),
          color: PdfColor.fromHex('#D1FAE5'),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('Lunch', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6, color: PdfColor.fromHex('#065F46'))),
              pw.Text('Recess', style: pw.TextStyle(fontSize: 5, color: PdfColor.fromHex('#047857'))),
            ],
          ),
        ),
        // Periods 5 to 6
        for (int p = 5; p <= 6; p++)
          pw.Padding(
            padding: const pw.EdgeInsets.all(1.5),
            child: _buildPdfPeriodCell(list, p),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final periods = _currentClassSchedule[_currentDay] ?? [];
    final teacherItems = _isTeacherMode ? _getTeacherScheduleForDay(_selectedTeacher, _currentDay) : <Map<String, dynamic>>[];
    final hasConflict = _isTeacherMode && _hasTimeConflict(teacherItems);
    final masterClashes = _isMasterMode ? _getMasterClashesForDay(_currentDay) : <String, List<Map<String, dynamic>>>{};

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _isMasterMode
              ? 'Master Timetable'
              : _isTeacherMode
              ? 'Teacher Schedule'
              : 'Weekly Timetable',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_rounded, color: Colors.white),
            tooltip: 'Copy Routine to Other Classes',
            onPressed: () => _openCopyScheduleDialog(),
          ),
          IconButton(
            icon: _generating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.share_rounded, color: Colors.white),
            tooltip: 'Share Timetable (PDF)',
            onPressed: _generating
                ? null
                : () {
                    if (_isMasterMode) {
                      _exportMasterTimetablePDF(share: true);
                    } else {
                      _shareTimetablePDF(allSchoolClasses: false);
                    }
                  },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            tooltip: 'Download PDF',
            onSelected: (val) {
              if (val == 'single') _exportTimetablePDF(allSchoolClasses: false);
              if (val == 'all') _exportTimetablePDF(allSchoolClasses: true);
              if (val == 'master') _exportMasterTimetablePDF(share: false);
              if (val == 'share_all') _shareTimetablePDF(allSchoolClasses: true);
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'single',
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF2563EB), size: 18),
                    const SizedBox(width: 8),
                    Text('Download Class $_selectedClass PDF'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'master',
                child: Row(
                  children: [
                    Icon(Icons.grid_view_rounded, color: Color(0xFFD97706), size: 18),
                    SizedBox(width: 8),
                    Text('Download Master Grid (All Classes)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(Icons.collections_bookmark_outlined, color: Color(0xFF0284C7), size: 18),
                    SizedBox(width: 8),
                    Text('Download All Classes Booklet (PDF)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share_all',
                child: Row(
                  children: [
                    Icon(Icons.share_outlined, color: Color(0xFF059669), size: 18),
                    SizedBox(width: 8),
                    Text('Share All Classes Booklet (PDF)'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 3-Way View Mode Switcher
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  // Tab 1: Class Routine
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _viewMode = 'class'),
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: _viewMode == 'class' ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _viewMode == 'class' ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))] : null,
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.class_outlined, size: 15, color: _viewMode == 'class' ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text('Class', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _viewMode == 'class' ? const Color(0xFF1E3A8A) : const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Tab 2: Master All-Classes Grid
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        setState(() => _viewMode = 'master');
                        _loadAllClassesCache();
                      },
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: _viewMode == 'master' ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _viewMode == 'master' ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))] : null,
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.grid_view_rounded, size: 15, color: _viewMode == 'master' ? const Color(0xFFD97706) : const Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text('Master Grid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _viewMode == 'master' ? const Color(0xFF92400E) : const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Tab 3: Teacher Schedule Inspector
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        setState(() => _viewMode = 'teacher');
                        _loadAllClassesCache();
                      },
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: _viewMode == 'teacher' ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _viewMode == 'teacher' ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))] : null,
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_pin_outlined, size: 15, color: _viewMode == 'teacher' ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text('Teacher', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _viewMode == 'teacher' ? const Color(0xFF1E3A8A) : const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Header Selector (Class Dropdown OR Teacher Dropdown OR Master Quick Action)
          if (_viewMode == 'class')
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedClass,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF475569)),
                          items: _allClasses.map((cls) => DropdownMenuItem(value: cls, child: Text('Class $cls', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))).toList(),
                          onChanged: (newCls) {
                            if (newCls != null) _loadScheduleForClass(newCls);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Quick +Prayer
                  ElevatedButton(
                    onPressed: () => _addOrEditPeriodDialog(presetType: 'prayer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFFBEB),
                      foregroundColor: const Color(0xFFB45309),
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFFFDE68A)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wb_sunny_rounded, size: 14, color: Color(0xFFD97706)),
                        SizedBox(width: 4),
                        Text('Prayer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Quick +Lunch
                  ElevatedButton(
                    onPressed: () => _addOrEditPeriodDialog(presetType: 'lunch'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFECFDF5),
                      foregroundColor: const Color(0xFF047857),
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFFA7F3D0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.restaurant_rounded, size: 14, color: Color(0xFF059669)),
                        SizedBox(width: 4),
                        Text('Lunch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Add Period button
                  ElevatedButton(
                    onPressed: () => _addOrEditPeriodDialog(presetType: 'regular'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 15),
                        SizedBox(width: 2),
                        Text('Period', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else if (_viewMode == 'teacher')
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _availableTeachers.contains(_selectedTeacher) ? _selectedTeacher : (_availableTeachers.isNotEmpty ? _availableTeachers.first : null),
                          isExpanded: true,
                          hint: const Text('Select Teacher', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF475569)),
                          items: _availableTeachers.map((t) => DropdownMenuItem(value: t, child: Row(
                            children: [
                              const Icon(Icons.person_rounded, size: 15, color: Color(0xFF2563EB)),
                              const SizedBox(width: 6),
                              Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ))).toList(),
                          onChanged: (newT) {
                            if (newT != null) setState(() => _selectedTeacher = newT);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF2563EB)),
                        const SizedBox(width: 6),
                        Text(
                          '${teacherItems.length} Periods',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E3A8A)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            // Master Mode Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.grid_view_rounded, size: 18, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All ${_allClasses.length} Classes Matrix ($_currentDay)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _generating ? null : () => _exportMasterTimetablePDF(share: false),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 14),
                    label: const Text('Export PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),

          // Day Selector Tabs
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _dayTabCtrl,
              isScrollable: true,
              labelColor: const Color(0xFF2563EB),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF2563EB),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: _days.map((d) {
                final count = _isTeacherMode
                    ? _getTeacherScheduleForDay(_selectedTeacher, d).length
                    : _isMasterMode
                    ? _allClasses.length
                    : (_currentClassSchedule[d]?.length ?? 0);
                return Tab(
                  child: Row(
                    children: [
                      Text(d),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('$count', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // Clash Banners
          if (_isTeacherMode && hasConflict)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Schedule Clash Detected: Multiple classes assigned at the same time for this teacher!',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),

          if (_isMasterMode && masterClashes.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Color(0xFFE11D48), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Double-Booking Alert: ${masterClashes.length} teacher(s) scheduled for 2 classes at the same period!',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF9F1239)),
                    ),
                  ),
                ],
              ),
            ),

          // Main View Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _isMasterMode
                    // ══════════════════════════════════════════════════════════
                    // MODE 2: MASTER GRID (ALL CLASSES ON ONE PAGE)
                    // ══════════════════════════════════════════════════════════
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(const Color(0xFF1E3A8A)),
                              headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              dataRowMinHeight: 52,
                              dataRowMaxHeight: 64,
                              columnSpacing: 16,
                              columns: const [
                                DataColumn(label: Text('CLASS')),
                                DataColumn(label: Text('☀️ PRAYER (08:30)')),
                                DataColumn(label: Text('PERIOD 1')),
                                DataColumn(label: Text('PERIOD 2')),
                                DataColumn(label: Text('PERIOD 3')),
                                DataColumn(label: Text('PERIOD 4')),
                                DataColumn(label: Text('🍱 LUNCH (12:15)')),
                                DataColumn(label: Text('PERIOD 5')),
                                DataColumn(label: Text('PERIOD 6')),
                              ],
                              rows: _allClasses.map((cls) {
                                final list = _allClassesCache[cls]?[_currentDay] ?? [];
                                final prayerP = list.where((p) => p.isPrayer).firstOrNull;
                                final lunchP = list.where((p) => p.isLunch).firstOrNull;

                                return DataRow(
                                  cells: [
                                    // Class Name
                                    DataCell(
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _selectedClass = cls;
                                            _viewMode = 'class';
                                          });
                                          _loadScheduleForClass(cls);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFBFDBFE)),
                                          ),
                                          child: Text('Class $cls', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A), fontSize: 12)),
                                        ),
                                      ),
                                    ),
                                    // Prayer
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFFDE68A)),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Morning Prayer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: Color(0xFF92400E))),
                                            Text(prayerP?.time ?? '08:30 - 09:00', style: const TextStyle(fontSize: 9.5, color: Color(0xFFB45309))),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Periods 1 to 4
                                    for (int p = 1; p <= 4; p++)
                                      _buildMasterGridCell(list, p),
                                    // Lunch
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD1FAE5),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFA7F3D0)),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Lunch Break', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: Color(0xFF065F46))),
                                            Text(lunchP?.time ?? '12:15 - 01:00', style: const TextStyle(fontSize: 9.5, color: Color(0xFF047857))),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Periods 5 to 6
                                    for (int p = 5; p <= 6; p++)
                                      _buildMasterGridCell(list, p),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      )
                    : _isTeacherMode
                    // ══════════════════════════════════════════════════════════
                    // MODE 3: TEACHER SCHEDULE INSPECTOR
                    // ══════════════════════════════════════════════════════════
                    ? (teacherItems.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_available_rounded, size: 52, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  _selectedTeacher.isNotEmpty
                                      ? 'No classes scheduled for $_selectedTeacher on $_currentDay'
                                      : 'No teachers found in timetable',
                                  style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(14),
                            itemCount: teacherItems.length,
                            itemBuilder: (ctx, idx) {
                              final item = teacherItems[idx];
                              final p = item['period'] as TimetablePeriod;
                              final cls = item['className'] as String;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Row(
                                    children: [
                                      // Squircle Period Badge
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF059669), Color(0xFF0D9488)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'P${p.periodNumber}',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // Subject & Class details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    'Class $cls',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF2563EB)),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    p.subject,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                const Icon(Icons.person_rounded, size: 14, color: Color(0xFF64748B)),
                                                const SizedBox(width: 4),
                                                Text(p.teacher, style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), fontWeight: FontWeight.w500)),
                                                if (p.room.isNotEmpty) ...[
                                                  const SizedBox(width: 10),
                                                  const Icon(Icons.room_outlined, size: 14, color: Color(0xFF64748B)),
                                                  const SizedBox(width: 4),
                                                  Text(p.room, style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), fontWeight: FontWeight.w500)),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Timing Pill
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: const Color(0xFFBFDBFE)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.access_time_filled_rounded, size: 13, color: Color(0xFF2563EB)),
                                            const SizedBox(width: 5),
                                            Text(p.time, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ))
                    // ══════════════════════════════════════════════════════════
                    // MODE 1: CLASS ROUTINE (With Prayer & Lunch Badges)
                    // ══════════════════════════════════════════════════════════
                    : periods.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy_rounded, size: 52, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text('No slots configured for $_currentDay', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              onPressed: () => _addOrEditPeriodDialog(presetType: 'regular'),
                              icon: const Icon(Icons.add),
                              label: const Text('Add First Slot'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: periods.length,
                        itemBuilder: (ctx, idx) {
                          final p = periods[idx];
                          final isPrayer = p.isPrayer;
                          final isLunch = p.isLunch;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isPrayer
                                  ? const Color(0xFFFFFBEB)
                                  : isLunch
                                  ? const Color(0xFFECFDF5)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isPrayer
                                    ? const Color(0xFFFDE68A)
                                    : isLunch
                                    ? const Color(0xFFA7F3D0)
                                    : const Color(0xFFE2E8F0),
                                width: isPrayer || isLunch ? 1.5 : 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  // Squircle Period / Prayer / Lunch Badge
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isPrayer
                                            ? const [Color(0xFFD97706), Color(0xFFF59E0B)]
                                            : isLunch
                                            ? const [Color(0xFF059669), Color(0xFF10B981)]
                                            : const [Color(0xFF2563EB), Color(0xFF4F46E5)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Center(
                                      child: isPrayer
                                          ? const Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 22)
                                          : isLunch
                                          ? const Icon(Icons.restaurant_rounded, color: Colors.white, size: 22)
                                          : Text(
                                              'P${p.periodNumber}',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            if (isPrayer)
                                              Container(
                                                margin: const EdgeInsets.only(right: 6),
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFD97706),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text('ASSEMBLY', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                              )
                                            else if (isLunch)
                                              Container(
                                                margin: const EdgeInsets.only(right: 6),
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF059669),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text('RECESS', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                              ),
                                            Expanded(
                                              child: Text(
                                                p.subject,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: isPrayer
                                                      ? const Color(0xFF92400E)
                                                      : isLunch
                                                      ? const Color(0xFF065F46)
                                                      : const Color(0xFF0F172A),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF64748B)),
                                            const SizedBox(width: 4),
                                            Text(p.teacher, style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), fontWeight: FontWeight.w500)),
                                            if (p.room.isNotEmpty) ...[
                                              const SizedBox(width: 10),
                                              const Icon(Icons.room_outlined, size: 14, color: Color(0xFF64748B)),
                                              const SizedBox(width: 4),
                                              Text(p.room, style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), fontWeight: FontWeight.w500)),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Timing Pill & Actions
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: isPrayer
                                              ? const Color(0xFFFEF3C7)
                                              : isLunch
                                              ? const Color(0xFFD1FAE5)
                                              : const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isPrayer
                                                ? const Color(0xFFFDE68A)
                                                : isLunch
                                                ? const Color(0xFFA7F3D0)
                                                : const Color(0xFFBFDBFE),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.access_time_filled_rounded,
                                              size: 13,
                                              color: isPrayer
                                                  ? const Color(0xFFD97706)
                                                  : isLunch
                                                  ? const Color(0xFF059669)
                                                  : const Color(0xFF2563EB),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              p.time,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: isPrayer
                                                    ? const Color(0xFF92400E)
                                                    : isLunch
                                                    ? const Color(0xFF065F46)
                                                    : const Color(0xFF1E3A8A),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () => _addOrEditPeriodDialog(existing: p, index: idx),
                                          ),
                                          const SizedBox(width: 12),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () => _deletePeriod(idx),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  DataCell _buildMasterGridCell(List<TimetablePeriod> list, int periodNum) {
    final matches = list.where((e) => !e.isPrayer && !e.isLunch && e.periodNumber == periodNum);
    if (matches.isEmpty) {
      return const DataCell(Center(child: Text('-', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))));
    }
    final p = matches.first;
    final t = p.teacher.trim();

    return DataCell(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.subject, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
