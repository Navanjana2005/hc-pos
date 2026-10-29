import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// HC-POS Typography — Manrope font system matching Stitch design.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get headlineXl => GoogleFonts.manrope(
        fontSize: 40,
        height: 48 / 40,
        letterSpacing: -0.02 * 40,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      );

  static TextStyle get headlineLg => GoogleFonts.manrope(
        fontSize: 32,
        height: 40 / 32,
        letterSpacing: -0.01 * 32,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      );

  static TextStyle get headlineLgMobile => GoogleFonts.manrope(
        fontSize: 28,
        height: 36 / 28,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      );

  static TextStyle get headlineMd => GoogleFonts.manrope(
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      );

  static TextStyle get bodyLg => GoogleFonts.manrope(
        fontSize: 18,
        height: 28 / 18,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurface,
      );

  static TextStyle get bodyMd => GoogleFonts.manrope(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurface,
      );

  static TextStyle get labelMd => GoogleFonts.manrope(
        fontSize: 14,
        height: 20 / 14,
        letterSpacing: 0.01 * 14,
        fontWeight: FontWeight.w500,
        color: AppColors.onSurface,
      );

  static TextStyle get labelSm => GoogleFonts.manrope(
        fontSize: 12,
        height: 16 / 12,
        letterSpacing: 0.05 * 12,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      );
}
