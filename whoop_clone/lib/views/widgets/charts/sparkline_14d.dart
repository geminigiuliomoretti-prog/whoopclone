import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/nature_theme.dart';

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
    this.primaryColor = NatureColors.tealLight,
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
              valueColor: AlwaysStoppedAnimation<Color>(NatureColors.secondaryText),
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
                    Icon(Icons.timeline, color: NatureColors.mutedText, size: 20),
                    SizedBox(height: 4),
                    Text(
                      'Nessun dato registrato per questa finestra temporale',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: NatureColors.mutedText, fontSize: 11),
                    ),
                  ],
                )
              : const Text('--', style: TextStyle(color: NatureColors.mutedText, fontSize: 11)),
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
            style: const TextStyle(color: NatureColors.secondaryText, fontSize: 11),
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
          dataPoints: dataPoints,
          minVal: effectiveMin,
          maxVal: effectiveMax,
          baselineValue: baselineValue,
          primaryColor: primaryColor,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double?> dataPoints;
  final double minVal;
  final double maxVal;
  final double? baselineValue;
  final Color primaryColor;

  _SparklinePainter({
    required this.dataPoints,
    required this.minVal,
    required this.maxVal,
    this.baselineValue,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final range = (maxVal - minVal) > 0 ? (maxVal - minVal) : 1.0;
    final stepX = size.width / (dataPoints.length - 1);

    // 1. Linea di Baseline (se presente)
    if (baselineValue != null) {
      final baseY = size.height - ((baselineValue! - minVal) / range) * (size.height - 10) - 5;
      final baselinePaint = Paint()
        ..color = NatureColors.borderSubtle
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      double startX = 0;
      const dashWidth = 4.0;
      const dashSpace = 3.0;
      while (startX < size.width) {
        canvas.drawLine(
          Offset(startX, baseY),
          Offset(startX + dashWidth, baseY),
          baselinePaint,
        );
        startX += dashWidth + dashSpace;
      }
    }

    // 2. Disegno Segmenti Sparkline (con gestione gap per valori nulli CHT-01)
    final strokePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final points = <Offset?>[];
    for (int i = 0; i < dataPoints.length; i++) {
      final v = dataPoints[i];
      if (v == null) {
        points.add(null);
      } else {
        final x = i * stepX;
        final y = size.height - ((v - minVal) / range) * (size.height - 10) - 5;
        points.add(Offset(x, y));
      }
    }

    // Disegna segmenti continui separando sui gap
    Path? currentPath;
    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      if (pt != null) {
        if (currentPath == null) {
          currentPath = Path()..moveTo(pt.dx, pt.dy);
        } else {
          currentPath.lineTo(pt.dx, pt.dy);
        }
      } else {
        if (currentPath != null) {
          canvas.drawPath(currentPath, strokePaint);
          currentPath = null;
        }
      }
    }
    if (currentPath != null) {
      canvas.drawPath(currentPath, strokePaint);
    }

    // 3. Disegno dell'ultimo punto registrato (punto attivo più recente)
    final lastValid = points.lastWhere((p) => p != null, orElse: () => null);
    if (lastValid != null) {
      canvas.drawCircle(lastValid, 4.0, Paint()..color = primaryColor);
      canvas.drawCircle(lastValid, 2.0, Paint()..color = NatureColors.surface);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.dataPoints != dataPoints ||
      oldDelegate.baselineValue != baselineValue ||
      oldDelegate.primaryColor != primaryColor;
}
