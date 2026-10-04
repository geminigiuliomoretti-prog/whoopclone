import 'package:flutter/material.dart';

/// Whoop 5.0 Hex Color Palette & Design System Constants
class AppColors {
  // Main Theme Backgrounds
  static const Color background = Color(0xFF0E1116);
  static const Color surface = Color(0xFF1A1F26);
  static const Color surfaceLight = Color(0xFF1E1E1E);
  static const Color cardBorder = Color(0xFF262C36);

  // COLIRE PREDOMINANTE ACCENT WHOOP (Blu Chiaro)
  static const Color brandBlue = Color(0xFF00B0FF);      // Blu Chiaro Primario
  static const Color brandBlueLight = Color(0xFF40C4FF); // Blu Chiaro Soft / Highlight
  static const Color strainBlue = Color(0xFF00B0FF);     // Sforzo & Accenti generali
  static const Color sleepSlate = Color(0xFF7BA1BB);     // Slate neutral data

  // Core Metric Colors
  static const Color recoveryGreen = Color(0xFF00E676); // Solo per punteggi Recovery >= 67%
  static const Color recoveryYellow = Color(0xFFFFEA00); // Solo per punteggi Recovery 34-66%
  static const Color recoveryRed = Color(0xFFFF1744);    // Solo per punteggi Recovery 1-33%
  static const Color strainHigh = Color(0xFFFF3D00);     // Solo per Max Strain / Zone 5

  // Sleep & Fasi Sonno
  static const Color sleepPurple = Color(0xFF7C4DFF); // Sonno
  static const Color lightSleep = Color(0xFF40C4FF);  // Leggero
  static const Color remSleep = Color(0xFF00E5FF);    // REM

  // Stress Monitor
  static const Color stressLow = Color(0xFF00E676);    // Basso
  static const Color stressMedium = Color(0xFFFF9100); // Medio
  static const Color stressHigh = Color(0xFFFF1744);   // Alto

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9E9EA8);
  static const Color textMuted = Color(0xFF6C6C78);

  static Color getRecoveryColor(double recoveryPct) {
    if (recoveryPct >= 67) {
      return recoveryGreen;
    } else if (recoveryPct >= 34) {
      return recoveryYellow;
    } else {
      return recoveryRed;
    }
  }
}
