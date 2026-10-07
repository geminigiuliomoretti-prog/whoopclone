import 'package:flutter/material.dart';
import '../theme/nature_theme.dart';

/// Natural Hex Color Palette & Design System Constants
/// Serena, organica, data-driven.
class AppColors {
  // Main Theme Backgrounds (Luminosa identità Bright Nature)
  static const Color background = NatureColors.offWhite;
  static const Color surface = Colors.white;
  static const Color surfaceLight = NatureColors.creamLight;
  static const Color cardBorder = NatureColors.sandBorder;

  // Varianti Dark di riserva
  static const Color backgroundDark = NatureColors.darkCanvas;
  static const Color surfaceDark = NatureColors.darkSurface;
  static const Color cardBorderDark = NatureColors.darkBorder;

  // Accento Primario Sereno (Powder Blue & Alpine Mist)
  static const Color brandBlue = NatureColors.powderBlue;
  static const Color brandBlueLight = NatureColors.mist;
  static const Color strainBlue = NatureColors.powderBlue;
  static const Color sleepSlate = NatureColors.teal;

  // Core Metric Colors (Tonalità Naturali Morbide, Zero Neon)
  static const Color recoveryGreen = NatureColors.sage;
  static const Color recoveryYellow = NatureColors.amberWarm;
  static const Color recoveryRed = NatureColors.terracotta;
  static const Color strainHigh = NatureColors.terracotta;

  // Sleep & Fasi Sonno (Teal Sereno, Pino Notturno & Heather)
  static const Color sleepPurple = NatureColors.lavender;
  static const Color lightSleep = NatureColors.tealLight;
  static const Color remSleep = NatureColors.mist;

  // Stress Monitor (Scala Fluida Salvia / Ambra / Terracotta)
  static const Color stressLow = NatureColors.sage;
  static const Color stressMedium = NatureColors.amberWarm;
  static const Color stressHigh = NatureColors.terracotta;

  // Text Colors (Gerarchia di contrasto pulita e leggibile)
  static const Color textPrimary = NatureColors.textLightPrimary;
  static const Color textSecondary = NatureColors.textLightSecondary;
  static const Color textMuted = NatureColors.textLightMuted;

  static Color getRecoveryColor(double recoveryPct) {
    return NatureColors.getRecoveryColor(recoveryPct);
  }
}
