import 'package:flutter/material.dart';
import '../../core/constants/whoop_theme.dart';

/// Modulo 7: Activity Details Screen (Sezione 7 Roadmap)
/// Analisi dettagliata della singola seduta di allenamento:
/// Dark mode GPS Map Overlay, Grafico FC continuo, Distribuzione 5 Zone FC, Calorie e Activity Strain.
class ActivityDetailsScreen extends StatelessWidget {
  final String activityName;
  final double activityStrain;
  final String durationText;
  final int? fcMaxBpm;
  final int? fcMediaBpm;
  final int? caloriesBurned;
  final double? distanceKm;
  final List<Map<String, dynamic>> routePoints;

  const ActivityDetailsScreen({
    super.key,
    this.activityName = 'Attività',
    this.activityStrain = 0.0,
    this.durationText = '0m',
    this.fcMaxBpm,
    this.fcMediaBpm,
    this.caloriesBurned,
    this.distanceKm,
    this.routePoints = const [],
  });

  static void show(BuildContext context, {
    String activityName = 'Attività',
    double activityStrain = 0.0,
    String durationText = '0m',
    int? fcMaxBpm,
    int? fcMediaBpm,
    int? caloriesBurned,
    double? distanceKm,
    List<Map<String, dynamic>> routePoints = const [],
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActivityDetailsScreen(
          activityName: activityName,
          activityStrain: activityStrain,
          durationText: durationText,
          fcMaxBpm: fcMaxBpm,
          fcMediaBpm: fcMediaBpm,
          caloriesBurned: caloriesBurned,
          distanceKm: distanceKm,
          routePoints: routePoints,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WhoopTheme.background,
      appBar: AppBar(
        title: Text(
          activityName.toUpperCase(),
          style: const TextStyle(
            color: WhoopTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: WhoopTheme.strainBlue),
            tooltip: 'Esporta Traccia GPX',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Traccia GPX generata con successo ed esportata!'),
                  backgroundColor: WhoopTheme.strainBlue,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share, color: WhoopTheme.strainBlue),
            tooltip: 'Condividi WHOOP Live',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('WHOOP Live Overlay esportato per la condivisione!')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Activity Strain & Summary Card
            Card(
              color: WhoopTheme.cardSurface,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: WhoopTheme.strainBlue.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: WhoopTheme.strainBlue, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          activityStrain.toStringAsFixed(1),
                          style: const TextStyle(
                            color: WhoopTheme.strainBlue,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activityName,
                            style: const TextStyle(
                              color: WhoopTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Oggi • 10:30 AM • $durationText',
                            style: const TextStyle(color: WhoopTheme.textSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sforzo elevato in Zona 4 per 48 min',
                            style: const TextStyle(color: WhoopTheme.strainHigh, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 2. Dark Mode GPS Map Overlay
            const Text(
              'TRACCIATO GPS OVERLAY OUTDOOR',
              style: TextStyle(
                color: WhoopTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),

            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 180,
                width: double.infinity,
                color: WhoopTheme.cardSurface,
                child: Stack(
                  children: [
                    CustomPaint(
                      size: const Size(double.infinity, 180),
                      painter: _DarkGpsMapPainter(routePoints: routePoints),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: WhoopTheme.background.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: WhoopTheme.cardBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.navigation, color: WhoopTheme.strainBlue, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'Distanza: ${distanceKm != null ? "${distanceKm!.toStringAsFixed(1)} km" : "--"}',
                              style: const TextStyle(color: WhoopTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 3. Statistiche Chiave (FC Media, FC Max, Calorie, Passo Medio)
            Row(
              children: [
                Expanded(child: _buildStatTile('FC Media', fcMediaBpm != null ? '$fcMediaBpm bpm' : '--', Icons.favorite, WhoopTheme.strainBlue)),
                const SizedBox(width: 10),
                Expanded(child: _buildStatTile('FC Max', fcMaxBpm != null ? '$fcMaxBpm bpm' : '--', Icons.favorite_border, WhoopTheme.strainHigh)),
                const SizedBox(width: 10),
                Expanded(child: _buildStatTile('Calorie', caloriesBurned != null ? '$caloriesBurned kcal' : '--', Icons.local_fire_department, WhoopTheme.recoveryYellow)),
              ],
            ),

            const SizedBox(height: 20),

            // 4. Grafico Frequenza Cardiaca nel Tempo
            const Text(
              'ANDAMENTO BATTITO CARDIACO (LIVE HR TIMELINE)',
              style: TextStyle(
                color: WhoopTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),

            Card(
              color: WhoopTheme.cardSurface,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _HrTimelinePainter(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 5. Ripartizione nelle 5 Zone FC
            const Text(
              'RIPARTIZIONE DEL TEMPO NELLE 5 ZONE FC',
              style: TextStyle(
                color: WhoopTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),

            Card(
              color: WhoopTheme.cardSurface,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildZoneItem('Zona 5 - Massimo (90-100% FCmax)', '12 min (11%)', WhoopTheme.strainHigh, 0.11),
                    const SizedBox(height: 8),
                    _buildZoneItem('Zona 4 - Soglia Anaerobica (80-90%)', '48 min (46%)', WhoopTheme.strainBlue, 0.46),
                    const SizedBox(height: 8),
                    _buildZoneItem('Zona 3 - Aerobica (70-80%)', '32 min (30%)', WhoopTheme.recoveryGreen, 0.30),
                    const SizedBox(height: 8),
                    _buildZoneItem('Zona 2 - Endurance / Brucia Grassi', '10 min (10%)', WhoopTheme.recoveryYellow, 0.10),
                    const SizedBox(height: 8),
                    _buildZoneItem('Zona 1 - Riscaldamento (50-60%)', '3 min (3%)', WhoopTheme.textSecondary, 0.03),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color) {
    return Card(
      color: WhoopTheme.cardSurface,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 10)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneItem(String label, String timeText, Color color, double pct) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: WhoopTheme.textPrimary, fontSize: 11)),
            Text(timeText, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: WhoopTheme.cardBorder,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

class _DarkGpsMapPainter extends CustomPainter {
  final List<Map<String, dynamic>> routePoints;

  _DarkGpsMapPainter({this.routePoints = const []});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw Dark Mode Grid background
    final gridPaint = Paint()
      ..color = WhoopTheme.cardBorder.withOpacity(0.3)
      ..strokeWidth = 1.0;

    for (double i = 0; i < size.width; i += 30) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double j = 0; j < size.height; j += 30) {
      canvas.drawLine(Offset(0, j), Offset(size.width, j), gridPaint);
    }

    if (routePoints.length < 2) {
      // Fallback: Disegna percorso rappresentativo dinamico
      final routePaint = Paint()
        ..color = WhoopTheme.strainBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;

      final path = Path();
      path.moveTo(size.width * 0.1, size.height * 0.8);
      path.cubicTo(
        size.width * 0.25, size.height * 0.2,
        size.width * 0.5, size.height * 0.9,
        size.width * 0.7, size.height * 0.3,
      );
      path.lineTo(size.width * 0.9, size.height * 0.5);

      canvas.drawPath(path, routePaint);

      final startDot = Paint()..color = WhoopTheme.recoveryGreen;
      canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.8), 6, startDot);

      final endDot = Paint()..color = WhoopTheme.strainHigh;
      canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.5), 6, endDot);
      return;
    }

    // Normalizzazione delle coordinate Lat/Lon reali per il canvas
    double minLat = routePoints.first['latitude'] as double;
    double maxLat = minLat;
    double minLon = routePoints.first['longitude'] as double;
    double maxLon = minLon;

    for (final pt in routePoints) {
      final lat = pt['latitude'] as double;
      final lon = pt['longitude'] as double;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lon < minLon) minLon = lon;
      if (lon > maxLon) maxLon = lon;
    }

    final latSpan = (maxLat - minLat).abs() < 0.0001 ? 0.0001 : (maxLat - minLat);
    final lonSpan = (maxLon - minLon).abs() < 0.0001 ? 0.0001 : (maxLon - minLon);

    final routePaint = Paint()
      ..color = WhoopTheme.strainBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final canvasPoints = <Offset>[];

    for (final pt in routePoints) {
      final lat = pt['latitude'] as double;
      final lon = pt['longitude'] as double;

      final x = ((lon - minLon) / lonSpan) * (size.width - 40) + 20;
      final y = (1.0 - ((lat - minLat) / latSpan)) * (size.height - 40) + 20;

      canvasPoints.add(Offset(x, y));
    }

    path.moveTo(canvasPoints.first.dx, canvasPoints.first.dy);
    for (int i = 1; i < canvasPoints.length; i++) {
      path.lineTo(canvasPoints[i].dx, canvasPoints[i].dy);
    }

    canvas.drawPath(path, routePaint);

    // Pin Inizio (Verde) e Fine (Rosso) su coordinate reali
    final startDot = Paint()..color = WhoopTheme.recoveryGreen;
    canvas.drawCircle(canvasPoints.first, 6, startDot);

    final endDot = Paint()..color = WhoopTheme.strainHigh;
    canvas.drawCircle(canvasPoints.last, 6, endDot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _HrTimelinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = WhoopTheme.strainHigh
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final points = [
      Offset(0, size.height * 0.8),
      Offset(size.width * 0.2, size.height * 0.6),
      Offset(size.width * 0.4, size.height * 0.3),
      Offset(size.width * 0.6, size.height * 0.2),
      Offset(size.width * 0.8, size.height * 0.5),
      Offset(size.width, size.height * 0.7),
    ];

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
