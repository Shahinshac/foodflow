import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors
  static const Color primary = Color(0xFFFF521B); // Vibrant Flame Orange
  static const Color primaryDark = Color(0xFFE03E0B);
  static const Color primaryLight = Color(0xFFFF7A4D);
  static const Color secondary = Color(0xFFFF9F1C); // Warm Amber
  static const Color accent = Color(0xFF2EC4B6); // Fresh Mint Teal

  // Semantic Colors
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF39C12);
  static const Color pending = Color(0xFFF39C12);
  static const Color error = Color(0xFFE74C3C);
  static const Color info = Color(0xFF3498DB);

  // Food specific
  static const Color veg = Color(0xFF27AE60);
  static const Color nonVeg = Color(0xFFE74C3C);
  static const Color starRating = Color(0xFFFFB800);

  // Reference UI Special Tokens
  static const Color darkAction = Color(0xFF16201B); // Dark charcoal/forest for primary buttons & active chips
  static const Color darkActionHover = Color(0xFF0F1713);
  static const Color sidebarDark = Color(0xFF13221C); // Deep forest dark sidebar
  static const Color sidebarDarkSurface = Color(0xFF1A2E26);
  static const Color creamBackground = Color(0xFFFBF9F5); // Warm cream off-white background
  static const Color chipBackground = Color(0xFFF3F4F6);

  // Light Theme Surfaces
  static const Color backgroundLight = Color(0xFFF8F9FD);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF191D23);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textMutedLight = Color(0xFF94A3B8);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color dividerLight = Color(0xFFF1F5F9);

  // Dark Theme Surfaces
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color cardDark = Color(0xFF1E293B);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textMutedDark = Color(0xFF64748B);
  static const Color borderDark = Color(0xFF334155);
  static const Color dividerDark = Color(0xFF1E293B);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF521B), Color(0xFFFF7A4D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warmHeroGradient = LinearGradient(
    colors: [Color(0xFFFF521B), Color(0xFFFF9F1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Shadows
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get primaryGlow => [
    BoxShadow(
      color: primary.withValues(alpha: 0.28),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}
