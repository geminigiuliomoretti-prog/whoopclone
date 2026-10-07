import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/whoop_theme.dart';
import '../../viewmodels/whoop_viewmodel.dart';

/// Modal Sveglia Aptica Strategica WHOOP 5.0 (Design Ufficiale Premium)
/// Supporta 3 modalità di risveglio: Orario Esatto, Target Sonno (Peak/Perform/Get By) e Zona Verde (Recovery >=67%).
class SmartAlarmModal extends StatefulWidget {
  const SmartAlarmModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const SmartAlarmModal(),
    );
  }

  @override
  State<SmartAlarmModal> createState() => _SmartAlarmModalState();
}

class _SmartAlarmModalState extends State<SmartAlarmModal> {
  // Modalità: 0 = Tempo Esatto, 1 = Obiettivo Sonno, 2 = Zona Verde
  int _selectedMode = 1;
  TimeOfDay _alarmTime = const TimeOfDay(hour: 7, minute: 0);

  // Target Sonno (100 = Peak, 85 = Perform, 70 = Get By)
  int _targetGoalIdx = 1; // Perform 85% default

  // Intensità Vibrazione Aptica (0 = Delicata, 1 = Standard, 2 = Forte)
  int _hapticIntensity = 1;
  bool _isAlarmEnabled = true;

  @override
  void initState() {
    super.initState();
    final vm = Provider.of<WhoopViewModel>(context, listen: false);
    _isAlarmEnabled = vm.isAlarmEnabled;
    _alarmTime = vm.alarmTime;
    _selectedMode = vm.alarmModeIdx;
    _targetGoalIdx = vm.alarmGoalIdx;
    _hapticIntensity = vm.alarmHapticIntensity;
  }

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<WhoopViewModel>(context);
    final double baseNeedMin = (vm.ultimoCiclo?.sonnoRichiestoMin != null && vm.ultimoCiclo!.sonnoRichiestoMin! > 0)
        ? vm.ultimoCiclo!.sonnoRichiestoMin!
        : (vm.userProfile.sleepBaselineMin > 0 ? vm.userProfile.sleepBaselineMin.toDouble() : 480.0);

    String formatHours(double min) {
      final h = min.toInt() ~/ 60;
      final m = min.toInt() % 60;
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }

    final sleepGoalsDynamic = [
      {'title': 'PEAK', 'pct': '100%', 'hours': formatHours(baseNeedMin * 1.0), 'sub': 'Massimo rendimento'},
      {'title': 'PERFORM', 'pct': '85%', 'hours': formatHours(baseNeedMin * 0.85), 'sub': 'Prestazione ottimale'},
      {'title': 'GET BY', 'pct': '70%', 'hours': formatHours(baseNeedMin * 0.70), 'sub': 'Recupero minimo'},
    ];

    final goalMultipliers = [1.0, 0.85, 0.70];
    final selectedMult = goalMultipliers[_targetGoalIdx.clamp(0, 2)];
    final targetSleepMin = (baseNeedMin * selectedMult).round();

    final now = DateTime.now();
    DateTime alarmDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _alarmTime.hour,
      _alarmTime.minute,
    );
    if (alarmDateTime.isBefore(now)) {
      alarmDateTime = alarmDateTime.add(const Duration(days: 1));
    }
    final bedtime = alarmDateTime.subtract(Duration(minutes: targetSleepMin + 15));
    final bedtimeStr = '${bedtime.hour.toString().padLeft(2, '0')}:${bedtime.minute.toString().padLeft(2, '0')}';
    final targetSleepStr = formatHours(targetSleepMin.toDouble());

    return Container(
      decoration: const BoxDecoration(
        color: WhoopTheme.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: WhoopTheme.cardBorder, width: 1.5)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: WhoopTheme.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: WhoopTheme.strainBlue.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.alarm, color: WhoopTheme.strainBlue, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SVEGLIA SMART APTICA',
                          style: TextStyle(
                            color: WhoopTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Text(
                          'Vibrazione stealth sensore WHOOP 5.0',
                          style: TextStyle(color: WhoopTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                Switch(
                  value: _isAlarmEnabled,
                  activeThumbColor: WhoopTheme.strainBlue,
                  onChanged: (val) => setState(() => _isAlarmEnabled = val),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Selettore Modalità (Segmented Buttons)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: WhoopTheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: WhoopTheme.cardBorder),
              ),
              child: Row(
                children: [
                  _buildSegmentButton(0, 'TEMPO ESATTO', Icons.access_time),
                  _buildSegmentButton(1, 'OBIETTIVO SONNO', Icons.hotel),
                  _buildSegmentButton(2, 'ZONA VERDE', Icons.verified),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Display Orario Grande con Neon Glow
            Center(
              child: GestureDetector(
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: _alarmTime);
                  if (picked != null) setState(() => _alarmTime = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: WhoopTheme.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: WhoopTheme.strainBlue.withValues(alpha: 0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: WhoopTheme.strainBlue.withValues(alpha: 0.15),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _alarmTime.format(context),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.edit, color: WhoopTheme.strainBlue, size: 22),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Dettaglio in base alla modalità selezionata
            if (_selectedMode == 1) ...[
              const Text(
                'TARGET DI SONNO DESIDERATO',
                style: TextStyle(
                  color: WhoopTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: List.generate(sleepGoalsDynamic.length, (i) {
                  final goal = sleepGoalsDynamic[i];
                  final isSelected = _targetGoalIdx == i;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _targetGoalIdx = i),
                      child: Container(
                        margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? WhoopTheme.strainBlue.withValues(alpha: 0.2) : WhoopTheme.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? WhoopTheme.strainBlue : WhoopTheme.cardBorder,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(goal['title']!, style: TextStyle(color: isSelected ? WhoopTheme.strainBlue : Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                Text(goal['pct']!, style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 9)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(goal['hours']!, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 2),
                            Text(goal['sub']!, style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 9)),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ] else if (_selectedMode == 2) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: WhoopTheme.officialCardDecoration(tint: WhoopTheme.recoveryGreen),
                child: const Row(
                  children: [
                    Icon(Icons.verified, color: WhoopTheme.recoveryGreen, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('RISVEGLIO IN ZONA VERDE', style: TextStyle(color: WhoopTheme.recoveryGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                          SizedBox(height: 2),
                          Text('La sveglia aptica ti sveglierà nella finestra tra le 06:15 e le 07:15 non appena la stima del tuo Recupero raggiunge il 67% (Verde).', style: TextStyle(color: Colors.white, fontSize: 11, height: 1.3)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Card Orario Consigliato Coricarsi
            Container(
              padding: const EdgeInsets.all(14),
              decoration: WhoopTheme.officialCardDecoration(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ORARIO CONSIGLIATO BEDTIME', style: TextStyle(color: WhoopTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Coricati entro le $bedtimeStr', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: WhoopTheme.strainBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Fabbisogno $targetSleepStr', style: const TextStyle(color: WhoopTheme.strainBlue, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Selettore Intensità Vibrazione Aptica
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Intensità Vibrazione', style: TextStyle(color: WhoopTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                Row(
                  children: List.generate(3, (idx) {
                    final labels = ['Lieve', 'Media', 'Forte'];
                    final isSel = _hapticIntensity == idx;
                    return GestureDetector(
                      onTap: () => setState(() => _hapticIntensity = idx),
                      child: Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSel ? WhoopTheme.strainBlue : WhoopTheme.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSel ? WhoopTheme.strainBlue : WhoopTheme.cardBorder),
                        ),
                        child: Text(labels[idx], style: TextStyle(color: isSel ? Colors.white : WhoopTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    );
                  }),
                ),
              ],
            ),

            // Pulsante Prova Vibrazione Immediata
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final viewModel = Provider.of<WhoopViewModel>(context, listen: false);
                  final success = await viewModel.scheduleHapticAlarm(
                    DateTime.now().add(const Duration(seconds: 1)),
                    vibrationPattern: _hapticIntensity + 1,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? '⚡ Segnale di prova inviato! Il bracciale WHOOP sta vibrando...'
                              : '⚠️ Bracciale non connesso in BLE. Connettilo nella schermata Dispositivo.',
                        ),
                        backgroundColor: success ? WhoopTheme.strainBlue : Colors.orange,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.vibration, color: WhoopTheme.strainBlue, size: 20),
                label: const Text(
                  '⚡ PROVA VIBRAZIONE ADESSO (1s)',
                  style: TextStyle(
                    color: WhoopTheme.strainBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: WhoopTheme.strainBlue, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Pulsante d'azione finale
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final viewModel = Provider.of<WhoopViewModel>(context, listen: false);
                  await viewModel.saveAlarmSettings(
                    isEnabled: _isAlarmEnabled,
                    alarmTime: _alarmTime,
                    selectedMode: _selectedMode,
                    targetGoalIdx: _targetGoalIdx,
                    hapticIntensity: _hapticIntensity,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _isAlarmEnabled
                              ? 'Sveglia Aptica WHOOP 5.0 salvata! Segnale di vibrazione inviato al bracciale.'
                              : 'Sveglia disattivata con successo.',
                        ),
                        backgroundColor: _isAlarmEnabled ? WhoopTheme.recoveryGreen : WhoopTheme.cardSurface,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.alarm_on, color: Colors.black),
                label: const Text(
                  'ATTIVA SVEGLIA APTICA',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1.0,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WhoopTheme.strainBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton(int modeIndex, String label, IconData icon) {
    final isSelected = _selectedMode == modeIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMode = modeIndex),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? WhoopTheme.strainBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? Colors.white : WhoopTheme.textMuted, size: 16),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : WhoopTheme.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
