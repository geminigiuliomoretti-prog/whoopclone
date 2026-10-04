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

  const StressWaveChart({
    super.key,
    required this.currentStress,
    this.peakStress = 2.6,
    this.peakTimeLabel = '16:45',
    this.lastUpdateTime,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeStr = lastUpdateTime ??
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final effectiveStress = currentStress > 0 ? currentStress : 0.8;

    String categoryText;
    Color categoryColor;
    if (effectiveStress < 1.0) {
      categoryText = 'BASSO';
      categoryColor = WhoopTheme.strainBlue;
    } else if (effectiveStress < 2.0) {
      categoryText = 'MEDIO';
      categoryColor = WhoopTheme.recoveryYellow;
    } else {
      categoryText = 'ELEVATO';
      categoryColor = WhoopTheme.recoveryRed;
    }

    final stressFormatted = effectiveStress.toStringAsFixed(1).replaceAll('.', ',');

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
              Text(
                'MONITORAGGIO DELLO STRESS',
                style: TextStyle(
                  color: WhoopTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              Icon(Icons.chevron_right, color: WhoopTheme.textSecondary, size: 20),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Subheader: Ultimo aggiornamento: 12:32     BASSO 0,8
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ultimo aggiornamento: $timeStr',
                style: const TextStyle(
                  color: WhoopTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
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

          // 3. Grafico 24h con Ipnogramma Notturno e Linea Tratteggiata Live
          SizedBox(
            height: 130,
            width: double.infinity,
            child: CustomPaint(
              painter: _WhoopStressChartPainter(
                currentStress: effectiveStress,
                currentTimeStr: timeStr,
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

  _WhoopStressChartPainter({
    required this.currentStress,
    required this.currentTimeStr,
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

    // 2. Zona Sonno ombreggiata in blu con icona Luna 🌙 (da ore 00:00 a ore 07:30 circa)
    final sleepWidth = chartRect.width * 0.42;
    final sleepRect = Rect.fromLTWH(
      chartRect.left,
      chartRect.top,
      sleepWidth,
      chartRect.height,
    );

    final sleepShadingPaint = Paint()
      ..color = const Color(0xFF2E4050).withOpacity(0.35)
      ..style = PaintingStyle.fill;
    canvas.drawRect(sleepRect, sleepShadingPaint);

    final sleepTopBorder = Paint()
      ..color = const Color(0xFF67AEE6).withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(chartRect.left, chartRect.top),
      Offset(chartRect.left + sleepWidth, chartRect.top),
      sleepTopBorder,
    );

    // Icona Luna sopra il sonno
    final moonPainter = TextPainter(
      text: const TextSpan(
        text: '🌙',
        style: TextStyle(fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    moonPainter.paint(
      canvas,
      Offset(chartRect.left + (sleepWidth / 2) - (moonPainter.width / 2), 0),
    );

    // 3. Generazione e Disegno della Curva Fisiologica dello Stress (Stile Whoop 5.0)
    // Finestra oraria coperta da 00:00 fino all'ora corrente (~0.75 della larghezza)
    final progressFraction = 0.88;
    final activeWidth = chartRect.width * progressFraction;

    final points = <Offset>[];
    const totalSteps = 45;

    // Generatore fisiologico coerente: basso durante il sonno, picchi dopo il risveglio
    for (int i = 0; i <= totalSteps; i++) {
      final frac = i / totalSteps;
      final x = chartRect.left + (frac * activeWidth);

      double val;
      if (frac < 0.45) {
        // Fase Sonno: oscillazioni minime attorno a 0.4 - 0.6
        val = 0.45 + (0.12 * sin(i * 1.2)) + (0.05 * cos(i * 2.5));
      } else if (frac < 0.55) {
        // Risveglio: transizione
        val = 0.55 + ((frac - 0.45) / 0.1) * 0.6 + (0.15 * sin(i * 1.5));
      } else {
        // Giorno: attività variabile
        final dayProgress = (frac - 0.55) / 0.45;
        val = 0.8 +
            (0.7 * sin(dayProgress * 4.0 * pi)) +
            (0.35 * cos(dayProgress * 8.0));
        val = val.clamp(0.3, 2.2);
      }

      // Ultimo punto agganciato esattamente al valore reale corrente
      if (i == totalSteps) {
        val = currentStress.clamp(0.1, 3.0);
      }

      final normalizedVal = (val / 3.0).clamp(0.0, 1.0);
      final y = chartRect.bottom - (normalizedVal * chartRect.height);
      points.add(Offset(x, y));
    }

    // Disegna la curva continua con bezier morbidi
    final curvePath = Path();
    curvePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      curvePath.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    curvePath.lineTo(points.last.dx, points.last.dy);

    final linePaint = Paint()
      ..color = const Color(0xFF00F19F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Gradiente della linea: blu nel sonno, teal/verde di giorno
    final lineShader = const LinearGradient(
      colors: [
        Color(0xFF40C4FF), // Blu sonno
        Color(0xFF00F19F), // Verde veglia/recupero
        Color(0xFF00F19F),
      ],
      stops: [0.0, 0.5, 1.0],
    ).createShader(chartRect);

    linePaint.shader = lineShader;
    canvas.drawPath(curvePath, linePaint);

    // 4. Linea tratteggiata verticale all'orario corrente con indicatore
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

    // Cerchietto bianco sul valore live corrente
    final dotPaintFill = Paint()..color = Colors.white;
    final dotPaintStroke = Paint()
      ..color = WhoopTheme.background
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(currentPos, 4.0, dotPaintFill);
    canvas.drawCircle(currentPos, 4.0, dotPaintStroke);

    // 5. Etichette X temporali: 00:43, 05:00, 09:00, orario corrente
    final xLabels = [
      {'time': '00:43', 'x': chartRect.left},
      {'time': '05:00', 'x': chartRect.left + (chartRect.width * 0.30)},
      {'time': '09:00', 'x': chartRect.left + (chartRect.width * 0.60)},
      {'time': currentTimeStr, 'x': currentPos.dx},
    ];

    for (final lbl in xLabels) {
      final timeStr = lbl['time'] as String;
      final xPos = lbl['x'] as double;

      final tp = TextPainter(
        text: TextSpan(
          text: timeStr,
          style: const TextStyle(
            color: WhoopTheme.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final renderX = (xPos - (tp.width / 2)).clamp(chartRect.left, size.width - tp.width);
      tp.paint(canvas, Offset(renderX, chartRect.bottom + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _WhoopStressChartPainter oldDelegate) {
    return oldDelegate.currentStress != currentStress ||
        oldDelegate.currentTimeStr != currentTimeStr;
  }
}
