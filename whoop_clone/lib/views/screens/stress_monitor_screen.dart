import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/nature_theme.dart';
import '../widgets/nature/nature_scene.dart';
import '../../data/database/database_helper.dart';
import '../../viewmodels/whoop_viewmodel.dart';
import '../widgets/stress_check_sheet.dart';
import '../breathe/haptic_breathe_screen.dart';
import '../stress/stress_timeline_view.dart';
import 'trends_screen.dart';
import '../widgets/nature/coach_emblem.dart';

/// Schermata UFFICIALE MONITORAGGIO DELLO STRESS (WHOOP 5.0)
/// Visualizza lo stress live, lo stress notturno calcolato e la timeline continua.
class StressMonitorScreen extends StatefulWidget {
  final double currentStressScore;

  const StressMonitorScreen({
    super.key,
    this.currentStressScore = 0.0,
  });

  static void show(BuildContext context, {double stressScore = 0.0}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StressMonitorScreen(currentStressScore: stressScore),
      ),
    );
  }

  @override
  State<StressMonitorScreen> createState() => _StressMonitorScreenState();
}

class _StressMonitorScreenState extends State<StressMonitorScreen> {
  List<StressTimelineSample> _samples = [];

  @override
  void initState() {
    super.initState();
    _loadSamples();
  }

  Future<void> _loadSamples() async {
    final viewModel = Provider.of<WhoopViewModel>(context, listen: false);
    final dateKey = viewModel.selectedDate.toIso8601String().substring(0, 10);
    final rows = await DatabaseHelper().getMisurazioniStressByDate(dateKey);

    if (mounted) {
      setState(() {
        _samples = rows.map((r) {
          final ts = DateTime.tryParse(r['timestamp'].toString()) ?? DateTime.now();
          final val = (r['valore_stress'] as num).toDouble();
          final bpm = (r['bpm'] as num?)?.toInt() ?? 60;
          final hrv = (r['hrv_ms'] as num?)?.toDouble() ?? 50.0;
          return StressTimelineSample(
            timestamp: ts,
            stressScore: val,
            bpm: bpm,
            hrvMs: hrv,
          );
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<WhoopViewModel>(context);
    final selectedDate = viewModel.selectedDate;
    final isToday = selectedDate.year == DateTime.now().year &&
        selectedDate.month == DateTime.now().month &&
        selectedDate.day == DateTime.now().day;

    final String dateLabel = isToday ? 'OGGI' : DateFormat('d MMMM', 'it_IT').format(selectedDate).toUpperCase();

    // Determina il valore di stress da visualizzare:
    // Priorità: parametro passato > live index > saved score > sleep stress > ultimo campione DB > 0.0
    double effectiveStress = 0.0;
    if (widget.currentStressScore > 0) {
      effectiveStress = widget.currentStressScore;
    } else if (viewModel.liveStressIndex > 0) {
      effectiveStress = viewModel.liveStressIndex;
    } else if (viewModel.currentStressScore > 0) {
      effectiveStress = viewModel.currentStressScore;
    } else if (viewModel.sleepStress != null && viewModel.sleepStress! > 0) {
      effectiveStress = viewModel.sleepStress!;
    } else if (_samples.isNotEmpty) {
      effectiveStress = _samples.last.stressScore;
    }

    final String categoryText;
    final Color categoryColor;
    if (effectiveStress <= 0) {
      categoryText = 'NESSUN DATO';
      categoryColor = NatureColors.textMuted;
    } else if (effectiveStress < 1.0) {
      categoryText = 'BASSO';
      categoryColor = NatureColors.sage;
    } else if (effectiveStress < 2.0) {
      categoryText = 'MODERATO';
      categoryColor = NatureColors.amber;
    } else {
      categoryText = 'ELEVATO';
      categoryColor = NatureColors.lavender;
    }

    final String timeLabel = effectiveStress > 0
        ? (_samples.isNotEmpty
            ? DateFormat('HH:mm').format(_samples.last.timestamp)
            : DateFormat('HH:mm').format(DateTime.now()))
        : '--:--';

    // Statistiche sonno per la Card "SONNO"
    final sonno = viewModel.ultimoSonno;
    final bool hasSonno = sonno != null && sonno.durataTotMin > 0;
    final int sonnoTotMin = hasSonno ? sonno.durataTotMin : 0;
    final int swsMin = hasSonno ? sonno.sonnoProfondoMin : 0;
    final int remMin = hasSonno ? sonno.sonnoRemMin : 0;
    final int lightMin = (sonnoTotMin - swsMin - remMin).clamp(0, 9999);

    final String sleepBassoTime = hasSonno
        ? '${(swsMin + lightMin) ~/ 60}:${((swsMin + lightMin) % 60).toString().padLeft(2, '0')}'
        : '--';
    final String sleepMedioTime = hasSonno
        ? '${remMin ~/ 60}:${(remMin % 60).toString().padLeft(2, '0')}'
        : '--';
    final String sleepAltoTime = hasSonno ? '0:00' : '--';

    // Statistiche campioni diurni per la Card "TOTALE GIORNALIERO"
    final int sampleBassoCount = _samples.where((s) => s.stressScore < 1.0).length;
    final int sampleMedioCount = _samples.where((s) => s.stressScore >= 1.0 && s.stressScore < 2.0).length;
    final int sampleAltoCount = _samples.where((s) => s.stressScore >= 2.0).length;
    final bool hasSamples = _samples.isNotEmpty;

    final String totBassoTime = hasSamples
        ? '${(sampleBassoCount * 5) ~/ 60}:${((sampleBassoCount * 5) % 60).toString().padLeft(2, '0')}'
        : (hasSonno ? sleepBassoTime : '--');
    final String totMedioTime = hasSamples
        ? '${(sampleMedioCount * 5) ~/ 60}:${((sampleMedioCount * 5) % 60).toString().padLeft(2, '0')}'
        : (hasSonno ? sleepMedioTime : '--');
    final String totAltoTime = hasSamples
        ? '${(sampleAltoCount * 5) ~/ 60}:${((sampleAltoCount * 5) % 60).toString().padLeft(2, '0')}'
        : (hasSonno ? sleepAltoTime : '--');

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? NatureColors.darkCanvas : NatureColors.offWhite,
      appBar: AppBar(
        backgroundColor: isDark ? NatureColors.darkCanvas : NatureColors.offWhite,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.chevron_left,
            color: isDark ? Colors.white : NatureColors.textLightPrimary,
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'MONITORAGGIO DELLO STRESS',
          style: TextStyle(
            color: isDark ? Colors.white : NatureColors.textLightPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: isDark ? Colors.white : NatureColors.textLightPrimary,
              size: 22,
            ),
            onPressed: () {
              _loadSamples();
              viewModel.loadData();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Selettore Data < OGGI > ─────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 30),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.chevron_left,
                        color: isDark ? NatureColors.textMuted : NatureColors.textLightMuted,
                        size: 20,
                      ),
                      onPressed: () {
                        viewModel.setSelectedDate(selectedDate.subtract(const Duration(days: 1)));
                        _loadSamples();
                      },
                    ),
                    Text(
                      dateLabel,
                      style: TextStyle(
                        color: isDark ? Colors.white : NatureColors.textLightPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.chevron_right,
                        color: isDark ? NatureColors.textMuted : NatureColors.textLightMuted,
                        size: 20,
                      ),
                      onPressed: () {
                        viewModel.setSelectedDate(selectedDate.add(const Duration(days: 1)));
                        _loadSamples();
                      },
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    Icons.info_outline,
                    color: isDark ? NatureColors.textMuted : NatureColors.textLightMuted,
                    size: 20,
                  ),
                  onPressed: () {},
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ── 2. Arc Gauge Grande 0,0 - 3,0 Immerso in NatureScene ───────────
            Stack(
              alignment: Alignment.center,
              children: [
                NatureScene(
                  mood: NatureMood.stress,
                  height: 185,
                  isDark: isDark,
                  borderRadius: BorderRadius.circular(24),
                ),
                SizedBox(
                  width: 240,
                  height: 160,
                  child: CustomPaint(
                    painter: _StressArcGaugePainter(stressValue: effectiveStress),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 36.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            effectiveStress > 0
                                ? effectiveStress.toStringAsFixed(1).replaceAll('.', ',')
                                : '--',
                            style: TextStyle(
                              color: isDark ? Colors.white : NatureColors.textLightPrimary,
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            categoryText,
                            style: TextStyle(
                              color: categoryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            timeLabel,
                            style: TextStyle(
                              color: isDark ? NatureColors.textMuted : NatureColors.textLightMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Tasto Prominente Spot-Check 60s
            Center(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    StressCheckSheet.show(context);
                    // Ricarica quando il modale si chiude
                    await Future.delayed(const Duration(seconds: 1));
                    _loadSamples();
                  },
                  icon: const Icon(Icons.bolt, color: Colors.white, size: 20),
                  label: const Text(
                    'AVVIA TEST STRESS (60S)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NatureColors.terracotta,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── 3. Tracciato Grafico Stress (Timeline Dinamica) ────────────────
            StressTimelineView(
              samples: _samples,
              currentStressScore: effectiveStress,
              height: 210,
            ),

            const SizedBox(height: 16),

            // ── 4. Card Stato Attuale ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: NatureTheme.organicCardDecoration(isDark: isDark, elevated: true),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: categoryColor.withValues(alpha: 0.16),
                          border: Border.all(color: categoryColor),
                        ),
                        child: CoachEmblem(
                          size: 14,
                          color: categoryColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'STRESS $categoryText',
                        style: TextStyle(
                          color: isDark ? Colors.white : NatureColors.textLightPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    effectiveStress > 0
                        ? (effectiveStress < 1.0
                            ? 'Il tuo corpo segnala un basso livello di stress. Il sistema cardiovascolare è stabile, rilassato e vicino allo stato di riposo.'
                            : (effectiveStress < 2.0
                                ? 'Livello di stress moderato. Risposta fisiologica equilibrata alle normali attività quotidiane.'
                                : 'Livello di stress elevato. Attivazione simpatica accentuata. Prova una sessione di respirazione per facilitare il recupero.'))
                        : 'Nessuna misurazione dello stress registrata per la data corrente. Connetti lo strap o avvia un test da 60s.',
                    style: TextStyle(
                      color: isDark ? NatureColors.textMuted : NatureColors.textLightSecondary,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── 5. Card TOTALE GIORNALIERO ─────────────────────────────────────
            _buildStressComparisonCard(
              context: context,
              icon: Icons.sync,
              title: 'TOTALE GIORNALIERO',
              subtitle: 'STRESS 24H vs. GIORNATA TIPICA',
              bassoTime: totBassoTime, bassoPct: hasSamples ? '' : '--',
              medioTime: totMedioTime, medioPct: hasSamples ? '' : '--',
              altoTime: totAltoTime, altoPct: hasSamples ? '' : '--',
              description: 'Lo stress sperimentato durante il giorno, inclusi i periodi di sonno e veglia.',
              isDark: isDark,
            ),

            const SizedBox(height: 16),

            // ── 6. Card SENZA ATTIVITÀ ─────────────────────────────────────────
            _buildStressComparisonCard(
              context: context,
              icon: Icons.accessibility_new,
              title: 'SENZA ATTIVITÀ',
              subtitle: 'STATO DI VEGLIA A RIPOSO',
              bassoTime: hasSamples ? totBassoTime : '--', bassoPct: '',
              medioTime: hasSamples ? totMedioTime : '--', medioPct: '',
              altoTime: hasSamples ? totAltoTime : '--', altoPct: '',
              description: 'Lo stress rilevato durante la veglia al di fuori di allenamenti intensi.',
              isDark: isDark,
            ),

            const SizedBox(height: 16),

            // ── 7. Card SONNO ──────────────────────────────────────────────────
            _buildStressComparisonCard(
              context: context,
              icon: Icons.nightlight_round,
              title: 'SONNO',
              subtitle: hasSonno ? 'SONNO NOTTURNO REGISTRATO' : 'NESSUN SONNO REGISTRATO',
              bassoTime: sleepBassoTime, bassoPct: hasSonno ? 'SWS + Leggero' : '',
              medioTime: sleepMedioTime, medioPct: hasSonno ? 'Fase REM' : '',
              altoTime: sleepAltoTime, altoPct: hasSonno ? 'Risvegli' : '',
              description: hasSonno
                  ? 'Distribuzione dello stress autonomico registrato durante le fasi del sonno.'
                  : 'Nessun dato di sonno disponibile per questa data.',
              isDark: isDark,
            ),

            const SizedBox(height: 20),

            // ── 8. SESSIONI (Respirazione Guidata & Biofeedback) ──────────────
            Text(
              'SESSIONI RESPIRAZIONE & BIOFEEDBACK',
              style: TextStyle(
                color: isDark ? NatureColors.textMuted : NatureColors.textLightMuted,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => HapticBreatheScreen.show(context),
                    child: _buildSessionCard(
                      title: 'AUMENTARE IL\nRILASSAMENTO',
                      subtitle: 'Respirazione aptica 4-6',
                      gradientColors: isDark
                          ? [const Color(0xFF1E2F35), const Color(0xFF142025)]
                          : [Colors.white, NatureColors.creamLight],
                      isDark: isDark,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => HapticBreatheScreen.show(context),
                    child: _buildSessionCard(
                      title: 'COERENZA\nCARDIACA',
                      subtitle: '0.1 Hz Risonanza vagale',
                      gradientColors: isDark
                          ? [const Color(0xFF262338), const Color(0xFF181525)]
                          : [Colors.white, const Color(0xFFF0ECF8)],
                      isDark: isDark,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildStressComparisonCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required String bassoTime, required String bassoPct,
    required String medioTime, required String medioPct,
    required String altoTime, required String altoPct,
    required String description,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: NatureTheme.organicCardDecoration(isDark: isDark, elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: isDark ? NatureColors.textMuted : NatureColors.textLightMuted, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : NatureColors.textLightPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: isDark ? NatureColors.textMuted : NatureColors.textLightMuted,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // 3 Column values
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    bassoTime,
                    style: TextStyle(
                      color: isDark ? Colors.white : NatureColors.textLightPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (bassoPct.isNotEmpty)
                    Text(
                      bassoPct,
                      style: TextStyle(
                        color: isDark ? NatureColors.textMuted : NatureColors.textLightMuted,
                        fontSize: 10,
                      ),
                    ),
                  const Text('BASSO', style: TextStyle(color: NatureColors.sage, fontSize: 9, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                children: [
                  Text(
                    medioTime,
                    style: TextStyle(
                      color: isDark ? Colors.white : NatureColors.textLightPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (medioPct.isNotEmpty)
                    Text(
                      medioPct,
                      style: TextStyle(
                        color: isDark ? NatureColors.textMuted : NatureColors.textLightMuted,
                        fontSize: 10,
                      ),
                    ),
                  const Text('MEDIO', style: TextStyle(color: NatureColors.amber, fontSize: 9, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                children: [
                  Text(
                    altoTime,
                    style: TextStyle(
                      color: isDark ? Colors.white : NatureColors.textLightPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (altoPct.isNotEmpty)
                    Text(
                      altoPct,
                      style: TextStyle(
                        color: isDark ? NatureColors.textMuted : NatureColors.textLightMuted,
                        fontSize: 10,
                      ),
                    ),
                  const Text('ALTO', style: TextStyle(color: NatureColors.lavender, fontSize: 9, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              color: isDark ? NatureColors.textMuted : NatureColors.textLightSecondary,
              fontSize: 11,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrendsScreen())),
            child: Row(
              children: [
                Text(
                  'VEDI LE TENDENZE',
                  style: TextStyle(
                    color: isDark ? Colors.white : NatureColors.textLightPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward,
                  color: isDark ? Colors.white : NatureColors.textLightPrimary,
                  size: 14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard({
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required bool isDark,
  }) {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradientColors),
        border: Border.all(
          color: isDark ? NatureColors.borderSubtle : NatureColors.sandBorder,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: const Color(0xFF2C3E50).withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Icon(
              Icons.sync,
              color: isDark ? Colors.white : NatureColors.textLightPrimary,
              size: 16,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : NatureColors.textLightPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: isDark ? NatureColors.textMuted : NatureColors.textLightMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Custom Painter per l'Arco di Stress (0,0 a 3,0)
class _StressArcGaugePainter extends CustomPainter {
  final double stressValue;

  _StressArcGaugePainter({required this.stressValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.82);
    final radius = size.width * 0.44;

    final bgPaint = Paint()
      ..color = NatureColors.borderSubtle
      ..strokeWidth = 9.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.14,
      3.14,
      false,
      bgPaint,
    );

    if (stressValue > 0) {
      final activePaint = Paint()
        ..shader = const LinearGradient(
          colors: [NatureColors.sage, NatureColors.amber, NatureColors.lavender],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..strokeWidth = 9.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final sweepAngle = (stressValue / 3.0).clamp(0.0, 1.0) * 3.14;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        3.14,
        sweepAngle,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StressArcGaugePainter oldDelegate) => oldDelegate.stressValue != stressValue;
}
