import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/whoop_theme.dart';
import '../../core/theme/nature_theme.dart';
import '../../viewmodels/whoop_viewmodel.dart';
import '../../data/models/ciclo_fisiologico.dart';

/// Modal Calendario Recupero (CAL-01)
/// Visualizza lo storico giornaliero con colorazione codificata in base al Recovery Score:
/// - Sage: Recupero >= 67%
/// - Amber: Recupero 34% - 66%
/// - Terracotta: Recupero 1% - 33%
/// - Grigio Neutro: Dati assenti / Dispositivo non indossato
class RecoveryCalendarModal extends StatefulWidget {
  final DateTime initialDate;

  const RecoveryCalendarModal({super.key, required this.initialDate});

  static Future<void> show(BuildContext context) {
    final vm = Provider.of<WhoopViewModel>(context, listen: false);
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => RecoveryCalendarModal(initialDate: vm.selectedDate),
    );
  }

  @override
  State<RecoveryCalendarModal> createState() => _RecoveryCalendarModalState();
}

class _RecoveryCalendarModalState extends State<RecoveryCalendarModal> {
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    _displayedMonth = DateTime(widget.initialDate.year, widget.initialDate.month, 1);
  }

  void _prevMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
    });
  }

  String _formatMonthYear(DateTime dt) {
    const months = [
      'GENNAIO', 'FEBBRAIO', 'MARZO', 'APRILE', 'MAGGIO', 'GIUGNO',
      'LUGLIO', 'AGOSTO', 'SETTEMBRE', 'OTTOBRE', 'NOVEMBRE', 'DICEMBRE'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  Color _getRecoveryColor(double? recoveryPct) {
    if (recoveryPct == null || recoveryPct <= 0) {
      return NatureColors.borderSubtle; // Neutral grey
    }
    if (recoveryPct >= 67.0) {
      return NatureColors.sage;
    } else if (recoveryPct >= 34.0) {
      return NatureColors.amber;
    } else {
      return NatureColors.terracotta;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vm = Provider.of<WhoopViewModel>(context);
    final selectedDate = vm.selectedDate;
    final cicliMap = <String, CicloFisiologico>{};
    for (final c in vm.cicliList) {
      cicliMap[c.dataIso] = c;
    }

    final daysInMonth = DateUtils.getDaysInMonth(_displayedMonth.year, _displayedMonth.month);
    final firstWeekday = DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday; // 1 = Monday, 7 = Sunday
    final leadingBlanks = firstWeekday - 1;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? NatureColors.darkCard : NatureColors.offWhite,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: isDark ? NatureColors.darkBorder : NatureColors.sandBorder,
            width: 1.5,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? NatureColors.darkBorder : NatureColors.sandBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header: Month Navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: isDark ? Colors.white : NatureColors.textPrimary),
                onPressed: _prevMonth,
              ),
              Text(
                _formatMonthYear(_displayedMonth),
                style: TextStyle(
                  color: isDark ? Colors.white : NatureColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: isDark ? Colors.white : NatureColors.textPrimary),
                onPressed: _nextMonth,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Weekday headers
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _WeekdayHeader('L'),
              _WeekdayHeader('M'),
              _WeekdayHeader('M'),
              _WeekdayHeader('G'),
              _WeekdayHeader('V'),
              _WeekdayHeader('S'),
              _WeekdayHeader('D'),
            ],
          ),
          const SizedBox(height: 8),

          // Days grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leadingBlanks + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              if (index < leadingBlanks) {
                return const SizedBox.shrink();
              }

              final dayNum = index - leadingBlanks + 1;
              final cellDate = DateTime(_displayedMonth.year, _displayedMonth.month, dayNum);
              final dateIso = cellDate.toIso8601String().substring(0, 10);
              final ciclo = cicliMap[dateIso];
              final recovery = ciclo?.punteggioRecuperoPct;
              final isSelected = cellDate.year == selectedDate.year &&
                  cellDate.month == selectedDate.month &&
                  cellDate.day == selectedDate.day;
              final recoveryColor = _getRecoveryColor(recovery);
              final hasRecovery = recovery != null && recovery > 0;

              return GestureDetector(
                onTap: () {
                  vm.setSelectedDate(cellDate);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? NatureColors.tealLight.withValues(alpha: 0.20)
                        : (isDark ? NatureColors.darkSurface : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? NatureColors.tealLight
                          : (hasRecovery
                              ? recoveryColor.withValues(alpha: 0.35)
                              : (isDark ? NatureColors.darkBorder : NatureColors.sandBorderSubtle)),
                      width: isSelected ? 2.0 : 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          color: isSelected
                              ? (isDark ? Colors.white : NatureColors.tealDark)
                              : (isDark ? NatureColors.textDarkPrimary : NatureColors.textPrimary),
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: recoveryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),

          // Legend (CAL-01)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? NatureColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? NatureColors.darkBorder : NatureColors.sandBorderSubtle,
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _LegendDot(color: NatureColors.sage, label: '≥ 67%'),
                _LegendDot(color: NatureColors.amber, label: '34-66%'),
                _LegendDot(color: NatureColors.terracotta, label: '< 34%'),
                _LegendDot(color: NatureColors.borderSubtle, label: 'Assente'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  final String label;
  const _WeekdayHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: WhoopTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: WhoopTheme.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
