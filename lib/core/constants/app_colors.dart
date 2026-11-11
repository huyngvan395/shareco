import 'package:flutter/material.dart';

const primaryOrange = Color(0xFFFFB347);

const primaryPink = Color(0xFFFF5FA2);

const primaryPurple = Color(0xFF9B5CFF);

const primaryBlue = Color(0xFF4A6CFF);

const secondaryGray = Color(0xFF808080);


const List<Color> brandGradient = [
  Color(0xFFFF2D55),
  Color(0xFFFF6B4A),
  Color(0xFF20D5EC),
  Color(0xFFFFC837),
];

abstract class AppColors {
  // Brand
  static const primary = Color(0xFFFF2D55);
  static const primarySoft = Color(0xFFFF5E7E);
  static const secondary = Color(0xFF20D5EC);
  static const accent = Color(0xFFEE1D52);
  static const indigo = Color(0xFF6366F1);
  static const gold = Color(0xFFFFC837);
  static const emerald = Color(0xFF10B981);

  // Unified Modern Dark Surfaces
  static const surfaceDark = Color(0xFF0B0D14);
  static const surfaceSheet = Color(0xFF131622);
  static const surfaceCard = Color(0xFF1B1F2E);
  static const surfaceElevated = Color(0xFF23283B);
  static const surfaceGlass = Color(0xA6131622);
  static const borderSubtle = Color(0x1FFFFFFF);
  static const borderHighlight = Color(0x3DFFFFFF);

  // Harmonized Brand Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF2D55), Color(0xFFFF5E62)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient shopGradient = LinearGradient(
    colors: [Color(0xFFFF7A18), Color(0xFFFF2D55)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient studioGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF20D5EC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient liveGradient = LinearGradient(
    colors: [Color(0xFFFF2D55), Color(0xFFFF6B4A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Backgrounds
  static const bgDark = Color(0xFF0B0D14);
  static const bgCard = Color(0xFF1B1F2E);
  static const bgInput = Color(0xFF1E2335);
  static const bgOverlay = Color(0x80000000);

  static const bgLight = Color(0xFFFFFFFF);


  // Text
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFE8E8E8);
  static const textMuted = Color(0xFF999999);
  static const textHint = Colors.white38;

  // UI Elements
  static const divider = Color(0xFF2A2A2A);
  static const border = Color(0xFF333333);
  static const iconMuted = Colors.white54;
  static const iconActive = Colors.white;

  // Actions
  static const like = Color(0xFFFF2D55);
  static const comment = Color(0xFF20D5EC);
  static const verified = Color(0xFF20D5EC);
  static const facebookLike = Color(0xFF4E9EF4);

  // Gradient
  static const gradientStart = Color(0xFF69C9D0);
  static const gradientEnd = Color(0xFFEE1D52);

  // Status
  static const success = Color(0xFF4CAF50);
  static const error = Color(0xFFFF5252);
  static const warning = Color(0xFFFFB300);

  static const Color chatBubbleMine = Color(0xFF007AFF); // Chat bubble for current user
  static const Color chatBubbleOther = Color(0xFF3A3A3C); // Chat bubble for other users
  static const Color textLight = Colors.white70; // Light text color
  static const Color textDark = Colors.black87; // Dark text color
}