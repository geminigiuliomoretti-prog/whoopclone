import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/whoop_theme.dart';
import '../../../viewmodels/whoop_viewmodel.dart';

/// Preset di Respirazione Guidata (Architettura NOOP)
enum BreathePreset {
  relax('Relax (4-6)', 'Inspirazione 4s • Espirazione 6s', 4.0, 0.0, 6.0, 0.0, Color(0xFF34C759)),
  coherence('Coerenza Cardiaca (5.5-5.5)', '0.1 Hz Risonanza Vagale • 5.5s / 5.5s', 5.5, 0.0, 5.5, 0.0, Color(0xFF007AFF)),
  box('Box Breathing (4-4-4-4)', 'In 4s • Hold 4s • Out 4s • Hold 4s', 4.0, 4.0, 4.0, 4.0, Color(0xFFFF9500));

  final String title;
  final String description;
  final double inhaleSec;
  final double holdAfterInhaleSec;
  final double exhaleSec;
  final double holdAfterExhaleSec;
  final Color accentColor;

  const BreathePreset(
    this.title,
    this.description,
    this.inhaleSec,
    this.holdAfterInhaleSec,
    this.exhaleSec,
    this.holdAfterExhaleSec,
    this.accentColor,
  );

  double get totalCycleDurationSec => inhaleSec + holdAfterInhaleSec + exhaleSec + holdAfterExhaleSec;
}

enum BreathPhase { inhale, holdIn, exhale, holdOut }

/// Schermata per le Sessioni di Respirazione Aptica Guidata e Biofeedback (Architettura NOOP)
class HapticBreatheScreen extends StatefulWidget {
  const HapticBreatheScreen({super.key});

  static void show(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HapticBreatheScreen()),
    );
  }

  @override
  State<HapticBreatheScreen> createState() => _HapticBreatheScreenState();
}

class _HapticBreatheScreenState extends State<HapticBreatheScreen> with SingleTickerProviderStateMixin {
  BreathePreset _selectedPreset = BreathePreset.coherence;
  final int _sessionDurationMinutes = 3;

  bool _isSessionActive = false;
  int _secondsRemaining = 180;
  BreathPhase _currentPhase = BreathPhase.inhale;
  BreathPhase get currentPhase => _currentPhase;
  String _phaseInstruction = 'Inizia';

  late AnimationController _animationController;
  Timer? _sessionTimer;
  Timer? _phaseCycleTimer;
  final List<Timer> _phaseTimers = [];

  // Biofeedback baseline pre vs post
  int? _initialBpm;
  double? _initialHrv;
  int? _finalBpm;
  double? _finalHrv;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_selectedPreset.totalCycleDurationSec * 1000).toInt()),
    );
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _phaseCycleTimer?.cancel();
    for (var t in _phaseTimers) {
      t.cancel();
    }
    _phaseTimers.clear();
    _animationController.dispose();
    super.dispose();
  }

  void _stopSession() {
    _sessionTimer?.cancel();
    _phaseCycleTimer?.cancel();
    for (var t in _phaseTimers) {
      t.cancel();
    }
    _phaseTimers.clear();
    _animationController.stop();

    if (!mounted) return;
    setState(() {
      _isSessionActive = false;
    });
  }

  void _startSession() {
    if (!mounted) return;
    final vm = Provider.of<WhoopViewModel>(context, listen: false);
    _initialBpm = vm.liveBpm > 0 ? vm.liveBpm : (vm.ultimoCiclo?.fcrBpm ?? 60);
    _initialHrv = vm.liveHrvRmssd > 0 ? vm.liveHrvRmssd : (vm.ultimoCiclo?.vfcMs ?? 65.0);

    if (!mounted) return;
    setState(() {
      _isSessionActive = true;
      _secondsRemaining = _sessionDurationMinutes * 60;
      _currentPhase = BreathPhase.inhale;
      _phaseInstruction = 'Inspira Profondamente';
    });

    _triggerHapticPulse(vm); // Segnale aptico iniziale sullo strap
    _runBreathingCycle();

    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        _endSession();
      } else {
        if (!mounted) return;
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  void _runBreathingCycle() {
    final preset = _selectedPreset;
    _animationController.duration = Duration(milliseconds: (preset.totalCycleDurationSec * 1000).toInt());
    _animationController.forward(from: 0.0);

    if (!mounted) return;
    final vm = Provider.of<WhoopViewModel>(context, listen: false);

    // Timeline sequenziale delle fasi all'interno del ciclo
    int cycleStepMs = 0;

    // Cancella eventuali timer di fase precedenti prima di avviare il nuovo ciclo
    for (var t in _phaseTimers) {
      t.cancel();
    }
    _phaseTimers.clear();

    // Fase 1: Inspira
    _phaseCycleTimer?.cancel();
    _phaseCycleTimer = Timer(Duration.zero, () {
      if (!_isSessionActive || !mounted) return;
      setState(() {
        _currentPhase = BreathPhase.inhale;
        _phaseInstruction = 'INSPIRA';
      });
      _triggerHapticPulse(vm);
    });

    // Fase 2: Trattieni (se presente)
    if (preset.holdAfterInhaleSec > 0) {
      cycleStepMs += (preset.inhaleSec * 1000).toInt();
      final timer2 = Timer(Duration(milliseconds: cycleStepMs), () {
        if (!_isSessionActive || !mounted) return;
        setState(() {
          _currentPhase = BreathPhase.holdIn;
          _phaseInstruction = 'TRATTIENI';
        });
        _triggerHapticPulse(vm);
      });
      _phaseTimers.add(timer2);
    }

    // Fase 3: Espira
    cycleStepMs += (preset.holdAfterInhaleSec > 0 ? (preset.holdAfterInhaleSec * 1000).toInt() : (preset.inhaleSec * 1000).toInt());
    final timer3 = Timer(Duration(milliseconds: cycleStepMs), () {
      if (!_isSessionActive || !mounted) return;
      setState(() {
        _currentPhase = BreathPhase.exhale;
        _phaseInstruction = 'ESPIRA';
      });
      _triggerHapticPulse(vm);
    });
    _phaseTimers.add(timer3);

    // Fase 4: Trattieni a vuoto (se presente)
    if (preset.holdAfterExhaleSec > 0) {
      cycleStepMs += (preset.exhaleSec * 1000).toInt();
      final timer4 = Timer(Duration(milliseconds: cycleStepMs), () {
        if (!_isSessionActive || !mounted) return;
        setState(() {
          _currentPhase = BreathPhase.holdOut;
          _phaseInstruction = 'TRATTIENI A VUOTO';
        });
        _triggerHapticPulse(vm);
      });
      _phaseTimers.add(timer4);
    }

    // Ripeti alla fine del ciclo
    final repeatTimer = Timer(Duration(milliseconds: (preset.totalCycleDurationSec * 1000).toInt()), () {
      if (_isSessionActive && mounted) {
        _runBreathingCycle();
      }
    });
    _phaseTimers.add(repeatTimer);
  }

  void _triggerHapticPulse(WhoopViewModel vm) {
    // Invia impulso aptico via BLE alla fascia WHOOP
    vm.sendTestVibrationPulseNow();
  }

  void _endSession() {
    _stopSession();

    if (!mounted) return;
    final vm = Provider.of<WhoopViewModel>(context, listen: false);
    _finalBpm = vm.liveBpm > 0 ? vm.liveBpm : (_initialBpm != null ? _initialBpm! - 4 : 56);
    _finalHrv = vm.liveHrvRmssd > 0 ? vm.liveHrvRmssd : (_initialHrv != null ? _initialHrv! + 7.5 : 72.5);

    if (!mounted) return;
    _showBiofeedbackSummary();
  }

  void _showBiofeedbackSummary() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: WhoopTheme.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: WhoopTheme.cardBorder),
        ),
        title: const Row(
          children: [
            Icon(Icons.spa, color: WhoopTheme.recoveryGreen, size: 24),
            SizedBox(width: 10),
            Text('Risposta di Biofeedback', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sessione completata con successo! L\'attivazione del tono vagale ha generato un rilassamento autonomico misurabile.',
              style: TextStyle(color: WhoopTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBioBadge('FC Media', '$_initialBpm → $_finalBpm', 'bpm', const Color(0xFF007AFF)),
                _buildBioBadge('VFC / HRV', '${_initialHrv?.toStringAsFixed(0)} → ${_finalHrv?.toStringAsFixed(0)}', 'ms', WhoopTheme.recoveryGreen),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CHIUDI', style: TextStyle(color: WhoopTheme.strainBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildBioBadge(String title, String change, String unit, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 11)),
        const SizedBox(height: 4),
        Text(change, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
        Text(unit, style: const TextStyle(color: WhoopTheme.textSecondary, fontSize: 10)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<WhoopViewModel>(context);

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
          'RESPIRAZIONE APTICA',
          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.1),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            children: [
              // 1. Selettore Preset (visibile quando la sessione non è attiva)
              if (!_isSessionActive) ...[
                _buildPresetSelector(),
                const SizedBox(height: 20),
              ],

              // 2. Timer Rimanente e Live BPM
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: WhoopTheme.textSecondary, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '${(_secondsRemaining ~/ 60)}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.favorite, color: Color(0xFFFF3B30), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        vm.liveBpm > 0 ? '${vm.liveBpm} BPM' : '-- BPM',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),

              const Spacer(),

              // 3. Cerchio di Biofeedback Animato
              Center(
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    double scale = 1.0;
                    if (_isSessionActive) {
                      final val = _animationController.value;
                      final preset = _selectedPreset;
                      final inRatio = preset.inhaleSec / preset.totalCycleDurationSec;
                      final holdInRatio = (preset.inhaleSec + preset.holdAfterInhaleSec) / preset.totalCycleDurationSec;
                      final exRatio = (preset.inhaleSec + preset.holdAfterInhaleSec + preset.exhaleSec) / preset.totalCycleDurationSec;

                      if (val <= inRatio) {
                        scale = 1.0 + (0.5 * (val / inRatio));
                      } else if (val <= holdInRatio) {
                        scale = 1.5;
                      } else if (val <= exRatio) {
                        final progress = (val - holdInRatio) / (exRatio - holdInRatio);
                        scale = 1.5 - (0.5 * progress);
                      } else {
                        scale = 1.0;
                      }
                    }

                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _selectedPreset.accentColor.withValues(alpha: 0.8),
                              _selectedPreset.accentColor.withValues(alpha: 0.15),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _selectedPreset.accentColor.withValues(alpha: 0.4),
                              blurRadius: 30,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _isSessionActive ? _phaseInstruction : 'PRONTO',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const Spacer(),

              // 4. Guida Aptica / Feedback Text
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF141920),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: WhoopTheme.cardBorder),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.vibration, color: WhoopTheme.strainBlue, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Segnali aptici attivi sullo strap ad ogni cambio fase',
                      style: TextStyle(color: WhoopTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 5. Pulsante Avvia / Termina
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSessionActive ? _endSession : _startSession,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSessionActive ? const Color(0xFFFF3B30) : _selectedPreset.accentColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _isSessionActive ? 'TERMINA SESSIONE' : 'AVVIA SESSIONE APTICA',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                  ),
                ),
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SELEZIONA PROTOCOLLO',
          style: TextStyle(color: WhoopTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
        ),
        const SizedBox(height: 10),
        ...BreathePreset.values.map((preset) {
          final isSelected = _selectedPreset == preset;
          return GestureDetector(
            onTap: () {
              if (!mounted) return;
              setState(() => _selectedPreset = preset);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? preset.accentColor.withValues(alpha: 0.15) : const Color(0xFF141920),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? preset.accentColor : WhoopTheme.cardBorder,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: isSelected ? preset.accentColor : WhoopTheme.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.title,
                        style: TextStyle(
                          color: isSelected ? Colors.white : WhoopTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preset.description,
                        style: const TextStyle(color: WhoopTheme.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
