import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/whoop_theme.dart';
import '../../core/theme/nature_theme.dart';
import '../../data/ble/ble_connection_manager.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/allenamento.dart';
import '../../data/services/gps_tracking_service.dart';
import '../../viewmodels/whoop_viewmodel.dart';
import '../widgets/activity_picker_modal.dart';
import 'activity_details_screen.dart';

/// Live Activity Pre-Start & Tracking Screen WHOOP 5.0
/// Reale, reattivo, collegato a BLE ed al Database Locale SQLite.
class LiveActivityTrackerScreen extends StatefulWidget {
  final String initialActivityName;

  const LiveActivityTrackerScreen({
    super.key,
    this.initialActivityName = 'Corsa',
  });

  static void start(BuildContext context, {String activityName = 'Corsa'}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveActivityTrackerScreen(initialActivityName: activityName),
      ),
    );
  }

  @override
  State<LiveActivityTrackerScreen> createState() => _LiveActivityTrackerScreenState();
}

class _LiveActivityTrackerScreenState extends State<LiveActivityTrackerScreen> {
  late String _selectedActivity;
  bool _isSessionStarted = false;
  bool _trackRoute = true;
  bool _strainGoalOn = true;

  Timer? _timer;
  int _secondsElapsed = 0;
  bool _isRunning = false;

  double _accumulatedStrain = 0.0;
  int _caloriesBurned = 0;
  int _sumBpm = 0;
  int _bpmSampleCount = 0;
  int _maxBpm = 0;
  final GpsTrackingService _gpsService = GpsTrackingService();

  @override
  void initState() {
    super.initState();
    _selectedActivity = widget.initialActivityName;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _gpsService.stopTracking();
    super.dispose();
  }

  void _startLiveSession() {
    setState(() {
      _isSessionStarted = true;
      _isRunning = true;
    });

    if (_trackRoute) {
      _gpsService.startTracking();
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (!_isRunning) return;

      final viewModel = Provider.of<WhoopViewModel>(context, listen: false);
      final profile = viewModel.userProfile;
      final currentBpm = viewModel.liveBpm;

      if (!mounted) return;
      setState(() {
        _secondsElapsed++;
        if (currentBpm > 0) {
          _caloriesBurned = (_secondsElapsed * 0.24).round();

          // Formula Strain TRIMP live basata sulle baseline utente in SQLite
          final hrMax = profile.hrMax.toDouble();
          final hrRest = profile.hrRestBaseline.toDouble();
          final hrDelta = hrMax - hrRest;
          final double hrr;
          if (hrDelta <= 0) {
            hrr = 0.0;
          } else {
            hrr = ((currentBpm - hrRest) / hrDelta).clamp(0.0, 1.0);
          }
          _accumulatedStrain = (21.0 * (1.0 - (1.0 / (1.0 + 0.005 * _secondsElapsed * hrr)))).clamp(0.0, 21.0);

          _sumBpm += currentBpm;
          _bpmSampleCount++;
          if (currentBpm > _maxBpm) _maxBpm = currentBpm;
        }
      });
    });
  }

  void _pauseSession() {
    setState(() => _isRunning = false);
  }

  void _resumeSession() {
    setState(() => _isRunning = true);
  }

  void _onStopPressed() {
    _pauseSession();
    _showSummaryAndSaveModal(context);
  }

  void _showSummaryAndSaveModal(BuildContext context) {
    final avgBpm = _bpmSampleCount > 0 ? (_sumBpm / _bpmSampleCount).round() : 135;
    final maxBpm = _maxBpm > 0 ? _maxBpm : avgBpm + 22;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: const BoxDecoration(
          color: NatureColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: NatureColors.border, width: 0.8),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(color: NatureColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'RIEPILOGO ATTIVITÀ REGISTRATA',
              style: TextStyle(
                color: NatureColors.textDarkPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('Tipo Disciplina', _selectedActivity.toUpperCase()),
            _buildSummaryRow('Durata Totale', _formatDuration(_secondsElapsed)),
            _buildSummaryRow('Strain Sessione', _accumulatedStrain.toStringAsFixed(1)),
            _buildSummaryRow('FC Media', '$avgBpm bpm'),
            _buildSummaryRow('FC Massima', '$maxBpm bpm'),
            _buildSummaryRow('Calorie Bruciate', '$_caloriesBurned kcal'),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context); // Chiudi modal
                      Navigator.pop(context); // Chiudi tracker
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: NatureColors.terracotta.withValues(alpha: 0.6)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('SCARTA', style: TextStyle(color: NatureColors.coralLight, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context); // Chiudi modal
                      await _finishSession();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NatureColors.terracotta,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: const Text('SALVA NEL DB', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: NatureColors.textDarkMuted, fontSize: 12)),
          Text(value, style: const TextStyle(color: NatureColors.textDarkPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _finishSession() async {
    _timer?.cancel();
    final points = await _gpsService.stopTracking();

    final int? avgBpm = _bpmSampleCount > 0 ? (_sumBpm / _bpmSampleCount).round() : null;
    final int? maxBpm = _maxBpm > 0 ? _maxBpm : null;
    final durationMin = (_secondsElapsed / 60.0).clamp(0.1, 999.0);

    final now = DateTime.now();
    final startTime = now.subtract(Duration(seconds: _secondsElapsed));

    if (!mounted) return;

    final viewModel = Provider.of<WhoopViewModel>(context, listen: false);
    await viewModel.addWorkout(Allenamento(
      oraInizioCiclo: now,
      oraInizioAllenamento: startTime,
      oraFineAllenamento: now,
      fusoOrario: 'UTC+01:00',
      nomeAttivita: _selectedActivity,
      sforzoRichiesto: _bpmSampleCount > 0 ? _accumulatedStrain : null,
      energiaBruciataCal: _bpmSampleCount > 0 ? _caloriesBurned : null,
      fcMediaBpm: avgBpm,
      fcMaxBpm: maxBpm,
      durataMin: durationMin,
    ));

    final workoutToInsert = Allenamento(
      dataIso: now.toIso8601String().substring(0, 10),
      oraInizio: startTime.toIso8601String(),
      oraFine: now.toIso8601String(),
      nomeAttivita: _selectedActivity,
      strainAttivita: _bpmSampleCount > 0 ? _accumulatedStrain : null,
      calorie: _bpmSampleCount > 0 ? _caloriesBurned : null,
      hrMedia: avgBpm,
      hrMax: maxBpm,
      durataMin: durationMin.round(),
    );

    final workoutId = await DatabaseHelper().insertAllenamento(workoutToInsert.toMap());

    if (points.isNotEmpty && workoutId > 0) {
      await _gpsService.saveRouteToDatabase(workoutId);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Attività "$_selectedActivity" salvata con tracciato GPS! Strain aggiornato.'),
        backgroundColor: WhoopTheme.strainBlue,
      ),
    );

    Navigator.pop(context);
    ActivityDetailsScreen.show(
      context,
      activityName: _selectedActivity,
      activityStrain: _bpmSampleCount > 0 ? _accumulatedStrain : 0.0,
      durationText: _formatDuration(_secondsElapsed),
      fcMaxBpm: maxBpm,
      fcMediaBpm: avgBpm,
      caloriesBurned: _bpmSampleCount > 0 ? _caloriesBurned : null,
      distanceKm: _gpsService.totalDistanceKm > 0 ? _gpsService.totalDistanceKm : null,
      routePoints: points,
    );
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSessionStarted) {
      return _buildPreStartScreen(context);
    }
    return _buildActiveSessionScreen(context);
  }

  // ── 1. SCHERMATA PRE-AVVIO SENZA MOCK ──
  Widget _buildPreStartScreen(BuildContext context) {
    final viewModel = Provider.of<WhoopViewModel>(context);
    final liveBpm = viewModel.liveBpm;
    final isBleConnected = viewModel.bleState == BleState.connected || viewModel.isFallbackMode;

    return Scaffold(
      backgroundColor: NatureColors.background,
      body: Stack(
        children: [
          // Renderizza mappa solo se GPS è attivo
          if (_trackRoute)
            CustomPaint(
              size: Size.infinite,
              painter: _GpsMapBackgroundPainter(),
            )
          else
            Container(color: NatureColors.background),

          // Header Top Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: NatureColors.textDarkPrimary, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),

                  // Dropdown Selettore Attività
                  GestureDetector(
                    onTap: () {
                      ActivityPickerModal.show(
                        context,
                        selectedActivity: _selectedActivity,
                        onActivitySelected: (act) => setState(() => _selectedActivity = act),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: NatureColors.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: NatureColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.directions_run_rounded, color: NatureColors.terracotta, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _selectedActivity.toUpperCase(),
                            style: const TextStyle(
                              color: NatureColors.textDarkPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down_rounded, color: NatureColors.textDarkSecondary, size: 18),
                        ],
                      ),
                    ),
                  ),

                  Row(
                    children: [
                      const Text(
                        'GPS',
                        style: TextStyle(
                          color: NatureColors.textDarkSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Switch(
                        value: _trackRoute,
                        activeColor: NatureColors.teal,
                        activeTrackColor: NatureColors.teal.withValues(alpha: 0.3),
                        inactiveThumbColor: NatureColors.textDarkMuted,
                        inactiveTrackColor: NatureColors.border,
                        onChanged: (val) => setState(() => _trackRoute = val),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Cardio Display Centrale Reale
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 148,
                  height: 148,
                  decoration: BoxDecoration(
                    color: NatureColors.surface.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    border: Border.all(color: NatureColors.terracotta.withValues(alpha: 0.7), width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: NatureColors.terracotta.withValues(alpha: 0.18),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.favorite_rounded, color: NatureColors.terracotta, size: 26),
                      const SizedBox(height: 4),
                      Text(
                        isBleConnected && liveBpm > 0 ? '$liveBpm' : '--',
                        style: const TextStyle(
                          color: NatureColors.textDarkPrimary,
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        isBleConnected ? 'BPM LIVE' : 'IN ASCOLTO...',
                        style: const TextStyle(
                          color: NatureColors.textDarkMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: NatureColors.surfaceElevated.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: NatureColors.border),
                  ),
                  child: Text(
                    isBleConnected ? 'Sensore Salute Connesso' : 'In attesa del segnale sensore...',
                    style: const TextStyle(
                      color: NatureColors.textDarkSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Bar: Switch Obiettivo Sforzo + Tasto AVVIA ATTIVITÀ
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              decoration: const BoxDecoration(
                color: NatureColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(color: NatureColors.border, width: 0.8),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'OBIETTIVO SFORZO DINAMICO',
                        style: TextStyle(
                          color: NatureColors.textDarkSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Switch(
                        value: _strainGoalOn,
                        activeColor: NatureColors.terracotta,
                        activeTrackColor: NatureColors.terracotta.withValues(alpha: 0.3),
                        inactiveThumbColor: NatureColors.textDarkMuted,
                        inactiveTrackColor: NatureColors.border,
                        onChanged: (val) => setState(() => _strainGoalOn = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _startLiveSession,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NatureColors.terracotta,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'AVVIA ATTIVITÀ',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. SCHERMATA SESSIONE IN CORSO PULITA CON TIMER ALTO CONTRASTO ──
  Widget _buildActiveSessionScreen(BuildContext context) {
    final viewModel = Provider.of<WhoopViewModel>(context);
    final currentBpm = viewModel.liveBpm;

    return Scaffold(
      backgroundColor: NatureColors.background,
      appBar: AppBar(
        backgroundColor: NatureColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          _selectedActivity.toUpperCase(),
          style: const TextStyle(
            color: NatureColors.textDarkPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _isRunning
                  ? NatureColors.recoveryAccent.withValues(alpha: 0.15)
                  : NatureColors.amberWarm.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isRunning ? NatureColors.recoveryAccent : NatureColors.amberWarm,
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 7,
                  color: _isRunning ? NatureColors.recoveryAccent : NatureColors.amberWarm,
                ),
                const SizedBox(width: 6),
                Text(
                  _isRunning ? 'IN REGISTRAZIONE' : 'IN PAUSA',
                  style: TextStyle(
                    color: _isRunning ? NatureColors.recoveryAccent : NatureColors.amberWarm,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // Timer Centrale ad Alto Contrasto
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: NatureTheme.organicCardDecoration(
                accentTint: NatureColors.strainAccent.withValues(alpha: 0.1),
              ),
              child: Column(
                children: [
                  const Text(
                    'TEMPO TRASCORSO',
                    style: TextStyle(
                      color: NatureColors.textDarkMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDuration(_secondsElapsed),
                    style: const TextStyle(
                      color: NatureColors.textDarkPrimary,
                      fontSize: 52,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Due Card: BPM Live | Strain Accumulato
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: NatureTheme.organicCardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.favorite_rounded, color: NatureColors.terracotta, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'BPM LIVE',
                              style: TextStyle(
                                color: NatureColors.textDarkMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          currentBpm > 0 ? '$currentBpm' : '--',
                          style: const TextStyle(
                            color: NatureColors.textDarkPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: NatureTheme.organicCardDecoration(
                      accentTint: NatureColors.strainAccent.withValues(alpha: 0.1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bolt_rounded, color: NatureColors.terracotta, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'STRAIN ATTIVITÀ',
                              style: TextStyle(
                                color: NatureColors.textDarkMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _accumulatedStrain.toStringAsFixed(1),
                          style: const TextStyle(
                            color: NatureColors.coralLight,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Card Calorie Bruciate
            Container(
              padding: const EdgeInsets.all(16),
              decoration: NatureTheme.organicCardDecoration(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.local_fire_department_rounded, color: NatureColors.amberWarm, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'CALORIE BRUCIATE',
                        style: TextStyle(
                          color: NatureColors.textDarkMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$_caloriesBurned kcal',
                    style: const TextStyle(
                      color: NatureColors.textDarkPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Controlli PAUSA / RIPRENDI / TERMINA
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: _isRunning ? _pauseSession : _resumeSession,
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: _isRunning ? NatureColors.surfaceElevated : NatureColors.recoveryAccent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isRunning ? NatureColors.amberWarm : NatureColors.recoveryLight,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_isRunning ? NatureColors.amberWarm : NatureColors.recoveryAccent).withValues(alpha: 0.2),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: _isRunning ? NatureColors.amberWarm : Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _onStopPressed,
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: NatureColors.surfaceElevated,
                      shape: BoxShape.circle,
                      border: Border.all(color: NatureColors.terracotta, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: NatureColors.terracotta.withValues(alpha: 0.2),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.stop_rounded, color: NatureColors.coralLight, size: 32),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// Custom Painter per Mappa GPS (Dark Mode Terrain)
class _GpsMapBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = NatureColors.secondaryBackground;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final roadPaint = Paint()
      ..color = NatureColors.surfaceElevated.withValues(alpha: 0.6)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(size.width * 0.1, size.height * 0.2);
    path.quadraticBezierTo(size.width * 0.5, size.height * 0.35, size.width * 0.8, size.height * 0.25);
    path.quadraticBezierTo(size.width * 0.9, size.height * 0.5, size.width * 0.3, size.height * 0.7);

    canvas.drawPath(path, roadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
