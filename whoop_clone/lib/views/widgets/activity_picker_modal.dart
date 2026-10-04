import 'package:flutter/material.dart';
import '../../core/constants/whoop_theme.dart';

/// Modal di Selezione Attività WHOOP 5.0 (Rispecchia al 100% l'immagine 2 dell'utente)
/// Include le 4 schede TUTTO / SFORZO / RECUPERO / SONNO, la sezione "Più recente" e l'elenco completo A-Z dal PDF Ufficiale WHOOP.
class ActivityPickerModal extends StatefulWidget {
  final String selectedActivity;
  final ValueChanged<String> onActivitySelected;

  const ActivityPickerModal({
    super.key,
    required this.selectedActivity,
    required this.onActivitySelected,
  });

  static void show(BuildContext context, {required String selectedActivity, required ValueChanged<String> onActivitySelected}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ActivityPickerModal(
        selectedActivity: selectedActivity,
        onActivitySelected: onActivitySelected,
      ),
    );
  }

  @override
  State<ActivityPickerModal> createState() => _ActivityPickerModalState();
}

class _ActivityPickerModalState extends State<ActivityPickerModal> {
  int _selectedTabIndex = 0; // 0: TUTTO, 1: SFORZO, 2: RECUPERO, 3: SONNO
  String _searchQuery = '';

  final List<Map<String, dynamic>> _recentActivities = [
    {'name': 'Corsa', 'icon': Icons.directions_run, 'type': 'sforzo'},
    {'name': 'Spinning', 'icon': Icons.directions_bike, 'type': 'sforzo'},
    {'name': 'Ciclismo', 'icon': Icons.pedal_bike, 'type': 'sforzo'},
    {'name': 'Tennis', 'icon': Icons.sports_tennis, 'type': 'sforzo'},
  ];

  final List<Map<String, dynamic>> _allActivities = [
    // SONNO & RECUPERO
    {'name': 'Sonno', 'icon': Icons.nightlight_round, 'type': 'sonno'},
    {'name': 'Riposo Breve', 'icon': Icons.airline_seat_recline_extra, 'type': 'sonno'},
    {'name': 'Agopuntura', 'icon': Icons.self_improvement, 'type': 'recupero'},
    {'name': 'Allattare un bambino', 'icon': Icons.child_care, 'type': 'recupero'},
    {'name': 'Allenamento di Sprint', 'icon': Icons.directions_run, 'type': 'sforzo'},
    {'name': 'Allenamento Pliometrico', 'icon': Icons.fitness_center, 'type': 'sforzo'},
    {'name': 'Allenamento su Sedia a Rotelle', 'icon': Icons.accessible, 'type': 'sforzo'},
    {'name': 'Allungamento', 'icon': Icons.accessibility_new, 'type': 'recupero'},
    {'name': 'Alpinismo', 'icon': Icons.terrain, 'type': 'sforzo'},
    {'name': 'Arti Marziali', 'icon': Icons.sports_mma, 'type': 'sforzo'},
    {'name': 'Bagno Freddo (Ice Bath)', 'icon': Icons.ac_unit, 'type': 'recupero'},
    {'name': 'Calcio', 'icon': Icons.sports_soccer, 'type': 'sforzo'},
    {'name': 'Camminata', 'icon': Icons.directions_walk, 'type': 'sforzo'},
    {'name': 'CrossFit / Functional Fitness', 'icon': Icons.fitness_center, 'type': 'sforzo'},
    {'name': 'Doccia Fredda', 'icon': Icons.shower, 'type': 'recupero'},
    {'name': 'Ginnastica Artistica', 'icon': Icons.sports_gymnastics, 'type': 'sforzo'},
    {'name': 'Golf', 'icon': Icons.sports_golf, 'type': 'sforzo'},
    {'name': 'HIIT', 'icon': Icons.bolt, 'type': 'sforzo'},
    {'name': 'Nuoto', 'icon': Icons.pool, 'type': 'sforzo'},
    {'name': 'Pallacanestro', 'icon': Icons.sports_basketball, 'type': 'sforzo'},
    {'name': 'Pallavolo', 'icon': Icons.sports_volleyball, 'type': 'sforzo'},
    {'name': 'Respirazione Guidata', 'icon': Icons.air, 'type': 'recupero'},
    {'name': 'Sauna Secca / Infrarossi', 'icon': Icons.hot_tub, 'type': 'recupero'},
    {'name': 'Sci / Snowboard', 'icon': Icons.downhill_skiing, 'type': 'sforzo'},
    {'name': 'Yoga / Hot Yoga', 'icon': Icons.self_improvement, 'type': 'sforzo'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: WhoopTheme.brandBlack,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: WhoopTheme.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header Bar: X | Icona + Nome Attività Attiva ▲
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 24),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.directions_run, color: WhoopTheme.strainBlue, size: 20),
                const SizedBox(width: 8),
                Text(
                  widget.selectedActivity,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_up, color: Colors.white, size: 20),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Tab Filter Row: TUTTO | SFORZO | RECUPERO | SONNO
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: WhoopTheme.cardBorder)),
            ),
            child: Row(
              children: [
                _buildFilterTab(0, 'TUTTO'),
                _buildFilterTab(1, 'SFORZO'),
                _buildFilterTab(2, 'RECUPERO'),
                _buildFilterTab(3, 'SONNO'),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: WhoopTheme.cardSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: WhoopTheme.cardBorder),
              ),
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  icon: Icon(Icons.search, color: WhoopTheme.textMuted, size: 20),
                  hintText: 'Cerca attività...',
                  hintStyle: TextStyle(color: WhoopTheme.textMuted, fontSize: 13),
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Lista Attività filtrata
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (_searchQuery.isEmpty && _selectedTabIndex == 0) ...[
                  const Text(
                    'Più recente',
                    style: TextStyle(
                      color: WhoopTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._recentActivities.map((act) => _buildActivityTile(act)),
                  const SizedBox(height: 16),
                  const Divider(color: WhoopTheme.cardBorder),
                  const SizedBox(height: 8),
                ],

                Text(
                  _searchQuery.isNotEmpty ? 'Risultati della ricerca' : 'Tutto dalla A alla Z',
                  style: const TextStyle(
                    color: WhoopTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ..._getFilteredList().map((act) => _buildActivityTile(act)),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredList() {
    return _allActivities.where((act) {
      final nameMatches = (act['name'] as String).toLowerCase().contains(_searchQuery);
      if (!nameMatches) return false;

      if (_selectedTabIndex == 1) return act['type'] == 'sforzo';
      if (_selectedTabIndex == 2) return act['type'] == 'recupero';
      if (_selectedTabIndex == 3) return act['type'] == 'sonno';
      return true;
    }).toList();
  }

  Widget _buildFilterTab(int index, String label) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 2.0,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : WhoopTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityTile(Map<String, dynamic> act) {
    final name = act['name'] as String;
    final isSelected = name == widget.selectedActivity;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () {
        widget.onActivitySelected(name);
        Navigator.pop(context);
      },
      leading: Icon(
        act['icon'] as IconData,
        color: isSelected ? WhoopTheme.strainBlue : WhoopTheme.textSecondary,
        size: 22,
      ),
      title: Text(
        name.toUpperCase(),
        style: TextStyle(
          color: isSelected ? WhoopTheme.strainBlue : Colors.white,
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check, color: WhoopTheme.strainBlue, size: 18) : null,
    );
  }
}
