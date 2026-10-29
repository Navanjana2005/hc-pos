import 'dart:ui';
import 'package:flutter/material.dart';

/// HC-POS Design System Color Tokens
/// Matches the Stitch/Tailwind design exactly.
class AppColors {
  AppColors._();

  // ── Backgrounds ──────────────────────────────────────────
  static const Color background         = Color(0xFF0B1326);
  static const Color surface            = Color(0xFF0B1326);
  static const Color surfaceDim         = Color(0xFF0B1326);
  static const Color surfaceLowest      = Color(0xFF060E20);
  static const Color surfaceLow         = Color(0xFF131B2E);
  static const Color surfaceContainer   = Color(0xFF171F33);
  static const Color surfaceContainerHigh = Color(0xFF222A3D);
  static const Color surfaceContainerHighest = Color(0xFF2D3449);
  static const Color surfaceBright      = Color(0xFF31394D);
  static const Color surfaceVariant     = Color(0xFF2D3449);
  static const Color inverseSurface     = Color(0xFFDAE2FD);
  static const Color inverseOnSurface   = Color(0xFF283044);

  // ── Primary (blue) ────────────────────────────────────────
  static const Color primary            = Color(0xFFA4C9FF);
  static const Color primaryFixed       = Color(0xFFD4E3FF);
  static const Color primaryFixedDim    = Color(0xFFA4C9FF);
  static const Color primaryContainer   = Color(0xFF60A5FA);
  static const Color onPrimary          = Color(0xFF00315D);
  static const Color onPrimaryFixed     = Color(0xFF001C39);
  static const Color onPrimaryFixedVariant = Color(0xFF004883);
  static const Color onPrimaryContainer = Color(0xFF003A6B);
  static const Color inversePrimary     = Color(0xFF0060AC);

  // ── Secondary (green) ─────────────────────────────────────
  static const Color secondary          = Color(0xFF4DE082);
  static const Color secondaryFixed     = Color(0xFF6DFE9C);
  static const Color secondaryFixedDim  = Color(0xFF4DE082);
  static const Color secondaryContainer = Color(0xFF00B55D);
  static const Color onSecondary        = Color(0xFF003919);
  static const Color onSecondaryFixed   = Color(0xFF00210C);
  static const Color onSecondaryFixedVariant = Color(0xFF005227);
  static const Color onSecondaryContainer = Color(0xFF003E1C);

  // ── Tertiary (amber/solar) ─────────────────────────────────
  static const Color tertiary           = Color(0xFFFFB954);
  static const Color tertiaryFixed      = Color(0xFFFFDDB4);
  static const Color tertiaryFixedDim   = Color(0xFFFFB954);
  static const Color tertiaryContainer  = Color(0xFFD8952D);
  static const Color onTertiary         = Color(0xFF452B00);
  static const Color onTertiaryFixed    = Color(0xFF291800);
  static const Color onTertiaryFixedVariant = Color(0xFF633F00);
  static const Color onTertiaryContainer = Color(0xFF513200);

  // ── Error (red) ───────────────────────────────────────────
  static const Color error              = Color(0xFFFFB4AB);
  static const Color errorContainer    = Color(0xFF93000A);
  static const Color onError            = Color(0xFF690005);
  static const Color onErrorContainer   = Color(0xFFFFDAD6);

  // ── On-surface / text colors ──────────────────────────────
  static const Color onSurface         = Color(0xFFDAE2FD);
  static const Color onSurfaceVariant  = Color(0xFFC1C7D3);
  static const Color onBackground      = Color(0xFFDAE2FD);
  static const Color outline           = Color(0xFF8B919D);
  static const Color outlineVariant    = Color(0xFF414751);

  // ── Semantic shorthand aliases ────────────────────────────
  static const Color batteryGreen      = secondaryFixed;   // #6DFE9C
  static const Color solarAmber        = tertiaryFixedDim; // #FFB954
  static const Color gridBlue          = primaryFixedDim;  // #A4C9FF
  static const Color emergencyRed      = error;             // #FFB4AB
  static const Color criticalRed       = Color(0xFFFF4444);
  static const Color warningOrange     = Color(0xFFFFB954);
  static const Color infoBlue          = primary;
}
