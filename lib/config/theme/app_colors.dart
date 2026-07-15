import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Base ──────────────────────────────────────────────────────────────────
  static const Color lightBg     = Color(0xFFF8FAFC);  // sky white bg
  static const Color cardBg      = Color(0xFFFFFFFF);  // pure white card
  static const Color cardBg2     = Color(0xFFF1F5F9);  // subtle slate gray

  // ── Brand (Cool Palette) ──────────────────────────────────────────────────
  static const Color cyan        = Color(0xFF0EA5E9);  // Sky blue (primary)
  static const Color cyanDark    = Color(0xFF0284C7);  // Ocean blue
  static const Color purple      = Color(0xFF6366F1);  // Indigo
  static const Color purpleLight = Color(0xFF818CF8);  // Soft Indigo
  static const Color gold        = Color(0xFFF59E0B);  // Amber (Host)

  // ── Neutral ───────────────────────────────────────────────────────────────
  static const Color fieldBorder = Color(0xFFE2E8F0);  // Border for light bg
  static const Color glassBorder = Color(0x330EA5E9);  // 20% blue glass border
  static const Color white       = Color(0xFFFFFFFF);
  static const Color slate       = Color(0xFF1E293B);  // Primary text color
  static const Color grey        = Color(0xFF64748B);  // Secondary text color
  static const Color greyLight   = Color(0xFF94A3B8);
  static const Color divider     = Color(0xFFF1F5F9);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color error   = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);

  // ── Immersive room (dark "theater" mode) ─────────────────────────────────
  static const Color roomBgTop    = Color(0xFF0C0820);  // near-black indigo
  static const Color roomBgMid    = Color(0xFF160F38);  // deep violet
  static const Color roomBgBottom = Color(0xFF1E1147);  // purple
  static const Color roomGlass    = Color(0x14FFFFFF);  // 8% white surface
  static const Color roomGlassBorder = Color(0x1FFFFFFF); // 12% white hairline

  /// Diagonal dark gradient behind the whole room, Rave-style.
  static const LinearGradient roomGradient = LinearGradient(
    colors: [roomBgTop, roomBgMid, roomBgBottom],
    stops: [0.0, 0.55, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Gradients ─────────────────────────────────────────────────────────────

  /// Sky Blue → Indigo — Main cool gradient.
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [cyan, purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Frosty glass gradient for headers.
  static const LinearGradient glassGradient = LinearGradient(
    colors: [
      Color(0xB3FFFFFF), // 70% white
      Color(0x80F0F9FF), // 50% ice blue
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Decorations ───────────────────────────────────────────────────────────

  /// Premium Glossy Card: Soft shadow + White surface + subtle blue border.
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: fieldBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: cyan.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      );

  /// Glassmorphism Card.
  static BoxDecoration get glassDecoration => BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: glassBorder, width: 1.5),
      );

  /// Premium Glow decoration for highlighted items.
  static BoxDecoration glowDecoration({double radius = 24}) => BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: cyan.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: cyan.withValues(alpha: 0.12),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      );
}
