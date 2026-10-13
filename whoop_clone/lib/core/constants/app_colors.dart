import 'package:flutter/material.dart';
import '../theme/nature_theme.dart';

/// AppColors — Bridge per il Design System Globale "Deep Navy / Teal / Natural"
class AppColors {
  // Main Theme Backgrounds
  static const Color background = NatureColors.background;
  static const Color backgroundSecondary = NatureColors.secondaryBackground;
  static const Color surface = NatureColors.surface;
  static const Color surfaceLight = NatureColors.elevatedSurface;
  static const Color cardBorder = NatureColors.border;

  // Varianti Dark
  static const Color backgroundDark = NatureColors.background;
  static const Color surfaceDark = NatureColors.surface;
  static const Color cardBorderDark = NatureColors.border;

  // Accento Primario Sereno
  static const Color brandBlue = NatureColors.teal;
  static const Color brandBlueLight = NatureColors.tealLight;
  static const Color strainBlue = NatureColors.teal;
  static const Color sleepSlate = NatureColors.sleep;

  // Core Metric Colors
  static const Color recoveryGreen = NatureColors.recovery;
  static const Color recoveryYellow = NatureColors.amberWarm;
  static const Color recoveryRed = NatureColors.strain;
  static const Color strainHigh = NatureColors.strain;

  // Sleep & Fasi Sonno
  static const Color sleepPurple = NatureColors.lavender;
  static const Color lightSleep = NatureColors.sleepLight;
  static const Color remSleep = NatureColors.mistLight;

  // Stress Monitor (Scala Fluida Salvia / Ambra / Terracotta)
  static const Color stressLow = NatureColors.recovery;
  static const Color stressMedium = NatureColors.amberWarm;
  static const Color stressHigh = NatureColors.strain;

  // Text Colors
  static const Color textPrimary = NatureColors.textPrimary;
  static const Color textSecondary = NatureColors.textSecondary;
  static const Color textMuted = NatureColors.textMuted;

  static Color getRecoveryColor(double recoveryPct) {
    return NatureColors.getRecoveryColor(recoveryPct);
  }
}
