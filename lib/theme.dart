import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class AppTheme {
  static final ThemeData lightTheme = _buildTheme(Brightness.light);
  static final ThemeData darkTheme = _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme scheme = isDark
        ? const ColorScheme.dark(
            primary: AppColors.darkPrimary,
            onPrimary: Color(0xFF0E1511),
            secondary: AppColors.darkSecondary,
            onSecondary: Color(0xFF121A16),
            tertiary: AppColors.darkAccent,
            onTertiary: Color(0xFF261409),
            error: AppColors.danger,
            onError: Colors.white,
            surface: AppColors.darkSurface,
            onSurface: AppColors.darkText,
            surfaceContainerHighest: Color(0xFF2A3034),
            outline: Color(0xFF566066),
          )
        : const ColorScheme.light(
            primary: AppColors.lightPrimary,
            onPrimary: Colors.white,
            secondary: AppColors.lightSecondary,
            onSecondary: Color(0xFF1A2B21),
            tertiary: AppColors.lightAccent,
            onTertiary: Colors.white,
            error: AppColors.danger,
            onError: Colors.white,
            surface: AppColors.lightSurface,
            onSurface: AppColors.lightText,
            surfaceContainerHighest: Color(0xFFE6E0D6),
            outline: Color(0xFFA29E94),
          );

    final TextTheme baseText = isDark
        ? Typography.whiteMountainView
        : Typography.blackMountainView;

    final TextTheme textTheme = GoogleFonts.manropeTextTheme(baseText).copyWith(
      displayLarge: GoogleFonts.sora(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        color: scheme.onSurface,
      ),
      displayMedium: GoogleFonts.sora(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: scheme.onSurface,
      ),
      headlineMedium: GoogleFonts.sora(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: scheme.onSurface,
      ),
      titleLarge: GoogleFonts.sora(
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      bodyLarge: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: scheme.onSurface,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14,
        color: scheme.onSurface.withValues(alpha: 0.88),
      ),
      labelLarge: GoogleFonts.manrope(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface.withValues(alpha: isDark ? 0.8 : 0.95),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline.withValues(alpha: 0.35),
        thickness: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface.withValues(alpha: isDark ? 0.84 : 0.94),
        indicatorColor: scheme.secondary.withValues(
          alpha: isDark ? 0.22 : 0.18,
        ),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return IconThemeData(color: scheme.primary, size: 24);
          }
          return IconThemeData(
            color: scheme.onSurface.withValues(alpha: 0.62),
            size: 22,
          );
        }),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          final bool selected = states.contains(MaterialState.selected);
          return GoogleFonts.manrope(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 12,
            color: selected
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: 0.65),
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.secondary.withValues(alpha: 0.22),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: textTheme.labelMedium,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface.withValues(alpha: isDark ? 0.72 : 0.9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        labelStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.72)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.55)),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primary.withValues(alpha: 0.2),
        circularTrackColor: scheme.primary.withValues(alpha: 0.2),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        backgroundColor: scheme.surfaceContainerHighest,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
