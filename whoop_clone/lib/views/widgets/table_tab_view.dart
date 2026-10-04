import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/whoop_theme.dart';
import '../../data/models/ciclo_fisiologico.dart';
import '../../data/models/allenamento.dart';
import '../../data/models/voce_diario.dart';
import '../../data/models/sonno.dart';

class TableTabView extends StatelessWidget {
  final List<CicloFisiologico> cicli;
  final List<Allenamento> allenamenti;
  final List<VoceDiario> diario;
  final List<Sonno> sonnoLogs;

  const TableTabView({
    super.key,
    required this.cicli,
    required this.allenamenti,
    required this.diario,
    required this.sonnoLogs,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            indicatorColor: AppColors.strainBlue,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: const [
              Tab(text: 'Cicli Fisiologici'),
              Tab(text: 'Allenamenti'),
              Tab(text: 'Voci Diario'),
              Tab(text: 'Sonno'),
            ],
          ),
          SizedBox(
            height: 350,
            child: TabBarView(
              children: [
                // 1. Cicli Fisiologici
                _buildScrollableListView(
                  itemCount: cicli.length,
                  itemBuilder: (context, i) {
                    final c = cicli[i];
                    return Card(
                      color: AppColors.surface,
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                        title: Text(
                          'Inizio Ciclo: ${dateFormat.format(c.oraInizioCiclo)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'FCR: ${c.fcrBpm ?? "-"} bpm | VFC: ${c.vfcMs?.toStringAsFixed(1) ?? "-"} ms | Sforzo: ${c.sforzoGiornaliero?.toStringAsFixed(1) ?? "-"}\nSpo2: ${c.spo2Pct ?? "-"}% | Temp: ${c.tempCutaneaC ?? "-"}°C | Cal: ${c.energiaBruciataCal ?? "-"}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.getRecoveryColor(c.punteggioRecuperoPct ?? 0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${c.punteggioRecuperoPct?.toInt() ?? 0}%',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

                // 2. Allenamenti
                _buildScrollableListView(
                  itemCount: allenamenti.length,
                  itemBuilder: (context, i) {
                    final a = allenamenti[i];
                    return Card(
                      color: AppColors.surface,
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: const Icon(Icons.fitness_center, color: AppColors.strainBlue),
                          title: Text(
                            a.nomeAttivita,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Inizio: ${dateFormat.format(a.oraInizioAllenamento)} (${a.durataMin.toInt()} min)\nFC Max: ${a.fcMaxBpm ?? "-"} bpm | Media: ${a.fcMediaBpm ?? "-"} bpm | Cal: ${a.energiaBruciataCal ?? "-"} | GPS: ${a.gpsAbilitato ? "Sì" : "No"}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          trailing: Text(
                            'Sforzo\n${a.sforzoRichiesto?.toStringAsFixed(1) ?? "-"}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.strainBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // 3. Voci Diario
                _buildScrollableListView(
                  itemCount: diario.length,
                  itemBuilder: (context, i) {
                    final d = diario[i];
                    return Card(
                      color: AppColors.surface,
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: Icon(
                            d.rispostaAffermativa ? Icons.check_circle : Icons.cancel,
                            color: d.rispostaAffermativa ? AppColors.recoveryGreen : AppColors.recoveryRed,
                          ),
                          title: Text(d.testoDomanda),
                          subtitle: Text(
                            'Risposta: ${d.rispostaAffermativa ? "SÌ" : "NO"}' +
                                (d.note != null ? ' | Note: ${d.note}' : ''),
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // 4. Sonno
                _buildScrollableListView(
                  itemCount: sonnoLogs.length,
                  itemBuilder: (context, i) {
                    final s = sonnoLogs[i];
                    return Card(
                      color: AppColors.surface,
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: const Icon(Icons.bedtime, color: WhoopTheme.strainBlue),
                          title: Text(
                            'Sonno: ${dateFormat.format(s.inizioSonno)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Durata: ${s.durataSonnoMin?.toInt() ?? 0} min | Efficienza: ${s.efficienzaSonnoPct?.toStringAsFixed(1) ?? "-"}%\nProfondo: ${s.sonnoProfondoMin} min | REM: ${s.sonnoRemMin} min',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          trailing: Text(
                            '${s.andamentoSonnoPct?.toInt() ?? 0}%',
                            style: const TextStyle(
                              color: WhoopTheme.strainBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollableListView({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
  }) {
    if (itemCount == 0) {
      return const Center(
        child: Text(
          'Nessun dato registrato',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}
