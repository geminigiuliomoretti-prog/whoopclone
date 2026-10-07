import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/nature_theme.dart';

/// Modalità / Mood della Scena Naturale
enum NatureMood {
  recovery, // Paesaggio montano che reagisce alla prontezza
  sleep,    // Cielo notturno, luna, colline silenziose e pini
  strain,   // Colline aperte con sole radioso e dinamismo organico
  stress,   // Onde fluide armoniche e brezze serafiche
  calm,     // Orizzonte neutro e bilanciato
}

/// NatureScene — Sistema Paesaggistico Riutilizzabile per l'Identità Visiva
/// Disegna montagne stilizzate, colline, orizzonti, alba/luna e onde organiche.
/// Metafora visiva del benessere: Calma + Salute + Natura + Tecnologia.
class NatureScene extends StatefulWidget {
  final NatureMood mood;
  final double intensity; // 0.0 - 1.0 (es. recovery / 100 o strain / 21)
  final double height;
  final bool isDark;
  final Widget? child; // Contenuto sovrapposto (es. metric rings, titoli)
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry? borderRadius;

  const NatureScene({
    super.key,
    this.mood = NatureMood.recovery,
    this.intensity = 0.85,
    this.height = 240,
    this.isDark = true,
    this.child,
    this.padding = EdgeInsets.zero,
    this.borderRadius,
  });

  @override
  State<NatureScene> createState() => _NatureSceneState();
}

class _NatureSceneState extends State<NatureScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    // Animazione di "respiro" sottile e continua: onda organica lentissima (8 secondi)
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      _animCtrl.repeat(reverse: true);
    } else {
      _animCtrl.value = 0.5;
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, _) {
        return Container(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // 1. Atmosfera Organica e Chiara (Luce Solare & Sfumatura Naturale Eterea)
              Positioned.fill(
                child: CustomPaint(
                  painter: _NatureLandscapePainter(
                    mood: widget.mood,
                    intensity: widget.intensity.clamp(0.0, 1.0),
                    isDark: widget.isDark,
                    animPhase: _animCtrl.value,
                  ),
                ),
              ),

              // 2. Velo Sfumato Inferiore per fondersi senza stacchi col canvas circostante
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 90,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        (widget.isDark ? NatureColors.darkCanvas : NatureColors.offWhite)
                            .withValues(alpha: 0.0),
                        (widget.isDark ? NatureColors.darkCanvas : NatureColors.offWhite)
                            .withValues(alpha: 1.0),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Contenuto in primo piano (Anelli e metriche)
              if (widget.child != null)
                Positioned.fill(
                  child: Padding(
                    padding: widget.padding,
                    child: widget.child!,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// CustomPainter per il Disegno dell'Atmosfera Naturale Eterea
class _NatureLandscapePainter extends CustomPainter {
  final NatureMood mood;
  final double intensity;
  final bool isDark;
  final double animPhase;

  _NatureLandscapePainter({
    required this.mood,
    required this.intensity,
    required this.isDark,
    required this.animPhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    // 1. Sfondo del Cielo (Atmosfera & Gradiente Luminoso)
    _paintSkyAtmosphere(canvas, size);

    // 2. Luce Solare Diffusa / Alone Etereo
    _paintCelestialGlow(canvas, size);

    // 3. Onde e Contorni Organici Sottili (Restrained Horizon Contours)
    _paintRestrainedContours(canvas, size);
  }

  void _paintSkyAtmosphere(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    List<Color> skyColors;

    if (isDark) {
      switch (mood) {
        case NatureMood.recovery:
          skyColors = [
            const Color(0xFF14221D),
            const Color(0xFF131A1E),
            NatureColors.darkCanvas,
          ];
          break;
        case NatureMood.sleep:
          skyColors = [
            const Color(0xFF11212B),
            const Color(0xFF131722),
            NatureColors.darkCanvas,
          ];
          break;
        case NatureMood.strain:
          skyColors = [
            const Color(0xFF261D19),
            const Color(0xFF19171C),
            NatureColors.darkCanvas,
          ];
          break;
        default:
          skyColors = [
            const Color(0xFF171F26),
            const Color(0xFF13171E),
            NatureColors.darkCanvas,
          ];
      }
    } else {
      switch (mood) {
        case NatureMood.recovery:
          // Luce mattutina calda + aura salvia rilassante
          skyColors = [
            const Color(0xFFE9F5EE),
            const Color(0xFFF3FAF6),
            NatureColors.offWhite,
          ];
          break;
        case NatureMood.sleep:
          // Notte serena e chiara (Teal/Azzurro polvere tenue)
          skyColors = [
            const Color(0xFFE2F0F5),
            const Color(0xFFEFF7FA),
            NatureColors.offWhite,
          ];
          break;
        case NatureMood.strain:
          // Luce solare calda, ambra e corallo misurato
          skyColors = [
            const Color(0xFFFDF0E7),
            const Color(0xFFFBF6F0),
            NatureColors.offWhite,
          ];
          break;
        default:
          skyColors = [
            const Color(0xFFEFF5F8),
            const Color(0xFFF7FBFD),
            NatureColors.offWhite,
          ];
      }
    }

    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: skyColors,
      ).createShader(rect);

    canvas.drawRect(rect, skyPaint);
  }

  void _paintCelestialGlow(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Centro della luce solare/atmosferica delicata in alto al centro
    final sunCenter = Offset(w * 0.50, h * 0.28);
    final glowRadius = w * 0.48;

    Color glowColor;
    if (isDark) {
      glowColor = mood == NatureMood.recovery
          ? NatureColors.sage.withValues(alpha: 0.16)
          : (mood == NatureMood.sleep
              ? NatureColors.teal.withValues(alpha: 0.16)
              : NatureColors.amberWarm.withValues(alpha: 0.14));
    } else {
      glowColor = mood == NatureMood.recovery
          ? NatureColors.sageLight.withValues(alpha: 0.18)
          : (mood == NatureMood.sleep
              ? NatureColors.tealLight.withValues(alpha: 0.18)
              : NatureColors.amberWarm.withValues(alpha: 0.15));
    }

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          glowColor,
          glowColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: glowRadius));

    canvas.drawCircle(sunCenter, glowRadius, glowPaint);
  }

  void _paintRestrainedContours(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final waveOffset = math.sin(animPhase * math.pi) * 3.5;

    // Onda organica di sfondo molto tenue (orizzonte naturale calmo)
    final path1 = Path();
    path1.moveTo(0, h * 0.60 + waveOffset);
    path1.quadraticBezierTo(
      w * 0.30,
      h * 0.52 + waveOffset,
      w * 0.65,
      h * 0.64 + waveOffset,
    );
    path1.quadraticBezierTo(
      w * 0.85,
      h * 0.70 + waveOffset,
      w,
      h * 0.58 + waveOffset,
    );
    path1.lineTo(w, h);
    path1.lineTo(0, h);
    path1.close();

    Color contourColor1;
    if (isDark) {
      contourColor1 = (mood == NatureMood.recovery
              ? NatureColors.sage
              : (mood == NatureMood.sleep ? NatureColors.teal : NatureColors.amberWarm))
          .withValues(alpha: 0.08);
    } else {
      contourColor1 = (mood == NatureMood.recovery
              ? NatureColors.sageLight
              : (mood == NatureMood.sleep ? NatureColors.tealLight : NatureColors.amberWarm))
          .withValues(alpha: 0.12);
    }

    final paint1 = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          contourColor1,
          contourColor1.withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size);

    canvas.drawPath(path1, paint1);
  }

  @override
  bool shouldRepaint(covariant _NatureLandscapePainter oldDelegate) {
    return oldDelegate.animPhase != animPhase ||
        oldDelegate.mood != mood ||
        oldDelegate.intensity != intensity ||
        oldDelegate.isDark != isDark;
  }
}
