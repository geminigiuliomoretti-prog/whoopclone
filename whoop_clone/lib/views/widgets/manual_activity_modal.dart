import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/whoop_theme.dart';
import '../../data/models/allenamento.dart';
import '../../viewmodels/whoop_viewmodel.dart';

/// Modal Bottom Sheet per la registrazione manuale e retroattiva di Sonno ed Allenamenti
class ManualActivityModal extends StatefulWidget {
  const ManualActivityModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const ManualActivityModal(),
      ),
    );
  }

  @override
  State<ManualActivityModal> createState() => _ManualActivityModalState();
}

class _ManualActivityModalState extends State<ManualActivityModal> {
  int _selectedTab = 0;

  // Due righe distinte Data e Ora per Inizio e Fine
  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;

  // Campi Allenamento Passato
  String _selectedActivityType = 'Corsa';
  final List<String> _activityTypes = [
    'Corsa',
    'Ciclismo',
    'Palestra',
    'Camminata',
    'Nuoto',
    'Yoga',
    'HIIT',
    'Calisthenics',
    'Calcio',
    'Tennis',
  ];
  double _workoutIntensity = 12.0; // Strain stimato (1.0 - 21.0)
  int _estimatedAvgHr = 145;

  @override
  void initState() {
    super.initState();
    _updateDefaultTimes();
  }

  void _updateDefaultTimes() {
    final now = DateTime.now();
    if (_selectedTab == 0) {
      // Sonno Passato: Inizio ieri sera 23:00, Fine oggi mattina 07:30 (o now se prima)
      _startDate = now.subtract(const Duration(days: 1));
      _startTime = const TimeOfDay(hour: 23, minute: 0);

      _endDate = now;
      if (now.hour < 8) {
        _endTime = TimeOfDay(hour: now.hour, minute: now.minute);
      } else {
        _endTime = const TimeOfDay(hour: 7, minute: 30);
      }
    } else {
      // Allenamento: di solito 1 ora fa fino ad adesso
      final oneHourAgo = now.subtract(const Duration(hours: 1));
      _startDate = oneHourAgo;
      _startTime = TimeOfDay(hour: oneHourAgo.hour, minute: oneHourAgo.minute);
      _endDate = now;
      _endTime = TimeOfDay(hour: now.hour, minute: now.minute);
    }
  }

  DateTime get _startDateTime => DateTime(
    _startDate.year,
    _startDate.month,
    _startDate.day,
    _startTime.hour,
    _startTime.minute,
  );

  DateTime get _endDateTime => DateTime(
    _endDate.year,
    _endDate.month,
    _endDate.day,
    _endTime.hour,
    _endTime.minute,
  );

  String? _validateDateTimes() {
    final now = DateTime.now().add(const Duration(minutes: 1)); // Tolleranza 1m clock skew
    if (_startDateTime.isAfter(now)) {
      return 'La data e l\'ora di inizio non possono essere nel futuro.';
    }
    if (_endDateTime.isAfter(now)) {
      return 'La data e l\'ora di fine non possono essere nel futuro.';
    }
    if (_startDateTime.isAfter(_endDateTime) || _startDateTime.isAtSameMomentAs(_endDateTime)) {
      return 'La data e l\'ora di inizio devono precedere la data e l\'ora di fine.';
    }
    return null;
  }

  int _calculateDurationMinutes() {
    final diff = _endDateTime.difference(_startDateTime).inMinutes;
    return diff > 0 ? diff : 0;
  }

  String _formatDuration(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Oggi (${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')})';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Ieri (${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')})';
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(DateTime.now()) ? DateTime.now() : initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: WhoopTheme.strainBlue,
            surface: WhoopTheme.cardSurface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: WhoopTheme.strainBlue,
            surface: WhoopTheme.cardSurface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _saveRecord() async {
    final validationError = _validateDateTimes();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: WhoopTheme.recoveryRed,
        ),
      );
      return;
    }

    final viewModel = Provider.of<WhoopViewModel>(context, listen: false);
    final durationMin = _calculateDurationMinutes();
    final dateIso = _endDate.toIso8601String().substring(0, 10);
    final startDateTime = _startDateTime;
    final endDateTime = _endDateTime;

    try {
      if (_selectedTab == 0) {
        final res = await viewModel.processAndAddManualSleep(
          startTime: startDateTime,
          endTime: endDateTime,
          dateIso: dateIso,
        );

        final bool hasRealBleData = res['hasRealBleData'] == true;

        if (mounted) {
          viewModel.setSelectedDate(_endDate, triggerAutoSync: false);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                hasRealBleData
                    ? 'Sonno elaborato sui dati BLE REALI! (${_formatDuration(durationMin)})'
                    : 'Sonno registrato con successo! (${_formatDuration(durationMin)})',
              ),
              backgroundColor: hasRealBleData ? WhoopTheme.recoveryGreen : WhoopTheme.sleepPurple,
            ),
          );
        }
      } else {
        // Salva Allenamento Passato
        final maxHr = (_estimatedAvgHr * 1.18).round().clamp(100, 210);
        final calories = (durationMin * (_estimatedAvgHr / 15.0)).round();

        final allenamento = Allenamento(
          dataIso: dateIso,
          nomeAttivita: _selectedActivityType,
          oraInizio: startDateTime.toIso8601String(),
          oraFine: endDateTime.toIso8601String(),
          durataMin: durationMin,
          hrMedia: _estimatedAvgHr,
          hrMax: maxHr,
          strainAttivita: _workoutIntensity,
          calorie: calories,
          zoneZ1Pct: 15.0,
          zoneZ2Pct: 35.0,
          zoneZ3Pct: 30.0,
          zoneZ4Pct: 15.0,
          zoneZ5Pct: 5.0,
        );

        await viewModel.addWorkout(allenamento);
        viewModel.setSelectedDate(_endDate);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$_selectedActivityType registrata! Sforzo: ${_workoutIntensity.toStringAsFixed(1)}',
              ),
              backgroundColor: WhoopTheme.strainBlue,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Errore durante il salvataggio manuale: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore salvataggio: $e'),
            backgroundColor: WhoopTheme.recoveryRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final durationMinutes = _calculateDurationMinutes();

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: WhoopTheme.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Center(
            child: Text(
              'REGISTRAZIONE RETROATTIVA',
              style: TextStyle(
                color: WhoopTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Toggle Tab: SONNO PASSATO | ALLENAMENTO PASSATO
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: WhoopTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: WhoopTheme.cardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTab = 0;
                        _updateDefaultTimes();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedTab == 0 ? WhoopTheme.sleepPurple.withValues(alpha: 0.3) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: _selectedTab == 0 ? Border.all(color: WhoopTheme.sleepPurple) : null,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.nightlight_round, size: 16, color: WhoopTheme.sleepPurple),
                          SizedBox(width: 6),
                          Text(
                            'SONNO PASSATO',
                            style: TextStyle(
                              color: WhoopTheme.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTab = 1;
                        _updateDefaultTimes();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedTab == 1 ? WhoopTheme.strainBlue.withValues(alpha: 0.3) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: _selectedTab == 1 ? Border.all(color: WhoopTheme.strainBlue) : null,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fitness_center, size: 16, color: WhoopTheme.strainBlue),
                          SizedBox(width: 6),
                          Text(
                            'ALLENAMENTO',
                            style: TextStyle(
                              color: WhoopTheme.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // RIGA 1: INIZIO (Data + Ora Inizio)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: WhoopTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: WhoopTheme.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bedtime_outlined, size: 14, color: WhoopTheme.sleepPurple),
                    SizedBox(width: 6),
                    Text(
                      'INIZIO (DATA E ORA)',
                      style: TextStyle(color: WhoopTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Data Inizio
                    Expanded(
                      flex: 3,
                      child: GestureDetector(
                        onTap: () => _pickDate(isStart: true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: WhoopTheme.surfaceRaised,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 14, color: WhoopTheme.textSecondary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _formatDate(_startDate),
                                  style: const TextStyle(color: WhoopTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Ora Inizio
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: () => _pickTime(isStart: true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: WhoopTheme.surfaceRaised,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, size: 14, color: WhoopTheme.strainBlue),
                              const SizedBox(width: 6),
                              Text(
                                _formatTimeOfDay(_startTime),
                                style: const TextStyle(color: WhoopTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // RIGA 2: FINE (Data + Ora Fine)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: WhoopTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: WhoopTheme.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.wb_sunny_outlined, size: 14, color: WhoopTheme.recoveryGreen),
                    SizedBox(width: 6),
                    Text(
                      'FINE (DATA E ORA)',
                      style: TextStyle(color: WhoopTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Data Fine
                    Expanded(
                      flex: 3,
                      child: GestureDetector(
                        onTap: () => _pickDate(isStart: false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: WhoopTheme.surfaceRaised,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 14, color: WhoopTheme.textSecondary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _formatDate(_endDate),
                                  style: const TextStyle(color: WhoopTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Ora Fine
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: () => _pickTime(isStart: false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: WhoopTheme.surfaceRaised,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.flag_outlined, size: 14, color: WhoopTheme.recoveryGreen),
                              const SizedBox(width: 6),
                              Text(
                                _formatTimeOfDay(_endTime),
                                style: const TextStyle(color: WhoopTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Card Durata Calcolata & Avvisi di Validazione
          Builder(
            builder: (context) {
              final err = _validateDateTimes();
              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: WhoopTheme.surfaceRaised,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Durata Effettiva:', style: TextStyle(color: WhoopTheme.textSecondary, fontSize: 12)),
                        Text(
                          _formatDuration(durationMinutes),
                          style: TextStyle(
                            color: _selectedTab == 0 ? WhoopTheme.sleepPurple : WhoopTheme.strainBlue,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (err != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: WhoopTheme.recoveryRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: WhoopTheme.recoveryRed.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 16, color: WhoopTheme.recoveryRed),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              err,
                              style: const TextStyle(color: WhoopTheme.recoveryRed, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          // Sezione specifica per Allenamento Passato
          if (_selectedTab == 1) ...[
            // Selettore Tipo Attività
            const Text('TIPO DI ATTIVITÀ', style: TextStyle(color: WhoopTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _activityTypes.length,
                itemBuilder: (context, index) {
                  final type = _activityTypes[index];
                  final isSelected = type == _selectedActivityType;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(type),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : WhoopTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      selectedColor: WhoopTheme.strainBlue,
                      backgroundColor: WhoopTheme.background,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedActivityType = type);
                        }
                      },
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Slider Intensità / Sforzo Stimato
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('INTENSITÀ / SFORZO STIMATO', style: TextStyle(color: WhoopTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                Text(
                  '${_workoutIntensity.toStringAsFixed(1)} / 21.0',
                  style: const TextStyle(color: WhoopTheme.strainBlue, fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            Slider(
              value: _workoutIntensity,
              min: 1.0,
              max: 21.0,
              divisions: 40,
              activeColor: WhoopTheme.strainBlue,
              inactiveColor: WhoopTheme.background,
              onChanged: (val) {
                setState(() {
                  _workoutIntensity = val;
                  _estimatedAvgHr = (100 + (val * 4.5)).round().clamp(90, 190);
                });
              },
            ),
          ],

          const SizedBox(height: 20),

          // Tasto Conferma "SALVA REGISTRAZIONE"
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveRecord,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedTab == 0 ? WhoopTheme.sleepPurple : WhoopTheme.strainBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                _selectedTab == 0 ? 'SALVA SONNO PASSATO' : 'SALVA ALLENAMENTO PASSATO',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.0),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
