import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/whoop_theme.dart';

/// Modal Esercizi di Respirazione Guidata (Cyclic Sighing) (Sezione 12 Roadmap)
/// Riduce lo stress istantaneo stimolando il nervo vago (doppio inspiro + lungo espiro)
class CyclicSighingModal extends StatefulWidget {
  const CyclicSighingModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const CyclicSighingModal(),
    );
  }

  @override
  State<CyclicSighingModal> createState() => _CyclicSighingModalState();
}

class _CyclicSighingModalState extends State<CyclicSighingModal> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  Timer? _timer;
  int _secondsLeft = 180; // Sessione da 3 minuti
  bool _isActive = false;
  String _phaseLabel = 'Premi Avvia per iniziare';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 30), // Primo inspiro
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.6), weight: 15), // Secondo inspiro
      TweenSequenceItem(tween: Tween(begin: 1.6, end: 1.0), weight: 55), // Espiro lungo
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  void _startSession() {
    setState(() {
      _isActive = true;
      _secondsLeft = 180;
    });

    _controller.repeat();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        _stopSession();
      } else {
        setState(() {
          _secondsLeft--;
          final cycleTime = (180 - _secondsLeft) % 8;
          if (cycleTime < 3) {
            _phaseLabel = '1. Inhala profondo (Naso)';
          } else if (cycleTime < 4) {
            _phaseLabel = '2. Inhala ancora un po\' (Naso)';
          } else {
            _phaseLabel = '3. Espira lentamente (Bocca)';
          }
        });
      }
    });
  }

  void _stopSession() {
    _timer?.cancel();
    _controller.stop();
    setState(() {
      _isActive = false;
      _phaseLabel = 'Sessione Completata!';
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: WhoopTheme.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: WhoopTheme.cardBorder, width: 1.5)),
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: WhoopTheme.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'RESPIRAZIONE GUIDATA (CYCLIC SIGHING)',
            style: TextStyle(
              color: WhoopTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Attiva il sistema nervoso parasimpatico e riduce l\'indice di stress istantaneo.',
            style: TextStyle(color: WhoopTheme.textSecondary, fontSize: 11),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 30),

          // Cerchio Animato di Espansione / Contrazione
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isActive ? _scaleAnimation.value : 1.0,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        WhoopTheme.strainBlue.withOpacity(0.8),
                        WhoopTheme.strainBlue.withOpacity(0.2),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: WhoopTheme.strainBlue.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${(_secondsLeft ~/ 60).toString().padLeft(2, '0')}:${(_secondsLeft % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          Text(
            _phaseLabel,
            style: const TextStyle(
              color: WhoopTheme.recoveryGreen,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isActive ? _stopSession : _startSession,
              icon: Icon(_isActive ? Icons.stop : Icons.play_arrow, color: Colors.black),
              label: Text(
                _isActive ? 'INTERROMPI SESSIONE' : 'AVVIA RESPIRAZIONE (3 MIN)',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isActive ? WhoopTheme.recoveryRed : WhoopTheme.strainBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
