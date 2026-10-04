import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/whoop_theme.dart';
import '../../data/models/ciclo_fisiologico.dart';
import '../../viewmodels/whoop_viewmodel.dart';

class DailyMetricPoint {
  final String dayName;
  final double strain; // 0.0 - 21.0
  final double recoveryPct; // 0 - 100%
  final bool isToday;

  DailyMetricPoint({
    required this.dayName,
    required this.strain,
    required this.recoveryPct,
    this.isToday = false,
  });
}

/// Card "SFORZO E RECUPERO ⓘ" WHOOP 5.0
/// Riproduce fedelmente lo screenshot ufficiale "Home - Monitoraggio Stress e Grafico Sforzo-Recupero.jpeg"
class WeeklyDualAxisChart extends StatefulWidget {
  const WeeklyDualAxisChart({super.key});

  @override
  State<WeeklyDualAxisChart> createState() => _WeeklyDualAxisChartState();
}

class _WeeklyDualAxisChartState extends State<WeeklyDualAxisChart> {
  int? _selectedDayIndex;

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<WhoopViewModel>(context);
    final cicli = viewModel.cicliList;

    final now = DateTime.now();
    final List<DailyMetricPoint> weeklyData = [];
    final daysOfWeek = ['LUN', 'MAR', 'MER', 'GIO', 'VEN', 'SAB', 'DOM'];

    for (int i = 6; i >= 0; i--) {
      final targetDate = now.subtract(Duration(days: i));
      final dateKey = targetDate.toIso8601String().substring(0, 10);
      final dayName = daysOfWeek[targetDate.weekday - 1];

      CicloFisiologico? match;
      for (final c in cicli) {
        if (c.dataIso == dateKey) {
          match = c;
          break;
        }
      }

      // Valori effettivi da SQLite/BLE
      final double s = match?.sforzoGiornaliero ?? 0.0;
      final double r = match?.punteggioRecuperoPct ?? 0.0;

      weeklyData.add(DailyMetricPoint(
        dayName: dayName,
        strain: s,
        recoveryPct: r,
        isToday: i == 0,
      ));
    }

    final selectedPoint = _selectedDayIndex != null ? weeklyData[_selectedDayIndex!] : null;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: WhoopTheme.officialCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: SFORZO E RECUPERO      ⓘ
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SFORZO E RECUPERO',
                style: TextStyle(
                  color: WhoopTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.info_outline, color: WhoopTheme.textSecondary, size: 18),
                onPressed: () => _showInfoDialog(context),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Dettaglio se un giorno è selezionato
          if (selectedPoint != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF222B32),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    selectedPoint.dayName,
                    style: const TextStyle(
                      color: WhoopTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'Sforzo: ${selectedPoint.strain.toStringAsFixed(1)}',
                        style: const TextStyle(
                          color: WhoopTheme.strainBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Recupero: ${selectedPoint.recoveryPct.toInt()}%',
                        style: TextStyle(
                          color: WhoopTheme.getRecoveryColor(selectedPoint.recoveryPct),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // 2. Grafico Dual Axis
          SizedBox(
            height: 160,
            width: double.infinity,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                final width = context.size?.width ?? 300.0;
                const leftPad = 28.0;
                const rightPad = 36.0;
                final chartW = width - leftPad - rightPad;
                final dx = details.localPosition.dx - leftPad;
                if (dx >= 0 && dx <= chartW) {
                  final idx = ((dx / chartW) * 7).floor().clamp(0, 6);
                  setState(() {
                    _selectedDayIndex = _selectedDayIndex == idx ? null : idx;
                  });
                }
              },
              child: CustomPaint(
                painter: _WhoopDualAxisPainter(
                  data: weeklyData,
                  selectedIndex: _selectedDayIndex,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WhoopTheme.cardSurface,
        title: const Text('Sforzo e Recupero Settimanale', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Questo grafico correla l\'impatto dello Sforzo (Day Strain 0–21 in blu) con la tua capacità di Recupero (0–100% in verde/giallo/rosso) negli ultimi 7 giorni. Aiuta a bilanciare il carico di allenamento con il riposo rigenerativo.',
          style: TextStyle(color: WhoopTheme.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: WhoopTheme.strainBlue)),
          ),
        ],
      ),
    );
  }
}

class _WhoopDualAxisPainter extends CustomPainter {
  final List<DailyMetricPoint> data;
  final int? selectedIndex;

  _WhoopDualAxisPainter({
    required this.data,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const leftMargin = 28.0; // Spazio per asse Y Strain (21, 14, 7)
    const rightMargin = 38.0; // Spazio per asse Y Recovery (100%, 66%, 33%)
    const topMargin = 16.0;
    const bottomMargin = 14.0;

    final chartRect = Rect.fromLTWH(
      leftMargin,
      topMargin,
      size.width - leftMargin - rightMargin,
      size.height - topMargin - bottomMargin,
    );

    // 1. Griglia Orizzontale a 3 Livelli (1/3, 2/3, 3/3)
    final gridPaint = Paint()
      ..color = const Color(0xFF222B32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final strainLabels = ['21', '14', '7'];
    final recoveryLabels = ['100%', '66%', '33%'];
    final recoveryColors = [
      WhoopTheme.recoveryGreen,
      WhoopTheme.recoveryYellow,
      WhoopTheme.recoveryRed,
    ];

    for (int i = 0; i < 3; i++) {
      final y = chartRect.top + (i * (chartRect.height / 2.0));
      canvas.drawLine(Offset(chartRect.left, y), Offset(chartRect.right, y), gridPaint);

      // Label Asse Y Sinistro: Strain (Blu)
      final tpStrain = TextPainter(
        text: TextSpan(
          text: strainLabels[i],
          style: const TextStyle(
            color: WhoopTheme.strainBlue,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tpStrain.paint(canvas, Offset(2, y - (tpStrain.height / 2)));

      // Label Asse Y Destro: Recovery (%)
      final tpRecov = TextPainter(
        text: TextSpan(
          text: recoveryLabels[i],
          style: TextStyle(
            color: recoveryColors[i],
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tpRecov.paint(canvas, Offset(chartRect.right + 6, y - (tpRecov.height / 2)));
    }

    // 2. Colonna "OGGI" Evidenziata con Pillola Sfumata Scura
    final stepX = chartRect.width / (data.length - 1);
    final todayIndex = data.length - 1;
    final todayX = chartRect.left + (todayIndex * stepX);

    final todayPillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(todayX, chartRect.top + (chartRect.height / 2)),
        width: stepX * 0.9,
        height: chartRect.height + 16,
      ),
      const Radius.circular(8),
    );
    final todayPillPaint = Paint()
      ..color = const Color(0xFF1E2832).withOpacity(0.55)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(todayPillRect, todayPillPaint);

    // 3. Calcolo Coordinate Punti
    final recoveryPoints = <Offset>[];
    final strainPoints = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final x = chartRect.left + (i * stepX);

      // Recovery: 0 - 100%
      final recovNorm = (data[i].recoveryPct / 100.0).clamp(0.0, 1.0);
      final ry = chartRect.bottom - (recovNorm * chartRect.height);
      recoveryPoints.add(Offset(x, ry));

      // Strain: 0 - 21.0
      final strainNorm = (data[i].strain / 21.0).clamp(0.0, 1.0);
      final sy = chartRect.bottom - (strainNorm * chartRect.height);
      strainPoints.add(Offset(x, sy));
    }

    // 4. Disegna Linea Grigia di Recupero
    final recoveryLinePaint = Paint()
      ..color = const Color(0xFF6B7A88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final recoveryPath = Path();
    recoveryPath.moveTo(recoveryPoints.first.dx, recoveryPoints.first.dy);
    for (int i = 1; i < recoveryPoints.length; i++) {
      recoveryPath.lineTo(recoveryPoints[i].dx, recoveryPoints[i].dy);
    }
    canvas.drawPath(recoveryPath, recoveryLinePaint);

    // 5. Disegna Linea Blu di Sforzo
    final strainLinePaint = Paint()
      ..color = WhoopTheme.strainBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final strainPath = Path();
    bool hasStrainPath = false;
    for (int i = 0; i < strainPoints.length; i++) {
      if (data[i].strain > 0) {
        if (!hasStrainPath) {
          strainPath.moveTo(strainPoints[i].dx, strainPoints[i].dy);
          hasStrainPath = true;
        } else {
          strainPath.lineTo(strainPoints[i].dx, strainPoints[i].dy);
        }
      }
    }
    if (hasStrainPath) {
      canvas.drawPath(strainPath, strainLinePaint);
    }

    // 6. Disegna Markers e Numeri del Recupero (Cerchi cavi colorati con percentuale)
    for (int i = 0; i < recoveryPoints.length; i++) {
      final pt = recoveryPoints[i];
      final val = data[i].recoveryPct;
      final ptColor = WhoopTheme.getRecoveryColor(val);

      // Disegna punto circolare cavo con riempimento scuro
      final bgCirclePaint = Paint()
        ..color = const Color(0xFF161D22)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pt, 5.0, bgCirclePaint);

      final strokeCirclePaint = Paint()
        ..color = ptColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(pt, 5.0, strokeCirclePaint);

      // Disegna percentuale sopra o vicino al punto
      if (val > 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${val.toInt()}%',
            style: TextStyle(
              color: ptColor,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final isCloseToTop = pt.dy - chartRect.top < 14;
        final labelY = isCloseToTop ? pt.dy + 8 : pt.dy - tp.height - 4;
        tp.paint(canvas, Offset(pt.dx - (tp.width / 2), labelY));
      }
    }

    // 7. Disegna Markers e Valori dello Sforzo (Cerchi cavi blu con numero)
    for (int i = 0; i < strainPoints.length; i++) {
      if (data[i].strain <= 0) continue;

      final pt = strainPoints[i];
      final val = data[i].strain;

      final bgCirclePaint = Paint()
        ..color = const Color(0xFF161D22)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pt, 4.5, bgCirclePaint);

      final strokeCirclePaint = Paint()
        ..color = WhoopTheme.strainBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(pt, 4.5, strokeCirclePaint);

      // Testo dello sforzo sotto il punto
      final tp = TextPainter(
        text: TextSpan(
          text: val.toStringAsFixed(1).replaceAll('.', ','),
          style: const TextStyle(
            color: WhoopTheme.strainBlue,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(pt.dx - (tp.width / 2), pt.dy + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _WhoopDualAxisPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.selectedIndex != selectedIndex;
  }
}
