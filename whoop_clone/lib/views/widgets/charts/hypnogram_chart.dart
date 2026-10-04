import 'package:flutter/material.dart';
import '../../../core/constants/whoop_theme.dart';

/// Rappresentazione di un blocco di stadio di sonno nell'ipnogramma
class HypnogramBlock {
  final DateTime startTime;
  final DateTime endTime;
  final String stage; // 'wake', 'light', 'sws', 'rem'
  final int durationMinutes;

  const HypnogramBlock({
    required this.startTime,
    required this.endTime,
    required this.stage,
    required this.durationMinutes,
  });

  Color get color {
    switch (stage.toLowerCase()) {
      case 'wake':
      case 'veglia':
        return const Color(0xFFFF9500); // Arancione veglia
      case 'rem':
        return const Color(0xFF5AC8FA); // Azzurro chiaro REM
      case 'light':
      case 'leggero':
        return const Color(0xFF5856D6); // Viola/Blu sonno leggero
      case 'sws':
      case 'deep':
      case 'profondo':
      default:
        return const Color(0xFF0A84FF); // Blu elettrico/profondo SWS
    }
  }

  String get displayName {
    switch (stage.toLowerCase()) {
      case 'wake':
      case 'veglia':
        return 'Veglia / Risveglio';
      case 'rem':
        return 'Sonno REM';
      case 'light':
      case 'leggero':
        return 'Sonno Leggero';
      case 'sws':
      case 'deep':
      case 'profondo':
      default:
        return 'Sonno Profondo (SWS)';
    }
  }
}

/// Grafico Ipnogramma Notturno Interattivo (Architettura NOOP)
/// Supporta interazione touch con tooltip fluttuante per visualizzare orari esatti e durate delle fasi.
class HypnogramChart extends StatefulWidget {
  final List<HypnogramBlock> blocks;
  final double height;
  final bool showLegend;

  const HypnogramChart({
    super.key,
    required this.blocks,
    this.height = 140,
    this.showLegend = true,
  });

  @override
  State<HypnogramChart> createState() => _HypnogramChartState();
}

class _HypnogramChartState extends State<HypnogramChart> {
  HypnogramBlock? _selectedBlock;
  Offset? _touchPosition;

  @override
  Widget build(BuildContext context) {
    if (widget.blocks.isEmpty) {
      return Container(
        height: widget.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF141920),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: WhoopTheme.cardBorder),
        ),
        child: const Text(
          'Nessun dato di ipnogramma registrato',
          style: TextStyle(color: WhoopTheme.textMuted, fontSize: 12),
        ),
      );
    }

    final totalMinutes = widget.blocks.map((b) => b.durationMinutes).reduce((a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Area Grafica con Gestione Touch
        GestureDetector(
          onTapDown: (details) => _handleTouch(details.localPosition, totalMinutes),
          onHorizontalDragUpdate: (details) => _handleTouch(details.localPosition, totalMinutes),
          onTapUp: (_) => setState(() => _selectedBlock = null),
          onHorizontalDragEnd: (_) => setState(() => _selectedBlock = null),
          child: Container(
            height: widget.height,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF141920),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: WhoopTheme.cardBorder),
            ),
            child: Stack(
              children: [
                // Griglia e Barre Temporali
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStageRow('VEGLIA', const Color(0xFFFF9500), 0.15),
                    _buildStageRow('REM', const Color(0xFF5AC8FA), 0.25),
                    _buildStageRow('LEGGERO', const Color(0xFF5856D6), 0.40),
                    _buildStageRow('SWS', const Color(0xFF0A84FF), 0.20),
                  ],
                ),

                // Tracciato a Blocchi Reale
                Positioned.fill(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: widget.blocks.map((block) {
                      final flex = (block.durationMinutes * 1000) ~/ (totalMinutes > 0 ? totalMinutes : 1);
                      final isSelected = _selectedBlock == block;

                      return Expanded(
                        flex: flex > 0 ? flex : 1,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 0.5),
                          decoration: BoxDecoration(
                            color: block.color.withValues(alpha: isSelected ? 1.0 : 0.85),
                            borderRadius: BorderRadius.circular(2),
                            border: isSelected ? Border.all(color: Colors.white, width: 1.5) : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Tooltip Fluttuante su Touch
                if (_selectedBlock != null && _touchPosition != null)
                  Positioned(
                    left: (_touchPosition!.dx - 80).clamp(0.0, MediaQuery.of(context).size.width - 200),
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _selectedBlock!.color, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 6,
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedBlock!.displayName,
                            style: TextStyle(
                              color: _selectedBlock!.color,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_formatTime(_selectedBlock!.startTime)} - ${_formatTime(_selectedBlock!.endTime)} (${_selectedBlock!.durationMinutes} min)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        if (widget.showLegend) ...[
          const SizedBox(height: 10),
          _buildLegend(),
        ],
      ],
    );
  }

  void _handleTouch(Offset localPos, int totalMinutes) {
    if (widget.blocks.isEmpty) return;
    final width = context.size?.width ?? 300.0;
    final ratio = (localPos.dx / width).clamp(0.0, 1.0);
    final targetMinute = ratio * totalMinutes;

    int accumulated = 0;
    HypnogramBlock? found;
    for (final b in widget.blocks) {
      accumulated += b.durationMinutes;
      if (targetMinute <= accumulated) {
        found = b;
        break;
      }
    }

    setState(() {
      _selectedBlock = found ?? widget.blocks.last;
      _touchPosition = localPos;
    });
  }

  Widget _buildStageRow(String label, Color color, double weight) {
    return Row(
      children: [
        SizedBox(
          width: 55,
          child: Text(
            label,
            style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Divider(color: WhoopTheme.cardBorder.withValues(alpha: 0.3), height: 1),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildLegendItem('Veglia', const Color(0xFFFF9500)),
        _buildLegendItem('REM', const Color(0xFF5AC8FA)),
        _buildLegendItem('Leggero', const Color(0xFF5856D6)),
        _buildLegendItem('SWS', const Color(0xFF0A84FF)),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: WhoopTheme.textSecondary, fontSize: 10),
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
