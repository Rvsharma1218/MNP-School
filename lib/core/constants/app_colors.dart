import 'package:flutter/material.dart';

class AppColors {
  // Primary palette — exact match to website's --primary: #1f108e
  static const primary = Color(0xFF1F108E);       // Deep Indigo (website match)
  static const primaryLight = Color(0xFF281AB5);  // Hover variant
  static const primaryDark = Color(0xFF160B6A);   // Darker

  // Accent — website's #e84c3d (red-orange)
  static const accent = Color(0xFFE84C3D);
  static const accentLight = Color(0xFFFF7B6E);
  static const accentDark = Color(0xFFB5372A);

  // Secondary — teal
  static const secondary = Color(0xFF00897B);     // Teal
  static const secondaryLight = Color(0xFF26A69A);
  static const secondaryDark = Color(0xFF00695C);

  // Background — website's --background: #f5f4fa
  static const background = Color(0xFFF5F4FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFEFF4FF);

  // Dark theme backgrounds
  static const darkBackground = Color(0xFF0F1035);
  static const darkSurface = Color(0xFF1A1B4B);
  static const darkCard = Color(0xFF252669);

  // Status colors (website compatible)
  static const success = Color(0xFF2E7D32);
  static const successLight = Color(0xFFE8F5E9);
  static const warning = Color(0xFFF57F17);
  static const warningLight = Color(0xFFFFF8E1);
  static const error = Color(0xFFC62828);
  static const errorLight = Color(0xFFFFEBEE);
  static const info = Color(0xFF1565C0);
  static const infoLight = Color(0xFFE3F2FD);

  // Text — website's --text: #1c1535, --text-secondary: #6b6783
  static const textPrimary = Color(0xFF1C1535);
  static const textSecondary = Color(0xFF6B6783);
  static const textHint = Color(0xFF9E9E9E);
  static const textLight = Color(0xFFFFFFFF);

  // Card gradients
  static const List<Color> gradientBlue = [Color(0xFF1F108E), Color(0xFF281AB5)];
  static const List<Color> gradientTeal = [Color(0xFF00695C), Color(0xFF26A69A)];
  static const List<Color> gradientGold = [Color(0xFFFFA000), Color(0xFFFFD54F)];
  static const List<Color> gradientPurple = [Color(0xFF4A148C), Color(0xFF7B1FA2)];
  static const List<Color> gradientOrange = [Color(0xFFE65100), Color(0xFFFF8F00)];
  static const List<Color> gradientGreen = [Color(0xFF1B5E20), Color(0xFF388E3C)];
  static const List<Color> gradientRed = [Color(0xFFE84C3D), Color(0xFFFF7B6E)];

  // Border — website's --border: #c8c4d5
  static const border = Color(0xFFC8C4D5);
  static const divider = Color(0xFFE8EAF6);
}
