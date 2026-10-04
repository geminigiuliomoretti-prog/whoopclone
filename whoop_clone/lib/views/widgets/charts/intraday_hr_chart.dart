import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/whoop_theme.dart';

/// Punto di telemetria cardiaca intraday
class HrDataPoint {
  final DateTime timestamp;
  final int bpm;

  const HrDataPoint({
    required this.timestamp,
    required this.bpm,
  });
}

/// Grafico Curva Cardiaca Intraday 24h con gradiente fluido (Architettura NOOP)
class IntradayHrChart extends StatefulWidget {
  final List<HrDataPoint> points;
  final double height;
  final int? hrRestBaseline;
  final int? hrMaxBaseline;

  const IntradayHrChart({
    super.key,
    required this.points,
    this.height = 180,
    this.hrRestBaseline = 55,
    this.hrMaxBaseline = 190,
  });

  @override
  State<IntradayHrChart> createState() => _IntradayHrChartState();
}

class _IntradayHrChartState extends State<IntradayHrChart> {
  HrDataPoint? _selectedPoint;

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return Container(
        height: widget.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF141920),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: WhoopTheme.cardBorder),
        ),
        child: const Text(
          'Nessun dato di frequenza cardiaca continuo',
          style: TextStyle(color: WhoopTheme.textMuted, fontSize: 12),
        ),
      );
    }

    final bpms = widget.points.map((p) => p.bpm).toList();
    final minBpm = bpms.reduce(math.min);
    final maxBpm = bpms.reduce(math.max);
    final avgBpm = (bpms.reduce((a, b) => a + b) / bpms.length).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header con Statistiche Rapide Min / Avg / Max
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatBadge('MIN', '$minBpm BPM', WhoopTheme.recoveryGreen),
            _buildStatBadge('MEDIA', '$avgBpm BPM', WhoopTheme.strainBlue),
            _buildStatBadge('MAX', '$maxBpm BPM', WhoopTheme.strainHigh),
          ],
        ),
        const SizedBox(height: 10),

        // Area Grafico CustomPaint
        GestureDetector(
          onTapDown: (details) => _selectPointAt(details.localPosition),
          onHorizontalDragUpdate: (details) => _selectPointAt(details.localPosition),
          onTapUp: (_) => setState(() => _selectedPoint = null),
          onHorizontalDragEnd: (_) => setState(() => _selectedPoint = null),
          child: Container(
            height: widget.height,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF141920),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: WhoopTheme.cardBorder),
            ),
            child: CustomPaint(
              painter: _IntradayHrPainter(
                points: widget.points,
                minBpm: math.min(minBpm, widget.hrRestBaseline ?? 50),
                maxBpm: math.max(maxBpm, widget.hrMaxBaseline ?? 180),
                selectedPoint: _selectedPoint,
              ),
            ),
          ),
        ),

        const SizedBox(height: 6),
        // Marcatori X-Axis (00:00 - 06:00 - 12:00 - 18:00 - 24:00)
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('00:00', style: TextStyle(color: WhoopTheme.textMuted, fontSize: 9)),
            Text('06:00', style: TextStyle(color: WhoopTheme.textMuted, fontSize: 9)),
            Text('12:00', style: TextStyle(color: WhoopTheme.textMuted, fontSize: 9)),
            Text('18:00', style: TextStyle(color: WhoopTheme.textMuted, fontSize: 9)),
            Text('24:00', style: TextStyle(color: WhoopTheme.textMuted, fontSize: 9)),
          ],
        ),
      ],
    );
  }

  void _selectPointAt(Offset pos) {
    if (widget.points.isEmpty) return;
    final width = context.size?.width ?? 300.0;
    final ratio = (pos.dx / width).clamp(0.0, 1.0);
    final index = ((widget.points.length - 1) * ratio).round();

    setState(() {
      _selectedPoint = widget.points[index];
    });
  }

  Widget _buildStatBadge(String label, String val, Color color) {
    return Row(
      children: [
        Text('$label: ', style: const TextStyle(color: WhoopTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
        Text(val, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _IntradayHrPainter extends CustomPainter {
  final List<HrDataPoint> points;
  final int minBpm;
  final int maxBpm;
  final HrDataPoint? selectedPoint;

  _IntradayHrPainter({
    required this.points,
    required this.minBpm,
    required this.maxBpm,
    this.selectedPoint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final bpmRange = (maxBpm - minBpm) > 0 ? (maxBpm - minBpm) : 100;
    final double stepX = size.width / (points.length - 1);

    final path = Path();
    final fillPath = Path();

    Offset getPointOffset(int i) {
      final x = i * stepX;
      final yRatio = (points[i].bpm - minBpm) / bpmRange;
      final y = size.height - (yRatio * (size.height - 20)) - 10;
      return Offset(x, y.clamp(5.0, size.height - 5.0));
    }

    final first = getPointOffset(0);
    path.moveTo(first.dx, first.dy);
    fillPath.moveTo(first.dx, size.height);
    fillPath.lineTo(first.dx, first.dy);

    for (int i = 1; i < points.length; i++) {
      final p0 = getPointOffset(i - 1);
      final p1 = getPointOffset(i);
      final controlX = (p0.dx + p1.dx) / 2;
      path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
      fillPath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Sfumatura gradiente verticale
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        WhoopTheme.strainBlue.withValues(alpha: 0.35),
        WhoopTheme.strainBlue.withValues(alpha: 0.0),
      ],
    );

    final fillPaint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Tracciato principale
    final strokePaint = Paint()
      ..color = WhoopTheme.strainBlue
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);

    // Evidenziazione punto selezionato su touch
    if (selectedPoint != null) {
      final selectedIndex = points.indexOf(selectedPoint!);
      if (selectedIndex >= 0) {
        final pos = getPointOffset(selectedIndex);

        final linePaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(pos.dx, 0), Offset(pos.dx, size.height), linePaint);

        final pointPaint = Paint()
          ..color = WhoopTheme.strainHigh
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, 5, pointPaint);
        canvas.drawCircle(pos, 8, Paint()..color = Colors.white.withValues(alpha: 0.3)..style = PaintingStyle.stroke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IntradayHrPainter oldDelegate) => true;
}
