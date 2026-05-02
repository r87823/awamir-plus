import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const gold = Color(0xFFC9A84C);
  static const goldLight = Color(0xFFE8D48B);
  static const goldDark = Color(0xFFA07D2E);
  static const cream = Color(0xFFFAF6EE);
  static const creamDark = Color(0xFFF0EBE0);
  static const navy = Color(0xFF1B2A4A);
  static const navyLight = Color(0xFF2C3E6B);
  static const navyDark = Color(0xFF0F1B33);
  static const brown = Color(0xFF5C4A32);
  static const brownLight = Color(0xFF8B7355);
  static const green = Color(0xFF2D6A4F);
  static const greenLight = Color(0xFF40916C);
  static const red = Color(0xFF9B2226);
  static const redLight = Color(0xFFCA6702);
  static const textDark = Color(0xFF1A1A2E);
  static const textBody = Color(0xFF3D3D5C);
  static const textMuted = Color(0xFF8E8EA0);
  static const white = Color(0xFFFFFFFF);
}

class AppRadius {
  const AppRadius._();

  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 18.0;
}

class AppShadows {
  const AppShadows._();

  static List<BoxShadow> soft = [
    BoxShadow(
      color: AppColors.navy.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> strong = [
    BoxShadow(
      color: AppColors.navy.withValues(alpha: 0.12),
      blurRadius: 40,
      offset: const Offset(0, 12),
    ),
  ];
}

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Tajawal',
      scaffoldBackgroundColor: AppColors.cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.gold,
        primary: AppColors.navy,
        secondary: AppColors.gold,
        surface: AppColors.white,
        error: AppColors.red,
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: 'Tajawal',
        bodyColor: AppColors.textBody,
        displayColor: AppColors.textDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Tajawal',
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: AppColors.white,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.creamDark, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.creamDark, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
        labelStyle: const TextStyle(
          color: AppColors.textBody,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.navyDark,
          elevation: 0,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          side: const BorderSide(color: AppColors.navy, width: 1.5),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
