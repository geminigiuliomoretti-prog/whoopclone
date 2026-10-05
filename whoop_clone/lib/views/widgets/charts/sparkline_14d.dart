import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/whoop_theme.dart';

/// Mini-grafico Sparkline a 14 Giorni per visualizzare i trend storici (Architettura NOOP, CHT-01..04)
/// Gestisce 4 stati espliciti: Caricamento, Vuoto, Dati parziali, Dati completi.
class Sparkline14d extends StatelessWidget {
  final List<double?> dataPoints; // fino a 14 valori (null se assenti)
  final double? baselineValue;
  final Color primaryColor;
  final double height;
  final double width;
  final String? label;
  final bool isLoading;

  const Sparkline14d({
    super.key,
    required this.dataPoints,
    this.baselineValue,
    this.primaryColor = WhoopTheme.recoveryGreen,
    this.height = 45,
    this.width = double.infinity,
    this.label,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Stato: Caricamento (spinner discreto) (CHT-03)
    if (isLoading) {
      return SizedBox(
        height: height,
        width: width,
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(WhoopTheme.textSecondary),
            ),
          ),
        ),
      );
    }

    final validValues = dataPoints.whereType<double>().toList();

    // 2. Stato: Vuoto / Nessun dato registrato (CHT-03)
    if (validValues.isEmpty) {
      return SizedBox(
        height: height,
        width: width,
        child: Center(
          child: height >= 60
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timeline, color: WhoopTheme.textMuted, size: 20),
                    SizedBox(height: 4),
                    Text(
                      'Nessun dato registrato per questa finestra temporale',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: WhoopTheme.textMuted, fontSize: 11),
                    ),
                  ],
                )
              : const Text('--', style: TextStyle(color: WhoopTheme.textMuted, fontSize: 11)),
        ),
      );
    }

    if (validValues.length == 1) {
      return SizedBox(
        height: height,
        width: width,
        child: Center(
          child: Text(
            '${validValues.first.toStringAsFixed(1)} (1 punto)',
            style: const TextStyle(color: WhoopTheme.textSecondary, fontSize: 11),
          ),
        ),
      );
    }

    final double minVal = validValues.reduce(math.min);
    final double maxVal = validValues.reduce(math.max);
    final double effectiveMin = math.min(minVal, baselineValue ?? minVal);
    final double effectiveMax = math.max(maxVal, baselineValue ?? maxVal);

    return SizedBox(
      height: height,
      width: width,
      child: CustomPaint(
        painter: _SparklinePainter(
          data: dataPoints,
          baseline: baselineValue,
          minVal: effectiveMin,
          maxVal: effectiveMax,
          color: primaryColor,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double?> data;
  final double? baseline;
  final double minVal;
  final double maxVal;
  final Color color;

  _SparklinePainter({
    required this.data,
    this.baseline,
    required this.minVal,
    required this.maxVal,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final range = (maxVal - minVal) > 0 ? (maxVal - minVal) : 1.0;
    final stepX = size.width / (data.length - 1 > 0 ? data.length - 1 : 1);

    // 1. Linea tratteggiata per la Baseline
    if (baseline != null) {
      final baselineY = size.height - (((baseline! - minVal) / range) * (size.height - 10)) - 5;
      final dashedPaint = Paint()
        ..color = WhoopTheme.textMuted.withValues(alpha: 0.4)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      double startX = 0;
      while (startX < size.width) {
        canvas.drawLine(
          Offset(startX, baselineY),
          Offset(startX + 4, baselineY),
          dashedPaint,
        );
        startX += 8;
      }
    }

    // 2. Tracciamento Path dei punti validi
    final path = Path();
    bool hasStarted = false;

    Offset? lastValidPoint;

    for (int i = 0; i < data.length; i++) {
      final val = data[i];
      if (val == null) continue;

      final x = i * stepX;
      final y = size.height - (((val - minVal) / range) * (size.height - 12)) - 6;
      final currentPoint = Offset(x, y.clamp(3.0, size.height - 3.0));

      if (!hasStarted) {
        path.moveTo(currentPoint.dx, currentPoint.dy);
        hasStarted = true;
      } else if (lastValidPoint != null) {
        final controlX = (lastValidPoint.dx + currentPoint.dx) / 2;
        path.cubicTo(controlX, lastValidPoint.dy, controlX, currentPoint.dy, currentPoint.dx, currentPoint.dy);
      }
      lastValidPoint = currentPoint;

      // Disegna un piccolo punto circolare
      final isLast = (i == data.length - 1);
      final pointPaint = Paint()
        ..color = isLast ? Colors.white : color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(currentPoint, isLast ? 3.5 : 2.0, pointPaint);
    }

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => true;
}
