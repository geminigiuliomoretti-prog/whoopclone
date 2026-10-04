import 'package:flutter/material.dart';
import '../../core/constants/whoop_theme.dart';
import 'strength_trainer_modal.dart';
import 'manual_activity_modal.dart';
import '../screens/journal_screen.dart';
import '../screens/live_activity_tracker_screen.dart';

class WhoopFabModal extends StatelessWidget {
  const WhoopFabModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const WhoopFabModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: WhoopTheme.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: WhoopTheme.cardBorder, width: 1.5),
        ),
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle bar
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
            'AZIONI RAPIDE WHOOP 5.0',
            style: TextStyle(
              color: WhoopTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),

          // 1. REGISTRA RETROATTIVAMENTE (SONNO PASSATO / ATTIVITÀ PASSATA)
          _buildActionButton(
            context: context,
            icon: Icons.history_toggle_off_rounded,
            title: 'AGGIUNGI ATTIVITÀ PASSATA / SONNO',
            subtitle: 'Inserisci retroattivamente orari di Sonno o Allenamenti passati',
            color: WhoopTheme.sleepPurple,
            onTap: () {
              Navigator.pop(context);
              ManualActivityModal.show(context);
            },
          ),

          // 2. AVVIA ATTIVITÀ IN TEMPO REALE
          _buildActionButton(
            context: context,
            icon: Icons.play_arrow_rounded,
            title: 'AVVIA ATTIVITÀ LIVE',
            subtitle: 'Tracciamento in tempo reale: Cronometro, BPM live e Strain',
            color: WhoopTheme.strainBlue,
            onTap: () {
              Navigator.pop(context);
              LiveActivityTrackerScreen.start(context);
            },
          ),

          // 3. ALLENATORE FORZA (Strength Trainer)
          _buildActionButton(
            context: context,
            icon: Icons.fitness_center_sharp,
            title: 'ALLENATORE FORZA',
            subtitle: 'Calcola Muscular Load (Serie, Reps, Carico, Velocità 3 Assi)',
            color: WhoopTheme.strainHigh,
            onTap: () {
              Navigator.pop(context);
              StrengthTrainerModal.show(context);
            },
          ),

          // 4. AGGIUNGI AL MIO DIARIO — naviga a JournalScreen
          _buildActionButton(
            context: context,
            icon: Icons.book,
            title: 'AGGIUNGI AL MIO DIARIO',
            subtitle: 'Registra le abitudini della giornata (Magnesio, Caffeina, ecc.)',
            color: WhoopTheme.strainBlue,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const JournalScreen()),
              );
            },
          ),

          // 5. CREA WHOOP LIVE
          _buildActionButton(
            context: context,
            icon: Icons.videocam,
            title: 'CREA WHOOP LIVE',
            subtitle: 'Genera overlay video/foto con dati biometrici in tempo reale',
            color: WhoopTheme.strainBlue,
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Whoop Live Overlay creato!')),
              );
            },
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Card(
        color: WhoopTheme.background,
        child: ListTile(
          onTap: onTap,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: WhoopTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 11),
          ),
          trailing: const Icon(Icons.chevron_right, color: WhoopTheme.textMuted, size: 18),
        ),
      ),
    );
  }
}
