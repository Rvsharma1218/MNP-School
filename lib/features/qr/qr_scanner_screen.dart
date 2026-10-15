import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../data/services/database_service.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  MobileScannerController? _ctrl;
  bool _scanned = false;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _ctrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    setState(() => _scanned = true);
    await _ctrl?.stop();

    final qrValue = barcode!.rawValue!;
    // The ID card's QR encodes a composite string —
    // 'ID:STU00001|Name:Ravi Sharma|Mobile:9876543210' — so it's readable
    // by any generic QR scanner too, not just this app. Extract just the
    // ID part for the lookup. Falls back to treating the raw value as a
    // bare studentId, so older/plain QR codes still work.
    String lookupId = qrValue;
    final idMatch = RegExp(r'ID:([^|]+)').firstMatch(qrValue);
    if (idMatch != null) {
      lookupId = idMatch.group(1)!.trim();
    }
    final student = await DatabaseService.instance.getStudentByQrId(lookupId);

    if (!mounted) return;
    if (student != null) {
      Navigator.pushReplacementNamed(context, AppRoutes.studentProfile,
          arguments: student.id);
    } else {
      // Show not found and allow retry
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Not Found'),
          content: Text('No student found for QR: $qrValue'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _scanned = false);
                _ctrl?.start();
              },
              child: const Text('Try Again'),
            ),
            TextButton(
              onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Student QR'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () {
              setState(() => _torchOn = !_torchOn);
              _ctrl?.toggleTorch();
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => _ctrl?.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera
          MobileScanner(controller: _ctrl!, onDetect: _onDetect),

          // Overlay
          Column(
            children: [
              Expanded(
                child: Container(color: Colors.black54),
              ),
              Row(
                children: [
                  Container(width: 60, color: Colors.black54),
                  Container(
                    width: 270, height: 270,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.accent, width: 3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  Container(color: Colors.black54, width: 60),
                ],
              ),
              Expanded(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: Text(
                      _scanned ? 'Processing...' : 'Align QR code within the frame',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Corner brackets
          Center(
            child: SizedBox(
              width: 270, height: 270,
              child: CustomPaint(painter: _CornerPainter()),
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    const len = 30.0;
    const r = 8.0;

    // Top-left
    canvas.drawLine(Offset(r, 0), Offset(len, 0), paint);
    canvas.drawLine(Offset(0, r), Offset(0, len), paint);
    // Top-right
    canvas.drawLine(Offset(size.width - len, 0), Offset(size.width - r, 0), paint);
    canvas.drawLine(Offset(size.width, r), Offset(size.width, len), paint);
    // Bottom-left
    canvas.drawLine(Offset(0, size.height - len), Offset(0, size.height - r), paint);
    canvas.drawLine(Offset(r, size.height), Offset(len, size.height), paint);
    // Bottom-right
    canvas.drawLine(Offset(size.width, size.height - len), Offset(size.width, size.height - r), paint);
    canvas.drawLine(Offset(size.width - len, size.height), Offset(size.width - r, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}