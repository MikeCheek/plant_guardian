import 'package:flutter/material.dart';

class AppColors {
  // Brand colors
  static const Color seed = Color(0xFF2F7D4E);
  static const Color moss = Color(0xFF3D8F5F);
  static const Color leaf = Color(0xFF71B97A);
  static const Color fern = Color(0xFF1F5C3C);
  static const Color soil = Color(0xFF8E5A3A);
  static const Color sunrise = Color(0xFFF0B574);
  static const Color nightMist = Color(0xFF1A1F22);
  static const Color slate = Color(0xFF2A3236);

  // Light theme tokens
  static const Color lightBackground = Color(0xFFF1EEE7);
  static const Color lightSurface = Color(0xFFF8F4ED);
  static const Color lightPrimary = Color(0xFF3E6E53);
  static const Color lightSecondary = Color(0xFF7CA786);
  static const Color lightAccent = Color(0xFF8E5A3A);
  static const Color lightText = Color(0xFF2A332F);
  static const Color lightButton = Color(0xFF3B6A50);

  // Dark theme tokens
  static const Color darkBackground = Color(0xFF111517);
  static const Color darkSurface = Color(0xFF1A2023);
  static const Color darkPrimary = Color(0xFF6FA884);
  static const Color darkSecondary = Color(0xFF88A997);
  static const Color darkAccent = Color(0xFFCF9160);
  static const Color darkText = Color(0xFFE7E6E1);
  static const Color darkButton = Color(0xFF5D9272);

  // Semantic status colors
  static const Color success = Color(0xFF3FAE5F);
  static const Color warning = Color(0xFFF0B574);
  static const Color danger = Color(0xFFDA6A52);

  static LinearGradient backgroundGradient(bool isDark) {
    if (isDark) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF171B1E), Color(0xFF121619), Color(0xFF202629)],
      );
    }

    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF6F2EB), Color(0xFFF0ECE5), Color(0xFFEAE5DD)],
    );
  }

  static LinearGradient shellGradient(bool isDark) {
    if (isDark) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2B353A), Color(0xFF1E262A)],
      );
    }

    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF6F3ED), Color(0xFFECE7DE)],
    );
  }
}
