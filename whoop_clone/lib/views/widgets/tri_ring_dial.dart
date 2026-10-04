import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/whoop_theme.dart';

/// Componente 3 Anelli Affiancati WHOOP 5.0 (Identico al 100% agli screenshot di reference_UI)
class TriRingDial extends StatefulWidget {
  final double strainScore; // 0.0 - 21.0
  final double recoveryPct; // 0 - 100%
  final double sleepPct; // 0 - 100%
  final int liveBpm;
  final int calories;
  final VoidCallback? onTapStrain;
  final VoidCallback? onTapRecovery;
  final VoidCallback? onTapSleep;

  const TriRingDial({
    super.key,
    required this.strainScore,
    required this.recoveryPct,
    required this.sleepPct,
    required this.liveBpm,
    required this.calories,
    this.onTapStrain,
    this.onTapRecovery,
    this.onTapSleep,
  });

  @override
  State<TriRingDial> createState() => _TriRingDialState();
}

class _TriRingDialState extends State<TriRingDial>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(TriRingDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.strainScore != widget.strainScore ||
        oldWidget.recoveryPct != widget.recoveryPct ||
        oldWidget.sleepPct != widget.sleepPct) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recoveryColor = WhoopTheme.getRecoveryColor(widget.recoveryPct);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Ring SONNO (Sinistra)
                  Expanded(
                    child: _buildSingleRingCard(
                      label: 'SONNO',
                      valueText: widget.sleepPct > 0 ? '${widget.sleepPct.toInt()}%' : '--',
                      ringColor: widget.sleepPct > 0 ? WhoopTheme.sleepSlate : WhoopTheme.textMuted,
                      trackColor: const Color(0xFF1E2830),
                      progressPct: widget.sleepPct > 0
                          ? (widget.sleepPct / 100.0).clamp(0.0, 1.0) * _animation.value
                          : 0.0,
                      size: 96,
                      strokeWidth: 8.5,
                      fontSize: 22,
                      onTap: widget.onTapSleep,
                    ),
                  ),

                  // 2. Ring RECUPERO (Centro - Prominente)
                  Expanded(
                    child: _buildSingleRingCard(
                      label: 'RECUPERO',
                      valueText: widget.recoveryPct > 0 ? '${widget.recoveryPct.toInt()}%' : '--',
                      ringColor: widget.recoveryPct > 0 ? recoveryColor : WhoopTheme.textMuted,
                      trackColor: widget.recoveryPct > 0 ? const Color(0xFF142B20) : const Color(0xFF1E2830),
                      progressPct: widget.recoveryPct > 0
                          ? (widget.recoveryPct / 100.0).clamp(0.0, 1.0) * _animation.value
                          : 0.0,
                      size: 104,
                      strokeWidth: 9.5,
                      fontSize: 26,
                      isHighlighted: true,
                      onTap: widget.onTapRecovery,
                    ),
                  ),

                  // 3. Ring SFORZO (Destra)
                  Expanded(
                    child: _buildSingleRingCard(
                      label: 'SFORZO',
                      valueText: widget.strainScore > 0
                          ? widget.strainScore.toStringAsFixed(1).replaceAll('.', ',')
                          : '0,0',
                      ringColor: widget.strainScore > 0 ? WhoopTheme.strainBlue : WhoopTheme.textMuted,
                      trackColor: const Color(0xFF162534),
                      progressPct: widget.strainScore > 0
                          ? (widget.strainScore / 21.0).clamp(0.0, 1.0) * _animation.value
                          : 0.0,
                      size: 96,
                      strokeWidth: 8.5,
                      fontSize: 22,
                      onTap: widget.onTapStrain,
                    ),
                  ),
                ],
              ),

              // Live BPM Pill (se sensore BLE collegato)
              if (widget.liveBpm > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141A20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: WhoopTheme.strainBlue.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: WhoopTheme.recoveryGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.liveBpm} BPM LIVE',
                        style: const TextStyle(
                          color: WhoopTheme.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSingleRingCard({
    required String label,
    required String valueText,
    required Color ringColor,
    required Color trackColor,
    required double progressPct,
    required double size,
    required double strokeWidth,
    required double fontSize,
    bool isHighlighted = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Ring Painter
              CustomPaint(
                size: Size(size, size),
                painter: _SingleRingPainter(
                  progressPct: progressPct,
                  ringColor: ringColor,
                  trackColor: trackColor,
                  strokeWidth: strokeWidth,
                ),
              ),

              // Center Value Stat
              Text(
                valueText,
                style: TextStyle(
                  color: WhoopTheme.textPrimary,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Label Below: SONNO > / RECUPERO > / SFORZO >
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isHighlighted ? WhoopTheme.textPrimary : WhoopTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                Icons.chevron_right,
                color: isHighlighted ? WhoopTheme.textPrimary : WhoopTheme.textSecondary,
                size: 14,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SingleRingPainter extends CustomPainter {
  final double progressPct;
  final Color ringColor;
  final Color trackColor;
  final double strokeWidth;

  _SingleRingPainter({
    required this.progressPct,
    required this.ringColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (strokeWidth / 2) - 2;
    const startAngle = -pi / 2; // Inizio ore 12

    // Background track ring
    final bgPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    // Foreground active arc
    if (progressPct > 0.0) {
      final fgPaint = Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * pi * progressPct;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SingleRingPainter oldDelegate) {
    return oldDelegate.progressPct != progressPct ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
