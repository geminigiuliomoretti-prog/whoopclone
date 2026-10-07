import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/nature_theme.dart';

/// NatureTriRingDial — La Nuova Identità delle Tre Circonferenze
/// RECOVERY • SLEEP • STRAIN
/// Design proprietario: stroke morbido, sweep gradients organici, profondità sottile,
/// tipografia premium e micro-interazioni tattili.
class NatureTriRingDial extends StatefulWidget {
  final double strainScore; // 0.0 - 21.0
  final double recoveryPct; // 0 - 100%
  final double sleepPct;    // 0 - 100%
  final int liveBpm;
  final int calories;
  final bool isDark;
  final VoidCallback? onTapRecovery;
  final VoidCallback? onTapSleep;
  final VoidCallback? onTapStrain;

  const NatureTriRingDial({
    super.key,
    required this.strainScore,
    required this.recoveryPct,
    required this.sleepPct,
    this.liveBpm = 0,
    this.calories = 0,
    this.isDark = true,
    this.onTapRecovery,
    this.onTapSleep,
    this.onTapStrain,
  });

  @override
  State<NatureTriRingDial> createState() => _NatureTriRingDialState();
}

class _NatureTriRingDialState extends State<NatureTriRingDial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _curveAnim;

  int? _pressedIndex; // 0 = Sonno, 1 = Recupero, 2 = Sforzo

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _curveAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutQuart,
    );
    _animCtrl.forward();
  }

  @override
  void didUpdateWidget(NatureTriRingDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recoveryPct != widget.recoveryPct ||
        oldWidget.sleepPct != widget.sleepPct ||
        oldWidget.strainScore != widget.strainScore) {
      _animCtrl.reset();
      _animCtrl.forward();
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
      animation: _curveAnim,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth;
            // Calcolo proporzionale elegante con respiro (ridotto del 12-15%)
            final ringBaseSize = (maxW / 4.2).clamp(70.0, 88.0);
            final centerRingSize = ringBaseSize * 1.16;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 1. Circonferenza SONNO (Sinistra)
                      _buildOrganicRingItem(
                        index: 0,
                        title: 'SONNO',
                        valueString: widget.sleepPct > 0 ? '${widget.sleepPct.round()}%' : '--',
                        subtitle: _getSleepLabel(widget.sleepPct),
                        progress: widget.sleepPct > 0
                            ? (widget.sleepPct / 100.0).clamp(0.0, 1.0) * _curveAnim.value
                            : 0.0,
                        gradientColors: [
                          NatureColors.tealLight,
                          NatureColors.teal,
                          NatureColors.tealDark,
                        ],
                        trackColor: widget.isDark
                            ? NatureColors.pineTrack
                            : NatureColors.tealBackground,
                        size: ringBaseSize,
                        strokeWidth: 6.5,
                        fontSize: ringBaseSize * 0.23,
                        onTap: widget.onTapSleep,
                      ),

                      // 2. Circonferenza RECUPERO (Centro — Eroe con gerarchia dominante)
                      _buildOrganicRingItem(
                        index: 1,
                        title: 'RECUPERO',
                        valueString: widget.recoveryPct > 0 ? '${widget.recoveryPct.round()}%' : '--',
                        subtitle: _getRecoveryLabel(widget.recoveryPct),
                        progress: widget.recoveryPct > 0
                            ? (widget.recoveryPct / 100.0).clamp(0.0, 1.0) * _curveAnim.value
                            : 0.0,
                        gradientColors: _getRecoveryGradient(widget.recoveryPct),
                        trackColor: NatureColors.getRecoveryTrackColor(widget.recoveryPct, isDark: widget.isDark),
                        size: centerRingSize,
                        strokeWidth: 7.8,
                        fontSize: centerRingSize * 0.25,
                        isHero: true,
                        onTap: widget.onTapRecovery,
                      ),

                      // 3. Circonferenza SFORZO (Destra)
                      _buildOrganicRingItem(
                        index: 2,
                        title: 'SFORZO',
                        valueString: widget.strainScore > 0
                            ? widget.strainScore.toStringAsFixed(1).replaceAll('.', ',')
                            : '0,0',
                        subtitle: _getStrainLabel(widget.strainScore),
                        progress: widget.strainScore > 0
                            ? (widget.strainScore / 21.0).clamp(0.0, 1.0) * _curveAnim.value
                            : 0.0,
                        gradientColors: const [
                          NatureColors.amberWarm,
                          NatureColors.terracotta,
                          NatureColors.terracottaDark,
                        ],
                        trackColor: widget.isDark
                            ? NatureColors.terracottaTrack
                            : NatureColors.terracottaBackground,
                        size: ringBaseSize,
                        strokeWidth: 6.5,
                        fontSize: ringBaseSize * 0.23,
                        onTap: widget.onTapStrain,
                      ),
                    ],
                  ),
                ),

                // Live BPM Capsule (se il cinturino BLE sta campionando frequenza cardiaca)
                if (widget.liveBpm > 0) ...[
                  const SizedBox(height: 8),
                  _buildLiveBpmCapsule(),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildOrganicRingItem({
    required int index,
    required String title,
    required String valueString,
    required String subtitle,
    required double progress,
    required List<Color> gradientColors,
    required Color trackColor,
    required double size,
    required double strokeWidth,
    required double fontSize,
    bool isHero = false,
    VoidCallback? onTap,
  }) {
    final isPressed = _pressedIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressedIndex = index),
      onTapCancel: () => setState(() => _pressedIndex = null),
      onTapUp: (_) {
        setState(() => _pressedIndex = null);
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: AnimatedScale(
        scale: isPressed ? 0.95 : (isHero ? 1.02 : 1.0),
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Titolo Superiore Pulito & Senza Scatola Bordata
            Text(
              title,
              style: TextStyle(
                color: isHero
                    ? (widget.isDark ? NatureColors.textDarkPrimary : NatureColors.textLightPrimary)
                    : (widget.isDark ? NatureColors.textDarkMuted : NatureColors.textLightSecondary),
                fontSize: isHero ? 10.5 : 9.5,
                fontWeight: isHero ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),

            // Anello Organico CustomPaint
            SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size(size, size),
                    painter: _OrganicArcPainter(
                      progress: progress,
                      trackColor: trackColor,
                      gradientColors: gradientColors,
                      strokeWidth: strokeWidth,
                      isDark: widget.isDark,
                    ),
                  ),

                  // Valore Numerico Centrale & Etichetta
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        valueString,
                        style: TextStyle(
                          color: widget.isDark
                              ? NatureColors.textDarkPrimary
                              : NatureColors.textLightPrimary,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: widget.isDark
                                ? NatureColors.textDarkSecondary
                                : NatureColors.textLightSecondary,
                            fontSize: 9.0,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveBpmCapsule() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: (widget.isDark ? NatureColors.darkSurfaceRaised : NatureColors.offWhite),
        borderRadius: BorderRadius.circular(NatureRadius.pill),
        border: Border.all(
          color: NatureColors.powderBlue.withValues(alpha: 0.35),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: NatureColors.powderBlue.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: NatureColors.sage,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            '${widget.liveBpm} BPM LIVE',
            style: TextStyle(
              color: widget.isDark ? NatureColors.textDarkPrimary : NatureColors.textLightPrimary,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String _getRecoveryLabel(double recovery) {
    if (recovery <= 0) return '';
    if (recovery >= 67) return 'OTTIMO';
    if (recovery >= 34) return 'MODERATO';
    return 'BASSO';
  }

  String _getSleepLabel(double sleep) {
    if (sleep <= 0) return '';
    if (sleep >= 85) return 'OTTIMO';
    if (sleep >= 70) return 'BUONO';
    return 'MINIMO';
  }

  String _getStrainLabel(double strain) {
    if (strain <= 0) return '';
    if (strain >= 14.0) return 'ELEVATO';
    if (strain >= 10.0) return 'ATTIVO';
    return 'LEGGERO';
  }

  List<Color> _getRecoveryGradient(double recovery) {
    if (recovery >= 67) {
      return const [NatureColors.sageLight, NatureColors.sage, NatureColors.sageDark];
    } else if (recovery >= 34) {
      return const [Color(0xFFF2BE74), NatureColors.amberWarm, Color(0xFFC77F32)];
    } else {
      return const [NatureColors.coralLight, NatureColors.terracotta, NatureColors.terracottaDark];
    }
  }
}

/// Painter per l'Arco Organico con SweepGradient e Glow
class _OrganicArcPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final List<Color> gradientColors;
  final double strokeWidth;
  final bool isDark;

  _OrganicArcPainter({
    required this.progress,
    required this.trackColor,
    required this.gradientColors,
    required this.strokeWidth,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    if (radius <= 0) return;

    // 1. Traccia Circolare di Sfondo
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0.0) return;

    // 2. Arco di Progresso Attivo con SweepGradient
    const startAngle = -math.pi / 2;
    final sweepAngle = (2 * math.pi * progress).clamp(0.01, 2 * math.pi);

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Glow leggero sotto l'arco
    final glowPaint = Paint()
      ..color = gradientColors.first.withValues(alpha: isDark ? 0.22 : 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawArc(rect, startAngle, sweepAngle, false, glowPaint);

    // Arco principale
    final sweepGradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      colors: gradientColors,
      transform: const GradientRotation(-math.pi / 2),
    );

    final activePaint = Paint()
      ..shader = sweepGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweepAngle, false, activePaint);
  }

  @override
  bool shouldRepaint(covariant _OrganicArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.isDark != isDark;
  }
}
