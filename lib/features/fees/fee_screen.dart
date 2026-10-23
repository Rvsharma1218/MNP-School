import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/fee_model.dart';
import '../../data/models/student_model.dart';
import '../../data/services/database_service.dart';
import '../../data/services/providers.dart';
import '../../widgets/common_widgets.dart';
import '../../data/services/firestore_service.dart';
import '../../data/services/receipt_pdf_service.dart';
import '../whatsapp/whatsapp_service.dart';

const List<int> _kDueDayOptions = [5, 10, 15, 20, 25];

class FeeScreen extends ConsumerStatefulWidget {
  final String studentId;
  const FeeScreen({super.key, required this.studentId});

  @override
  ConsumerState<FeeScreen> createState() => _FeeScreenState();
}

class _FeeScreenState extends ConsumerState<FeeScreen> {
  StudentModel? _student;
  MonthlyFeeModel? _fee;
  bool _loading = true;
  bool _saving = false;

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  final _paymentCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  String _paymentMode = 'Cash';

  final _modes = [
    'Cash',
    'UPI',
    'Bank Transfer',
    'Card',
    'Cheque',
    'NEFT',
  ];

  final Map<String, TextEditingController> _feeCtrls = {};

  List<PaymentModel> _payments = [];
  final _fsTuitionCtrl = TextEditingController();
  final _fsTransportCtrl = TextEditingController();
  final _fsGameCtrl = TextEditingController();
  final _fsFineCtrl = TextEditingController();
  int _fsDueDay = 10;

  static const Map<String, String> _feeFields = {
    'admissionFee': 'Admission Fee',
    'tuitionFee': 'Tuition Fee',
    'examinationFee': 'Examination Fee',
    'previousDue': 'Previous Dues',
    'gameFee': 'Game Fee',
    'reAdmissionFee': 'Re-Admission Fee',
    'developmentFee': 'Development Fee',
    'schoolIdFee': 'School ID',
    'tieBagBeltFee': 'Tie, Bag, Belt',
    'backDues': 'Back Dues',
    'transportFee': 'Transport Fee',
    'otherFee': 'Other Fee',
    'lateFine': 'Late Fine',
  };

  @override
  void initState() {
    super.initState();
    for (final key in _feeFields.keys) {
      final ctrl = TextEditingController();
      ctrl.addListener(() {
        if (mounted) setState(() {});
      });
      _feeCtrls[key] = ctrl;
    }
    _load();
  }

  @override
  void dispose() {
    _paymentCtrl.dispose();
    _remarksCtrl.dispose();
    for (final c in _feeCtrls.values) {
      c.dispose();
    }
    _fsTuitionCtrl.dispose();
    _fsTransportCtrl.dispose();
    _fsGameCtrl.dispose();
    _fsFineCtrl.dispose();
    super.dispose();
  }

  String get _monthKey =>
      '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final student =
      await DatabaseService.instance.getStudentById(widget.studentId);

      final structure =
      await DatabaseService.instance.getFeeStructure(widget.studentId);

      final payments =
      await DatabaseService.instance.getPayments(widget.studentId);

      final monthly = await DatabaseService.instance.ensureMonthlyFee(
        studentId: widget.studentId,
        month: _monthKey,
        autoCreate: false,
      );

      if (!mounted) return;
      setState(() {
        _student = student;
        _fee = monthly;
        _payments = payments;
        _loading = false;
      });
      _fillControllers(monthly);
      _fillStructureControllers(structure);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _error(e.toString());
      }
    }
  }

  void _fillControllers(MonthlyFeeModel fee) {
    final values = {
      'admissionFee': fee.admissionFee,
      'tuitionFee': fee.tuitionFee,
      'examinationFee': fee.examinationFee,
      'previousDue': fee.previousDue,
      'gameFee': fee.gameFee,
      'reAdmissionFee': fee.reAdmissionFee,
      'developmentFee': fee.developmentFee,
      'schoolIdFee': fee.schoolIdFee,
      'tieBagBeltFee': fee.tieBagBeltFee,
      'backDues': fee.backDues,
      'transportFee': fee.transportFee,
      'otherFee': fee.otherFee,
      'lateFine': fee.lateFine,
    };

    for (final entry in values.entries) {
      _feeCtrls[entry.key]!.text =
      entry.value == 0 ? '' : entry.value.toStringAsFixed(0);
    }
  }

  void _fillStructureControllers(StudentFeeStructureModel? structure) {
    _fsTuitionCtrl.text = structure == null || structure.tuitionFee == 0
        ? ''
        : structure.tuitionFee.toStringAsFixed(0);
    _fsTransportCtrl.text = structure == null || structure.transportFee == 0
        ? ''
        : structure.transportFee.toStringAsFixed(0);
    _fsGameCtrl.text = structure == null || structure.gameFee == 0
        ? ''
        : structure.gameFee.toStringAsFixed(0);
    _fsFineCtrl.text = structure == null || structure.finePerDay == 0
        ? ''
        : structure.finePerDay.toStringAsFixed(0);
    _fsDueDay = structure?.dueDay ?? 10;
    if (!_kDueDayOptions.contains(_fsDueDay)) _fsDueDay = 10;
  }

  double _v(String key) =>
      double.tryParse(_feeCtrls[key]!.text.trim()) ?? 0;

  double get _demandTotal =>
      _feeFields.keys.fold(0.0, (sum, key) => sum + _v(key));

  List<PaymentModel> get _monthPaymentsList {
    final formattedMonth = _formatMonth(_monthKey);
    return _payments.where((p) {
      final fm = p.feeMonth ?? '';
      final pd = p.paymentDate.toIso8601String();
      if (fm == _monthKey || fm == formattedMonth || pd.startsWith(_monthKey)) {
        return true;
      }
      if (fm.toLowerCase().contains(formattedMonth.toLowerCase())) {
        return true;
      }
      return false;
    }).toList();
  }

  double get _previousDueAmount => _v('previousDue');

  double get _paidForMonth {
    final list = _monthPaymentsList;
    if (list.isNotEmpty) {
      return list.fold<double>(0.0, (sum, p) => sum + p.amount);
    }
    return _fee?.paidAmount ?? 0.0;
  }

  double get _remaining =>
      (_demandTotal - _paidForMonth).clamp(0.0, double.infinity);

  Future<MonthlyFeeModel> _saveDemandInternal() async {
    final additionalFees = <FeeLineItem>[
      FeeLineItem(
        key: 'previousDue',
        label: 'Previous Dues',
        amount: _v('previousDue'),
      ),
      FeeLineItem(
        key: 'admissionFee',
        label: 'Admission Fee',
        amount: _v('admissionFee'),
      ),
      FeeLineItem(
        key: 'examinationFee',
        label: 'Examination Fee',
        amount: _v('examinationFee'),
      ),
      FeeLineItem(
        key: 'gameFee',
        label: 'Game Fee',
        amount: _v('gameFee'),
      ),
      FeeLineItem(
        key: 'reAdmissionFee',
        label: 'Re-Admission Fee',
        amount: _v('reAdmissionFee'),
      ),
      FeeLineItem(
        key: 'developmentFee',
        label: 'Development Fee',
        amount: _v('developmentFee'),
      ),
      FeeLineItem(
        key: 'schoolIdFee',
        label: 'School ID',
        amount: _v('schoolIdFee'),
      ),
      FeeLineItem(
        key: 'tieBagBeltFee',
        label: 'Tie, Bag, Belt',
        amount: _v('tieBagBeltFee'),
      ),
      FeeLineItem(
        key: 'backDues',
        label: 'Back Dues',
        amount: _v('backDues'),
      ),
      FeeLineItem(
        key: 'transportFee',
        label: 'Transport Fee',
        amount: _v('transportFee'),
      ),
      FeeLineItem(
        key: 'otherFee',
        label: 'Other Fee',
        amount: _v('otherFee'),
      ),
    ];

    final updated = await DatabaseService.instance.saveMonthlyFeeStructure(
      studentId: widget.studentId,
      month: _monthKey,
      tuitionFee: _v('tuitionFee'),
      additionalFees: additionalFees,
    );

    if (_v('tuitionFee') > 0) {
      DatabaseService.instance.saveFeeStructure(
        studentId: widget.studentId,
        tuitionFee: _v('tuitionFee'),
        transportFee: _v('transportFee'),
        gameFee: _v('gameFee'),
        dueDay: _fsDueDay,
        finePerDay: 0,
        startMonth: _monthKey,
      ).then((savedFs) {
        FirestoreService.instance.syncFeeStructure(savedFs).catchError((_) => null);
      }).catchError((_) => null);
    }

    return updated;
  }

  Future<void> _saveDemand() async {
    try {
      final updated = await _saveDemandInternal();
      if (!mounted) return;
      setState(() => _fee = updated);
      _fillControllers(updated);

      ref.invalidate(feeProvider(widget.studentId));
      ref.invalidate(dashboardStatsProvider);

      // Fire-and-forget: SQLite already saved above, Firestore is background sync.
      // Do NOT await — quota/network failure must not block the local save.
      FirestoreService.instance.syncMonthlyFee(updated).catchError((e) {
        debugPrint('[FeeScreen] Firestore syncMonthlyFee skipped: $e');
        return null;
      });

      _success('Fee particulars saved.');
    } catch (e) {
      _error(e.toString());
    }
  }

  Future<void> _resetDemand() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.restart_alt_rounded, color: Colors.amber, size: 24),
            SizedBox(width: 8),
            Text('Reset Fee Particulars?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Kya aap $_monthKey ke extra fee particulars ko reset karna chahte hain? Isse default tuition fee aur rolling previous dues restore ho jayenge.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _saving = true);
      final defaultTuition = _student?.monthlyFee ?? 0.0;
      final rollingPrev = await DatabaseService.instance.getRollingPreviousDue(widget.studentId, _monthKey);

      final updated = await DatabaseService.instance.saveMonthlyFeeStructure(
        studentId: widget.studentId,
        month: _monthKey,
        tuitionFee: defaultTuition,
        additionalFees: [
          FeeLineItem(key: 'previousDue', label: 'Previous Dues', amount: rollingPrev),
        ],
      );

      if (!mounted) return;
      setState(() {
        _fee = updated;
        _saving = false;
      });
      _fillControllers(updated);

      ref.invalidate(feeProvider(widget.studentId));
      ref.invalidate(dashboardStatsProvider);

      FirestoreService.instance.syncMonthlyFee(updated).catchError((e) {
        debugPrint('[FeeScreen] Firestore syncMonthlyFee skipped: $e');
        return null;
      });

      _success('Fee particulars reset to defaults.');
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      _error(e.toString());
    }
  }

  Future<void> _setDueDate() async {
    final fee = _fee;

    if (fee == null) {
      _error('Save the selected month first.');
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: fee.dueDate ??
          DateTime(
            _selectedMonth.year,
            _selectedMonth.month,
            10,
          ),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _saving = true;
    });

    try {
      await DatabaseService.instance.updateMonthlyFeeDueDate(
        studentId: widget.studentId,
        month: _monthKey,
        dueDate: picked,
      );

      final updated = await DatabaseService.instance.getMonthlyFee(
        widget.studentId,
        _monthKey,
      );

      if (updated != null) {
        await FirestoreService.instance.syncMonthlyFee(
          updated,
        );
      }

      await _load();

      ref.invalidate(feeProvider(widget.studentId));
      ref.invalidate(dashboardStatsProvider);

      _success('Due date updated.');
    } catch (e) {
      _error(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _addPayment() async {
    final amount = double.tryParse(_paymentCtrl.text.trim());

    if (amount == null || amount <= 0) {
      _error('Enter a valid payment amount.');
      return;
    }

    if (_fee == null) {
      _error('Fee record not found.');
      return;
    }

    if (amount > _remaining + 0.0001) {
      _error(
        'Payment cannot exceed remaining fee '
            '${AppUtils.formatCurrency(_remaining)}.',
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await _saveDemandInternal();

      final updated = await DatabaseService.instance.addMonthlyPayment(
        studentId: widget.studentId,
        month: _monthKey,
        amount: amount,
        paymentMode: _paymentMode,
        remarks: _remarksCtrl.text.trim().isEmpty
            ? null
            : _remarksCtrl.text.trim(),
      );

      final history = await DatabaseService.instance.getMonthlyPaymentHistory(
        widget.studentId,
        _monthKey,
      );

      final receiptNo =
      history.isNotEmpty ? history.first.receiptNumber : 'Generated';

      final payments =
      await DatabaseService.instance.getPayments(widget.studentId);

      if (!mounted) return;

      setState(() {
        _fee = updated;
        _payments = payments;
      });
      _fillControllers(updated);
      _paymentCtrl.clear();
      _remarksCtrl.clear();

      ref.invalidate(feeProvider(widget.studentId));
      ref.invalidate(dashboardStatsProvider);

      // All Firestore syncs are fire-and-forget — SQLite is the primary store.
      // Do NOT await: quota exceeded or network loss must never block local save.
      FirestoreService.instance.syncMonthlyFee(updated).catchError((e) {
        debugPrint('[FeeScreen] Firestore syncMonthlyFee skipped: $e');
        return null;
      });
      if (history.isNotEmpty) {
        final latestPayment = history.first;
        FirestoreService.instance.syncPayment(latestPayment).catchError((e) {
          debugPrint('[FeeScreen] Firestore syncPayment skipped: $e');
          return null;
        });
        final paidBefore = await DatabaseService.instance.getPaidBeforePayment(
          widget.studentId,
          _monthKey,
          latestPayment.id,
          latestPayment.paymentDate,
        );
        FirestoreService.instance.syncReceipt(
          payment: latestPayment,
          fee: updated,
          studentName: _student?.name ?? '',
          admissionNumber: _student?.admissionNumber ?? '',
          className: _student?.displayClass ?? '',
          paidBefore: paidBefore,
          mobile: _student?.mobile ?? '',
          alternateMobile: _student?.alternateMobile ?? '',
        ).catchError((e) {
          debugPrint('[FeeScreen] Firestore syncReceipt skipped: $e');
          return null;
        });
      }

      _success(
        'Payment ${AppUtils.formatCurrency(amount)} recorded. '
            'Receipt $receiptNo — opening PDF…',
      );

      // Auto-open receipt PDF after payment is recorded.
      if (history.isNotEmpty) {
        final latestPayment = history.first;
        try {
          final receiptDoc = await _generateReceiptPdf(updated, latestPayment);
          await Printing.layoutPdf(onLayout: (_) => receiptDoc.save());
        } catch (e) {
          debugPrint('[FeeScreen] Receipt PDF error: $e');
        }
      }
    } catch (e) {
      _error(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendReceiptWhatsApp(PaymentModel payment) async {
    final student = _student;
    if (student == null) return;
    try {
      final settings = await DatabaseService.instance.getSettings();
      final feeMonthRaw = payment.feeMonth ?? payment.monthKey ?? '';
      final mKey = PaymentModel.toMonthKey(feeMonthRaw, payment.paymentDate);
      MonthlyFeeModel? fee;
      if (mKey.isNotEmpty) {
        fee = await DatabaseService.instance.getMonthlyFee(student.id, mKey) ??
            await DatabaseService.instance.getMonthlyFee(student.studentId, mKey);
      }
      final file = await ReceiptPdfService.instance.createPdfFile(
        student: student,
        payment: payment,
        settings: settings,
        fee: fee ?? _fee,
      );
      if (!mounted) return;
      PaymentModel? priorPayment;
      try {
        final payments = await DatabaseService.instance.getPayments(student.id);
        payments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
        for (final p in payments) {
          if (p.id != payment.id && !p.paymentDate.isAfter(payment.paymentDate)) {
            priorPayment = p;
            break;
          }
        }
      } catch (_) {}

      final double prevPaid = (payment.previousPaid != null && payment.previousPaid! > 0)
          ? payment.previousPaid!
          : (priorPayment != null ? priorPayment.amount : 0.0);
      final double totalPaid = payment.totalPaidAfter ?? (prevPaid + payment.amount);
      final double effectiveTotalDemand = payment.totalDemand != null && payment.totalDemand! > 0
          ? payment.totalDemand!
          : ((fee ?? _fee)?.totalDue != null && (fee ?? _fee)!.totalDue > 0
              ? (fee ?? _fee)!.totalDue
              : (student.monthlyFee != null && student.monthlyFee! > 0
                  ? student.monthlyFee!
                  : payment.amount));
      final double balance = payment.balanceDue ??
          ((fee ?? _fee) != null && (fee ?? _fee)!.remaining >= 0
              ? (fee ?? _fee)!.remaining
              : (effectiveTotalDemand - totalPaid).clamp(0.0, double.infinity));

      final phone = student.mobile.trim().isNotEmpty
          ? student.mobile.trim()
          : (student.alternateMobile?.trim() ?? '');

      final receiptMsg = WhatsAppService.buildReceiptVoucherText(
        studentName: student.name,
        fatherName: student.fatherName,
        className: student.displayClass,
        receiptNumber: payment.receiptNumber,
        paymentDate: payment.paymentDate,
        amount: payment.amount,
        paymentMode: payment.paymentMode,
        feeMonth: payment.feeMonth ?? "Monthly Tuition Fee",
        totalDemand: payment.totalDemand ?? (prevPaid + payment.amount + balance),
        previousPaid: prevPaid,
        totalPaid: totalPaid,
        balanceDue: balance,
        instituteName: settings.instituteName,
        institutePhone: settings.mobile,
      );

      if (!mounted) return;
      await WhatsAppService.showReceiptShareSheet(
        context,
        studentName: student.name,
        phone: phone,
        alternatePhone: student.alternateMobile,
        receiptNumber: payment.receiptNumber,
        message: receiptMsg,
        filePath: file,
      );
    } catch (e) {
      _error('Could not send WhatsApp receipt: $e');
    }
  }

  Future<void> _printReceiptPdf(PaymentModel payment) async {
    final student = _student;
    if (student == null) return;
    try {
      final settings = await DatabaseService.instance.getSettings();
      final feeMonth = payment.feeMonth;
      MonthlyFeeModel? fee;
      if (feeMonth != null && feeMonth.isNotEmpty) {
        fee = await DatabaseService.instance.getMonthlyFee(student.id, feeMonth);
      }
      final doc = await ReceiptPdfService.instance.generateDocument(
        student: student,
        payment: payment,
        settings: settings,
        fee: fee ?? _fee,
      );
      await Printing.layoutPdf(onLayout: (_) => doc.save());
    } catch (e) {
      _error('Could not open receipt PDF: $e');
    }
  }

  Future<pw.Document> _generateReceiptPdf(
      MonthlyFeeModel fee,
      PaymentModel payment,
      ) async {
    final student = _student;
    if (student == null) return pw.Document();

    final settings = await DatabaseService.instance.getSettings();
    return ReceiptPdfService.instance.generateDocument(
      student: student,
      payment: payment,
      settings: settings,
      fee: fee,
    );
  }

  String _formatMonth(String month) {
    final parts = month.split('-');
    if (parts.length != 2) return month;
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final m = int.tryParse(parts[1]);
    if (m == null || m < 1 || m > 12) return month;
    return '${names[m - 1]} ${parts[0]}';
  }

  bool _isOverdue(MonthlyFeeModel fee) {
    if (fee.dueDate == null || fee.remaining <= 0) return false;
    return DateTime.now().isAfter(fee.dueDate!);
  }

  Widget _moneyField(String key, {bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: _feeCtrls[key],
        readOnly: readOnly,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: _feeFields[key],
          prefixIcon: const Icon(Icons.currency_rupee),
        ),
      ),
    );
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
    _load();
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
    _load();
  }

  void _error(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _success(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );
  }

  /// Shown when navigating to a month that has no fee record yet.
  /// The principal must explicitly "Save Fee Particulars" to create it.
  Widget _buildNoFeeForMonth() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Month navigator row so user can go back/forward
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _previousMonth,
                  icon: const Icon(Icons.chevron_left, color: AppColors.primary, size: 32),
                ),
                Column(
                  children: [
                    const Text('FEE MONTH',
                        style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    Text(
                      _formatMonth(_monthKey),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _nextMonth,
                  icon: const Icon(Icons.chevron_right, color: AppColors.primary, size: 32),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              'No fee record for ${_formatMonth(_monthKey)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Navigate back to an existing month, or scroll up and\n'
              'save fee particulars to create this month\'s record.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await _saveDemand();
              },
              icon: const Icon(Icons.add_circle_outline),
              label: Text('Save Fee Record for ${_formatMonth(_monthKey)}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _student?.name ?? 'Student';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Fees — $name'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const LoadingWidget(message: 'Loading fee details...')
          : _fee == null
          ? _buildNoFeeForMonth()
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Month Selector with Auto-Rollover Badge ──
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _previousMonth,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.chevron_left, size: 20),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.calendar_month, size: 16, color: Color(0xFF818CF8)),
                            const SizedBox(width: 6),
                            Text(
                              _formatMonth(_fee!.month),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _fee?.remarks == 'Pre-admission month'
                                  ? Icons.info_outline
                                  : Icons.auto_awesome,
                              size: 12,
                              color: _fee?.remarks == 'Pre-admission month'
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF34D399),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _fee?.remarks == 'Pre-admission month'
                                    ? 'Pre-enrollment Month — No Recurring Demand'
                                    : 'Previous Dues Automatically Carried Forward',
                                style: TextStyle(
                                  color: _fee?.remarks == 'Pre-admission month'
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF34D399),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _nextMonth,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.chevron_right, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Auto-Accrued Monthly Summary Ribbon (4 Cards) ──
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.5,
              children: [
                _summaryCard(
                  title: 'PREVIOUS DUE (CARRIED)',
                  titleColor: const Color(0xFFFBBF24),
                  value: AppUtils.formatCurrency(_previousDueAmount),
                  valueColor: const Color(0xFFFBBF24),
                  subtitle: 'Auto rolled from last month',
                  bgColor: const Color(0xE51E293B),
                  borderColor: const Color(0x66F59E0B),
                ),
                _summaryCard(
                  title: 'TOTAL DEMAND (THIS MONTH)',
                  titleColor: const Color(0xFF94A3B8),
                  value: AppUtils.formatCurrency(_demandTotal),
                  valueColor: const Color(0xFFA5B4FC),
                  subtitle: 'Sum of all 13 fee heads',
                  bgColor: const Color(0xE51E293B),
                  borderColor: const Color(0xFF334155),
                ),
                _summaryCard(
                  title: 'PAID THIS MONTH',
                  titleColor: const Color(0xFF34D399),
                  value: AppUtils.formatCurrency(_paidForMonth),
                  valueColor: const Color(0xFF34D399),
                  subtitle: '${_monthPaymentsList.length} receipt(s)',
                  bgColor: const Color(0xE51E293B),
                  borderColor: const Color(0x6610B981),
                ),
                _summaryCard(
                  title: 'REMAINING FEE',
                  titleColor: _remaining > 0 ? const Color(0xFFFB7185) : const Color(0xFF34D399),
                  value: AppUtils.formatCurrency(_remaining),
                  valueColor: _remaining > 0 ? const Color(0xFFFB7185) : const Color(0xFF34D399),
                  subtitle: _remaining > 0 ? 'Auto rolls to next month' : '✓ Month Cleared',
                  bgColor: _remaining > 0
                      ? const Color(0x804C0519)
                      : const Color(0x66064E3B),
                  borderColor: _remaining > 0
                      ? const Color(0x66F43F5E)
                      : const Color(0x6610B981),
                ),
              ],
            ),
            const SizedBox(height: 14),



            Card(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.receipt_long,
                            color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Fee Particulars',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Previous Dues is automatic from the previous month.',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 13),
                    _moneyField('admissionFee'),
                    _moneyField('tuitionFee'),
                    _moneyField('examinationFee'),
                    _moneyField('previousDue', readOnly: false),
                    _moneyField('gameFee'),
                    _moneyField('reAdmissionFee'),
                    _moneyField('developmentFee'),
                    _moneyField('schoolIdFee'),
                    _moneyField('tieBagBeltFee'),
                    _moneyField('backDues'),
                    _moneyField('transportFee'),
                    _moneyField('otherFee'),
                    _moneyField('lateFine', readOnly: true),
                    const Divider(),
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL',
                            style: TextStyle(
                                fontWeight: FontWeight.w900)),
                        Text(
                          AppUtils.formatCurrency(_demandTotal),
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _resetDemand,
                          icon: const Icon(Icons.restart_alt, size: 18),
                          label: const Text('Reset'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _saveDemand,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Save Particulars'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.event_busy,
                            color: AppColors.warning),
                        SizedBox(width: 8),
                        Text('Due Date',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _setDueDate,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        _fee!.dueDate == null
                            ? 'Set Due Date'
                            : '${_fee!.dueDate!.day.toString().padLeft(2, '0')}-'
                            '${_fee!.dueDate!.month.toString().padLeft(2, '0')}-'
                            '${_fee!.dueDate!.year}',
                      ),
                    ),
                    if (_isOverdue(_fee!))
                      const Text(
                        'OVERDUE',
                        style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w800),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.add_card,
                            color: AppColors.success),
                        SizedBox(width: 8),
                        Text('Add Payment',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Remaining: ${AppUtils.formatCurrency(_remaining)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _paymentCtrl,
                      keyboardType:
                      const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Payment Amount (₹) *',
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _paymentMode,
                      decoration: const InputDecoration(
                        labelText: 'Payment Mode',
                        prefixIcon: Icon(Icons.payment),
                      ),
                      items: _modes
                          .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(m),
                      ))
                          .toList(),
                      onChanged: (v) => setState(() {
                        _paymentMode = v ?? 'Cash';
                      }),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _remarksCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Remarks (optional)'),
                    ),
                    const SizedBox(height: 13),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving || _remaining <= 0
                            ? null
                            : _addPayment,
                        icon: _saving
                            ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2))
                            : const Icon(Icons.receipt_long),
                        label: Text(
                          _saving
                              ? 'Saving...'
                              : 'Cut Receipt / Record Payment',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_payments.isNotEmpty) ...[
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.receipt_long, color: AppColors.primary),
                          const SizedBox(width: 8),
                          const Text(
                            'Receipt History',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          const Spacer(),
                          Text(
                            '${_payments.length} Payments',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _payments.length,
                        separatorBuilder: (_, __) => const Divider(height: 16),
                        itemBuilder: (context, idx) {
                          final p = _payments[idx];
                          final pDate = p.paymentDate;
                          final dateStr = '${pDate.day.toString().padLeft(2, '0')}-${pDate.month.toString().padLeft(2, '0')}-${pDate.year}';
                          return Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: AppColors.successLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.receipt_long, color: AppColors.success, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppUtils.formatCurrency(p.amount),
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                    ),
                                    Text(
                                      '${p.receiptNumber} • $dateStr • ${p.paymentMode}${p.feeMonth != null ? " • ${p.feeMonth}" : ""}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'WhatsApp Receipt',
                                icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 22),
                                onPressed: () => _sendReceiptWhatsApp(p),
                              ),
                              IconButton(
                                tooltip: 'Print / View Slip',
                                icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 22),
                                onPressed: () => _printReceiptPdf(p),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required Color titleColor,
    required String value,
    required Color valueColor,
    required String subtitle,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 8.5,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
