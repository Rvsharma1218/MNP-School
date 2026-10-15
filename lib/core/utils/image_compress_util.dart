import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImageCompressUtil {
  /// Compresses any student photo file down to [minKb] - [maxKb] (default 20 - 30 KB).
  /// Preserves clear facial details and optimal passport photo resolution.
  static Future<File> compressStudentPhotoFile(
    File inputFile, {
    int minKb = 20,
    int maxKb = 30,
    int maxDimension = 480,
  }) async {
    final bytes = await inputFile.readAsBytes();
    final compressedBytes = await compressBytesToTargetKb(
      bytes,
      minKb: minKb,
      maxKb: maxKb,
      maxDimension: maxDimension,
    );

    final tempDir = await getTemporaryDirectory();
    final outPath = '${tempDir.path}/student_dp_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outFile = File(outPath);
    await outFile.writeAsBytes(compressedBytes);
    return outFile;
  }

  /// Compresses an existing photo string (base64 Data URL, raw base64, or local file)
  /// down to [minKb] - [maxKb] (20 - 30 KB). Returns the optimized base64 Data URL.
  /// If already under 35 KB, returns as-is without re-encoding.
  static Future<String?> compressExistingPhotoString(
    String? rawPhoto, {
    int minKb = 20,
    int maxKb = 30,
  }) async {
    if (rawPhoto == null || rawPhoto.trim().isEmpty) return null;
    final trimmed = rawPhoto.trim();

    Uint8List? rawBytes;

    if (trimmed.startsWith('data:image/')) {
      final commaIdx = trimmed.indexOf(',');
      if (commaIdx != -1) {
        final b64Part = trimmed.substring(commaIdx + 1);
        // If base64 length <= 42 KB characters (~30 KB binary), it is already optimized!
        if (b64Part.length <= 42 * 1024) {
          return trimmed;
        }
        try {
          rawBytes = base64Decode(b64Part);
        } catch (_) {}
      }
    } else if (trimmed.startsWith('/') || trimmed.startsWith('file:') || File(trimmed).existsSync()) {
      try {
        final f = File(trimmed.replaceFirst('file://', ''));
        if (await f.exists()) {
          final len = await f.length();
          if (len <= maxKb * 1024) {
            final b = await f.readAsBytes();
            return 'data:image/jpeg;base64,${base64Encode(b)}';
          }
          rawBytes = await f.readAsBytes();
        }
      } catch (_) {}
    } else {
      // Possible raw base64
      if (trimmed.length > 42 * 1024) {
        try {
          rawBytes = base64Decode(trimmed);
        } catch (_) {}
      }
    }

    if (rawBytes == null) return rawPhoto;

    final compressed = await compressBytesToTargetKb(rawBytes, minKb: minKb, maxKb: maxKb);
    return 'data:image/jpeg;base64,${base64Encode(compressed)}';
  }

  /// Compresses raw bytes down to [minKb] - [maxKb] (20 - 30 KB).
  static Future<Uint8List> compressBytesToTargetKb(
    Uint8List inputBytes, {
    int minKb = 20,
    int maxKb = 30,
    int maxDimension = 480,
  }) async {
    img.Image? decoded = img.decodeImage(inputBytes);
    if (decoded == null) return inputBytes;

    // Auto-fix orientation from EXIF
    decoded = img.bakeOrientation(decoded);

    int targetW = decoded.width;
    int targetH = decoded.height;

    // Scale down if exceeding maxDimension (standard passport photo is around 360x480)
    if (targetW > maxDimension || targetH > maxDimension) {
      if (targetW >= targetH) {
        targetH = (targetH * maxDimension / targetW).round();
        targetW = maxDimension;
      } else {
        targetW = (targetW * maxDimension / targetH).round();
        targetH = maxDimension;
      }
    }

    img.Image resized = img.copyResize(
      decoded,
      width: targetW,
      height: targetH,
      interpolation: img.Interpolation.linear,
    );

    // Initial compression at quality 75
    int quality = 75;
    List<int> result = img.encodeJpg(resized, quality: quality);

    // If larger than maxKb (30 KB), step down quality and dimensions
    int iterations = 0;
    while (result.length > maxKb * 1024 && iterations < 8) {
      iterations++;
      if (quality > 32) {
        quality -= 8;
      } else {
        // Quality floor reached: scale down dimensions by 12%
        targetW = (targetW * 0.88).round();
        targetH = (targetH * 0.88).round();
        resized = img.copyResize(resized, width: targetW, height: targetH);
      }
      result = img.encodeJpg(resized, quality: quality);
    }

    // If smaller than minKb (20 KB) and quality < 92, increase quality to preserve crispness
    iterations = 0;
    while (result.length < minKb * 1024 && quality < 92 && iterations < 4) {
      iterations++;
      quality += 8;
      final tryBytes = img.encodeJpg(resized, quality: quality);
      if (tryBytes.length <= maxKb * 1024) {
        result = tryBytes;
      } else {
        break;
      }
    }

    return Uint8List.fromList(result);
  }
}
