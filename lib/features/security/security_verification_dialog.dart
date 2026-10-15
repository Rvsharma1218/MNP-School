import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import 'device_security_service.dart';

class SecurityVerificationDialog extends StatefulWidget {
  final VoidCallback onCompleted;

  const SecurityVerificationDialog({super.key, required this.onCompleted});

  static Future<void> showIfNeeded(BuildContext context) async {
    final service = DeviceSecurityService.instance;
    // If revoked, show locked dialog immediately
    if (service.isRevoked) {
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => PopScope(
            canPop: false,
            child: AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Row(
                children: [
                  Icon(Icons.lock_rounded, color: Colors.redAccent, size: 24),
                  SizedBox(width: 10),
                  Text('Device Disconnected', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: const Text(
                'Your mobile device session has been revoked by the Super Administrator.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ),
        );
      }
      return;
    }
  }

  @override
  State<SecurityVerificationDialog> createState() => _SecurityVerificationDialogState();
}

class _SecurityVerificationDialogState extends State<SecurityVerificationDialog> {
  bool _cameraDone = false;
  String? _photoBase64;
  bool _isLoading = false;

  Future<void> _takeCameraVerification() async {
    try {
      setState(() => _isLoading = true);
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 320,
        maxHeight: 240,
        imageQuality: 50,
      );

      if (xfile != null) {
        final bytes = await xfile.readAsBytes();
        final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        setState(() {
          _photoBase64 = base64Str;
          _cameraDone = true;
        });

        // Sync immediately with cloud
        await DeviceSecurityService.instance.syncSession(
          cameraSnapshotBase64: base64Str,
        );
      }
    } catch (e) {
      debugPrint('[SecurityVerificationDialog] photo error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = DeviceSecurityService.instance.securityConfig;
    final isCameraReq = config['isCameraRequired'] == true;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.shield_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Security Compliance Required',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                    Text(
                      'School Admin requires operator verification',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          if (isCameraReq)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _cameraDone ? Colors.teal : Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.camera_alt_rounded, color: Colors.purpleAccent, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Camera Verification', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                        Text(
                          _cameraDone ? 'Selfie snapshot verified ✓' : 'Operator snapshot required',
                          style: TextStyle(fontSize: 11, color: _cameraDone ? Colors.tealAccent : Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  if (_photoBase64 != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64Decode(_photoBase64!.split(',').last),
                        width: 34,
                        height: 34,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _cameraDone ? Colors.teal : AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isLoading ? null : _takeCameraVerification,
                    child: Text(
                      _cameraDone ? 'Retake' : 'Take Photo',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // Completion Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                widget.onCompleted();
              },
              child: const Text('Continue to App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
