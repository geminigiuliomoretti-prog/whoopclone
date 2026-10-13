import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/whoop_theme.dart';
import '../../core/theme/nature_theme.dart';
import '../../viewmodels/whoop_viewmodel.dart';

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


  String _getStrainStateLabel(double strain) {
    if (strain <= 0) return 'A RIPOSO';
    if (strain >= 14) return 'SFORZO INTENSO';
    if (strain >= 8) return 'MODERATO';
    return 'LEGGERO';
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '0 min';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    WhoopViewModel? viewModel;
    try {
      viewModel = Provider.of<WhoopViewModel>(context);
    } catch (_) {}

    final recoveryScore = viewModel?.recoveryScore;
    final String targetMsg;
    if (recoveryScore == null) {
      targetMsg = 'Il tuo corpo sta raccogliendo i dati per determinare il target ottimale. Mantieni uno sforzo moderato in base a come ti senti.';
    } else if (recoveryScore >= 67) {
      targetMsg = 'Ottimo recupero ($recoveryScore%). Il tuo corpo è pronto per un carico elevato oggi. Puoi spingerti verso uno sforzo tra 14.0 e 18.0 senza rischi.';
    } else if (recoveryScore >= 34) {
      targetMsg = 'Recupero moderato ($recoveryScore%). Il tuo corpo è in grado di sostenere uno sforzo moderato oggi. Per mantenere l\'equilibrio, mantieni uno sforzo tra 10.0 e 14.0.';
    } else {
      targetMsg = 'Recupero basso ($recoveryScore%). Priorità al riposo e alla rigenerazione attiva. Cerca di mantenere lo sforzo al di sotto di 9.0 oggi.';
    }

    final zones = viewModel?.currentHrZones ?? {};
    final z1Sec = (zones['z1_seconds'] as num?)?.toInt() ?? 0;
    final z2Sec = (zones['z2_seconds'] as num?)?.toInt() ?? 0;
    final z3Sec = (zones['z3_seconds'] as num?)?.toInt() ?? 0;
    final z4Sec = (zones['z4_seconds'] as num?)?.toInt() ?? 0;
    final z5Sec = (zones['z5_seconds'] as num?)?.toInt() ?? 0;

    final z1Pct = (zones['z1_pct'] as num?)?.toDouble() ?? 0.0;
    final z2Pct = (zones['z2_pct'] as num?)?.toDouble() ?? 0.0;
    final z3Pct = (zones['z3_pct'] as num?)?.toDouble() ?? 0.0;
    final z4Pct = (zones['z4_pct'] as num?)?.toDouble() ?? 0.0;
    final z5Pct = (zones['z5_pct'] as num?)?.toDouble() ?? 0.0;

    final z1Str = _formatDuration(z1Sec);
    final z2Str = _formatDuration(z2Sec);
    final z3Str = _formatDuration(z3Sec);
    final z4Str = _formatDuration(z4Sec);
    final z5Str = _formatDuration(z5Sec);

    final z1to3TotalSec = z1Sec + z2Sec + z3Sec;
    final z4to5TotalSec = z4Sec + z5Sec;
    final z1to3Str = z1to3TotalSec > 0 ? _formatDuration(z1to3TotalSec) : zone1to3Duration;
    final z4to5Str = z4to5TotalSec > 0 ? _formatDuration(z4to5TotalSec) : zone4to5Duration;

    final bmrCal = (caloriesTotal * 0.65).round();
    final activeCal = caloriesTotal - bmrCal;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? NatureColors.darkCanvas : NatureColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.chevron_left,
            color: isDark ? NatureColors.textDarkPrimary : NatureColors.textPrimary,
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'OGGI',
          style: TextStyle(
            color: isDark ? NatureColors.textDarkPrimary : NatureColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.info_outline,
              color: isDark ? NatureColors.textDarkSecondary : NatureColors.textSecondary,
              size: 22,
            ),
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

            // 1. Grande Cerchio Strain (Zero atmospheric image)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 270,
                decoration: NatureTheme.organicCardDecoration(
                  isDark: isDark,
                  accentTint: NatureColors.strainAccent.withValues(alpha: 0.12),
                ),
                child: Center(
                  child: SizedBox(
                    width: 220,
                    height: 220,
                    child: CustomPaint(
                      painter: _OfficialStrainArcPainter(
                        percent: (dayStrain / 21.0).clamp(0.0, 1.0),
                        activeColor: NatureColors.terracotta,
                        isDark: isDark,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? NatureColors.darkSurface.withOpacity(0.7)
                                    : NatureColors.creamDark.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? NatureColors.darkBorder.withOpacity(0.6)
                                      : NatureColors.sandBorderSubtle,
                                ),
                              ),
                              child: Text(
                                _getStrainStateLabel(dayStrain),
                                style: TextStyle(
                                  color: isDark ? NatureColors.textDarkSecondary : NatureColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dayStrain.toStringAsFixed(1).replaceAll('.', ','),
                              style: TextStyle(
                                color: isDark ? Colors.white : NatureColors.textPrimary,
                                fontSize: 52,
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'SFORZO',
                              style: TextStyle(
                                color: isDark ? NatureColors.textDarkSecondary : NatureColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 2. Card Sub-metriche Zone FC
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: NatureTheme.organicCardDecoration(),
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  children: [
                    _buildSubMetricRow(
                      icon: Icons.favorite_border,
                      title: 'ZONE DI FREQUENZA CARDIACA\n1-3',
                      value: z1to3Str,
                      baseline: zone1to3Baseline,
                      indicatorType: _IndicatorType.downOrange,
                      iconColor: NatureColors.tealLight,
                    ),
                    Divider(color: NatureColors.darkBorder.withOpacity(0.6), height: 20, thickness: 1),
                    _buildSubMetricRow(
                      icon: Icons.favorite_border,
                      title: 'ZONE DI FREQUENZA CARDIACA\n4-5',
                      value: z4to5Str,
                      baseline: zone4to5Baseline,
                      indicatorType: _IndicatorType.dotGrey,
                      iconColor: NatureColors.terracotta,
                    ),
                    Divider(color: NatureColors.darkBorder.withOpacity(0.6), height: 20, thickness: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: NatureColors.darkSurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: NatureColors.darkBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.arrow_drop_up, color: NatureColors.sage, size: 15),
                                Icon(Icons.arrow_drop_down, color: NatureColors.amberWarm, size: 15),
                                SizedBox(width: 6),
                                Text(
                                  'Oggi vs. 30 giorni precedenti',
                                  style: TextStyle(
                                    color: NatureColors.textDarkSecondary,
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
                decoration: NatureTheme.organicCardDecoration(accentTint: NatureColors.terracotta),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      targetMsg,
                      style: const TextStyle(
                        color: NatureColors.textDarkPrimary,
                        fontSize: 13.5,
                        height: 1.45,
                        fontWeight: FontWeight.w400,
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
                decoration: NatureTheme.organicCardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DISPENDIO ENERGETICO',
                      style: TextStyle(
                        color: NatureColors.textDarkSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildCalTile('Totali', '$caloriesTotal kcal', Colors.white)),
                        Container(width: 1, height: 40, color: NatureColors.darkBorder),
                        Expanded(child: _buildCalTile('BMR Basale', '$bmrCal kcal', NatureColors.textDarkSecondary)),
                        Container(width: 1, height: 40, color: NatureColors.darkBorder),
                        Expanded(child: _buildCalTile('Attive', '$activeCal kcal', NatureColors.terracotta)),
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
                decoration: NatureTheme.organicCardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DISTRIBUZIONE NELLE 5 ZONE FC',
                      style: TextStyle(
                        color: NatureColors.textDarkSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildZoneRow('Zona 5 — Max (90–100%)', z5Str, NatureColors.terracotta, z5Pct),
                    const SizedBox(height: 12),
                    _buildZoneRow('Zona 4 — Anaerobica (80–90%)', z4Str, NatureColors.amberWarm, z4Pct),
                    const SizedBox(height: 12),
                    _buildZoneRow('Zona 3 — Aerobica (70–80%)', z3Str, NatureColors.powderBlue, z3Pct),
                    const SizedBox(height: 12),
                    _buildZoneRow('Zona 2 — Endurance (60–70%)', z2Str, NatureColors.sage, z2Pct),
                    const SizedBox(height: 12),
                    _buildZoneRow('Zona 1 — Riscaldamento (50–60%)', z1Str, NatureColors.textDarkMuted, z1Pct),
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
    Color? iconColor,
  }) {
    Widget indicatorWidget;
    switch (indicatorType) {
      case _IndicatorType.downOrange:
        indicatorWidget = const Icon(Icons.arrow_drop_down, color: NatureColors.amberWarm, size: 16);
        break;
      case _IndicatorType.upGreen:
        indicatorWidget = const Icon(Icons.arrow_drop_up, color: NatureColors.sage, size: 16);
        break;
      case _IndicatorType.dotGrey:
        indicatorWidget = Container(
          width: 5,
          height: 5,
          margin: const EdgeInsets.only(left: 4, right: 3),
          decoration: const BoxDecoration(
            color: NatureColors.textDarkMuted,
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
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: NatureColors.darkSurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: NatureColors.darkBorder.withOpacity(0.5)),
                  ),
                  child: Icon(icon, color: iconColor ?? NatureColors.terracotta, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: NatureColors.textDarkPrimary,
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
                  color: NatureColors.textDarkMuted,
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
  final bool isDark;

  _OfficialStrainArcPainter({
    required this.percent,
    required this.activeColor,
    this.isDark = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 10;
    const strokeWidth = 13.5;

    // 1. Traccia di sfondo circolare completa
    final trackPaint = Paint()
      ..color = isDark ? const Color(0xFF222B34) : NatureColors.sandBorderSubtle
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
