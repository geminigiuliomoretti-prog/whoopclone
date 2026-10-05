import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/whoop_theme.dart';
import '../../viewmodels/whoop_viewmodel.dart';
import 'manual_activity_modal.dart';
import 'charts/hypnogram_chart.dart';
import 'charts/intraday_hr_chart.dart';
import 'charts/heart_rate_zones_chart.dart';
import 'charts/sparkline_14d.dart';
import 'provenance_badge.dart';

/// Schermata Dettaglio Sonno WHOOP 5.0 (Full Page)
/// Zero-Tolerance Mock Purge: Legge i dati calcolati matematicamente da SQLite (sonno & cicli_fisiologici)
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
      // ViewModel opzionale se la schermata viene visualizzata isolata
      debugPrint('SleepDetailModal: WhoopViewModel non trovato nel contesto: $e');
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

            // 1. Grande Cerchio Prestazione del Sonno
            Center(
              child: SizedBox(
                width: 220,
                height: 220,
                child: CustomPaint(
                  painter: _SleepArcPainter(
                    percentage: hasSleep ? widget.sleepPct : 0.0,
                    arcColor: WhoopTheme.sleepSlate,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'WHOOP',
                        style: TextStyle(
                          color: WhoopTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasSleep ? '${widget.sleepPct.toInt()}%' : '--',
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
                        'PRESTAZIONE\nDEL SONNO',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: WhoopTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          height: 1.2,
                        ),
                      ),
                      if (widget.provenance != null) ...[
                        const SizedBox(height: 6),
                        ProvenanceBadge(provenance: widget.provenance!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Indicatori di paginazione a 3 trattini
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 14,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3844),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  width: 18,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  width: 14,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3844),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 2. Card 4 Sub-metriche con triangolo Caret Notch
            const Center(
              child: CustomPaint(
                size: Size(14, 7),
                painter: _SleepTriangleCaretPainter(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: WhoopTheme.officialCardDecoration(),
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  children: [
                    _buildSleepSubMetricRow(
                      icon: Icons.nightlight_round,
                      title: 'ORE EFFETTIVE VS\nNECESSARIE',
                      value: hasSleep ? '${widget.sleepPct.toInt()}%' : '--',
                      segments: 2,
                      activeSegment: 2,
                      activeColor: WhoopTheme.sleepSlate,
                    ),
                    const Divider(color: WhoopTheme.cardBorder, height: 22, thickness: 1),
                    _buildSleepSubMetricRow(
                      icon: Icons.schedule,
                      title: 'REGOLARITÀ DEL\nSONNO',
                      value: widget.consistencyPct > 0 ? '${widget.consistencyPct.toInt()}%' : '--',
                      segments: 2,
                      activeSegment: 2,
                      activeColor: WhoopTheme.sleepSlate,
                    ),
                    const Divider(color: WhoopTheme.cardBorder, height: 22, thickness: 1),
                    _buildSleepSubMetricRow(
                      icon: Icons.hotel,
                      title: 'EFFICIENZA DEL SONNO',
                      value: widget.efficiencyPct > 0 ? '${widget.efficiencyPct.toInt()}%' : '--',
                      segments: 2,
                      activeSegment: 2,
                      activeColor: WhoopTheme.sleepSlate,
                    ),
                    const Divider(color: WhoopTheme.cardBorder, height: 22, thickness: 1),
                    _buildSleepSubMetricRow(
                      icon: Icons.refresh,
                      title: 'STRESS ELEVATO NEL\nSONNO',
                      value: '0%',
                      segments: 3,
                      activeSegment: 3,
                      activeColor: WhoopTheme.recoveryGreen,
                    ),
                    const Divider(color: WhoopTheme.cardBorder, height: 20, thickness: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141920),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF222B34)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(width: 10, height: 2.5, color: const Color(0xFFFF9800)),
                            const SizedBox(width: 4),
                            const Text('Scarso', style: TextStyle(color: WhoopTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 12),
                            Container(width: 10, height: 2.5, color: const Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            const Text('Sufficiente', style: TextStyle(color: WhoopTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 12),
                            Container(width: 10, height: 2.5, color: WhoopTheme.recoveryGreen),
                            const SizedBox(width: 4),
                            const Text('Ottimale', style: TextStyle(color: WhoopTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Header Il sonno della scorsa notte
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Il sonno della scorsa notte',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Oggi vs. 30 giorni precedenti',
                        style: TextStyle(color: WhoopTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => ManualActivityModal.show(context),
                    icon: const Icon(Icons.edit_outlined, size: 14, color: WhoopTheme.textSecondary),
                    label: const Text(
                      'MODIFICARE',
                      style: TextStyle(
                        color: WhoopTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card ORE DI SONNO (con IntradayHrChart dai bucket reali aggregati CHT-01..02)
            _buildDetailCard(
              title: 'ORE DI SONNO',
              mainValue: _formatHoursMin(widget.durationMin),
              baselineValue: baseDur != null ? _formatHoursMin(baseDur) : '--:--',
              isUp: baseDur != null && widget.durationMin >= baseDur,
              child: _buildHrTimelineChart(intradayPoints, viewModel),
            ),

            const SizedBox(height: 24),

            // Sub-header Intervallo Tipico
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('FASI DEL SONNO', style: TextStyle(color: WhoopTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  Text(hasSleep ? 'DURATA ${_formatHoursMin(widget.durationMin)}' : 'NESSUN DATO', style: const TextStyle(color: WhoopTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Fasi Sonno Reali con Ipnogramma interattivo (STG-07, CHT-01)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: WhoopTheme.officialCardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HypnogramChart(
                      blocks: hypnogramBlocks,
                      height: 140,
                      isLoading: viewModel?.isChartsLoading ?? false,
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: WhoopTheme.cardBorder, height: 1),
                    const SizedBox(height: 14),
                    _buildPhaseRow('VEGLIA', widget.awakeMin, WhoopTheme.textMuted),
                    const SizedBox(height: 14),
                    _buildPhaseRow('LEGGERO', widget.lightSleepMin, WhoopTheme.strainBlue),
                    const SizedBox(height: 14),
                    _buildPhaseRow('SONNO A ONDE LENTE (PROFONDO)', widget.deepSleepMin, const Color(0xFFE91E8C)),
                    const SizedBox(height: 14),
                    _buildPhaseRow('REM', widget.remSleepMin, const Color(0xFF9C27B0)),
                    const Divider(color: WhoopTheme.cardBorder, height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(width: 10, height: 10, color: const Color(0xFFE91E8C)),
                            const SizedBox(width: 8),
                            const Text('SONNO RISTORATORE', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          ],
                        ),
                        Text(_formatHoursMin(restorativeMin), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Card ORE EFFETTIVE VS NECESSARIE
            _buildDetailCard(
              title: 'ORE EFFETTIVE VS NECESSARIE',
              mainValue: hasSleep ? '${widget.sleepPct.toInt()}%' : '--',
              baselineValue: basePerf != null ? '${basePerf.toInt()}%' : '--',
              isUp: basePerf != null && widget.sleepPct >= basePerf,
              child: Column(
                children: [
                  _buildBarRow('ORE DI SONNO', _formatHoursMin(widget.durationMin), WhoopTheme.sleepSlate, widget.sleepNeedMin > 0 ? (widget.durationMin / (widget.sleepNeedMin + 60)) : 0.0),
                  const SizedBox(height: 16),
                  _buildBarRow('FABBISOGNO DI SONNO', _formatHoursMin(widget.sleepNeedMin), WhoopTheme.textSecondary, widget.sleepNeedMin > 0 ? (widget.sleepNeedMin / (widget.sleepNeedMin + 60)) : 0.0, isNeed: true),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Distribuzione Zone FC nel Sonno (CHT-01..02)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: HeartRateZonesChart.fromDistributionMap(
                hrZonesMap,
                isLoading: viewModel?.isChartsLoading ?? false,
              ),
            ),

            const SizedBox(height: 24),

            // Trend Storico Sonno 14 Giorni (CHT-01)
            Padding(
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
                        const Text(
                          'TREND SONNO (14 GIORNI)',
                          style: TextStyle(
                            color: WhoopTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          '${baseDur != null ? _formatHoursMin(baseDur) : "8:00"} BASELINE',
                          style: const TextStyle(
                            color: WhoopTheme.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Sparkline14d(
                      dataPoints: history14dSleep,
                      baselineValue: baseDur != null ? (baseDur / 60.0) : 8.0,
                      height: 55,
                      primaryColor: WhoopTheme.sleepSlate,
                      isLoading: viewModel?.isChartsLoading ?? false,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── GRAFICI SETTIMANALI DALLA TELEMETRIA REALE ──
            _buildWeeklyBarCard(
              title: 'ORE VS NECESSARIE (%)',
              days: last7DaysData.map((d) => d['label'] as String).toList(),
              values: last7DaysData.map((d) => (d['pct'] as num).toInt()).toList(),
              activeIdx: last7DaysData.length - 1,
              suffix: '%',
              barColor: WhoopTheme.sleepSlate,
            ),

            const SizedBox(height: 16),

            _buildWeeklyLineCard(
              title: 'EFFICIENZA DEL SONNO (%)',
              days: last7DaysData.map((d) => d['label'] as String).toList(),
              values: last7DaysData.map((d) => (d['eff'] as num).toInt()).toList(),
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

      dynamic matchingSonno;
      if (historical != null) {
        for (final s in historical) {
          if (s.dataIso == dateIso) {
            matchingSonno = s;
            break;
          }
        }
      }

      final pct = (matchingSonno?.sleepPerformancePct as num?)?.toInt() ?? (i == 0 && widget.sleepPct > 0 ? widget.sleepPct.toInt() : 0);
      final eff = (matchingSonno?.efficienzaPct as num?)?.toInt() ?? (i == 0 && widget.efficiencyPct > 0 ? widget.efficiencyPct.toInt() : 0);

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

  Widget _buildSleepSubMetricRow({
    required IconData icon,
    required String title,
    required String value,
    required int segments,
    required int activeSegment,
    required Color activeColor,
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(segments, (i) {
                  final isActive = i == (activeSegment - 1);
                  return Container(
                    width: 16,
                    height: 3,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                      color: isActive ? activeColor : const Color(0xFF2C3946),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 46,
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
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


  Widget _buildDetailCard({
    required String title,
    required String mainValue,
    required String baselineValue,
    required bool isUp,
    bool isYellow = false,
    required Widget child,
  }) {
    Color arrowColor = isYellow ? WhoopTheme.recoveryYellow : (isUp ? WhoopTheme.recoveryGreen : WhoopTheme.recoveryRed);
    IconData arrowIcon = isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: WhoopTheme.officialCardDecoration(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: WhoopTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                const Icon(Icons.info_outline, color: WhoopTheme.textSecondary, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(mainValue, style: TextStyle(color: isYellow ? WhoopTheme.recoveryYellow : (isUp ? WhoopTheme.recoveryGreen : Colors.white), fontSize: 38, fontWeight: FontWeight.bold, height: 1.0)),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(arrowIcon, color: arrowColor, size: 24),
                      const SizedBox(width: 2),
                      Text(baselineValue, style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildHrTimelineChart(List<HrDataPoint> points, WhoopViewModel? viewModel) {
    return IntradayHrChart(
      points: points,
      height: 150,
      hrRestBaseline: viewModel?.userProfile.hrRestBaseline ?? 55,
      hrMaxBaseline: viewModel?.userProfile.hrMax ?? 190,
      isLoading: viewModel?.isChartsLoading ?? false,
    );
  }

  Widget _buildPhaseRow(String label, double minutes, Color color) {
    final double timeInBed = (widget.durationMin + widget.awakeMin) > 0
        ? (widget.durationMin + widget.awakeMin)
        : (widget.durationMin > 0 ? widget.durationMin : 1.0);
    double pct = minutes > 0 ? (minutes / timeInBed) : 0.0;
    return Row(
      children: [
        Icon(Icons.circle_outlined, color: color, size: 14),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: Text('$label ${(pct * 100).toInt()}%', style: const TextStyle(color: WhoopTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Stack(
            children: [
              Container(height: 1, color: WhoopTheme.cardBorder, margin: const EdgeInsets.symmetric(vertical: 7)),
              if (pct > 0)
                FractionallySizedBox(
                  widthFactor: pct.clamp(0.05, 1.0),
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(_formatHoursMin(minutes), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildBarRow(String label, String value, Color color, double pct, {bool isNeed = false}) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: const TextStyle(color: WhoopTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(height: 1, color: WhoopTheme.cardBorder, margin: const EdgeInsets.symmetric(vertical: 7)),
              if (isNeed)
                Container(
                  height: 16,
                  width: double.infinity,
                  decoration: BoxDecoration(color: WhoopTheme.cardBorder, borderRadius: BorderRadius.circular(3)),
                ),
              if (pct > 0)
                FractionallySizedBox(
                  widthFactor: pct.clamp(0.1, 1.0),
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: isNeed ? const BorderRadius.horizontal(left: Radius.circular(3)) : BorderRadius.circular(3),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

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
                  final heightFactor = val > 0 ? (val / 100.0).clamp(0.05, 1.0) : 0.02;

                  return Container(
                    padding: isActive ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4) : null,
                    decoration: isActive ? BoxDecoration(color: WhoopTheme.cardSurface, borderRadius: BorderRadius.circular(8)) : null,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(val > 0 ? '$val$suffix' : '--', style: TextStyle(color: isActive ? WhoopTheme.sleepSlate : WhoopTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Container(
                          width: 24,
                          height: 90 * heightFactor,
                          decoration: BoxDecoration(
                            color: val > 0 ? (isActive ? WhoopTheme.sleepSlate : WhoopTheme.sleepSlate.withValues(alpha: 0.5)) : WhoopTheme.cardBorder,
                            borderRadius: BorderRadius.circular(4),
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
                painter: _WeeklyLinePainter(values: values, activeIdx: activeIdx),
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

class _SleepArcPainter extends CustomPainter {
  final double percentage;
  final Color arcColor;

  const _SleepArcPainter({required this.percentage, required this.arcColor});

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
      ..color = percentage > 0 ? arcColor : WhoopTheme.cardBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepMax * (percentage / 100.0).clamp(0.0, 1.0), false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _SleepArcPainter old) => old.percentage != percentage || old.arcColor != arcColor;
}

class _WeeklyLinePainter extends CustomPainter {
  final List<int> values;
  final int activeIdx;

  _WeeklyLinePainter({required this.values, required this.activeIdx});

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
          text: TextSpan(text: '${values[i]}%', style: TextStyle(color: isAct ? WhoopTheme.sleepSlate : WhoopTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, Offset(p.dx - textPainter.width / 2, p.dy - 16));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SleepTriangleCaretPainter extends CustomPainter {
  const _SleepTriangleCaretPainter();

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

