import 'package:flutter/material.dart';
import '../../core/constants/whoop_theme.dart';

class WhoopHeader extends StatelessWidget {
  final String currentDateLabel;
  final int selectedRingIndex; // 0 = Sonno, 1 = Recupero, 2 = Sforzo
  final ValueChanged<int>? onRingSelected;
  final VoidCallback? onPreviousDate;
  final VoidCallback? onNextDate;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onDateTap;
  final VoidCallback? onBatteryTap;
  final String userInitials;
  final int streakDays;
  final int? batteryPct;
  final bool bleConnected;
  final bool showRingSelectors;

  const WhoopHeader({
    super.key,
    this.currentDateLabel = 'OGGI',
    this.selectedRingIndex = 1,
    this.onRingSelected,
    this.onPreviousDate,
    this.onNextDate,
    this.onAvatarTap,
    this.onDateTap,
    this.onBatteryTap,
    this.userInitials = '--',
    this.streakDays = 0,
    this.batteryPct,
    this.bleConnected = false,
    this.showRingSelectors = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: WhoopTheme.background,
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 12.0),
      child: Column(
        children: [
          // 1. Top Status Row: [Avatar + Streak]   [ <  OGGI  > ]   [ Battery Band Icon ]
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Avatar GM + Flame Streak (Cliccabile -> Profilo)
              GestureDetector(
                onTap: onAvatarTap,
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: WhoopTheme.recoveryGreen,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          userInitials,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.local_fire_department, color: Color(0xFFFF5252), size: 18),
                    const SizedBox(width: 3),
                    Text(
                      '$streakDays',
                      style: const TextStyle(
                        color: WhoopTheme.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // Date Pill Selector < OGGI > (Cliccabile -> DatePicker)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E262C),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: WhoopTheme.cardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.chevron_left, color: WhoopTheme.textSecondary, size: 18),
                      onPressed: onPreviousDate,
                    ),
                    GestureDetector(
                      onTap: onDateTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                        child: Text(
                          currentDateLabel.toUpperCase(),
                          style: const TextStyle(
                            color: WhoopTheme.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(Icons.chevron_right, color: onNextDate != null ? WhoopTheme.textSecondary : WhoopTheme.cardBorder, size: 18),
                      onPressed: onNextDate,
                    ),
                  ],
                ),
              ),

              // Battery Status & Whoop Band Icon (Cliccabile -> Gestione Dispositivo BLE)
              GestureDetector(
                onTap: onBatteryTap,
                child: Row(
                  children: [
                    Text(
                      batteryPct != null ? '$batteryPct%' : '--%',
                      style: const TextStyle(
                        color: WhoopTheme.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Authentic WHOOP 5.0 Strap & Puck Battery Glyphs
                    CustomPaint(
                      size: const Size(20, 24),
                      painter: _WhoopBatteryPuckPainter(
                        batteryPct: batteryPct ?? 0,
                        isConnected: bleConnected,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Official WHOOP Brand Wordmark Center (\V/HOOP)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                WhoopTheme.logoWhite,
                height: 20,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Text(
                  '\\V/ H O O P',
                  style: TextStyle(
                    color: WhoopTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 4.0,
                  ),
                ),
              ),
            ],
          ),

          // 3. Top Metric Rings Row Selector (O SONNO, O RECUPERO, O SFORZO) - Visibile solo se richiesto (es. sticky scroll)
          if (showRingSelectors) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildRingSelectorItem(
                  index: 0,
                  label: 'SONNO',
                  ringColor: WhoopTheme.sleepSlate,
                ),
                _buildRingSelectorItem(
                  index: 1,
                  label: 'RECUPERO',
                  ringColor: WhoopTheme.recoveryGreen,
                ),
                _buildRingSelectorItem(
                  index: 2,
                  label: 'SFORZO',
                  ringColor: WhoopTheme.strainBlue,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRingSelectorItem({
    required int index,
    required String label,
    required Color ringColor,
  }) {
    final isSelected = selectedRingIndex == index;

    return GestureDetector(
      onTap: () => onRingSelected?.call(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? ringColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? ringColor : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ringColor, width: 2.5),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? WhoopTheme.textPrimary : WhoopTheme.textSecondary,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Disegna il caratteristico indicatore di batteria WHOOP (Puck sagomato con arco di carica)
class _WhoopBatteryPuckPainter extends CustomPainter {
  final int batteryPct;
  final bool isConnected;

  const _WhoopBatteryPuckPainter({
    required this.batteryPct,
    required this.isConnected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Colore stato carica
    Color levelColor;
    if (!isConnected) {
      levelColor = WhoopTheme.textMuted;
    } else if (batteryPct >= 50) {
      levelColor = WhoopTheme.recoveryGreen;
    } else if (batteryPct >= 20) {
      levelColor = WhoopTheme.recoveryYellow;
    } else {
      levelColor = WhoopTheme.recoveryRed;
    }

    // 1. Profilo Cinturino WHOOP (Puck a capsula verticale)
    final puckRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, 2, w - 8, h - 4),
      const Radius.circular(5),
    );

    final puckOutlinePaint = Paint()
      ..color = const Color(0xFF435360)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(puckRect, puckOutlinePaint);

    // 2. Arco di Carica laterale (Stile Whoop 5.0)
    final arcPaint = Paint()
      ..color = levelColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final sweep = ((batteryPct.clamp(0, 100) / 100.0) * (h - 6));
    canvas.drawLine(
      Offset(w - 2, h - 3),
      Offset(w - 2, (h - 3) - sweep),
      arcPaint,
    );

    // 3. Dot di Connessione BLE Attiva
    if (isConnected) {
      final dotPaint = Paint()..color = WhoopTheme.recoveryGreen;
      canvas.drawCircle(Offset(w - 2, 3), 1.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WhoopBatteryPuckPainter oldDelegate) {
    return oldDelegate.batteryPct != batteryPct || oldDelegate.isConnected != isConnected;
  }
}
