import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'signature_processor.dart';

class SignatureHelper {
  /// Picks image from camera/gallery, opens crop tool, and removes background to output dark-ink transparent base64 PNG.
  static Future<String?> pickCropAndCleanSignature(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 92);
    if (picked == null) return null;

    // 1. Interactive Crop step
    CroppedFile? cropped;
    try {
      cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Signature (हस्ताक्षर क्रॉप करें)',
            toolbarColor: const Color(0xFF7C3AED),
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: const Color(0xFF7C3AED),
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Signature',
            aspectRatioLockEnabled: false,
          ),
        ],
      );
    } catch (_) {}

    final effectivePath = cropped?.path ?? picked.path;

    // 2. Remove paper background and clean to dark ink transparent PNG
    final cleaned = await SignatureProcessor.processAndCleanSignature(effectivePath, colorMode: 'dark');
    return cleaned;
  }

  /// Full size signature preview dialog with background removal details
  static void showFullSignatureDialog(BuildContext context, String signatureUrl, String teacherName) {
    Uint8List? bytes;
    try {
      final b64 = signatureUrl.contains(',') ? signatureUrl.split(',').last.trim() : signatureUrl.trim();
      bytes = base64Decode(b64);
    } catch (_) {}

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.draw_rounded, color: Color(0xFF7C3AED), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Signature • $teacherName', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 180,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: bytes != null
                  ? Image.memory(bytes, fit: BoxFit.contain)
                  : const Center(child: Text('Signature Preview Error')),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 16),
                  SizedBox(width: 6),
                  Text('Background Removed (Transparent PNG)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  /// Transparent preview box widget with BG removed badge
  static Widget buildSignaturePreviewBox({
    required BuildContext context,
    required String? signatureUrl,
    required String teacherName,
    VoidCallback? onCropEdit,
    VoidCallback? onRemove,
  }) {
    if (signatureUrl == null || signatureUrl.trim().isEmpty) return const SizedBox.shrink();

    Uint8List? bytes;
    try {
      final b64 = signatureUrl.contains(',') ? signatureUrl.split(',').last.trim() : signatureUrl.trim();
      bytes = base64Decode(b64);
    } catch (_) {}

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => showFullSignatureDialog(context, signatureUrl, teacherName),
            child: Stack(
              children: [
                Container(
                  height: 75,
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  child: Center(
                    child: bytes != null
                        ? Image.memory(bytes, fit: BoxFit.contain)
                        : const Text('Signature Preview Error', style: TextStyle(color: Colors.red, fontSize: 11)),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('✨ BG REMOVED', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in, size: 12, color: Colors.blueGrey),
                        SizedBox(width: 2),
                        Text('Tap to View Full', style: TextStyle(fontSize: 9, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onCropEdit != null || onRemove != null) ...[
            const SizedBox(height: 6),
            const Divider(height: 1),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onCropEdit != null)
                  TextButton.icon(
                    onPressed: onCropEdit,
                    icon: const Icon(Icons.crop_rounded, size: 14, color: Color(0xFF7C3AED)),
                    label: const Text('Crop / Re-edit', style: TextStyle(fontSize: 11, color: Color(0xFF7C3AED), fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero),
                  ),
                if (onRemove != null)
                  TextButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                    label: const Text('Remove', style: TextStyle(fontSize: 11, color: Colors.red)),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

