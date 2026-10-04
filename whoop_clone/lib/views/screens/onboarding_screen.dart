import 'package:flutter/material.dart';
import '../../core/constants/whoop_theme.dart';

/// Modulo 22: Onboarding e Primi 4 Giorni (Sezione 22 Roadmap)
/// Percorso guidato d'inizializzazione: associazione BLE sensore, posizionamento sul corpo
/// e stato della calibrazione iniziale della baseline rolling per i primi 4 giorni.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static void show(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const OnboardingScreen()),
    );
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 2; // Giorno 3 di 4 in calibrazione iniziale
  bool _isBlePaired = true;
  String _placement = 'Polso Sinistro';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WhoopTheme.background,
      appBar: AppBar(
        title: const Text(
          'ONBOARDING & CALIBRAZIONE 4 GIORNI',
          style: TextStyle(
            color: WhoopTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner di stato calibrazione iniziale
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: WhoopTheme.strainBlue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: WhoopTheme.strainBlue.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.tune, color: WhoopTheme.strainBlue, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'CALIBRAZIONE BASELINE IN CORSO',
                        style: TextStyle(
                          color: WhoopTheme.strainBlue,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Il sensore WHOOP 5.0 sta apprendendo la tua fisiologia unica (FCR, VFC, Temperatura e Architettura del Sonno).',
                    style: TextStyle(color: WhoopTheme.textPrimary, fontSize: 12, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  // Progress indicator 4 giorni
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: (_currentStep + 1) / 4.0,
                          backgroundColor: WhoopTheme.cardBorder,
                          valueColor: const AlwaysStoppedAnimation<Color>(WhoopTheme.strainBlue),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'GIORNO ${_currentStep + 1} / 4',
                        style: const TextStyle(color: WhoopTheme.strainBlue, fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Stepper delle 4 Fasi di Onboarding
            const Text(
              'PERCORSO GUIDATO INIZIALIZZAZIONE',
              style: TextStyle(
                color: WhoopTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),

            _buildStepCard(
              stepNum: 1,
              title: '1. Associazione Sensore BLE WHOOP 5.0',
              subtitle: 'Sensore rilevato e associato: WHOOP 5A00479315',
              isCompleted: _isBlePaired,
              icon: Icons.bluetooth_connected,
            ),

            _buildStepCard(
              stepNum: 2,
              title: '2. Posizionamento Corretto sul Corpo',
              subtitle: 'Indossato su: $_placement (Aderente 1cm sopra l\'osso del polso)',
              isCompleted: true,
              icon: Icons.accessibility_new,
            ),

            _buildStepCard(
              stepNum: 3,
              title: '3. Calibrazione Baseline (Primi 4 Giorni)',
              subtitle: 'Raccolta campioni notturni per stabilire la tua media VFC e FCR.',
              isCompleted: false,
              icon: Icons.analytics,
            ),

            _buildStepCard(
              stepNum: 4,
              title: '4. Attivazione Motore Algoritmi Biometrici',
              subtitle: 'Sblocco completo delle stime di Recovery, Sleep Need e Stress 24h.',
              isCompleted: false,
              icon: Icons.verified_user,
            ),

            const SizedBox(height: 24),

            // Pulsante Completamento Manuale / Salta Onboarding per utenti esperti
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Onboarding e Calibrazione iniziale completati!')),
                  );
                },
                icon: const Icon(Icons.check_circle, color: Colors.black),
                label: const Text(
                  'COMPLETA E VAI ALLA HOME',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WhoopTheme.recoveryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required int stepNum,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required IconData icon,
  }) {
    return Card(
      color: WhoopTheme.cardSurface,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCompleted ? WhoopTheme.recoveryGreen : WhoopTheme.cardBorder,
          child: Icon(
            isCompleted ? Icons.check : icon,
            color: isCompleted ? Colors.black : WhoopTheme.textSecondary,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isCompleted ? WhoopTheme.textPrimary : WhoopTheme.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 11),
        ),
      ),
    );
  }
}
