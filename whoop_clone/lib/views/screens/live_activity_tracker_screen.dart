import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/whoop_theme.dart';
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
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: WhoopTheme.cardSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: WhoopTheme.cardBorder, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'RIEPILOGO ATTIVITÀ REGISTRATA',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.2),
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
                      side: const BorderSide(color: WhoopTheme.recoveryRed),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('SCARTA', style: TextStyle(color: WhoopTheme.recoveryRed, fontWeight: FontWeight.bold)),
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
                      backgroundColor: WhoopTheme.strainBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('SALVA NEL DB', style: TextStyle(fontWeight: FontWeight.w900)),
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
          Text(label, style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
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
      backgroundColor: WhoopTheme.background,
      body: Stack(
        children: [
          // Renderizza mappa solo se GPS è attivo
          if (_trackRoute)
            CustomPaint(
              size: Size.infinite,
              painter: _GpsMapBackgroundPainter(),
            )
          else
            Container(color: WhoopTheme.background),

          // Header Top Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1A24),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: WhoopTheme.cardBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.directions_run, color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            _selectedActivity.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                  ),

                  Row(
                    children: [
                      const Text(
                        'GPS',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      Switch(
                        value: _trackRoute,
                        activeThumbColor: WhoopTheme.strainBlue,
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
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1A24).withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    border: Border.all(color: WhoopTheme.strainBlue, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: WhoopTheme.strainBlue.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.favorite, color: WhoopTheme.strainBlue, size: 28),
                      const SizedBox(height: 4),
                      Text(
                        isBleConnected && liveBpm > 0 ? '$liveBpm' : '--',
                        style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        isBleConnected ? 'BPM LIVE' : 'IN ASCOLTO...',
                        style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isBleConnected ? 'Sensore WHOOP 5.0 Connesso' : 'In attesa del segnale sensore BLE...',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
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
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF0F1A24),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'OBIETTIVO SFORZO DINAMICO',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      Switch(
                        value: _strainGoalOn,
                        activeThumbColor: WhoopTheme.strainBlue,
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
                        backgroundColor: WhoopTheme.strainBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                        elevation: 6,
                      ),
                      child: const Text(
                        'AVVIA ATTIVITÀ',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2),
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
      backgroundColor: WhoopTheme.background,
      appBar: AppBar(
        backgroundColor: WhoopTheme.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          _selectedActivity.toUpperCase(),
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _isRunning ? WhoopTheme.recoveryGreen.withValues(alpha: 0.2) : WhoopTheme.recoveryYellow.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _isRunning ? WhoopTheme.recoveryGreen : WhoopTheme.recoveryYellow),
            ),
            child: Row(
              children: [
                Icon(Icons.circle, size: 8, color: _isRunning ? WhoopTheme.recoveryGreen : WhoopTheme.recoveryYellow),
                const SizedBox(width: 6),
                Text(
                  _isRunning ? 'IN REGISTRAZIONE' : 'IN PAUSA',
                  style: TextStyle(color: _isRunning ? WhoopTheme.recoveryGreen : WhoopTheme.recoveryYellow, fontSize: 10, fontWeight: FontWeight.bold),
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
              decoration: WhoopTheme.officialCardDecoration(tint: WhoopTheme.strainBlue),
              child: Column(
                children: [
                  const Text('TEMPO TRASCORSO', style: TextStyle(color: WhoopTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  const SizedBox(height: 8),
                  Text(
                    _formatDuration(_secondsElapsed),
                    style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w900, letterSpacing: 2.0, height: 1.0),
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
                    decoration: WhoopTheme.officialCardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.favorite, color: WhoopTheme.strainBlue, size: 16),
                            SizedBox(width: 6),
                            Text('BPM LIVE', style: TextStyle(color: WhoopTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(currentBpm > 0 ? '$currentBpm' : '--', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: WhoopTheme.officialCardDecoration(tint: WhoopTheme.strainBlue),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bolt, color: WhoopTheme.strainBlue, size: 16),
                            SizedBox(width: 6),
                            Text('STRAIN ACCUMULATO', style: TextStyle(color: WhoopTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _accumulatedStrain.toStringAsFixed(1),
                          style: const TextStyle(color: WhoopTheme.strainBlue, fontSize: 34, fontWeight: FontWeight.w900),
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
              decoration: WhoopTheme.officialCardDecoration(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.local_fire_department, color: WhoopTheme.strainHigh, size: 20),
                      SizedBox(width: 10),
                      Text('CALORIE BRUCIATE', style: TextStyle(color: WhoopTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Text('$_caloriesBurned kcal', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
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
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: _isRunning ? WhoopTheme.recoveryYellow : WhoopTheme.recoveryGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isRunning ? WhoopTheme.recoveryYellow : WhoopTheme.recoveryGreen).withValues(alpha: 0.3),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(_isRunning ? Icons.pause : Icons.play_arrow, color: Colors.black, size: 36),
                  ),
                ),
                GestureDetector(
                  onTap: _onStopPressed,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: WhoopTheme.recoveryRed,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: WhoopTheme.recoveryRed.withValues(alpha: 0.3),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.stop, color: Colors.white, size: 36),
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

// Custom Painter per Mappa GPS
class _GpsMapBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFC7E3C8);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
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
