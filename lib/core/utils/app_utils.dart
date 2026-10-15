import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppUtils {
  static String formatDate(DateTime date) {
    return DateFormat('dd-MM-yyyy').format(date);
  }

  static String formatDateLong(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }

  static String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'hi_IN',
      symbol: '\u20B9', // Unicode Rupee symbol — works in PDF with NotoSans
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  static String generateStudentId(int index) {
    return 'STU${index.toString().padLeft(5, '0')}';
  }

  static String getGrade(double percentage) {
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 70) return 'B+';
    if (percentage >= 60) return 'B';
    if (percentage >= 50) return 'C';
    if (percentage >= 40) return 'D';
    return 'F';
  }

  static String getAttendancePercentage(int present, int total) {
    if (total == 0) return '0%';
    return '${((present / total) * 100).toStringAsFixed(1)}%';
  }

  static bool isValidMobile(String mobile) {
    return RegExp(r'^[6-9]\d{9}$').hasMatch(mobile);
  }

  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  static String getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  /// Universally loads raw image bytes from Network URL, Base64 data string, or local file.
  static Future<Uint8List?> loadAppImageBytes(String? path) async {
    if (path == null || path.trim().isEmpty) return null;
    final trimmed = path.trim();
    try {
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        final request = await HttpClient().getUrl(Uri.parse(trimmed));
        final response = await request.close();
        if (response.statusCode == 200) {
          return await consolidateHttpClientResponseBytes(response);
        }
      } else if (trimmed.startsWith('data:image')) {
        final base64Str = trimmed.split(',').last;
        return base64Decode(base64Str);
      } else {
        final file = File(trimmed);
        if (file.existsSync()) {
          return await file.readAsBytes();
        }
        // Fallback for raw Base64 strings (without data:image prefix)
        try {
          final clean = trimmed.replaceAll('\n', '').replaceAll('\r', '').trim();
          return base64Decode(clean);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[AppUtils] loadAppImageBytes error: $e');
    }
    return null;
  }

  /// Universally builds an Image Widget from Network URL, Base64 data string, or local file.
  static Widget buildAppImageWidget(
    String? path, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
  }) {
    if (path == null || path.trim().isEmpty) {
      return placeholder ?? const SizedBox.shrink();
    }
    final trimmed = path.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Image.network(
        trimmed,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => placeholder ?? const SizedBox.shrink(),
      );
    }
    if (trimmed.startsWith('data:image')) {
      try {
        final bytes = base64Decode(trimmed.split(',').last.trim());
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => placeholder ?? const SizedBox.shrink(),
        );
      } catch (_) {}
    }
    try {
      final file = File(trimmed);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => placeholder ?? const SizedBox.shrink(),
        );
      }
    } catch (_) {}
    // Fallback for raw Base64 strings
    try {
      final clean = trimmed.replaceAll('\n', '').replaceAll('\r', '').trim();
      final bytes = base64Decode(clean);
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => placeholder ?? const SizedBox.shrink(),
      );
    } catch (_) {}
    return placeholder ?? const SizedBox.shrink();
  }
}
