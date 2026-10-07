import 'package:flutter/material.dart';
import '../../core/constants/whoop_theme.dart';
import '../../core/theme/nature_theme.dart';

/// Punto di campionamento dello stress diurno
class StressTimelineSample {
  final DateTime timestamp;
  final double stressScore; // 0.0 to 3.0
  final int bpm;
  final double hrvMs;

  const StressTimelineSample({
    required this.timestamp,
    required this.stressScore,
    required this.bpm,
    required this.hrvMs,
  });

  String get category {
    if (stressScore < 1.0) return 'Basso / Riposo';
    if (stressScore <= 2.0) return 'Medio';
    return 'Elevato';
  }

  Color get color {
    if (stressScore < 1.0) return NatureColors.sage;
    if (stressScore <= 2.0) return NatureColors.amber;
    return NatureColors.terracotta;
  }
}

/// Timeline Giornaliera dello Stress e Calcolo del Carico Autonomico (Architettura NOOP)
class StressTimelineView extends StatefulWidget {
  final List<StressTimelineSample> samples;
  final double currentStressScore;
  final double height;

  const StressTimelineView({
    super.key,
    required this.samples,
    required this.currentStressScore,
    this.height = 190,
  });

  @override
  State<StressTimelineView> createState() => _StressTimelineViewState();
}

class _StressTimelineViewState extends State<StressTimelineView> {
  StressTimelineSample? _selectedSample;

  @override
  Widget build(BuildContext context) {
    // Calcolo minuti totali trascorsi in stato di stress elevato (> 2.0)
    final highStressCount = widget.samples.where((s) => s.stressScore > 2.0).length;
    // Supponendo campionamenti periodici o minuti aggregati
    final int highStressMinutes = highStressCount > 0 ? highStressCount * 5 : 0;

    final lowStressCount = widget.samples.where((s) => s.stressScore < 1.0).length;
    final int lowStressMinutes = lowStressCount > 0 ? lowStressCount * 5 : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: NatureTheme.organicCardDecoration(elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Carico Autonomico
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TIMELINE STRESS DIURNO',
                style: TextStyle(
                  color: WhoopTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 13, color: NatureColors.terracotta),
                  const SizedBox(width: 4),
                  Text(
                    'Elevato: ${highStressMinutes}m',
                    style: const TextStyle(color: NatureColors.terracotta, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Area Grafica Timeline
          if (widget.samples.isEmpty)
            SizedBox(
              height: widget.height - 70,
              child: const Center(
                child: Text('Nessun dato di stress registrato per oggi', style: TextStyle(color: NatureColors.textMuted, fontSize: 11)),
              ),
            )
          else ...[
            GestureDetector(
              onTapDown: (details) => _selectSampleAt(details.localPosition),
              onHorizontalDragUpdate: (details) => _selectSampleAt(details.localPosition),
              onTapUp: (_) => setState(() => _selectedSample = null),
              onHorizontalDragEnd: (_) => setState(() => _selectedSample = null),
              child: SizedBox(
                height: widget.height - 70,
                width: double.infinity,
                child: CustomPaint(
                  painter: _StressTimelinePainter(
                    samples: widget.samples,
                    selectedSample: _selectedSample,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('06:00', style: TextStyle(color: NatureColors.textMuted, fontSize: 9)),
                Text('10:00', style: TextStyle(color: NatureColors.textMuted, fontSize: 9)),
                Text('14:00', style: TextStyle(color: NatureColors.textMuted, fontSize: 9)),
                Text('18:00', style: TextStyle(color: NatureColors.textMuted, fontSize: 9)),
                Text('22:00', style: TextStyle(color: NatureColors.textMuted, fontSize: 9)),
              ],
            ),
          ],

          const SizedBox(height: 12),
          // Riepilogo a 3 fasce
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildFasciaBadge('Riposo (0-1)', '${lowStressMinutes}m', NatureColors.sage),
              _buildFasciaBadge('Medio (1-2)', '${(widget.samples.length - highStressCount - lowStressCount).clamp(0, 999) * 5}m', NatureColors.amber),
              _buildFasciaBadge('Elevato (2-3)', '${highStressMinutes}m', NatureColors.terracotta),
            ],
          ),
        ],
      ),
    );
  }

  void _selectSampleAt(Offset pos) {
    if (widget.samples.isEmpty) return;
    final width = context.size?.width ?? 300.0;
    final ratio = (pos.dx / width).clamp(0.0, 1.0);
    final index = ((widget.samples.length - 1) * ratio).round();

    setState(() {
      _selectedSample = widget.samples[index];
    });
  }

  Widget _buildFasciaBadge(String label, String time, Color color) {
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text('$label: ', style: const TextStyle(color: NatureColors.textMuted, fontSize: 9.5)),
        Text(time, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _StressTimelinePainter extends CustomPainter {
  final List<StressTimelineSample> samples;
  final StressTimelineSample? selectedSample;

  _StressTimelinePainter({
    required this.samples,
    this.selectedSample,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;

    // Linee guida orizzontali (Soglia 1.0 e Soglia 2.0)
    final y1 = size.height - (1.0 / 3.0) * size.height;
    final y2 = size.height - (2.0 / 3.0) * size.height;

    final gridPaint = Paint()
      ..color = NatureColors.borderSubtle.withValues(alpha: 0.5)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, y1), Offset(size.width, y1), gridPaint);
    canvas.drawLine(Offset(0, y2), Offset(size.width, y2), gridPaint);

    final double stepX = size.width / (samples.length - 1 > 0 ? samples.length - 1 : 1);

    final path = Path();
    final fillPath = Path();

    Offset getOffset(int i) {
      final x = i * stepX;
      final y = size.height - ((samples[i].stressScore / 3.0) * (size.height - 10)) - 5;
      return Offset(x, y.clamp(3.0, size.height - 3.0));
    }

    final p0 = getOffset(0);
    path.moveTo(p0.dx, p0.dy);
    fillPath.moveTo(p0.dx, size.height);
    fillPath.lineTo(p0.dx, p0.dy);

    for (int i = 1; i < samples.length; i++) {
      final prev = getOffset(i - 1);
      final curr = getOffset(i);
      final midX = (prev.dx + curr.dx) / 2;
      path.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
      fillPath.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Sfumatura gradiente serena per lo stress (Lavender -> Sage)
    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        NatureColors.lavender.withValues(alpha: 0.30),
        NatureColors.amber.withValues(alpha: 0.12),
        NatureColors.sage.withValues(alpha: 0.0),
      ],
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Linea principale dello Stress in Lavender organico
    final strokePaint = Paint()
      ..color = NatureColors.lavender
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);

    // Indicatore selezione
    if (selectedSample != null) {
      final idx = samples.indexOf(selectedSample!);
      if (idx >= 0) {
        final pos = getOffset(idx);
        canvas.drawLine(
          Offset(pos.dx, 0),
          Offset(pos.dx, size.height),
          Paint()..color = Colors.white.withValues(alpha: 0.5)..strokeWidth = 1.0,
        );
        canvas.drawCircle(pos, 5.0, Paint()..color = selectedSample!.color..style = PaintingStyle.fill);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StressTimelinePainter oldDelegate) => true;
}
