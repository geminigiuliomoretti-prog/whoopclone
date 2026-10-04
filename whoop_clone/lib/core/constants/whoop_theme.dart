import 'package:flutter/material.dart';
import 'app_colors.dart';

/// WhoopTheme definisce la palette Hex e le specifiche visive UFFICIALI WHOOP
class WhoopTheme {
  // Canvas & Surfaces
  static const Color background = AppColors.background;
  static const Color cardSurface = AppColors.surface;
  static const Color surfaceRaised = AppColors.surfaceLight;
  static const Color surfaceOverlay = Color(0xFF283339);

  // Borders & Hairlines
  static const Color cardBorder = AppColors.cardBorder;
  static const Color hairlineStrong = Color(0xFF384750);

  // Official WHOOP Brand Colors
  static const Color brandBlack = Color(0xFF000000);
  static const Color brandWhite = Color(0xFFFFFFFF);
  static const Color brandTeal = Color(0xFF00F19F);
  static const Color strainBlue = AppColors.strainBlue;
  static const Color recoveryBlue = Color(0xFF67AEE6);
  static const Color sleepSlate = Color(0xFF7BA1BB);
  static const Color sleepPurple = Color(0xFF7C4DFF);
  static const Color lightSleep = Color(0xFF40C4FF);
  static const Color remSleep = Color(0xFF00E5FF);

  // Official Recovery Scale
  static const Color recoveryGreen = Color(0xFF00F19F);
  static const Color recoveryYellow = AppColors.recoveryYellow;
  static const Color recoveryRed = AppColors.recoveryRed;
  static const Color strainHigh = AppColors.strainHigh;

  // Stress Monitor Scale
  static const Color stressLow = Color(0xFF00B0FF);
  static const Color stressMedium = Color(0xFFFF9100);
  static const Color stressHigh = Color(0xFFFF1744);

  // Text Colors
  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color textMuted = AppColors.textMuted;

  // Logo Assets Paths
  static const String logoWhite = 'assets/logos/whoop_logo_white.png';
  static const String logoBlack = 'assets/logos/whoop_logo_black.png';
  static const String circleWhite = 'assets/logos/whoop_circle_white.png';
  static const String puckWhite = 'assets/logos/whoop_puck_white.png';

  static Color getRecoveryColor(double recoveryPct) {
    if (recoveryPct >= 67) {
      return recoveryGreen;
    } else if (recoveryPct >= 34) {
      return recoveryYellow;
    } else {
      return recoveryRed;
    }
  }

  static BoxDecoration officialCardDecoration({
    Color? tint,
    double borderRadius = 16.0,
    bool elevated = false,
  }) {
    return BoxDecoration(
      color: const Color(0xFF161D22),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: tint?.withValues(alpha: 0.45) ?? const Color(0xFF242E35),
        width: 1.0,
      ),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF1A2228),
          Color(0xFF12171B),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: elevated ? 0.45 : 0.25),
          blurRadius: elevated ? 12 : 8,
          offset: const Offset(0, 3),
        )
      ],
    );
  }

  static TextStyle cardTitleStyle({
    double fontSize = 11.0,
    Color color = textPrimary,
  }) {
    return TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.0,
    );
  }

  static TextStyle headlineStyle({
    double fontSize = 12.0,
    Color color = textSecondary,
  }) {
    return TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.8,
    );
  }

  static TextStyle metricNumberStyle({
    double fontSize = 24.0,
    Color color = textPrimary,
  }) {
    return TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        surface: cardSurface,
        primary: strainBlue,
        secondary: recoveryGreen,
        tertiary: brandTeal,
        onSurface: textPrimary,
      ),
      cardTheme: CardThemeData(
        color: cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}
