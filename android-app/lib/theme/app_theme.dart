import 'package:flutter/material.dart';

class AppColors {
  static const sky = Color(0xFFF0F6FF);
  static const deepBlue = Color(0xFF1D4E89);
  static const ocean = Color(0xFF0E3C70);
  static const card = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF09203B);
  static const textMuted = Color(0xFF60728A);
  static const accent = Color(0xFF4A90E2);
  static const line = Color(0xFFD9E6F7);
  static const good = Color(0xFF2BAA66);
  static const warn = Color(0xFFF5A623);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.deepBlue,
      brightness: Brightness.light,
      primary: AppColors.deepBlue,
      secondary: AppColors.accent,
      surface: AppColors.card,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.sky,
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    textTheme: base.textTheme.copyWith(
      headlineMedium: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      bodyMedium: const TextStyle(
        color: AppColors.textMuted,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.6),
      ),
    ),
  );
}

