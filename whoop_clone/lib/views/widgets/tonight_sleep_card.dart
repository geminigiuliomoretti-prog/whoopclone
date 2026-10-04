import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/whoop_theme.dart';
import '../../viewmodels/whoop_viewmodel.dart';
import 'smart_alarm_modal.dart';

/// Card "SONNO DI STANOTTE" (Identica al 100% agli screenshot di reference_UI)
class TonightSleepCard extends StatelessWidget {
  final double sleepNeedMinutes;

  const TonightSleepCard({
    super.key,
    this.sleepNeedMinutes = 480.0,
  });

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<WhoopViewModel>(context);
    final isAlarmEnabled = viewModel.isAlarmEnabled;
    final alarmTime = viewModel.alarmTime;
    final alarmFormatted = '${alarmTime.hour.toString().padLeft(2, '0')}:${alarmTime.minute.toString().padLeft(2, '0')}';

    final alarmDateTime = DateTime(2026, 1, 1, alarmTime.hour, alarmTime.minute);
    final bedDateTime = alarmDateTime.subtract(Duration(minutes: sleepNeedMinutes.round()));
    final bedFormatted = '${bedDateTime.hour.toString().padLeft(2, '0')}:${bedDateTime.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: WhoopTheme.officialCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: SONNO DI STANOTTE >
          GestureDetector(
            onTap: () => SmartAlarmModal.show(context),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SONNO DI STANOTTE',
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
          ),

          const SizedBox(height: 16),

          // Due Colonne: Ora Consigliata | Sveglia
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Sinistra: Ora consigliata per andare a letto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.wb_twilight, color: WhoopTheme.textSecondary, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          bedFormatted,
                          style: const TextStyle(
                            color: WhoopTheme.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'ORA CONSIGLIATA\nPER ANDARE A LETTO',
                      style: TextStyle(
                        color: WhoopTheme.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              // Separatore tratteggiato orizzontale
              const Text('-----', style: TextStyle(color: WhoopTheme.cardBorder, fontWeight: FontWeight.bold)),

              // Destra: Sveglia Disattivata / Attivata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Icon(Icons.wb_sunny_outlined, color: WhoopTheme.textSecondary, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          alarmFormatted,
                          style: const TextStyle(
                            color: WhoopTheme.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAlarmEnabled ? 'SVEGLIA ATTIVATA' : 'SVEGLIA\nDISATTIVATA',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: isAlarmEnabled ? WhoopTheme.recoveryGreen : const Color(0xFFFFB74D),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Tasto Sospeso Pill: IMPOSTA SVEGLIA (con icona sensore Whoop)
          InkWell(
            onTap: () => SmartAlarmModal.show(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF263238),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: WhoopTheme.cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    WhoopTheme.puckWhite,
                    height: 16,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.vibration, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'IMPOSTA SVEGLIA',
                    style: TextStyle(
                      color: WhoopTheme.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
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
}
