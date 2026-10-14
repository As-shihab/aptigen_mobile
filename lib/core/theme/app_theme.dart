import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Raw color constants. Market screens should read colors through
/// [Palette.of] instead so light/dark both work.
class AppColors {
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const darkBg = Color(0xFF0B1120);
  static const darkFg = Color(0xFFEDEDED);
  static const lightFg = Color(0xFF171717);

  static const slate950 = Color(0xFF020617);
  static const slate900 = Color(0xFF0F172A);
  static const slate800 = Color(0xFF1E293B);
  static const slate700 = Color(0xFF334155);
  static const slate600 = Color(0xFF475569);
  static const slate500 = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate50 = Color(0xFFF8FAFC);

  static const gray100 = Color(0xFFF3F4F6);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray300 = Color(0xFFD1D5DB);
  static const gray900 = Color(0xFF111827);

  static const blue600 = Color(0xFF0A6ED1);
  static const indigo600 = Color(0xFF0854A0);
  static const cyan500 = Color(0xFF0A6ED1);
  static const purple500 = Color(0xFFA855F7);
  static const rose500 = Color(0xFFF43F5E);

  /// Aptigen market brand blue (SAP blue) — same `#0A6ED1` the web market
  /// uses for links, active states and primary actions.
  static const accent = Color(0xFF0A6ED1);
  static const accentDark = Color(0xFF0854A0);
  static const primary = accent;

  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
  static const star = Color(0xFFFBBF24);
}

class AppGradients {
  static const primaryBtn = LinearGradient(
    colors: [AppColors.accent, AppColors.accentDark],
  );
}

/// One soft-background / strong-foreground pair. Category icons, chips and
/// promo cards cycle these by list position, like `ICON_TINTS` in
/// frontend/app/lib/marketBrand.ts.
class Tone {
  final Color bg;
  final Color fg;
  const Tone(this.bg, this.fg);
}

const _lightTones = <Tone>[
  Tone(Color(0xFFEAF3FC), Color(0xFF0A6ED1)),
  Tone(Color(0xFFFFF1F2), Color(0xFFE11D48)),
  Tone(Color(0xFFFFFBEB), Color(0xFFD97706)),
  Tone(Color(0xFFECFDF5), Color(0xFF059669)),
  Tone(Color(0xFFF5F3FF), Color(0xFF7C3AED)),
  Tone(Color(0xFFF0F9FF), Color(0xFF0284C7)),
  Tone(Color(0xFFFFF7ED), Color(0xFFEA580C)),
  Tone(Color(0xFFF7FEE7), Color(0xFF4D7C0F)),
];

/// Theme-aware market palette — mirrors marketBrand.ts for light mode and
/// derives a matching dark variant.
class Palette {
  final bool isDark;
  final Color bg;
  final Color card;
  final Color fill;
  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final Color border;
  final Color accent;
  final Color accentSoft;

  const Palette._({
    required this.isDark,
    required this.bg,
    required this.card,
    required this.fill,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.accent,
    required this.accentSoft,
  });

  static const light = Palette._(
    isDark: false,
    bg: Color(0xFFF8FAFC),
    card: Color(0xFFFFFFFF),
    fill: Color(0xFFF1F5F9),
    text: Color(0xFF111827),
    textSecondary: Color(0xFF64748B),
    textTertiary: Color(0xFF94A3B8),
    border: Color(0xFFE5E7EB),
    accent: AppColors.accent,
    accentSoft: Color(0xFFEAF3FC),
  );

  static const dark = Palette._(
    isDark: true,
    bg: Color(0xFF0B1120),
    card: Color(0xFF111827),
    fill: Color(0xFF1E293B),
    text: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    textTertiary: Color(0xFF64748B),
    border: Color(0xFF1F2937),
    accent: Color(0xFF3B8FE0),
    accentSoft: Color(0xFF13263D),
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  Tone tone(int index) {
    final t = _lightTones[index % _lightTones.length];
    if (!isDark) return t;
    return Tone(t.fg.withValues(alpha: 0.16), Color.lerp(t.fg, Colors.white, 0.25)!);
  }
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Palette.light, Brightness.light);
  static ThemeData dark() => _build(Palette.dark, Brightness.dark);

  static ThemeData _build(Palette p, Brightness brightness) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: brightness,
      ).copyWith(
        primary: p.accent,
        onPrimary: Colors.white,
        surface: p.card,
        onSurface: p.text,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: p.bg,
      textTheme: GoogleFonts.poppinsTextTheme(base).apply(
        bodyColor: p.text,
        displayColor: p.text,
      ),
      splashFactory: InkSparkle.splashFactory,
      dividerColor: p.border,
      appBarTheme: AppBarTheme(
        backgroundColor: p.card,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: p.text,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.isDark ? p.fill : const Color(0xFF111827),
        contentTextStyle: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.fill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.accent, width: 1.4),
        ),
        hintStyle: GoogleFonts.poppins(color: p.textTertiary, fontSize: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: p.fill,
          disabledForegroundColor: p.textTertiary,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          side: BorderSide(color: p.border),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
