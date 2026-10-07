import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../theme/nature_theme.dart';

/// WhoopTheme definisce la palette Hex e le specifiche visive UFFICIALI WHOOP
class WhoopTheme {
  // Canvas & Surfaces
  static const Color background = AppColors.background;
  static const Color backgroundDark = AppColors.backgroundDark;
  static const Color cardSurface = AppColors.surface;
  static const Color cardSurfaceDark = AppColors.surfaceDark;
  static const Color surfaceRaised = AppColors.surfaceLight;
  static const Color surfaceOverlay = Color(0xFFEFE9DE);

  // Borders & Hairlines
  static const Color cardBorder = AppColors.cardBorder;
  static const Color cardBorderDark = AppColors.cardBorderDark;
  static const Color hairlineStrong = Color(0xFFC8BFB0);

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
    double borderRadius = 20.0,
    bool elevated = false,
    bool isDark = false,
  }) {
    if (isDark) {
      return BoxDecoration(
        color: const Color(0xFF161E24),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: tint?.withValues(alpha: 0.35) ?? const Color(0xFF26323D),
          width: 1.0,
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B242C),
            Color(0xFF141A20),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: elevated ? 0.30 : 0.15),
            blurRadius: elevated ? 16 : 8,
            offset: const Offset(0, 4),
          )
        ],
      );
    }
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: tint?.withValues(alpha: 0.25) ?? NatureColors.sandBorder,
        width: 0.85,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF1E2832).withValues(alpha: elevated ? 0.05 : 0.025),
          blurRadius: elevated ? 14 : 8,
          offset: const Offset(0, 3),
        ),
      ],
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

  static ThemeData get lightTheme => NatureTheme.lightTheme;

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: NatureColors.darkCanvas,
      colorScheme: const ColorScheme.dark(
        surface: NatureColors.darkSurface,
        primary: strainBlue,
        secondary: recoveryGreen,
        tertiary: brandTeal,
        onSurface: NatureColors.textDarkPrimary,
      ),
      cardTheme: CardThemeData(
        color: NatureColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: NatureColors.darkBorder, width: 0.85),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: NatureColors.darkCanvas,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}
