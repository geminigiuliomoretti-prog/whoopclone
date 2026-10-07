import 'package:flutter/material.dart';
import '../../core/constants/whoop_theme.dart';
import '../../core/theme/nature_theme.dart';

/// Card Frequenza Cardiaca Live WHOOP 5.0
/// Riproduce al 100% lo screenshot "Salute - Tab Salute Frequenza Cardiaca e 5 Parametri Vitali.jpeg":
/// - Icona cuore blu elettrico (#00B0FF)
/// - Cifra BPM in tabular figures (es. 70 BPM)
/// - Indicatore "Zona 0" con 5 trattini orizzontali di zona
/// - Griglia coordinata di sfondo con linea d'onda blu sfumata
/// - Linea verticale tratteggiata e pallino live
class LiveHeartRateCard extends StatelessWidget {
  final int liveBpm;
  final int maxHr;
  final List<int>? bpmHistory;

  const LiveHeartRateCard({
    super.key,
    required this.liveBpm,
    this.maxHr = 195,
    this.bpmHistory,
  });

  int get _currentZone {
    if (liveBpm <= 0) return 0;
    final pct = liveBpm / maxHr;
    if (pct < 0.50) return 0;
    if (pct < 0.60) return 1;
    if (pct < 0.70) return 2;
    if (pct < 0.80) return 3;
    if (pct < 0.90) return 4;
    return 5;
  }

  @override
  Widget build(BuildContext context) {
    final zone = _currentZone;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: 196,
      padding: const EdgeInsets.all(18.0),
      decoration: WhoopTheme.officialCardDecoration(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FREQUENZA CARDIACA',
            style: TextStyle(
              color: WhoopTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Colonna Sinistra: Cuore + BPM + Zona + 5 Trattini
                SizedBox(
                  width: 100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.favorite,
                        color: WhoopTheme.strainBlue,
                        size: 26,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        liveBpm > 0 ? '$liveBpm' : '--',
                        style: const TextStyle(
                          color: WhoopTheme.textPrimary,
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'BPM',
                        style: TextStyle(
                          color: WhoopTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        liveBpm > 0 ? 'Zona $zone' : '--',
                        style: const TextStyle(
                          color: WhoopTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // 5 Trattini Orizzontali
                      Row(
                        children: List.generate(5, (index) {
                          final isActive = index < zone;
                          return Container(
                            width: 14,
                            height: 3.5,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? WhoopTheme.strainBlue
                                  : (isDark ? const Color(0xFF26323D) : NatureColors.sandPebble),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Area Destra: Griglia coordinata + onda blu sfumata + linea tratteggiata
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _LiveHeartRateGridPainter(
                        liveBpm: liveBpm,
                        isDark: isDark,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveHeartRateGridPainter extends CustomPainter {
  final int liveBpm;
  final bool isDark;

  _LiveHeartRateGridPainter({
    required this.liveBpm,
    this.isDark = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = isDark ? const Color(0xFF1B242C) : NatureColors.sandBorderSubtle
      ..strokeWidth = 1.0;

    // 1. Griglia orizzontale (4 linee)
    const hLines = 4;
    for (int i = 0; i <= hLines; i++) {
      final y = size.height * (i / hLines);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Griglia verticale (6 linee)
    const vLines = 6;
    for (int i = 0; i <= vLines; i++) {
      final x = size.width * (i / vLines);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Se nessun battito live, disegna una linea di base neutra senza curva o punti mock
    if (liveBpm <= 0) {
      final neutralPaint = Paint()
        ..color = isDark ? const Color(0xFF26333D) : NatureColors.sandPebble
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(0, size.height * 0.5),
        Offset(size.width, size.height * 0.5),
        neutralPaint,
      );
      return;
    }

    // Posizione X del valore live (al 90% della larghezza)
    final targetX = size.width * 0.90;
    // Calcoliamo la coordinata Y in base al BPM (range 50-140)
    final normalizedY = 1.0 - ((liveBpm.clamp(50, 140) - 50) / 90.0);
    final targetY = (size.height * 0.2) + (normalizedY * (size.height * 0.6));

    // 3. Alone di riempimento sfumato sotto la linea
    final fillPath = Path();
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, size.height * 0.52);
    fillPath.cubicTo(
      size.width * 0.25,
      size.height * 0.50,
      size.width * 0.55,
      size.height * 0.50,
      targetX,
      targetY,
    );
    fillPath.lineTo(targetX, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          WhoopTheme.strainBlue.withValues(alpha: 0.22),
          WhoopTheme.strainBlue.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, targetX, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // 4. Linea d'onda blu luminescente
    final wavePath = Path();
    wavePath.moveTo(0, size.height * 0.52);
    wavePath.cubicTo(
      size.width * 0.25,
      size.height * 0.50,
      size.width * 0.55,
      size.height * 0.50,
      targetX,
      targetY,
    );

    final linePaint = Paint()
      ..color = WhoopTheme.strainBlue
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(wavePath, linePaint);

    // 5. Linea verticale tratteggiata
    final dashPaint = Paint()
      ..color = const Color(0xFF495B6A)
      ..strokeWidth = 1.0;
    const dashHeight = 3.5;
    const dashSpace = 3.0;
    double currentY = 0;
    while (currentY < size.height) {
      canvas.drawLine(
        Offset(targetX, currentY),
        Offset(targetX, currentY + dashHeight),
        dashPaint,
      );
      currentY += dashHeight + dashSpace;
    }

    // 6. Pallino bianco con alone di bagliore blu
    final haloPaint = Paint()
      ..color = WhoopTheme.strainBlue.withValues(alpha: 0.40);
    canvas.drawCircle(Offset(targetX, targetY), 6.0, haloPaint);

    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(targetX, targetY), 3.2, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _LiveHeartRateGridPainter oldDelegate) {
    return oldDelegate.liveBpm != liveBpm;
  }
}
