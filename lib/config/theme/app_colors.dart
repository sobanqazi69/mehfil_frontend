import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color darkBg      = Color(0xFF110D2B);
  static const Color cardBg      = Color(0xFF1A1040);
  static const Color cardBg2     = Color(0xFF1F1550);
  static const Color cyan        = Color(0xFF00E5FF);
  static const Color cyanDark    = Color(0xFF00B8D9);
  static const Color purple      = Color(0xFF7B2FBE);
  static const Color purpleLight = Color(0xFF9B4FDE);
  static const Color gold        = Color(0xFFD4A843);
  static const Color fieldBorder = Color(0xFF2D2060);
  static const Color white       = Color(0xFFFFFFFF);
  static const Color grey        = Color(0xFF8A8A9A);
  static const Color greyLight   = Color(0xFFB0B0C0);
  static const Color error       = Color(0xFFFF4D6D);
  static const Color success     = Color(0xFF00C896);
  static const Color divider     = Color(0xFF2A1F55);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [purple, cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [cardBg, cardBg2],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bgGradient = LinearGradient(
    colors: [darkBg, Color(0xFF1A1040)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static BoxDecoration get cardDecoration => BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fieldBorder, width: 1),
      );

  static BoxDecoration get glassDecoration => BoxDecoration(
        color: cardBg.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fieldBorder, width: 1),
      );
}
