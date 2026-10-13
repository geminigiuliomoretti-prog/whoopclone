import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/nature_theme.dart';
import '../../viewmodels/whoop_viewmodel.dart';
import 'manual_activity_modal.dart';
import 'charts/hypnogram_chart.dart';
import 'charts/intraday_hr_chart.dart';
import 'charts/heart_rate_zones_chart.dart';
import 'charts/sparkline_14d.dart';
import 'provenance_badge.dart';
import 'nature/atmospheric_hero_header.dart';
import '../../domain/analytics/whoop_analytics_engine.dart';

/// SleepDetailModal — Schermata Dettaglio Sonno Riprogettata
///
/// Nuova Identità Visiva Notturna, Organica e Sofisticata:
/// - Finestra atmosferica notturna con cielo stellato, luna crescente e crinali montani (sleep visual asset)
/// - Sfumatura eterea progressiva verso il Midnight Navy (nessun effetto wallpaper)
/// - Indicatore circolare centrale della prestazione del sonno ad arco calmo
/// - Grafici delle fasi notturne, ipnogramma e frequenza cardiaca armonizzati
/// - Nessuna modifica agli algoritmi o ai dati SQLite
class SleepDetailModal extends StatefulWidget {
  final double sleepPct;
  final double durationMin;
  final double sleepNeedMin;
  final double sleepDebtMin;
  final double lightSleepMin;
  final double deepSleepMin;
  final double remSleepMin;
  final double awakeMin;
  final double efficiencyPct;
  final double consistencyPct;
  final double? baselineDurationMin;
  final double? baselinePerformancePct;
  final List<dynamic>? historicalSonno;
  final List<HypnogramBlock>? hypnogramBlocks;
  final List<HrDataPoint>? intradayPoints;
  final Map<String, dynamic>? hrZonesMap;
  final String? provenance;

  final DateTime? startTime;
  final DateTime? endTime;

  const SleepDetailModal({
    super.key,
    required this.sleepPct,
    required this.durationMin,
    required this.sleepNeedMin,
    required this.sleepDebtMin,
    required this.lightSleepMin,
    required this.deepSleepMin,
    required this.remSleepMin,
    required this.awakeMin,
    required this.efficiencyPct,
    required this.consistencyPct,
    this.startTime,
    this.endTime,
    this.baselineDurationMin,
    this.baselinePerformancePct,
    this.historicalSonno,
    this.hypnogramBlocks,
    this.intradayPoints,
    this.hrZonesMap,
    this.provenance = 'REAL',
  });

  static void show(
    BuildContext context, {
    required double sleepPct,
    required double durationMin,
    required double sleepNeedMin,
    required double sleepDebtMin,
    required double lightSleepMin,
    required double deepSleepMin,
    required double remSleepMin,
    required double awakeMin,
    required double efficiencyPct,
    required double consistencyPct,
    DateTime? startTime,
    DateTime? endTime,
    double? baselineDurationMin,
    double? baselinePerformancePct,
    List<dynamic>? historicalSonno,
    List<HypnogramBlock>? hypnogramBlocks,
    List<HrDataPoint>? intradayPoints,
    Map<String, dynamic>? hrZonesMap,
    String? provenance = 'REAL',
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SleepDetailModal(
          sleepPct: sleepPct,
          durationMin: durationMin,
          sleepNeedMin: sleepNeedMin,
          sleepDebtMin: sleepDebtMin,
          lightSleepMin: lightSleepMin,
          deepSleepMin: deepSleepMin,
          remSleepMin: remSleepMin,
          awakeMin: awakeMin,
          efficiencyPct: efficiencyPct,
          consistencyPct: consistencyPct,
          startTime: startTime,
          endTime: endTime,
          baselineDurationMin: baselineDurationMin,
          baselinePerformancePct: baselinePerformancePct,
          historicalSonno: historicalSonno,
          hypnogramBlocks: hypnogramBlocks,
          intradayPoints: intradayPoints,
          hrZonesMap: hrZonesMap,
          provenance: provenance,
        ),
      ),
    );
  }

  @override
  State<SleepDetailModal> createState() => _SleepDetailModalState();
}

class _SleepDetailModalState extends State<SleepDetailModal> {
  String _formatHoursMin(double min) {
    if (min <= 0) return '--:--';
    final h = min ~/ 60;
    final m = (min % 60).toInt();
    return '$h:${m.toString().padLeft(2, '0')}';
  }

  String _formatTimeOfDay(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _getSleepStateLabel(double pct) {
    if (pct <= 0) return 'IN ATTESA';
    if (pct >= 85) return 'RIPOSO PROFONDO';
    if (pct >= 70) return 'SUFFICIENTE';
    return 'INSUFFICIENTE';
  }

  @override
  Widget build(BuildContext context) {
    final hasSleep = widget.durationMin > 0;
    final restorativeMin = widget.deepSleepMin + widget.remSleepMin;
    final double? baseDur = widget.baselineDurationMin;
    final double? basePerf = widget.baselinePerformancePct;

    final List<Map<String, dynamic>> last7DaysData = _buildLast7DaysSeries(widget.historicalSonno);

    WhoopViewModel? viewModel;
    try {
      viewModel = Provider.of<WhoopViewModel>(context);
    } catch (e) {
      debugPrint('SleepDetailModal: WhoopViewModel non presente nel contesto: $e');
    }

    final List<HypnogramBlock> hypnogramBlocks = widget.hypnogramBlocks ??
        (viewModel != null && viewModel.currentHypnogramSegments.isNotEmpty
            ? viewModel.currentHypnogramSegments.map((s) => HypnogramBlock.fromMap(s)).toList()
            : <HypnogramBlock>[]);

    final List<HrDataPoint> intradayPoints = widget.intradayPoints ??
        (viewModel != null && viewModel.currentIntradayHrBuckets.isNotEmpty
            ? HrDataPoint.fromBuckets(viewModel.currentIntradayHrBuckets)
            : <HrDataPoint>[]);

    final Map<String, dynamic> hrZonesMap = widget.hrZonesMap ??
        (viewModel?.currentHrZones ?? <String, dynamic>{});

    final List<double?> history14dSleep = viewModel?.history14dSleep ?? const <double?>[];

    DateTime? effStart = widget.startTime;
    DateTime? effEnd = widget.endTime;
    if (effStart == null && widget.historicalSonno != null && widget.historicalSonno!.isNotEmpty) {
      final s = widget.historicalSonno!.first;
      if (s != null) {
        try {
          if (s.oraInizio is String && (s.oraInizio as String).isNotEmpty) {
            effStart = s.inizioSonno;
            effEnd = s.inizioRisveglio;
          }
        } catch (_) {}
      }
    }
    if (effStart == null && hypnogramBlocks.isNotEmpty) {
      effStart = hypnogramBlocks.first.startTime;
      effEnd = hypnogramBlocks.last.endTime;
    }
    final String? timeRangeStr = (effStart != null && effEnd != null)
        ? '${_formatTimeOfDay(effStart)} - ${_formatTimeOfDay(effEnd)}'
        : null;

    return Scaffold(
      backgroundColor: NatureColors.background,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. FINESTRA ATMOSFERICA NOTTURNA (MOON & MOUNTAIN HERO HEADER) ──
            AtmosphericHeroHeader(
              imageAsset: 'assets/images/nature/sleep_atmosphere.png',
              backgroundColor: NatureColors.background,
              glowColor: const Color(0x32439EB8), // Diffusione lunare ciano/teal
              imageAlignment: const Alignment(0.0, 0.16),
              height: 335.0,
              title: 'OGGI',
              onBack: () => Navigator.of(context).pop(),
              onInfo: () {},
              child: _buildHeroSleepDial(hasSleep),
            ),

            const SizedBox(height: 12),

            // ── 2. CARD PILASTRI QUALITÀ DEL SONNO ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSleepPillarsCard(hasSleep, viewModel),
            ),

            const SizedBox(height: 16),

            // ── 3. CARD IL SONNO DELLA SCORSA NOTTE (ORE & TIMELINE HR) ─────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildLastNightSummaryCard(
                timeRangeStr: timeRangeStr,
                baseDur: baseDur,
                intradayPoints: intradayPoints,
                viewModel: viewModel,
              ),
            ),

            // Stato Vuoto Esplicito (se il sonno non è ancora registrato)
            if (!hasSleep) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildWaitingSleepDataCard(),
              ),
            ],

            const SizedBox(height: 16),

            // ── 4. CARD FASI DEL SONNO CON IPNOGRAMMA NOTTURNO ──────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSleepStagesCard(
                hasSleep: hasSleep,
                hypnogramBlocks: hypnogramBlocks,
                restorativeMin: restorativeMin,
                viewModel: viewModel,
              ),
            ),

            const SizedBox(height: 16),

            // ── 5. CARD ORE EFFETTIVE VS NECESSARIE ─────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildHoursVsNeedCard(hasSleep: hasSleep, basePerf: basePerf),
            ),

            const SizedBox(height: 16),

            // ── 6. CARD DISTRIBUZIONE ZONE CARDIACHE NEL SONNO ─────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildHrZonesCard(hrZonesMap: hrZonesMap, viewModel: viewModel),
            ),

            const SizedBox(height: 16),

            // ── 7. CARD TREND STORICO SONNO 14 GIORNI ───────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSparklineCard(
                history14dSleep: history14dSleep,
                baseDur: baseDur,
                viewModel: viewModel,
              ),
            ),

            const SizedBox(height: 24),

            // ── 8. SEZIONE TENDENZE SETTIMANALI ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tendenze del sonno',
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

            // Grafico 1: Ore vs Necessarie (%) a Barre
            _buildWeeklyBarCard(
              title: 'ORE VS NECESSARIE (%)',
              days: last7DaysData.map((d) => d['label'] as String).toList(),
              values: last7DaysData.map((d) => (d['pct'] as num).toInt()).toList(),
              activeIdx: last7DaysData.length - 1,
              suffix: '%',
              barColor: NatureColors.sleepAccent,
            ),

            const SizedBox(height: 14),

            // Grafico 2: Efficienza del Sonno a Curva Continua
            _buildWeeklyLineCard(
              title: 'EFFICIENZA DEL SONNO (%)',
              days: last7DaysData.map((d) => d['label'] as String).toList(),
              values: last7DaysData.map((d) => (d['eff'] as num).toInt()).toList(),
              activeIdx: last7DaysData.length - 1,
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ── HERO SLEEP DIAL ─────────────────────────────────────────────────────
  Widget _buildHeroSleepDial(bool hasSleep) {
    final actualVsNeededPct = WhoopAnalyticsEngine.calculateActualVsNeededPct(
      actualDurationMin: widget.durationMin,
      sleepNeedMin: widget.sleepNeedMin,
    );

    // Valore autorevole per Sleep Performance:
    // 1. Se la sessione è importata da WHOOP (WHOOP_IMPORT / WHOOP_NAP) e ha sleepPct > 0, usa quello storico ufficiale
    // 2. Altrimenti usa il calcolo analitico effettivo sonno/bisogno (actualVsNeededPct) se disponibile
    // 3. Fallback a widget.sleepPct se valido, oppure 0.0
    final double? authoritativePerfPct;
    final isImported = widget.provenance == 'WHOOP_IMPORT' || widget.provenance == 'WHOOP_NAP';

    if (isImported && widget.sleepPct > 0) {
      authoritativePerfPct = widget.sleepPct;
    } else if (actualVsNeededPct != null) {
      authoritativePerfPct = actualVsNeededPct;
    } else if (widget.sleepPct > 0) {
      authoritativePerfPct = widget.sleepPct;
    } else {
      authoritativePerfPct = null;
    }

    final effectivePerfPct = authoritativePerfPct ?? 0.0;

    return SizedBox(
      width: 190,
      height: 190,
      child: CustomPaint(
        painter: _OrganicSleepArcPainter(
          percent: hasSleep ? (effectivePerfPct / 100.0).clamp(0.0, 1.0) : 0.0,
          color: NatureColors.tealLight,
          trackColor: NatureColors.sleepTrack,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge di stato del sonno
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
                  _getSleepStateLabel(effectivePerfPct),
                  style: TextStyle(
                    color: (hasSleep && authoritativePerfPct != null) ? NatureColors.tealLight : NatureColors.mutedText,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 4),

              // Punteggio percentuale
              Text(
                (hasSleep && authoritativePerfPct != null)
                    ? '${authoritativePerfPct.round()}%'
                    : '--',
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
                'PRESTAZIONE\nDEL SONNO',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: NatureColors.secondaryText,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  height: 1.15,
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

  // ── CARD PILASTRI QUALITÀ DEL SONNO ─────────────────────────────────────
  Widget _buildSleepPillarsCard(bool hasSleep, WhoopViewModel? viewModel) {
    final actualVsNeededPct = WhoopAnalyticsEngine.calculateActualVsNeededPct(
      actualDurationMin: widget.durationMin,
      sleepNeedMin: widget.sleepNeedMin,
    );

    final sleepStress = viewModel?.sleepStress;
    final sleepStressStr = sleepStress != null ? '${sleepStress.toStringAsFixed(1)} / 3.0' : '--';
    final int stressSegment = sleepStress != null
        ? (sleepStress < 1.0 ? 3 : (sleepStress < 2.0 ? 2 : 1))
        : 1;

    return Container(
      decoration: NatureTheme.organicCardDecoration(isDark: true),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          _buildSleepSubMetricRow(
            icon: Icons.nightlight_round,
            title: 'ORE EFFETTIVE VS\nNECESSARIE',
            value: (hasSleep && actualVsNeededPct != null) ? '${actualVsNeededPct.round()}%' : '--',
            segments: 3,
            activeSegment: actualVsNeededPct != null ? (actualVsNeededPct >= 85 ? 3 : (actualVsNeededPct >= 70 ? 2 : 1)) : 1,
            activeColor: NatureColors.tealLight,
            iconColor: NatureColors.tealLight,
          ),
          Divider(color: NatureColors.borderSubtle, height: 18, thickness: 0.8),
          _buildSleepSubMetricRow(
            icon: Icons.schedule_rounded,
            title: 'REGOLARITÀ DEL\nSONNO',
            value: widget.consistencyPct > 0 ? '${widget.consistencyPct.toInt()}%' : '--',
            segments: 3,
            activeSegment: widget.consistencyPct >= 80 ? 3 : (widget.consistencyPct >= 65 ? 2 : 1),
            activeColor: NatureColors.tealLight,
            iconColor: NatureColors.powderBlue,
          ),
          Divider(color: NatureColors.borderSubtle, height: 18, thickness: 0.8),
          _buildSleepSubMetricRow(
            icon: Icons.hotel_rounded,
            title: 'EFFICIENZA DEL SONNO',
            value: widget.efficiencyPct > 0 ? '${widget.efficiencyPct.toInt()}%' : '--',
            segments: 3,
            activeSegment: widget.efficiencyPct >= 85 ? 3 : (widget.efficiencyPct >= 75 ? 2 : 1),
            activeColor: NatureColors.tealLight,
            iconColor: NatureColors.recoveryAccent,
          ),
          Divider(color: NatureColors.borderSubtle, height: 18, thickness: 0.8),
          _buildSleepSubMetricRow(
            icon: Icons.spa_outlined,
            title: 'STRESS ELEVATO NEL\nSONNO',
            value: sleepStressStr,
            segments: 3,
            activeSegment: stressSegment,
            activeColor: NatureColors.recoveryAccent,
            iconColor: NatureColors.lavender,
          ),
          Divider(color: NatureColors.borderSubtle, height: 18, thickness: 0.8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Scarso', NatureColors.amberWarm),
                const SizedBox(width: 14),
                _buildLegendItem('Sufficiente', NatureColors.teal),
                const SizedBox(width: 14),
                _buildLegendItem('Ottimale', NatureColors.recoveryAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: NatureColors.secondaryText,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSleepSubMetricRow({
    required IconData icon,
    required String title,
    required String value,
    required int segments,
    required int activeSegment,
    required Color activeColor,
    Color? iconColor,
  }) {
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
                    color: (iconColor ?? NatureColors.tealLight).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (iconColor ?? NatureColors.tealLight).withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(icon, color: iconColor ?? NatureColors.tealLight, size: 15),
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
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(segments, (i) {
                  final isActive = i < activeSegment;
                  return Container(
                    width: 14,
                    height: 3.5,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                      color: isActive ? activeColor : NatureColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: NatureColors.primaryText,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── CARD IL SONNO DELLA SCORSA NOTTE ─────────────────────────────────────
  Widget _buildLastNightSummaryCard({
    required String? timeRangeStr,
    required double? baseDur,
    required List<HrDataPoint> intradayPoints,
    required WhoopViewModel? viewModel,
  }) {
    final isUp = baseDur != null && widget.durationMin >= baseDur;

    return Container(
      decoration: NatureTheme.organicCardDecoration(isDark: true),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Il sonno della scorsa notte',
                      style: TextStyle(
                        color: NatureColors.primaryText,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeRangeStr != null
                          ? '$timeRangeStr • Oggi vs. 30 giorni precedenti'
                          : 'Oggi vs. 30 giorni precedenti',
                      style: const TextStyle(
                        color: NatureColors.secondaryText,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => ManualActivityModal.show(context),
                icon: const Icon(Icons.edit_outlined, size: 14, color: NatureColors.tealLight),
                label: const Text(
                  'MODIFICA',
                  style: TextStyle(
                    color: NatureColors.tealLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Metrica Principale Durata
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatHoursMin(widget.durationMin),
                style: const TextStyle(
                  color: NatureColors.primaryText,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      isUp ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
                      color: isUp ? NatureColors.recoveryAccent : NatureColors.strainAccent,
                      size: 22,
                    ),
                    Text(
                      baseDur != null ? _formatHoursMin(baseDur) : '--:--',
                      style: const TextStyle(
                        color: NatureColors.secondaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'BASELINE',
                      style: TextStyle(
                        color: NatureColors.mutedText,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Timeline Cardiaca Intraday
          IntradayHrChart(
            points: intradayPoints,
            height: 140,
            hrRestBaseline: viewModel?.userProfile.hrRestBaseline ?? 55,
            hrMaxBaseline: viewModel?.userProfile.hrMax ?? 190,
            isLoading: viewModel?.isChartsLoading ?? false,
          ),
        ],
      ),
    );
  }

  // ── CARD FASI DEL SONNO CON IPNOGRAMMA ───────────────────────────────────
  Widget _buildSleepStagesCard({
    required bool hasSleep,
    required List<HypnogramBlock> hypnogramBlocks,
    required double restorativeMin,
    required WhoopViewModel? viewModel,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: NatureTheme.organicCardDecoration(isDark: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'FASI DEL SONNO',
                style: TextStyle(
                  color: NatureColors.secondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                hasSleep ? 'DURATA ${_formatHoursMin(widget.durationMin)}' : 'NESSUN DATO',
                style: const TextStyle(
                  color: NatureColors.secondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Grafico Ipnogramma
          HypnogramChart(
            blocks: hypnogramBlocks,
            height: 135,
            isLoading: viewModel?.isChartsLoading ?? false,
          ),

          const SizedBox(height: 16),
          Divider(color: NatureColors.borderSubtle, height: 1),
          const SizedBox(height: 14),

          // Tempo a letto vs Sonno effettivo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TEMPO A LETTO',
                style: TextStyle(
                  color: NatureColors.secondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                _formatHoursMin(widget.durationMin + widget.awakeMin),
                style: const TextStyle(
                  color: NatureColors.primaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SONNO EFFETTIVO',
                style: TextStyle(
                  color: NatureColors.tealLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                _formatHoursMin(widget.durationMin),
                style: const TextStyle(
                  color: NatureColors.tealLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: NatureColors.borderSubtle, height: 1),
          const SizedBox(height: 14),

          // Righe di scomposizione stadi
          _buildPhaseRow('VEGLIA', widget.awakeMin, const Color(0xFFDF955B)),
          const SizedBox(height: 12),
          _buildPhaseRow('LEGGERO', widget.lightSleepMin, const Color(0xFF6F6A9E)),
          const SizedBox(height: 12),
          _buildPhaseRow('SONNO A ONDE LENTE (PROFONDO)', widget.deepSleepMin, const Color(0xFF2E7B91)),
          const SizedBox(height: 12),
          _buildPhaseRow('REM', widget.remSleepMin, const Color(0xFF6AB6CC)),

          Divider(color: NatureColors.borderSubtle, height: 22),

          // Sonno Ristoratore (Profondo + REM)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: NatureColors.tealLight,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'SONNO RISTORATORE',
                    style: TextStyle(
                      color: NatureColors.primaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Text(
                _formatHoursMin(restorativeMin),
                style: const TextStyle(
                  color: NatureColors.primaryText,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseRow(String label, double minutes, Color color) {
    final double timeInBed = (widget.durationMin + widget.awakeMin) > 0
        ? (widget.durationMin + widget.awakeMin)
        : (widget.durationMin > 0 ? widget.durationMin : 1.0);
    double pct = minutes > 0 ? (minutes / timeInBed) : 0.0;

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: Text(
            '$label ${(pct * 100).toInt()}%',
            style: const TextStyle(
              color: NatureColors.secondaryText,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: NatureColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
                margin: const EdgeInsets.symmetric(vertical: 5),
              ),
              if (pct > 0)
                FractionallySizedBox(
                  widthFactor: pct.clamp(0.04, 1.0),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 5),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _formatHoursMin(minutes),
          style: const TextStyle(
            color: NatureColors.primaryText,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  // ── CARD ORE EFFETTIVE VS NECESSARIE ────────────────────────────────────
  Widget _buildHoursVsNeedCard({required bool hasSleep, required double? basePerf}) {
    final actualVsNeededPct = WhoopAnalyticsEngine.calculateActualVsNeededPct(
      actualDurationMin: widget.durationMin,
      sleepNeedMin: widget.sleepNeedMin,
    );

    return Container(
      decoration: NatureTheme.organicCardDecoration(isDark: true),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ORE EFFETTIVE VS NECESSARIE',
                style: TextStyle(
                  color: NatureColors.secondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const Icon(Icons.info_outline_rounded, color: NatureColors.secondaryText, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                (hasSleep && actualVsNeededPct != null) ? '${actualVsNeededPct.round()}%' : '--',
                style: const TextStyle(
                  color: NatureColors.primaryText,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Icon(
                      (basePerf != null && actualVsNeededPct != null && actualVsNeededPct >= basePerf)
                          ? Icons.arrow_drop_up_rounded
                          : Icons.arrow_drop_down_rounded,
                      color: (basePerf != null && actualVsNeededPct != null && actualVsNeededPct >= basePerf)
                          ? NatureColors.recoveryAccent
                          : NatureColors.strainAccent,
                      size: 20,
                    ),
                    Text(
                      basePerf != null ? '${basePerf.toInt()}%' : '--',
                      style: const TextStyle(
                        color: NatureColors.secondaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'BASELINE',
                      style: TextStyle(
                        color: NatureColors.mutedText,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildBarRow(
            'ORE DI SONNO',
            _formatHoursMin(widget.durationMin),
            NatureColors.tealLight,
            widget.sleepNeedMin > 0 ? (widget.durationMin / (widget.sleepNeedMin + 60)) : 0.0,
          ),
          const SizedBox(height: 12),
          _buildBarRow(
            'FABBISOGNO DI SONNO',
            _formatHoursMin(widget.sleepNeedMin),
            NatureColors.secondaryText,
            widget.sleepNeedMin > 0 ? (widget.sleepNeedMin / (widget.sleepNeedMin + 60)) : 0.0,
            isNeed: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBarRow(String label, String value, Color color, double pct, {bool isNeed = false}) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(
              color: NatureColors.secondaryText,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: NatureColors.borderSubtle,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              if (pct > 0)
                FractionallySizedBox(
                  widthFactor: pct.clamp(0.08, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          style: const TextStyle(
            color: NatureColors.primaryText,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  // ── CARD ZONE CARDIACHE NEL SONNO ────────────────────────────────────────
  Widget _buildHrZonesCard({
    required Map<String, dynamic> hrZonesMap,
    required WhoopViewModel? viewModel,
  }) {
    return HeartRateZonesChart.fromDistributionMap(
      hrZonesMap,
      isLoading: viewModel?.isChartsLoading ?? false,
    );
  }

  // ── CARD SPARKLINE 14 GIORNI ─────────────────────────────────────────────
  Widget _buildSparklineCard({
    required List<double?> history14dSleep,
    required double? baseDur,
    required WhoopViewModel? viewModel,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: NatureTheme.organicCardDecoration(isDark: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TREND STORICO SONNO (14 GIORNI)',
                style: TextStyle(
                  color: NatureColors.secondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                '${baseDur != null ? _formatHoursMin(baseDur) : "8:00"} BASELINE',
                style: const TextStyle(
                  color: NatureColors.mutedText,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Sparkline14d(
            dataPoints: history14dSleep,
            baselineValue: baseDur != null ? (baseDur / 60.0) : 8.0,
            height: 55,
            primaryColor: NatureColors.tealLight,
            isLoading: viewModel?.isChartsLoading ?? false,
          ),
        ],
      ),
    );
  }

  // ── CARD STATO IN ATTESA SONNO ───────────────────────────────────────────
  Widget _buildWaitingSleepDataCard() {
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
            child: const Icon(Icons.nightlight_outlined, color: NatureColors.secondaryText, size: 18),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nessun sonno registrato',
                  style: TextStyle(
                    color: NatureColors.primaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Indossa il dispositivo durante la notte o aggiungi una sessione tramite il pulsante Modifica.',
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

  // ── GRAFICI SETTIMANALI ──────────────────────────────────────────────────
  Widget _buildWeeklyBarCard({
    required String title,
    required List<String> days,
    required List<int> values,
    required int activeIdx,
    String suffix = '',
    required Color barColor,
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
                  final heightFactor = val > 0 ? (val / 100.0).clamp(0.06, 1.0) : 0.04;

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
                          val > 0 ? '$val$suffix' : '--',
                          style: TextStyle(
                            color: isActive ? NatureColors.tealLight : NatureColors.secondaryText,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 22,
                          height: 85 * heightFactor,
                          decoration: BoxDecoration(
                            color: val > 0
                                ? (isActive ? NatureColors.tealLight : NatureColors.tealLight.withValues(alpha: 0.5))
                                : NatureColors.border,
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
                painter: _WeeklyCurvedSleepLinePainter(values: values, activeIdx: activeIdx),
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
    final refDate = widget.startTime ?? DateTime.now();
    final List<Map<String, dynamic>> series = [];

    for (int i = 6; i >= 0; i--) {
      final date = refDate.subtract(Duration(days: i));
      final dateIso = date.toIso8601String().substring(0, 10);
      final weekdayStr = _weekdayShort(date.weekday);
      final dayNum = date.day;

      dynamic matchingSonno;
      if (historical != null) {
        for (final s in historical) {
          if (s.dataIso == dateIso) {
            matchingSonno = s;
            break;
          }
        }
      }

      int? computedPct = (matchingSonno?.sleepPerformancePct as num?)?.toInt();
      if (computedPct == null && matchingSonno != null) {
        final durata = (matchingSonno.durataTotMin as num?)?.toDouble() ?? 0.0;
        final need = (matchingSonno.sleepNeedMin as num?)?.toDouble() ?? 0.0;
        if (durata > 0 && need > 0) {
          computedPct = ((durata / need) * 100).round();
        }
      }

      final pct = computedPct ??
          (i == 0 && widget.sleepPct > 0 ? widget.sleepPct.toInt() : 0);
      final eff = (matchingSonno?.efficienzaPct as num?)?.toInt() ??
          (i == 0 && widget.efficiencyPct > 0 ? widget.efficiencyPct.toInt() : 0);

      series.add({
        'label': '$weekdayStr $dayNum',
        'pct': pct,
        'eff': eff,
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

// ── CUSTOM PAINTERS NOTTURNI ───────────────────────────────────────────────

class _OrganicSleepArcPainter extends CustomPainter {
  final double percent;
  final Color color;
  final Color trackColor;

  const _OrganicSleepArcPainter({
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

    // Traccia notturna discreta
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

    // Arco attivo sfumato nei toni teal/ciano chiaro
    final rect = Rect.fromCircle(center: center, radius: radius);
    final arcPaint = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepMax,
        colors: [
          NatureColors.tealDark,
          color,
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
  bool shouldRepaint(covariant _OrganicSleepArcPainter old) =>
      old.percent != percent || old.color != color || old.trackColor != trackColor;
}

class _WeeklyCurvedSleepLinePainter extends CustomPainter {
  final List<int> values;
  final int activeIdx;

  _WeeklyCurvedSleepLinePainter({required this.values, required this.activeIdx});

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

    final minV = nonZero.reduce(min) - 4.0;
    final maxV = nonZero.reduce(max) + 4.0;
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

    // Curva morbida
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final midX = (p0.dx + p1.dx) / 2;
      path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    final linePaint = Paint()
      ..color = NatureColors.tealLight
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final isAct = i == activeIdx;

      canvas.drawCircle(
        p,
        isAct ? 5.0 : 3.5,
        Paint()..color = isAct ? NatureColors.primaryText : NatureColors.tealLight,
      );
      canvas.drawCircle(
        p,
        isAct ? 2.5 : 1.8,
        Paint()..color = NatureColors.surface,
      );

      if (values[i] > 0) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: '${values[i]}%',
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
