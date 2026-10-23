import '../../core/utils/signature_processor.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../core/utils/file_saver.dart';
import '../../data/models/settings_model.dart';
import '../../data/models/student_model.dart';
import '../../data/services/providers.dart';

class IdCardScreen extends ConsumerStatefulWidget {
  final String? studentId;
  const IdCardScreen({super.key, this.studentId});

  @override
  ConsumerState<IdCardScreen> createState() => _IdCardScreenState();
}

class _IdCardScreenState extends ConsumerState<IdCardScreen> {
  String _selectedClass = 'All';
  StudentModel? _previewStudent;
  bool _showBackSide = false;
  bool _generatingPdf = false;
  String _searchQuery = '';

  ColorFilter _getInkColorFilter(String mode) {
    switch (mode.toLowerCase()) {
      case 'gold':
        return const ColorFilter.mode(Color(0xFFFFD700), BlendMode.srcIn);
      case 'dark':
        return const ColorFilter.mode(Color(0xFF0A1128), BlendMode.srcIn);
      case 'blue':
        return const ColorFilter.mode(Color(0xFF0F3E8A), BlendMode.srcIn);
      case 'white':
      default:
        return const ColorFilter.mode(Colors.white, BlendMode.srcIn);
    }
  }

  Color _getInkTextColor(String mode) {
    switch (mode.toLowerCase()) {
      case 'gold':
        return const Color(0xFFFFD700);
      case 'dark':
        return const Color(0xFF0A1128);
      case 'blue':
        return const Color(0xFF0F3E8A);
      case 'white':
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.valueOrNull ?? SettingsModel.defaultSettings();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('ID Card Studio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0A1128),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share ID Card',
            onPressed: _previewStudent == null ? null : () => _shareIdCardPDF(_previewStudent!),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Download All ID Cards PDF',
            onPressed: _generatingPdf ? null : () => _exportIdCardsPDF(),
          ),
        ],
      ),
      body: studentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading students: $e')),
        data: (students) {
          final schoolClasses = ['All', ...settings.schoolClasses];

          final filtered = students.where((s) {
            final matchClass = _selectedClass == 'All' || s.displayClass.contains(_selectedClass) || s.course == _selectedClass;
            final q = _searchQuery.trim().toLowerCase();
            final matchSearch = q.isEmpty ||
                s.name.toLowerCase().contains(q) ||
                s.id.toLowerCase().contains(q) ||
                (s.rollNumber ?? '').toLowerCase().contains(q);
            return matchClass && matchSearch;
          }).toList();

          if (widget.studentId != null && widget.studentId!.isNotEmpty) {
            final match = students.where((s) => s.id == widget.studentId).firstOrNull;
            if (match != null) _previewStudent = match;
          } else if (_previewStudent == null && filtered.isNotEmpty) {
            _previewStudent = filtered.first;
          } else if (_previewStudent != null && !filtered.any((s) => s.id == _previewStudent!.id) && filtered.isNotEmpty) {
            _previewStudent = filtered.first;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Filter Card (Only for Principal / Staff managing whole school)
                if (widget.studentId == null) ...[
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: schoolClasses.contains(_selectedClass) ? _selectedClass : 'All',
                                  decoration: InputDecoration(
                                    labelText: 'Select Class',
                                    prefixIcon: const Icon(Icons.class_outlined, color: Color(0xFF0A1128)),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  items: schoolClasses.map((c) => DropdownMenuItem(value: c, child: Text(c == 'All' ? 'All Classes (${students.length})' : 'Class $c'))).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedClass = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: _generatingPdf || filtered.isEmpty ? null : () => _exportIdCardsPDF(),
                                icon: _generatingPdf
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.download, size: 18),
                                label: Text(_generatingPdf ? 'Generating...' : 'Download All (${filtered.length})'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0A1128),
                                  foregroundColor: const Color(0xFFFFD700),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'Search student by name, roll, ID...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Preview Card Section
                if (_previewStudent != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ID Card Live Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0A1128))),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('FRONT SIDE'),
                            selected: !_showBackSide,
                            selectedColor: const Color(0xFF0A1128),
                            labelStyle: TextStyle(color: !_showBackSide ? const Color(0xFFFFD700) : Colors.black87, fontWeight: FontWeight.bold, fontSize: 11),
                            onSelected: (val) => setState(() => _showBackSide = !val),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('BACK SIDE'),
                            selected: _showBackSide,
                            selectedColor: const Color(0xFF0A1128),
                            labelStyle: TextStyle(color: _showBackSide ? const Color(0xFFFFD700) : Colors.black87, fontWeight: FontWeight.bold, fontSize: 11),
                            onSelected: (val) => setState(() => _showBackSide = val),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Real Card View
                  Center(
                    child: _showBackSide
                        ? _buildInAppCardBack(_previewStudent!, settings)
                        : _buildInAppCardFront(_previewStudent!, settings),
                  ),
                  const SizedBox(height: 10),

                  // Official Ink Color Selector (Matches Website)
                  if (settings.principalSignature != null && settings.principalSignature!.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.palette_outlined, size: 16, color: Color(0xFF0A1128)),
                          const SizedBox(width: 8),
                          const Text('Sign Ink Color:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0A1128))),
                          const Spacer(),
                          _buildInkColorBtn(context, ref, settings, 'White', 'white'),
                          const SizedBox(width: 4),
                          _buildInkColorBtn(context, ref, settings, 'Gold', 'gold'),
                          const SizedBox(width: 4),
                          _buildInkColorBtn(context, ref, settings, 'Blue', 'blue'),
                          const SizedBox(width: 4),
                          _buildInkColorBtn(context, ref, settings, 'Dark', 'dark'),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Single Download / Share Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _generatingPdf ? null : () => _exportIdCardsPDF(singleStudent: _previewStudent),
                          icon: const Icon(Icons.download, size: 18),
                          label: Text('Download ${_previewStudent!.name} (PDF)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0A1128),
                            side: const BorderSide(color: Color(0xFF0A1128), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: const Color(0xFF0A1128), foregroundColor: const Color(0xFFFFD700)),
                        icon: const Icon(Icons.share),
                        onPressed: () => _shareIdCardPDF(_previewStudent!),
                        tooltip: 'Share Card',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                // Student Selection Grid / List
                const Text('Select Student to Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0A1128))),
                const SizedBox(height: 8),
                filtered.isEmpty
                    ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No students found.')))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final s = filtered[index];
                          final isSelected = _previewStudent?.id == s.id;
                          return Card(
                            elevation: isSelected ? 3 : 1,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: isSelected ? const Color(0xFF0A1128) : Colors.transparent, width: 2),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF0A1128),
                                foregroundColor: const Color(0xFFFFD700),
                                child: Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text('ID: ${s.id} | Roll: ${s.rollNumber} | Class: ${s.displayClass}', style: const TextStyle(fontSize: 12)),
                              trailing: ElevatedButton(
                                onPressed: () => setState(() => _previewStudent = s),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSelected ? const Color(0xFF0A1128) : Colors.grey.shade200,
                                  foregroundColor: isSelected ? const Color(0xFFFFD700) : Colors.black87,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                                child: Text(isSelected ? 'Viewing' : 'Preview'),
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          );
        },
      ),
    );
  }

  // =================== IN-APP CARD FRONT (MATCHES IMAGE 3) ===================
  Widget _buildInAppCardFront(StudentModel s, SettingsModel settings) {
    final schoolName = settings.schoolName.isNotEmpty ? settings.schoolName : 'MISSION NAVODAYA PUBLIC SCHOOL';
    final session = settings.currentSession.isNotEmpty ? settings.currentSession : '2026-27';
    final address = settings.address.isNotEmpty ? settings.address : 'Mora Mairi, BagwaanPur hat ,Siwan,Bihar 841507';
    final isComp = s.studentType == 'computer';

    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: const Color(0xFF0A1128),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Golden Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: const Color(0xFFFFD700),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('OFFICIAL STUDENT ID', style: TextStyle(color: Color(0xFF0A1128), fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
                Text('SESSION $session', style: const TextStyle(color: Color(0xFF0A1128), fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
              ],
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFFD700), width: 1),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AppUtils.buildAppImageWidget(
                    settings.logoPath,
                    width: 32,
                    height: 32,
                    placeholder: const Center(child: Text('MN', style: TextStyle(color: Color(0xFF0A1128), fontWeight: FontWeight.bold, fontSize: 12))),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schoolName.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        address,
                        style: const TextStyle(color: Color(0xFFFFD700), fontSize: 8, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFFFD700), thickness: 1),

          // Body Content
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Photo & Badge
                Column(
                  children: [
                    Container(
                      width: 72,
                      height: 88,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A1128),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFD700), width: 1.8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: s.photoPath != null && s.photoPath!.isNotEmpty
                          ? AppUtils.buildAppImageWidget(s.photoPath, fit: BoxFit.cover)
                          : Center(
                              child: Text(
                                s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                                style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900),
                              ),
                            ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('STUDENT', style: TextStyle(color: Color(0xFF0A1128), fontSize: 8.5, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // Center Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      _buildPreviewRow('STUDENT ID', s.id),
                      _buildPreviewRow('ADM NO', s.admissionNumber.isNotEmpty ? s.admissionNumber : s.id),
                      _buildPreviewRow(isComp ? 'COURSE' : 'CLASS / SEC', isComp ? (s.course ?? 'Computer') : s.displayClass),
                      _buildPreviewRow("FATHER'S NAME", s.fatherName.isNotEmpty ? s.fatherName : '-'),
                      _buildPreviewRow('CONTACT NO', s.mobile),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Signature Right above Bottom Bar (Image 3 layout)
          Padding(
            padding: const EdgeInsets.only(right: 14, bottom: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (settings.principalSignature != null && settings.principalSignature!.isNotEmpty) ...[
                  ColorFiltered(
                    colorFilter: _getInkColorFilter(settings.signatureColorMode),
                    child: AppUtils.buildAppImageWidget(
                      settings.principalSignature,
                      height: 27,
                      placeholder: const SizedBox.shrink(),
                    ),
                  ),
                ] else ...[
                  const Text('Ravi Ku', style: TextStyle(fontFamily: 'serif', fontStyle: FontStyle.italic, color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ),

          // Bottom Footer Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            color: const Color(0xFF05091E),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'PROPERTY OF $schoolName'.toUpperCase(),
                    style: const TextStyle(color: Colors.white70, fontSize: 7, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Text('AUTH SIGNATURE', style: TextStyle(color: Color(0xFFFFD700), fontSize: 7.5, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =================== IN-APP CARD BACK (MATCHES IMAGE 2) ===================
  Widget _buildInAppCardBack(StudentModel s, SettingsModel settings) {
    final schoolName = settings.schoolName.isNotEmpty ? settings.schoolName : 'MISSION NAVODAYA PUBLIC SCHOOL';
    final phone = settings.mobile.isNotEmpty ? settings.mobile : '8568643490';
    final address = settings.address.isNotEmpty ? settings.address : 'Mora Mairi, BagwaanPur hat ,Siwan,Bihar 841507';

    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: const Color(0xFF0A1128),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Yellow Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            color: const Color(0xFFFFD700),
            width: double.infinity,
            child: const Text('TERMS & CONDITIONS', style: TextStyle(color: Color(0xFF0A1128), fontWeight: FontWeight.w900, fontSize: 10.5, letterSpacing: 0.5)),
          ),

          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRuleItem('1. This card is non-transferable and must be presented upon request.'),
                      _buildRuleItem('2. If found, return to institute address below.'),
                      _buildRuleItem('3. Loss must be reported immediately.'),
                      _buildRuleItem('4. Scan QR code to open Student Portal.'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: QrImageView(
                    data: 'ID:${s.id}|ADM:${s.admissionNumber}',
                    version: QrVersions.auto,
                    size: 54,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFFFD700), thickness: 1),

          // Bottom Details & Signature
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(schoolName.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10), maxLines: 1),
                      const SizedBox(height: 2),
                      Text('Contact: $phone', style: const TextStyle(color: Colors.white70, fontSize: 8.5)),
                      Text(address, style: const TextStyle(color: Colors.white70, fontSize: 8), maxLines: 2),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (settings.principalSignature != null && settings.principalSignature!.isNotEmpty) ...[
                      ColorFiltered(
                        colorFilter: _getInkColorFilter(settings.signatureColorMode),
                        child: AppUtils.buildAppImageWidget(
                          settings.principalSignature,
                          height: 27,
                          placeholder: const SizedBox.shrink(),
                        ),
                      ),
                    ] else ...[
                      const Text('Ravi Ku', style: TextStyle(fontFamily: 'serif', fontStyle: FontStyle.italic, color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                    Container(width: 85, height: 1, color: Colors.white),
                    const SizedBox(height: 2),
                    const Text('DIRECTOR SIGN', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 8)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text('$label:', style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFFFFD700))),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 8.5, height: 1.25)),
    );
  }

  // =================== PDF CARD GENERATOR (MATCHES IMAGE 2 & 3) ===================
  pw.Widget _buildPdfFrontSide(StudentModel s, SettingsModel settings, pw.MemoryImage? logo, pw.MemoryImage? sig, pw.MemoryImage? photo) {
    final schoolName = settings.schoolName.isNotEmpty ? settings.schoolName : 'MISSION NAVODAYA PUBLIC SCHOOL';
    final session = settings.currentSession.isNotEmpty ? settings.currentSession : '2026-27';
    final address = settings.address.isNotEmpty ? settings.address : 'Mora Mairi, BagwaanPur hat ,Siwan,Bihar 841507';
    final isComp = s.studentType == 'computer';

    return pw.Container(
      width: 260,
      height: 165,
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#0A1128'),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColor.fromHex('#FFD700'), width: 1.5),
      ),
      child: pw.Column(
        children: [
          // Top Golden Bar
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            color: PdfColor.fromHex('#FFD700'),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('OFFICIAL STUDENT ID', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0A1128'))),
                pw.Text('SESSION $session', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0A1128'))),
              ],
            ),
          ),

          // Header
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 8),
            child: pw.Row(
              children: [
                if (logo != null) ...[
                  pw.Container(
                    width: 22,
                    height: 22,
                    margin: const pw.EdgeInsets.only(right: 6),
                    decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(3)),
                    child: pw.Image(logo, fit: pw.BoxFit.contain),
                  ),
                ],
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(schoolName.toUpperCase(), style: pw.TextStyle(color: PdfColors.white, fontSize: 8.5, fontWeight: pw.FontWeight.bold), maxLines: 1),
                      pw.Text(address, style: pw.TextStyle(color: PdfColor.fromHex('#FFD700'), fontSize: 5.5), maxLines: 1),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.Divider(height: 1, color: PdfColor.fromHex('#FFD700'), thickness: 0.8),

          // Content
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Photo with gold border
                  pw.Column(
                    children: [
                      pw.Container(
                        width: 52,
                        height: 64,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColor.fromHex('#FFD700'), width: 1.2),
                          color: PdfColor.fromHex('#0A1128'),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: photo != null
                            ? pw.ClipRRect(horizontalRadius: 4, verticalRadius: 4, child: pw.Image(photo, fit: pw.BoxFit.cover))
                            : pw.Center(
                                child: pw.Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                              ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#FFD700'), borderRadius: pw.BorderRadius.circular(2)),
                        child: pw.Text('STUDENT', style: pw.TextStyle(color: PdfColor.fromHex('#0A1128'), fontSize: 5.5, fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  pw.SizedBox(width: 8),

                  // Details
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(s.name.toUpperCase(), style: pw.TextStyle(color: PdfColors.white, fontSize: 9.5, fontWeight: pw.FontWeight.bold), maxLines: 1),
                        pw.SizedBox(height: 3),
                        _buildCardDetailPdf('STUDENT ID', s.id),
                        _buildCardDetailPdf('ADM NO', s.admissionNumber.isNotEmpty ? s.admissionNumber : s.id),
                        _buildCardDetailPdf(isComp ? 'COURSE' : 'CLASS / SEC', isComp ? (s.course ?? 'Computer') : s.displayClass),
                        _buildCardDetailPdf("FATHER'S NAME", s.fatherName.isNotEmpty ? s.fatherName.toUpperCase() : '-'),
                        _buildCardDetailPdf('CONTACT NO', s.mobile),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Right Signature right above footer bar
          pw.Padding(
            padding: const pw.EdgeInsets.only(right: 12, bottom: 2),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                if (sig != null) ...[
                  pw.Container(height: 20, child: pw.Image(sig, fit: pw.BoxFit.contain)),
                ] else ...[
                  pw.Text('Ravi Ku', style: pw.TextStyle(color: PdfColor.fromHex('#FFD700'), fontSize: 11, fontWeight: pw.FontWeight.bold, fontStyle: pw.FontStyle.italic)),
                ],
              ],
            ),
          ),

          // Footer bar
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
            color: PdfColor.fromHex('#05091E'),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text('PROPERTY OF ${schoolName.toUpperCase()}', style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 5.5), maxLines: 1),
                ),
                pw.Text('AUTH SIGNATURE', style: pw.TextStyle(color: PdfColor.fromHex('#FFD700'), fontSize: 6, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfBackSide(StudentModel s, SettingsModel settings, pw.MemoryImage? sig) {
    final schoolName = settings.schoolName.isNotEmpty ? settings.schoolName : 'MISSION NAVODAYA PUBLIC SCHOOL';
    final phone = settings.mobile.isNotEmpty ? settings.mobile : '8568643490';
    final address = settings.address.isNotEmpty ? settings.address : 'Mora Mairi, BagwaanPur hat ,Siwan,Bihar 841507';

    return pw.Container(
      width: 260,
      height: 165,
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#0A1128'),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColor.fromHex('#FFD700'), width: 1.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            color: PdfColor.fromHex('#FFD700'),
            width: double.infinity,
            child: pw.Text('TERMS & CONDITIONS', style: pw.TextStyle(color: PdfColor.fromHex('#0A1128'), fontSize: 7, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildRuleItemPdf('1. This card is non-transferable and must be presented upon request.'),
                      _buildRuleItemPdf('2. If found, return to institute address below.'),
                      _buildRuleItemPdf('3. Loss must be reported immediately to admin.'),
                      _buildRuleItemPdf('4. Scan QR code for 1-Tap Student Portal login.'),
                    ],
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.all(2),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: 'ID:${s.id}|ADM:${s.admissionNumber}',
                    width: 44,
                    height: 44,
                  ),
                ),
              ],
            ),
          ),
          pw.Spacer(),
          pw.Divider(height: 1, color: PdfColor.fromHex('#FFD700'), thickness: 0.8),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(schoolName.toUpperCase(), style: pw.TextStyle(color: PdfColors.white, fontSize: 7.5, fontWeight: pw.FontWeight.bold), maxLines: 1),
                      pw.Text('Contact: $phone', style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 6)),
                      pw.Text(address, style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 5.5), maxLines: 2),
                    ],
                  ),
                ),
                pw.Column(
                  children: [
                    if (sig != null) ...[
                      pw.Container(height: 20, child: pw.Image(sig, fit: pw.BoxFit.contain)),
                    ] else ...[
                      pw.Text('Ravi Ku', style: pw.TextStyle(color: PdfColor.fromHex('#FFD700'), fontSize: 11, fontWeight: pw.FontWeight.bold, fontStyle: pw.FontStyle.italic)),
                    ],
                    pw.Container(width: 70, height: 0.8, color: PdfColors.white),
                    pw.SizedBox(height: 2),
                    pw.Text('DIRECTOR SIGN', style: pw.TextStyle(color: PdfColor.fromHex('#FFD700'), fontSize: 6, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildCardDetailPdf(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.8),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 58, child: pw.Text('$label:', style: pw.TextStyle(fontSize: 6.5, color: PdfColor.fromHex('#FFD700'), fontWeight: pw.FontWeight.bold))),
          pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontSize: 7, color: PdfColors.white, fontWeight: pw.FontWeight.bold), maxLines: 1)),
        ],
      ),
    );
  }

  pw.Widget _buildRuleItemPdf(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Text(text, style: const pw.TextStyle(color: PdfColors.white, fontSize: 6.5, height: 1.2)),
    );
  }

  Future<void> _exportIdCardsPDF({StudentModel? singleStudent}) async {
    setState(() => _generatingPdf = true);
    final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
    final schoolName = settings.schoolName.isNotEmpty ? settings.schoolName : 'MISSION NAVODAYA PUBLIC SCHOOL';
    final students = ref.read(studentsProvider).valueOrNull ?? [];

    final targetStudents = singleStudent != null
        ? [singleStudent]
        : students.where((s) {
            return _selectedClass == 'All' || s.displayClass.contains(_selectedClass) || s.course == _selectedClass;
          }).toList();

    if (targetStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No students to export.')));
      setState(() => _generatingPdf = false);
      return;
    }

    try {
      final logoBytes = await AppUtils.loadAppImageBytes(settings.logoPath);
      final sigBytes = await AppUtils.loadAppImageBytes(settings.principalSignature);
      final pw.MemoryImage? logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;
      final pw.MemoryImage? sigImage = sigBytes != null ? pw.MemoryImage(sigBytes) : null;

      final pdf = pw.Document();

      for (int i = 0; i < targetStudents.length; i += 2) {
        final s1 = targetStudents[i];
        final s2 = (i + 1 < targetStudents.length) ? targetStudents[i + 1] : null;

        pw.MemoryImage? photo1;
        if (s1.photoPath != null && s1.photoPath!.isNotEmpty) {
          final b = await AppUtils.loadAppImageBytes(s1.photoPath);
          if (b != null) photo1 = pw.MemoryImage(b);
        }

        pw.MemoryImage? photo2;
        if (s2 != null && s2.photoPath != null && s2.photoPath!.isNotEmpty) {
          final b = await AppUtils.loadAppImageBytes(s2.photoPath);
          if (b != null) photo2 = pw.MemoryImage(b);
        }

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (pw.Context ctx) {
              return pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      _buildPdfFrontSide(s1, settings, logoImage, sigImage, photo1),
                      _buildPdfBackSide(s1, settings, sigImage),
                    ],
                  ),
                  pw.SizedBox(height: 24),
                  if (s2 != null) ...[
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        _buildPdfFrontSide(s2, settings, logoImage, sigImage, photo2),
                        _buildPdfBackSide(s2, settings, sigImage),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        );
      }

      final bytes = await pdf.save();
      final filename = singleStudent != null
          ? 'ID_Card_${singleStudent.name.replaceAll(' ', '_')}.pdf'
          : 'ID_Cards_${_selectedClass.replaceAll(' ', '_')}.pdf';

      if (mounted) {
        await FileSaver.showSaveShareSheet(
          context,
          bytes: bytes,
          filename: filename,
          subject: 'Student ID Cards - $schoolName',
          category: FileCategory.idCards,
          schoolName: schoolName,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  Future<void> _shareIdCardPDF(StudentModel student) async {
    final settings = ref.read(settingsProvider).valueOrNull ?? SettingsModel.defaultSettings();
    try {
      final logoBytes = await AppUtils.loadAppImageBytes(settings.logoPath);
      final sigBytes = await AppUtils.loadAppImageBytes(settings.principalSignature);
      final pw.MemoryImage? logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;
      final pw.MemoryImage? sigImage = sigBytes != null ? pw.MemoryImage(sigBytes) : null;

      pw.MemoryImage? photo;
      if (student.photoPath != null && student.photoPath!.isNotEmpty) {
        final b = await AppUtils.loadAppImageBytes(student.photoPath);
        if (b != null) photo = pw.MemoryImage(b);
      }

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context ctx) {
            return pw.Center(
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPdfFrontSide(student, settings, logoImage, sigImage, photo),
                  _buildPdfBackSide(student, settings, sigImage),
                ],
              ),
            );
          },
        ),
      );

      final bytes = await pdf.save();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/ID_${student.name.replaceAll(' ', '_')}.pdf');
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Official Student ID Card - ${student.name}',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sharing ID card: $e')));
      }
    }
  }
  Widget _buildInkColorBtn(BuildContext context, WidgetRef ref, SettingsModel settings, String label, String mode) {
    final isSelected = (settings.signatureColorMode == mode) || (mode == 'white' && settings.signatureColorMode.isEmpty);
    return InkWell(
      onTap: () async {
        final src = settings.rawSignature != null && settings.rawSignature!.isNotEmpty
            ? settings.rawSignature
            : settings.principalSignature;
        if (src == null || src.isEmpty) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Applying $label ink to ID Card...'), duration: const Duration(seconds: 1)),
        );
        final converted = await SignatureProcessor.processAndCleanSignature(src, colorMode: mode);
        if (converted != null) {
          final raw = (settings.rawSignature != null && settings.rawSignature!.isNotEmpty) ? settings.rawSignature : src;
          await ref.read(settingsProvider.notifier).save(
            settings.copyWith(
              principalSignature: converted,
              rawSignature: raw,
              signatureColorMode: mode,
            ),
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('ID Card updated with $label signature!'), backgroundColor: AppColors.success, duration: const Duration(seconds: 2)),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0A1128) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFFFFD700) : Colors.grey.shade300, width: isSelected ? 1.5 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? const Color(0xFFFFD700) : Colors.black87,
          ),
        ),
      ),
    );
  }
}
