import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/nature_theme.dart';
import '../../data/models/personal_baseline.dart';
import '../../data/services/whoop_archive_importer.dart';
import '../../viewmodels/whoop_viewmodel.dart';

/// Schermata "Importa dati WHOOP"
/// Permette di selezionare l'archivio ZIP esportato da WHOOP,
/// salvare lo storico completo su SQLite e inizializzare le baseline
/// fisiologiche personali dell'utente (HRV, RHR, respirazione, sonno, temp, SpO2).
class WhoopImportScreen extends StatefulWidget {
  const WhoopImportScreen({super.key});

  static void show(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WhoopImportScreen()),
    );
  }

  @override
  State<WhoopImportScreen> createState() => _WhoopImportScreenState();
}

class _WhoopImportScreenState extends State<WhoopImportScreen> {
  bool _isImporting = false;
  WhoopImportProgress? _currentProgress;
  WhoopImportResult? _lastResult;
  String? _errorMessage;
  String? _detectedLocalZipPath;

  @override
  void initState() {
    super.initState();
    _checkDetectedLocalFiles();
  }

  void _checkDetectedLocalFiles() {
    try {
      if (Platform.isWindows) {
        // Verifica se nella cartella Downloads dell'utente è presente l'export
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          final downloadsDir = Directory('$userProfile\\Downloads');
          if (downloadsDir.existsSync()) {
            final candidates = downloadsDir.listSync().whereType<File>().where((f) {
              final name = f.path.toLowerCase();
              return name.endsWith('.zip') && (name.contains('whoop') || name.contains('export'));
            }).toList();

            if (candidates.isNotEmpty) {
              // Ordina per ultimo modificato decrescente
              candidates.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
              setState(() {
                _detectedLocalZipPath = candidates.first.path;
              });
            }
          }
        }
      }
    } catch (_) {
      // Non bloccare se l'ispezione della directory locale fallisce
    }
  }

  Future<void> _pickAndImportFile({String? forcedPath}) async {
    String? selectedPath = forcedPath;
    List<int>? fileBytes;

    if (selectedPath == null) {
      try {
        final pickedFiles = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['zip'],
        );

        if (pickedFiles.isEmpty) {
          return;
        }

        final picked = pickedFiles.first;
        selectedPath = picked.path;
        if (selectedPath == null) {
          fileBytes = await picked.readAsBytes();
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Impossibile accedere al selettore di file: $e';
        });
        return;
      }
    }

    if (selectedPath == null && fileBytes == null) {
      return;
    }

    setState(() {
      _isImporting = true;
      _errorMessage = null;
      _currentProgress = const WhoopImportProgress(
        stage: WhoopImportStage.validating,
        message: 'Analisi export...',
        fraction: 0.05,
      );
    });

    final viewModel = Provider.of<WhoopViewModel>(context, listen: false);

    try {
      final importResult = await viewModel.importWhoopArchive(
        filePath: selectedPath,
        fileBytes: fileBytes,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _currentProgress = progress;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isImporting = false;
          _lastResult = importResult;
          if (!importResult.success) {
            _errorMessage = importResult.errors.isNotEmpty
                ? importResult.errors.join('\n')
                : 'Importazione non riuscita.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _errorMessage = 'Errore imprevisto durante l\'importazione: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<WhoopViewModel>(context);
    final existingBaselines = viewModel.personalBaselines;

    return Scaffold(
      backgroundColor: NatureColors.background,
      appBar: AppBar(
        backgroundColor: NatureColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: NatureColors.textDarkPrimary, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'IMPORTA DATI WHOOP',
          style: TextStyle(
            color: NatureColors.textDarkPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Hero Card Educativo
            _buildHeroCard(),

            const SizedBox(height: 16),

            // 2. Banner di Stato / Progresso
            if (_isImporting) _buildProgressCard(),

            // 3. Banner Errore se presente
            if (_errorMessage != null && !_isImporting) _buildErrorCard(_errorMessage!),

            // 4. Riepilogo Risultato Importazione
            if (_lastResult != null && _lastResult!.success && !_isImporting)
              _buildSuccessSummaryCard(_lastResult!),

            // 5. Pulsante di Selezione File
            if (!_isImporting) ...[
              const SizedBox(height: 20),
              _buildActionButtons(),
            ],

            // 6. Baseline Attive (Mostrate se già presenti o appena calcolate)
            if (existingBaselines.isNotEmpty && !_isImporting) ...[
              const SizedBox(height: 28),
              _buildBaselinesSection(existingBaselines),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      decoration: NatureTheme.organicCardDecoration(isDark: true),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: NatureColors.teal.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.folder_zip_outlined, color: NatureColors.tealLight, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Personalizzazione Baseline',
                  style: TextStyle(
                    color: NatureColors.textDarkPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Importa il tuo storico WHOOP per personalizzare le tue baseline.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'L\'archivio ZIP esportato da WHOOP contiene cicli fisiologici, sonno, allenamenti e risposte al diario. '
            'Tutti i dati storici vengono archiviati in locale e utilizzati dal motore dell\'app per calcolare i tuoi intervalli fisiologici reali '
            '(VFC, FCR, frequenza respiratoria, temperatura, SpO2 e fabbisogno di sonno), sostituendo i valori standard universali.',
            style: TextStyle(
              color: NatureColors.textDarkSecondary,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: NatureColors.surfaceElevated.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: NatureColors.borderSubtle),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: NatureColors.teal, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '100% Privacy Locale • Nessun upload su server esterni o chiamate cloud.',
                    style: TextStyle(
                      color: NatureColors.textDarkMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
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

  Widget _buildProgressCard() {
    final progress = _currentProgress;
    final pct = (progress?.progressPct ?? 0.1).clamp(0.0, 1.0);
    final msg = progress?.message ?? 'Elaborazione in corso...';

    return Container(
      decoration: NatureTheme.organicCardDecoration(
        isDark: true,
        accentTint: NatureColors.teal.withValues(alpha: 0.1),
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(NatureColors.tealLight),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  msg,
                  style: const TextStyle(
                    color: NatureColors.textDarkPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${(pct * 100).round()}%',
                style: const TextStyle(
                  color: NatureColors.tealLight,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: NatureColors.surfaceElevated,
              valueColor: const AlwaysStoppedAnimation<Color>(NatureColors.teal),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Elaborazione dello storico senza perdita di dati. Attendere la finalizzazione delle baseline...',
            style: TextStyle(color: NatureColors.textDarkMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      decoration: NatureTheme.organicCardDecoration(
        isDark: true,
        accentTint: NatureColors.terracotta.withValues(alpha: 0.12),
      ),
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: NatureColors.terracotta, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Attenzione',
                  style: TextStyle(
                    color: NatureColors.terracotta,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  error,
                  style: const TextStyle(color: NatureColors.textDarkSecondary, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessSummaryCard(WhoopImportResult result) {
    final periodText = (result.startDate != null && result.endDate != null)
        ? '${_formatDate(result.startDate!)} → ${_formatDate(result.endDate!)}'
        : 'Periodo rilevato';

    return Container(
      decoration: NatureTheme.organicCardDecoration(
        isDark: true,
        accentTint: NatureColors.recoveryGreen.withValues(alpha: 0.12),
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: NatureColors.recoveryGreen.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: NatureColors.recoveryGreen, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Importazione completata',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Baseline personali inizializzate.',
                      style: TextStyle(
                        color: NatureColors.tealLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Griglia delle statistiche importate
          Row(
            children: [
              Expanded(child: _buildMetricBadge('${result.cyclesCount}', 'cicli fisiologici', Icons.timeline)),
              const SizedBox(width: 10),
              Expanded(child: _buildMetricBadge('${result.sleepsCount}', 'sessioni di sonno', Icons.nightlight_round)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildMetricBadge('${result.workoutsCount}', 'allenamenti', Icons.fitness_center)),
              const SizedBox(width: 10),
              Expanded(child: _buildMetricBadge('${result.journalCount}', 'voci diario', Icons.book_outlined)),
            ],
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: NatureColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: NatureColors.borderSubtle),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, color: NatureColors.textDarkMuted, size: 16),
                const SizedBox(width: 10),
                const Text(
                  'Periodo importato: ',
                  style: TextStyle(color: NatureColors.textDarkMuted, fontSize: 12),
                ),
                Expanded(
                  child: Text(
                    periodText,
                    style: const TextStyle(
                      color: NatureColors.textDarkPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Note: ${result.warnings.join(', ')}',
              style: const TextStyle(color: NatureColors.textDarkMuted, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricBadge(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: NatureColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NatureColors.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(icon, color: NatureColors.tealLight, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: NatureColors.textDarkPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: NatureColors.textDarkMuted,
                    fontSize: 10.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Se un archivio ZIP è stato rilevato automaticamente nei Downloads locali
        if (_detectedLocalZipPath != null) ...[
          Container(
            decoration: NatureTheme.organicCardDecoration(
              isDark: true,
              accentTint: NatureColors.teal.withValues(alpha: 0.08),
            ),
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: NatureColors.tealLight, size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'Export rilevato nei tuoi Download:',
                      style: TextStyle(color: NatureColors.tealLight, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _detectedLocalZipPath!.split(Platform.isWindows ? '\\' : '/').last,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: () => _pickAndImportFile(forcedPath: _detectedLocalZipPath),
                    icon: const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                    label: const Text(
                      'IMPORTA RAPIDO FILE RILEVATO',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.8),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NatureColors.teal,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Pulsante primario per selezione manuale
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => _pickAndImportFile(),
            icon: const Icon(Icons.file_upload_outlined, color: Colors.white, size: 20),
            label: const Text(
              'Seleziona export WHOOP',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: NatureColors.teal,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBaselinesSection(List<PersonalBaseline> baselines) {
    final Map<String, PersonalBaseline> map = {
      for (final b in baselines) b.metricKey: b,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'BASELINE PERSONALI INIZIALIZZATE',
              style: TextStyle(
                color: NatureColors.textDarkSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              '${baselines.length} metriche',
              style: const TextStyle(
                color: NatureColors.tealLight,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Metriche chiave
        if (map.containsKey('hrv'))
          _buildBaselineTile(
            title: 'Variabilità Frequenza Cardiaca (VFC)',
            baseline: map['hrv']!,
            unit: 'ms',
            icon: Icons.show_chart,
            color: NatureColors.teal,
          ),
        if (map.containsKey('rhr'))
          _buildBaselineTile(
            title: 'FC a Riposo (FCR)',
            baseline: map['rhr']!,
            unit: 'bpm',
            icon: Icons.favorite,
            color: NatureColors.terracotta,
          ),
        if (map.containsKey('respiratory_rate'))
          _buildBaselineTile(
            title: 'Frequenza Respiratoria',
            baseline: map['respiratory_rate']!,
            unit: 'rpm',
            icon: Icons.air,
            color: NatureColors.tealLight,
          ),
        if (map.containsKey('skin_temp'))
          _buildBaselineTile(
            title: 'Temperatura Cutanea',
            baseline: map['skin_temp']!,
            unit: '°C',
            icon: Icons.thermostat,
            color: NatureColors.terracotta,
          ),
        if (map.containsKey('spo2'))
          _buildBaselineTile(
            title: 'Ossigeno nel Sangue (SpO₂)',
            baseline: map['spo2']!,
            unit: '%',
            icon: Icons.water_drop_outlined,
            color: NatureColors.teal,
          ),
        if (map.containsKey('sleep_duration'))
          _buildBaselineTile(
            title: 'Durata Sonno',
            baseline: map['sleep_duration']!,
            unit: 'min',
            icon: Icons.nightlight_round,
            color: NatureColors.sleepAccent,
            formatAsHoursMin: true,
          ),
        if (map.containsKey('sleep_efficiency'))
          _buildBaselineTile(
            title: 'Efficienza del Sonno',
            baseline: map['sleep_efficiency']!,
            unit: '%',
            icon: Icons.bedtime_outlined,
            color: NatureColors.sleepAccent,
          ),
        if (map.containsKey('sws_sleep'))
          _buildBaselineTile(
            title: 'Sonno Profondo (SWS)',
            baseline: map['sws_sleep']!,
            unit: 'min',
            icon: Icons.dark_mode,
            color: NatureColors.sleepAccent,
            formatAsHoursMin: true,
          ),
        if (map.containsKey('rem_sleep'))
          _buildBaselineTile(
            title: 'Sonno REM',
            baseline: map['rem_sleep']!,
            unit: 'min',
            icon: Icons.visibility,
            color: NatureColors.sleepAccent,
            formatAsHoursMin: true,
          ),
      ],
    );
  }

  Widget _buildBaselineTile({
    required String title,
    required PersonalBaseline baseline,
    required String unit,
    required IconData icon,
    required Color color,
    bool formatAsHoursMin = false,
  }) {
    String formatVal(double val) {
      if (formatAsHoursMin) {
        final hours = val ~/ 60;
        final mins = (val % 60).round();
        return '${hours}h ${mins}m';
      }
      return val.toStringAsFixed(1);
    }

    final baselineFormatted = '${formatVal(baseline.baselineValue)} $unit';
    final rangeText = 'Normale: ${formatVal(baseline.p10)} – ${formatVal(baseline.p90)} $unit';

    return Container(
      decoration: NatureTheme.organicCardDecoration(isDark: true),
      padding: const EdgeInsets.all(14.0),
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: NatureColors.textDarkPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rangeText,
                  style: const TextStyle(
                    color: NatureColors.textDarkMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                baselineFormatted,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              Text(
                '${baseline.sampleCount} gg',
                style: const TextStyle(
                  color: NatureColors.textDarkMuted,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final parts = iso.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
      return iso;
    } catch (_) {
      return iso;
    }
  }
}
