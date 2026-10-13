import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/nature_theme.dart';

/// Punto di telemetria cardiaca intraday con supporto per valori nulli (gap reale)
class HrDataPoint {
  final DateTime timestamp;
  final int? bpm;

  const HrDataPoint({
    required this.timestamp,
    required this.bpm,
  });

  bool get hasData => bpm != null && bpm! > 0;

  /// Converte i bucket SQL aggregati restituiti da `getIntradayHrBuckets` (CHT-02)
  static List<HrDataPoint> fromBuckets(List<Map<String, dynamic>?> buckets) {
    final List<HrDataPoint> list = [];
    for (final b in buckets) {
      if (b == null) continue;
      final ts = b['timestamp'] is DateTime
          ? b['timestamp'] as DateTime
          : DateTime.fromMillisecondsSinceEpoch(b['timestamp_utc_ms'] as int? ?? 0, isUtc: true).toLocal();
      final bpmVal = (b['avg'] as num?)?.toInt() ?? (b['bpm'] as num?)?.toInt();
      list.add(HrDataPoint(timestamp: ts, bpm: bpmVal));
    }
    return list;
  }
}

/// Grafico Curva Cardiaca Intraday 24h con gestione dei gap > 5 minuti e 4 stati espliciti (CHT-01..04)
class IntradayHrChart extends StatefulWidget {
  final List<HrDataPoint> points;
  final double height;
  final int? hrRestBaseline;
  final int? hrMaxBaseline;
  final bool isLoading;
  final Color? lineColor;

  const IntradayHrChart({
    super.key,
    required this.points,
    this.height = 180,
    this.hrRestBaseline = 55,
    this.hrMaxBaseline = 190,
    this.isLoading = false,
    this.lineColor,
  });

  @override
  State<IntradayHrChart> createState() => _IntradayHrChartState();
}

class _IntradayHrChartState extends State<IntradayHrChart> {
  HrDataPoint? _selectedPoint;

  @override
  Widget build(BuildContext context) {
    final effectiveLineColor = widget.lineColor ?? NatureColors.tealLight;

    // 1. Stato: Caricamento (spinner discreto) (CHT-03)
    if (widget.isLoading) {
      return Container(
        height: widget.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: NatureColors.surfaceHighlight.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NatureColors.borderSubtle),
        ),
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(NatureColors.secondaryText),
          ),
        ),
      );
    }

    final validPoints = widget.points.where((p) => p.hasData).toList();

    // 2. Stato: Vuoto / Nessun dato registrato (CHT-03)
    if (validPoints.isEmpty) {
      return Container(
        height: widget.height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: NatureColors.surfaceHighlight.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NatureColors.borderSubtle),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, color: NatureColors.mutedText, size: 24),
            SizedBox(height: 8),
            Text(
              'Nessun dato registrato per questa finestra temporale',
              textAlign: TextAlign.center,
              style: TextStyle(color: NatureColors.secondaryText, fontSize: 12),
            ),
          ],
        ),
      );
    }

    // 3. Rilevamento Buchi / Dati Parziali (gap > 5 minuti)
    bool hasGaps = false;
    for (int i = 1; i < validPoints.length; i++) {
      if (validPoints[i].timestamp.difference(validPoints[i - 1].timestamp).inMinutes > 5) {
        hasGaps = true;
        break;
      }
    }

    final bpms = validPoints.map((p) => p.bpm!).toList();
    final minBpm = bpms.reduce(math.min);
    final maxBpm = bpms.reduce(math.max);
    final avgBpm = (bpms.reduce((a, b) => a + b) / bpms.length).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasGaps) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 14, color: NatureColors.amberWarm),
                SizedBox(width: 5),
                Text(
                  'Dati parziali: rilevate interruzioni nel segnale (> 5 min)',
                  style: TextStyle(
                    color: NatureColors.amberWarm,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Area Tracciato con Gestione Touch
        GestureDetector(
          onTapDown: (details) => _selectPointAt(details.localPosition, validPoints),
          onHorizontalDragUpdate: (details) => _selectPointAt(details.localPosition, validPoints),
          onTapUp: (_) => _selectedBlockNull(),
          onHorizontalDragEnd: (_) => _selectedBlockNull(),
          child: Container(
            height: widget.height,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: NatureColors.surfaceHighlight.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: NatureColors.borderSubtle),
            ),
            child: Stack(
              children: [
                // Griglia e Linee di Baseline
                Positioned.fill(
                  child: CustomPaint(
                    painter: _IntradayGridPainter(
                      minBpm: minBpm,
                      maxBpm: maxBpm,
                      hrRestBaseline: widget.hrRestBaseline,
                    ),
                  ),
                ),

                // Tracciato Curva Cardiaca
                Positioned.fill(
                  child: CustomPaint(
                    painter: _IntradayHrPainter(
                      points: validPoints,
                      minBpm: minBpm,
                      maxBpm: maxBpm,
                      selectedPoint: _selectedPoint,
                      lineColor: effectiveLineColor,
                    ),
                  ),
                ),

                // Tooltip Fluttuante su Touch
                if (_selectedPoint != null)
                  Positioned(
                    top: 0,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: NatureColors.surface.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: effectiveLineColor.withValues(alpha: 0.5), width: 0.8),
                      ),
                      child: Text(
                        '${_selectedPoint!.bpm} bpm  •  ${_formatTime(_selectedPoint!.timestamp)}',
                        style: TextStyle(
                          color: effectiveLineColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Barra Statistiche in basso (Min, Media, Max, Baseline)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatBadge('MIN', '$minBpm BPM', NatureColors.secondaryText),
            _buildStatBadge('MEDIA', '$avgBpm BPM', NatureColors.primaryText),
            _buildStatBadge('MAX', '$maxBpm BPM', effectiveLineColor),
            if (widget.hrRestBaseline != null)
              _buildStatBadge('A RIPOSO', '${widget.hrRestBaseline} BPM', NatureColors.recoveryAccent),
          ],
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _selectedBlockNull() {
    setState(() => _selectedPoint = null);
  }

  void _selectPointAt(Offset pos, List<HrDataPoint> validPoints) {
    if (validPoints.isEmpty) return;
    final width = context.size?.width ?? 300.0;
    final ratio = (pos.dx / width).clamp(0.0, 1.0);
    final index = ((validPoints.length - 1) * ratio).round().clamp(0, validPoints.length - 1);

    setState(() {
      _selectedPoint = validPoints[index];
    });
  }

  Widget _buildStatBadge(String label, String val, Color color) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: NatureColors.mutedText,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
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
  final Color lineColor;

  _IntradayHrPainter({
    required this.points,
    required this.minBpm,
    required this.maxBpm,
    this.selectedPoint,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final bpmRange = (maxBpm - minBpm) > 0 ? (maxBpm - minBpm) : 100;

    if (points.length == 1) {
      final p = points.first;
      final yRatio = (p.bpm! - minBpm) / bpmRange;
      final y = size.height - (yRatio * (size.height - 20)) - 10;
      canvas.drawCircle(Offset(size.width / 2, y), 4, Paint()..color = lineColor);
      return;
    }

    final startTime = points.first.timestamp;
    final endTime = points.last.timestamp;
    final totalSpanMs = endTime.difference(startTime).inMilliseconds;
    final double safeSpanMs = totalSpanMs > 0 ? totalSpanMs.toDouble() : 1.0;

    Offset getPointOffset(HrDataPoint pt, int i) {
      final double x;
      if (totalSpanMs > 0) {
        final elapsed = pt.timestamp.difference(startTime).inMilliseconds;
        x = (elapsed / safeSpanMs) * size.width;
      } else {
        x = (i / (points.length - 1)) * size.width;
      }
      final yRatio = (pt.bpm! - minBpm) / bpmRange;
      final y = size.height - (yRatio * (size.height - 20)) - 10;
      return Offset(x.clamp(0.0, size.width), y.clamp(5.0, size.height - 5.0));
    }

    final strokePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        lineColor.withValues(alpha: 0.25),
        lineColor.withValues(alpha: 0.0),
      ],
    );

    final fillPaint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    List<Offset> currentSegment = [];

    void drawSegment(List<Offset> seg) {
      if (seg.isEmpty) return;
      if (seg.length == 1) {
        canvas.drawCircle(seg.first, 2.5, Paint()..color = lineColor);
        return;
      }

      final path = Path();
      final fillPath = Path();

      path.moveTo(seg.first.dx, seg.first.dy);
      fillPath.moveTo(seg.first.dx, size.height);
      fillPath.lineTo(seg.first.dx, seg.first.dy);

      for (int j = 1; j < seg.length; j++) {
        final p0 = seg[j - 1];
        final p1 = seg[j];
        final controlX = (p0.dx + p1.dx) / 2;
        path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
        fillPath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
      }

      fillPath.lineTo(seg.last.dx, size.height);
      fillPath.close();

      canvas.drawPath(fillPath, fillPaint);
      canvas.drawPath(path, strokePaint);
    }

    currentSegment.add(getPointOffset(points[0], 0));

    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final diffMinutes = curr.timestamp.difference(prev.timestamp).inMinutes;

      if (diffMinutes > 5) {
        drawSegment(currentSegment);
        currentSegment = [];
      }
      currentSegment.add(getPointOffset(curr, i));
    }
    drawSegment(currentSegment);

    if (selectedPoint != null && selectedPoint!.hasData) {
      final selectedIndex = points.indexOf(selectedPoint!);
      if (selectedIndex >= 0) {
        final ptOffset = getPointOffset(selectedPoint!, selectedIndex);
        canvas.drawCircle(ptOffset, 6, Paint()..color = Colors.white);
        canvas.drawCircle(ptOffset, 3, Paint()..color = lineColor);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IntradayHrPainter old) =>
      old.points != points || old.selectedPoint != selectedPoint || old.lineColor != lineColor;
}

class _IntradayGridPainter extends CustomPainter {
  final int minBpm;
  final int maxBpm;
  final int? hrRestBaseline;

  _IntradayGridPainter({
    required this.minBpm,
    required this.maxBpm,
    this.hrRestBaseline,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = NatureColors.borderSubtle.withValues(alpha: 0.5)
      ..strokeWidth = 0.8;

    canvas.drawLine(Offset(0, size.height * 0.25), Offset(size.width, size.height * 0.25), gridPaint);
    canvas.drawLine(Offset(0, size.height * 0.50), Offset(size.width, size.height * 0.50), gridPaint);
    canvas.drawLine(Offset(0, size.height * 0.75), Offset(size.width, size.height * 0.75), gridPaint);

    if (hrRestBaseline != null && hrRestBaseline! >= minBpm && hrRestBaseline! <= maxBpm) {
      final bpmRange = (maxBpm - minBpm) > 0 ? (maxBpm - minBpm) : 100;
      final yRatio = (hrRestBaseline! - minBpm) / bpmRange;
      final y = size.height - (yRatio * (size.height - 20)) - 10;

      final baselinePaint = Paint()
        ..color = NatureColors.recoveryAccent.withValues(alpha: 0.4)
        ..strokeWidth = 1.0;

      double startX = 0;
      const dashWidth = 4.0;
      const dashSpace = 3.0;
      while (startX < size.width) {
        canvas.drawLine(Offset(startX, y), Offset(startX + dashWidth, y), baselinePaint);
        startX += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
