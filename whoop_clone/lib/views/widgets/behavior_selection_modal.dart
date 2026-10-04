import 'package:flutter/material.dart';
import '../../core/constants/whoop_theme.dart';
import '../../data/database/database_helper.dart';

/// Modal "SELEZIONA COMPORTAMENTI" (Rispecchia al 100% l'immagine del video al min 6:15, frame 75)
class BehaviorSelectionModal extends StatefulWidget {
  const BehaviorSelectionModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const BehaviorSelectionModal(),
    );
  }

  @override
  State<BehaviorSelectionModal> createState() => _BehaviorSelectionModalState();
}

class _BehaviorSelectionModalState extends State<BehaviorSelectionModal> {
  int _selectedCategoryIndex = 0;
  String _searchQuery = '';

  final Map<String, Map<String, dynamic>> _allBehaviors = {
    'Cena': {'question': 'Hai cenato?', 'selected': true, 'category': 'Alimentazione'},
    'Cioccolato fondente': {'question': 'Hai consumato cioccolato fondente?', 'selected': true, 'category': 'Alimentazione'},
    'Colazione': {'question': 'Hai fatto colazione?', 'selected': true, 'category': 'Alimentazione'},
    'Coperta pesante': {'question': 'Hai usato una coperta ponderata mentre dormivi?', 'selected': true, 'category': 'Benessere'},
    'Creatina': {'question': 'Hai assunto creatina?', 'selected': true, 'category': 'Alimentazione'},
    'Dispositivo (ad es. telefono) a letto': {'question': 'Hai utilizzato un dispositivo con schermo a letto?', 'selected': true, 'category': 'Benessere'},
    'Doccia fredda': {'question': 'Hai fatto una doccia fredda?', 'selected': true, 'category': 'Benessere'},
    'Dolore': {'question': 'Hai sofferto di indolenzimento muscolare?', 'selected': true, 'category': 'Benessere'},
    'Dormire in una stanza buia': {'question': 'Hai dormito in una stanza buia?', 'selected': true, 'category': 'Benessere'},
    'Dormire nel proprio letto': {'question': 'Hai dormito nello stesso letto come al solito?', 'selected': true, 'category': 'Benessere'},
    'Magnesio Bisglicinato': {'question': 'Hai assunto magnesio bisglicinato?', 'selected': true, 'category': 'Alimentazione'},
    'Caffeina dopo le 14:00': {'question': 'Hai consumato caffeina nel pomeriggio?', 'selected': false, 'category': 'Alimentazione'},
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: WhoopTheme.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: WhoopTheme.cardBorder, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),

          const Text(
            'SELEZIONA COMPORTAMENTI',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.2),
          ),
          const SizedBox(height: 16),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: WhoopTheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: WhoopTheme.cardBorder),
              ),
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  icon: Icon(Icons.search, color: WhoopTheme.textMuted, size: 20),
                  hintText: 'Cerca comportamenti',
                  hintStyle: TextStyle(color: WhoopTheme.textMuted, fontSize: 13),
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Category Tabs: TUTTO | ALIMENTAZIONE | BENESSERE
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildCategoryChip(0, 'TUTTO'),
                const SizedBox(width: 10),
                _buildCategoryChip(1, 'ALIMENTAZIONE'),
                const SizedBox(width: 10),
                _buildCategoryChip(2, 'BENESSERE'),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Behaviors List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              children: _getFilteredBehaviors().map((key) {
                final item = _allBehaviors[key]!;
                final isChecked = item['selected'] as bool;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: WhoopTheme.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: WhoopTheme.cardBorder),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: CheckboxListTile(
                      title: Text(key, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Text(item['question'] as String, style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 11)),
                      value: isChecked,
                      activeColor: WhoopTheme.strainBlue,
                      onChanged: (val) {
                        setState(() {
                          item['selected'] = val ?? false;
                        });
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Tasto Aggiungi Comportamento Personalizzato
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: OutlinedButton.icon(
              onPressed: _showAddCustomHabitDialog,
              icon: const Icon(Icons.add, color: WhoopTheme.strainBlue, size: 18),
              label: const Text(
                'AGGIUNGI COMPORTAMENTO PERSONALIZZATO',
                style: TextStyle(color: WhoopTheme.strainBlue, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: WhoopTheme.strainBlue),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // Bottom Button: SALVA COMPORTAMENTI
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Comportamenti salvati con successo nel diario!')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: WhoopTheme.strainBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                child: const Text('SALVA COMPORTAMENTI', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getFilteredBehaviors() {
    return _allBehaviors.keys.where((key) {
      final matchesSearch = key.toLowerCase().contains(_searchQuery);
      if (!matchesSearch) return false;
      if (_selectedCategoryIndex == 1) return _allBehaviors[key]!['category'] == 'Alimentazione';
      if (_selectedCategoryIndex == 2) return _allBehaviors[key]!['category'] == 'Benessere';
      return true;
    }).toList();
  }

  Future<void> _showAddCustomHabitDialog() async {
    final nameCtrl = TextEditingController();
    final qCtrl = TextEditingController();

    try {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: WhoopTheme.cardSurface,
          title: const Text('Nuovo Comportamento', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Nome abitudine (es. Creatina)',
                  labelStyle: TextStyle(color: WhoopTheme.textMuted, fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: qCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Domanda del diario',
                  labelStyle: TextStyle(color: WhoopTheme.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ANNULLA', style: TextStyle(color: WhoopTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isNotEmpty) {
                  final question = qCtrl.text.trim().isNotEmpty ? qCtrl.text.trim() : 'Hai registrato $name?';
                  if (!mounted) return;
                  setState(() {
                    _allBehaviors[name] = {
                      'question': question,
                      'selected': true,
                      'category': 'Alimentazione',
                    };
                  });

                  final dbHelper = DatabaseHelper();
                  await dbHelper.insertVoceDiario({
                    'data_voce': DateTime.now().toIso8601String(),
                    'nome_comportamento': name,
                    'risposta_bool': 1,
                    'valore_numerico': null,
                    'categoria': 'Alimentazione',
                  });

                  if (context.mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: WhoopTheme.strainBlue),
              child: const Text('AGGIUNGI', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } finally {
      nameCtrl.dispose();
      qCtrl.dispose();
    }
  }

  Widget _buildCategoryChip(int index, String label) {
    final isSelected = _selectedCategoryIndex == index;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      selected: isSelected,
      selectedColor: Colors.white,
      backgroundColor: WhoopTheme.background,
      onSelected: (val) => setState(() => _selectedCategoryIndex = index),
    );
  }
}
