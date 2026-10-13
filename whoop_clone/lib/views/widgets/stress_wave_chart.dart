import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/whoop_theme.dart';

/// Card "MONITORAGGIO DELLO STRESS >" WHOOP 5.0
/// Riproduce fedelmente lo screenshot ufficiale "Home - Monitoraggio Stress e Grafico Sforzo-Recupero.jpeg"
class StressWaveChart extends StatelessWidget {
  final double currentStress; // 0.0 - 3.0
  final double peakStress; // 0.0 - 3.0
  final String peakTimeLabel;
  final String? lastUpdateTime;
  final List<dynamic>? stressSamples;

  const StressWaveChart({
    super.key,
    required this.currentStress,
    this.peakStress = 2.6,
    this.peakTimeLabel = '16:45',
    this.lastUpdateTime,
    this.stressSamples,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeStr = lastUpdateTime ??
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final hasStress = currentStress > 0;
    final String categoryText;
    final Color categoryColor;
    final String stressFormatted;

    if (!hasStress) {
      categoryText = 'IN ATTESA';
      categoryColor = WhoopTheme.textSecondary;
      stressFormatted = '--';
    } else if (currentStress < 1.0) {
      categoryText = 'BASSO';
      categoryColor = WhoopTheme.strainBlue;
      stressFormatted = currentStress.toStringAsFixed(1).replaceAll('.', ',');
    } else if (currentStress < 2.0) {
      categoryText = 'MEDIO';
      categoryColor = WhoopTheme.recoveryYellow;
      stressFormatted = currentStress.toStringAsFixed(1).replaceAll('.', ',');
    } else {
      categoryText = 'ELEVATO';
      categoryColor = WhoopTheme.recoveryRed;
      stressFormatted = currentStress.toStringAsFixed(1).replaceAll('.', ',');
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: WhoopTheme.officialCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: MONITORAGGIO DELLO STRESS >
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'MONITORAGGIO DELLO STRESS',
                  style: TextStyle(
                    color: WhoopTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: WhoopTheme.textSecondary, size: 20),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Subheader
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Ultimo aggiornamento: $timeStr',
                  style: const TextStyle(
                    color: WhoopTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    categoryText,
                    style: TextStyle(
                      color: categoryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    stressFormatted,
                    style: const TextStyle(
                      color: WhoopTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 3. Grafico Reale o Linea Neutra in Attesa
          SizedBox(
            height: 130,
            width: double.infinity,
            child: CustomPaint(
              painter: _WhoopStressChartPainter(
                currentStress: currentStress,
                currentTimeStr: timeStr,
                samples: stressSamples,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhoopStressChartPainter extends CustomPainter {
  final double currentStress;
  final String currentTimeStr;
  final List<dynamic>? samples;

  _WhoopStressChartPainter({
    required this.currentStress,
    required this.currentTimeStr,
    this.samples,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const yAxisWidth = 32.0;
    const xAxisHeight = 22.0;

    final chartRect = Rect.fromLTWH(
      yAxisWidth,
      12.0,
      size.width - yAxisWidth,
      size.height - xAxisHeight - 12.0,
    );

    // 1. Linee orizzontali di griglia e valori Y: 3,0 / 2,0 / 1,0 / 0,0
    final gridPaint = Paint()
      ..color = const Color(0xFF222B32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final yValues = ['3,0', '2,0', '1,0', '0,0'];
    for (int i = 0; i < 4; i++) {
      final y = chartRect.top + (i * (chartRect.height / 3.0));
      canvas.drawLine(Offset(chartRect.left, y), Offset(chartRect.right, y), gridPaint);

      final tp = TextPainter(
        text: TextSpan(
          text: yValues[i],
          style: const TextStyle(
            color: WhoopTheme.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y - (tp.height / 2)));
    }

    // Estrazione punti reali
    final realValues = <double>[];
    if (samples != null && samples!.isNotEmpty) {
      for (final s in samples!) {
        if (s is num) {
          realValues.add(s.toDouble());
        } else if (s is Map && s['valore_stress'] is num) {
          realValues.add((s['valore_stress'] as num).toDouble());
        }
      }
    }
    if (currentStress > 0 && (realValues.isEmpty || (realValues.last - currentStress).abs() > 0.01)) {
      realValues.add(currentStress);
    }

    // Se non ci sono campioni reali, disegna linea tratteggiata neutra con messaggio
    if (realValues.isEmpty) {
      final dashPaint = Paint()
        ..color = WhoopTheme.textSecondary.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      final midY = chartRect.top + (chartRect.height / 2);
      double curX = chartRect.left;
      const dashW = 6.0;
      const spaceW = 4.0;
      while (curX < chartRect.right) {
        canvas.drawLine(
          Offset(curX, midY),
          Offset(min(curX + dashW, chartRect.right), midY),
          dashPaint,
        );
        curX += dashW + spaceW;
      }

      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'In attesa di misurazioni stress',
          style: TextStyle(
            color: WhoopTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(
          chartRect.left + (chartRect.width - textPainter.width) / 2,
          midY - textPainter.height - 8,
        ),
      );
      return;
    }

    // Costruzione punti reali
    final points = <Offset>[];
    final stepX = realValues.length > 1
        ? chartRect.width / (realValues.length - 1)
        : chartRect.width;

    for (int i = 0; i < realValues.length; i++) {
      final val = realValues[i].clamp(0.0, 3.0);
      final x = realValues.length > 1
          ? chartRect.left + (i * stepX)
          : chartRect.left + chartRect.width * 0.8;
      final normalizedVal = (val / 3.0).clamp(0.0, 1.0);
      final y = chartRect.bottom - (normalizedVal * chartRect.height);
      points.add(Offset(x, y));
    }

    final curvePath = Path();
    curvePath.moveTo(points.first.dx, points.first.dy);
    if (points.length == 1) {
      curvePath.lineTo(points.first.dx, points.first.dy);
    } else {
      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
        curvePath.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
      }
      curvePath.lineTo(points.last.dx, points.last.dy);
    }

    final linePaint = Paint()
      ..color = const Color(0xFF00F19F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final lineShader = const LinearGradient(
      colors: [
        Color(0xFF40C4FF),
        Color(0xFF00F19F),
      ],
    ).createShader(chartRect);

    linePaint.shader = lineShader;
    canvas.drawPath(curvePath, linePaint);

    final currentPos = points.last;
    final dashedPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    double curY = chartRect.top;
    const dashHeight = 4.0;
    const dashSpace = 3.0;
    while (curY < chartRect.bottom) {
      canvas.drawLine(
        Offset(currentPos.dx, curY),
        Offset(currentPos.dx, min(curY + dashHeight, chartRect.bottom)),
        dashedPaint,
      );
      curY += dashHeight + dashSpace;
    }

    final dotPaintFill = Paint()..color = Colors.white;
    final dotPaintStroke = Paint()
      ..color = WhoopTheme.background
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(currentPos, 4.0, dotPaintFill);
    canvas.drawCircle(currentPos, 4.0, dotPaintStroke);

    final timePainter = TextPainter(
      text: TextSpan(
        text: currentTimeStr,
        style: const TextStyle(
          color: WhoopTheme.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final renderX = (currentPos.dx - (timePainter.width / 2)).clamp(chartRect.left, size.width - timePainter.width);
    timePainter.paint(canvas, Offset(renderX, chartRect.bottom + 6));
  }

  @override
  bool shouldRepaint(covariant _WhoopStressChartPainter oldDelegate) {
    return oldDelegate.currentStress != currentStress ||
        oldDelegate.currentTimeStr != currentTimeStr ||
        oldDelegate.samples != samples;
  }
}
