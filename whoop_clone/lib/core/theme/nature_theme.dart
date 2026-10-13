import 'dart:ui';
import 'package:flutter/material.dart';

/// TimeOfDayPeriod — Riconoscimento del Momento della Giornata per gli Asset Paesaggistici
enum TimeOfDayPeriod {
  morning,
  midday,
  afternoon,
  night;

  String get assetPath {
    switch (this) {
      case TimeOfDayPeriod.morning:
        return 'assets/images/nature/morning.jpg';
      case TimeOfDayPeriod.midday:
        return 'assets/images/nature/midday.jpg';
      case TimeOfDayPeriod.afternoon:
        return 'assets/images/nature/afternoon.jpg';
      case TimeOfDayPeriod.night:
        return 'assets/images/nature/night.jpg';
    }
  }

  String get label {
    switch (this) {
      case TimeOfDayPeriod.morning:
        return 'Mattina';
      case TimeOfDayPeriod.midday:
        return 'Mezzogiorno';
      case TimeOfDayPeriod.afternoon:
        return 'Pomeriggio';
      case TimeOfDayPeriod.night:
        return 'Notte';
    }
  }

  String get greeting {
    switch (this) {
      case TimeOfDayPeriod.morning:
        return 'Buongiorno';
      case TimeOfDayPeriod.midday:
        return 'Buon pomeriggio';
      case TimeOfDayPeriod.afternoon:
        return 'Buona sera';
      case TimeOfDayPeriod.night:
        return 'Buona notte';
    }
  }
}

/// Determina il periodo del giorno in base all'orario
TimeOfDayPeriod getTimeOfDayPeriod([DateTime? time]) {
  final now = time ?? DateTime.now();
  final hour = now.hour;
  if (hour >= 5 && hour < 12) {
    return TimeOfDayPeriod.morning;
  } else if (hour >= 12 && hour < 17) {
    return TimeOfDayPeriod.midday;
  } else if (hour >= 17 && hour < 21) {
    return TimeOfDayPeriod.afternoon;
  } else {
    return TimeOfDayPeriod.night;
  }
}

/// NatureColors — Sistema Globale di Colori
/// Fondazione: Deep Navy, Midnight Blue, Blue-Green, Deep Teal.
/// Supporto: Muted Natural Greens, Ring Colors, Calmi Accenti Caldi.
class NatureColors {
  const NatureColors._();

  // ── Global Foundation: Deep Navy, Midnight Blue, Deep Teal ───────────
  static const Color background = Color(0xFF090F17);            // Deep midnight navy canvas
  static const Color secondaryBackground = Color(0xFF0D1622);   // Secondary midnight
  static const Color backgroundSecondary = secondaryBackground;

  // Surfaces & Cards
  static const Color surface = Color(0xFF131F2E);               // Soft deep navy-teal surface
  static const Color elevatedSurface = Color(0xFF19293C);       // Raised card surface
  static const Color surfaceElevated = elevatedSurface;
  static const Color surfaceHighlight = Color(0xFF20334A);      // Active / focused surface
  static const Color translucentSurface = Color(0xDB131F2E);    // Frosted bottom bar & modals
  static const Color surfaceTranslucent = translucentSurface;

  // Aliases compatibilità superfici
  static const Color canvas = background;
  static const Color card = surface;
  static const Color cardElevated = elevatedSurface;
  static const Color darkCanvas = background;
  static const Color darkSurface = surface;
  static const Color darkSurfaceRaised = elevatedSurface;
  static const Color darkSurfaceHighlight = surfaceHighlight;
  static const Color darkCard = surfaceElevated;
  static const Color offWhite = background;                     // Reindirizzato per evitare canvas bianchi
  static const Color creamLight = surface;
  static const Color cream = elevatedSurface;
  static const Color creamDark = surfaceElevated;
  static const Color warmOatmeal = surfaceHighlight;
  static const Color sandPebble = border;

  // Borders & Hairlines
  static const Color border = Color(0xFF1D2E40);                // Mineral hairline border
  static const Color borderSubtle = Color(0xFF162536);          // Ultra-delicate divider
  static const Color sandBorder = border;                       // Alias
  static const Color sandBorderSubtle = borderSubtle;           // Alias
  static const Color darkBorder = border;                       // Alias
  static const Color darkBorderSubtle = borderSubtle;           // Alias

  // ── Core Accents: Deep Teal & Alpine Cyan ─────────────────────────────
  static const Color accent = Color(0xFF2A9E99);                // Deep teal
  static const Color teal = Color(0xFF2A9E99);
  static const Color tealLight = Color(0xFF56BFC4);
  static const Color tealDark = Color(0xFF1C6E6A);
  static const Color tealBackground = Color(0xFF11252D);

  // ── Health & Ring Accents: Muted Natural Greens (Recovery/Sage) ───────
  static const Color recoveryAccent = Color(0xFF38B27E);        // Muted natural emerald sage
  static const Color recovery = recoveryAccent;
  static const Color recoveryLight = Color(0xFF5DC293);
  static const Color recoveryDark = Color(0xFF247653);
  static const Color recoveryBackground = Color(0xFF10281E);
  static const Color recoveryTrack = Color(0xFF12241C);
  static const Color sage = recovery;                           // Alias
  static const Color sageLight = recoveryLight;                 // Alias
  static const Color sageDark = recoveryDark;                   // Alias
  static const Color sageBackground = recoveryBackground;       // Alias
  static const Color forestDeep = Color(0xFF1A3B2C);
  static const Color forestTrack = recoveryTrack;

  // ── Sleep & Nocturnal Physiology: Calm Twilight & Slate Cyan ─────────
  static const Color sleepAccent = Color(0xFF439EB8);           // Calm twilight cyan
  static const Color sleep = sleepAccent;
  static const Color sleepLight = Color(0xFF6AB6CC);
  static const Color sleepDark = Color(0xFF286D80);
  static const Color sleepBackground = Color(0xFF112530);
  static const Color sleepTrack = Color(0xFF142733);
  static const Color pineNight = Color(0xFF173540);
  static const Color pineTrack = sleepTrack;

  // ── Activity & Strain: Restrained Warm Terracotta / Sunrise Coral ─────
  static const Color strainAccent = Color(0xFFDF7B52);          // Restrained warm terracotta
  static const Color strain = strainAccent;
  static const Color strainLight = Color(0xFFEAA082);
  static const Color strainDark = Color(0xFFB55835);
  static const Color strainBackground = Color(0xFF301C15);
  static const Color strainTrack = Color(0xFF2E1C15);
  static const Color terracotta = strain;                       // Alias
  static const Color terracottaLight = strainLight;             // Alias
  static const Color terracottaDark = strainDark;               // Alias
  static const Color terracottaBackground = strainBackground;   // Alias
  static const Color coralLight = strainLight;                  // Alias
  static const Color terracottaTrack = strainTrack;

  // ── Restrained Warm Accents (Amber / Sunlight / Mid-Recovery) ─────────
  static const Color amberWarm = Color(0xFFD69E45);
  static const Color amber = amberWarm;
  static const Color amberLight = Color(0xFFE5B86F);
  static const Color amberBackground = Color(0xFF2B2011);
  static const Color amberTrack = Color(0xFF261D12);

  // ── Calm & Mental Recovery (Heather / Lavender Tenue) ─────────────────
  static const Color lavender = Color(0xFF9086B8);
  static const Color lavenderLight = Color(0xFFB3ABD0);
  static const Color lavenderDark = Color(0xFF6B6291);
  static const Color lavenderBackground = Color(0xFF1E1A2C);
  static const Color heatherTrack = Color(0xFF201B2E);

  // ── Atmosphere & Mist Accents ─────────────────────────────────────────
  static const Color mist = Color(0xFF86A3B8);
  static const Color mistLight = Color(0xFFA6BED0);
  static const Color powderBlue = Color(0xFF5D8EAA);
  static const Color alpineSky = Color(0xFF3D6B82);

  // ── Semantics ─────────────────────────────────────────────────────────
  static const Color success = recovery;
  static const Color warning = amberWarm;
  static const Color error = Color(0xFFD9534F);

  // ── Typography & Text Hierarchy ───────────────────────────────────────
  static const Color primaryText = Color(0xFFF1F5F9);           // Soft warm alabaster
  static const Color textPrimary = primaryText;
  static const Color secondaryText = Color(0xFF93A7BC);         // Cool slate blue
  static const Color textSecondary = secondaryText;
  static const Color mutedText = Color(0xFF5D7186);             // Calm twilight grey-blue
  static const Color textMuted = mutedText;

  // Aliases retrocompatibilità
  static const Color textLightPrimary = textPrimary;
  static const Color textLightSecondary = textSecondary;
  static const Color textLightMuted = textMuted;
  static const Color textDarkPrimary = textPrimary;
  static const Color textDarkSecondary = textSecondary;
  static const Color textDarkMuted = textMuted;

  // Recovery Aliases
  static const Color recoveryGreen = recovery;
  static const Color recoveryYellow = amberWarm;
  static const Color recoveryRed = strain;

  // Helper scale di recupero
  static Color getRecoveryColor(double recoveryPct) {
    if (recoveryPct >= 67) return recovery;
    if (recoveryPct >= 34) return amberWarm;
    return strain;
  }

  static Color getRecoveryTrackColor(double recoveryPct, {bool isDark = true}) {
    if (recoveryPct >= 67) return recoveryTrack;
    if (recoveryPct >= 34) return amberTrack;
    return strainTrack;
  }
}

/// Raggi di Arrotondamento Organici
class NatureRadius {
  const NatureRadius._();

  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 22.0;
  static const double xl = 28.0;
  static const double pill = 999.0;

  static BorderRadius get card => BorderRadius.circular(lg);
  static BorderRadius get capsule => BorderRadius.circular(pill);
  static BorderRadius get modalSheet => const BorderRadius.vertical(top: Radius.circular(28.0));
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

  static Color getRecoveryColor(double recoveryPct) => NatureColors.getRecoveryColor(recoveryPct);
  static Color getRecoveryTrackColor(double recoveryPct, {bool isDark = true}) =>
      NatureColors.getRecoveryTrackColor(recoveryPct, isDark: isDark);

  static BoxDecoration organicCardDecoration({
    bool isDark = true,
    Color? accentTint,
    double radius = NatureRadius.lg,
    bool elevated = false,
  }) {
    final bg = elevated ? NatureColors.elevatedSurface : NatureColors.surface;
    final borderColor = accentTint != null
        ? accentTint.withValues(alpha: 0.32)
        : NatureColors.border;

    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: 0.85),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: elevated ? 0.35 : 0.20),
          blurRadius: elevated ? 16 : 8,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  static BoxDecoration capsuleDecoration({
    bool isDark = true,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? NatureColors.surface,
      borderRadius: BorderRadius.circular(NatureRadius.pill),
      border: Border.all(
        color: borderColor ?? NatureColors.border,
        width: 0.85,
      ),
    );
  }

  // ── Typographic Hierarchy ─────────────────────────────────────────────
  static TextStyle displayScore({
    bool isDark = true,
    double fontSize = 38.0,
    Color? color,
  }) {
    return TextStyle(
      color: color ?? NatureColors.textPrimary,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.0,
      height: 1.05,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextStyle editorialHeadline({
    bool isDark = true,
    double fontSize = 22.0,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
  }) {
    return TextStyle(
      color: color ?? NatureColors.textPrimary,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: -0.4,
      height: 1.25,
    );
  }

  static TextStyle sectionTitle({
    bool isDark = true,
    double fontSize = 16.0,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
  }) {
    return TextStyle(
      color: color ?? NatureColors.textPrimary,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: -0.2,
      height: 1.2,
    );
  }

  static TextStyle heading({
    bool isDark = true,
    double fontSize = 19.0,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
  }) {
    return TextStyle(
      color: color ?? NatureColors.textPrimary,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: -0.3,
      height: 1.25,
    );
  }

  static TextStyle body({
    bool isDark = true,
    double fontSize = 14.0,
    Color? color,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    return TextStyle(
      color: color ?? NatureColors.textSecondary,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: 1.45,
    );
  }

  static TextStyle captionCaps({
    bool isDark = true,
    double fontSize = 10.5,
    Color? color,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    return TextStyle(
      color: color ?? NatureColors.textMuted,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: 1.1,
      height: 1.2,
    );
  }

  static TextStyle metricLabel({
    bool isDark = true,
    double fontSize = 12.0,
    Color? color,
  }) {
    return TextStyle(
      color: color ?? NatureColors.textSecondary,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
    );
  }

  // ── Global ThemeData ──────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: NatureColors.background,
      colorScheme: const ColorScheme.dark(
        surface: NatureColors.surface,
        primary: NatureColors.teal,
        secondary: NatureColors.recovery,
        tertiary: NatureColors.strain,
        onSurface: NatureColors.textPrimary,
        outline: NatureColors.border,
      ),
      cardTheme: CardThemeData(
        color: NatureColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NatureRadius.md),
          side: const BorderSide(color: NatureColors.border, width: 0.85),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: NatureColors.background,
        elevation: 0,
        centerTitle: true,
        foregroundColor: NatureColors.textPrimary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: NatureColors.elevatedSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NatureRadius.lg),
          side: const BorderSide(color: NatureColors.border, width: 0.85),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: NatureColors.elevatedSurface,
        modalBackgroundColor: NatureColors.elevatedSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.0)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: NatureColors.borderSubtle,
        thickness: 0.85,
      ),
    );
  }

  static ThemeData get lightTheme => darkTheme;
}
