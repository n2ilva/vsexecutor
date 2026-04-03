import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Backgrounds
  static const Color background = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF12121A);
  static const Color surfaceLight = Color(0xFF1A1A2E);
  static const Color surfaceLighter = Color(0xFF222240);
  static const Color channelStrip = Color(0xFF151528);
  static const Color channelStripHover = Color(0xFF1A1A35);

  // Accent
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryLight = Color(0xFF8B7CF7);
  static const Color accent = Color(0xFF00D4FF);
  static const Color accentGlow = Color(0x3300D4FF);

  // Transport / State colors
  static const Color playGreen = Color(0xFF00FF87);
  static const Color stopRed = Color(0xFFFF4757);
  static const Color soloYellow = Color(0xFFFFD700);
  static const Color muteRed = Color(0xFFFF4444);
  static const Color recordRed = Color(0xFFFF3B30);

  // VU Meter gradient
  static const Color vuLow = Color(0xFF00FF87);
  static const Color vuMid = Color(0xFFFFD700);
  static const Color vuHigh = Color(0xFFFF4444);

  // Section marker colors
  static const List<Color> sectionColors = [
    Color(0xFF6C5CE7), // Purple
    Color(0xFF00D4FF), // Cyan
    Color(0xFFFF6B6B), // Coral
    Color(0xFF00FF87), // Green
    Color(0xFFFFD700), // Gold
    Color(0xFFFF8C00), // Orange
    Color(0xFFFF69B4), // Pink
    Color(0xFF00CED1), // Teal
  ];

  // Text
  static const Color textPrimary = Color(0xFFEAEAEA);
  static const Color textSecondary = Color(0xFF8892B0);
  static const Color textMuted = Color(0xFF5A6178);

  // Borders & Dividers
  static const Color border = Color(0xFF2A2A3E);
  static const Color divider = Color(0xFF1F1F35);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C5CE7), Color(0xFF00D4FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF0A0A0F), Color(0xFF12121A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient vuMeterGradient = LinearGradient(
    colors: [vuHigh, vuMid, vuLow],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
