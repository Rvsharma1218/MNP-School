import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../core/constants/app_colors.dart';

class PdfViewScreen extends StatelessWidget {
  final String title;
  final String? filePath;
  final Uint8List? pdfBytes;

  const PdfViewScreen({
    super.key,
    required this.title,
    this.filePath,
    this.pdfBytes,
  }) : assert(filePath != null || pdfBytes != null, 'Provide either filePath or pdfBytes');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: PdfPreview(
          build: (format) async {
            if (pdfBytes != null) return pdfBytes!;
            final file = File(filePath!);
            if (await file.exists()) {
              return file.readAsBytes();
            }
            throw Exception('PDF file not found at $filePath');
          },
          canChangeOrientation: false,
          canChangePageFormat: false,
          canDebug: false,
          allowPrinting: true,
          allowSharing: true,
          pdfFileName: '${title.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '_')}.pdf',
          loadingWidget: const Center(
            child: CircularProgressIndicator(color: Colors.amber),
          ),
          onError: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  Text(
                    'Unable to display PDF:\n$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
