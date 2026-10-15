import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

class SignatureProcessor {
  /// Cleans paper background, removes rectangular borders, and converts ink strokes to selected ink color PNG.
  /// [colorMode] options: 'white' (Pure White Contrast), 'gold' (Gold Ink), 'dark' (Dark Ink), 'blue' (Royal Blue).
  static Future<String?> processAndCleanSignature(
    dynamic source, {
    String colorMode = 'white',
  }) async {
    try {
      Uint8List? bytes;
      if (source == null) return null;

      if (source is Uint8List) {
        bytes = source;
      } else if (source is String) {
        if (source.isEmpty) return null;
        if (source.startsWith('data:image')) {
          final commaIdx = source.indexOf(',');
          if (commaIdx != -1) {
            bytes = base64Decode(source.substring(commaIdx + 1).trim());
          }
        } else if (source.startsWith('/') || source.contains(r'\')) {
          final file = File(source);
          if (await file.exists()) {
            bytes = await file.readAsBytes();
          }
        } else {
          try {
            bytes = base64Decode(source.trim());
          } catch (_) {}
        }
      }

      if (bytes == null || bytes.isEmpty) return source is String ? source : null;

      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final ui.Image image = frame.image;

      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return source is String ? source : null;

      final pixels = byteData.buffer.asUint8List();
      final totalPixels = pixels.length ~/ 4;

      // Scan min/max luminance
      double minLum = 255;
      double maxLum = 0;
      int transparentCount = 0;
      final lumList = Float32List(totalPixels);

      for (int i = 0, j = 0; i < pixels.length; i += 4, j++) {
        final r = pixels[i];
        final g = pixels[i + 1];
        final b = pixels[i + 2];
        final a = pixels[i + 3];

        if (a < 20) {
          transparentCount++;
          lumList[j] = 255;
          continue;
        }

        final lum = 0.299 * r + 0.587 * g + 0.114 * b;
        lumList[j] = lum;
        if (lum < minLum) minLum = lum;
        if (lum > maxLum) maxLum = lum;
      }

      final lumRange = maxLum - minLum;
      final strokeCutoff = (minLum + lumRange * 0.45).clamp(0.0, 160.0);
      final featherStart = strokeCutoff * 0.70;

      // Target RGB values based on colorMode (exact match to Web IdCardView.jsx)
      int targetR = 255;
      int targetG = 255;
      int targetB = 255;

      final mode = colorMode.toLowerCase().trim();
      if (mode == 'gold') {
        targetR = 255;
        targetG = 215;
        targetB = 0;
      } else if (mode == 'dark') {
        targetR = 10;
        targetG = 17;
        targetB = 40;
      } else if (mode == 'blue') {
        targetR = 15;
        targetG = 62;
        targetB = 138;
      } else {
        // white / default
        targetR = 255;
        targetG = 255;
        targetB = 255;
      }

      final bool alreadyClean = transparentCount > (totalPixels * 0.25);

      for (int i = 0, j = 0; i < pixels.length; i += 4, j++) {
        final a = pixels[i + 3];
        final lum = lumList[j];

        if (alreadyClean) {
          if (a < 20) {
            pixels[i] = 0;
            pixels[i + 1] = 0;
            pixels[i + 2] = 0;
            pixels[i + 3] = 0;
            continue;
          }
          pixels[i] = targetR;
          pixels[i + 1] = targetG;
          pixels[i + 2] = targetB;
        } else {
          if (lum >= strokeCutoff || a < 20) {
            pixels[i] = 0;
            pixels[i + 1] = 0;
            pixels[i + 2] = 0;
            pixels[i + 3] = 0;
            continue;
          }

          int alpha;
          if (lum <= featherStart) {
            alpha = 255;
          } else {
            final t = (strokeCutoff - lum) / (strokeCutoff - featherStart);
            alpha = (t * t * 255).clamp(0, 255).toInt();
          }

          pixels[i] = targetR;
          pixels[i + 1] = targetG;
          pixels[i + 2] = targetB;
          pixels[i + 3] = alpha;
        }
      }

      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixels,
        image.width,
        image.height,
        ui.PixelFormat.rgba8888,
        (result) => completer.complete(result),
      );
      final outImage = await completer.future;
      final outByteData = await outImage.toByteData(format: ui.ImageByteFormat.png);
      if (outByteData == null) return source is String ? source : null;
      final pngBytes = outByteData.buffer.asUint8List();

      return 'data:image/png;base64,${base64Encode(pngBytes)}';
    } catch (e) {
      debugPrint('Error processing signature: \$e');
      return source is String ? source : null;
    }
  }
  /// Cleans paper background from official rubber stamps/seals, converting white/light paper background to transparent.
  /// Preserves the original stamp ink color (blue, violet, red, green, black) while boosting contrast.
  static Future<String?> processAndCleanStamp(
    dynamic source, {
    double brightnessThreshold = 205.0,
  }) async {
    try {
      Uint8List? bytes;
      if (source == null) return null;

      if (source is Uint8List) {
        bytes = source;
      } else if (source is String) {
        if (source.isEmpty) return null;
        if (source.startsWith('data:image')) {
          final commaIdx = source.indexOf(',');
          if (commaIdx != -1) {
            bytes = base64Decode(source.substring(commaIdx + 1).trim());
          }
        } else if (source.startsWith('/') || source.contains(r'\')) {
          final file = File(source);
          if (await file.exists()) {
            bytes = await file.readAsBytes();
          }
        } else {
          try {
            bytes = base64Decode(source.trim());
          } catch (_) {}
        }
      }

      if (bytes == null || bytes.isEmpty) return source is String ? source : null;

      // Downscale to max 180px for instant processing and staying well under Firestore 1MB document limit (<20KB)
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 180,
      );
      final frame = await codec.getNextFrame();
      final ui.Image image = frame.image;

      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return source is String ? source : null;

      final pixels = byteData.buffer.asUint8List();
      final totalPixels = pixels.length ~/ 4;

      int transparentCount = 0;
      double minLum = 255.0;
      double maxLum = 0.0;
      final lumList = Float32List(totalPixels);

      for (int i = 0, j = 0; i < pixels.length; i += 4, j++) {
        final r = pixels[i];
        final g = pixels[i + 1];
        final b = pixels[i + 2];
        final a = pixels[i + 3];

        if (a < 20) {
          transparentCount++;
          lumList[j] = 255.0;
          continue;
        }

        final lum = 0.299 * r + 0.587 * g + 0.114 * b;
        lumList[j] = lum;
        if (lum < minLum) minLum = lum;
        if (lum > maxLum) maxLum = lum;
      }

      final bool alreadyClean = transparentCount > (totalPixels * 0.20);
      if (alreadyClean) {
        final outByteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (outByteData != null) {
          return 'data:image/png;base64,${base64Encode(outByteData.buffer.asUint8List())}';
        }
        return source is String && source.startsWith('data:image')
            ? source
            : 'data:image/png;base64,${base64Encode(bytes)}';
      }

      int paperCount = 0;
      for (int i = 0, j = 0; i < pixels.length; i += 4, j++) {
        final r = pixels[i];
        final g = pixels[i + 1];
        final b = pixels[i + 2];
        final a = pixels[i + 3];

        if (a < 20) {
          paperCount++;
          pixels[i] = 0;
          pixels[i + 1] = 0;
          pixels[i + 2] = 0;
          pixels[i + 3] = 0;
          continue;
        }

        final lum = lumList[j];
        final maxC = math.max(r, math.max(g, b));
        final minC = math.min(r, math.min(g, b));
        final sat = maxC - minC;

        // Paper is bright (lum > 185) with low color saturation (sat < 35), OR bright neutral off-white
        final isPaper = (lum > 185 && sat < 35) || (r > 215 && g > 215 && b > 215 && sat < 25);

        if (isPaper) {
          paperCount++;
          pixels[i] = 0;
          pixels[i + 1] = 0;
          pixels[i + 2] = 0;
          pixels[i + 3] = 0;
        } else {
          // Preserve stamp ink details with full solid opacity
          pixels[i + 3] = 255;
        }
      }

      // Safety guard: only abort if > 98.5% of pixels became transparent (pure blank white sheet)
      if (paperCount > (totalPixels * 0.985)) {
        final origByteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (origByteData != null) {
          return 'data:image/png;base64,${base64Encode(origByteData.buffer.asUint8List())}';
        }
        return source is String && source.startsWith('data:image') ? source : null;
      }

      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixels,
        image.width,
        image.height,
        ui.PixelFormat.rgba8888,
        (result) => completer.complete(result),
      );
      final outImage = await completer.future;
      final outByteData = await outImage.toByteData(format: ui.ImageByteFormat.png);
      if (outByteData == null) return source is String ? source : null;
      final pngBytes = outByteData.buffer.asUint8List();

      return 'data:image/png;base64,${base64Encode(pngBytes)}';
    } catch (e) {
      debugPrint('Error processing school stamp: $e');
      return source is String ? source : null;
    }
  }

}
