import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Base
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const darkBg = Color(0xFF0A0A0A);   // body dark: globals.css --background dark
  static const darkFg = Color(0xFFEDEDED);   // body dark: globals.css --foreground dark
  static const lightFg = Color(0xFF171717);  // body light foreground

  // Slate scale
  static const slate950 = Color(0xFF020617);
  static const slate900 = Color(0xFF0F172A);  // .dark .bg-white → #0f172a
  static const slate800 = Color(0xFF1E293B);
  static const slate700 = Color(0xFF334155);
  static const slate600 = Color(0xFF475569);
  static const slate500 = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate50 = Color(0xFFF8FAFC);

  // Gray scale (login page)
  static const gray100 = Color(0xFFF3F4F6);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray300 = Color(0xFFD1D5DB);
  static const gray900 = Color(0xFF111827);

  // Blue
  static const blue600 = Color(0xFF2563EB);
  static const blue500 = Color(0xFF3B82F6);
  static const blue400 = Color(0xFF60A5FA);

  // Indigo
  static const indigo600 = Color(0xFF4F46E5);
  static const indigo500 = Color(0xFF6366F1);

  // Cyan (login focus, links)
  static const cyan500 = Color(0xFF06B6D4);
  static const cyan400 = Color(0xFF22D3EE);

  // Emerald / Teal (bg orbs, badges)
  static const emerald500 = Color(0xFF10B981);
  static const teal500 = Color(0xFF14B8A6);

  // Purple (login blob)
  static const purple500 = Color(0xFFA855F7);

  // Semantic
  static const amber400 = Color(0xFFFBBF24);
  static const orange500 = Color(0xFFF97316);
  static const rose500 = Color(0xFFF43F5E);

  // Shortcuts (primary = blue-600)
  static const primary = blue600;
  static const primaryLight = blue400;
}

/// Gradient helpers
class AppGradients {
  static const primaryBtn = LinearGradient(
    colors: [AppColors.blue600, AppColors.indigo600],
  );

  static const blueOrb = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x333B82F6), Color(0x336366F1)],
  );

  static const emeraldOrb = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x3310B981), Color(0x3314B8A6)],
  );
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.blue600,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppColors.blue600,
        secondary: AppColors.indigo600,
        surface: AppColors.white,
      ),
      scaffoldBackgroundColor: AppColors.white,
      useMaterial3: true,
      textTheme: GoogleFonts.poppinsTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.lightFg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.gray300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.gray300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.cyan500, width: 1.5),
        ),
        hintStyle: GoogleFonts.poppins(
            color: AppColors.slate400, fontSize: 14),
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.blue600,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppColors.blue600,
        secondary: AppColors.indigo600,
        surface: AppColors.slate900,
      ),
      scaffoldBackgroundColor: AppColors.darkBg,
      useMaterial3: true,
      textTheme:
          GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.darkFg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.cyan500, width: 1.5),
        ),
        hintStyle: GoogleFonts.poppins(
            color: AppColors.slate500, fontSize: 14),
      ),
    );
  }
}
