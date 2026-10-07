import 'package:flutter/material.dart';

/// NatureTheme — Design System Centrale per la Nuova Identità Visiva
/// "Un compagno personale per la salute, immerso nella natura, costruito con tecnologia premium."
/// Calma + Salute + Natura + Tecnologia.
class NatureColors {
  const NatureColors._();

  // ── Recovery & Wellness (Verde Morbido & Salvia) ──────────────────────
  static const Color sageLight = Color(0xFF6FBD95);
  static const Color sage = Color(0xFF3EA572);
  static const Color sageDark = Color(0xFF2E8056);
  static const Color sageBackground = Color(0xFFEFF8F3);
  static const Color forestDeep = Color(0xFF23533B);
  static const Color forestTrack = Color(0xFF1B3327);

  // ── Sleep & Physiological Data (Teal Sereno & Pino Notturno) ──────────
  static const Color tealLight = Color(0xFF5AB6C4);
  static const Color teal = Color(0xFF2A8E9E);
  static const Color tealDark = Color(0xFF1E6F7C);
  static const Color tealBackground = Color(0xFFEFF8F9);
  static const Color pineNight = Color(0xFF163E45);
  static const Color pineTrack = Color(0xFF152A2E);

  // ── Calm & Background Accents (Powder Blue & Morning Mist) ─────────────
  static const Color mistLight = Color(0xFFE4F0F6);
  static const Color mist = Color(0xFFA5C8D8);
  static const Color powderBlue = Color(0xFF6DA4BC);
  static const Color alpineSky = Color(0xFF4C7B90);

  // ── Surfaces & Warm Tones (Cream / Alabaster / Warm Ivory) ────────────
  static const Color offWhite = Color(0xFFFAF8F5);
  static const Color creamLight = Color(0xFFF5F1E8);
  static const Color cream = Color(0xFFEDE8DD);
  static const Color warmOatmeal = Color(0xFFE5DFC7);
  static const Color sandBorder = Color(0xFFECE6DC);
  static const Color sandBorderSubtle = Color(0xFFF3EFE8);

  // ── Stress & Mental Recovery (Heather / Lavender Tenue) ────────────────
  static const Color lavenderLight = Color(0xFFCEC7E2);
  static const Color lavender = Color(0xFF988EC1);
  static const Color lavenderDark = Color(0xFF70649D);
  static const Color lavenderBackground = Color(0xFFF6F4FA);
  static const Color heatherTrack = Color(0xFF262138);

  // ── Activity & Strain (Warm Terracotta / Coral — Accento Misurato) ────
  static const Color coralLight = Color(0xFFEE9F88);
  static const Color terracotta = Color(0xFFD76F52);
  static const Color terracottaDark = Color(0xFFB5583C);
  static const Color terracottaBackground = Color(0xFFFDF3F0);
  static const Color amberWarm = Color(0xFFDFA048);
  static const Color amberBackground = Color(0xFFFDF8EE);
  static const Color terracottaTrack = Color(0xFF38231C);

  // ── Dark Canvas & Slate Surfaces (Charcoal Naturale — Mai Nero Puro) ───
  static const Color darkCanvas = Color(0xFF111519);
  static const Color darkSurface = Color(0xFF171E24);
  static const Color darkSurfaceRaised = Color(0xFF1E272F);
  static const Color darkSurfaceHighlight = Color(0xFF25313B);
  static const Color darkBorder = Color(0xFF28343F);
  static const Color darkBorderSubtle = Color(0xFF1F2932);

  // ── Text & Content Hierarchy ──────────────────────────────────────────
  // Light Mode (Default per Identità Bright Nature)
  static const Color textLightPrimary = Color(0xFF182228);
  static const Color textLightSecondary = Color(0xFF5A6872);
  static const Color textLightMuted = Color(0xFF93A0AA);
  // Dark Mode
  static const Color textDarkPrimary = Color(0xFFF5F7FA);
  static const Color textDarkSecondary = Color(0xFFA4B2C0);
  static const Color textDarkMuted = Color(0xFF6E7E8E);

  // ── Aliases Rapidi & Coerenti (Bright Nature — Light First) ─────────────
  static const Color canvas = offWhite;
  static const Color card = Colors.white;
  static const Color cardElevated = creamLight;
  static const Color creamDark = Color(0xFFE5DFC7);
  static const Color sandPebble = Color(0xFFDFD8CC);
  static const Color darkCard = darkSurfaceRaised;
  static const Color border = sandBorder;
  static const Color borderSubtle = sandBorderSubtle;
  static const Color amber = amberWarm;
  static const Color textPrimary = textLightPrimary;
  static const Color textSecondary = textLightSecondary;
  static const Color textMuted = textLightMuted;

  // ── Scale di Recupero Morbide (Senza Contrasti Violenti) ──────────────
  static Color getRecoveryColor(double recoveryPct) {
    if (recoveryPct >= 67) {
      return sage;
    } else if (recoveryPct >= 34) {
      return amberWarm;
    } else {
      return terracotta;
    }
  }

  static Color getRecoveryTrackColor(double recoveryPct, {bool isDark = false}) {
    if (isDark) {
      if (recoveryPct >= 67) return forestTrack;
      if (recoveryPct >= 34) return const Color(0xFF332717);
      return terracottaTrack;
    } else {
      if (recoveryPct >= 67) return const Color(0xFFDCF2E6);
      if (recoveryPct >= 34) return const Color(0xFFF9EEDD);
      return const Color(0xFFFBE4DD);
    }
  }
}

/// Raggi di Arrotondamento Organici
class NatureRadius {
  const NatureRadius._();

  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 18.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double pill = 999.0;

  static BorderRadius get card => BorderRadius.circular(lg);
  static BorderRadius get capsule => BorderRadius.circular(pill);
  static BorderRadius get modalSheet => const BorderRadius.vertical(top: Radius.circular(32.0));
}

/// Spaziature del Design System
class NatureSpacing {
  const NatureSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double hero = 40.0;
}

/// Decorazioni & Superfici Organiche
class NatureTheme {
  const NatureTheme._();

  static BoxDecoration organicCardDecoration({
    bool isDark = false,
    Color? accentTint,
    double radius = NatureRadius.lg,
    bool elevated = false,
  }) {
    final bg = isDark ? NatureColors.darkSurface : Colors.white;
    final borderColor = isDark
        ? (accentTint != null ? accentTint.withValues(alpha: 0.35) : NatureColors.darkBorder)
        : (accentTint != null ? accentTint.withValues(alpha: 0.20) : NatureColors.sandBorder);

    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: 0.9),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: elevated ? 0.35 : 0.15)
              : const Color(0xFF1E2832).withValues(alpha: elevated ? 0.06 : 0.03),
          blurRadius: elevated ? 16 : 8,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  static BoxDecoration capsuleDecoration({
    bool isDark = false,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? (isDark ? NatureColors.darkSurfaceRaised : NatureColors.creamLight),
      borderRadius: BorderRadius.circular(NatureRadius.pill),
      border: Border.all(
        color: borderColor ?? (isDark ? NatureColors.darkBorderSubtle : NatureColors.sandBorder),
        width: 1.0,
      ),
    );
  }

  // Typography Scale (Bright Nature: Default Light Mode)
  static TextStyle displayScore({
    bool isDark = false,
    double fontSize = 38.0,
    Color? color,
  }) {
    return TextStyle(
      color: color ?? (isDark ? NatureColors.textDarkPrimary : NatureColors.textLightPrimary),
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.0,
      height: 1.05,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextStyle editorialHeadline({
    bool isDark = false,
    double fontSize = 23.0,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
  }) {
    return TextStyle(
      color: color ?? (isDark ? NatureColors.textDarkPrimary : NatureColors.textLightPrimary),
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: -0.4,
      height: 1.25,
    );
  }

  static TextStyle sectionTitle({
    bool isDark = false,
    double fontSize = 16.5,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
  }) {
    return TextStyle(
      color: color ?? (isDark ? NatureColors.textDarkPrimary : NatureColors.textLightPrimary),
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: -0.2,
      height: 1.2,
    );
  }

  static TextStyle heading({
    bool isDark = false,
    double fontSize = 20.0,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
  }) {
    return TextStyle(
      color: color ?? (isDark ? NatureColors.textDarkPrimary : NatureColors.textLightPrimary),
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: -0.3,
      height: 1.25,
    );
  }

  static TextStyle body({
    bool isDark = false,
    double fontSize = 14.5,
    Color? color,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    return TextStyle(
      color: color ?? (isDark ? NatureColors.textDarkSecondary : NatureColors.textLightSecondary),
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: 1.45,
    );
  }

  static TextStyle captionCaps({
    bool isDark = false,
    double fontSize = 10.5,
    Color? color,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    return TextStyle(
      color: color ?? (isDark ? NatureColors.textDarkMuted : NatureColors.textLightMuted),
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: 1.1,
      height: 1.2,
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: NatureColors.offWhite,
      colorScheme: const ColorScheme.light(
        surface: Colors.white,
        primary: NatureColors.sage,
        secondary: NatureColors.teal,
        tertiary: NatureColors.terracotta,
        onSurface: NatureColors.textLightPrimary,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NatureRadius.md),
          side: const BorderSide(color: NatureColors.sandBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: NatureColors.offWhite,
        elevation: 0,
        centerTitle: true,
        foregroundColor: NatureColors.textLightPrimary,
      ),
      dividerTheme: const DividerThemeData(
        color: NatureColors.sandBorder,
        thickness: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: NatureColors.darkCanvas,
      colorScheme: const ColorScheme.dark(
        surface: NatureColors.darkSurface,
        primary: NatureColors.sage,
        secondary: NatureColors.teal,
        tertiary: NatureColors.terracotta,
        onSurface: NatureColors.textDarkPrimary,
      ),
      cardTheme: CardThemeData(
        color: NatureColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NatureRadius.md),
          side: const BorderSide(color: NatureColors.darkBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: NatureColors.darkCanvas,
        elevation: 0,
        centerTitle: true,
        foregroundColor: NatureColors.textDarkPrimary,
      ),
      dividerTheme: const DividerThemeData(
        color: NatureColors.darkBorderSubtle,
        thickness: 1,
      ),
    );
  }
}
