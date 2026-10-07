import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/whoop_theme.dart';
import '../../viewmodels/whoop_viewmodel.dart';

/// Modulo 17 — Dashboard Personalizzabile
/// Permette di attivare/disattivare e riordinare le tessere biometriche della Home.
class CustomizableDashboardScreen extends StatefulWidget {
  const CustomizableDashboardScreen({super.key});

  @override
  State<CustomizableDashboardScreen> createState() =>
      _CustomizableDashboardScreenState();
}

class _CustomizableDashboardScreenState
    extends State<CustomizableDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = Provider.of<WhoopViewModel>(context, listen: false);
      final enabledKeys = viewModel.enabledTileKeys;
      setState(() {
        for (var tile in _tiles) {
          tile['enabled'] = enabledKeys.contains(tile['key']);
        }
      });
    });
  }

  // Ogni tessera ha: chiave, titolo, sottotitolo, icona, colore, attiva
  final List<Map<String, dynamic>> _tiles = [
    {
      'key': 'vfc',
      'title': 'Variabilità FC (VFC)',
      'subtitle': 'RMSSD in ms',
      'icon': Icons.show_chart,
      'color': WhoopTheme.recoveryGreen,
      'enabled': true,
    },
    {
      'key': 'fcr',
      'title': 'FC a Riposo (FCR)',
      'subtitle': 'bpm notturni',
      'icon': Icons.favorite_border,
      'color': WhoopTheme.recoveryGreen,
      'enabled': true,
    },
    {
      'key': 'steps',
      'title': 'Passi Giornalieri',
      'subtitle': 'Totale odierno',
      'icon': Icons.directions_walk,
      'color': WhoopTheme.strainBlue,
      'enabled': true,
    },
    {
      'key': 'zone_fc_low',
      'title': 'Zone FC 1–3 (Settimanale)',
      'subtitle': 'Tempo aerobico totale',
      'icon': Icons.donut_large,
      'color': WhoopTheme.strainBlue,
      'enabled': true,
    },
    {
      'key': 'zone_fc_high',
      'title': 'Zone FC 4–5 (Settimanale)',
      'subtitle': 'Tempo anaerobico totale',
      'icon': Icons.local_fire_department,
      'color': WhoopTheme.strainHigh,
      'enabled': true,
    },
    {
      'key': 'vo2max',
      'title': 'VO₂ Max Stimato',
      'subtitle': 'ml/kg/min',
      'icon': Icons.speed,
      'color': WhoopTheme.strainBlue,
      'enabled': true,
    },
    {
      'key': 'calories',
      'title': 'Dispendio Energetico',
      'subtitle': 'kcal (BMR + Attività)',
      'icon': Icons.bolt,
      'color': WhoopTheme.recoveryYellow,
      'enabled': false,
    },
    {
      'key': 'sleep_need',
      'title': 'Fabbisogno di Sonno',
      'subtitle': 'ore:min dinamico',
      'icon': Icons.nightlight_round,
      'color': WhoopTheme.sleepSlate,
      'enabled': false,
    },
    {
      'key': 'recovery',
      'title': 'Recupero',
      'subtitle': 'Punteggio % giornaliero',
      'icon': Icons.battery_charging_full,
      'color': WhoopTheme.recoveryGreen,
      'enabled': false,
    },
    {
      'key': 'sleep_debt',
      'title': 'Sonno Arretrato',
      'subtitle': 'ore:min accumulate',
      'icon': Icons.hourglass_empty,
      'color': WhoopTheme.recoveryRed,
      'enabled': false,
    },
    {
      'key': 'resp_rate',
      'title': 'Frequenza Respiratoria',
      'subtitle': 'rpm notturni',
      'icon': Icons.air,
      'color': WhoopTheme.strainBlue,
      'enabled': false,
    },
    {
      'key': 'skin_temp',
      'title': 'Temperatura Cutanea',
      'subtitle': 'Δ °C rispetto baseline',
      'icon': Icons.thermostat,
      'color': WhoopTheme.recoveryYellow,
      'enabled': false,
    },
    {
      'key': 'spo2',
      'title': 'Ossigeno nel Sangue (SpO₂)',
      'subtitle': '% saturazione notturna',
      'icon': Icons.water_drop_outlined,
      'color': WhoopTheme.strainBlue,
      'enabled': false,
    },
    {
      'key': 'deep_sleep',
      'title': 'Sonno Profondo (SWS)',
      'subtitle': 'ore:min di recupero fisico',
      'icon': Icons.bedtime,
      'color': WhoopTheme.strainBlue,
      'enabled': false,
    },
    {
      'key': 'rem_sleep',
      'title': 'Sonno REM',
      'subtitle': 'ore:min di recupero mentale',
      'icon': Icons.psychology,
      'color': WhoopTheme.strainBlue,
      'enabled': false,
    },
    {
      'key': 'sleep_efficiency',
      'title': 'Efficienza del Sonno',
      'subtitle': '% tempo a letto dormito',
      'icon': Icons.check_circle_outline,
      'color': WhoopTheme.recoveryGreen,
      'enabled': false,
    },
  ];

  bool _hasChanges = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WhoopTheme.background,
      appBar: AppBar(
        title: const Text(
          'DASHBOARD PERSONALIZZABILE',
          style: TextStyle(
            color: WhoopTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _saveChanges,
              child: const Text(
                'SALVA',
                style: TextStyle(
                    color: WhoopTheme.recoveryGreen,
                    fontWeight: FontWeight.w900),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Banner informativo
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: WhoopTheme.strainBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: WhoopTheme.strainBlue.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.drag_handle,
                    color: WhoopTheme.strainBlue, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tieni premuto e trascina per riordinare. Usa il toggle per mostrare/nascondere una metrica nella Home.',
                    style:
                        TextStyle(color: WhoopTheme.textPrimary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Sezione ATTIVE
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'METRICHE ATTIVE',
                  style: TextStyle(
                    color: WhoopTheme.recoveryGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4,
                  ),
                ),
                Text(
                  '${_tiles.where((t) => t['enabled'] == true).length} / ${_tiles.length}',
                  style: const TextStyle(
                      color: WhoopTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Lista riordinabile
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              itemCount: _tiles.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _tiles.removeAt(oldIndex);
                  _tiles.insert(newIndex, item);
                  _hasChanges = true;
                });
              },
              itemBuilder: (context, index) {
                final tile = _tiles[index];
                final isEnabled = tile['enabled'] as bool;
                final color = tile['color'] as Color;

                return Padding(
                  key: ValueKey(tile['key']),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isEnabled
                          ? WhoopTheme.cardSurface
                          : WhoopTheme.cardSurface.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isEnabled
                            ? color.withOpacity(0.35)
                            : WhoopTheme.cardBorder,
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Icona drag handle
                        const Icon(Icons.drag_indicator,
                            color: WhoopTheme.textMuted, size: 20),
                        const SizedBox(width: 10),

                        // Icona metrica
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withOpacity(isEnabled ? 0.15 : 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            tile['icon'] as IconData,
                            color: isEnabled
                                ? color
                                : color.withOpacity(0.35),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Titolo e sottotitolo
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tile['title'] as String,
                                style: TextStyle(
                                  color: isEnabled
                                      ? WhoopTheme.textPrimary
                                      : WhoopTheme.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                tile['subtitle'] as String,
                                style: const TextStyle(
                                    color: WhoopTheme.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),

                        // Toggle attiva/disattiva
                        Switch(
                          value: isEnabled,
                          activeColor: color,
                          inactiveThumbColor: WhoopTheme.textMuted,
                          inactiveTrackColor:
                              WhoopTheme.cardBorder,
                          onChanged: (val) {
                            setState(() {
                              _tiles[index]['enabled'] = val;
                              _hasChanges = true;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _saveChanges() {
    setState(() => _hasChanges = false);

    final activeKeys = _tiles
        .where((t) => t['enabled'] == true)
        .map((t) => t['key'] as String)
        .toList();

    Provider.of<WhoopViewModel>(context, listen: false).updateDashboardTiles(activeKeys);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle,
                color: WhoopTheme.recoveryGreen, size: 18),
            const SizedBox(width: 8),
            Text(
              'Dashboard salvata: ${activeKeys.length} metriche attive.',
              style: const TextStyle(
                color: WhoopTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        backgroundColor: WhoopTheme.cardSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: WhoopTheme.cardBorder),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.pop(context);
  }
}
