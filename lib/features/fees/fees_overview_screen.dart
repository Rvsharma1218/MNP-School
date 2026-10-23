import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/fee_model.dart';
import '../../data/models/student_model.dart';
import '../../data/models/settings_model.dart';
import '../../data/services/database_service.dart';
import '../../data/services/firestore_service.dart';
import '../../data/services/session_service.dart';
import '../../data/services/providers.dart';
import '../whatsapp/whatsapp_service.dart';
import '../../data/services/receipt_pdf_service.dart';
import 'package:printing/printing.dart';
import '../../widgets/common_widgets.dart';

/// Defense-in-depth: the Fees tiles are already hidden from a Teacher's
/// Dashboard, but a deep link / restored route could still land here
/// directly, so block both fee screens at this level too.
Widget? _principalOnlyGuard(String title) {
  if (SessionService.instance.isPrincipal) return null;
  return Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: Text(title),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    ),
    body: const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Fee details are only visible to the Principal.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    ),
  );
}

// ─── Data Model ───────────────────────────────────────────────────────────────

class _StudentFeeRow {
  final StudentModel student;
  final FeeModel fee;
  _StudentFeeRow(this.student, this.fee);
}

// ─── Unified Fees Screen (Collected, Pending, Outstanding, Transactions) ──────

class FeesCollectedScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  const FeesCollectedScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<FeesCollectedScreen> createState() => _FeesCollectedScreenState();
}

class _FeesCollectedScreenState extends ConsumerState<FeesCollectedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<_StudentFeeRow> _allFeeRows = [];
  List<PaymentModel> _allPayments = [];
  Map<String, StudentModel> _studentMap = {};
  bool _loading = true;

  // Filter state for Collected Tab (Tab 0)
  String _collectedFilter = 'all'; // all | paid | partial
  String _collectedDateMode = 'all'; // all | date | month
  DateTime? _collectedSelectedDate;
  DateTime? _collectedSelectedMonth;
  String _collectedSelectedClass = 'All Classes';
  String _collectedViewMode = 'grouped'; // 'grouped' | 'receipts'
  final Set<String> _expandedStudentIds = {};

  // Search & Filter state for Pending Tab (Tab 1)
  String _pendingSearch = '';
  String _pendingSortBy = 'amount'; // amount | name | due
  String _pendingDateMode = 'all'; // all | date | month
  DateTime? _pendingSelectedDate;
  DateTime? _pendingSelectedMonth;
  String _pendingSelectedClass = 'All Classes';

  // Search & Sort state for Outstanding Tab (Tab 2)
  String _defaulterSearch = '';
  String _defaulterSortBy = 'overdue'; // overdue | amount | name
  String _defaulterSelectedClass = 'All Classes';

  // Filter & Search state for Transaction Register Tab (Tab 3)
  String _transactionSearch = '';
  String _transactionDateMode = 'all'; // all | date | month
  DateTime? _transactionSelectedDate;
  DateTime? _transactionSelectedMonth;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // 1. Instantly load & render from SQLite cache with zero waiting
    await _processAndRenderLocalData();

    // 2. Fetch fresh updates from Firestore in the background
    () async {
      try {
        final remote = await FirestoreService.instance.fetchStudents();
        if (remote.isNotEmpty) {
          await DatabaseService.instance.bulkUpsertStudentsFromRemote(remote);
        }
        final remotePayments = await FirestoreService.instance.fetchPayments();
        if (remotePayments.isNotEmpty) {
          await DatabaseService.instance.bulkUpsertPaymentsFromRemote(remotePayments);
        }
        final remoteFees = await FirestoreService.instance.fetchFees();
        if (remoteFees.isNotEmpty) {
          await DatabaseService.instance.bulkUpsertFeesFromRemote(remoteFees);
        }
        final remoteMonthly = await FirestoreService.instance.fetchMonthlyFees();
        if (remoteMonthly.isNotEmpty) {
          await DatabaseService.instance.bulkUpsertMonthlyFeesFromRemote(remoteMonthly);
        }
        if (mounted) {
          await _processAndRenderLocalData();
        }
      } catch (_) {}
    }();
  }

  Future<void> _processAndRenderLocalData() async {
    try {
      final students = await DatabaseService.instance.getAllStudents();
      final feesMap = await DatabaseService.instance.getAllFeesMap();
      final payments = await DatabaseService.instance.getAllPayments();

      final sMap = <String, StudentModel>{};
      for (final s in students) {
        sMap[s.id] = s;
        if (s.studentId.isNotEmpty) sMap[s.studentId] = s;
        if (s.admissionNumber.isNotEmpty) sMap[s.admissionNumber] = s;
      }

      // Merge payments from all sources first to guarantee complete history
      final allPaymentsMap = <String, PaymentModel>{};
      for (final p in payments) {
        final key = p.id.isNotEmpty ? p.id : '${p.studentId}_${p.paymentDate.toIso8601String()}_${p.amount}';
        allPaymentsMap[key] = p;
      }
      for (final fee in feesMap.values) {
        for (final p in fee.payments) {
          final key = p.id.isNotEmpty ? p.id : '${p.studentId}_${p.paymentDate.toIso8601String()}_${p.amount}';
          allPaymentsMap.putIfAbsent(key, () => p);
        }
      }
      final mergedPayments = allPaymentsMap.values.toList()
        ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));

      final rows = <_StudentFeeRow>[];
      final now = DateTime.now();

      for (final s in students) {
        // Collect all payments made by this student across the entire database
        final stuPayments = mergedPayments.where((p) {
          if (p.studentId == s.id) return true;
          if (s.studentId.isNotEmpty && p.studentId == s.studentId) return true;
          if (s.admissionNumber.isNotEmpty && p.admissionNumber == s.admissionNumber) return true;
          if (p.studentName != null && p.studentName!.trim().toLowerCase() == s.name.trim().toLowerCase()) return true;
          return false;
        }).toList();

        final fee = feesMap[s.id] ??
            (s.studentId.isNotEmpty ? feesMap[s.studentId] : null) ??
            (s.admissionNumber.isNotEmpty ? feesMap[s.admissionNumber] : null);

        final model = fee != null
            ? FeeModel(
                studentId: fee.studentId,
                totalFees: fee.totalFees,
                paidFees: fee.paidFees,
                explicitRemaining: fee.explicitRemaining,
                dueDate: fee.dueDate,
                lastPaidDate: fee.lastPaidDate,
                payments: stuPayments.isNotEmpty ? stuPayments : fee.payments,
              )
            : FeeModel(
                studentId: s.id,
                totalFees: 0,
                paidFees: 0,
                explicitRemaining: 0,
                dueDate: DateTime(now.year, now.month, 10),
                payments: stuPayments,
              );

        rows.add(_StudentFeeRow(s, model));
      }

      if (mounted) {
        setState(() {
          _allFeeRows = rows;
          _allPayments = mergedPayments;
          _studentMap = sMap;
          _loading = false;
        });
        ref.invalidate(dashboardStatsProvider);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  StudentModel? _findStudent(PaymentModel p) {
    if (_studentMap.containsKey(p.studentId)) return _studentMap[p.studentId];
    for (final s in _studentMap.values) {
      if (s.id == p.studentId ||
          s.studentId == p.studentId ||
          (p.admissionNumber != null && p.admissionNumber!.isNotEmpty && s.admissionNumber == p.admissionNumber) ||
          (p.studentName != null && p.studentName!.trim().toLowerCase() == s.name.trim().toLowerCase())) {
        return s;
      }
    }
    return null;
  }

  // ─── Filter Helpers ──────────────────────────────────────────────────────────

  List<String> get _availableClasses {
    final classes = <String>{};
    for (final r in _allFeeRows) {
      final c = r.student.displayClass.trim();
      if (c.isNotEmpty) classes.add(c);
    }
    final sorted = classes.toList()..sort((a, b) => a.compareTo(b));
    return ['All Classes', ...sorted];
  }

  List<_StudentFeeRow> get _collectedRows {
    var paidRows = _allFeeRows.where((r) => r.fee.totalPaid > 0).toList();
    if (_collectedSelectedClass != 'All Classes') {
      paidRows = paidRows.where((r) => r.student.displayClass == _collectedSelectedClass).toList();
    }
    if (_collectedFilter == 'paid') return paidRows.where((r) => r.fee.remaining <= 0).toList();
    if (_collectedFilter == 'partial') return paidRows.where((r) => r.fee.remaining > 0).toList();
    return paidRows;
  }

  double get _totalCollectedAllTime {
    var rows = _allFeeRows;
    if (_collectedSelectedClass != 'All Classes') {
      rows = rows.where((r) => r.student.displayClass == _collectedSelectedClass).toList();
    }
    return rows.fold(0.0, (sum, r) => sum + r.fee.totalPaid);
  }

  List<PaymentModel> _filterPaymentsByDate(
    List<PaymentModel> list,
    String mode,
    DateTime? selDate,
    DateTime? selMonth,
  ) {
    if (mode == 'all') return list;
    if (mode == 'date') {
      final sel = selDate ?? DateTime.now();
      return list.where((p) {
        final pDate = p.paymentDate.toLocal();
        return pDate.year == sel.year &&
            pDate.month == sel.month &&
            pDate.day == sel.day;
      }).toList();
    }
    if (mode == 'month') {
      final sel = selMonth ?? DateTime.now();
      return list.where((p) {
        final pDate = p.paymentDate.toLocal();
        return pDate.year == sel.year &&
            pDate.month == sel.month;
      }).toList();
    }
    return list;
  }

  List<PaymentModel> get _collectedDatePayments {
    var list = _filterPaymentsByDate(
      _allPayments,
      _collectedDateMode,
      _collectedSelectedDate,
      _collectedSelectedMonth,
    );
    if (_collectedSelectedClass != 'All Classes') {
      list = list.where((p) {
        final s = _findStudent(p);
        final c = s?.displayClass ?? p.className ?? '';
        return c == _collectedSelectedClass;
      }).toList();
    }
    return list;
  }

  double get _collectedDateTotal =>
      _collectedDatePayments.fold(0.0, (sum, p) => sum + p.amount);

  List<_StudentPaymentGroup> get _collectedStudentGroups {
    final paymentsList = _collectedDatePayments;
    final Map<String, _StudentPaymentGroup> map = {};

    for (final p in paymentsList) {
      final s = _findStudent(p);
      final key = s?.id ?? (p.studentId.isNotEmpty ? p.studentId : (p.studentName ?? 'unknown'));
      if (!map.containsKey(key)) {
        map[key] = _StudentPaymentGroup(
          student: s ?? StudentModel(
            id: p.studentId,
            studentId: p.studentId,
            name: p.studentName ?? 'Student',
            className: p.className ?? '',
            admissionNumber: p.admissionNumber ?? '',
            fatherName: '',
            mobile: '',
            dob: DateTime(2000),
            gender: 'other',
            address: '',
            studentType: 'school',
            admissionDate: DateTime.now(),
            createdAt: DateTime.now(),
          ),
          payments: [],
        );
      }
      map[key]!.payments.add(p);
    }

    final groups = map.values.toList();
    for (final g in groups) {
      g.payments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
    }
    groups.sort((a, b) {
      final dateA = a.payments.isNotEmpty ? a.payments.first.paymentDate : DateTime(1970);
      final dateB = b.payments.isNotEmpty ? b.payments.first.paymentDate : DateTime(1970);
      return dateB.compareTo(dateA);
    });
    return groups;
  }

  List<_StudentFeeRow> get _pendingRows {
    var list = _allFeeRows.where((r) => r.fee.remaining > 0).toList();

    if (_pendingSelectedClass != 'All Classes') {
      list = list.where((r) => r.student.displayClass == _pendingSelectedClass).toList();
    }

    if (_pendingDateMode == 'date') {
      final sel = _pendingSelectedDate ?? DateTime.now();
      list = list.where((r) {
        if (r.fee.dueDate != null) {
          final d = r.fee.dueDate!.toLocal();
          return d.year == sel.year && d.month == sel.month && d.day == sel.day;
        }
        final now = DateTime.now();
        if (sel.year == now.year && sel.month == now.month && sel.day == now.day) {
          return r.fee.isOverdue || r.fee.remaining > 0;
        }
        return false;
      }).toList();
    } else if (_pendingDateMode == 'month') {
      final sel = _pendingSelectedMonth ?? DateTime.now();
      list = list.where((r) {
        if (r.fee.dueDate != null) {
          final d = r.fee.dueDate!.toLocal();
          return d.year == sel.year && d.month == sel.month;
        }
        return true;
      }).toList();
    }

    if (_pendingSearch.trim().isNotEmpty) {
      final q = _pendingSearch.trim().toLowerCase();
      list = list.where((r) {
        final s = r.student;
        return s.name.toLowerCase().contains(q) ||
            s.admissionNumber.toLowerCase().contains(q) ||
            s.displayClass.toLowerCase().contains(q) ||
            s.mobile.contains(q);
      }).toList();
    }
    if (_pendingSortBy == 'amount') {
      list.sort((a, b) => b.fee.remaining.compareTo(a.fee.remaining));
    } else if (_pendingSortBy == 'name') {
      list.sort((a, b) => a.student.name.compareTo(b.student.name));
    } else if (_pendingSortBy == 'due') {
      list.sort((a, b) {
        if (a.fee.dueDate == null) return 1;
        if (b.fee.dueDate == null) return -1;
        return a.fee.dueDate!.compareTo(b.fee.dueDate!);
      });
    }
    return list;
  }

  double get _totalPendingAmount =>
      _pendingRows.fold(0.0, (s, r) => s + r.fee.remaining);

  double get _totalPendingPaidAmount =>
      _pendingRows.fold(0.0, (s, r) => s + r.fee.totalPaid);

  double get _totalPendingTotalFees =>
      _pendingRows.fold(0.0, (s, r) => s + r.fee.totalFees);

  List<_StudentFeeRow> get _defaulterRows {
    var list = _allFeeRows.where((r) => r.fee.remaining > 0).toList();
    if (_defaulterSelectedClass != 'All Classes') {
      list = list.where((r) => r.student.displayClass.trim() == _defaulterSelectedClass.trim() || (r.student.className != null && r.student.className!.trim() == _defaulterSelectedClass.trim())).toList();
    }

    if (_defaulterSearch.trim().isNotEmpty) {
      final q = _defaulterSearch.trim().toLowerCase();
      list = list.where((r) {
        final s = r.student;
        return s.name.toLowerCase().contains(q) ||
            s.admissionNumber.toLowerCase().contains(q) ||
            s.displayClass.toLowerCase().contains(q) ||
            s.mobile.contains(q);
      }).toList();
    }

    if (_defaulterSortBy == 'overdue') {
      list.sort((a, b) => b.fee.overdueDays.compareTo(a.fee.overdueDays));
    } else if (_defaulterSortBy == 'amount') {
      list.sort((a, b) => b.fee.remaining.compareTo(a.fee.remaining));
    } else if (_defaulterSortBy == 'name') {
      list.sort((a, b) => a.student.name.compareTo(b.student.name));
    }
    return list;
  }

  double get _totalDefaulterAmount =>
      _defaulterRows.fold(0.0, (s, r) => s + r.fee.remaining);

  double get _totalDefaulterPaidAmount =>
      _defaulterRows.fold(0.0, (s, r) => s + r.fee.totalPaid);

  double get _totalDefaulterTotalFees =>
      _defaulterRows.fold(0.0, (s, r) => s + r.fee.totalFees);

  List<PaymentModel> get _filteredTransactions {
    var list = _filterPaymentsByDate(
      _allPayments,
      _transactionDateMode,
      _transactionSelectedDate,
      _transactionSelectedMonth,
    );
    if (_transactionSearch.trim().isNotEmpty) {
      final q = _transactionSearch.trim().toLowerCase();
      list = list.where((p) {
        final s = _findStudent(p);
        final sName = (s?.name ?? p.studentName ?? '').toLowerCase();
        final rcpt = p.receiptNumber.toLowerCase();
        final mode = p.paymentMode.toLowerCase();
        final adm = (s?.admissionNumber ?? p.admissionNumber ?? '').toLowerCase();
        return sName.contains(q) || rcpt.contains(q) || mode.contains(q) || adm.contains(q);
      }).toList();
    }
    return list;
  }

  double get _filteredTransactionsTotal =>
      _filteredTransactions.fold(0.0, (sum, p) => sum + p.amount);

  // ─── Date / Month Pickers ───────────────────────────────────────────────────

  Future<void> _pickDateFor({
    required BuildContext context,
    required DateTime? currentDate,
    required void Function(DateTime date) onSelected,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onSelected(picked);
    }
  }

  Future<void> _pickMonthFor({
    required BuildContext context,
    required DateTime? currentMonth,
    required void Function(DateTime month) onSelected,
  }) async {
    int tempYear = (currentMonth ?? DateTime.now()).year;
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    final result = await showDialog<DateTime>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Select Month', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 22),
                        onPressed: () => setDialogState(() => tempYear--),
                      ),
                      Text('$tempYear', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 22),
                        onPressed: () => setDialogState(() => tempYear++),
                      ),
                    ],
                  ),
                ],
              ),
              content: SizedBox(
                width: 320,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: List.generate(12, (index) {
                    final mNum = index + 1;
                    final isSelected = currentMonth != null &&
                        currentMonth.year == tempYear &&
                        currentMonth.month == mNum;
                    return InkWell(
                      onTap: () => Navigator.of(ctx).pop(DateTime(tempYear, mNum, 1)),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 68,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.grey.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          months[index].substring(0, 3),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : null,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      onSelected(result);
    }
  }

  void _openFilterModal({
    required BuildContext context,
    required String currentDateMode,
    required DateTime? selectedDate,
    required DateTime? selectedMonth,
    required String selectedClass,
    required void Function(String dateMode, DateTime? date, DateTime? month, String cls) onApply,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String tempMode = currentDateMode;
        DateTime? tempDate = selectedDate;
        DateTime? tempMonth = selectedMonth;
        String tempClass = selectedClass;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final cs = Theme.of(context).colorScheme;
            final now = DateTime.now();

            return Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: cs.outlineVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tune_rounded, size: 20, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Filter & Date Range',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Text(
                      'QUICK DATE FILTER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('All Dues'),
                          selected: tempMode == 'all',
                          onSelected: (val) => setSheetState(() => tempMode = 'all'),
                        ),
                        ChoiceChip(
                          label: const Text('Today'),
                          selected: tempMode == 'date' && tempDate != null && DateUtils.isSameDay(tempDate, now),
                          onSelected: (val) {
                            setSheetState(() {
                              tempMode = 'date';
                              tempDate = DateTime.now();
                            });
                          },
                        ),
                        ChoiceChip(
                          label: const Text('This Month'),
                          selected: tempMode == 'month' && tempMonth != null && tempMonth!.year == now.year && tempMonth!.month == now.month,
                          onSelected: (val) {
                            setSheetState(() {
                              tempMode = 'month';
                              tempMonth = DateTime(now.year, now.month);
                            });
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.calendar_today_outlined, size: 14),
                          label: Text(
                            tempMode == 'date' && tempDate != null && !DateUtils.isSameDay(tempDate, now)
                                ? DateFormat('dd MMM yyyy').format(tempDate!)
                                : 'Pick Date',
                          ),
                          onPressed: () {
                            _pickDateFor(
                              context: context,
                              currentDate: tempDate,
                              onSelected: (picked) {
                                setSheetState(() {
                                  tempDate = picked;
                                  tempMode = 'date';
                                });
                              },
                            );
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.calendar_month_outlined, size: 14),
                          label: Text(
                            tempMode == 'month' && tempMonth != null && (tempMonth!.year != now.year || tempMonth!.month != now.month)
                                ? DateFormat('MMM yyyy').format(tempMonth!)
                                : 'Pick Month',
                          ),
                          onPressed: () {
                            _pickMonthFor(
                              context: context,
                              currentMonth: tempMonth,
                              onSelected: (picked) {
                                setSheetState(() {
                                  tempMonth = picked;
                                  tempMode = 'month';
                                });
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_availableClasses.length > 1) ...[
                      Text(
                        'SELECT CLASS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurfaceVariant,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableClasses.map((cls) {
                          final isSel = cls == tempClass;
                          return ChoiceChip(
                            label: Text(cls),
                            selected: isSel,
                            onSelected: (val) => setSheetState(() => tempClass = cls),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setSheetState(() {
                                tempMode = 'all';
                                tempDate = null;
                                tempMonth = null;
                                tempClass = 'All Classes';
                              });
                              onApply('all', null, null, 'All Classes');
                              Navigator.pop(ctx);
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Reset All', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              onApply(tempMode, tempDate, tempMonth, tempClass);
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── Filter Bar Widget ──────────────────────────────────────────────────────

  Widget _buildDateFilterBar({
    required ColorScheme cs,
    required String mode,
    required DateTime? selectedDate,
    required DateTime? selectedMonth,
    required VoidCallback onAllTap,
    required VoidCallback onTodayTap,
    required VoidCallback onThisMonthTap,
    required VoidCallback onPickDateTap,
    required VoidCallback onPickMonthTap,
  }) {
    final now = DateTime.now();
    final isAll = mode == 'all';
    final isDate = mode == 'date';
    final isMonth = mode == 'month';

    final isToday = isDate &&
        selectedDate != null &&
        selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;

    final isThisMonth = isMonth &&
        selectedMonth != null &&
        selectedMonth.year == now.year &&
        selectedMonth.month == now.month;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.4)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildQuickChip(label: 'All', isSelected: isAll, onTap: onAllTap, cs: cs),
            const SizedBox(width: 6),
            _buildQuickChip(label: 'Today', isSelected: isToday, onTap: onTodayTap, cs: cs),
            const SizedBox(width: 6),
            _buildQuickChip(label: 'This Month', isSelected: isThisMonth, onTap: onThisMonthTap, cs: cs),
            const SizedBox(width: 8),
            // Date Picker Chip
            InkWell(
              onTap: onPickDateTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isDate ? AppColors.primary.withOpacity(0.12) : cs.surfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDate ? AppColors.primary : cs.outlineVariant.withOpacity(0.5),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_outlined, size: 16, color: isDate ? AppColors.primary : cs.onSurfaceVariant),
                    const SizedBox(width: 5),
                    Text(
                      isDate && selectedDate != null
                          ? DateFormat('dd MMM yyyy').format(selectedDate)
                          : 'Date Picker',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDate ? AppColors.primary : cs.onSurface,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_drop_down, size: 18, color: isDate ? AppColors.primary : cs.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Month Picker Chip
            InkWell(
              onTap: onPickMonthTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isMonth ? AppColors.primary.withOpacity(0.12) : cs.surfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isMonth ? AppColors.primary : cs.outlineVariant.withOpacity(0.5),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_month_outlined, size: 16, color: isMonth ? AppColors.primary : cs.onSurfaceVariant),
                    const SizedBox(width: 5),
                    Text(
                      isMonth && selectedMonth != null
                          ? DateFormat('MMM yyyy').format(selectedMonth)
                          : 'Month Picker',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isMonth ? AppColors.primary : cs.onSurface,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_drop_down, size: 18, color: isMonth ? AppColors.primary : cs.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassFilterBar({
    required ColorScheme cs,
    required String selectedClass,
    required void Function(String) onClassSelected,
  }) {
    final classes = _availableClasses;
    if (classes.length <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Row(
              children: [
                Icon(Icons.class_outlined, size: 15, color: cs.onSurfaceVariant),
                const SizedBox(width: 5),
                Text(
                  'Class:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            ...classes.map((cls) {
              final isSelected = cls == selectedClass;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () => onClassSelected(cls),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : cs.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : cs.outlineVariant.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      cls,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : cs.onSurface,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ColorScheme cs,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : cs.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  void _openBulkWhatsAppReminderDialog(List<_StudentFeeRow> pendingRows) {
    if (pendingRows.isEmpty) return;
    final settings = ref.read(settingsProvider).value ?? SettingsModel.defaultSettings();
    showDialog(
      context: context,
      builder: (ctx) => _BulkWhatsAppReminderDialog(
        rows: pendingRows,
        settings: settings,
      ),
    );
  }

  // ─── Build Method ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final guard = _principalOnlyGuard('Fee Management');
    if (guard != null) return guard;

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        title: const Text('Fee Management'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Data',
            onPressed: _load,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3.5,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 11.5),
          isScrollable: false,
          tabs: const [
            Tab(text: 'Collected', icon: Icon(Icons.check_circle_outline_rounded, size: 19)),
            Tab(text: 'Pending', icon: Icon(Icons.pending_actions_rounded, size: 19)),
            Tab(text: 'Outstanding', icon: Icon(Icons.warning_amber_rounded, size: 19)),
            Tab(text: 'Transactions', icon: Icon(Icons.receipt_long_rounded, size: 19)),
          ],
        ),
      ),
      body: _loading
          ? const LoadingWidget(message: 'Loading fee records...')
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCollectedTab(cs),
                _buildPendingTab(cs),
                _buildOutstandingTab(cs),
                _buildTransactionsTab(cs),
              ],
            ),
    );
  }

  // ─── TAB 0: Fee Collected ───────────────────────────────────────────────────

  Widget _buildCollectedTab(ColorScheme cs) {
    final now = DateTime.now();
    final isFilteringActive = _collectedDateMode != 'all';
    final datePayments = _collectedDatePayments;
    final studentGroups = _collectedStudentGroups;

    String bannerTitle;
    if (_collectedDateMode == 'date') {
      bannerTitle = 'Collection on ${DateFormat('dd MMM yyyy').format(_collectedSelectedDate ?? now)}';
    } else if (_collectedDateMode == 'month') {
      bannerTitle = 'Collection in ${DateFormat('MMMM yyyy').format(_collectedSelectedMonth ?? now)}';
    } else {
      bannerTitle = 'Total All-Time Collected';
    }
    if (_collectedSelectedClass != 'All Classes') {
      bannerTitle += ' • $_collectedSelectedClass';
    }

    String bannerSubtitle;
    if (_collectedDateMode == 'date') {
      bannerSubtitle = '${datePayments.length} receipts on this date';
    } else if (_collectedDateMode == 'month') {
      bannerSubtitle = '${datePayments.length} receipts in this month';
    } else {
      bannerSubtitle = '${studentGroups.length} students • ${datePayments.length} total receipts';
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          // Sleek Compact Collected Summary Banner
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.success.withOpacity(0.12),
                  AppColors.success.withOpacity(0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.success.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                          const SizedBox(width: 4),
                          Text(
                            '$bannerTitle: ${AppUtils.formatCurrency(_collectedDateTotal)}',
                            style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        bannerSubtitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Filter Icon Button
                InkWell(
                  onTap: () => _openFilterModal(
                    context: context,
                    currentDateMode: _collectedDateMode,
                    selectedDate: _collectedSelectedDate,
                    selectedMonth: _collectedSelectedMonth,
                    selectedClass: _collectedSelectedClass,
                    onApply: (mode, date, month, cls) {
                      setState(() {
                        _collectedDateMode = mode;
                        _collectedSelectedDate = date;
                        _collectedSelectedMonth = month;
                        _collectedSelectedClass = cls;
                      });
                    },
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (_collectedDateMode != 'all' || _collectedSelectedClass != 'All Classes')
                          ? AppColors.primary.withOpacity(0.12)
                          : cs.surfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                      border: (_collectedDateMode != 'all' || _collectedSelectedClass != 'All Classes')
                          ? Border.all(color: AppColors.primary, width: 1.2)
                          : null,
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: (_collectedDateMode != 'all' || _collectedSelectedClass != 'All Classes')
                              ? AppColors.primary
                              : cs.onSurfaceVariant,
                        ),
                        if (_collectedDateMode != 'all' || _collectedSelectedClass != 'All Classes')
                          const Positioned(
                            right: -2,
                            top: -2,
                            child: CircleAvatar(
                              radius: 3.5,
                              backgroundColor: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Active Filter Chips Preview
          if (_collectedDateMode != 'all' || _collectedSelectedClass != 'All Classes')
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_collectedSelectedClass != 'All Classes')
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InputChip(
                          label: Text(_collectedSelectedClass, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onDeleted: () => setState(() => _collectedSelectedClass = 'All Classes'),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    if (_collectedDateMode != 'all')
                      InputChip(
                        label: Text(
                          _collectedDateMode == 'date' && _collectedSelectedDate != null
                              ? DateFormat('dd MMM').format(_collectedSelectedDate!)
                              : (_collectedDateMode == 'month' && _collectedSelectedMonth != null
                                  ? DateFormat('MMM yyyy').format(_collectedSelectedMonth!)
                                  : 'Active Date'),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onDeleted: () => setState(() => _collectedDateMode = 'all'),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            ),

          // View Mode Switcher: By Student (Accordion Dropdown) vs All Receipts (Flat)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _collectedViewMode = 'grouped'),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _collectedViewMode == 'grouped'
                            ? AppColors.primary
                            : cs.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_alt_outlined,
                            size: 15,
                            color: _collectedViewMode == 'grouped' ? Colors.white : cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'By Student (${studentGroups.length})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _collectedViewMode == 'grouped' ? Colors.white : cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _collectedViewMode = 'receipts'),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _collectedViewMode == 'receipts'
                            ? AppColors.primary
                            : cs.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 15,
                            color: _collectedViewMode == 'receipts' ? Colors.white : cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'All Receipts (${datePayments.length})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _collectedViewMode == 'receipts' ? Colors.white : cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // List Content: Either Grouped by Student or Flat All Receipts
          Expanded(
            child: _collectedViewMode == 'grouped'
                ? (studentGroups.isEmpty
                    ? EmptyState(
                        icon: Icons.payments_outlined,
                        title: 'No Collections',
                        subtitle: isFilteringActive
                            ? 'No fee receipts matching selected date filter'
                            : 'No student payments recorded yet',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: studentGroups.length,
                        itemBuilder: (_, i) {
                          final group = studentGroups[i];
                          final isExpanded = _expandedStudentIds.contains(group.student.id);
                          return _StudentPaymentGroupCard(
                            group: group,
                            isExpanded: isExpanded,
                            onToggleExpand: () {
                              setState(() {
                                if (isExpanded) {
                                  _expandedStudentIds.remove(group.student.id);
                                } else {
                                  _expandedStudentIds.add(group.student.id);
                                }
                              });
                            },
                            onRefresh: _load,
                          );
                        },
                      ))
                : (datePayments.isEmpty
                    ? const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No Receipts',
                        subtitle: 'No fee receipts found for this filter',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: datePayments.length,
                        itemBuilder: (_, i) => _PaymentTransactionCard(
                          payment: datePayments[i],
                          student: _findStudent(datePayments[i]),
                          onRefresh: _load,
                        ),
                      )),
          ),
        ],
      ),
    );
  }

  // ─── TAB 1: Fee Pending ─────────────────────────────────────────────────────

  Widget _buildPendingTab(ColorScheme cs) {
    final pending = _pendingRows;

    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          // Sleek Compact Summary Banner
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.error.withOpacity(0.08),
                  AppColors.error.withOpacity(0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.error.withOpacity(0.18)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Pending: ${AppUtils.formatCurrency(_totalPendingAmount)}',
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${pending.length} Due',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            'Total Collected: ${AppUtils.formatCurrency(_allPayments.fold(0.0, (sum, p) => sum + p.amount))}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                          Text(
                            ' • Due Group Paid: ${AppUtils.formatCurrency(_totalPendingPaidAmount)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (pending.isNotEmpty)
                  InkWell(
                    onTap: () => _openBulkWhatsAppReminderDialog(pending),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF25D366).withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.mark_chat_unread_rounded, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'Bulk (${pending.length})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Search + Filter Icon Button Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _pendingSearch = v),
                    decoration: InputDecoration(
                      hintText: 'Search student name, roll, class...',
                      hintStyle: TextStyle(fontSize: 13, color: cs.onSurfaceVariant.withOpacity(0.7)),
                      prefixIcon: const Icon(Icons.search, size: 19),
                      suffixIcon: _pendingSearch.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => _pendingSearch = ''),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      filled: true,
                      fillColor: cs.surfaceVariant.withOpacity(0.35),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Filter Icon Button (Opens Filter Bottom Sheet)
                InkWell(
                  onTap: () => _openFilterModal(
                    context: context,
                    currentDateMode: _pendingDateMode,
                    selectedDate: _pendingSelectedDate,
                    selectedMonth: _pendingSelectedMonth,
                    selectedClass: _pendingSelectedClass,
                    onApply: (mode, date, month, cls) {
                      setState(() {
                        _pendingDateMode = mode;
                        _pendingSelectedDate = date;
                        _pendingSelectedMonth = month;
                        _pendingSelectedClass = cls;
                      });
                    },
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: (_pendingDateMode != 'all' || _pendingSelectedClass != 'All Classes')
                          ? AppColors.primary.withOpacity(0.12)
                          : cs.surfaceVariant.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: (_pendingDateMode != 'all' || _pendingSelectedClass != 'All Classes')
                          ? Border.all(color: AppColors.primary, width: 1.2)
                          : null,
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 20,
                          color: (_pendingDateMode != 'all' || _pendingSelectedClass != 'All Classes')
                              ? AppColors.primary
                              : cs.onSurfaceVariant,
                        ),
                        if (_pendingDateMode != 'all' || _pendingSelectedClass != 'All Classes')
                          const Positioned(
                            right: -2,
                            top: -2,
                            child: CircleAvatar(
                              radius: 3.5,
                              backgroundColor: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: cs.surfaceVariant.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.sort_rounded, size: 20),
                  ),
                  tooltip: 'Sort By',
                  onSelected: (v) => setState(() => _pendingSortBy = v),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'amount', child: Text('Sort by Highest Amount')),
                    const PopupMenuItem(value: 'name', child: Text('Sort by Name')),
                    const PopupMenuItem(value: 'due', child: Text('Sort by Due Date')),
                  ],
                ),
              ],
            ),
          ),

          // Active Filter Chips Preview
          if (_pendingDateMode != 'all' || _pendingSelectedClass != 'All Classes')
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_pendingSelectedClass != 'All Classes')
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InputChip(
                          label: Text(_pendingSelectedClass, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onDeleted: () => setState(() => _pendingSelectedClass = 'All Classes'),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    if (_pendingDateMode != 'all')
                      InputChip(
                        label: Text(
                          _pendingDateMode == 'date' && _pendingSelectedDate != null
                              ? DateFormat('dd MMM').format(_pendingSelectedDate!)
                              : (_pendingDateMode == 'month' && _pendingSelectedMonth != null
                                  ? DateFormat('MMM yyyy').format(_pendingSelectedMonth!)
                                  : 'Active Date'),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onDeleted: () => setState(() => _pendingDateMode = 'all'),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            ),

          // List
          Expanded(
            child: pending.isEmpty
                ? const EmptyState(
                    icon: Icons.check_circle_outline,
                    title: 'All Clear!',
                    subtitle: 'No pending fees found',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: pending.length,
                    itemBuilder: (_, i) => _FeeRow(row: pending[i], type: 'pending', onRefresh: _load),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── TAB 2: Outstanding / Defaulters ────────────────────────────────────────

  Widget _buildOutstandingTab(ColorScheme cs) {
    final defaulters = _defaulterRows;

    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          // Sleek Compact Defaulters Summary Banner
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.error.withOpacity(0.12),
                  AppColors.warning.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.error.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.error),
                          const SizedBox(width: 4),
                          Text(
                            'Defaulters: ${AppUtils.formatCurrency(_totalDefaulterAmount)}',
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${defaulters.length} Overdue',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            'Paid: ${AppUtils.formatCurrency(_totalDefaulterPaidAmount)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                          Text(
                            ' • Total: ${AppUtils.formatCurrency(_totalDefaulterTotalFees)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search & Filter Icon Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _defaulterSearch = v),
                    decoration: InputDecoration(
                      hintText: 'Search defaulters by name or class...',
                      hintStyle: TextStyle(fontSize: 13, color: cs.onSurfaceVariant.withOpacity(0.7)),
                      prefixIcon: const Icon(Icons.search, size: 19),
                      suffixIcon: _defaulterSearch.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => _defaulterSearch = ''),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      filled: true,
                      fillColor: cs.surfaceVariant.withOpacity(0.35),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Filter Icon Button
                InkWell(
                  onTap: () => _openFilterModal(
                    context: context,
                    currentDateMode: 'all',
                    selectedDate: null,
                    selectedMonth: null,
                    selectedClass: _defaulterSelectedClass,
                    onApply: (mode, date, month, cls) {
                      setState(() {
                        _defaulterSelectedClass = cls;
                      });
                    },
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: _defaulterSelectedClass != 'All Classes'
                          ? AppColors.primary.withOpacity(0.12)
                          : cs.surfaceVariant.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: _defaulterSelectedClass != 'All Classes'
                          ? Border.all(color: AppColors.primary, width: 1.2)
                          : null,
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 20,
                          color: _defaulterSelectedClass != 'All Classes'
                              ? AppColors.primary
                              : cs.onSurfaceVariant,
                        ),
                        if (_defaulterSelectedClass != 'All Classes')
                          const Positioned(
                            right: -2,
                            top: -2,
                            child: CircleAvatar(
                              radius: 3.5,
                              backgroundColor: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: cs.surfaceVariant.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.sort_rounded, size: 20),
                  ),
                  tooltip: 'Sort Defaulters',
                  onSelected: (v) => setState(() => _defaulterSortBy = v),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'overdue', child: Text('Sort by Most Overdue Days')),
                    const PopupMenuItem(value: 'amount', child: Text('Sort by Highest Due Amount')),
                    const PopupMenuItem(value: 'name', child: Text('Sort by Student Name')),
                  ],
                ),
              ],
            ),
          ),

          // Active Class Filter Chip Preview for Defaulters
          if (_defaulterSelectedClass != 'All Classes')
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Row(
                children: [
                  InputChip(
                    label: Text(_defaulterSelectedClass, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onDeleted: () => setState(() => _defaulterSelectedClass = 'All Classes'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

          // List
          Expanded(
            child: defaulters.isEmpty
                ? const EmptyState(
                    icon: Icons.verified_user_outlined,
                    title: 'No Defaulters!',
                    subtitle: 'Great job! No students have overdue fee balances',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: defaulters.length,
                    itemBuilder: (_, i) => _DefaulterCard(row: defaulters[i], onRefresh: _load),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── Monthly Trend Chart ─────────────────────────────────────────────────────

  /// Builds a bar chart showing month-wise fee collection for the last 12 months.
  Widget _buildMonthlyTrendChart(ColorScheme cs) {
    // Group all payments by YYYY-MM
    final Map<String, double> monthlyTotals = {};
    for (final p in _allPayments) {
      final key = DateFormat('yyyy-MM').format(p.paymentDate.toLocal());
      monthlyTotals[key] = (monthlyTotals[key] ?? 0) + p.amount;
    }

    if (monthlyTotals.isEmpty) return const SizedBox.shrink();

    // Last 12 months sorted
    final now = DateTime.now();
    final months = List.generate(12, (i) {
      final d = DateTime(now.year, now.month - 11 + i, 1);
      return DateFormat('yyyy-MM').format(d);
    });

    final entries = months.map((k) => MapEntry(k, monthlyTotals[k] ?? 0.0)).toList();
    final maxVal = entries.map((e) => e.value).fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Monthly Collection Trend',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                'Last 12 Months',
                style: TextStyle(
                  fontSize: 10,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: entries.map((e) {
                final fraction = maxVal > 0 ? e.value / maxVal : 0.0;
                final isCurrentMonth = e.key == DateFormat('yyyy-MM').format(now);
                final label = DateFormat('MMM').format(DateTime.parse('${e.key}-01'));
                final hasData = e.value > 0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (hasData)
                          Container(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              AppUtils.formatCurrency(e.value)
                                  .replaceAll('₹', '')
                                  .replaceAll(',000', 'k')
                                  .replaceAll(',', '.'),
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w700,
                                color: isCurrentMonth ? AppColors.primary : cs.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          height: hasData ? (fraction * 70).clamp(4.0, 70.0) : 3,
                          decoration: BoxDecoration(
                            gradient: hasData
                                ? LinearGradient(
                                    colors: isCurrentMonth
                                        ? [AppColors.primary, AppColors.primary.withOpacity(0.7)]
                                        : [AppColors.success, AppColors.success.withOpacity(0.6)],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  )
                                : null,
                            color: hasData ? null : cs.outlineVariant.withOpacity(0.3),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: isCurrentMonth ? FontWeight.w800 : FontWeight.w500,
                            color: isCurrentMonth ? AppColors.primary : cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB 3: Transaction Register ────────────────────────────────────────────

  Widget _buildTransactionsTab(ColorScheme cs) {
    final now = DateTime.now();
    final transactions = _filteredTransactions;

    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          // Filter Bar
          _buildDateFilterBar(
            cs: cs,
            mode: _transactionDateMode,
            selectedDate: _transactionSelectedDate,
            selectedMonth: _transactionSelectedMonth,
            onAllTap: () => setState(() => _transactionDateMode = 'all'),
            onTodayTap: () {
              setState(() {
                _transactionSelectedDate = DateTime.now();
                _transactionDateMode = 'date';
              });
            },
            onThisMonthTap: () {
              setState(() {
                _transactionSelectedMonth = DateTime(now.year, now.month);
                _transactionDateMode = 'month';
              });
            },
            onPickDateTap: () {
              _pickDateFor(
                context: context,
                currentDate: _transactionSelectedDate,
                onSelected: (picked) {
                  setState(() {
                    _transactionSelectedDate = picked;
                    _transactionDateMode = 'date';
                  });
                },
              );
            },
            onPickMonthTap: () {
              _pickMonthFor(
                context: context,
                currentMonth: _transactionSelectedMonth,
                onSelected: (picked) {
                  setState(() {
                    _transactionSelectedMonth = picked;
                    _transactionDateMode = 'month';
                  });
                },
              );
            },
          ),

          // Total Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: cs.surfaceVariant.withOpacity(0.4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      '${transactions.length} Transactions',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Total: ${AppUtils.formatCurrency(_filteredTransactionsTotal)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),

          // Monthly trend chart — only visible when no date filter is active
          if (_transactionDateMode == 'all') _buildMonthlyTrendChart(cs),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              onChanged: (v) => setState(() => _transactionSearch = v),
              decoration: InputDecoration(
                hintText: 'Search receipt #, student name, or payment mode...',
                hintStyle: TextStyle(fontSize: 13, color: cs.onSurfaceVariant.withOpacity(0.7)),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _transactionSearch.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _transactionSearch = ''),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                filled: true,
                fillColor: cs.surfaceVariant.withOpacity(0.35),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // List
          Expanded(
            child: transactions.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No Transactions',
                    subtitle: 'No payment transactions matched your filter',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: transactions.length,
                    itemBuilder: (_, i) => _PaymentTransactionCard(
                      payment: transactions[i],
                      student: _findStudent(transactions[i]),
                      onRefresh: _load,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statusFilterChip(
    String label,
    String value,
    String currentValue,
    ValueChanged<String> onChanged,
    ColorScheme cs,
  ) {
    final sel = currentValue == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : cs.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: sel ? Colors.white : cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ─── Fees Pending Screen Wrapper (Direct Link from Dashboard) ─────────────────

class FeesPendingScreen extends StatelessWidget {
  const FeesPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeesCollectedScreen(initialTabIndex: 1);
  }
}

// ─── Defaulter Card Component ─────────────────────────────────────────────────

class _DefaulterCard extends ConsumerWidget {
  final _StudentFeeRow row;
  final VoidCallback? onRefresh;
  const _DefaulterCard({required this.row, this.onRefresh});

  Future<void> _callParent(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final s = row.student;
    final fee = row.fee;
    final overdueDays = fee.overdueDays;

    return Card(
      color: cs.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.error.withOpacity(0.2), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top: Name + Overdue Tag
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: cs.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${s.displayClass} • Adm #${s.admissionNumber}',
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    overdueDays > 0 ? '$overdueDays DAYS OVERDUE' : 'OVERDUE',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Due amounts row
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pending Due', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                      const SizedBox(height: 2),
                      Text(
                        AppUtils.formatCurrency(fee.remaining),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Paid / Total Fee', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: AppUtils.formatCurrency(fee.totalPaid),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                            ),
                            TextSpan(
                              text: ' / ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            TextSpan(
                              text: AppUtils.formatCurrency(fee.totalFees),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (fee.dueDate != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.event, size: 12, color: AppColors.error),
                  const SizedBox(width: 4),
                  Text(
                    'Due Date: ${DateFormat('dd MMM yyyy').format(fee.dueDate!)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Action Buttons: Call Parent, WhatsApp Reminder, Collect Fee
            Row(
              children: [
                // Call Parent
                if (s.mobile.isNotEmpty) ...[
                  OutlinedButton.icon(
                    onPressed: () => _callParent(s.mobile),
                    icon: const Icon(Icons.phone_rounded, size: 15),
                    label: const Text('Call', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary.withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // WhatsApp Reminder
                OutlinedButton.icon(
                  onPressed: () {
                    final settings = ref.read(settingsProvider).value ?? SettingsModel.defaultSettings();
                    WhatsAppService.showFeeReminderDialog(
                      context,
                      student: s,
                      settings: settings,
                      dueAmount: fee.remaining,
                      totalFee: fee.totalFees,
                      paidFee: fee.totalPaid,
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366), size: 15),
                  label: const Text('WhatsApp', style: TextStyle(fontSize: 12, color: Color(0xFF25D366))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF25D366), width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const Spacer(),

                // Collect Fee button
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.pushNamed(context, AppRoutes.fees, arguments: s.id);
                    onRefresh?.call();
                  },
                  icon: const Icon(Icons.payment_rounded, size: 15),
                  label: const Text('Pay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Student Payment Group Model & Expandable Dropdown Card ──────────────────

class _StudentPaymentGroup {
  final StudentModel student;
  final List<PaymentModel> payments;

  _StudentPaymentGroup({
    required this.student,
    required this.payments,
  });

  double get totalCollected => payments.fold(0.0, (sum, p) => sum + p.amount);
}

void _sendFullFeeStatement(
  BuildContext context, {
  required StudentModel student,
  required List<PaymentModel> payments,
  required SettingsModel settings,
}) {
  final totalPaid = payments.fold(0.0, (sum, p) => sum + p.amount);
  final buffer = StringBuffer();
  buffer.writeln('🧾 *COMPLETE FEE PAYMENT STATEMENT*');
  buffer.writeln('*${settings.instituteName.toUpperCase()}*');
  if (settings.address.isNotEmpty) buffer.writeln('📍 ${settings.address}');
  if (settings.phone.isNotEmpty) buffer.writeln('📞 ${settings.phone}');
  buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
  buffer.writeln('👤 *Student:* ${student.name}');
  buffer.writeln('🆔 *Student ID:* ${student.studentId}');
  buffer.writeln('📄 *Admission No:* ${student.admissionNumber}');
  buffer.writeln('🏫 *Class:* ${student.displayClass}');
  buffer.writeln('💰 *Total Fees Received:* ${AppUtils.formatCurrency(totalPaid)} (${payments.length} Receipts)');
  buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
  buffer.writeln('📋 *RECEIPTS BREAKDOWN:*');
  for (int i = 0; i < payments.length; i++) {
    final p = payments[i];
    final dateStr = DateFormat('dd MMM yyyy').format(p.paymentDate);
    buffer.writeln('${i + 1}. *Receipt #${p.receiptNumber}* ($dateStr): ${AppUtils.formatCurrency(p.amount)} [${p.paymentMode.toUpperCase()}]');
  }
  buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
  buffer.writeln('*Thank you for timely fee payment!*');
  buffer.writeln('*${settings.instituteName}*');

  WhatsAppService.sendMessage(
    context: context,
    phone: student.mobile,
    message: buffer.toString(),
  );
}

Future<void> _sendSingleReceiptWhatsApp(
  BuildContext context, {
  required PaymentModel payment,
  required StudentModel? student,
  required SettingsModel settings,
}) async {
  StudentModel? s = student;
  if (s == null && payment.studentId.isNotEmpty) {
    s = await DatabaseService.instance.getStudentById(payment.studentId) ??
        await DatabaseService.instance.getStudentByQrId(payment.studentId);
  }
  if (s == null && payment.admissionNumber != null && payment.admissionNumber!.isNotEmpty) {
    s = await DatabaseService.instance.getStudentByQrId(payment.admissionNumber!);
  }
  if (s == null && payment.studentName != null && payment.studentName!.isNotEmpty) {
    try {
      final all = await DatabaseService.instance.getAllStudents();
      s = all.firstWhere((st) => st.name.trim().toLowerCase() == payment.studentName!.trim().toLowerCase());
    } catch (_) {}
  }
  if (s == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student details not found for this receipt.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
    return;
  }

  try {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rendering official PDF Receipt for ${s.name}…'),
          duration: const Duration(seconds: 1),
        ),
      );
    }

    MonthlyFeeModel? fee;
    final feeMonthRaw = payment.feeMonth ?? payment.monthKey ?? '';
    final mKey = PaymentModel.toMonthKey(feeMonthRaw, payment.paymentDate);
    final feeMonthLabel = PaymentModel.toFeeMonthLabel(feeMonthRaw.isNotEmpty ? feeMonthRaw : mKey, payment.paymentDate);

    if (mKey.isNotEmpty) {
      try {
        fee = await DatabaseService.instance.getMonthlyFee(s.id, mKey) ??
            await DatabaseService.instance.getMonthlyFee(s.studentId, mKey) ??
            await DatabaseService.instance.getMonthlyFee(payment.studentId, mKey);
      } catch (_) {}
    }

    final struct = await DatabaseService.instance.getFeeStructure(s.id) ??
        await DatabaseService.instance.getFeeStructure(s.studentId);
    final aggFee = await DatabaseService.instance.getFeeByStudentId(s.id) ??
        await DatabaseService.instance.getFeeByStudentId(s.studentId);

    final double standardMonthlyTuition = (struct?.tuitionFee != null && struct!.tuitionFee > 0)
        ? struct.tuitionFee
        : ((s.feeStructure != null && (s.feeStructure!['tuitionFee'] as num?)?.toDouble() != null && ((s.feeStructure!['tuitionFee'] as num).toDouble() > 0))
            ? (s.feeStructure!['tuitionFee'] as num).toDouble()
            : (s.monthlyFee != null && s.monthlyFee! > 0
                ? s.monthlyFee!
                : (fee?.tuitionFee != null && fee!.tuitionFee > 0
                    ? fee.tuitionFee
                    : 0.0)));
    final double totalMonthDemand = payment.totalDemand != null && payment.totalDemand! > 0
        ? payment.totalDemand!
        : (fee?.totalDue != null && fee!.totalDue > 0
            ? fee.totalDue
            : (standardMonthlyTuition > 0
                ? standardMonthlyTuition
                : (s.initialTotalFees != null && s.initialTotalFees! > 0 ? s.initialTotalFees! : payment.amount)));

    final double monthDue = payment.balanceDue ??
        (fee != null && fee.remaining >= 0
            ? fee.remaining
            : (totalMonthDemand - payment.amount).clamp(0.0, double.infinity));
    final double overallStudentDue = s.remainingFees ?? s.totalPending ?? aggFee?.remainingFees ?? 0.0;

    final filePath = await ReceiptPdfService.instance.createPdfFile(
      student: s,
      payment: payment,
      settings: settings,
      fee: fee,
    );

    final sName = s.name;
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(payment.paymentDate);
    final buffer = StringBuffer();
    buffer.writeln('🧾 *FEE RECEIPT VOUCHER*');
    buffer.writeln('*${settings.instituteName.toUpperCase()}*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('👤 *Student:* $sName');
    if (s.fatherName.isNotEmpty) {
      buffer.writeln('👨‍👦 *Father:* ${s.fatherName}');
    }
    buffer.writeln('🏫 *Class:* ${s.displayClass}');
    buffer.writeln('📄 *Receipt No:* #${payment.receiptNumber}');
    buffer.writeln('📅 *Date:* $dateStr');
    if (feeMonthLabel.isNotEmpty) {
      buffer.writeln('📆 *Fee Month:* $feeMonthLabel');
    }
    buffer.writeln('💵 *Amount Received:* ${AppUtils.formatCurrency(payment.amount)} (${payment.paymentMode.toUpperCase()})');
    if (monthDue > 0) {
      buffer.writeln('⚠️ *Month Balance Due:* ${AppUtils.formatCurrency(monthDue)}');
    } else {
      buffer.writeln('✅ *Month Status:* Fully Cleared');
    }
    if (overallStudentDue > 0 && (overallStudentDue - monthDue).abs() > 1) {
      buffer.writeln('📌 *Total Overall Pending Dues:* ${AppUtils.formatCurrency(overallStudentDue)}');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Payment received successfully. Thank you!');
    if (settings.mobile.isNotEmpty) {
      buffer.writeln('📞 *Helpline:* ${settings.mobile}');
    }
    buffer.writeln('*${settings.instituteName}*');

    final phone = s.mobile.trim().isNotEmpty
        ? s.mobile.trim()
        : (s.alternateMobile?.trim() ?? '');

    if (!context.mounted) return;
    await WhatsAppService.showReceiptShareSheet(
      context,
      studentName: s.name,
      phone: phone,
      alternatePhone: s.alternateMobile,
      receiptNumber: payment.receiptNumber,
      message: buffer.toString(),
      filePath: filePath,
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not generate or send PDF receipt: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

Future<void> _printOrViewReceiptPdf(
  BuildContext context, {
  required PaymentModel payment,
  required StudentModel? student,
  required SettingsModel settings,
}) async {
  StudentModel? s = student;
  if (s == null && payment.studentId.isNotEmpty) {
      s = await DatabaseService.instance.getStudentById(payment.studentId) ??
          await DatabaseService.instance.getStudentByQrId(payment.studentId);
  }
  if (s == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student details not found for this receipt.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
    return;
  }

  try {
    MonthlyFeeModel? fee;
    final feeMonthRaw = payment.feeMonth ?? payment.monthKey ?? '';
    final mKey = PaymentModel.toMonthKey(feeMonthRaw, payment.paymentDate);
    if (mKey.isNotEmpty) {
      try {
        fee = await DatabaseService.instance.getMonthlyFee(s.id, mKey) ??
            await DatabaseService.instance.getMonthlyFee(s.studentId, mKey) ??
            await DatabaseService.instance.getMonthlyFee(payment.studentId, mKey);
      } catch (_) {}
    }
    final doc = await ReceiptPdfService.instance.generateDocument(
      student: s,
      payment: payment,
      settings: settings,
      fee: fee,
    );
    await Printing.layoutPdf(
      name: 'Receipt_${payment.receiptNumber}_${s.name}.pdf',
      onLayout: (_) => doc.save(),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open PDF receipt: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _StudentPaymentGroupCard extends ConsumerWidget {
  final _StudentPaymentGroup group;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onRefresh;

  const _StudentPaymentGroupCard({
    required this.group,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final s = group.student;
    final payments = group.payments;
    final totalCollected = group.totalCollected;

    return Card(
      color: cs.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isExpanded ? AppColors.primary.withOpacity(0.5) : cs.outlineVariant.withOpacity(0.4),
          width: isExpanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (Tappable to expand/collapse dropdown)
          InkWell(
            onTap: onToggleExpand,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(16),
              bottom: isExpanded ? Radius.zero : const Radius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.success.withOpacity(0.12),
                    child: Text(
                      s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Student Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: cs.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${s.displayClass} • Adm #${s.admissionNumber}',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${payments.length} ${payments.length == 1 ? 'Receipt' : 'Receipts'}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Total Collected Amount + Expand Arrow
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total Collected',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppUtils.formatCurrency(totalCollected),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isExpanded ? AppColors.primary : cs.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          size: 18,
                          color: isExpanded ? Colors.white : cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Dropdown Body (Visible when isExpanded == true)
          if (isExpanded) ...[
            Divider(height: 1, color: cs.outlineVariant.withOpacity(0.4)),

            // Action Bar (Send Statement WhatsApp + Manage Fee)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: cs.surfaceVariant.withOpacity(0.25),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final settings = ref.read(settingsProvider).value ?? SettingsModel.defaultSettings();
                        _sendFullFeeStatement(context, student: s, payments: payments, settings: settings);
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366), size: 16),
                      label: const Text(
                        'WhatsApp Statement',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E7E34)),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        side: const BorderSide(color: Color(0xFF25D366), width: 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        backgroundColor: const Color(0xFF25D366).withOpacity(0.06),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.pushNamed(context, AppRoutes.fees, arguments: s.id);
                        onRefresh();
                      },
                      icon: const Icon(Icons.payment_rounded, size: 16),
                      label: const Text(
                        'Fee Structure / Pay',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Receipts Sub-List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(10),
              itemCount: payments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, pIdx) {
                final p = payments[pIdx];
                final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(p.paymentDate);

                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.surfaceVariant.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      // Receipt Icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt_rounded, size: 18, color: AppColors.success),
                      ),
                      const SizedBox(width: 10),

                      // Receipt Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Receipt #${p.receiptNumber}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: cs.surface,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
                                  ),
                                  child: Text(
                                    p.paymentMode.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateStr,
                              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                            ),
                            if (p.feeMonth != null && p.feeMonth!.isNotEmpty)
                              Text(
                                'Month: ${p.feeMonth}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Amount & WhatsApp button
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '+${AppUtils.formatCurrency(p.amount)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () {
                                  final settings = ref.read(settingsProvider).value ?? SettingsModel.defaultSettings();
                                  _printOrViewReceiptPdf(context, payment: p, student: s, settings: settings);
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.print_rounded, size: 11, color: AppColors.primary),
                                      SizedBox(width: 3),
                                      Text(
                                        'PDF',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () {
                                  final settings = ref.read(settingsProvider).value ?? SettingsModel.defaultSettings();
                                  _sendSingleReceiptWhatsApp(context, payment: p, student: s, settings: settings);
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF25D366).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF25D366).withOpacity(0.4)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.picture_as_pdf_rounded, size: 11, color: Color(0xFF1E7E34)),
                                      SizedBox(width: 3),
                                      Text(
                                        'Share PDF',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1E7E34),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Payment Transaction Card (For Collected & Transaction Register Tabs) ─────

class _PaymentTransactionCard extends StatelessWidget {
  final PaymentModel payment;
  final StudentModel? student;
  final VoidCallback? onRefresh;

  const _PaymentTransactionCard({
    required this.payment,
    required this.student,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final studentName = student?.name ?? payment.studentName ?? 'Student';
    final className = student != null
        ? student!.displayClass
        : (payment.className ?? '—');
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(payment.paymentDate);

    return Card(
      color: cs.surface,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () async {
          if (student != null) {
            await Navigator.pushNamed(context, AppRoutes.fees, arguments: student!.id);
            onRefresh?.call();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Receipt Avatar / Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.receipt_rounded, color: AppColors.success, size: 22),
                ),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: cs.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$className • Receipt #${payment.receiptNumber}',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    if (payment.feeMonth != null && payment.feeMonth!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Fee Month: ${payment.feeMonth}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Amount + Payment Mode + Time
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '+${AppUtils.formatCurrency(payment.amount)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      payment.paymentMode.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 9,
                      color: cs.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Action Buttons: Print PDF & Share PDF
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: () async {
                  final settings = await DatabaseService.instance.getSettings();
                  if (context.mounted) {
                    _printOrViewReceiptPdf(context, payment: payment, student: student, settings: settings);
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.print_rounded, size: 13, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text(
                        'Print PDF',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () async {
                  final settings = await DatabaseService.instance.getSettings();
                  if (context.mounted) {
                    _sendSingleReceiptWhatsApp(context, payment: payment, student: student, settings: settings);
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF25D366).withOpacity(0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.picture_as_pdf_rounded, size: 13, color: Color(0xFF1E7E34)),
                      SizedBox(width: 4),
                      Text(
                        'Share PDF',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E7E34),
                        ),
                      ),
                    ],
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
}

// ─── Shared Fee Row Card (For Collected & Pending Tabs) ────────────────────────

class _FeeRow extends ConsumerWidget {
  final _StudentFeeRow row;
  final String type; // collected | pending
  final VoidCallback? onRefresh;

  const _FeeRow({required this.row, required this.type, this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final s = row.student;
    final fee = row.fee;
    final isPending = type == 'pending';

    return Card(
      color: cs.surface,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () async {
          await Navigator.pushNamed(context, AppRoutes.fees, arguments: s.id);
          onRefresh?.call();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name + Status + WhatsApp Quick Action
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: cs.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isPending && fee.remaining > 0) ...[
                    IconButton(
                      onPressed: () {
                        final settings = ref.read(settingsProvider).value ?? SettingsModel.defaultSettings();
                        WhatsAppService.showFeeReminderDialog(
                          context,
                          student: s,
                          settings: settings,
                          dueAmount: fee.remaining,
                          totalFee: fee.totalFees,
                          paidFee: fee.totalPaid,
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366), size: 18),
                      tooltip: 'Send WhatsApp Reminder',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPending
                          ? (fee.isOverdue ? AppColors.error : AppColors.warning).withOpacity(0.12)
                          : AppColors.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isPending
                          ? (fee.isOverdue ? 'OVERDUE' : 'PENDING')
                          : fee.feeStatus.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: isPending
                            ? (fee.isOverdue ? AppColors.error : AppColors.warning)
                            : AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Info row
              Row(
                children: [
                  Icon(Icons.numbers, size: 11, color: cs.onSurfaceVariant),
                  const SizedBox(width: 3),
                  Text(s.admissionNumber, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  const SizedBox(width: 10),
                  Icon(Icons.school_outlined, size: 11, color: cs.onSurfaceVariant),
                  const SizedBox(width: 3),
                  Text(s.displayClass, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  const SizedBox(width: 10),
                  Icon(Icons.phone_outlined, size: 11, color: cs.onSurfaceVariant),
                  const SizedBox(width: 3),
                  Text(s.mobile, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 10),

              // Amounts Section (Matching Website Table: Monthly Fee, Accrued, Paid, Outstanding)
              if (isPending) ...[
                Row(
                  children: [
                    _amountBox(
                      'Monthly Fee',
                      (s.feeStructure?['tuitionFee'] as num?)?.toDouble() ?? s.monthlyFee ?? 0.0,
                      cs.onSurfaceVariant,
                      cs,
                      suffix: '/mo',
                    ),
                    const SizedBox(width: 6),
                    _amountBox('Accrued Total', fee.totalFees, cs.onSurfaceVariant, cs),
                    const SizedBox(width: 6),
                    _amountBox('Paid Fees', fee.totalPaid, AppColors.success, cs),
                    const SizedBox(width: 6),
                    _amountBox('Outstanding Due', fee.remaining, AppColors.error, cs),
                  ],
                ),
                const SizedBox(height: 10),
                // Website Action Buttons (WhatsApp & Fee Structure)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final settings = ref.read(settingsProvider).value ?? SettingsModel.defaultSettings();
                          WhatsAppService.showFeeReminderDialog(
                            context,
                            student: s,
                            settings: settings,
                            dueAmount: fee.remaining,
                            totalFee: fee.totalFees,
                            paidFee: fee.totalPaid,
                          );
                        },
                        icon: const Icon(Icons.mark_chat_unread_rounded, size: 15, color: Color(0xFF25D366)),
                        label: const Text(
                          'WhatsApp',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E7E34)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF25D366), width: 1.2),
                          backgroundColor: const Color(0xFF25D366).withOpacity(0.08),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await Navigator.pushNamed(context, AppRoutes.fees, arguments: s.id);
                          onRefresh?.call();
                        },
                        icon: const Icon(Icons.payment_rounded, size: 15),
                        label: const Text(
                          'Fee Structure',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    _amountBox('Total', fee.totalFees, cs.onSurfaceVariant, cs),
                    const SizedBox(width: 8),
                    _amountBox('Paid (All-Time)', fee.totalPaid, AppColors.success, cs),
                    const SizedBox(width: 8),
                    _amountBox(
                      'Remaining',
                      fee.remaining,
                      AppColors.success,
                      cs,
                    ),
                  ],
                ),
              ],

              // Due date (pending only)
              if (isPending && fee.dueDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event,
                        size: 12,
                        color: fee.isOverdue ? AppColors.error : cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Due: ${DateFormat('dd MMM yyyy').format(fee.dueDate!)}'
                        '${fee.isOverdue ? '  ⚠️ ${fee.overdueDays} days overdue' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color: fee.isOverdue ? AppColors.error : cs.onSurfaceVariant,
                          fontWeight: fee.isOverdue ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _amountBox(String label, double amount, Color color, ColorScheme cs, {String suffix = ''}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 8.5, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              '₹${amount.toStringAsFixed(0)}$suffix',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bulk WhatsApp Reminder Dialog (1-Click Auto Send) ────────────────────────

class _BulkWhatsAppReminderDialog extends StatefulWidget {
  final List<_StudentFeeRow> rows;
  final SettingsModel settings;

  const _BulkWhatsAppReminderDialog({
    required this.rows,
    required this.settings,
  });

  @override
  State<_BulkWhatsAppReminderDialog> createState() => _BulkWhatsAppReminderDialogState();
}

class _BulkWhatsAppReminderDialogState extends State<_BulkWhatsAppReminderDialog> {
  String _lang = 'hi';
  late Set<String> _selectedIds;
  final Set<String> _sentStudentIds = {};
  Map<String, List<PaymentModel>> _studentPaymentsCache = {};

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.rows.map((r) => r.student.id).toSet();
    _preloadPayments();
  }

  Future<void> _preloadPayments() async {
    for (final row in widget.rows) {
      try {
        final pList = await DatabaseService.instance.getPayments(row.student.id);
        if (mounted) {
          setState(() {
            _studentPaymentsCache[row.student.id] = pList;
          });
        }
      } catch (_) {}
    }
  }

  String _buildMessageForStudent(_StudentFeeRow row) {
    final s = row.student;
    final fee = row.fee;
    final pList = _studentPaymentsCache[s.id] ?? [];

    return WhatsAppService.buildDetailedFeeReminderMessage(
      student: s,
      settings: widget.settings,
      dueAmount: fee.remaining,
      totalFee: fee.totalFees,
      paidFee: fee.totalPaid,
      payments: pList,
      lang: _lang,
    );
  }

  Future<void> _sendToStudent(_StudentFeeRow row) async {
    final s = row.student;
    final phone = s.alternateMobile?.isNotEmpty == true ? s.alternateMobile! : s.mobile;
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No valid phone number for ${s.name}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final message = _buildMessageForStudent(row);

    setState(() {
      _sentStudentIds.add(s.id);
    });

    await WhatsAppService.sendMessage(
      context: context,
      phone: clean,
      message: message,
    );
  }

  _StudentFeeRow? get _nextPendingRow {
    final selectedRows = widget.rows.where((r) => _selectedIds.contains(r.student.id)).toList();
    for (final r in selectedRows) {
      if (!_sentStudentIds.contains(r.student.id)) {
        return r;
      }
    }
    return null;
  }

  void _previewMessageDialog(_StudentFeeRow row) {
    final msg = _buildMessageForStudent(row);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Message Preview: ${row.student.name}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: SelectableText(
            msg,
            style: const TextStyle(fontSize: 12, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _sendToStudent(row);
            },
            icon: const Icon(Icons.send_rounded, size: 14),
            label: const Text('Send on WhatsApp'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selectedRows = widget.rows.where((r) => _selectedIds.contains(r.student.id)).toList();
    final totalDue = selectedRows.fold(0.0, (sum, r) => sum + r.fee.remaining);
    final sentCount = selectedRows.where((r) => _sentStudentIds.contains(r.student.id)).length;
    final nextRow = _nextPendingRow;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.mark_chat_unread_rounded, color: Color(0xFF25D366), size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bulk Due WhatsApp Reminder',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_selectedIds.length} of ${widget.rows.length} selected · Total: ${AppUtils.formatCurrency(totalDue)}',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Language Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('🇮🇳 हिंदी (Hindi)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  selected: _lang == 'hi',
                  onSelected: (sel) { if (sel) setState(() => _lang = 'hi'); },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('🇬🇧 English', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  selected: _lang == 'en',
                  onSelected: (sel) { if (sel) setState(() => _lang = 'en'); },
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Select all / Deselect all + Sent counter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedIds.length == widget.rows.length) {
                        _selectedIds.clear();
                      } else {
                        _selectedIds = widget.rows.map((r) => r.student.id).toSet();
                      }
                    });
                  },
                  child: Text(
                    _selectedIds.length == widget.rows.length ? 'Deselect All' : 'Select All',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: sentCount == selectedRows.length && selectedRows.isNotEmpty
                        ? AppColors.success.withOpacity(0.12)
                        : cs.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Sent: $sentCount / ${selectedRows.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: sentCount == selectedRows.length && selectedRows.isNotEmpty
                          ? AppColors.success
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),

            // Student list with checkboxes & per-student status
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 270),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final row = widget.rows[i];
                  final s = row.student;
                  final fee = row.fee;
                  final isChecked = _selectedIds.contains(s.id);
                  final isSent = _sentStudentIds.contains(s.id);
                  final father = s.fatherName.trim();

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isChecked,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedIds.add(s.id);
                              } else {
                                _selectedIds.remove(s.id);
                              }
                            });
                          },
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => _previewMessageDialog(row),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        s.name,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isSent) ...[
                                      const SizedBox(width: 5),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.success.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Sent',
                                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.success),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  '${s.displayClass}${father.isNotEmpty ? " • S/O $father" : ""} · Due: ${AppUtils.formatCurrency(fee.remaining)}',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: isSent ? cs.onSurfaceVariant : AppColors.error,
                                    fontWeight: isSent ? FontWeight.normal : FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // 1-Tap send button on row
                        IconButton(
                          icon: Icon(
                            isSent ? Icons.check_circle_rounded : Icons.send_rounded,
                            size: 18,
                            color: isSent ? AppColors.success : const Color(0xFF25D366),
                          ),
                          tooltip: 'Send reminder to ${s.name}',
                          onPressed: () => _sendToStudent(row),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      actions: [
        Row(
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            const Spacer(),
            if (nextRow != null)
              ElevatedButton.icon(
                onPressed: () => _sendToStudent(nextRow),
                icon: const Icon(Icons.send_rounded, size: 14),
                label: Text(
                  'Send Next: ${nextRow.student.name.split(' ').first}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.check_circle_rounded, size: 14),
                label: const Text(
                  'All Done',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
