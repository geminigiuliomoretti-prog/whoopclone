import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/nature_theme.dart';
import '../../viewmodels/whoop_viewmodel.dart';
import 'smart_alarm_modal.dart';

/// Card "SONNO DI STANOTTE" Riprogettata
///
/// Appartiene alla nuova identità visiva:
/// - Superficie dark navy rilassante con bordi minerali sottili
/// - Accenti twilight e alba controllati
/// - Tipografia raffinata e proporzioni organiche
/// - Zero modifiche alla logica o ai calcoli della sveglia/sonno
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
    final alarmFormatted =
        '${alarmTime.hour.toString().padLeft(2, '0')}:${alarmTime.minute.toString().padLeft(2, '0')}';

    final alarmDateTime = DateTime(2026, 1, 1, alarmTime.hour, alarmTime.minute);
    final bedDateTime = alarmDateTime.subtract(Duration(minutes: sleepNeedMinutes.round()));
    final bedFormatted =
        '${bedDateTime.hour.toString().padLeft(2, '0')}:${bedDateTime.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: NatureTheme.organicCardDecoration(isDark: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: SONNO DI STANOTTE >
          GestureDetector(
            onTap: () => SmartAlarmModal.show(context),
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: NatureColors.tealLight.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.nightlight_round,
                          color: NatureColors.tealLight,
                          size: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'SONNO DI STANOTTE',
                      style: TextStyle(
                        color: NatureColors.secondaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: NatureColors.secondaryText,
                  size: 18,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Due Colonne: Ora Consigliata | Sveglia Intelligente
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Sinistra: Ora consigliata per andare a letto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.wb_twilight_rounded,
                            color: NatureColors.secondaryText,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            bedFormatted,
                            style: const TextStyle(
                              color: NatureColors.primaryText,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'ORA CONSIGLIATA\nPER ANDARE A LETTO',
                      style: TextStyle(
                        color: NatureColors.mutedText,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              // Separatore verticale delicato
              Container(
                height: 38,
                width: 1,
                color: NatureColors.borderSubtle,
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),

              // Destra: Sveglia Disattivata / Attivata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Icon(
                            Icons.alarm_rounded,
                            color: NatureColors.secondaryText,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            alarmFormatted,
                            style: const TextStyle(
                              color: NatureColors.primaryText,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAlarmEnabled ? 'SVEGLIA ATTIVATA' : 'SVEGLIA\nDISATTIVATA',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: isAlarmEnabled ? NatureColors.recoveryAccent : NatureColors.amberWarm,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
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

          // Tasto Capsule: IMPOSTA SVEGLIA
          InkWell(
            onTap: () => SmartAlarmModal.show(context),
            borderRadius: BorderRadius.circular(NatureRadius.pill),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: NatureColors.surfaceHighlight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(NatureRadius.pill),
                border: Border.all(
                  color: NatureColors.borderSubtle,
                  width: 0.85,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.vibration_rounded,
                    color: NatureColors.primaryText,
                    size: 15,
                  ),
                  SizedBox(width: 7),
                  Text(
                    'IMPOSTA SVEGLIA',
                    style: TextStyle(
                      color: NatureColors.primaryText,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
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
