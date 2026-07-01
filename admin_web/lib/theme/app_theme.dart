import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary = Color(0xFF0E7C66);
  static const Color primaryDark = Color(0xFF0A5C4C);
  static const Color primaryLight = Color(0xFFE3F3EE);
  static const Color accent = Color(0xFFD98A28);
  static const Color background = Color(0xFFF4F8F6);
  static const Color surface = Colors.white;
  static const Color sidebarBg = Color(0xFF10211C);
  static const Color border = Color(0xFFE3EAE6);
  static const Color textPrimary = Color(0xFF10211C);
  static const Color textMuted = Color(0xFF62726C);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
          surface: surface,
        ),
        scaffoldBackgroundColor: background,
        fontFamily: GoogleFonts.manrope().fontFamily,
        textTheme: GoogleFonts.manropeTextTheme(),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: border),
          ),
          margin: EdgeInsets.zero,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: surface,
          foregroundColor: textPrimary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w700, color: textPrimary),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: primary, width: 2),
          ),
        ),
        dividerTheme: DividerThemeData(color: border, space: 1),
      );
}

/// Sora (headings/emphasis) + Manrope (body) — matches the AfyaRide design reference.
class AppFonts {
  static TextStyle sora({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w700,
    Color color = AppTheme.textPrimary,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.sora(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  static TextStyle manrope({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    Color color = AppTheme.textMuted,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.manrope(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
}

enum StatusTone { amber, blue, green, red, slate, violet, cyan }

extension StatusToneX on StatusTone {
  Color get bg {
    switch (this) {
      case StatusTone.amber:
        return const Color(0xFFFBEFD9);
      case StatusTone.blue:
        return const Color(0xFFDBEAFE);
      case StatusTone.green:
        return const Color(0xFFE3F3EE);
      case StatusTone.red:
        return const Color(0xFFFCE9E5);
      case StatusTone.slate:
        return const Color(0xFFF1F5F9);
      case StatusTone.violet:
        return const Color(0xFFEDE9FE);
      case StatusTone.cyan:
        return const Color(0xFFCFFAFE);
    }
  }

  Color get fg {
    switch (this) {
      case StatusTone.amber:
        return const Color(0xFFA56C12);
      case StatusTone.blue:
        return const Color(0xFF1D4ED8);
      case StatusTone.green:
        return const Color(0xFF0A5C4C);
      case StatusTone.red:
        return const Color(0xFFC0503B);
      case StatusTone.slate:
        return const Color(0xFF475569);
      case StatusTone.violet:
        return const Color(0xFF6D28D9);
      case StatusTone.cyan:
        return const Color(0xFF0E7490);
    }
  }

  Color get dot {
    switch (this) {
      case StatusTone.amber:
        return const Color(0xFFD98A28);
      case StatusTone.blue:
        return const Color(0xFF0EA5E9);
      case StatusTone.green:
        return const Color(0xFF0E7C66);
      case StatusTone.red:
        return const Color(0xFFC0503B);
      case StatusTone.slate:
        return const Color(0xFF94A3B8);
      case StatusTone.violet:
        return const Color(0xFF8B5CF6);
      case StatusTone.cyan:
        return const Color(0xFF06B6D4);
    }
  }
}
