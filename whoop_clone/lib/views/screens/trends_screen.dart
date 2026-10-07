import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/whoop_theme.dart';
import '../../core/theme/nature_theme.dart';
import '../../data/models/ciclo_fisiologico.dart';
import '../../viewmodels/whoop_viewmodel.dart';

class TrendsScreen extends StatefulWidget {
  final String? initialMetric;

  const TrendsScreen({super.key, this.initialMetric});

  static void show(BuildContext context, {String? initialMetric}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrendsScreen(initialMetric: initialMetric),
      ),
    );
  }

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  String _selectedRange = '30D';
  late String _selectedMetric;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedMetric = widget.initialMetric ?? 'Variabilità FC (VFC)';
  }

  final List<String> _allMetrics = [
    'Variabilità FC (VFC)',
    'FC a Riposo (FCR)',
    'Passi Giornalieri',
    'Sforzo Giornaliero',
    'Zone FC 1–3',
    'Zone FC 4–5',
    'Frequenza Respiratoria',
    'Temperatura Cutanea',
    'VO₂ Max Stimato',
    'Dispendio Energetico',
  ];

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<WhoopViewModel>(context);
    final allCicli = viewModel.storicoCicli;

    final int limit;
    switch (_selectedRange) {
      case '7D':
        limit = 7;
        break;
      case '30D':
        limit = 30;
        break;
      case '6M':
        limit = 180;
        break;
      case '1Y':
        limit = 365;
        break;
      default:
        limit = 30;
    }

    final cicli = allCicli.length > limit
        ? allCicli.sublist(allCicli.length - limit)
        : allCicli;

    final hasData = cicli.isNotEmpty;
    final strainList = cicli.map((c) => c.sforzoGiornaliero).whereType<double>().toList();
    final avgStrain = strainList.isNotEmpty
        ? (strainList.reduce((a, b) => a + b) / strainList.length)
        : 0.0;

    final recoveryList = cicli.map((c) => c.punteggioRecuperoPct).whereType<double>().toList();
    final avgRecovery = recoveryList.isNotEmpty
        ? (recoveryList.reduce((a, b) => a + b) / recoveryList.length)
        : 0.0;

    final hrvList = cicli.map((c) => c.vfcMs).whereType<double>().toList();
    final avgHrv = hrvList.isNotEmpty
        ? (hrvList.reduce((a, b) => a + b) / hrvList.length)
        : 0.0;

    final sleepList = cicli.map((c) => c.andamentoSonnoPct).whereType<double>().toList();
    final avgSleep = sleepList.isNotEmpty
        ? (sleepList.reduce((a, b) => a + b) / sleepList.length)
        : 0.0;

    final strainValues = strainList;
    final recoveryValues = recoveryList;
    final hrvValues = hrvList;
    final sleepValues = sleepList;

    final selectedData = _extractMetricData(_selectedMetric, cicli);

    final selectedDateStr = _selectedDate.toIso8601String().substring(0, 10);
    CicloFisiologico? dayCiclo;
    try {
      dayCiclo = allCicli.firstWhere((c) => c.giorno.toIso8601String().substring(0, 10) == selectedDateStr);
    } catch (_) {
      dayCiclo = null;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? NatureColors.darkCanvas : NatureColors.canvas,
      appBar: AppBar(
        backgroundColor: isDark ? NatureColors.darkCanvas : NatureColors.canvas,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.chevron_left,
            color: isDark ? Colors.white : NatureColors.textPrimary,
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedMetric,
            dropdownColor: isDark ? NatureColors.darkCard : Colors.white,
            icon: const Icon(Icons.arrow_drop_down, color: NatureColors.tealLight),
            style: TextStyle(
              color: isDark ? Colors.white : NatureColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
            items: _allMetrics.map((m) {
              return DropdownMenuItem<String>(
                value: m,
                child: Text(
                  m.toUpperCase(),
                  style: TextStyle(
                    color: isDark ? Colors.white : NatureColors.textPrimary,
                  ),
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedMetric = val);
            },
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time Range Selector (7D, 30D, 6M, 1Y)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['7D', '30D', '6M', '1Y'].map((range) {
                final isSelected = _selectedRange == range;
                return ChoiceChip(
                  label: Text(range),
                  selected: isSelected,
                  selectedColor: NatureColors.tealLight,
                  backgroundColor: NatureColors.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: isSelected ? NatureColors.tealLight : NatureColors.borderSubtle),
                  ),
                  labelStyle: TextStyle(
                    color: isSelected ? NatureColors.canvas : NatureColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedRange = range;
                      });
                    }
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Metrica Focus Principale Selezionata
            _buildTrendCard(
              title: '${selectedData.title.toUpperCase()} ($_selectedRange)',
              averageLabel: selectedData.values.isNotEmpty
                  ? 'Media: ${selectedData.avgFormatted} | Min: ${selectedData.minFormatted} | Max: ${selectedData.maxFormatted}'
                  : 'Nessun dato registrato nel periodo',
              color: selectedData.color,
              chartHeight: 130,
              values: selectedData.values,
            ),

            const SizedBox(height: 16),

            // Trend Chart 1: Sforzo
            _buildTrendCard(
              title: 'ANDAMENTO SFORZO GIORNALIERO ($_selectedRange)',
              averageLabel: hasData
                  ? 'Media Sforzo: ${avgStrain.toStringAsFixed(1)} / 21.0 (${cicli.length} cicli)'
                  : 'Nessun ciclo fisiologico registrato nel DB',
              color: NatureColors.amber,
              chartHeight: 110,
              values: strainValues,
              fixedMax: 21.0,
              fixedMin: 0.0,
            ),

            const SizedBox(height: 16),

            // Trend Chart 2: Recupero
            _buildTrendCard(
              title: 'ANDAMENTO RECUPERO ($_selectedRange)',
              averageLabel: hasData
                  ? 'Media Recupero: ${avgRecovery.toInt()}% (${cicli.length} cicli)'
                  : 'Dati Recupero non disponibili',
              color: NatureColors.sage,
              chartHeight: 110,
              values: recoveryValues,
              fixedMax: 100.0,
              fixedMin: 0.0,
            ),

            const SizedBox(height: 16),

            // Trend Chart 3: VFC / HRV
            _buildTrendCard(
              title: 'VARIABILITÀ CARDIACA VFC ($_selectedRange)',
              averageLabel: hasData
                  ? 'Media VFC: ${avgHrv.toStringAsFixed(1)} ms'
                  : 'Dati VFC non disponibili in SQLite',
              color: NatureColors.sage,
              chartHeight: 110,
              values: hrvValues,
            ),

            const SizedBox(height: 16),

            // Trend Chart 4: Prestazione Sonno
            _buildTrendCard(
              title: 'PRESTAZIONE ED EFFICIENZA SONNO ($_selectedRange)',
              averageLabel: hasData
                  ? 'Media Sonno: ${avgSleep.toInt()}%'
                  : 'Dati Sonno non disponibili in SQLite',
              color: NatureColors.tealLight,
              chartHeight: 110,
              values: sleepValues,
              fixedMax: 100.0,
              fixedMin: 0.0,
            ),

            const SizedBox(height: 24),
            Divider(color: NatureColors.borderSubtle),
            const SizedBox(height: 16),

            // Navigatore Storico a Calendario
            const Text(
              'NAVIGATORE STORICO CALENDARIO',
              style: TextStyle(
                color: WhoopTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: NatureTheme.organicCardDecoration(elevated: true),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Data Selezionata: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: TextStyle(
                          color: isDark ? Colors.white : NatureColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2025),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedDate = picked;
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_month, size: 16),
                        label: const Text('Cambia Data'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: NatureColors.tealLight,
                          foregroundColor: NatureColors.canvas,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: NatureColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NatureColors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('Recupero', style: TextStyle(color: NatureColors.textMuted, fontSize: 11)),
                            Text(
                              dayCiclo?.punteggioRecuperoPct != null
                                  ? '${dayCiclo!.punteggioRecuperoPct!.toInt()}%'
                                  : '--%',
                              style: const TextStyle(color: NatureColors.sage, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('Sforzo', style: TextStyle(color: NatureColors.textMuted, fontSize: 11)),
                            Text(
                              dayCiclo?.sforzoGiornaliero != null
                                  ? dayCiclo!.sforzoGiornaliero!.toStringAsFixed(1)
                                  : '--',
                              style: const TextStyle(color: NatureColors.amber, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('Sonno', style: TextStyle(color: NatureColors.textMuted, fontSize: 11)),
                            Text(
                              dayCiclo?.andamentoSonnoPct != null
                                  ? '${dayCiclo!.andamentoSonnoPct!.toInt()}%'
                                  : '--%',
                              style: const TextStyle(color: NatureColors.tealLight, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  MetricData _extractMetricData(String metric, List<CicloFisiologico> cicli) {
    if (cicli.isEmpty) {
      return MetricData(title: metric, values: [], unit: '', color: NatureColors.tealLight);
    }

    switch (metric) {
      case 'Variabilità FC (VFC)':
        final vals = cicli.map((c) => c.vfcMs).whereType<double>().toList();
        return MetricData(title: metric, values: vals, unit: 'ms', color: NatureColors.sage);

      case 'FC a Riposo (FCR)':
        final vals = cicli.map((c) => c.frequenzaCardiacaRiposoBpm?.toDouble()).whereType<double>().toList();
        return MetricData(title: metric, values: vals, unit: 'bpm', color: NatureColors.sage);

      case 'Passi Giornalieri':
        return MetricData(title: metric, values: [], unit: 'passi', color: NatureColors.mist);

      case 'Sforzo Giornaliero':
        final vals = cicli.map((c) => c.sforzoGiornaliero).whereType<double>().toList();
        return MetricData(title: metric, values: vals, unit: '', color: NatureColors.amber);

      case 'Frequenza Respiratoria':
        final vals = cicli.map((c) => c.frequenzaRespiratoriaRpm).whereType<double>().toList();
        return MetricData(title: metric, values: vals, unit: 'rpm', color: NatureColors.sage);

      case 'Temperatura Cutanea':
        final vals = cicli.map((c) => c.temperaturaPelleCelsius).whereType<double>().toList();
        return MetricData(title: metric, values: vals, unit: '°C', color: NatureColors.amber);

      case 'VO₂ Max Stimato':
        return MetricData(title: metric, values: [], unit: 'ml/kg/min', color: NatureColors.tealLight);

      case 'Dispendio Energetico':
        final vals = cicli.map((c) => c.calorieTot?.toDouble()).whereType<double>().toList();
        return MetricData(title: metric, values: vals, unit: 'kcal', color: NatureColors.terracotta);

      default:
        final vals = cicli.map((c) => c.sforzoGiornaliero).whereType<double>().toList();
        return MetricData(title: metric, values: vals, unit: '', color: NatureColors.amber);
    }
  }

  Widget _buildTrendCard({
    required String title,
    required String averageLabel,
    required Color color,
    required double chartHeight,
    required List<double> values,
    double? fixedMin,
    double? fixedMax,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: NatureTheme.organicCardDecoration(elevated: true, isDark: isDark),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : NatureColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            averageLabel,
            style: const TextStyle(
              color: NatureColors.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: chartHeight,
            width: double.infinity,
            child: CustomPaint(
              painter: _TrendChartPainter(
                lineColor: color,
                values: values,
                fixedMin: fixedMin,
                fixedMax: fixedMax,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MetricData {
  final String title;
  final List<double> values;
  final String unit;
  final Color color;

  MetricData({
    required this.title,
    required this.values,
    required this.unit,
    required this.color,
  });

  String get avgFormatted {
    if (values.isEmpty) return '--';
    final avg = values.reduce((a, b) => a + b) / values.length;
    return '${avg.toStringAsFixed(1)} $unit';
  }

  String get minFormatted {
    if (values.isEmpty) return '--';
    final min = values.reduce(math.min);
    return '${min.toStringAsFixed(1)} $unit';
  }

  String get maxFormatted {
    if (values.isEmpty) return '--';
    final max = values.reduce(math.max);
    return '${max.toStringAsFixed(1)} $unit';
  }
}

class _TrendChartPainter extends CustomPainter {
  final Color lineColor;
  final List<double> values;
  final double? fixedMin;
  final double? fixedMax;

  _TrendChartPainter({
    required this.lineColor,
    required this.values,
    this.fixedMin,
    this.fixedMax,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) {
      final dashPaint = Paint()
        ..color = NatureColors.borderSubtle
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        dashPaint,
      );
      return;
    }

    final double minVal = fixedMin ?? values.reduce(math.min);
    final double maxVal = fixedMax ?? values.reduce(math.max);
    final double range = (maxVal - minVal) > 0 ? (maxVal - minVal) : 1.0;

    final double step = values.length > 1 ? size.width / (values.length - 1) : size.width / 2;
    final path = Path();
    final fillPath = Path();

    Offset getOffset(int i) {
      final x = values.length > 1 ? i * step : size.width / 2;
      final normalized = ((values[i] - minVal) / range).clamp(0.0, 1.0);
      final y = size.height - (normalized * (size.height - 20)) - 10;
      return Offset(x, y);
    }

    final p0 = getOffset(0);
    path.moveTo(p0.dx, p0.dy);
    fillPath.moveTo(p0.dx, size.height);
    fillPath.lineTo(p0.dx, p0.dy);

    for (int i = 1; i < values.length; i++) {
      final prev = getOffset(i - 1);
      final curr = getOffset(i);
      final midX = (prev.dx + curr.dx) / 2;
      path.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
      fillPath.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
    }

    fillPath.lineTo(getOffset(values.length - 1).dx, size.height);
    fillPath.close();

    // Sfumatura gradiente verticale
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.28),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);

    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    for (int i = 0; i < values.length; i++) {
      final p = getOffset(i);
      canvas.drawCircle(p, 3.5, dotPaint);
      canvas.drawCircle(p, 1.5, Paint()..color = NatureColors.canvas);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) => true;
}
