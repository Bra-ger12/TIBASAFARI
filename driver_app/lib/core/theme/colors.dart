import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── AfyaRide brand greens ─────────────────────────────────────────────────────
const Color cTeal       = Color(0xFF0E7C66);   // Bright brand green (CTAs, active)
const Color cTealDark   = Color(0xFF0A5C4C);   // Pressed / hover
const Color cTealDeep   = Color(0xFF10211C);   // Near-black heading/emphasis text
const Color cTealMid    = Color(0xFF4FAF95);   // Mid accent
const Color cTealLight  = Color(0xFFE3F3EE);   // Light bg tint

// ── Dark surfaces (headers, nav, cards on dark) ───────────────────────────────
const Color cDark       = Color(0xFF10211C);   // Header / hero background
const Color cDarkMid    = Color(0xFF1E332C);   // Slightly lighter dark

// ── App chrome ────────────────────────────────────────────────────────────────
const Color cBg         = Color(0xFFF4F8F6);   // Scaffold background
const Color cSurface    = Color(0xFFFFFFFF);   // Card / sheet surface
const Color cBorder     = Color(0xFFE3EAE6);   // Card borders, dividers
const Color cDivider    = Color(0xFFEEF2F0);   // Light dividers inside cards

// ── Typography ────────────────────────────────────────────────────────────────
const Color cText       = Color(0xFF10211C);   // Primary text
const Color cMuted      = Color(0xFF62726C);   // Secondary/body text
const Color cMutedLight = Color(0xFF84938C);   // Hint / caption text

// ── Status semantics ─────────────────────────────────────────────────────────
const Color cError      = Color(0xFFC0503B);
const Color cAmber      = Color(0xFFD98A28);
const Color cBlue       = Color(0xFF3B82F6);
const Color cGreen      = Color(0xFF22C55E);
const Color cOrange     = Color(0xFFD98A28);
const Color cGrey       = Color(0xFF94A3B8);

// ── Info banner ───────────────────────────────────────────────────────────────
const Color cInfoBg     = Color(0xFFEFF6FF);
const Color cInfoBorder = Color(0xFFBFDBFE);
const Color cInfoText   = Color(0xFF2563EB);

/// Sora (headings/emphasis) + Manrope (body) — matches the AfyaRide design reference.
class AppFonts {
  static TextStyle sora({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w700,
    Color color = cTealDeep,
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
    Color color = cMuted,
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
