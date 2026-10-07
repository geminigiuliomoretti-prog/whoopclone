import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/whoop_theme.dart';

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

  const IntradayHrChart({
    super.key,
    required this.points,
    this.height = 180,
    this.hrRestBaseline = 55,
    this.hrMaxBaseline = 190,
    this.isLoading = false,
  });

  @override
  State<IntradayHrChart> createState() => _IntradayHrChartState();
}

class _IntradayHrChartState extends State<IntradayHrChart> {
  HrDataPoint? _selectedPoint;

  @override
  Widget build(BuildContext context) {
    // 1. Stato: Caricamento (spinner discreto) (CHT-03)
    if (widget.isLoading) {
      return Container(
        height: widget.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF141920),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: WhoopTheme.cardBorder),
        ),
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(WhoopTheme.textSecondary),
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
          color: const Color(0xFF141920),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: WhoopTheme.cardBorder),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, color: WhoopTheme.textMuted, size: 24),
            SizedBox(height: 8),
            Text(
              'Nessun dato registrato per questa finestra temporale',
              textAlign: TextAlign.center,
              style: TextStyle(color: WhoopTheme.textMuted, fontSize: 12),
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
            padding: EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFFF9F0A)),
                SizedBox(width: 5),
                Text(
                  'Dati parziali: rilevate interruzioni nel segnale (> 5 min)',
                  style: TextStyle(
                    color: Color(0xFFFF9F0A),
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],

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

        // Area Grafico CustomPaint con spezzamento esplicito delle linee (CHT-01)
        GestureDetector(
          onTapDown: (details) => _selectPointAt(details.localPosition, validPoints),
          onHorizontalDragUpdate: (details) => _selectPointAt(details.localPosition, validPoints),
          onTapUp: (_) => setState(() => _selectedPoint = null),
          onHorizontalDragEnd: (_) => setState(() => _selectedBlockNull()),
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
                points: validPoints,
                minBpm: math.min(minBpm, widget.hrRestBaseline ?? 50),
                maxBpm: math.max(maxBpm, widget.hrMaxBaseline ?? 180),
                selectedPoint: _selectedPoint,
              ),
            ),
          ),
        ),

        const SizedBox(height: 6),
        _buildTimeAxis(validPoints),
      ],
    );
  }

  Widget _buildTimeAxis(List<HrDataPoint> points) {
    if (points.isEmpty) return const SizedBox.shrink();
    final start = points.first.timestamp;
    final end = points.last.timestamp;
    final spanMs = end.difference(start).inMilliseconds;
    if (spanMs <= 0) {
      return Center(
        child: Text(_formatTime(start), style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 9)),
      );
    }

    final t1 = DateTime.fromMillisecondsSinceEpoch(start.millisecondsSinceEpoch + (spanMs * 0.25).round());
    final t2 = DateTime.fromMillisecondsSinceEpoch(start.millisecondsSinceEpoch + (spanMs * 0.50).round());
    final t3 = DateTime.fromMillisecondsSinceEpoch(start.millisecondsSinceEpoch + (spanMs * 0.75).round());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(_formatTime(start), style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 9)),
          Text(_formatTime(t1), style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 9)),
          Text(_formatTime(t2), style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 9)),
          Text(_formatTime(t3), style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 9)),
          Text(_formatTime(end), style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 9)),
        ],
      ),
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
            color: WhoopTheme.textSecondary,
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

  _IntradayHrPainter({
    required this.points,
    required this.minBpm,
    required this.maxBpm,
    this.selectedPoint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final bpmRange = (maxBpm - minBpm) > 0 ? (maxBpm - minBpm) : 100;

    // Se c'è solo un punto
    if (points.length == 1) {
      final p = points.first;
      final yRatio = (p.bpm! - minBpm) / bpmRange;
      final y = size.height - (yRatio * (size.height - 20)) - 10;
      canvas.drawCircle(Offset(size.width / 2, y), 4, Paint()..color = WhoopTheme.strainBlue);
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
      ..color = WhoopTheme.strainBlue
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

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

    // Spezzamento esplicito delle linee in presenza di gap > 5 minuti (CHT-01)
    List<Offset> currentSegment = [];

    void drawSegment(List<Offset> seg) {
      if (seg.isEmpty) return;
      if (seg.length == 1) {
        canvas.drawCircle(seg.first, 2.5, Paint()..color = WhoopTheme.strainBlue);
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
        // Gap > 5 minuti: spezza la linea senza interpolare
        drawSegment(currentSegment);
        currentSegment = [];
      }
      currentSegment.add(getPointOffset(curr, i));
    }
    drawSegment(currentSegment);

    // Evidenziazione punto selezionato su touch
    if (selectedPoint != null && selectedPoint!.hasData) {
      final selectedIndex = points.indexOf(selectedPoint!);
      if (selectedIndex >= 0) {
        final pos = getPointOffset(selectedPoint!, selectedIndex);

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
