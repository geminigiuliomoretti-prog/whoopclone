import 'package:flutter/material.dart';
import '../../core/constants/whoop_theme.dart';

/// Modal modulo avanzato Strength Trainer (Sezione 8 Roadmap)
/// Gestisce la misurazione del Carico Muscolare, Tonnellaggio, Esercizi, Serie, Reps, Carico (kg) e RPE (1-20).
class StrengthTrainerModal extends StatefulWidget {
  const StrengthTrainerModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const StrengthTrainerModal(),
    );
  }

  @override
  State<StrengthTrainerModal> createState() => _StrengthTrainerModalState();
}

class _StrengthTrainerModalState extends State<StrengthTrainerModal> {
  String _selectedExercise = 'Squat con Bilanciere';

  final List<Map<String, dynamic>> _sets = [
    {'set': 1, 'reps': 10, 'weight': 80.0, 'done': true},
    {'set': 2, 'reps': 10, 'weight': 85.0, 'done': true},
    {'set': 3, 'reps': 8, 'weight': 90.0, 'done': true},
    {'set': 4, 'reps': 6, 'weight': 95.0, 'done': false},
  ];

  double _rpeScore = 14.0; // Scala RPE 1-20

  double get _totalTonnage {
    double total = 0.0;
    for (var s in _sets) {
      total += (s['reps'] as int) * (s['weight'] as double);
    }
    return total;
  }

  double get _muscularLoad {
    // Algoritmo stimato Muscular Load basato su tonnellaggio e RPE
    return (_totalTonnage / 300.0) * (_rpeScore / 10.0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: WhoopTheme.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: WhoopTheme.cardBorder, width: 1.5)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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

            const Row(
              children: [
                Icon(Icons.fitness_center_sharp, color: WhoopTheme.strainHigh, size: 24),
                SizedBox(width: 10),
                Text(
                  'STRENGTH TRAINER (CARICO MUSCOLARE)',
                  style: TextStyle(
                    color: WhoopTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Tracciamento accelerometro 3-assi per massa, accelerazione e tonnellaggio muscolare.',
              style: TextStyle(color: WhoopTheme.textSecondary, fontSize: 11),
            ),

            const SizedBox(height: 16),

            // Selezione Esercizio
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Esercizio Corrente:', style: TextStyle(color: WhoopTheme.textMuted, fontSize: 11)),
                DropdownButton<String>(
                  value: _selectedExercise,
                  dropdownColor: WhoopTheme.cardSurface,
                  style: const TextStyle(color: WhoopTheme.strainHigh, fontWeight: FontWeight.bold, fontSize: 13),
                  items: ['Squat con Bilanciere', 'Panca Piana', 'Stacco da Terra', 'Push Press', 'Trazioni alla Sbarra']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedExercise = val);
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Tonnellaggio e Muscular Load Summary Card
            Card(
              color: WhoopTheme.background,
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Tonnellaggio Totale', style: TextStyle(color: WhoopTheme.textMuted, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text('${_totalTonnage.toInt()} kg', style: const TextStyle(color: WhoopTheme.strainHigh, fontSize: 18, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    Container(width: 1, height: 32, color: WhoopTheme.cardBorder),
                    Column(
                      children: [
                        const Text('Muscular Load', style: TextStyle(color: WhoopTheme.textMuted, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text(_muscularLoad.toStringAsFixed(1), style: const TextStyle(color: WhoopTheme.strainBlue, fontSize: 18, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Tabella Serie & Reps
            const Text(
              'REGISTRO SERIE & CARICHI',
              style: TextStyle(color: WhoopTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1),
            ),
            const SizedBox(height: 8),

            ..._sets.map((s) {
              return Card(
                color: WhoopTheme.background,
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 12,
                    backgroundColor: WhoopTheme.cardBorder,
                    child: Text('${s['set']}', style: const TextStyle(color: WhoopTheme.textPrimary, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  title: Text('${s['reps']} Ripetizioni @ ${s['weight']} kg', style: const TextStyle(color: WhoopTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                  trailing: Checkbox(
                    value: s['done'] as bool,
                    activeColor: WhoopTheme.strainHigh,
                    onChanged: (val) {
                      setState(() => s['done'] = val ?? false);
                    },
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height: 8),

            TextButton.icon(
              onPressed: () {
                setState(() {
                  _sets.add({
                    'set': _sets.length + 1,
                    'reps': 8,
                    'weight': 85.0,
                    'done': false,
                  });
                });
              },
              icon: const Icon(Icons.add, size: 16, color: WhoopTheme.strainHigh),
              label: const Text('Aggiungi Serie', style: TextStyle(color: WhoopTheme.strainHigh, fontWeight: FontWeight.bold, fontSize: 12)),
            ),

            const SizedBox(height: 14),

            // RPE Scale Selector (1-20 Borg/Whoop Scale)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Percezione dello Sforzo (RPE 1-20):', style: TextStyle(color: WhoopTheme.textSecondary, fontSize: 11)),
                Text('${_rpeScore.toInt()} / 20', style: const TextStyle(color: WhoopTheme.strainHigh, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            Slider(
              value: _rpeScore,
              min: 1.0,
              max: 20.0,
              divisions: 19,
              activeColor: WhoopTheme.strainHigh,
              inactiveColor: WhoopTheme.cardBorder,
              onChanged: (val) => setState(() => _rpeScore = val),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Allenamento Strength Trainer registrato: ${_totalTonnage.toInt()} kg tonnellaggio!')),
                  );
                },
                icon: const Icon(Icons.check, color: Colors.black),
                label: const Text('SALVA WORKOUT STRENGTH TRAINER', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WhoopTheme.strainHigh,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
