import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/whoop_theme.dart';
import '../../data/database/database_helper.dart';
import '../../viewmodels/whoop_viewmodel.dart';
import '../widgets/behavior_selection_modal.dart';
import 'behavior_detail_screen.dart';

/// WHOOP Journal & Impact Analytics
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final Map<String, bool> _habits = {
    'Magnesio Bisglicinato prima di dormire (400mg)': true,
    'Consumo di Caffeina dopo le 14:00': false,
    'Idratazione > 3 Litri d\'acqua': true,
    'Consumo di Alcolici la sera': false,
    'Utilizzo schermi / Luce blu prima di coricarsi': false,
    'Doccia fredda / Saunaterapia': true,
  };

  Future<void> _showAddCustomHabitDialog(BuildContext context) async {
    final controller = TextEditingController();
    try {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: WhoopTheme.cardSurface,
          title: const Text('AGGIUNGI NUOVA ABITUDINE', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Es: Caffè dopo le 14:00, Magnesio...',
              hintStyle: TextStyle(color: WhoopTheme.textMuted),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ANNULLA', style: TextStyle(color: WhoopTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.trim().isNotEmpty) {
                  final habitName = controller.text.trim();
                  await DatabaseHelper().insertAbitudineCustom(habitName, 'boolean');
                  if (!mounted) return;
                  setState(() {
                    _habits[habitName] = true;
                  });
                  if (context.mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: WhoopTheme.strainBlue),
              child: const Text('AGGIUNGI', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: WhoopTheme.background,
        appBar: AppBar(
          backgroundColor: WhoopTheme.background,
          elevation: 0,
          title: const Text(
            'WHOOP JOURNAL & IMPACT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          centerTitle: true,
          bottom: const TabBar(
            indicatorColor: WhoopTheme.strainBlue,
            labelColor: Colors.white,
            unselectedLabelColor: WhoopTheme.textSecondary,
            tabs: [
              Tab(text: 'Diario Mattutino'),
              Tab(text: 'Impact Analytics (+/- %)'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildJournalInputTab(context),
            _buildImpactAnalyticsTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildJournalInputTab(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'COMPORTAMENTI DI IERI',
                style: TextStyle(
                  color: WhoopTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              TextButton.icon(
                onPressed: () => BehaviorSelectionModal.show(context),
                icon: const Icon(Icons.tune, color: WhoopTheme.strainBlue, size: 16),
                label: const Text(
                  'PERSONALIZZA',
                  style: TextStyle(color: WhoopTheme.strainBlue, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _habits.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final key = _habits.keys.elementAt(index);
              final val = _habits[key]!;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: WhoopTheme.officialCardDecoration(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        key,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('NO'),
                          selected: !val,
                          selectedColor: WhoopTheme.recoveryRed.withValues(alpha: 0.3),
                          backgroundColor: WhoopTheme.cardSurface,
                          labelStyle: TextStyle(
                            color: !val ? WhoopTheme.recoveryRed : WhoopTheme.textMuted,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          onSelected: (selected) {
                            if (selected) setState(() => _habits[key] = false);
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('SÌ'),
                          selected: val,
                          selectedColor: WhoopTheme.recoveryGreen.withValues(alpha: 0.3),
                          backgroundColor: WhoopTheme.cardSurface,
                          labelStyle: TextStyle(
                            color: val ? WhoopTheme.recoveryGreen : WhoopTheme.textMuted,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          onSelected: (selected) {
                            if (selected) setState(() => _habits[key] = true);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Tasto Aggiungi Abitudine Custom
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => _showAddCustomHabitDialog(context),
              icon: const Icon(Icons.add, color: WhoopTheme.strainBlue, size: 18),
              label: const Text('AGGIUNGI ABITUDINE PERSONALIZZATA', style: TextStyle(color: WhoopTheme.strainBlue, fontWeight: FontWeight.bold, fontSize: 11)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: WhoopTheme.strainBlue),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Voci del Diario salvate in SQLite!'),
                    backgroundColor: WhoopTheme.recoveryGreen,
                  ),
                );
              },
              icon: const Icon(Icons.check, color: Colors.black),
              label: const Text(
                'SALVA DIARIO',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: WhoopTheme.strainBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildImpactAnalyticsTab(BuildContext context) {
    final viewModel = Provider.of<WhoopViewModel>(context);

    final List<Map<String, dynamic>> validImpacts = [];
    final List<Map<String, dynamic>> accumulatingImpacts = [];

    for (var key in _habits.keys) {
      final res = viewModel.getHabitImpact(key);
      if (res.hasStatisticalValidity) {
        validImpacts.add({
          'key': key,
          'impactVal': res.recoveryImpactPct,
          'sampleText': '${res.countYes} Sì, ${res.countNo} No',
        });
      } else {
        accumulatingImpacts.add({
          'key': key,
          'sampleText': '${res.countYes} Sì, ${res.countNo} No (Servono >=5 per validità)',
        });
      }
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: WhoopTheme.strainBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: WhoopTheme.strainBlue.withValues(alpha: 0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.query_stats, color: WhoopTheme.strainBlue, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Regola di Validità Statistica: Gli impatti (+/- %) richiedono almeno 5 risposte "Sì" e 5 "No" registrate in SQLite.',
                    style: TextStyle(color: WhoopTheme.strainBlue, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'IMPATTO SUL PUNTEGGIO DI RECUPERO (%)',
            style: TextStyle(
              color: WhoopTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),

          if (validImpacts.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: WhoopTheme.officialCardDecoration(),
              child: const Center(
                child: Text(
                  'Nessun comportamento ha ancora raggiunto la soglia statistica (>=5 Sì, >=5 No).',
                  style: TextStyle(color: WhoopTheme.textMuted, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...validImpacts.map((item) {
              final val = item['impactVal'] as double;
              final isPos = val >= 0;
              final label = '${isPos ? "+" : ""}${val.toStringAsFixed(1)}%';
              final color = isPos ? WhoopTheme.recoveryGreen : WhoopTheme.recoveryRed;

              return _buildImpactBarItem(
                item['key'],
                label,
                val,
                color,
                true,
                item['sampleText'],
              );
            }),

          const SizedBox(height: 16),
          const Divider(color: WhoopTheme.cardBorder),
          const SizedBox(height: 12),

          const Text(
            'IN FASE DI ACCUMULO DATI (SOTTO SOGLIA)',
            style: TextStyle(
              color: WhoopTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),

          ...accumulatingImpacts.map((item) {
            return _buildImpactBarItem(
              item['key'],
              'In accumulo',
              0.0,
              WhoopTheme.textMuted,
              false,
              item['sampleText'],
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildImpactBarItem(
    String habit,
    String impactLabel,
    double impactValue,
    Color color,
    bool isValid,
    String sampleCountText,
  ) {
    return GestureDetector(
      onTap: () => BehaviorDetailScreen.show(
        context,
        habitName: habit,
        impactPct: impactValue,
        isPositive: impactValue >= 0,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12.0),
        decoration: WhoopTheme.officialCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    habit,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  impactLabel,
                  style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              sampleCountText,
              style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
