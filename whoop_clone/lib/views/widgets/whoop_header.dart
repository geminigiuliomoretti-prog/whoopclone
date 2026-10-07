import 'package:flutter/material.dart';
import '../../core/constants/whoop_theme.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? WhoopTheme.background : NatureColors.offWhite,
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
                        color: (isDark
                                ? WhoopTheme.recoveryGreen
                                : NatureColors.sage)
                            .withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? WhoopTheme.recoveryGreen.withValues(alpha: 0.60)
                              : NatureColors.sage,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          userInitials,
                          style: TextStyle(
                            color: isDark ? Colors.white : NatureColors.textLightPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF281C16)
                            : NatureColors.coralLight.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF4A2B1E)
                              : NatureColors.coralLight.withValues(alpha: 0.50),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_fire_department, color: Color(0xFFE07A5F), size: 14),
                          const SizedBox(width: 3),
                          Text(
                            '$streakDays',
                            style: TextStyle(
                              color: isDark ? Colors.white : NatureColors.textLightPrimary,
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
                  color: isDark ? const Color(0xFF182026) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF26333D) : NatureColors.sandBorder,
                  ),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: const Color(0xFF2C3E50).withValues(alpha: 0.04),
                        blurRadius: 6,
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
                      icon: Icon(
                        Icons.chevron_left,
                        color: isDark ? WhoopTheme.textSecondary : NatureColors.textLightSecondary,
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
                          style: TextStyle(
                            color: isDark ? Colors.white : NatureColors.textLightPrimary,
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
                            ? (isDark ? WhoopTheme.textSecondary : NatureColors.textLightSecondary)
                            : (isDark ? WhoopTheme.cardBorder : NatureColors.sandBorder),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161F26) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: bleConnected
                          ? (isDark ? WhoopTheme.recoveryGreen.withValues(alpha: 0.40) : NatureColors.sage)
                          : (isDark ? const Color(0xFF26333D) : NatureColors.sandBorder),
                      width: 0.8,
                    ),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: const Color(0xFF1E2832).withValues(alpha: 0.03),
                          blurRadius: 6,
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
                              ? (isDark ? WhoopTheme.recoveryGreen : NatureColors.sage)
                              : const Color(0xFF8E9BA7),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        batteryPct != null ? '$batteryPct%' : '--%',
                        style: TextStyle(
                          color: isDark ? Colors.white : NatureColors.textLightPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 2. Top Metric Rings Row Selector (O SONNO, O RECUPERO, O SFORZO) - Visibile solo se richiesto (es. sticky scroll)
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
