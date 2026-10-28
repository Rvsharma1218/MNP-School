import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/app_utils.dart';
import '../../core/utils/file_saver.dart';
import '../../data/models/settings_model.dart';
import '../../data/models/student_model.dart';
import '../../data/services/database_service.dart';
import '../../data/services/providers.dart';

class TransportRecord {
  final String studentId;
  final String studentName;
  final String className;
  final String rollNumber;
  final String parentMobile;
  final String pickupStop;
  final String vehicleNumber;
  final String driverName;
  final String driverMobile;
  final double monthlyFee;
  final String assignedDate;

  TransportRecord({
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.rollNumber,
    required this.parentMobile,
    required this.pickupStop,
    required this.vehicleNumber,
    required this.driverName,
    required this.driverMobile,
    required this.monthlyFee,
    required this.assignedDate,
  });

  Map<String, dynamic> toJson() => {
    'studentId': studentId,
    'studentName': studentName,
    'className': className,
    'rollNumber': rollNumber,
    'parentMobile': parentMobile,
    'pickupStop': pickupStop,
    'vehicleNumber': vehicleNumber,
    'driverName': driverName,
    'driverMobile': driverMobile,
    'monthlyFee': monthlyFee,
    'assignedDate': assignedDate,
  };

  factory TransportRecord.fromJson(Map<String, dynamic> map) => TransportRecord(
    studentId: map['studentId'] ?? '',
    studentName: map['studentName'] ?? '',
    className: map['className'] ?? '',
    rollNumber: map['rollNumber'] ?? '',
    parentMobile: map['parentMobile'] ?? '',
    pickupStop: map['pickupStop'] ?? 'Main Gate',
    vehicleNumber: map['vehicleNumber'] ?? 'Bus #01',
    driverName: map['driverName'] ?? 'Driver',
    driverMobile: map['driverMobile'] ?? '',
    monthlyFee: (map['monthlyFee'] as num?)?.toDouble() ?? 500.0,
    assignedDate: map['assignedDate'] ?? '',
  );
}

class TransportScreen extends ConsumerStatefulWidget {
  const TransportScreen({super.key});

  @override
  ConsumerState<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends ConsumerState<TransportScreen> {
  bool _loading = true;
  bool _generatingPdf = false;
  List<TransportRecord> _transportList = [];
  List<StudentModel> _allStudents = [];
  String _searchQuery = '';
  final String _selectedRouteFilter = 'All';

  final TextEditingController _searchCtrl = TextEditingController();

  final List<String> _commonStops = [
    'Main Campus Gate',
    'Station Chowk',
    'Main Market Siwan',
    'Hospital Road',
    'Mora Mairi Chowk',
    'Bhagwaanpur Bus Stop',
    'NH-28 Bypass Crossing',
    'Gandhi Maidan Area',
  ];

  final List<String> _commonVehicles = [
    'School Bus #01 (BR-29-A-1234)',
    'School Bus #02 (BR-29-B-5678)',
    'School Van #01 (BR-29-C-9012)',
    'School Van #02 (BR-29-D-3456)',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final db = DatabaseService.instance;
    _allStudents = await db.getAllStudents();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('school_transport_roster');
    if (raw != null) {
      try {
        final List decoded = jsonDecode(raw);
        _transportList = decoded.map((e) => TransportRecord.fromJson(e)).toList();
      } catch (_) {
        _initSampleTransportData();
      }
    } else {
      _initSampleTransportData();
    }

    if (mounted) setState(() => _loading = false);
  }

  void _initSampleTransportData() {
    if (_allStudents.isNotEmpty) {
      final sample = _allStudents.take(5).toList();
      _transportList = [
        for (int i = 0; i < sample.length; i++)
          TransportRecord(
            studentId: sample[i].id,
            studentName: sample[i].name,
            className: sample[i].displayClass,
            rollNumber: sample[i].rollNumber ?? '${i + 1}',
            parentMobile: sample[i].mobile,
            pickupStop: _commonStops[i % _commonStops.length],
            vehicleNumber: _commonVehicles[i % _commonVehicles.length],
            driverName: i % 2 == 0 ? 'Ramesh Kumar' : 'Sunil Sharma',
            driverMobile: '9876543210',
            monthlyFee: 500.0 + (i * 100),
            assignedDate: DateFormat('dd-MM-yyyy').format(DateTime.now()),
          )
      ];
      _saveTransportData();
    }
  }

  Future<void> _saveTransportData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_transportList.map((e) => e.toJson()).toList());
      await prefs.setString('school_transport_roster', raw);
    } catch (_) {}
  }

  List<TransportRecord> get _filteredList {
    return _transportList.where((item) {
      final matchRoute = _selectedRouteFilter == 'All' || item.pickupStop == _selectedRouteFilter;
      final matchSearch = _searchQuery.isEmpty ||
          item.studentName.toLowerCase().contains(_searchQuery) ||
          item.rollNumber.toLowerCase().contains(_searchQuery) ||
          item.pickupStop.toLowerCase().contains(_searchQuery) ||
          item.vehicleNumber.toLowerCase().contains(_searchQuery);
      return matchRoute && matchSearch;
    }).toList();
  }

  void _showAddEditTransportDialog({TransportRecord? existing, int? index}) {
    StudentModel? selectedStudent = existing != null
        ? _allStudents.where((s) => s.id == existing.studentId).firstOrNull
        : (_allStudents.isNotEmpty ? _allStudents.first : null);

    final stopCtrl = TextEditingController(text: existing?.pickupStop ?? _commonStops.first);
    final vehicleCtrl = TextEditingController(text: existing?.vehicleNumber ?? _commonVehicles.first);
    final driverNameCtrl = TextEditingController(text: existing?.driverName ?? 'Ramesh Kumar');
    final driverMobileCtrl = TextEditingController(text: existing?.driverMobile ?? '9876543210');
    final feeCtrl = TextEditingController(text: '${existing?.monthlyFee.toInt() ?? 600}');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF0D9488).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.directions_bus_rounded, color: Color(0xFF0D9488), size: 22),
              ),
              const SizedBox(width: 10),
              Text(existing != null ? 'Edit Transport Details' : 'Add Student to Transport', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (existing == null) ...[
                  const Text('Select Student:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(10)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<StudentModel>(
                        value: selectedStudent,
                        isExpanded: true,
                        items: _allStudents.map((s) => DropdownMenuItem(value: s, child: Text('${s.name} (${s.displayClass})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)))).toList(),
                        onChanged: (val) {
                          if (val != null) setDlgState(() => selectedStudent = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        const Icon(Icons.person, color: Color(0xFF0D9488), size: 20),
                        const SizedBox(width: 8),
                        Text('${existing.studentName} (${existing.className})', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                const Text('Pick-up Stop / Route:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569))),
                const SizedBox(height: 6),
                TextField(
                  controller: stopCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. Station Chowk, Siwan',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),

                const Text('Vehicle / Bus No:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569))),
                const SizedBox(height: 6),
                TextField(
                  controller: vehicleCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. School Bus #01',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Driver Name:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569))),
                          const SizedBox(height: 6),
                          TextField(
                            controller: driverNameCtrl,
                            decoration: InputDecoration(
                              hintText: 'Driver Name',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Monthly Fee (₹):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569))),
                          const SizedBox(height: 6),
                          TextField(
                            controller: feeCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: '600',
                              prefixText: '₹ ',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (selectedStudent == null) return;
                final rec = TransportRecord(
                  studentId: selectedStudent!.id,
                  studentName: selectedStudent!.name,
                  className: selectedStudent!.displayClass,
                  rollNumber: selectedStudent!.rollNumber ?? 'N/A',
                  parentMobile: selectedStudent!.mobile,
                  pickupStop: stopCtrl.text.trim().isNotEmpty ? stopCtrl.text.trim() : 'Campus Gate',
                  vehicleNumber: vehicleCtrl.text.trim().isNotEmpty ? vehicleCtrl.text.trim() : 'Bus #01',
                  driverName: driverNameCtrl.text.trim().isNotEmpty ? driverNameCtrl.text.trim() : 'Driver',
                  driverMobile: driverMobileCtrl.text.trim(),
                  monthlyFee: double.tryParse(feeCtrl.text.trim()) ?? 500.0,
                  assignedDate: existing?.assignedDate ?? DateFormat('dd-MM-yyyy').format(DateTime.now()),
                );

                setState(() {
                  if (existing != null && index != null) {
                    _transportList[index] = rec;
                  } else {
                    _transportList.removeWhere((item) => item.studentId == rec.studentId);
                    _transportList.insert(0, rec);
                  }
                });
                _saveTransportData();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${rec.studentName} added to Transport Service!'), backgroundColor: const Color(0xFF0D9488)),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
              child: Text(existing != null ? 'Update' : 'Save Student'),
            ),
          ],
        ),
      ),
    );
  }

  void _removeTransportRecord(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from Transport?'),
        content: Text('Remove ${_transportList[index].studentName} from school transport service?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() => _transportList.removeAt(index));
              _saveTransportData();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportTransportPDF() async {
    setState(() => _generatingPdf = true);
    final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
    final schoolName = settings.schoolName.isNotEmpty ? settings.schoolName : 'MISSION NAVODAYA PUBLIC SCHOOL';

    try {
      final logoBytes = await AppUtils.loadAppImageBytes(settings.logoPath);
      final sigBytes = await AppUtils.loadAppImageBytes(settings.principalSignature);
      final stampBytes = await AppUtils.loadAppImageBytes(settings.schoolStamp);
      final pw.MemoryImage? logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;
      final pw.MemoryImage? sigImage = sigBytes != null ? pw.MemoryImage(sigBytes) : null;
      final pw.MemoryImage? stampImage = stampBytes != null ? pw.MemoryImage(stampBytes) : null;

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#0D9488'), borderRadius: pw.BorderRadius.circular(6)),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Row(
                        children: [
                          if (logoImage != null) ...[
                            pw.Container(width: 30, height: 30, child: pw.Image(logoImage, fit: pw.BoxFit.contain)),
                            pw.SizedBox(width: 8),
                          ],
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(schoolName.toUpperCase(), style: pw.TextStyle(color: PdfColors.white, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                              pw.Text('OFFICIAL TRANSPORT & BUS SERVICE ROSTER', style: pw.TextStyle(color: PdfColor.fromHex('#FDE047'), fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                      pw.Text('TOTAL: ${_transportList.length} STUDENTS', style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),

                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('S.No', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Student Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Class', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Pick-up Stop', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Vehicle', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Fee (₹)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                      ],
                    ),
                    ..._transportList.asMap().entries.map((e) => pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${e.key + 1}', style: const pw.TextStyle(fontSize: 7.5))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(e.value.studentName, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(e.value.className, style: const pw.TextStyle(fontSize: 7.5))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(e.value.pickupStop, style: const pw.TextStyle(fontSize: 7.5))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(e.value.vehicleNumber, style: const pw.TextStyle(fontSize: 7.5))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('₹${e.value.monthlyFee.toInt()}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7.5))),
                      ],
                    )),
                  ],
                ),
                pw.Spacer(),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Generated: ${DateFormat("dd-MM-yyyy hh:mm a").format(DateTime.now())}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                    // Principal Sign & Official Stamp (Signature layered inside/over stamp)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(
                          width: 120,
                          height: 38,
                          child: pw.Stack(
                            alignment: pw.Alignment.center,
                            children: [
                              if (stampImage != null)
                                pw.Opacity(
                                  opacity: 0.88,
                                  child: pw.Image(stampImage, width: 36, height: 36, fit: pw.BoxFit.contain),
                                ),
                              if (sigImage != null)
                                pw.Image(sigImage, width: 80, height: 22, fit: pw.BoxFit.contain),
                            ],
                          ),
                        ),
                        pw.Container(width: 120, height: 1, color: PdfColors.grey600),
                        pw.SizedBox(height: 2),
                        pw.Text('Principal Sign', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      final bytes = await pdf.save();
      if (mounted) {
        await FileSaver.showSaveShareSheet(
          context,
          bytes: bytes,
          filename: 'School_Transport_Roster.pdf',
          subject: '$schoolName - Transport Roster',
          category: FileCategory.general,
          schoolName: schoolName,
          icon: Icons.directions_bus_rounded,
          color: const Color(0xFF0D9488),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalRevenue = 0;
    _transportList.forEach((e) => totalRevenue += e.monthlyFee);

    final displayList = _filteredList;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('School Transport Service', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _generatingPdf
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
            tooltip: 'Export Transport Roster PDF',
            onPressed: _generatingPdf ? null : _exportTransportPDF,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard('Active Students', '${_transportList.length}', Icons.directions_bus_rounded, const Color(0xFF0D9488)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildStatCard('Monthly Fees', '₹${totalRevenue.toInt()}', Icons.currency_rupee_rounded, const Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: InputDecoration(
                                hintText: 'Search student, stop, bus...',
                                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _showAddEditTransportDialog(),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Student', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D9488),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                Expanded(
                  child: displayList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.directions_bus_outlined, size: 54, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text('No students enrolled in Transport Service', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                onPressed: () => _showAddEditTransportDialog(),
                                icon: const Icon(Icons.add),
                                label: const Text('Enroll First Student'),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: displayList.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, idx) {
                            final item = displayList[idx];
                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE2E8F0))),
                              color: Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(color: const Color(0xFF0D9488).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                      child: const Center(child: Icon(Icons.directions_bus_rounded, color: Color(0xFF0D9488), size: 22)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          const SizedBox(height: 2),
                                          Text('${item.className} • Roll ${item.rollNumber}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: const Color(0xFFCCFBF1), borderRadius: BorderRadius.circular(6)),
                                                child: Text('📍 ${item.pickupStop}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                                child: Text('🚌 ${item.vehicleNumber}', style: const TextStyle(fontSize: 10, color: Color(0xFF475569))),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                                                child: Text('₹${item.monthlyFee.toInt()}/mo', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB), size: 18),
                                          onPressed: () => _showAddEditTransportDialog(existing: item, index: idx),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                                          onPressed: () => _removeTransportRecord(idx),
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

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
              Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}
