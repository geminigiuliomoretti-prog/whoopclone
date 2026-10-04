import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/whoop_theme.dart';
import '../../data/services/insight_engine.dart';

/// Schermata Dettaglio Recupero WHOOP 5.0 (Full Page)
/// Zero-Tolerance Mock Purge: Legge i dati calcolati matematicamente da SQLite (cicli_fisiologici)
class RecoveryDetailModal extends StatefulWidget {
  final double recoveryPct;
  final double hrvMs;
  final int fcrBpm;
  final double respRateRpm;
  final double spo2Pct;
  final double tempDeltaC;
  final double? hrvBaseline;
  final int? fcrBaseline;
  final double? respRateBaseline;
  final double? sleepPerformancePct;
  final double? sleepPerfBaseline;
  final List<dynamic>? historicalCicli;

  const RecoveryDetailModal({
    super.key,
    required this.recoveryPct,
    required this.hrvMs,
    required this.fcrBpm,
    required this.respRateRpm,
    required this.spo2Pct,
    required this.tempDeltaC,
    this.hrvBaseline,
    this.fcrBaseline,
    this.respRateBaseline,
    this.sleepPerformancePct,
    this.sleepPerfBaseline,
    this.historicalCicli,
  });

  static void show(
    BuildContext context, {
    required double recoveryPct,
    required double hrvMs,
    required int fcrBpm,
    required double respRateRpm,
    required double spo2Pct,
    required double tempDeltaC,
    double? hrvBaseline,
    int? fcrBaseline,
    double? respRateBaseline,
    double? sleepPerformancePct,
    double? sleepPerfBaseline,
    List<dynamic>? historicalCicli,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecoveryDetailModal(
          recoveryPct: recoveryPct,
          hrvMs: hrvMs,
          fcrBpm: fcrBpm,
          respRateRpm: respRateRpm,
          spo2Pct: spo2Pct,
          tempDeltaC: tempDeltaC,
          hrvBaseline: hrvBaseline,
          fcrBaseline: fcrBaseline,
          respRateBaseline: respRateBaseline,
          sleepPerformancePct: sleepPerformancePct,
          sleepPerfBaseline: sleepPerfBaseline,
          historicalCicli: historicalCicli,
        ),
      ),
    );
  }

  @override
  State<RecoveryDetailModal> createState() => _RecoveryDetailModalState();
}

class _RecoveryDetailModalState extends State<RecoveryDetailModal> {
  Color get _recoveryColor => widget.recoveryPct > 0
      ? WhoopTheme.getRecoveryColor(widget.recoveryPct)
      : WhoopTheme.textMuted;

  @override
  Widget build(BuildContext context) {
    final double? hrvBase = widget.hrvBaseline;
    final int? fcrBase = widget.fcrBaseline;
    final double? respBase = widget.respRateBaseline;
    final double? sleepPerf = widget.sleepPerformancePct;
    final double? sleepBase = widget.sleepPerfBaseline;

    final hasRecovery = widget.recoveryPct > 0;
    final hasHrv = widget.hrvMs > 0;
    final hasFcr = widget.fcrBpm > 0;
    final hasResp = widget.respRateRpm >= 7.0 && widget.respRateRpm <= 24.0;
    final hasSleepPerf = sleepPerf != null && sleepPerf > 0;

    // Generazione serie temporale reale ultimi 7 giorni
    final List<Map<String, dynamic>> last7DaysData = _buildLast7DaysSeries(widget.historicalCicli);

    return Scaffold(
      backgroundColor: WhoopTheme.background,
      appBar: AppBar(
        backgroundColor: WhoopTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'OGGI',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: WhoopTheme.textSecondary, size: 22),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),

            // 1. Grande Cerchio Recovery
            Center(
              child: SizedBox(
                width: 220,
                height: 220,
                child: CustomPaint(
                  painter: _RecoveryArcPainter(
                    percent: hasRecovery ? (widget.recoveryPct / 100.0) : 0.0,
                    color: _recoveryColor,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'WHOOP',
                          style: TextStyle(
                            color: WhoopTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasRecovery ? '${widget.recoveryPct.toInt()}%' : '--',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 54,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'RECUPERO',
                          style: TextStyle(
                            color: WhoopTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 2. Card 4 Sub-metriche Reali con Caret Notch
            Center(
              child: CustomPaint(
                size: const Size(14, 7),
                painter: const _TriangleCaretPainter(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: WhoopTheme.officialCardDecoration(),
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  children: [
                    _buildSubMetricRow(
                      icon: Icons.show_chart,
                      title: 'VARIABILITÀ DELLA FREQUENZA CARDIACA',
                      value: hasHrv ? '${widget.hrvMs.toInt()}' : '--',
                      baseline: hrvBase != null ? '${hrvBase.toInt()}' : '--',
                      isUp: hrvBase != null && widget.hrvMs >= hrvBase,
                    ),
                    const Divider(color: WhoopTheme.cardBorder, height: 22, thickness: 1),
                    _buildSubMetricRow(
                      icon: Icons.favorite_border,
                      title: 'FREQUENZA CARDIACA A RIPOSO',
                      value: hasFcr ? '${widget.fcrBpm}' : '--',
                      baseline: fcrBase != null ? '$fcrBase' : '--',
                      isUp: fcrBase != null && widget.fcrBpm <= fcrBase,
                      arrowColor: WhoopTheme.recoveryGreen,
                    ),
                    const Divider(color: WhoopTheme.cardBorder, height: 22, thickness: 1),
                    _buildSubMetricRow(
                      icon: Icons.air,
                      title: 'FREQUENZA RESPIRATORIA',
                      value: hasResp ? widget.respRateRpm.toStringAsFixed(1) : '--',
                      baseline: respBase != null ? respBase.toStringAsFixed(1) : '--',
                      isUp: respBase != null && widget.respRateRpm <= respBase + 0.5,
                      arrowColor: const Color(0xFFFF9800),
                    ),
                    const Divider(color: WhoopTheme.cardBorder, height: 22, thickness: 1),
                    _buildSubMetricRow(
                      icon: Icons.nightlight_round,
                      title: 'PRESTAZIONE DEL SONNO',
                      value: hasSleepPerf ? '${sleepPerf.toInt()}%' : '--',
                      baseline: sleepBase != null ? '${sleepBase.toInt()}%' : '--',
                      isUp: sleepBase != null && (sleepPerf ?? 0) >= sleepBase,
                    ),
                    const Divider(color: WhoopTheme.cardBorder, height: 20, thickness: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141920),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF222B34)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.arrow_drop_up, color: WhoopTheme.recoveryGreen, size: 15),
                                Icon(Icons.arrow_drop_down, color: Color(0xFFFF9800), size: 15),
                                SizedBox(width: 6),
                                Text(
                                  'Oggi vs. 30 giorni precedenti',
                                  style: TextStyle(
                                    color: WhoopTheme.textMuted,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 3. Card Valutazione Fisiologica VFC Dinamica
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: WhoopTheme.officialCardDecoration(tint: WhoopTheme.recoveryGreen),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      InsightEngine.generateHrvInsight(
                        hrvSws: hasHrv ? widget.hrvMs : null,
                        hrvBaseline: hrvBase,
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {},
                      child: const Text(
                        'ESPLORA I TUOI APPROFONDIMENTI SUL RECUPERO',
                        style: TextStyle(
                          color: WhoopTheme.strainBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 5. Titolo Tendenze settimanali
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Tendenze settimanali',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 14),

            // 6. Grafico RECUPERO (%) settimanale
            _buildWeeklyRecoveryBarCard(
              title: 'RECUPERO',
              days: last7DaysData.map((d) => d['label'] as String).toList(),
              values: last7DaysData.map((d) => (d['rec'] as num).toInt()).toList(),
              activeIdx: last7DaysData.length - 1,
            ),

            const SizedBox(height: 16),

            // 7. Grafico VARIABILITÀ DELLA FREQUENZA CARDIACA
            _buildWeeklyLineCard(
              title: 'VARIABILITÀ DELLA FREQUENZA CARDIACA',
              days: last7DaysData.map((d) => d['label'] as String).toList(),
              values: last7DaysData.map((d) => (d['hrv'] as num).toInt()).toList(),
              activeIdx: last7DaysData.length - 1,
            ),

            const SizedBox(height: 16),

            // 8. Grafico FREQUENZA CARDIACA A RIPOSO
            _buildWeeklyLineCard(
              title: 'FREQUENZA CARDIACA A RIPOSO',
              days: last7DaysData.map((d) => d['label'] as String).toList(),
              values: last7DaysData.map((d) => (d['rhr'] as num).toInt()).toList(),
              activeIdx: last7DaysData.length - 1,
            ),

            const SizedBox(height: 16),

            // 9. Grafico FREQUENZA RESPIRATORIA
            _buildWeeklyLineCardDouble(
              title: 'FREQUENZA RESPIRATORIA',
              days: last7DaysData.map((d) => d['label'] as String).toList(),
              values: last7DaysData.map((d) => (d['resp'] as num).toDouble()).toList(),
              activeIdx: last7DaysData.length - 1,
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _buildLast7DaysSeries(List<dynamic>? historical) {
    final now = DateTime.now();
    final List<Map<String, dynamic>> series = [];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateIso = date.toIso8601String().substring(0, 10);
      final weekdayStr = _weekdayShort(date.weekday);
      final dayNum = date.day;

      dynamic matchingCiclo;
      if (historical != null) {
        for (final c in historical) {
          if (c.dataIso == dateIso) {
            matchingCiclo = c;
            break;
          }
        }
      }

      final rec = (matchingCiclo?.punteggioRecuperoPct as num?)?.toInt() ?? (i == 0 && widget.recoveryPct > 0 ? widget.recoveryPct.toInt() : 0);
      final hrv = (matchingCiclo?.vfcMs as num?)?.toInt() ?? (i == 0 && widget.hrvMs > 0 ? widget.hrvMs.toInt() : 0);
      final rhr = (matchingCiclo?.fcrBpm as num?)?.toInt() ?? (i == 0 && widget.fcrBpm > 0 ? widget.fcrBpm : 0);
      final resp = (matchingCiclo?.frequenzaRespiratoriaRpm as num?)?.toDouble() ?? (i == 0 && widget.respRateRpm > 0 ? widget.respRateRpm : 0.0);

      series.add({
        'label': '$weekdayStr $dayNum',
        'rec': rec,
        'hrv': hrv,
        'rhr': rhr,
        'resp': resp,
      });
    }

    return series;
  }

  String _weekdayShort(int weekday) {
    switch (weekday) {
      case 1:
        return 'lun';
      case 2:
        return 'mar';
      case 3:
        return 'mer';
      case 4:
        return 'gio';
      case 5:
        return 'ven';
      case 6:
        return 'sab';
      case 7:
        return 'dom';
      default:
        return '';
    }
  }

  Widget _buildSubMetricRow({
    required IconData icon,
    required String title,
    required String value,
    required String baseline,
    required bool isUp,
    Color? arrowColor,
  }) {
    final effectiveArrowColor = arrowColor ?? (isUp ? WhoopTheme.recoveryGreen : WhoopTheme.recoveryRed);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(icon, color: WhoopTheme.textSecondary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    color: effectiveArrowColor,
                    size: 16,
                  ),
                ],
              ),
              Text(
                baseline,
                style: const TextStyle(
                  color: WhoopTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyRecoveryBarCard({
    required String title,
    required List<String> days,
    required List<int> values,
    required int activeIdx,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: WhoopTheme.officialCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: WhoopTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                const Icon(Icons.chevron_right, color: WhoopTheme.textSecondary, size: 20),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(days.length, (i) {
                  final isActive = i == activeIdx;
                  final val = values[i];
                  final color = val > 0 ? WhoopTheme.getRecoveryColor(val.toDouble()) : WhoopTheme.cardBorder;

                  return Container(
                    padding: isActive ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4) : null,
                    decoration: isActive ? BoxDecoration(color: WhoopTheme.cardSurface, borderRadius: BorderRadius.circular(8)) : null,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(val > 0 ? '$val%' : '--', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Container(
                          width: 24,
                          height: val > 0 ? (90 * (val / 100.0)) : 4.0,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(days[i].split(' ')[0], style: TextStyle(color: isActive ? Colors.white : WhoopTheme.textMuted, fontSize: 10)),
                        Text(days[i].split(' ')[1], style: TextStyle(color: isActive ? Colors.white : WhoopTheme.textMuted, fontSize: 10, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyLineCard({
    required String title,
    required List<String> days,
    required List<int> values,
    required int activeIdx,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: WhoopTheme.officialCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: WhoopTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                const Icon(Icons.chevron_right, color: WhoopTheme.textSecondary, size: 20),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              width: double.infinity,
              child: CustomPaint(
                painter: _WeeklyLineIntPainter(values: values, activeIdx: activeIdx),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(days.length, (i) {
                final isActive = i == activeIdx;
                return Column(
                  children: [
                    Text(days[i].split(' ')[0], style: TextStyle(color: isActive ? Colors.white : WhoopTheme.textMuted, fontSize: 9)),
                    Text(days[i].split(' ')[1], style: TextStyle(color: isActive ? Colors.white : WhoopTheme.textMuted, fontSize: 9, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyLineCardDouble({
    required String title,
    required List<String> days,
    required List<double> values,
    required int activeIdx,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: WhoopTheme.officialCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: WhoopTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                const Icon(Icons.chevron_right, color: WhoopTheme.textSecondary, size: 20),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              width: double.infinity,
              child: CustomPaint(
                painter: _WeeklyLineDoublePainter(values: values, activeIdx: activeIdx),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(days.length, (i) {
                final isActive = i == activeIdx;
                return Column(
                  children: [
                    Text(days[i].split(' ')[0], style: TextStyle(color: isActive ? Colors.white : WhoopTheme.textMuted, fontSize: 9)),
                    Text(days[i].split(' ')[1], style: TextStyle(color: isActive ? Colors.white : WhoopTheme.textMuted, fontSize: 9, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ── CUSTOM PAINTERS ────────────────────────────────────────────────────

class _RecoveryArcPainter extends CustomPainter {
  final double percent;
  final Color color;

  const _RecoveryArcPainter({required this.percent, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - 10;

    final bgPaint = Paint()
      ..color = WhoopTheme.cardBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    const startAngle = 3 * pi / 4;
    const sweepMax = 3 * pi / 2;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepMax, false, bgPaint);

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepMax * percent.clamp(0.0, 1.0), false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _RecoveryArcPainter old) => old.percent != percent || old.color != color;
}

class _WeeklyLineIntPainter extends CustomPainter {
  final List<int> values;
  final int activeIdx;

  _WeeklyLineIntPainter({required this.values, required this.activeIdx});

  @override
  void paint(Canvas canvas, Size size) {
    final nonZero = values.where((v) => v > 0).toList();
    if (nonZero.isEmpty) {
      final textPainter = TextPainter(
        text: const TextSpan(text: 'In attesa di misurazioni', style: TextStyle(color: WhoopTheme.textMuted, fontSize: 11)),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(size.width / 2 - textPainter.width / 2, size.height / 2));
      return;
    }

    final path = Path();
    final spacing = size.width / (values.length - 0.5);

    final minV = nonZero.reduce(min) - 4;
    final maxV = nonZero.reduce(max) + 4;
    final span = (maxV - minV) > 0 ? (maxV - minV) : 1;

    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = spacing * (i + 0.3);
      final y = values[i] > 0
          ? size.height - ((values[i] - minV) / span) * (size.height - 30) - 15
          : size.height - 15.0;
      points.add(Offset(x, y));
    }

    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final linePaint = Paint()
      ..color = WhoopTheme.sleepSlate
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final isAct = i == activeIdx;
      canvas.drawCircle(p, 4, Paint()..color = isAct ? Colors.white : WhoopTheme.sleepSlate);
      canvas.drawCircle(p, 2, Paint()..color = WhoopTheme.background);

      if (values[i] > 0) {
        final textPainter = TextPainter(
          text: TextSpan(text: '${values[i]}', style: TextStyle(color: isAct ? WhoopTheme.sleepSlate : WhoopTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, Offset(p.dx - textPainter.width / 2, p.dy - 16));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WeeklyLineDoublePainter extends CustomPainter {
  final List<double> values;
  final int activeIdx;

  _WeeklyLineDoublePainter({required this.values, required this.activeIdx});

  @override
  void paint(Canvas canvas, Size size) {
    final nonZero = values.where((v) => v > 0).toList();
    if (nonZero.isEmpty) {
      final textPainter = TextPainter(
        text: const TextSpan(text: 'In attesa di misurazioni', style: TextStyle(color: WhoopTheme.textMuted, fontSize: 11)),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(size.width / 2 - textPainter.width / 2, size.height / 2));
      return;
    }

    final path = Path();
    final spacing = size.width / (values.length - 0.5);

    final minV = nonZero.reduce(min) - 0.5;
    final maxV = nonZero.reduce(max) + 0.5;
    final span = (maxV - minV) > 0 ? (maxV - minV) : 1.0;

    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = spacing * (i + 0.3);
      final y = values[i] > 0
          ? size.height - ((values[i] - minV) / span) * (size.height - 30) - 15
          : size.height - 15.0;
      points.add(Offset(x, y));
    }

    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final linePaint = Paint()
      ..color = WhoopTheme.sleepSlate
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final isAct = i == activeIdx;
      canvas.drawCircle(p, 4, Paint()..color = isAct ? Colors.white : WhoopTheme.sleepSlate);
      canvas.drawCircle(p, 2, Paint()..color = WhoopTheme.background);

      if (values[i] > 0) {
        final textPainter = TextPainter(
          text: TextSpan(text: values[i].toStringAsFixed(1), style: TextStyle(color: isAct ? WhoopTheme.sleepSlate : WhoopTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, Offset(p.dx - textPainter.width / 2, p.dy - 16));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TriangleCaretPainter extends CustomPainter {
  const _TriangleCaretPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();

    final fillPaint = Paint()
      ..color = const Color(0xFF12171B)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFF242E35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawPath(path, fillPaint);
    canvas.drawLine(Offset(0, size.height), Offset(size.width / 2, 0), borderPaint);
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width, size.height), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

