import 'package:flutter/material.dart';
import '../../core/constants/whoop_theme.dart';

/// Schermata "DETTAGLI DEL COMPORTAMENTO" (Rispecchia al 100% l'immagine del video al min 3:30, frame 30)
class BehaviorDetailScreen extends StatelessWidget {
  final String habitName;
  final double impactPercentage;
  final bool isPositive;

  const BehaviorDetailScreen({
    super.key,
    this.habitName = 'Social Media',
    this.impactPercentage = -5.0,
    this.isPositive = false,
  });

  static void show(BuildContext context, {String habitName = 'Social Media', double impactPct = -5.0, bool isPositive = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BehaviorDetailScreen(
          habitName: habitName,
          impactPercentage: impactPct,
          isPositive: isPositive,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = isPositive ? WhoopTheme.recoveryGreen : WhoopTheme.recoveryYellow;
    final statusText = isPositive ? 'Positivo' : 'Negativo';

    return Scaffold(
      backgroundColor: WhoopTheme.background,
      appBar: AppBar(
        backgroundColor: WhoopTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'DETTAGLI DEL COMPORTAMENTO',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titolo Abitudine
            Text(
              habitName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),

            // Card IMPATTO SUL RECUPERO
            Container(
              padding: const EdgeInsets.all(16),
              decoration: WhoopTheme.officialCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'IMPATTO SUL RECUPERO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (impactPercentage.abs() / 15.0).clamp(0.1, 1.0),
                            backgroundColor: WhoopTheme.cardBorder,
                            valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${impactPercentage > 0 ? "+" : ""}${impactPercentage.toInt()}%',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // PER QUANTO TEMPO?
                  const Text('PER QUANTO TEMPO?', style: TextStyle(color: WhoopTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  const SizedBox(height: 8),
                  _buildSubImpactRow('2-120 Minuti', '-6%'),
                  _buildSubImpactRow('150-200 Minuti', '+3%'),

                  const SizedBox(height: 16),

                  // QUANDO HAI SMESSO?
                  const Text('QUANDO HAI SMESSO?', style: TextStyle(color: WhoopTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  const SizedBox(height: 8),
                  _buildSubImpactRow('0 ore prima di andare a letto', '0%'),
                  _buildSubImpactRow('1-3 ore prima di andare a letto', '-5%'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Cronologia delle registrazioni (Matrice Calendario)
            const Text(
              'Cronologia delle registrazioni',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white, size: 20), onPressed: () {}),
                const Text('APR \'26 - GIU \'26', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                IconButton(icon: const Icon(Icons.chevron_right, color: Colors.white, size: 20), onPressed: () {}),
              ],
            ),
            const SizedBox(height: 12),

            // Matrice pallini calendario
            Container(
              padding: const EdgeInsets.all(16),
              decoration: WhoopTheme.officialCardDecoration(),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMonthDotColumn('APR', 22),
                      _buildMonthDotColumn('MAG', 16),
                      _buildMonthDotColumn('GIU', 3),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.circle, color: WhoopTheme.strainBlue, size: 10),
                      SizedBox(width: 4),
                      Text('Sì (41)', style: TextStyle(color: WhoopTheme.textMuted, fontSize: 10)),
                      SizedBox(width: 12),
                      Icon(Icons.circle_outlined, color: Colors.white, size: 10),
                      SizedBox(width: 4),
                      Text('No (0)', style: TextStyle(color: WhoopTheme.textMuted, fontSize: 10)),
                      SizedBox(width: 12),
                      Icon(Icons.circle_outlined, color: WhoopTheme.textMuted, size: 10),
                      SizedBox(width: 4),
                      Text('Mancante (50)', style: TextStyle(color: WhoopTheme.textMuted, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSubImpactRow(String label, String value) {
    final isPos = value.startsWith('+');
    final color = isPos ? WhoopTheme.recoveryGreen : WhoopTheme.recoveryYellow;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMonthDotColumn(String monthName, int count) {
    return Column(
      children: [
        Row(
          children: [
            Text(monthName, style: const TextStyle(color: WhoopTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(color: WhoopTheme.strainBlue.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
              child: Text('✓ $count', style: const TextStyle(color: WhoopTheme.strainBlue, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Mini dot grid simulation
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: List.generate(15, (i) => Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: i < 10 ? WhoopTheme.strainBlue : WhoopTheme.cardBorder))),
        ),
      ],
    );
  }
}
