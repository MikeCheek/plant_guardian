import 'package:flutter/material.dart';
import 'colors.dart';

class AppTheme {
  // Shared Shape to keep code DRY (Don't Repeat Yourself)
  static final _snackShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  );

  // Shared Margin for positioning
  static const _snackMargin = EdgeInsets.fromLTRB(20, 0, 20, 30);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBackground,
    primaryColor: AppColors.lightPrimary,
    colorScheme: const ColorScheme.light(
      primary: AppColors.lightPrimary,
      secondary: AppColors.lightSecondary,
      surface: AppColors.lightSurface,
      onPrimary: Colors.white,
      onSurface: AppColors.lightText,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: AppColors.lightText),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.lightButton,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.lightText, // Darker bar for light mode
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: _snackShape,
      elevation: 6,
      insetPadding: _snackMargin,
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    primaryColor: AppColors.darkPrimary,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.darkPrimary,
      secondary: AppColors.darkSecondary,
      surface: AppColors.darkSurface,
      onPrimary: Colors.black,
      onSurface: AppColors.darkText,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: AppColors.darkText),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.darkButton,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor:
          Colors.grey[800], // Slightly lighter bar for dark mode depth
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: _snackShape,
      elevation: 6,
      insetPadding: _snackMargin, // 🚨 Use margin, not insetPadding
    ),
  );
}
