import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/whoop_theme.dart';
import '../data/ble/ble_connection_manager.dart';
import '../data/biometrics/health_vitals_engine.dart';
import '../viewmodels/whoop_viewmodel.dart';
import 'widgets/whoop_header.dart';
import 'widgets/tri_ring_dial.dart';
import 'widgets/stress_wave_chart.dart';
import 'widgets/weekly_dual_axis_chart.dart';
import 'widgets/tonight_sleep_card.dart';
import 'widgets/recovery_detail_modal.dart';
import 'widgets/sleep_detail_modal.dart';
import 'widgets/strain_detail_modal.dart';
import 'widgets/whoop_fab_modal.dart';
import 'screens/health_vitals_detail_screen.dart';
import 'screens/activity_details_screen.dart';
import 'screens/journal_screen.dart';
import 'screens/profile_plan_screen.dart';
import 'screens/customizable_dashboard_screen.dart';
import 'screens/coach_screen.dart';
import 'screens/stress_monitor_screen.dart';
import 'screens/trends_screen.dart';
import 'screens/live_activity_tracker_screen.dart';
import 'device/device_screen.dart';

/// Schermata Home WHOOP 5.0 (Rispecchia al 100% gli screenshot e i collegamenti del video in reference_UI)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedRingIndex = 1; // 0 = Sonno, 1 = Recupero, 2 = Sforzo

  // Lista Notifiche/Insight sfogliabili e rimuovibili con Swipe
  final List<Map<String, String>> _notifications = [
    {
      'id': '1',
      'title': 'VFC elevata',
      'badge': '1',
      'body': 'La tua VFC è 6% più elevata del solito, il che indica un recupero massimo. Una VFC elevata indica che il tuo corpo è in equilibrio e il recupero completo.',
    },
    {
      'id': '2',
      'title': 'Prontezza Recupero 82%',
      'badge': '2',
      'body': 'Il tuo sistema nervoso autonomo è in condizioni ottimali. Il target di Sforzo consigliato per oggi è tra 15.0 e 17.5.',
    },
    {
      'id': '3',
      'title': 'Fabbisogno Sonno Ottimizzato',
      'badge': '3',
      'body': 'In base all\'attività recente hai 30 minuti di sonno arretrato. Ti consigliamo di coricarti entro le 22:28.',
    },
  ];

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
            // 1. Official Header (GM avatar, flame 175, < OGGI >, 62% battery, \V/HOOP logo)
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
              onDateTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: viewModel.selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  builder: (context, child) => Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: WhoopTheme.strainBlue,
                        surface: WhoopTheme.cardSurface,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  viewModel.setSelectedDate(picked);
                }
              },
              onBatteryTap: () => DeviceScreen.navigateTo(context),
            ),

            const SizedBox(height: 8),

            // 2. Hero Metric Rings Display (3 Anelli Singoli Affiancati)
            Center(
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
                  hrvBaseline: viewModel.userProfile.hrvBaselineMean > 0 ? viewModel.userProfile.hrvBaselineMean.toDouble() : 72.0,
                  fcrBaseline: viewModel.userProfile.hrRestBaseline > 0 ? viewModel.userProfile.hrRestBaseline : 53,
                  respRateBaseline: 13.6,
                  sleepPerformancePct: ciclo?.andamentoSonnoPct ?? sleep,
                  sleepPerfBaseline: 75.0,
                  historicalCicli: viewModel.cicliList,
                ),
                onTapSleep: () => SleepDetailModal.show(
                  context,
                  sleepPct: sleep > 0 ? sleep : (sonno?.sleepPerformancePct ?? 0.0),
                  durationMin: (sonno?.durataTotMin != null && sonno!.durataTotMin > 0)
                      ? sonno.durataTotMin.toDouble()
                      : 0.0,
                  sleepNeedMin: ciclo?.sonnoRichiestoMin ?? viewModel.currentSleepNeedMinutes,
                  sleepDebtMin: ciclo?.sonnoArretratoMin ?? 0.0,
                  lightSleepMin: sonno?.sonnoLeggeroMin ?? 0.0,
                  deepSleepMin: sonno?.sonnoProfondoMinDouble ?? 0.0,
                  remSleepMin: sonno?.sonnoRemMinDouble ?? 0.0,
                  awakeMin: sonno?.vegliaMin ?? 0.0,
                  efficiencyPct: sonno?.efficienzaPct ??
                      ((sonno != null && sonno.tempoALettoMin > 0)
                          ? ((sonno.durataTotMin / sonno.tempoALettoMin) * 100).clamp(0.0, 100.0)
                          : 0.0),
                  consistencyPct: sonno?.regolaritaSonnoPct ?? 0.0,
                  baselineDurationMin: viewModel.userProfile.sleepBaselineMin > 0
                      ? viewModel.userProfile.sleepBaselineMin.toDouble()
                      : 480.0,
                  baselinePerformancePct: 80.0,
                  historicalSonno: viewModel.sonnoList,
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

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 3. Card Notifiche/Insight Dismissibili (Swipe a destra per rimuovere)
                  if (_notifications.isNotEmpty) _buildDismissibleNotificationCard(),

                  const SizedBox(height: 12),

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
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: sColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    iconData,
                                    color: sColor == WhoopTheme.textMuted ? Colors.white : Colors.black,
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
                                sColor = stressScore < 1.3 ? WhoopTheme.strainBlue : WhoopTheme.recoveryYellow;
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
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF142434),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: WhoopTheme.strainBlue, width: 1.2),
                                  ),
                                  child: Text(
                                    scoreText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      fontFeatures: [FontFeature.tabularFigures()],
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

                  const SizedBox(height: 22),

                  // 5. Sezione "La mia giornata" + Button (+) Bianco Rotondo con + Nero
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'La mia giornata',
                        style: TextStyle(
                          color: WhoopTheme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => WhoopFabModal.show(context),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add, color: Colors.black, size: 20),
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

                  // 7. Sezione "Il mio piano"
                  _buildMyPlanCard(),

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

  /// Card Notifiche/Insight Dismissibili con Swipe a Destra
  Widget _buildDismissibleNotificationCard() {
    final item = _notifications.first;

    return Dismissible(
      key: Key(item['id']!),
      direction: DismissDirection.startToEnd,
      onDismissed: (direction) {
        setState(() {
          _notifications.removeAt(0);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notifica "${item['title']}" archiviata.'),
            backgroundColor: WhoopTheme.cardSurface,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      background: Container(
        padding: const EdgeInsets.only(left: 20),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: WhoopTheme.recoveryRed.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text('Rimuovi Notifica', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: WhoopTheme.officialCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item['title']!,
                  style: const TextStyle(
                    color: WhoopTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF263238),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        item['badge']!,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item['body']!,
              style: const TextStyle(
                color: WhoopTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
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

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CoachScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF332B22), Color(0xFF1B2329)],
          ),
          border: Border.all(color: const Color(0xFF3D362E)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  hasRecovery ? Icons.wb_sunny_outlined : Icons.schedule,
                  color: hasRecovery ? const Color(0xFFE5B17B) : WhoopTheme.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  hasRecovery ? 'Le tue prospettive giornaliere' : 'In attesa di calcolo del sonno',
                  style: TextStyle(
                    color: hasRecovery ? WhoopTheme.textPrimary : WhoopTheme.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFC7B39E), size: 20),
          ],
        ),
      ),
    );
  }

  /// Card Calorie Bruciate e Target Giornaliero (Stile Ufficiale Whoop 5.0)
  Widget _buildCaloriesCard(int calories, {int? targetCal}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: WhoopTheme.officialCardDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.local_fire_department_outlined, color: WhoopTheme.textSecondary, size: 20),
              SizedBox(width: 8),
              Text(
                'CALORIE',
                style: TextStyle(
                  color: WhoopTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
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
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, color: WhoopTheme.textSecondary, size: 18),
                ],
              ),
              Text(
                (targetCal != null && targetCal > 0) ? '$targetCal' : '--',
                style: const TextStyle(
                  color: WhoopTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
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
                  color: WhoopTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
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
                  sleepPct: sleepPct,
                  durationMin: sleepMin,
                  sleepNeedMin: ciclo?.sonnoRichiestoMin ?? viewModel.currentSleepNeedMinutes,
                  sleepDebtMin: 0.0,
                  lightSleepMin: sonno?.sonnoLeggeroMin ?? 0.0,
                  deepSleepMin: sonno?.sonnoProfondoMinDouble ?? 0.0,
                  remSleepMin: sonno?.sonnoRemMinDouble ?? 0.0,
                  awakeMin: sonno?.vegliaMin ?? 0.0,
                  efficiencyPct: sonno?.efficienzaPct ??
                      ((sonno != null && sonno.tempoALettoMin > 0)
                          ? ((sonno.durataTotMin / sonno.tempoALettoMin) * 100).clamp(0.0, 100.0)
                          : 0.0),
                  consistencyPct: sonno?.regolaritaSonnoPct ?? 0.0,
                  baselineDurationMin: viewModel.userProfile.sleepBaselineMin > 0 ? viewModel.userProfile.sleepBaselineMin.toDouble() : null,
                  baselinePerformancePct: 80.0,
                  historicalSonno: viewModel.sonnoList,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161E24),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF26333D)),
                  ),
                  child: Row(
                    children: [
                      // Badge Pillola Blu Sonno con Icona Luna
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5D849E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.nightlight_round, color: Colors.white, size: 14),
                            const SizedBox(width: 5),
                            Text(
                              sleepFormattedText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        'SONNO',
                        style: TextStyle(
                          color: WhoopTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const Spacer(),
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
                              fontWeight: FontWeight.bold,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 6,
                            color: WhoopTheme.cardBorder,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                          ),
                          Text(
                            endHourStr,
                            style: const TextStyle(
                              color: WhoopTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
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
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161E24),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: WhoopTheme.strainBlue.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.fitness_center, color: WhoopTheme.strainBlue, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            a.nomeAttivita.toUpperCase(),
                            style: const TextStyle(
                              color: WhoopTheme.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
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
                        style: const TextStyle(
                          color: WhoopTheme.strainBlue,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],

          const SizedBox(height: 14),

          // Tasti Azione: + AGGIUNGI ATTIVITÀ | ⏱ INIZIA ATTIVITÀ (Pulsanti Pieni Scuri Whoop 5.0)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => WhoopFabModal.show(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF222B32),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF2E3842)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 14, color: WhoopTheme.textPrimary),
                        SizedBox(width: 6),
                        Text(
                          'AGGIUNGI ATTIVITÀ',
                          style: TextStyle(
                            color: WhoopTheme.textPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => LiveActivityTrackerScreen.start(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF222B32),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF2E3842)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.timer_outlined, size: 14, color: WhoopTheme.textPrimary),
                        SizedBox(width: 6),
                        Text(
                          'INIZIA ATTIVITÀ',
                          style: TextStyle(
                            color: WhoopTheme.textPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
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
    final days = ['GIO', 'VEN', 'SAB', 'SOLE', 'LUN', 'MAR', 'MER'];

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
                    color: WhoopTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                Icon(Icons.chevron_right, color: WhoopTheme.textSecondary, size: 20),
              ],
            ),
            const SizedBox(height: 14),

            // Giorni della settimana
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: days.map((day) {
                final isToday = day == 'MER';
                return Column(
                  children: [
                    Text(
                      day,
                      style: TextStyle(
                        color: isToday ? WhoopTheme.textPrimary : WhoopTheme.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isToday ? WhoopTheme.textPrimary : WhoopTheme.cardBorder,
                          width: isToday ? 2 : 1,
                        ),
                      ),
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
              label: const Text('APPROFONDIMENTI SUL COMPORTAMENTO', style: TextStyle(color: WhoopTheme.textPrimary, fontSize: 10, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: WhoopTheme.cardBorder),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card Piano Personale — naviga a ProfilePlanScreen tab MyPlan
  Widget _buildMyPlanCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const ProfilePlanScreen(initialTab: 1)),
      ),
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
                  'Il mio piano',
                  style: TextStyle(
                    color: WhoopTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Icon(Icons.chevron_right, color: WhoopTheme.textSecondary, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF101518),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: WhoopTheme.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'COMPLETATO',
                        style: TextStyle(color: WhoopTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                      ),
                      Icon(Icons.keyboard_arrow_down, color: WhoopTheme.textSecondary, size: 20),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '5 giorni rimanenti',
                    style: TextStyle(color: WhoopTheme.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '14% PIANO PERSONALIZZATO',
                    style: TextStyle(color: WhoopTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      value: 0.14,
                      minHeight: 6,
                      backgroundColor: WhoopTheme.cardBorder,
                      valueColor: AlwaysStoppedAnimation<Color>(WhoopTheme.recoveryGreen),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sezione Dashboard Personalizzabile Metriche
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

    final allMetrics = [
      {
        'key': 'vfc',
        'title': 'VARIABILITÀ DELLA FREQUENZA CARDIACA',
        'metricName': 'Variabilità FC (VFC)',
        'val': hasData && vfcMs > 0 ? '${vfcMs.toInt()}' : '--',
        'base': '${profile.hrvBaselineMean.toInt()} ms',
        'arrow': hasData && vfcMs > 0 ? (vfcMs >= profile.hrvBaselineMean ? '▲' : '▼') : '•',
        'color': hasData && vfcMs > 0 ? (vfcMs >= profile.hrvBaselineMean ? WhoopTheme.recoveryGreen : WhoopTheme.recoveryYellow) : WhoopTheme.textSecondary,
      },
      {
        'key': 'fcr',
        'title': 'FREQUENZA CARDIACA A RIPOSO',
        'metricName': 'FC a Riposo (FCR)',
        'val': hasData && fcrBpm > 0 ? '$fcrBpm' : '--',
        'base': '${profile.hrRestBaseline} bpm',
        'arrow': hasData && fcrBpm > 0 ? (fcrBpm <= profile.hrRestBaseline ? '▼' : '▲') : '•',
        'color': hasData && fcrBpm > 0 ? (fcrBpm <= profile.hrRestBaseline ? WhoopTheme.recoveryGreen : WhoopTheme.recoveryYellow) : WhoopTheme.textSecondary,
      },
      {
        'key': 'steps',
        'title': 'PASSI GIORNALIERI',
        'metricName': 'Passi Giornalieri',
        'val': hasData && sforzoGiornaliero > 0 ? '${(sforzoGiornaliero * 650).round()}' : '--',
        'base': 'Target 10.000',
        'arrow': hasData && sforzoGiornaliero > 0 ? '▲' : '•',
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
        'base': '${(profile.sleepBaselineMin / 60).floor()}h ${(profile.sleepBaselineMin % 60)}m',
        'arrow': '•',
        'color': WhoopTheme.textSecondary,
      },
      {
        'key': 'recovery',
        'title': 'RECUPERO',
        'metricName': 'Recupero',
        'val': hasData && punteggioRecuperoPct > 0 ? '${punteggioRecuperoPct.toInt()}%' : '--',
        'base': 'Baseline 65%',
        'arrow': hasData && punteggioRecuperoPct > 0 ? (punteggioRecuperoPct >= 65 ? '▲' : '▼') : '•',
        'color': hasData && punteggioRecuperoPct > 0 ? (punteggioRecuperoPct >= 65 ? WhoopTheme.recoveryGreen : WhoopTheme.recoveryYellow) : WhoopTheme.textSecondary,
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
        'base': '14.0 rpm',
        'arrow': '•',
        'color': WhoopTheme.textPrimary,
      },
      {
        'key': 'skin_temp',
        'title': 'TEMPERATURA CUTANEA',
        'metricName': 'Temperatura Cutanea',
        'val': (hasData && ciclo?.tempCutaneaC != null) ? '${ciclo!.tempCutaneaC! >= 0 ? '+' : ''}${ciclo.tempCutaneaC!.toStringAsFixed(1)} °C' : '--',
        'base': '0.0 °C',
        'arrow': '•',
        'color': WhoopTheme.textPrimary,
      },
      {
        'key': 'spo2',
        'title': 'OSSIGENO NEL SANGUE (SPO₂)',
        'metricName': 'Ossigeno nel Sangue (SpO₂)',
        'val': (hasData && ciclo?.spo2Pct != null && ciclo!.spo2Pct! > 0) ? '${ciclo.spo2Pct!.round()}%' : '--',
        'base': '96%',
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
            const Text(
              'La mia dashboard',
              style: TextStyle(color: WhoopTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CustomizableDashboardScreen()),
              ),
              icon: const Icon(Icons.edit_outlined, size: 14, color: WhoopTheme.textPrimary),
              label: const Text('PERSONALIZZA', style: TextStyle(color: WhoopTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
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
                          color: WhoopTheme.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
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
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              m['arrow'] as String,
                              style: TextStyle(
                                color: m['color'] as Color,
                                fontSize: 14,
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
