import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/whoop_theme.dart';

/// Modulo 6 — Strain Detail Screen (Full Page)
/// Riproduce fedelmente lo screenshot ufficiale "Strain - Pagina Sforzo Day Strain e Zone FC.jpeg":
/// - Top bar con freccia indietro, "OGGI" e icona info ⓘ
/// - Grande cerchio Strain WHOOP con arco target, tacca superiore e valore numerico
/// - Card sub-metriche con triangolo caret superiore, 4 righe (Zone 1-3, Zone 4-5, Forza, Passi) e pill baseline
/// - Card approfondimento sforzo con link "ESPLORA I TUOI APPROFONDIMENTI SULLO SFORZO"
/// - Sezioni dettagliate: Dispendio Energetico e Ripartizione nelle 5 Zone FC
class StrainDetailModal extends StatelessWidget {
  final double dayStrain;
  final int fcMaxBpm;
  final int fcMediaBpm;
  final int caloriesTotal;
  final int? steps;
  final int? stepsBaseline;
  final String zone1to3Duration;
  final String zone1to3Baseline;
  final String zone4to5Duration;
  final String zone4to5Baseline;
  final String strengthDuration;
  final String strengthBaseline;

  const StrainDetailModal({
    super.key,
    required this.dayStrain,
    required this.fcMaxBpm,
    required this.fcMediaBpm,
    required this.caloriesTotal,
    this.steps,
    this.stepsBaseline,
    this.zone1to3Duration = '0:00',
    this.zone1to3Baseline = '--',
    this.zone4to5Duration = '0:00',
    this.zone4to5Baseline = '--',
    this.strengthDuration = '0:00',
    this.strengthBaseline = '--',
  });

  static void show(
    BuildContext context, {
    required double dayStrain,
    required int fcMaxBpm,
    required int fcMediaBpm,
    required int caloriesTotal,
    int? steps,
    int? stepsBaseline,
    String zone1to3Duration = '0:00',
    String zone1to3Baseline = '--',
    String zone4to5Duration = '0:00',
    String zone4to5Baseline = '--',
    String strengthDuration = '0:00',
    String strengthBaseline = '--',
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StrainDetailModal(
          dayStrain: dayStrain,
          fcMaxBpm: fcMaxBpm,
          fcMediaBpm: fcMediaBpm,
          caloriesTotal: caloriesTotal,
          steps: steps,
          stepsBaseline: stepsBaseline,
          zone1to3Duration: zone1to3Duration,
          zone1to3Baseline: zone1to3Baseline,
          zone4to5Duration: zone4to5Duration,
          zone4to5Baseline: zone4to5Baseline,
          strengthDuration: strengthDuration,
          strengthBaseline: strengthBaseline,
        ),
      ),
    );
  }

  Color get _strainColor => WhoopTheme.strainBlue;

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  @override
  Widget build(BuildContext context) {
    final bmrCal = (caloriesTotal * 0.65).round();
    final activeCal = caloriesTotal - bmrCal;

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

            // 1. Grande Cerchio Strain WHOOP con target zone arc e tacca
            Center(
              child: SizedBox(
                width: 220,
                height: 220,
                child: CustomPaint(
                  painter: _OfficialStrainArcPainter(
                    percent: (dayStrain / 21.0).clamp(0.0, 1.0),
                    activeColor: _strainColor,
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
                          dayStrain.toStringAsFixed(1).replaceAll('.', ','),
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
                          'SFORZO',
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

            // 2. Card 4 Sub-metriche con triangolo Caret Notch
            Center(
              child: CustomPaint(
                size: const Size(14, 7),
                painter: const _StrainTriangleCaretPainter(),
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
                      icon: Icons.favorite_border,
                      title: 'ZONE DI FREQUENZA CARDIACA\n1-3',
                      value: zone1to3Duration,
                      baseline: zone1to3Baseline,
                      indicatorType: _IndicatorType.downOrange,
                    ),
                    const Divider(color: WhoopTheme.cardBorder, height: 22, thickness: 1),
                    _buildSubMetricRow(
                      icon: Icons.favorite_border,
                      title: 'ZONE DI FREQUENZA CARDIACA\n4-5',
                      value: zone4to5Duration,
                      baseline: zone4to5Baseline,
                      indicatorType: _IndicatorType.dotGrey,
                    ),
                    const Divider(color: WhoopTheme.cardBorder, height: 22, thickness: 1),
                    _buildSubMetricRow(
                      icon: Icons.fitness_center,
                      title: 'TEMPO DI ATTIVITÀ DI FORZA',
                      value: strengthDuration,
                      baseline: strengthBaseline,
                      indicatorType: _IndicatorType.dotGrey,
                    ),
                    const Divider(color: WhoopTheme.cardBorder, height: 22, thickness: 1),
                    _buildSubMetricRow(
                      icon: Icons.directions_walk,
                      title: 'PASSI',
                      value: steps != null && steps! > 0 ? _formatNumber(steps!) : '--',
                      baseline: stepsBaseline != null && stepsBaseline! > 0 ? _formatNumber(stepsBaseline!) : '--',
                      indicatorType: steps != null && steps! > 0 ? _IndicatorType.downOrange : _IndicatorType.dotGrey,
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

            // 3. Card Approfondimento Sforzo & Target Consigliato
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: WhoopTheme.officialCardDecoration(tint: WhoopTheme.strainBlue),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Il tuo corpo è in grado di sostenere uno sforzo moderato oggi. Per mantenere l\'equilibrio, oggi mantieni un livello di sforzo moderato tra 11,8 e 16,5.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        height: 1.45,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () {},
                      child: const Text(
                        'ESPLORA I TUOI APPROFONDIMENTI SULLO SFORZO',
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

            // 4. Sezione Dettagli Dispendio Energetico
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: WhoopTheme.officialCardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DISPENDIO ENERGETICO',
                      style: TextStyle(
                        color: WhoopTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildCalTile('Totali', '$caloriesTotal kcal', Colors.white)),
                        Container(width: 1, height: 40, color: const Color(0xFF222B34)),
                        Expanded(child: _buildCalTile('BMR Basale', '$bmrCal kcal', WhoopTheme.textSecondary)),
                        Container(width: 1, height: 40, color: const Color(0xFF222B34)),
                        Expanded(child: _buildCalTile('Attive', '$activeCal kcal', WhoopTheme.strainBlue)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 5. Sezione Dettaglio 5 Zone FC
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: WhoopTheme.officialCardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DISTRIBUZIONE NELLE 5 ZONE FC',
                      style: TextStyle(
                        color: WhoopTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildZoneRow('Zona 5 — Max (90–100%)', '0 min', WhoopTheme.strainHigh, 0.0),
                    const SizedBox(height: 12),
                    _buildZoneRow('Zona 4 — Anaerobica (80–90%)', '0 min', const Color(0xFFFF6D00), 0.0),
                    const SizedBox(height: 12),
                    _buildZoneRow('Zona 3 — Aerobica (70–80%)', '0 min', WhoopTheme.strainBlue, 0.0),
                    const SizedBox(height: 12),
                    _buildZoneRow('Zona 2 — Endurance (60–70%)', '0 min', WhoopTheme.recoveryGreen, 0.0),
                    const SizedBox(height: 12),
                    _buildZoneRow('Zona 1 — Riscaldamento (50–60%)', '0 min', WhoopTheme.textMuted, 0.0),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCalTile(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: WhoopTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildZoneRow(String label, String timeStr, Color color, double pct) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: WhoopTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
            Text(timeStr, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: pct,
          backgroundColor: const Color(0xFF1E2833),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
        ),
      ],
    );
  }

  Widget _buildSubMetricRow({
    required IconData icon,
    required String title,
    required String value,
    required String baseline,
    required _IndicatorType indicatorType,
  }) {
    Widget indicatorWidget;
    switch (indicatorType) {
      case _IndicatorType.downOrange:
        indicatorWidget = const Icon(Icons.arrow_drop_down, color: Color(0xFFFF9800), size: 16);
        break;
      case _IndicatorType.upGreen:
        indicatorWidget = const Icon(Icons.arrow_drop_up, color: WhoopTheme.recoveryGreen, size: 16);
        break;
      case _IndicatorType.dotGrey:
        indicatorWidget = Container(
          width: 5,
          height: 5,
          margin: const EdgeInsets.only(left: 4, right: 3),
          decoration: const BoxDecoration(
            color: WhoopTheme.textMuted,
            shape: BoxShape.circle,
          ),
        );
        break;
    }

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
                      height: 1.25,
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
                  indicatorWidget,
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
}

enum _IndicatorType { downOrange, upGreen, dotGrey }

/// Disegna il grande quadrante circolare di Sforzo WHOOP 5.0
/// Riproduce esattamente:
/// - Cerchio di traccia scuro (#222B34)
/// - Tacca blu superiore alle 12:00
/// - Arco target di sforzo consigliato in basso a sinistra (#344555) con tacca bianca
/// - Arco di sforzo attivo in blu elettrico WhoopTheme.strainBlue
class _OfficialStrainArcPainter extends CustomPainter {
  final double percent;
  final Color activeColor;

  _OfficialStrainArcPainter({
    required this.percent,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 10;
    const strokeWidth = 13.5;

    // 1. Traccia scura di sfondo circolare completa
    final trackPaint = Paint()
      ..color = const Color(0xFF222B34)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, trackPaint);

    // 2. Arco Target di Sforzo Consigliato (in basso a sinistra, approx 11.8 - 16.5 su scala 21)
    // Su scala 21: 11.8 / 21 = 0.56, 16.5 / 21 = 0.785
    // Angolo: partendo da -pi/2: 0.56 * 2pi a 0.785 * 2pi
    const startAngleTarget = -math.pi / 2 + (0.56 * 2 * math.pi);
    const sweepAngleTarget = (0.785 - 0.56) * 2 * math.pi;

    final targetPaint = Paint()
      ..color = const Color(0xFF384958)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngleTarget,
      sweepAngleTarget,
      false,
      targetPaint,
    );

    // Tacca bianca al limite del target consigliato
    final markerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final markerAngle = startAngleTarget + sweepAngleTarget;
    final markerInner = Offset(
      center.dx + (radius - strokeWidth / 2 - 1) * math.cos(markerAngle),
      center.dy + (radius - strokeWidth / 2 - 1) * math.sin(markerAngle),
    );
    final markerOuter = Offset(
      center.dx + (radius + strokeWidth / 2 + 1) * math.cos(markerAngle),
      center.dy + (radius + strokeWidth / 2 + 1) * math.sin(markerAngle),
    );
    canvas.drawLine(markerInner, markerOuter, markerPaint);

    // 3. Tacca blu alle 12:00
    const topAngle = -math.pi / 2;
    final topPipPaint = Paint()
      ..color = WhoopTheme.strainBlue
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final topInner = Offset(
      center.dx + (radius - strokeWidth / 2 - 2) * math.cos(topAngle),
      center.dy + (radius - strokeWidth / 2 - 2) * math.sin(topAngle),
    );
    final topOuter = Offset(
      center.dx + (radius + strokeWidth / 2 + 2) * math.cos(topAngle),
      center.dy + (radius + strokeWidth / 2 + 2) * math.sin(topAngle),
    );
    canvas.drawLine(topInner, topOuter, topPipPaint);

    // 4. Arco attivo di Sforzo Giornaliero
    if (percent > 0) {
      final activePaint = Paint()
        ..color = activeColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        percent * 2 * math.pi,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OfficialStrainArcPainter oldDelegate) {
    return oldDelegate.percent != percent || oldDelegate.activeColor != activeColor;
  }
}

class _StrainTriangleCaretPainter extends CustomPainter {
  const _StrainTriangleCaretPainter();

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
