import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle heading1 = GoogleFonts.poppins(
    fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.white,
  );

  static TextStyle heading2 = GoogleFonts.poppins(
    fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.white,
  );

  static TextStyle heading3 = GoogleFonts.poppins(
    fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.white,
  );

  static TextStyle bodyLarge = GoogleFonts.poppins(
    fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.white,
  );

  static TextStyle bodyMedium = GoogleFonts.poppins(
    fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.white,
  );

  static TextStyle bodySmall = GoogleFonts.poppins(
    fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.grey,
  );

  static TextStyle labelMedium = GoogleFonts.poppins(
    fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.white,
  );

  static TextStyle labelSmall = GoogleFonts.poppins(
    fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.grey,
  );

  static TextStyle button = GoogleFonts.poppins(
    fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.white,
    letterSpacing: 0.5,
  );

  static TextStyle cyan = GoogleFonts.poppins(
    fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.cyan,
  );
}
