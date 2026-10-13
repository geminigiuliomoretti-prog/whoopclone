import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/nature_theme.dart';
import '../../data/services/insight_engine.dart';
import 'provenance_badge.dart';
import 'nature/atmospheric_hero_header.dart';

/// RecoveryDetailModal — Schermata Dettaglio Recupero Riprogettata
///
/// Nuova Identità Visiva Organica, Naturale e Sofisticata:
/// - Finestra atmosferica con paesaggio montano all'alba (sunrise visual asset)
/// - Sfumatura eterea ultra-morbida verso la fondazione Dark Navy (nessun effetto wallpaper)
/// - Indicatore circolare centrale del recupero ad arco organico
/// - Schede metriche con bordi minerali sottili ed elevazione morbida
/// - Nessuna modifica ai calcoli fisiologici o ai dati SQLite
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
  final String? provenance;

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
    this.provenance = 'REAL',
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
    String? provenance = 'REAL',
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
          provenance: provenance,
        ),
      ),
    );
  }

  @override
  State<RecoveryDetailModal> createState() => _RecoveryDetailModalState();
}

class _RecoveryDetailModalState extends State<RecoveryDetailModal> {
  Color _getRecoveryColor(double pct) {
    if (pct <= 0) return NatureColors.mutedText;
    if (pct >= 67) return NatureColors.recoveryAccent;
    if (pct >= 34) return NatureColors.amberWarm;
    return NatureColors.strainAccent;
  }

  String _getRecoveryStateLabel(double pct) {
    if (pct <= 0) return 'IN ATTESA';
    if (pct >= 67) return 'OTTIMALE';
    if (pct >= 34) return 'ADEGUATO';
    return 'INSUFFICIENTE';
  }

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

    // Generazione serie temporale reale ultimi 7 giorni dai cicli storici
    final List<Map<String, dynamic>> last7DaysData = _buildLast7DaysSeries(widget.historicalCicli);

    return Scaffold(
      backgroundColor: NatureColors.background,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. FINISTRA ATMOSFERICA ALL'ALBA (SUNRISE HERO HEADER) ──────────
            AtmosphericHeroHeader(
              imageAsset: 'assets/images/nature/recovery_atmosphere.png',
              backgroundColor: NatureColors.background,
              glowColor: const Color(0x35E29A56), // Diffusione dorata dell'alba
              imageAlignment: const Alignment(0.0, 0.22),
              height: 335.0,
              title: 'OGGI',
              onBack: () => Navigator.of(context).pop(),
              onInfo: () {},
              child: _buildHeroRecoveryDial(hasRecovery),
            ),

            const SizedBox(height: 12),

            // ── 2. CARD METRICHE CHIAVE DEL RECUPERO ────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildKeyMetricsCard(
                hasHrv: hasHrv,
                hrvBase: hrvBase,
                hasFcr: hasFcr,
                fcrBase: fcrBase,
                hasResp: hasResp,
                respBase: respBase,
                hasSleepPerf: hasSleepPerf,
                sleepPerf: sleepPerf,
                sleepBase: sleepBase,
              ),
            ),

            const SizedBox(height: 16),

            // ── 3. CARD INSIGHT & VALUTAZIONE FISIOLOGICA ────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildPhysiologicalAssessmentCard(hasHrv, hrvBase),
            ),

            // Stato Vuoto Esplicito (se il recupero non è ancora calcolato)
            if (!hasRecovery) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildWaitingDataCard(),
              ),
            ],

            const SizedBox(height: 24),

            // ── 4. SEZIONE TENDENZE SETTIMANALI ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tendenze settimanali',
                    style: TextStyle(
                      color: NatureColors.primaryText,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Analisi comparativa degli ultimi 7 giorni',
                    style: TextStyle(
                      color: NatureColors.secondaryText,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Grafico 1: Recupero Settimanale a Barre Organiche
            _buildWeeklyRecoveryBarCard(
              title: 'RECUPERO',
              days: last7DaysData.map((d) => d['label'] as String).toList(),
              values: last7DaysData.map((d) => (d['rec'] as num).toInt()).toList(),
              activeIdx: last7DaysData.length - 1,
            ),

            const SizedBox(height: 14),

            // Grafico 2: Variabilità Frequenza Cardiaca (VFC) a Curva Continua
            _buildWeeklyLineCard(
              title: 'VARIABILITÀ DELLA FREQUENZA CARDIACA (VFC)',
              unit: 'ms',
              lineColor: NatureColors.recoveryAccent,
              days: last7DaysData.map((d) => d['label'] as String).toList(),
              values: last7DaysData.map((d) => (d['hrv'] as num).toInt()).toList(),
              activeIdx: last7DaysData.length - 1,
            ),

            const SizedBox(height: 14),

            // Grafico 3: Frequenza Cardiaca a Riposo (FCR)
            _buildWeeklyLineCard(
              title: 'FREQUENZA CARDIACA A RIPOSO (FCR)',
              unit: 'bpm',
              lineColor: NatureColors.strainAccent,
              days: last7DaysData.map((d) => d['label'] as String).toList(),
              values: last7DaysData.map((d) => (d['rhr'] as num).toInt()).toList(),
              activeIdx: last7DaysData.length - 1,
            ),

            const SizedBox(height: 14),

            // Grafico 4: Frequenza Respiratoria a Precisione Decimale
            _buildWeeklyLineCardDouble(
              title: 'FREQUENZA RESPIRATORIA',
              unit: 'rpm',
              lineColor: NatureColors.powderBlue,
              days: last7DaysData.map((d) => d['label'] as String).toList(),
              values: last7DaysData.map((d) => (d['resp'] as num).toDouble()).toList(),
              activeIdx: last7DaysData.length - 1,
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ── HERO RECOVERY DIAL ──────────────────────────────────────────────────
  Widget _buildHeroRecoveryDial(bool hasRecovery) {
    final recColor = _getRecoveryColor(widget.recoveryPct);

    return SizedBox(
      width: 190,
      height: 190,
      child: CustomPaint(
        painter: _OrganicRecoveryArcPainter(
          percent: hasRecovery ? (widget.recoveryPct / 100.0) : 0.0,
          color: recColor,
          trackColor: NatureColors.recoveryTrack,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge di stato del recupero
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(
                  color: NatureColors.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(NatureRadius.pill),
                  border: Border.all(
                    color: NatureColors.border.withValues(alpha: 0.6),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  _getRecoveryStateLabel(widget.recoveryPct),
                  style: TextStyle(
                    color: hasRecovery ? recColor : NatureColors.mutedText,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 4),

              // Punteggio principale (tipografia calma e raffinata)
              Text(
                hasRecovery ? '${widget.recoveryPct.toInt()}%' : '--',
                style: const TextStyle(
                  color: NatureColors.primaryText,
                  fontSize: 46,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                  letterSpacing: -1.0,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),

              const SizedBox(height: 2),

              // Dicitura metrica
              const Text(
                'RECUPERO',
                style: TextStyle(
                  color: NatureColors.secondaryText,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                ),
              ),

              if (widget.provenance != null) ...[
                const SizedBox(height: 5),
                ProvenanceBadge(provenance: widget.provenance!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── CARD 4 SUB-METRICHE ─────────────────────────────────────────────────
  Widget _buildKeyMetricsCard({
    required bool hasHrv,
    required double? hrvBase,
    required bool hasFcr,
    required int? fcrBase,
    required bool hasResp,
    required double? respBase,
    required bool hasSleepPerf,
    required double? sleepPerf,
    required double? sleepBase,
  }) {
    return Container(
      decoration: NatureTheme.organicCardDecoration(isDark: true),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          _buildSubMetricRow(
            icon: Icons.show_chart_rounded,
            title: 'VARIABILITÀ DELLA FREQUENZA CARDIACA (VFC)',
            value: hasHrv ? '${widget.hrvMs.toInt()}' : '--',
            baseline: hrvBase != null ? '${hrvBase.toInt()}' : '--',
            isUp: hrvBase != null && widget.hrvMs >= hrvBase,
            iconColor: NatureColors.recoveryAccent,
          ),
          Divider(color: NatureColors.borderSubtle, height: 18, thickness: 0.8),
          _buildSubMetricRow(
            icon: Icons.favorite_rounded,
            title: 'FREQUENZA CARDIACA A RIPOSO (FCR)',
            value: hasFcr ? '${widget.fcrBpm}' : '--',
            baseline: fcrBase != null ? '$fcrBase' : '--',
            isUp: fcrBase != null && widget.fcrBpm <= fcrBase,
            arrowColor: NatureColors.recoveryAccent,
            iconColor: NatureColors.amberWarm,
          ),
          Divider(color: NatureColors.borderSubtle, height: 18, thickness: 0.8),
          _buildSubMetricRow(
            icon: Icons.air_rounded,
            title: 'FREQUENZA RESPIRATORIA',
            value: hasResp ? widget.respRateRpm.toStringAsFixed(1) : '--',
            baseline: respBase != null ? respBase.toStringAsFixed(1) : '--',
            isUp: respBase != null && widget.respRateRpm <= respBase + 0.5,
            arrowColor: NatureColors.amberWarm,
            iconColor: NatureColors.powderBlue,
          ),
          Divider(color: NatureColors.borderSubtle, height: 18, thickness: 0.8),
          _buildSubMetricRow(
            icon: Icons.bedtime_rounded,
            title: 'PRESTAZIONE DEL SONNO',
            value: (hasSleepPerf && sleepPerf != null) ? '${sleepPerf.toInt()}%' : '--',
            baseline: sleepBase != null ? '${sleepBase.toInt()}%' : '--',
            isUp: sleepBase != null && (sleepPerf ?? 0) >= sleepBase,
            iconColor: NatureColors.tealLight,
          ),
          Divider(color: NatureColors.borderSubtle, height: 18, thickness: 0.8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: NatureColors.surfaceHighlight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: NatureColors.borderSubtle),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_drop_up_rounded, color: NatureColors.recoveryAccent, size: 16),
                      Icon(Icons.arrow_drop_down_rounded, color: NatureColors.amberWarm, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Oggi vs. 30 giorni precedenti',
                        style: TextStyle(
                          color: NatureColors.secondaryText,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
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
    );
  }

  Widget _buildSubMetricRow({
    required IconData icon,
    required String title,
    required String value,
    required String baseline,
    required bool isUp,
    Color? arrowColor,
    Color? iconColor,
  }) {
    final effectiveArrowColor = arrowColor ?? (isUp ? NatureColors.recoveryAccent : NatureColors.strainAccent);

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
                    color: (iconColor ?? NatureColors.recoveryAccent).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (iconColor ?? NatureColors.recoveryAccent).withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(icon, color: iconColor ?? NatureColors.recoveryAccent, size: 15),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: NatureColors.primaryText,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
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
                      color: NatureColors.primaryText,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    isUp ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
                    color: effectiveArrowColor,
                    size: 18,
                  ),
                ],
              ),
              Text(
                baseline,
                style: const TextStyle(
                  color: NatureColors.secondaryText,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── CARD VALUTAZIONE FISIOLOGICA ─────────────────────────────────────────
  Widget _buildPhysiologicalAssessmentCard(bool hasHrv, double? hrvBase) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: NatureTheme.organicCardDecoration(
        accentTint: NatureColors.recoveryAccent,
        isDark: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny_rounded, color: Color(0xFFE29A56), size: 15),
              const SizedBox(width: 7),
              const Text(
                'VALUTAZIONE FISIOLOGICA',
                style: TextStyle(
                  color: Color(0xFFE29A56),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            InsightEngine.generateHrvInsight(
              hrvSws: hasHrv ? widget.hrvMs : null,
              hrvBaseline: hrvBase,
            ),
            style: const TextStyle(
              color: NatureColors.primaryText,
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {},
            child: const Text(
              'ESPLORA I TUOI APPROFONDIMENTI SUL RECUPERO →',
              style: TextStyle(
                color: NatureColors.tealLight,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── CARD STATO IN ATTESA ─────────────────────────────────────────────────
  Widget _buildWaitingDataCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: NatureTheme.organicCardDecoration(isDark: true),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: NatureColors.mutedText.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.spa_outlined, color: NatureColors.secondaryText, size: 18),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'In attesa di nuovo sonno notturno',
                  style: TextStyle(
                    color: NatureColors.primaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Il recupero verrà calcolato al termine della prossima sessione di riposo registrata.',
                  style: TextStyle(
                    color: NatureColors.secondaryText,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── GRAFICO A BARRE RECUPERO SETTIMANALE ──────────────────────────────────
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
        decoration: NatureTheme.organicCardDecoration(isDark: true),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: NatureColors.secondaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: NatureColors.secondaryText,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 145,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(days.length, (i) {
                  final isActive = i == activeIdx;
                  final val = values[i];
                  final color = _getRecoveryColor(val.toDouble());

                  return Container(
                    padding: isActive ? const EdgeInsets.symmetric(horizontal: 5, vertical: 4) : null,
                    decoration: isActive
                        ? BoxDecoration(
                            color: NatureColors.surfaceHighlight.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: NatureColors.borderSubtle),
                          )
                        : null,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          val > 0 ? '$val%' : '--',
                          style: TextStyle(
                            color: val > 0 ? color : NatureColors.mutedText,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 22,
                          height: val > 0 ? (85 * (val / 100.0)).clamp(6.0, 85.0) : 4.0,
                          decoration: BoxDecoration(
                            color: val > 0 ? color : NatureColors.border,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          days[i].split(' ')[0],
                          style: TextStyle(
                            color: isActive ? NatureColors.primaryText : NatureColors.secondaryText,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          days[i].split(' ')[1],
                          style: TextStyle(
                            color: isActive ? NatureColors.primaryText : NatureColors.secondaryText,
                            fontSize: 10,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                          ),
                        ),
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

  // ── GRAFICO LINEARE CON CURVA FLUIDA ─────────────────────────────────────
  Widget _buildWeeklyLineCard({
    required String title,
    required String unit,
    required Color lineColor,
    required List<String> days,
    required List<int> values,
    required int activeIdx,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: NatureTheme.organicCardDecoration(isDark: true),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: NatureColors.secondaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: NatureColors.secondaryText,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              width: double.infinity,
              child: CustomPaint(
                painter: _WeeklyCurvedLinePainter(
                  values: values.map((v) => v.toDouble()).toList(),
                  activeIdx: activeIdx,
                  strokeColor: lineColor,
                  unit: unit,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(days.length, (i) {
                final isActive = i == activeIdx;
                return Column(
                  children: [
                    Text(
                      days[i].split(' ')[0],
                      style: TextStyle(
                        color: isActive ? NatureColors.primaryText : NatureColors.secondaryText,
                        fontSize: 9.5,
                      ),
                    ),
                    Text(
                      days[i].split(' ')[1],
                      style: TextStyle(
                        color: isActive ? NatureColors.primaryText : NatureColors.secondaryText,
                        fontSize: 9.5,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
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
    required String unit,
    required Color lineColor,
    required List<String> days,
    required List<double> values,
    required int activeIdx,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: NatureTheme.organicCardDecoration(isDark: true),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: NatureColors.secondaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: NatureColors.secondaryText,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              width: double.infinity,
              child: CustomPaint(
                painter: _WeeklyCurvedLinePainter(
                  values: values,
                  activeIdx: activeIdx,
                  strokeColor: lineColor,
                  isDouble: true,
                  unit: unit,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(days.length, (i) {
                final isActive = i == activeIdx;
                return Column(
                  children: [
                    Text(
                      days[i].split(' ')[0],
                      style: TextStyle(
                        color: isActive ? NatureColors.primaryText : NatureColors.secondaryText,
                        fontSize: 9.5,
                      ),
                    ),
                    Text(
                      days[i].split(' ')[1],
                      style: TextStyle(
                        color: isActive ? NatureColors.primaryText : NatureColors.secondaryText,
                        fontSize: 9.5,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // Costruzione serie temporale reale degli ultimi 7 giorni
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

      final rec = (matchingCiclo?.punteggioRecuperoPct as num?)?.toInt() ??
          (i == 0 && widget.recoveryPct > 0 ? widget.recoveryPct.toInt() : 0);
      final hrv = (matchingCiclo?.vfcMs as num?)?.toInt() ??
          (i == 0 && widget.hrvMs > 0 ? widget.hrvMs.toInt() : 0);
      final rhr = (matchingCiclo?.fcrBpm as num?)?.toInt() ??
          (i == 0 && widget.fcrBpm > 0 ? widget.fcrBpm : 0);
      final resp = (matchingCiclo?.frequenzaRespiratoriaRpm as num?)?.toDouble() ??
          (i == 0 && widget.respRateRpm > 0 ? widget.respRateRpm : 0.0);

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
}

// ── CUSTOM PAINTERS RAFFINATI ───────────────────────────────────────────────

class _OrganicRecoveryArcPainter extends CustomPainter {
  final double percent;
  final Color color;
  final Color trackColor;

  const _OrganicRecoveryArcPainter({
    required this.percent,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - 10;

    const startAngle = 3 * pi / 4;
    const sweepMax = 3 * pi / 2;

    // 1. Traccia di sfondo
    final bgPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepMax,
      false,
      bgPaint,
    );

    if (percent <= 0) return;

    // 2. Arco attivo sfumato organicamente
    final rect = Rect.fromCircle(center: center, radius: radius);
    final arcPaint = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepMax,
        colors: [
          const Color(0xFFE29A56), // Tonalità alba calda iniziale
          color,                   // Tonalità finale (sage o livello calcolato)
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      startAngle,
      sweepMax * percent.clamp(0.0, 1.0),
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _OrganicRecoveryArcPainter old) =>
      old.percent != percent || old.color != color || old.trackColor != trackColor;
}

class _WeeklyCurvedLinePainter extends CustomPainter {
  final List<double> values;
  final int activeIdx;
  final Color strokeColor;
  final bool isDouble;
  final String unit;

  _WeeklyCurvedLinePainter({
    required this.values,
    required this.activeIdx,
    required this.strokeColor,
    this.isDouble = false,
    this.unit = '',
  });

  @override
  void paint(Canvas canvas, Size size) {
    final nonZero = values.where((v) => v > 0).toList();
    if (nonZero.isEmpty) {
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'In attesa di misurazioni',
          style: TextStyle(color: NatureColors.mutedText, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(size.width / 2 - textPainter.width / 2, size.height / 2 - 8),
      );
      return;
    }

    final minV = nonZero.reduce(min) - (isDouble ? 0.4 : 3.0);
    final maxV = nonZero.reduce(max) + (isDouble ? 0.4 : 3.0);
    final span = (maxV - minV) > 0 ? (maxV - minV) : 1.0;
    final spacing = size.width / (values.length - 0.5);

    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = spacing * (i + 0.3);
      final y = values[i] > 0
          ? size.height - ((values[i] - minV) / span) * (size.height - 34) - 16
          : size.height - 16.0;
      points.add(Offset(x, y));
    }

    // Costruzione curva morbida bezier
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final midX = (p0.dx + p1.dx) / 2;
      path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    // Linea principale
    final linePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    // Indicatori circolari sui punti
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final isAct = i == activeIdx;

      canvas.drawCircle(
        p,
        isAct ? 5.0 : 3.5,
        Paint()..color = isAct ? NatureColors.primaryText : strokeColor,
      );
      canvas.drawCircle(
        p,
        isAct ? 2.5 : 1.8,
        Paint()..color = NatureColors.surface,
      );

      if (values[i] > 0) {
        final valStr = isDouble ? values[i].toStringAsFixed(1) : '${values[i].toInt()}';
        final textPainter = TextPainter(
          text: TextSpan(
            text: valStr,
            style: TextStyle(
              color: isAct ? NatureColors.primaryText : NatureColors.secondaryText,
              fontSize: 10,
              fontWeight: isAct ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, Offset(p.dx - textPainter.width / 2, p.dy - 17));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
