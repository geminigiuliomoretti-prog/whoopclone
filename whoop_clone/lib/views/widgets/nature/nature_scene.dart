import 'package:flutter/material.dart';
import '../../../core/theme/nature_theme.dart';
import '../../../core/utils/clock.dart';

/// Modalità / Mood della Scena Naturale
enum NatureMood {
  recovery,
  sleep,
  strain,
  stress,
  calm,
}

/// NatureScene — Sistema Atmosferico Paesaggistico Reale per la Home e le Sezioni Principali
///
/// Integra gli asset visuali atmosferici (sunrise per Recovery, nighttime per Sleep)
/// con dissolvenza progressiva multi-stop verso il canvas dark navy dell'applicazione.
class NatureScene extends StatelessWidget {
  final TimeOfDayPeriod? timePeriod;
  final NatureMood mood;
  final double intensity; // 0.0 - 1.0
  final double height;
  final bool isDark;
  final Widget? child; // Contenuto sovrapposto (es. 3 metric rings)
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry? borderRadius;

  const NatureScene({
    super.key,
    this.timePeriod,
    this.mood = NatureMood.recovery,
    this.intensity = 0.85,
    this.height = 300,
    this.isDark = true,
    this.child,
    this.padding = EdgeInsets.zero,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    // La Home e l'ambiente naturale montano utilizzano ESCLUSIVAMENTE
    // le 4 immagini realistiche montane basate sul momento della giornata (Time-of-day).
    // Le immagini stilizzate recovery_atmosphere e sleep_atmosphere sono
    // RISERVATE IN MODO ESCLUSIVO alle rispettive schermate modali (Recovery & Sleep).
    final currentPeriod = timePeriod ?? getTimeOfDayPeriod(appClock.now());
    final String assetPath = currentPeriod.assetPath;
    const Alignment imageAlignment = Alignment.topCenter;

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: NatureColors.background,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Asset Paesaggistico Atmosferico
          Image.asset(
            assetPath,
            fit: BoxFit.cover,
            alignment: imageAlignment,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF142232),
                      NatureColors.background,
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. Dissolvenza Atmosferica Multi-Stop Verticale
          // Transizione progressiva:
          // Montagna realistica -> Velo d'alta quota -> Dark Navy Canvas (#090F17)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    NatureColors.background.withValues(alpha: 0.20),
                    NatureColors.background.withValues(alpha: 0.05),
                    NatureColors.background.withValues(alpha: 0.38),
                    NatureColors.background.withValues(alpha: 0.82),
                    NatureColors.background,
                  ],
                  stops: const [0.0, 0.25, 0.58, 0.84, 1.0],
                ),
              ),
            ),
          ),

          // 3. Maschera Laterale Morbida (Zero bordi rigidi ai lati)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    NatureColors.background.withValues(alpha: 0.30),
                    Colors.transparent,
                    Colors.transparent,
                    NatureColors.background.withValues(alpha: 0.30),
                  ],
                  stops: const [0.0, 0.12, 0.88, 1.0],
                ),
              ),
            ),
          ),

          // 4. Bagliore Etereo dell'Anello Selezionato (Accento Misurato)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            height: 120,
            child: Center(
              child: Container(
                width: 220,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _getGlowColorForMood(mood).withValues(alpha: 0.22),
                      _getGlowColorForMood(mood).withValues(alpha: 0.0),
                    ],
                    radius: 0.8,
                  ),
                ),
              ),
            ),
          ),

          // 5. Contenuto in Primo Piano (Anelli metrici, titoli)
          if (child != null)
            Positioned.fill(
              child: Padding(
                padding: padding,
                child: child!,
              ),
            ),
        ],
      ),
    );
  }

  Color _getGlowColorForMood(NatureMood mood) {
    switch (mood) {
      case NatureMood.sleep:
        return NatureColors.tealLight;
      case NatureMood.recovery:
        return const Color(0xFFE29A56); // Sunrise glow
      case NatureMood.strain:
        return NatureColors.strainAccent;
      case NatureMood.stress:
        return NatureColors.lavender;
      case NatureMood.calm:
        return NatureColors.powderBlue;
    }
  }
}
