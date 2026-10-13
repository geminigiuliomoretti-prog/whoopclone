import 'package:flutter/material.dart';
import '../../core/theme/nature_theme.dart';

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
  final Color? backgroundColor;

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
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? Colors.transparent,
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 8.0),
      child: Column(
        children: [
          // 1. Top Status Row: [Avatar + Streak]   [ <  OGGI  > ]   [ Battery Band Icon ]
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Avatar + Streak (Cliccabile -> Profilo)
              GestureDetector(
                onTap: onAvatarTap,
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: NatureColors.surfaceElevated,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: NatureColors.recovery.withValues(alpha: 0.55),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          userInitials,
                          style: const TextStyle(
                            color: NatureColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: NatureColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: NatureColors.strain.withValues(alpha: 0.35),
                          width: 0.85,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.20),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_fire_department, color: NatureColors.strain, size: 14),
                          const SizedBox(width: 3),
                          Text(
                            '$streakDays',
                            style: const TextStyle(
                              color: NatureColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Date Pill Selector < OGGI > (Cliccabile -> DatePicker)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: NatureColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: NatureColors.border,
                    width: 0.85,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.chevron_left,
                        color: NatureColors.textSecondary,
                        size: 18,
                      ),
                      onPressed: onPreviousDate,
                    ),
                    GestureDetector(
                      onTap: onDateTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                        child: Text(
                          currentDateLabel.toUpperCase(),
                          style: const TextStyle(
                            color: NatureColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.chevron_right,
                        color: onNextDate != null
                            ? NatureColors.textSecondary
                            : NatureColors.textMuted.withValues(alpha: 0.4),
                        size: 18,
                      ),
                      onPressed: onNextDate,
                    ),
                  ],
                ),
              ),

              // Battery Status & Wearable Capsule (Cliccabile -> Diagnostica BLE)
              GestureDetector(
                onTap: onBatteryTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: NatureColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: bleConnected
                          ? NatureColors.recovery.withValues(alpha: 0.50)
                          : NatureColors.border,
                      width: 0.85,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: bleConnected
                              ? NatureColors.recovery
                              : NatureColors.textMuted,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        batteryPct != null ? '$batteryPct%' : '--%',
                        style: const TextStyle(
                          color: NatureColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 2. Top Metric Rings Row Selector (O SONNO, O RECUPERO, O SFORZO)
          if (showRingSelectors) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildRingSelectorItem(
                  index: 0,
                  label: 'SONNO',
                  ringColor: NatureColors.sleep,
                ),
                _buildRingSelectorItem(
                  index: 1,
                  label: 'RECUPERO',
                  ringColor: NatureColors.recovery,
                ),
                _buildRingSelectorItem(
                  index: 2,
                  label: 'SFORZO',
                  ringColor: NatureColors.strain,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? ringColor.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? ringColor : NatureColors.border,
            width: 0.85,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ringColor, width: 2.2),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? NatureColors.textPrimary : NatureColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 11,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
