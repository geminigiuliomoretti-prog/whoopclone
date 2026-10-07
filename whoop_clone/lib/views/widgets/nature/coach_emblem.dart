import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/nature_theme.dart';

/// CoachEmblem — Simbolo di Guida Originale per WHOOP Coach AI
/// Rimpiazza completamente ogni riferimento a "W" o "\V/".
/// Concetto: Sun-Beacon / Guida Organica (Sole sferico + raggio-guida ascendente).
class CoachEmblem extends StatelessWidget {
  final double size;
  final Color? color;
  final bool animateGlow;

  const CoachEmblem({
    super.key,
    this.size = 24.0,
    this.color,
    this.animateGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? NatureColors.teal;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CoachEmblemPainter(
          color: effectiveColor,
        ),
      ),
    );
  }
}

class _CoachEmblemPainter extends CustomPainter {
  final Color color;

  _CoachEmblemPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = math.min(w, h) / 2;

    // 1. Nucleo Centrale (Sun Orb Core)
    final corePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.38, corePaint);

    // 2. Anello di Guida Organica (Beacon Orbit Wave)
    final arcPaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.22
      ..strokeCap = StrokeCap.round;

    final arcRect = Rect.fromCircle(center: center, radius: radius * 0.72);
    // Arco elegante ascendente (simbolo di crescita e orientamento)
    canvas.drawArc(arcRect, -math.pi * 0.85, math.pi * 1.3, false, arcPaint);

    // 3. Piccola stella/luce di beacon apicale
    final beaconPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final beaconPoint = Offset(
      center.dx + radius * 0.72 * math.cos(-math.pi * 0.85),
      center.dy + radius * 0.72 * math.sin(-math.pi * 0.85),
    );
    canvas.drawCircle(beaconPoint, radius * 0.16, beaconPaint);
  }

  @override
  bool shouldRepaint(covariant _CoachEmblemPainter oldDelegate) =>
      oldDelegate.color != color;
}
