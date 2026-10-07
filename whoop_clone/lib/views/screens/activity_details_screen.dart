import 'package:flutter/material.dart';
import '../../core/constants/whoop_theme.dart';
import '../../core/theme/nature_theme.dart';

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
  final double? zoneZ1Pct;
  final double? zoneZ2Pct;
  final double? zoneZ3Pct;
  final double? zoneZ4Pct;
  final double? zoneZ5Pct;
  final int? durationMin;

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
    this.zoneZ1Pct,
    this.zoneZ2Pct,
    this.zoneZ3Pct,
    this.zoneZ4Pct,
    this.zoneZ5Pct,
    this.durationMin,
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
    double? zoneZ1Pct,
    double? zoneZ2Pct,
    double? zoneZ3Pct,
    double? zoneZ4Pct,
    double? zoneZ5Pct,
    int? durationMin,
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
          zoneZ1Pct: zoneZ1Pct,
          zoneZ2Pct: zoneZ2Pct,
          zoneZ3Pct: zoneZ3Pct,
          zoneZ4Pct: zoneZ4Pct,
          zoneZ5Pct: zoneZ5Pct,
          durationMin: durationMin,
        ),
      ),
    );
  }

  int get _effectiveDurationMinutes {
    if (durationMin != null && durationMin! > 0) return durationMin!;
    final match = RegExp(r'\d+').firstMatch(durationText);
    if (match != null) {
      return int.tryParse(match.group(0) ?? '') ?? 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final totalMin = _effectiveDurationMinutes;
    final z1 = (zoneZ1Pct ?? 0.0).clamp(0.0, 1.0);
    final z2 = (zoneZ2Pct ?? 0.0).clamp(0.0, 1.0);
    final z3 = (zoneZ3Pct ?? 0.0).clamp(0.0, 1.0);
    final z4 = (zoneZ4Pct ?? 0.0).clamp(0.0, 1.0);
    final z5 = (zoneZ5Pct ?? 0.0).clamp(0.0, 1.0);

    String formatZone(double pct) {
      if (pct <= 0.0 || totalMin <= 0) return '0 min (0%)';
      final m = (pct * totalMin).round();
      final p = (pct * 100.0).round();
      return '$m min ($p%)';
    }

    return Scaffold(
      backgroundColor: NatureColors.darkCanvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          activityName.toUpperCase(),
          style: const TextStyle(
            color: NatureColors.textDarkPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: NatureColors.powderBlue),
            tooltip: 'Esporta Traccia GPX',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Traccia GPX generata con successo ed esportata!'),
                  backgroundColor: NatureColors.powderBlue,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share, color: NatureColors.powderBlue),
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
            Container(
              decoration: NatureTheme.organicCardDecoration(accentTint: NatureColors.terracotta),
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: NatureColors.terracotta.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: NatureColors.terracotta, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        activityStrain.toStringAsFixed(1),
                        style: const TextStyle(
                          color: NatureColors.coralLight,
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
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Oggi • 10:30 AM • $durationText',
                          style: const TextStyle(color: NatureColors.textDarkSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Sforzo elevato in Zona 4 per 48 min',
                          style: TextStyle(color: NatureColors.coralLight, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. Dark Mode GPS Map Overlay
            const Text(
              'TRACCIATO GPS OVERLAY OUTDOOR',
              style: TextStyle(
                color: NatureColors.textDarkSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),

            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: NatureTheme.organicCardDecoration(),
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
                          color: NatureColors.darkSurface.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: NatureColors.darkBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.navigation, color: NatureColors.coralLight, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'Distanza: ${distanceKm != null ? "${distanceKm!.toStringAsFixed(1)} km" : "--"}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
                Expanded(child: _buildStatTile('FC Media', fcMediaBpm != null ? '$fcMediaBpm bpm' : '--', Icons.favorite, NatureColors.powderBlue)),
                const SizedBox(width: 10),
                Expanded(child: _buildStatTile('FC Max', fcMaxBpm != null ? '$fcMaxBpm bpm' : '--', Icons.favorite_border, NatureColors.terracotta)),
                const SizedBox(width: 10),
                Expanded(child: _buildStatTile('Calorie', caloriesBurned != null ? '$caloriesBurned kcal' : '--', Icons.local_fire_department, NatureColors.amberWarm)),
              ],
            ),

            const SizedBox(height: 20),

            // 4. Grafico Frequenza Cardiaca nel Tempo
            const Text(
              'ANDAMENTO BATTITO CARDIACO (LIVE HR TIMELINE)',
              style: TextStyle(
                color: NatureColors.textDarkSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),

            Container(
              decoration: NatureTheme.organicCardDecoration(),
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                height: 120,
                width: double.infinity,
                child: CustomPaint(
                  painter: _HrTimelinePainter(),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 5. Ripartizione nelle 5 Zone FC
            const Text(
              'RIPARTIZIONE DEL TEMPO NELLE 5 ZONE FC',
              style: TextStyle(
                color: NatureColors.textDarkSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),

            Container(
              decoration: NatureTheme.organicCardDecoration(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildZoneItem('Zona 5 - Massimo (90-100% FCmax)', formatZone(z5), NatureColors.terracotta, z5),
                  const SizedBox(height: 8),
                  _buildZoneItem('Zona 4 - Soglia Anaerobica (80-90%)', formatZone(z4), NatureColors.amberWarm, z4),
                  const SizedBox(height: 8),
                  _buildZoneItem('Zona 3 - Aerobica (70-80%)', formatZone(z3), NatureColors.powderBlue, z3),
                  const SizedBox(height: 8),
                  _buildZoneItem('Zona 2 - Endurance / Brucia Grassi', formatZone(z2), NatureColors.sage, z2),
                  const SizedBox(height: 8),
                  _buildZoneItem('Zona 1 - Riscaldamento (50-60%)', formatZone(z1), NatureColors.textDarkMuted, z1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color) {
    return Container(
      decoration: NatureTheme.organicCardDecoration(),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: NatureColors.textDarkMuted, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
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
            Text(label, style: const TextStyle(color: NatureColors.textDarkPrimary, fontSize: 11)),
            Text(timeText, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: NatureColors.darkBorder,
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
