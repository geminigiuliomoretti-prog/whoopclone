import 'package:flutter/material.dart';
import '../../core/constants/whoop_theme.dart';

/// Modulo 20: Integrations Screen (Sezione 20 Roadmap)
/// Pannello per la connessione ed integrazione con ecosistemi esterni:
/// Apple Health, Health Connect, Strava, TrainingPeaks e Withings.
class IntegrationsScreen extends StatefulWidget {
  const IntegrationsScreen({super.key});

  static void show(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const IntegrationsScreen()),
    );
  }

  @override
  State<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends State<IntegrationsScreen> {
  final Map<String, Map<String, dynamic>> _integrations = {
    'Apple Health': {
      'icon': Icons.health_and_safety,
      'color': Colors.redAccent,
      'connected': true,
      'description': 'Sincronizzazione FCR, VFC, Sonno, SpO2 e Frequenza Respiratoria.',
      'lastSync': 'Oggi, 11:30 AM',
    },
    'Health Connect (Android)': {
      'icon': Icons.android,
      'color': WhoopTheme.recoveryGreen,
      'connected': true,
      'description': 'Scambio dati nativo Android con Google Fit & Health Connect.',
      'lastSync': 'Oggi, 11:30 AM',
    },
    'Strava': {
      'icon': Icons.directions_bike,
      'color': Colors.deepOrange,
      'connected': true,
      'description': 'Esportazione automatica di attività outdoor, GPS, FC e Activity Strain.',
      'lastSync': 'Ieri, 18:45 PM',
    },
    'TrainingPeaks': {
      'icon': Icons.equalizer,
      'color': WhoopTheme.strainBlue,
      'connected': false,
      'description': 'Invio del carico cardiovascolare TSS, IF e metriche di sforzo.',
      'lastSync': 'Non collegato',
    },
    'Withings': {
      'icon': Icons.scale,
      'color': Colors.tealAccent,
      'connected': true,
      'description': 'Importazione automatica di peso corporeo e percentuale di massa grassa.',
      'lastSync': '02/08/2026',
    },
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WhoopTheme.background,
      appBar: AppBar(
        title: const Text(
          'INTEGRAZIONI ECOSISTEMI ESTERNI',
          style: TextStyle(
            color: WhoopTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: WhoopTheme.strainBlue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: WhoopTheme.strainBlue.withOpacity(0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.sync, color: WhoopTheme.strainBlue, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sincronizza i tuoi dati WHOOP 5.0 in tempo reale con le tue app di allenamento e salute preferite.',
                      style: TextStyle(color: WhoopTheme.textPrimary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'PLATTAFORME SUPPORTATE',
              style: TextStyle(
                color: WhoopTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),

            ..._integrations.keys.map((name) {
              final item = _integrations[name]!;
              final isConnected = item['connected'] as bool;
              final icon = item['icon'] as IconData;
              final color = item['color'] as Color;
              final desc = item['description'] as String;
              final lastSync = item['lastSync'] as String;

              return Card(
                color: WhoopTheme.cardSurface,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: color, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: WhoopTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  desc,
                                  style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isConnected,
                            activeColor: WhoopTheme.recoveryGreen,
                            onChanged: (val) {
                              setState(() {
                                item['connected'] = val;
                                if (val) {
                                  item['lastSync'] = 'Adesso';
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Ultimo sync: $lastSync',
                            style: const TextStyle(color: WhoopTheme.textSecondary, fontSize: 10),
                          ),
                          Text(
                            isConnected ? 'CONNESSO' : 'DISCONNESSO',
                            style: TextStyle(
                              color: isConnected ? WhoopTheme.recoveryGreen : WhoopTheme.textMuted,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sincronizzazione istantanea completata con tutti gli ecosistemi!')),
                  );
                },
                icon: const Icon(Icons.refresh, color: Colors.black),
                label: const Text(
                  'SINCRONIZZA ORA TUTTI GLI ECOSISTEMI',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WhoopTheme.strainBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
