import 'package:flutter/material.dart';
import '../theme/nature_theme.dart';

/// WhoopTheme definisce le specifiche visive coerenti con la nuova identità "Deep Navy / Teal / Natural"
class WhoopTheme {
  // Canvas & Surfaces
  static const Color background = NatureColors.background;
  static const Color backgroundDark = NatureColors.background;
  static const Color cardSurface = NatureColors.surface;
  static const Color cardSurfaceDark = NatureColors.surface;
  static const Color surfaceRaised = NatureColors.elevatedSurface;
  static const Color surfaceOverlay = NatureColors.translucentSurface;

  // Borders & Hairlines
  static const Color cardBorder = NatureColors.border;
  static const Color cardBorderDark = NatureColors.border;
  static const Color hairlineStrong = NatureColors.border;

  // Core Brand Colors
  static const Color brandBlack = NatureColors.background;
  static const Color brandWhite = NatureColors.textPrimary;
  static const Color brandTeal = NatureColors.teal;
  static const Color strainBlue = NatureColors.teal;
  static const Color recoveryBlue = NatureColors.sleep;
  static const Color sleepSlate = NatureColors.sleep;
  static const Color sleepPurple = NatureColors.lavender;
  static const Color lightSleep = NatureColors.sleepLight;
  static const Color remSleep = NatureColors.mistLight;

  // Recovery Scale
  static const Color recoveryGreen = NatureColors.recovery;
  static const Color recoveryYellow = NatureColors.amberWarm;
  static const Color recoveryRed = NatureColors.strain;
  static const Color strainHigh = NatureColors.strain;

  // Stress Monitor Scale (Calm, analytical)
  static const Color stressLow = NatureColors.recovery;
  static const Color stressMedium = NatureColors.amberWarm;
  static const Color stressHigh = NatureColors.strain;

  // Text Colors
  static const Color textPrimary = NatureColors.textPrimary;
  static const Color textSecondary = NatureColors.textSecondary;
  static const Color textMuted = NatureColors.textMuted;

  // Logo Assets Paths
  static const String logoWhite = 'assets/logos/whoop_logo_white.png';
  static const String logoBlack = 'assets/logos/whoop_logo_black.png';
  static const String circleWhite = 'assets/logos/whoop_circle_white.png';
  static const String puckWhite = 'assets/logos/whoop_puck_white.png';

  static Color getRecoveryColor(double recoveryPct) {
    return NatureColors.getRecoveryColor(recoveryPct);
  }

  static BoxDecoration officialCardDecoration({
    Color? tint,
    double borderRadius = 20.0,
    bool elevated = false,
    bool isDark = true,
  }) {
    return NatureTheme.organicCardDecoration(
      isDark: isDark,
      accentTint: tint,
      radius: borderRadius,
      elevated: elevated,
    );
  }

  static TextStyle cardTitleStyle({
    double fontSize = 11.5,
    Color color = textSecondary,
  }) {
    return TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    );
  }

  static TextStyle headlineStyle({
    double fontSize = 13.0,
    Color color = textPrimary,
  }) {
    return TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    );
  }

  static TextStyle metricNumberStyle({
    double fontSize = 24.0,
    Color color = textPrimary,
  }) {
    return TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static ThemeData get lightTheme => NatureTheme.darkTheme;
  static ThemeData get darkTheme => NatureTheme.darkTheme;
}
