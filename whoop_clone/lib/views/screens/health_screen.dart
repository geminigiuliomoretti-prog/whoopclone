import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/whoop_theme.dart';
import '../../data/biometrics/health_vitals_engine.dart';
import '../../viewmodels/whoop_viewmodel.dart';
import '../widgets/live_heart_rate_card.dart';
import 'stress_monitor_screen.dart';
import 'health_vitals_detail_screen.dart';

/// Schermata TAB SALUTE WHOOP 5.0 (Rispecchia al 100% "Salute - Tab Salute Frequenza Cardiaca e 5 Parametri Vitali.jpeg")
class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  String _getCurrentItalianWeekday() {
    final now = DateTime.now();
    switch (now.weekday) {
      case DateTime.monday:
        return 'lunedì';
      case DateTime.tuesday:
        return 'martedì';
      case DateTime.wednesday:
        return 'mercoledì';
      case DateTime.thursday:
        return 'giovedì';
      case DateTime.friday:
        return 'venerdì';
      case DateTime.saturday:
        return 'sabato';
      case DateTime.sunday:
        return 'domenica';
      default:
        return 'giorno';
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<WhoopViewModel>(context);
    final liveBpm = viewModel.liveBpm;
    final vitals = viewModel.vitalEvaluations;

    return Scaffold(
      backgroundColor: WhoopTheme.background,
      appBar: AppBar(
        backgroundColor: WhoopTheme.background,
        elevation: 0,
        title: const Text(
          'SALUTE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. FREQUENZA CARDIACA (Live BPM Box con griglia, onda e 5 trattini zona)
            LiveHeartRateCard(liveBpm: liveBpm),

            const SizedBox(height: 16),

            // 2. MONITORAGGIO DELLA SALUTE (5 Vitals Column con divisori + pill scuro con spunta)
            _buildHealthVitalsCard(context, vitals),

            const SizedBox(height: 16),

            // 3. MONITORAGGIO DELLO STRESS (Picco di stress + mini wave graph)
            _buildStressSummaryCard(context, viewModel),

            const SizedBox(height: 16),

            // 4. HEALTHSPAN (Card con lucchetto 🔒 per sbloccare)
            _buildHealthspanCard(),

            const SizedBox(height: 80), // Padding per floating bar
          ],
        ),
      ),
    );
  }

  // Card 2: Monitoraggio della Salute
  Widget _buildHealthVitalsCard(BuildContext context, List<VitalEvaluation> vitals) {
    final inRangeCount = vitals.where((v) => v.status == VitalStatus.inRange).length;
    final calibrationCount = vitals.where((v) => v.status == VitalStatus.calibration).length;
    final noDataCount = vitals.where((v) => v.status == VitalStatus.noData).length;

    String pillText;
    Color pillColor;
    IconData pillIcon;

    if (noDataCount == vitals.length) {
      pillText = 'Dati non disponibili';
      pillColor = WhoopTheme.textMuted;
      pillIcon = Icons.remove_circle_outline;
    } else if (calibrationCount > 0) {
      final samples = vitals.first.sampleCount;
      pillText = 'Calibrazione in corso ($samples/7 giorni)';
      pillColor = WhoopTheme.strainBlue;
      pillIcon = Icons.tune;
    } else if (inRangeCount == (vitals.length - noDataCount) && inRangeCount > 0) {
      pillText = '$inRangeCount/${vitals.length - noDataCount} parametri nella norma';
      pillColor = WhoopTheme.recoveryGreen;
      pillIcon = Icons.check;
    } else {
      final validCount = vitals.length - noDataCount;
      pillText = validCount > 0 ? '$inRangeCount/$validCount parametri nella norma' : 'Dati non disponibili';
      pillColor = validCount > 0 ? WhoopTheme.recoveryYellow : WhoopTheme.textMuted;
      pillIcon = validCount > 0 ? Icons.warning_amber_rounded : Icons.remove_circle_outline;
    }

    VitalStatus getStatus(String key, int fallbackIdx) {
      final found = vitals.where((v) => v.key == key).firstOrNull;
      if (found != null) return found.status;
      if (vitals.length > fallbackIdx) return vitals[fallbackIdx].status;
      return VitalStatus.noData;
    }

    return GestureDetector(
      onTap: () => HealthVitalsDetailScreen.show(context),
      child: Container(
        padding: const EdgeInsets.all(18.0),
        decoration: WhoopTheme.officialCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'MONITORAGGIO DELLA SALUTE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                Icon(Icons.chevron_right, color: WhoopTheme.textSecondary, size: 20),
              ],
            ),
            const SizedBox(height: 20),

            // 5 Colonne con divisori verticali sottili
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(child: _buildVitalIconColumn('FR', Icons.air, getStatus('resp_rate', 0))),
                  _buildVerticalDivider(),
                  Expanded(child: _buildVitalIconColumn('SPO₂', Icons.water_drop_outlined, getStatus('spo2', 1))),
                  _buildVerticalDivider(),
                  Expanded(child: _buildVitalIconColumn('FCR', Icons.favorite_border, getStatus('fcr', 2))),
                  _buildVerticalDivider(),
                  Expanded(child: _buildVitalIconColumn('VFC', Icons.show_chart, getStatus('vfc', 3))),
                  _buildVerticalDivider(),
                  Expanded(child: _buildVitalIconColumn('TEMP', Icons.thermostat, getStatus('temp', 4))),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Pill Contenitore: Sfondo nero opaco, spunta verde quadrata e testo bianco
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFF141D22),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF222D35)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: pillColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(pillIcon, color: Colors.black, size: 14),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      pillText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
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

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: const Color(0xFF202A33),
    );
  }

  Widget _buildVitalIconColumn(String label, IconData icon, VitalStatus status) {
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case VitalStatus.inRange:
        statusColor = WhoopTheme.recoveryGreen;
        statusIcon = Icons.check;
        break;
      case VitalStatus.outOfRange:
        statusColor = WhoopTheme.recoveryRed;
        statusIcon = Icons.priority_high;
        break;
      case VitalStatus.calibration:
        statusColor = WhoopTheme.strainBlue;
        statusIcon = Icons.tune;
        break;
      case VitalStatus.noData:
        statusColor = WhoopTheme.textMuted;
        statusIcon = Icons.remove;
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: WhoopTheme.textSecondary, size: 22),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(statusIcon, color: Colors.black, size: 14),
        ),
      ],
    );
  }

  // Card 3: Monitoraggio dello Stress
  Widget _buildStressSummaryCard(BuildContext context, WhoopViewModel viewModel) {
    final stressScore = viewModel.liveStressIndex > 0
        ? viewModel.liveStressIndex
        : (viewModel.ultimoCiclo?.vfcMs != null ? (viewModel.ultimoCiclo!.vfcMs! < 50 ? 1.8 : 0.8) : 0.8);

    final weekdayName = _getCurrentItalianWeekday();

    return GestureDetector(
      onTap: () => StressMonitorScreen.show(context, stressScore: stressScore),
      child: Container(
        padding: const EdgeInsets.all(18.0),
        decoration: WhoopTheme.officialCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'MONITORAGGIO DELLO STRESS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                Icon(Icons.chevron_right, color: WhoopTheme.textSecondary, size: 20),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Colonna Sinistra
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PICCO DI STRESS DI\nOGGI',
                        style: TextStyle(
                          color: WhoopTheme.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '0:00 h',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF132B25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.arrow_drop_down,
                              color: WhoopTheme.recoveryGreen,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'rispetto a un tipico $weekdayName',
                              style: const TextStyle(
                                color: WhoopTheme.recoveryGreen,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Area Destra: Grafico mini onda fisiologica con spike verdi e pallino bianco
                SizedBox(
                  width: 145,
                  height: 75,
                  child: CustomPaint(
                    painter: _StressWaveHealthPainter(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Card 4: Healthspan
  Widget _buildHealthspanCard() {
    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: WhoopTheme.officialCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'HEALTHSPAN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF2C3945), width: 1.2),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: WhoopTheme.textSecondary,
                  size: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Per sbloccare devi avere almeno 18 anni.',
            style: TextStyle(
              color: WhoopTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),

          Row(
            children: const [
              Text(
                'LIFE',
                style: TextStyle(
                  color: WhoopTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              SizedBox(width: 20),
              Text(
                'PEAK',
                style: TextStyle(
                  color: WhoopTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Custom painter per la mini-onda dello stress in HealthScreen
/// Riproduce fedelmente la preview di stress con baseline ciano e picchi verdi
class _StressWaveHealthPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Linea guida orizzontale di base
    final guidePaint = Paint()
      ..color = const Color(0xFF1E2833)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(0, size.height * 0.40),
      Offset(size.width, size.height * 0.40),
      guidePaint,
    );

    // 2. Linea tratteggiata verticale
    final targetX = size.width * 0.90;
    final dashPaint = Paint()
      ..color = const Color(0xFF495B6A)
      ..strokeWidth = 1.0;
    double currentY = 0;
    while (currentY < size.height) {
      canvas.drawLine(
        Offset(targetX, currentY),
        Offset(targetX, currentY + 3),
        dashPaint,
      );
      currentY += 6;
    }

    // 3. Onda continua dello stress con sfumatura ciano -> verde
    final wavePath = Path();
    wavePath.moveTo(0, size.height * 0.65);
    wavePath.lineTo(size.width * 0.15, size.height * 0.63);
    wavePath.lineTo(size.width * 0.25, size.height * 0.68);
    wavePath.lineTo(size.width * 0.35, size.height * 0.64);
    wavePath.lineTo(size.width * 0.45, size.height * 0.55);
    wavePath.lineTo(size.width * 0.50, size.height * 0.67);
    wavePath.lineTo(size.width * 0.58, size.height * 0.65);
    // Picco moderato
    wavePath.lineTo(size.width * 0.62, size.height * 0.35);
    wavePath.lineTo(size.width * 0.66, size.height * 0.68);
    wavePath.lineTo(size.width * 0.72, size.height * 0.66);
    // Picco alto
    wavePath.lineTo(size.width * 0.76, size.height * 0.15);
    wavePath.lineTo(size.width * 0.80, size.height * 0.60);
    // Picco secondario
    wavePath.lineTo(size.width * 0.84, size.height * 0.20);
    wavePath.lineTo(size.width * 0.88, size.height * 0.28);
    // Valore live sul tratteggio
    wavePath.lineTo(targetX, size.height * 0.48);

    final linePaint = Paint()
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(
        colors: [
          WhoopTheme.stressLow,
          WhoopTheme.stressLow,
          WhoopTheme.recoveryGreen,
          WhoopTheme.recoveryGreen,
        ],
        stops: const [0.0, 0.55, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(wavePath, linePaint);

    // 4. Pallino bianco live
    final liveDotY = size.height * 0.48;
    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(targetX, liveDotY), 3.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
