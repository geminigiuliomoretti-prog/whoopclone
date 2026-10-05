import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/whoop_theme.dart';
import '../../data/database/database_helper.dart';
import '../../data/ble/ble_connection_manager.dart';
import '../../data/engine/whoop_analytics_engine.dart';
import '../../viewmodels/whoop_viewmodel.dart';

class StressCheckSheet extends StatefulWidget {
  const StressCheckSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const StressCheckSheet(),
    );
  }

  @override
  State<StressCheckSheet> createState() => _StressCheckSheetState();
}

class _StressCheckSheetState extends State<StressCheckSheet> {
  int _secondsRemaining = 60;
  bool _isMoving = false;
  bool _isCompleted = false;
  bool _noDeviceConnected = false;
  Timer? _timer;
  StreamSubscription? _hrSub;

  double _finalStressScore = 0.0;
  double _currentRmssd = 0.0;
  int _currentBpm = 0;
  final List<int> _bpmBuffer = [];

  @override
  void initState() {
    super.initState();
    _startSpotCheck();
  }

  void _startSpotCheck() {
    final viewModel = Provider.of<WhoopViewModel>(context, listen: false);
    if (viewModel.bleState != BleState.connected && viewModel.liveBpm <= 0) {
      setState(() {
        _noDeviceConnected = true;
      });
      return;
    }

    _noDeviceConnected = false;
    _currentBpm = viewModel.liveBpm > 0 ? viewModel.liveBpm : 65;
    _currentRmssd = viewModel.liveHrvRmssd > 0 ? viewModel.liveHrvRmssd : 60.0;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isMoving) return;

      final vm = Provider.of<WhoopViewModel>(context, listen: false);
      if (vm.liveBpm > 0) {
        _currentBpm = vm.liveBpm;
        _bpmBuffer.add(_currentBpm);
      }
      if (vm.liveHrvRmssd > 0) {
        _currentRmssd = vm.liveHrvRmssd;
      }

      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer?.cancel();
        _completeSpotCheck();
      }
    });
  }

  Future<void> _completeSpotCheck() async {
    final viewModel = Provider.of<WhoopViewModel>(context, listen: false);

    final double? liveBpm = _bpmBuffer.isNotEmpty
        ? (_bpmBuffer.reduce((a, b) => a + b) / _bpmBuffer.length)
        : (_currentBpm > 0 ? _currentBpm.toDouble() : null);

    final double avgBpm = liveBpm ?? (viewModel.ultimoCiclo?.fcrBpm?.toDouble() ?? viewModel.userProfile.hrRestBaseline.toDouble());

    final double hrRest = (viewModel.ultimoCiclo?.fcrBpm ?? viewModel.userProfile.hrRestBaseline).toDouble();
    final double hrvMean = viewModel.userProfile.hrvBaselineMean;
    final double hrvStd = viewModel.userProfile.hrvBaselineStd;

    final double calculatedScore = WhoopAnalyticsEngine.calculateStressScore(
      hrLive: avgBpm,
      hrRest: hrRest,
      hrvLiveMs: _currentRmssd > 0 ? _currentRmssd : hrvMean,
      baselineHrvMean: hrvMean,
      baselineHrvStd: hrvStd,
    );

    final String dataIso = DateTime.now().toIso8601String().substring(0, 10);
    final double recordedHrv = _currentRmssd > 0 ? _currentRmssd : (hrvMean > 0 ? hrvMean : 0.0);
    await DatabaseHelper().insertMisurazioneStress(
      dataIso,
      calculatedScore,
      recordedHrv,
      avgBpm.round(),
    );

    if (mounted) {
      setState(() {
        _secondsRemaining = 0;
        _finalStressScore = calculatedScore;
        _currentBpm = avgBpm.round();
        _isCompleted = true;
      });
      await viewModel.loadData();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hrSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progressPct = (60 - _secondsRemaining) / 60.0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: WhoopTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Header Sheet
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SPOT-CHECK STRESS (60S)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: WhoopTheme.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Expanded(
            child: _noDeviceConnected
                ? _buildNoDeviceView()
                : (_isCompleted ? _buildCompletedView() : _buildActiveTimerView(progressPct)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDeviceView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: WhoopTheme.recoveryRed.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.bluetooth_disabled_rounded, color: WhoopTheme.recoveryRed, size: 56),
        ),
        const SizedBox(height: 24),
        const Text(
          'DISPOSITIVO WHOOP NON CONNESSO',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            'Per effettuare la misurazione dello stress in tempo reale è necessario che la banda WHOOP sia connessa via Bluetooth e stia rilevando il battito cardiaco.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: WhoopTheme.textMuted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 36),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/device');
            },
            icon: const Icon(Icons.bluetooth_searching, color: Colors.black),
            label: const Text(
              'CONNETTI DISPOSITIVO WHOOP',
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: WhoopTheme.strainBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveTimerView(double progressPct) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Avviso Movimento Braccio
        if (_isMoving)
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: WhoopTheme.recoveryRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: WhoopTheme.recoveryRed),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: WhoopTheme.recoveryRed, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Rimani immobile per una misurazione precisa',
                    style: TextStyle(color: WhoopTheme.recoveryRed, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

        // Progress Circular Indicator & Timer Regressivo
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: CircularProgressIndicator(
                value: progressPct,
                strokeWidth: 10,
                backgroundColor: WhoopTheme.cardSurface,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _isMoving ? WhoopTheme.recoveryRed : WhoopTheme.strainBlue,
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_secondsRemaining}s',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isMoving ? 'PAUSA (MOVIMENTO)' : 'ANALISI PPG IN CORSO',
                  style: TextStyle(
                    color: _isMoving ? WhoopTheme.recoveryRed : WhoopTheme.strainBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 40),

        // Cardio Telemetry Live
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildMetricTile('BPM LIVE', '$_currentBpm', Icons.favorite, WhoopTheme.recoveryRed),
            _buildMetricTile('rMSSD', '${_currentRmssd.toStringAsFixed(1)} ms', Icons.show_chart, WhoopTheme.recoveryGreen),
          ],
        ),

        const SizedBox(height: 30),

        // Tasto Simulatore Movimento per Collaudo
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _isMoving = !_isMoving;
            });
          },
          icon: Icon(_isMoving ? Icons.play_arrow : Icons.motion_photos_on, color: WhoopTheme.textSecondary),
          label: Text(
            _isMoving ? 'RIPRENDI (STOP MOVIMENTO)' : 'SIMULA MOVIMENTO (PAUSA)',
            style: const TextStyle(color: WhoopTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: WhoopTheme.cardBorder),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedView() {
    final String label = _finalStressScore < 1.0
        ? 'STRESS BASSO / RIPOSO'
        : (_finalStressScore < 2.0 ? 'STRESS MEDIO' : 'STRESS ELEVATO');

    final Color scoreColor = _finalStressScore < 1.0
        ? WhoopTheme.recoveryGreen
        : (_finalStressScore < 2.0 ? WhoopTheme.recoveryYellow : WhoopTheme.recoveryRed);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle_outline, color: scoreColor, size: 72),
        const SizedBox(height: 16),
        const Text(
          'MISURAZIONE COMPLETATA!',
          style: TextStyle(color: WhoopTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
        const SizedBox(height: 8),
        Text(
          _finalStressScore.toStringAsFixed(2),
          style: TextStyle(color: scoreColor, fontSize: 54, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: TextStyle(color: scoreColor, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0),
        ),
        const SizedBox(height: 30),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: WhoopTheme.officialCardDecoration(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Text('BPM MEDIO', style: TextStyle(color: WhoopTheme.textMuted, fontSize: 10)),
                  Text('$_currentBpm', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                children: [
                  const Text('rMSSD', style: TextStyle(color: WhoopTheme.textMuted, fontSize: 10)),
                  Text('${_currentRmssd.toStringAsFixed(1)} ms', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                children: [
                  const Text('SALVATO SU', style: TextStyle(color: WhoopTheme.textMuted, fontSize: 10)),
                  const Text('SQLite', style: TextStyle(color: WhoopTheme.strainBlue, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _secondsRemaining = 60;
                    _isCompleted = false;
                  });
                  _startSpotCheck();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: WhoopTheme.strainBlue),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('RIPETI TEST', style: TextStyle(color: WhoopTheme.strainBlue, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WhoopTheme.strainBlue,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('SALVA E CHIUDI', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: WhoopTheme.officialCardDecoration(),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
              Text(val, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}
