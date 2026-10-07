import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/whoop_theme.dart';
import '../core/theme/nature_theme.dart';
import '../data/ble/ble_connection_manager.dart';
import '../data/biometrics/health_vitals_engine.dart';
import '../viewmodels/whoop_viewmodel.dart';
import 'widgets/whoop_header.dart';
import 'widgets/tri_ring_dial.dart';
import 'widgets/nature/nature_scene.dart';
import 'widgets/stress_wave_chart.dart';
import 'widgets/weekly_dual_axis_chart.dart';
import 'widgets/tonight_sleep_card.dart';
import 'widgets/recovery_detail_modal.dart';
import 'widgets/sleep_detail_modal.dart';
import 'widgets/strain_detail_modal.dart';
import 'widgets/whoop_fab_modal.dart';
import 'widgets/recovery_calendar_modal.dart';
import 'widgets/provenance_badge.dart';
import 'screens/health_vitals_detail_screen.dart';
import 'screens/activity_details_screen.dart';
import 'screens/journal_screen.dart';
import 'screens/profile_plan_screen.dart';
import 'screens/customizable_dashboard_screen.dart';
import 'screens/coach_screen.dart';
import 'screens/stress_monitor_screen.dart';
import 'screens/trends_screen.dart';
import 'screens/live_activity_tracker_screen.dart';
import 'screens/diagnostic_screen.dart';

/// Schermata Home WHOOP 5.0 (Rispecchia al 100% gli screenshot e i collegamenti del video in reference_UI)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedRingIndex = 1; // 0 = Sonno, 1 = Recupero, 2 = Sforzo

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'OGGI';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'IERI';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  NatureMood _getNatureMoodForRing(int ringIndex, double recovery) {
    if (ringIndex == 0) return NatureMood.sleep;
    if (ringIndex == 2) return NatureMood.strain;
    return NatureMood.recovery;
  }

  Widget _buildSunInsightCard(
    double recovery,
    double strain,
    double sleep,
    dynamic ciclo,
    bool isDark,
  ) {
    Color accentColor;
    IconData icon;
    String badgeTitle;
    String title;
    String body;

    if (ciclo != null && recovery > 0) {
      if (recovery >= 67) {
        accentColor = NatureColors.sage;
        icon = Icons.wb_sunny_rounded;
        badgeTitle = 'RECUPERO OTTIMALE';
        title = 'Il tuo corpo è pronto per risplendere';
        body =
            'Sistema nervoso autonomo in perfetto equilibrio. Le riserve fisiologiche sono elevate e pronte per assorbire intensità.';
      } else if (recovery >= 34) {
        accentColor = NatureColors.amberWarm;
        icon = Icons.wb_twilight_rounded;
        badgeTitle = 'CAPACITÀ BILANCIATA';
        title = 'Una giornata di ritmo controllato';
        body =
            'Capacità di sforzo equilibrata. Mantieni un\'intensità regolare per preservare energia e favorire il recupero stasera.';
      } else {
        accentColor = NatureColors.terracotta;
        icon = Icons.spa_outlined;
        badgeTitle = 'RIGENERAZIONE PRIORITARIA';
        title = 'Dai priorità al riposo oggi';
        body =
            'Le riserve fisiologiche sono contenute. Concentrati su idratazione, mobilità dolce e un riposo ristoratore tempestivo.';
      }
    } else {
      accentColor = NatureColors.powderBlue;
      icon = Icons.cloud_queue_rounded;
      badgeTitle = 'IN ATTESA DATI';
      title = 'Inizia a raccogliere i tuoi dati';
      body =
          'Collega il dispositivo per sincronizzare il tuo sonno o inserisci i dati per sbloccare la tua analisi fisiologica.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? NatureColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? NatureColors.darkBorderSubtle
              : accentColor.withValues(alpha: 0.18),
          width: 0.85,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.20)
                : const Color(0xFF1E2832).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header compatto con icona sole e badge
          Row(
            children: [
              Icon(icon, color: accentColor, size: 16),
              const SizedBox(width: 7),
              Text(
                'SUN INSIGHT',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 10.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  badgeTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? NatureColors.textDarkMuted : NatureColors.textLightMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          // Titolo Editoriale
          Text(
            title,
            style: TextStyle(
              color: isDark ? NatureColors.textDarkPrimary : NatureColors.textLightPrimary,
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 5),
          // Corpo Narrativo Calmo
          Text(
            body,
            style: TextStyle(
              color: isDark
                  ? NatureColors.textDarkSecondary
                  : NatureColors.textLightSecondary,
              fontSize: 13.0,
              height: 1.42,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WhoopViewModel>(
      builder: (context, viewModel, child) {
        return Scaffold(
          backgroundColor: WhoopTheme.background,
          body: SafeArea(
            child: _buildBody(context, viewModel),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, WhoopViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: WhoopTheme.strainBlue),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ciclo = viewModel.ultimoCiclo;
    final sonno = viewModel.sonnoList.isNotEmpty ? viewModel.sonnoList.first : null;
    final strain = ciclo?.sforzoGiornaliero ?? 0.0;
    final recovery = ciclo?.punteggioRecuperoPct ?? 0.0;
    final double sleepDurationMin = (sonno?.durataTotMin ?? 0).toDouble();
    final double sleep = (sleepDurationMin > 0 && sonno?.sleepPerformancePct != null)
        ? sonno!.sleepPerformancePct!
        : 0.0;

    return RefreshIndicator(
      onRefresh: () => viewModel.loadData(),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 90.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Official Header (GM avatar, flame 175, < OGGI >, 62% battery, WHOOP logo)
            WhoopHeader(
              currentDateLabel: _formatDateLabel(viewModel.selectedDate),
              selectedRingIndex: _selectedRingIndex,
              showRingSelectors: false,
              userInitials: viewModel.userName.length >= 2
                  ? viewModel.userName.substring(0, 2).toUpperCase()
                  : 'GM',
              streakDays: viewModel.streakDays,
              batteryPct: viewModel.batteryPct,
              bleConnected: viewModel.bleState == BleState.connected || viewModel.liveBpm > 0,
              onRingSelected: (idx) {
                setState(() => _selectedRingIndex = idx);
              },
              onAvatarTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePlanScreen()),
              ),
              onPreviousDate: () {
                viewModel.setSelectedDate(viewModel.selectedDate.subtract(const Duration(days: 1)));
              },
              onNextDate: _isToday(viewModel.selectedDate)
                  ? null
                  : () {
                      viewModel.setSelectedDate(viewModel.selectedDate.add(const Duration(days: 1)));
                    },
              onDateTap: () => RecoveryCalendarModal.show(context),
              onBatteryTap: () => DiagnosticScreen.navigateTo(context),
            ),

            const SizedBox(height: 8),

            // 2. Hero Nature Landscape & 3 Metric Rings Display (Ridotto del 10-15%)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: NatureScene(
                mood: _getNatureMoodForRing(_selectedRingIndex, recovery),
                intensity: (recovery > 0 ? (recovery / 100.0) : 0.70),
                height: 235,
                isDark: isDark,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Center(
                  child: TriRingDial(
                    strainScore: strain,
                    recoveryPct: recovery,
                    sleepPct: sleep,
                    liveBpm: viewModel.liveBpm,
                    calories: ciclo?.energiaBruciataCal ?? 0,
                    onTapRecovery: () => RecoveryDetailModal.show(
                      context,
                      recoveryPct: recovery,
                      hrvMs: (ciclo?.vfcMs != null && ciclo!.vfcMs! > 0) ? ciclo.vfcMs! : 0.0,
                      fcrBpm: (ciclo?.fcrBpm != null && ciclo!.fcrBpm! > 0) ? ciclo.fcrBpm! : 0,
                      respRateRpm: (ciclo?.frequenzaRespiratoriaRpm != null && ciclo!.frequenzaRespiratoriaRpm! > 0)
                          ? ciclo.frequenzaRespiratoriaRpm!
                          : 0.0,
                      spo2Pct: ciclo?.spo2Pct ?? 0.0,
                      tempDeltaC: ciclo?.tempCutaneaC ?? 0.0,
                      hrvBaseline: (viewModel.userProfile.baselineSampleCount >= 4 && viewModel.userProfile.hrvBaselineMean > 0)
                          ? viewModel.userProfile.hrvBaselineMean.toDouble()
                          : null,
                      fcrBaseline: (viewModel.userProfile.baselineSampleCount >= 4 && viewModel.userProfile.hrRestBaseline > 0)
                          ? viewModel.userProfile.hrRestBaseline
                          : null,
                      respRateBaseline: viewModel.userProfile.baselineSampleCount >= 4 ? 13.6 : null,
                      sleepPerformancePct: ciclo?.andamentoSonnoPct ?? (sleep > 0 ? sleep : null),
                      sleepPerfBaseline: viewModel.userProfile.baselineSampleCount >= 4 ? 75.0 : null,
                      historicalCicli: viewModel.cicliList,
                      provenance: ciclo?.provenance ?? 'REAL',
                    ),
                    onTapSleep: () => SleepDetailModal.show(
                      context,
                      startTime: sonno?.inizioSonno,
                      endTime: sonno?.inizioRisveglio,
                      sleepPct: sleep > 0 ? sleep : (sonno?.sleepPerformancePct ?? 0.0),
                      durationMin: (sonno?.durataTotMin != null && sonno!.durataTotMin > 0)
                          ? sonno.durataTotMin.toDouble()
                          : 0.0,
                      sleepNeedMin: ciclo?.sonnoRichiestoMin ?? viewModel.currentSleepNeedMinutes,
                      sleepDebtMin: ciclo?.sonnoArretratoMin ?? viewModel.accumulatedSleepDebtMinutes,
                      lightSleepMin: sonno?.sonnoLeggeroMin ?? 0.0,
                      deepSleepMin: sonno?.sonnoProfondoMinDouble ?? 0.0,
                      remSleepMin: sonno?.sonnoRemMinDouble ?? 0.0,
                      awakeMin: sonno?.vegliaMin ?? 0.0,
                      efficiencyPct: sonno?.efficienzaPct ??
                          ((sonno != null && sonno.tempoALettoMin > 0)
                              ? ((sonno.durataTotMin / sonno.tempoALettoMin) * 100).clamp(0.0, 100.0)
                              : 0.0),
                      consistencyPct: sonno?.regolaritaSonnoPct ?? 0.0,
                      baselineDurationMin: (viewModel.userProfile.baselineSampleCount >= 4 && viewModel.userProfile.sleepBaselineMin > 0)
                          ? viewModel.userProfile.sleepBaselineMin.toDouble()
                          : null,
                      baselinePerformancePct: viewModel.userProfile.baselineSampleCount >= 4 ? 80.0 : null,
                      historicalSonno: viewModel.sonnoList,
                      provenance: sonno?.provenance ?? (ciclo?.provenance ?? 'REAL'),
                    ),
                    onTapStrain: () => StrainDetailModal.show(
                      context,
                      dayStrain: strain,
                      fcMaxBpm: ciclo?.fcMaxBpm ?? (viewModel.liveBpm > 0 ? viewModel.liveBpm : 0),
                      fcMediaBpm: ciclo?.fcMediaBpm ?? (viewModel.liveBpm > 0 ? viewModel.liveBpm : 0),
                      caloriesTotal: ciclo?.energiaBruciataCal ?? 0,
                      steps: null,
                    ),
                  ),
                ),
              ),
            ),

            if (ciclo != null && ciclo.provenance.isNotEmpty) ...[
              const SizedBox(height: 6),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'RECUPERO: ',
                      style: TextStyle(
                        color: WhoopTheme.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    ProvenanceBadge(provenance: ciclo.provenance),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Sun Insights — L'UNICO Sistema di Insight nella Home (Dati Reali e Ottimismo Fisiologico)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildSunInsightCard(recovery, strain, sleep, ciclo, isDark),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 4. Due Card Affiancate con Navigazione Diretta alle Dashboard
                  Row(
                    children: [
                      // Monitoraggio della Salute -> Naviga a HealthVitalsDetailScreen
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const HealthVitalsDetailScreen()),
                            );
                          },
                          child: Builder(
                            builder: (context) {
                              final vitals = viewModel.vitalEvaluations;
                              final inRange = vitals.where((v) => v.status == VitalStatus.inRange).length;
                              final calibration = vitals.where((v) => v.status == VitalStatus.calibration).length;
                              final noData = vitals.where((v) => v.status == VitalStatus.noData).length;

                              String sTitle;
                              Color sColor;
                              String sSubtitle;
                              IconData iconData;

                              if (noData == vitals.length) {
                                sTitle = 'IN ATTESA';
                                sColor = WhoopTheme.textMuted;
                                sSubtitle = 'In attesa dati';
                                iconData = Icons.schedule;
                              } else if (calibration > 0) {
                                sTitle = 'CALIBRAZIONE';
                                sColor = WhoopTheme.strainBlue;
                                sSubtitle = '${vitals.first.sampleCount}/7 giorni';
                                iconData = Icons.tune;
                              } else if (inRange == vitals.length) {
                                sTitle = 'NELLA NORMA';
                                sColor = WhoopTheme.recoveryGreen;
                                sSubtitle = '5/5 Parametri';
                                iconData = Icons.check;
                              } else {
                                sTitle = 'FUORI NORMA';
                                sColor = WhoopTheme.recoveryRed;
                                sSubtitle = '$inRange/5 in norma';
                                iconData = Icons.warning_amber_rounded;
                              }

                              return _buildSquareStatusCard(
                                title: 'MONITORAGGIO\nDELLA SALUTE',
                                badgeWidget: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: sColor.withValues(alpha: isDark ? 0.22 : 0.14),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    iconData,
                                    color: sColor,
                                    size: 15,
                                  ),
                                ),
                                statusTitle: sTitle,
                                statusColor: sColor,
                                statusSubtitle: sSubtitle,
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Monitoraggio dello Stress -> Naviga a StressMonitorScreen (24h Stress Tracking)
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            final stress = viewModel.currentStressScore;
                            StressMonitorScreen.show(context, stressScore: stress);
                          },
                          child: Builder(
                            builder: (context) {
                              final stressScore = viewModel.currentStressScore;
                              final now = DateTime.now();
                              final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

                              String sTitle;
                              Color sColor;

                              if (stressScore > 0) {
                                sTitle = stressScore < 1.3 ? 'BASSO' : 'MEDIO';
                                sColor = stressScore < 1.3 ? NatureColors.teal : NatureColors.amberWarm;
                              } else {
                                sTitle = 'IN ATTESA';
                                sColor = WhoopTheme.textMuted;
                              }

                              final scoreText = stressScore > 0
                                  ? stressScore.toStringAsFixed(1).replaceAll('.', ',')
                                  : '--';

                              return _buildSquareStatusCard(
                                title: 'MONITORAGGIO\nDELLO STRESS',
                                badgeWidget: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: sColor.withValues(alpha: isDark ? 0.20 : 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: sColor.withValues(alpha: 0.35), width: 0.8),
                                  ),
                                  child: Text(
                                    scoreText,
                                    style: TextStyle(
                                      color: sColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ),
                                statusTitle: sTitle,
                                statusColor: sColor,
                                statusSubtitle: timeStr,
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 5. Sezione "La mia giornata" + Button (+)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'La mia giornata',
                          style: TextStyle(
                            color: isDark ? NatureColors.textDarkPrimary : NatureColors.textLightPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => WhoopFabModal.show(context),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isDark ? NatureColors.darkSurfaceRaised : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? NatureColors.darkBorderSubtle : NatureColors.sandBorder,
                              width: 0.85,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E2832).withValues(alpha: isDark ? 0.20 : 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(Icons.add, color: isDark ? Colors.white : NatureColors.textLightPrimary, size: 18),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Banner: "Le tue prospettive giornaliere >" in gradiente bronzo
                  _buildDailyProspectsBanner(ciclo),

                  const SizedBox(height: 12),

                  // Card: "ATTIVITÀ DI OGGI" ↗ (Sonno 8:24, Allenamenti Rilevati, Aggiungi Attività, Inizia Attività)
                  _buildTodayActivitiesCard(context, ciclo, sleep, viewModel),

                  const SizedBox(height: 12),

                  // Card: "SONNO DI STANOTTE" > (Ora consigliata calcolata matematicamente)
                  TonightSleepCard(
                    sleepNeedMinutes: viewModel.currentSleepNeedMinutes > 0
                        ? viewModel.currentSleepNeedMinutes
                        : viewModel.userProfile.sleepBaselineMin.toDouble(),
                  ),

                  const SizedBox(height: 16),

                  // 6. Sezione "Il mio diario >"
                  _buildJournalSection(),

                  const SizedBox(height: 16),



                  // 8. Card "CALORIE"
                  _buildCaloriesCard(ciclo?.energiaBruciataCal ?? 0),

                  const SizedBox(height: 16),

                  // 9. Card "MONITORAGGIO DELLO STRESS >"
                  GestureDetector(
                    onTap: () => StressMonitorScreen.show(
                      context,
                      stressScore: viewModel.currentStressScore,
                    ),
                    child: StressWaveChart(
                      currentStress: viewModel.currentStressScore,
                      peakStress: viewModel.currentStressScore,
                      peakTimeLabel: 'OGGI',
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 10. Card "SFORZO E RECUPERO" ⓘ
                  const WeeklyDualAxisChart(),

                  const SizedBox(height: 16),

                  // 11. Sezione "La mia dashboard" PERSONALIZZA 🖊️
                  _buildDashboardSection(ciclo, viewModel),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card Quadrata per Salute e Stress (Stile Ufficiale Whoop 5.0)
  Widget _buildSquareStatusCard({
    required String title,
    required Widget badgeWidget,
    required String statusTitle,
    required Color statusColor,
    required String statusSubtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: WhoopTheme.officialCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: WhoopTheme.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    height: 1.2,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: WhoopTheme.textSecondary, size: 18),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              badgeWidget,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusSubtitle,
                      style: const TextStyle(
                        color: WhoopTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Banner Prospettive Giornaliere — naviga a CoachScreen
  Widget _buildDailyProspectsBanner(dynamic ciclo) {
    final hasRecovery = ciclo?.punteggioRecuperoPct != null;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CoachScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: isLight
            ? BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: NatureColors.sandBorder, width: 0.85),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06182228),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              )
            : BoxDecoration(
                color: NatureColors.darkCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: WhoopTheme.cardBorder, width: 0.85),
              ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: hasRecovery
                    ? (isLight ? NatureColors.amberBackground : const Color(0xFF332B22))
                    : (isLight ? NatureColors.creamLight : const Color(0xFF1B2329)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasRecovery ? Icons.wb_sunny_outlined : Icons.schedule,
                color: hasRecovery
                    ? (isLight ? NatureColors.amberWarm : const Color(0xFFE5B17B))
                    : WhoopTheme.textMuted,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasRecovery ? 'PROSPETTIVE GIORNALIERE' : 'IN ATTESA DI CALCOLO',
                    style: TextStyle(
                      color: hasRecovery
                          ? (isLight ? NatureColors.amberWarm : const Color(0xFFE5B17B))
                          : WhoopTheme.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.9,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasRecovery ? 'Guida e previsioni per oggi' : 'In attesa di calcolo del sonno',
                    style: const TextStyle(
                      color: WhoopTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: isLight ? NatureColors.textLightMuted : const Color(0xFFC7B39E),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// Card Calorie Bruciate e Target Giornaliero (Stile Ufficiale Whoop 5.0)
  Widget _buildCaloriesCard(int calories, {int? targetCal}) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: WhoopTheme.officialCardDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isLight ? NatureColors.terracottaBackground : const Color(0xFF261D1A),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_fire_department_outlined,
                  color: isLight ? NatureColors.terracotta : WhoopTheme.textSecondary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'CALORIE',
                style: TextStyle(
                  color: WhoopTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    calories > 0 ? '$calories' : '--',
                    style: const TextStyle(
                      color: WhoopTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_drop_down, color: WhoopTheme.textSecondary, size: 18),
                ],
              ),
              Text(
                (targetCal != null && targetCal > 0) ? 'Target $targetCal' : 'Target --',
                style: const TextStyle(
                  color: WhoopTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Card Attività di Oggi (Stile Ufficiale Whoop 5.0)
  Widget _buildTodayActivitiesCard(BuildContext context, dynamic ciclo, double sleep, WhoopViewModel viewModel) {
    final allenamenti = viewModel.allenamentiList;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: WhoopTheme.officialCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ATTIVITÀ DI OGGI',
                style: TextStyle(
                  color: WhoopTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.open_in_full, color: WhoopTheme.textSecondary, size: 16),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Item Sonno -> Identico al reference Home - Attività del Giorno e Sonno di Stanotte.jpeg
          Builder(
            builder: (context) {
              final sonno = viewModel.sonnoList.isNotEmpty ? viewModel.sonnoList.first : null;
              final double sleepMin = (sonno?.durataTotMin ?? 0).toDouble();
              final bool hasSleep = sleepMin > 0;
              final int sleepHours = hasSleep ? (sleepMin / 60).floor() : 0;
              final int sleepRemMin = hasSleep ? (sleepMin % 60).round() : 0;
              final String sleepFormattedText = hasSleep ? '$sleepHours:${sleepRemMin.toString().padLeft(2, '0')}' : '--:--';
              final double sleepPct = (hasSleep && sonno?.sleepPerformancePct != null)
                  ? sonno!.sleepPerformancePct!
                  : 0.0;
              final String startHourStr = (hasSleep && sonno != null && sonno.oraInizio.isNotEmpty)
                  ? '${sonno.inizioSonno.hour}:${sonno.inizioSonno.minute.toString().padLeft(2, '0')}'
                  : '--:--';
              final String endHourStr = (hasSleep && sonno != null && sonno.oraFine.isNotEmpty)
                  ? '${sonno.inizioRisveglio.hour}:${sonno.inizioRisveglio.minute.toString().padLeft(2, '0')}'
                  : '--:--';

              return GestureDetector(
                onTap: () => SleepDetailModal.show(
                  context,
                  startTime: sonno?.inizioSonno,
                  endTime: sonno?.inizioRisveglio,
                  sleepPct: sleepPct,
                  durationMin: sleepMin,
                  sleepNeedMin: ciclo?.sonnoRichiestoMin ?? viewModel.currentSleepNeedMinutes,
                  sleepDebtMin: ciclo?.sonnoArretratoMin ?? viewModel.accumulatedSleepDebtMinutes,
                  lightSleepMin: sonno?.sonnoLeggeroMin ?? 0.0,
                  deepSleepMin: sonno?.sonnoProfondoMinDouble ?? 0.0,
                  remSleepMin: sonno?.sonnoRemMinDouble ?? 0.0,
                  awakeMin: sonno?.vegliaMin ?? 0.0,
                  efficiencyPct: sonno?.efficienzaPct ??
                      ((sonno != null && sonno.tempoALettoMin > 0)
                          ? ((sonno.durataTotMin / sonno.tempoALettoMin) * 100).clamp(0.0, 100.0)
                          : 0.0),
                  consistencyPct: sonno?.regolaritaSonnoPct ?? 0.0,
                  baselineDurationMin: (viewModel.userProfile.baselineSampleCount >= 4 && viewModel.userProfile.sleepBaselineMin > 0)
                      ? viewModel.userProfile.sleepBaselineMin.toDouble()
                      : null,
                  baselinePerformancePct: viewModel.userProfile.baselineSampleCount >= 4 ? 80.0 : null,
                  historicalSonno: viewModel.sonnoList,
                  provenance: sonno?.provenance ?? (ciclo?.provenance ?? 'REAL'),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isLight ? NatureColors.creamLight : const Color(0xFF161E24),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isLight ? NatureColors.sandBorderSubtle : const Color(0xFF26333D),
                      width: 0.85,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Badge Pillola Blu Sonno con Icona Luna
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isLight ? NatureColors.tealBackground : const Color(0xFF5D849E),
                          borderRadius: BorderRadius.circular(8),
                          border: isLight ? Border.all(color: NatureColors.teal.withOpacity(0.3), width: 0.8) : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.nightlight_round,
                              color: isLight ? NatureColors.tealDark : Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              sleepFormattedText,
                              style: TextStyle(
                                color: isLight ? NatureColors.tealDark : Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Row(
                          children: [
                            const Text(
                              'SONNO',
                              style: TextStyle(
                                color: WhoopTheme.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            if (sonno != null && sonno.provenance.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              ProvenanceBadge(provenance: sonno.provenance),
                            ],
                          ],
                        ),
                      ),
                      // Orari Inizio e Fine (es. 0:52 | 10:32)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            startHourStr,
                            style: const TextStyle(
                              color: WhoopTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 6,
                            color: isLight ? NatureColors.sandBorder : WhoopTheme.cardBorder,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                          ),
                          Text(
                            endHourStr,
                            style: const TextStyle(
                              color: WhoopTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Lista Allenamenti Rilevati/Registrati
          if (allenamenti.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...allenamenti.map((a) {
              final strainVal = a.strainAttivita ?? a.sforzoRichiesto ?? 0.0;
              return GestureDetector(
                onTap: () => ActivityDetailsScreen.show(
                  context,
                  activityName: a.nomeAttivita,
                  activityStrain: strainVal,
                  durationText: '${a.durataMin} min',
                  fcMaxBpm: a.hrMax ?? a.fcMaxBpm ?? 0,
                  fcMediaBpm: a.hrMedia ?? a.fcMediaBpm ?? 0,
                  caloriesBurned: a.calorie ?? a.energiaBruciataCal ?? 0,
                  zoneZ1Pct: a.zoneZ1Pct,
                  zoneZ2Pct: a.zoneZ2Pct,
                  zoneZ3Pct: a.zoneZ3Pct,
                  zoneZ4Pct: a.zoneZ4Pct,
                  zoneZ5Pct: a.zoneZ5Pct,
                  durationMin: a.durataMin,
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isLight ? NatureColors.creamLight : const Color(0xFF161E24),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isLight ? NatureColors.sandBorderSubtle : WhoopTheme.strainBlue.withOpacity(0.35),
                      width: 0.85,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.fitness_center,
                            color: isLight ? NatureColors.amberWarm : WhoopTheme.strainBlue,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            a.nomeAttivita.toUpperCase(),
                            style: const TextStyle(
                              color: WhoopTheme.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${a.durataMin} min',
                            style: const TextStyle(color: WhoopTheme.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                      Text(
                        'Sforzo ${strainVal.toStringAsFixed(1)}',
                        style: TextStyle(
                          color: isLight ? NatureColors.amberWarm : WhoopTheme.strainBlue,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],

          const SizedBox(height: 14),

          // Tasti Azione: + AGGIUNGI ATTIVITÀ | ⏱ INIZIA ATTIVITÀ
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => WhoopFabModal.show(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isLight ? Colors.white : const Color(0xFF222B32),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isLight ? NatureColors.sandBorder : const Color(0xFF2E3842),
                        width: 0.85,
                      ),
                      boxShadow: isLight
                          ? const [
                              BoxShadow(
                                color: Color(0x06182228),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, size: 14, color: WhoopTheme.textPrimary),
                            SizedBox(width: 6),
                            Text(
                              'AGGIUNGI ATTIVITÀ',
                              style: TextStyle(
                                color: WhoopTheme.textPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => LiveActivityTrackerScreen.start(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isLight ? Colors.white : const Color(0xFF222B32),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isLight ? NatureColors.sandBorder : const Color(0xFF2E3842),
                        width: 0.85,
                      ),
                      boxShadow: isLight
                          ? const [
                              BoxShadow(
                                color: Color(0x06182228),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.timer_outlined, size: 14, color: WhoopTheme.textPrimary),
                            SizedBox(width: 6),
                            Text(
                              'INIZIA ATTIVITÀ',
                              style: TextStyle(
                                color: WhoopTheme.textPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Sezione Diario — naviga a JournalScreen
  Widget _buildJournalSection() {
    final viewModel = Provider.of<WhoopViewModel>(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final now = DateTime.now();
    final todayIso = now.toIso8601String().substring(0, 10);

    final italianDayNames = ['LUN', 'MAR', 'MER', 'GIO', 'VEN', 'SAB', 'DOM'];
    final past7Days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      final iso = d.toIso8601String().substring(0, 10);
      final weekdayName = italianDayNames[(d.weekday - 1) % 7];
      final isToday = iso == todayIso;
      final isCompleted = viewModel.completedDiaryDates.contains(iso);
      return (name: weekdayName, iso: iso, isToday: isToday, isCompleted: isCompleted);
    });

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const JournalScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: WhoopTheme.officialCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'IL MIO DIARIO',
                  style: TextStyle(
                    color: WhoopTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                Icon(Icons.chevron_right, color: WhoopTheme.textSecondary, size: 20),
              ],
            ),
            const SizedBox(height: 14),

            // Giorni della settimana reali agganciati al database
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: past7Days.map((day) {
                final isToday = day.isToday;
                final isCompleted = day.isCompleted;

                return Column(
                  children: [
                    Text(
                      day.name,
                      style: TextStyle(
                        color: isToday ? WhoopTheme.textPrimary : WhoopTheme.textMuted,
                        fontSize: 10,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? (isLight ? NatureColors.sage : WhoopTheme.recoveryGreen)
                            : (isToday
                                ? (isLight ? NatureColors.creamLight : NatureColors.darkCard)
                                : Colors.transparent),
                        border: Border.all(
                          color: isCompleted
                              ? (isLight ? NatureColors.sageDark : WhoopTheme.recoveryGreen)
                              : (isToday
                                  ? WhoopTheme.textPrimary
                                  : (isLight ? NatureColors.sandBorder : WhoopTheme.cardBorder)),
                          width: isToday || isCompleted ? 1.5 : 1.0,
                        ),
                      ),
                      child: isCompleted
                          ? const Center(
                              child: Icon(Icons.check, size: 14, color: Colors.white),
                            )
                          : (isToday
                              ? Center(
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: WhoopTheme.textPrimary,
                                    ),
                                  ),
                                )
                              : null),
                    ),
                  ],
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const JournalScreen()),
              ),
              icon: const Icon(Icons.lightbulb_outline, size: 16, color: WhoopTheme.textPrimary),
              label: const Text(
                'APPROFONDIMENTI SUL COMPORTAMENTO',
                style: TextStyle(
                  color: WhoopTheme.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: isLight ? NatureColors.sandBorder : WhoopTheme.cardBorder,
                  width: 0.85,
                ),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sezione Dashboard Personalizzabile Metriche
  Widget _buildDashboardSection(dynamic ciclo, WhoopViewModel viewModel) {
    final double vfcMs = (ciclo?.vfcMs ?? 0.0).toDouble();
    final int fcrBpm = ciclo?.fcrBpm ?? 0;
    final double punteggioRecuperoPct = (ciclo?.punteggioRecuperoPct ?? 0.0).toDouble();
    final double sforzoGiornaliero = (ciclo?.sforzoGiornaliero ?? 0.0).toDouble();
    final int energiaBruciataCal = ciclo?.energiaBruciataCal ?? 0;
    final double sonnoRichiestoMin = (ciclo?.sonnoRichiestoMin ?? 0.0).toDouble();
    final double sonnoArretratoMin = (ciclo?.sonnoArretratoMin ?? 0.0).toDouble();
    final double frequenzaRespiratoriaRpm = (ciclo?.frequenzaRespiratoriaRpm ?? 0.0).toDouble();
    final double sonnoProfondoMin = (ciclo?.sonnoProfondoMin ?? 0.0).toDouble();
    final double sonnoRemMin = (ciclo?.sonnoRemMin ?? 0.0).toDouble();
    final double efficienzaSonnoPct = (ciclo?.efficienzaSonnoPct ?? 0.0).toDouble();

    final bool hasData = ciclo != null && (vfcMs > 0 || fcrBpm > 0 || punteggioRecuperoPct > 0 || sforzoGiornaliero > 0);
    final profile = viewModel.userProfile;
    final bool isCalibrated = profile.baselineSampleCount >= 4;

    final allMetrics = [
      {
        'key': 'vfc',
        'title': 'VARIABILITÀ DELLA FREQUENZA CARDIACA',
        'metricName': 'Variabilità FC (VFC)',
        'val': hasData && vfcMs > 0 ? '${vfcMs.toInt()}' : '--',
        'base': isCalibrated ? '${profile.hrvBaselineMean.toInt()} ms' : 'In calibrazione',
        'arrow': hasData && vfcMs > 0 && isCalibrated ? (vfcMs >= profile.hrvBaselineMean ? '▲' : '▼') : '•',
        'color': hasData && vfcMs > 0 && isCalibrated ? (vfcMs >= profile.hrvBaselineMean ? WhoopTheme.recoveryGreen : WhoopTheme.recoveryYellow) : WhoopTheme.textSecondary,
      },
      {
        'key': 'fcr',
        'title': 'FREQUENZA CARDIACA A RIPOSO',
        'metricName': 'FC a Riposo (FCR)',
        'val': hasData && fcrBpm > 0 ? '$fcrBpm' : '--',
        'base': isCalibrated ? '${profile.hrRestBaseline} bpm' : 'In calibrazione',
        'arrow': hasData && fcrBpm > 0 && isCalibrated ? (fcrBpm <= profile.hrRestBaseline ? '▼' : '▲') : '•',
        'color': hasData && fcrBpm > 0 && isCalibrated ? (fcrBpm <= profile.hrRestBaseline ? WhoopTheme.recoveryGreen : WhoopTheme.recoveryYellow) : WhoopTheme.textSecondary,
      },
      {
        'key': 'steps',
        'title': 'PASSI GIORNALIERI',
        'metricName': 'Passi Giornalieri',
        'val': '--',
        'base': 'Nessun pedometro hardware',
        'arrow': '•',
        'color': WhoopTheme.textSecondary,
      },
      {
        'key': 'zone_fc_low',
        'title': 'ZONE FC 1-3 (SETTIMANALE)',
        'metricName': 'Zone FC 1–3',
        'val': '--',
        'base': 'Target 3:00',
        'arrow': '•',
        'color': WhoopTheme.textSecondary,
      },
      {
        'key': 'zone_fc_high',
        'title': 'ZONE FC 4-5 (SETTIMANALE)',
        'metricName': 'Zone FC 4–5',
        'val': '--',
        'base': 'Target 0:30',
        'arrow': '•',
        'color': WhoopTheme.textSecondary,
      },
      {
        'key': 'vo2max',
        'title': 'VO₂ MAX',
        'metricName': 'VO₂ Max Stimato',
        'val': '--',
        'base': 'Baseline --',
        'arrow': '•',
        'color': WhoopTheme.textPrimary,
      },
      {
        'key': 'calories',
        'title': 'CALORIE / DISPENDIO ENERGETICO',
        'metricName': 'Dispendio Energetico',
        'val': hasData && energiaBruciataCal > 0 ? '$energiaBruciataCal' : '--',
        'base': 'Target 2.200 kcal',
        'arrow': hasData ? '▲' : '•',
        'color': WhoopTheme.textSecondary,
      },
      {
        'key': 'sleep_need',
        'title': 'FABBISOGNO DI SONNO',
        'metricName': 'Fabbisogno di Sonno',
        'val': hasData && sonnoRichiestoMin > 0 ? '${(sonnoRichiestoMin / 60).floor()}:${(sonnoRichiestoMin % 60).round().toString().padLeft(2, '0')}' : '--',
        'base': isCalibrated ? '${(profile.sleepBaselineMin / 60).floor()}h ${(profile.sleepBaselineMin % 60)}m' : 'In calibrazione',
        'arrow': '•',
        'color': WhoopTheme.textSecondary,
      },
      {
        'key': 'recovery',
        'title': 'RECUPERO',
        'metricName': 'Recupero',
        'val': hasData && punteggioRecuperoPct > 0 ? '${punteggioRecuperoPct.toInt()}%' : '--',
        'base': isCalibrated ? 'Baseline 65%' : 'In calibrazione',
        'arrow': hasData && punteggioRecuperoPct > 0 && isCalibrated ? (punteggioRecuperoPct >= 65 ? '▲' : '▼') : '•',
        'color': hasData && punteggioRecuperoPct > 0 && isCalibrated ? (punteggioRecuperoPct >= 65 ? WhoopTheme.recoveryGreen : WhoopTheme.recoveryYellow) : WhoopTheme.textSecondary,
      },
      {
        'key': 'sleep_debt',
        'title': 'SONNO ARRETRATO',
        'metricName': 'Sonno Arretrato',
        'val': hasData && sonnoArretratoMin > 0 ? '${sonnoArretratoMin.toInt()}m' : '0m',
        'base': '0 min',
        'arrow': '•',
        'color': WhoopTheme.textSecondary,
      },
      {
        'key': 'resp_rate',
        'title': 'FREQUENZA RESPIRATORIA',
        'metricName': 'Frequenza Respiratoria',
        'val': hasData && frequenzaRespiratoriaRpm > 0 ? '${frequenzaRespiratoriaRpm.toStringAsFixed(1)} rpm' : '--',
        'base': isCalibrated ? '14.0 rpm' : 'In calibrazione',
        'arrow': '•',
        'color': WhoopTheme.textPrimary,
      },
      {
        'key': 'skin_temp',
        'title': 'TEMPERATURA CUTANEA',
        'metricName': 'Temperatura Cutanea',
        'val': (hasData && ciclo?.tempCutaneaC != null) ? '${ciclo!.tempCutaneaC! >= 0 ? '+' : ''}${ciclo.tempCutaneaC!.toStringAsFixed(1)} °C' : '--',
        'base': isCalibrated ? '0.0 °C' : 'In calibrazione',
        'arrow': '•',
        'color': WhoopTheme.textPrimary,
      },
      {
        'key': 'spo2',
        'title': 'OSSIGENO NEL SANGUE (SPO₂)',
        'metricName': 'Ossigeno nel Sangue (SpO₂)',
        'val': (hasData && ciclo?.spo2Pct != null && ciclo!.spo2Pct! > 0) ? '${ciclo.spo2Pct!.round()}%' : '--',
        'base': isCalibrated ? '96%' : 'In calibrazione',
        'arrow': '•',
        'color': WhoopTheme.strainBlue,
      },
      {
        'key': 'deep_sleep',
        'title': 'SONNO PROFONDO (SWS)',
        'metricName': 'Sonno Profondo (SWS)',
        'val': hasData && sonnoProfondoMin > 0 ? '${(sonnoProfondoMin / 60).floor()}h ${(sonnoProfondoMin % 60).round()}m' : '--',
        'base': 'Target 1h 30m',
        'arrow': '•',
        'color': WhoopTheme.strainBlue,
      },
      {
        'key': 'rem_sleep',
        'title': 'SONNO REM',
        'metricName': 'Sonno REM',
        'val': hasData && sonnoRemMin > 0 ? '${(sonnoRemMin / 60).floor()}h ${(sonnoRemMin % 60).round()}m' : '--',
        'base': 'Target 2h 00m',
        'arrow': '•',
        'color': WhoopTheme.strainBlue,
      },
      {
        'key': 'sleep_efficiency',
        'title': 'EFFICIENZA SONNO',
        'metricName': 'Efficienza del Sonno',
        'val': hasData && efficienzaSonnoPct > 0 ? '${efficienzaSonnoPct.toInt()}%' : '--',
        'base': 'Target 90%',
        'arrow': '•',
        'color': WhoopTheme.recoveryGreen,
      },
    ];

    final enabledKeys = viewModel.enabledTileKeys;
    final metrics = allMetrics.where((m) => enabledKeys.contains(m['key'])).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'La mia dashboard',
                style: WhoopTheme.cardTitleStyle(fontSize: 16, color: WhoopTheme.textPrimary),
              ),
            ),
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CustomizableDashboardScreen()),
              ),
              icon: const Icon(Icons.edit_outlined, size: 14, color: WhoopTheme.textPrimary),
              label: const Text('PERSONALIZZA', style: TextStyle(color: WhoopTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final m = metrics[index];
            return GestureDetector(
              onTap: () => TrendsScreen.show(context, initialMetric: m['metricName'] as String),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: WhoopTheme.officialCardDecoration(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        m['title'] as String,
                        style: const TextStyle(
                          color: WhoopTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Text(
                              m['val'] as String,
                              style: const TextStyle(
                                color: WhoopTheme.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              m['arrow'] as String,
                              style: TextStyle(
                                color: m['color'] as Color,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          m['base'] as String,
                          style: const TextStyle(
                            color: WhoopTheme.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
