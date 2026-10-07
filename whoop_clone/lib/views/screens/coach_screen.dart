import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/nature_theme.dart';
import '../../data/database/database_helper.dart';
import '../../data/services/coach/coach_context_builder.dart';
import '../../data/services/coach/coach_models.dart';
import '../../data/services/coach/coach_service.dart';
import '../../viewmodels/whoop_viewmodel.dart';
import '../widgets/nature/coach_emblem.dart';

class CoachChatMessage {
  final String sender; // 'user' o 'coach'
  final String text;
  final DateTime timestamp;

  CoachChatMessage({
    required this.sender,
    required this.text,
    required this.timestamp,
  });
}

/// WHOOP Coach AI V5.4 (Redesign Stile Chat Moderno WHOOP Beta V5.2)
class CoachScreen extends StatefulWidget {
  final VoidCallback? onBackToHome;
  const CoachScreen({super.key, this.onBackToHome});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final TextEditingController _textController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final CoachService _coachService = CoachService();

  List<CoachChatMessage> _messages = [];
  bool _isLoadingMessages = true;
  bool _isAiResponding = false;

  final List<String> _suggestedPrompts = [
    'Quali fasce orarie di sonno e risveglio sono più costanti per me?',
    'Come dovrei allenarmi oggi?',
    'Qual è il mio fabbisogno sonno per stasera?',
    'Impatto del magnesio sulla mia VFC?',
  ];

  @override
  void initState() {
    super.initState();
    _loadCoachMessagesFromSqlite();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadCoachMessagesFromSqlite() async {
    try {
      final maps = await _dbHelper.getCoachMessages();
      if (maps.isEmpty) {
        await _dbHelper.insertCoachMessage(
          'coach',
          'Quali interrogativi ti poni oggi?',
        );
        final initialMaps = await _dbHelper.getCoachMessages();
        _messages = initialMaps
            .map((m) => CoachChatMessage(
                  sender: m['mittente'] as String,
                  text: m['testo_messaggio'] as String,
                  timestamp: DateTime.parse(m['timestamp'] as String),
                ))
            .toList();
      } else {
        _messages = maps
            .map((m) => CoachChatMessage(
                  sender: m['mittente'] as String,
                  text: m['testo_messaggio'] as String,
                  timestamp: DateTime.parse(m['timestamp'] as String),
                ))
            .toList();
      }
    } catch (_) {
      _messages = [
        CoachChatMessage(
          sender: 'coach',
          text: 'Quali interrogativi ti poni oggi?',
          timestamp: DateTime.now(),
        ),
      ];
    }

    if (mounted) {
      setState(() => _isLoadingMessages = false);
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _textController.clear();

    await _dbHelper.insertCoachMessage('user', text);
    await _loadCoachMessagesFromSqlite();

    if (!mounted) return;
    setState(() => _isAiResponding = true);

    final viewModel = Provider.of<WhoopViewModel>(context, listen: false);
    final coachContext = CoachContextBuilder.fromViewModelState(
      selectedDateIso: viewModel.selectedDateIso,
      ultimoCiclo: viewModel.ultimoCiclo,
      sonnoList: viewModel.sonnoList,
      vociDiarioList: viewModel.vociDiarioList,
      currentSleepNeedMin: viewModel.currentSleepNeedMinutes,
      isBleConnected: viewModel.isBleConnected,
    );

    try {
      final response = await _coachService.askCoach(
        query: text,
        context: coachContext,
      );

      await _dbHelper.insertCoachMessage('coach', response.text);
    } catch (e) {
      await _dbHelper.insertCoachMessage('coach', 'Errore durante la comunicazione con il Coach: $e');
    } finally {
      if (mounted) {
        setState(() => _isAiResponding = false);
        await _loadCoachMessagesFromSqlite();
      }
    }
  }

  void _showCoachSettingsDialog(BuildContext context) {
    CoachProviderType selectedType = _coachService.config.providerType;
    final apiKeyController = TextEditingController(text: _coachService.config.apiKey ?? '');
    final modelController = TextEditingController(text: _coachService.config.model);
    final endpointController = TextEditingController(text: _coachService.config.endpoint ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return AlertDialog(
              backgroundColor: isDark ? NatureColors.darkSurface : Colors.white,
              title: const Text('Configurazione Coach AI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Provider LLM:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<CoachProviderType>(
                      value: selectedType,
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      items: CoachProviderType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.label, style: const TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedType = val;
                            if (val == CoachProviderType.openAi && modelController.text.isEmpty) {
                              modelController.text = 'gpt-4o-mini';
                            } else if (val == CoachProviderType.anthropic && modelController.text.isEmpty) {
                              modelController.text = 'claude-3-5-sonnet-20241022';
                            } else if (val == CoachProviderType.gemini && modelController.text.isEmpty) {
                              modelController.text = 'gemini-1.5-flash';
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    if (selectedType != CoachProviderType.localRuleBased) ...[
                      const Text('Chiave API (Salvata localmente):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: apiKeyController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: 'Inserisci la tua API Key',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Nome Modello:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: modelController,
                        decoration: const InputDecoration(
                          hintText: 'es. gpt-4o-mini / gemini-1.5-flash',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Custom Endpoint (Opzionale):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: endpointController,
                        decoration: const InputDecoration(
                          hintText: 'Lascia vuoto per endpoint ufficiale',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'Il provider Locale Offline analizza i tuoi dati scientifici reali senza inviare alcuna informazione a server terzi.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annulla'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newCfg = _coachService.config.copyWith(
                      providerType: selectedType,
                      apiKey: apiKeyController.text.trim().isEmpty ? null : apiKeyController.text.trim(),
                      model: modelController.text.trim().isEmpty ? 'gpt-4o-mini' : modelController.text.trim(),
                      endpoint: endpointController.text.trim().isEmpty ? null : endpointController.text.trim(),
                    );
                    await _coachService.updateConfig(newCfg);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Salva'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? NatureColors.darkCanvas : NatureColors.offWhite,
      appBar: AppBar(
        backgroundColor: isDark ? NatureColors.darkCanvas : NatureColors.offWhite,
        elevation: 0,
        leading: (widget.onBackToHome != null || Navigator.canPop(context))
            ? IconButton(
                icon: Icon(
                  Icons.chevron_left,
                  color: isDark ? Colors.white : NatureColors.textLightPrimary,
                  size: 28,
                ),
                onPressed: () {
                  if (widget.onBackToHome != null) {
                    widget.onBackToHome!();
                  } else if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              )
            : null,
        title: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? NatureColors.teal.withValues(alpha: 0.25)
                        : NatureColors.sage.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: CoachEmblem(
                    size: 16,
                    color: isDark ? NatureColors.tealLight : NatureColors.sageDark,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'COACH AI',
                  style: TextStyle(
                    color: isDark ? Colors.white : NatureColors.textLightPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            Text(
              'GUIDA FISIOLOGICA INTELLIGENTE',
              style: TextStyle(
                color: isDark ? NatureColors.textDarkMuted : NatureColors.textLightMuted,
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.tune,
              color: isDark ? Colors.white : NatureColors.textLightPrimary,
              size: 22,
            ),
            tooltip: 'Impostazioni Coach AI',
            onPressed: () => _showCoachSettingsDialog(context),
          ),
          IconButton(
            icon: Icon(
              Icons.history,
              color: isDark ? Colors.white : NatureColors.textLightPrimary,
              size: 22,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick Prompt Chips horizontal bar
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _suggestedPrompts.length,
              itemBuilder: (context, idx) {
                final prompt = _suggestedPrompts[idx];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(
                      prompt,
                      style: TextStyle(
                        color: isDark ? NatureColors.textDarkPrimary : NatureColors.textLightPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: isDark ? NatureColors.darkSurface : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isDark ? NatureColors.darkBorderSubtle : NatureColors.sandBorder,
                      ),
                    ),
                    onPressed: () => _sendMessage(prompt),
                  ),
                );
              },
            ),
          ),

          Divider(
            color: isDark ? NatureColors.darkBorderSubtle : NatureColors.sandBorder,
            height: 1,
          ),

          // Messages List View
          Expanded(
            child: _isLoadingMessages
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(
                        isDark ? NatureColors.tealLight : NatureColors.sage,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _messages.length + (_isAiResponding ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _buildThinkingBubble(isDark);
                      }
                      final msg = _messages[index];
                      final isUser = msg.sender == 'user';
                      return _buildMessageBubble(msg, isUser, isDark);
                    },
                  ),
          ),

          // Input Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            decoration: BoxDecoration(
              color: isDark ? NatureColors.darkSurfaceRaised : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? NatureColors.darkBorderSubtle : NatureColors.sandBorder,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: TextStyle(
                      color: isDark ? Colors.white : NatureColors.textLightPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Chiedi al tuo Coach AI...',
                      hintStyle: TextStyle(
                        color: isDark ? NatureColors.textDarkMuted : NatureColors.textLightMuted,
                        fontSize: 12,
                      ),
                      filled: true,
                      fillColor: isDark ? NatureColors.darkSurface : NatureColors.offWhite,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: isDark ? NatureColors.darkBorderSubtle : NatureColors.sandBorder,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: isDark ? NatureColors.darkBorderSubtle : NatureColors.sandBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: isDark ? NatureColors.tealLight : NatureColors.sage,
                        ),
                      ),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.send_rounded,
                    color: isDark ? NatureColors.tealLight : NatureColors.sage,
                    size: 24,
                  ),
                  onPressed: () => _sendMessage(_textController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(CoachChatMessage msg, bool isUser, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark
                    ? NatureColors.tealLight.withValues(alpha: 0.25)
                    : NatureColors.sage.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: CoachEmblem(
                size: 16,
                color: isDark ? NatureColors.tealLight : NatureColors.sageDark,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? (isDark
                        ? NatureColors.darkSurfaceRaised
                        : NatureColors.sage)
                    : (isDark ? NatureColors.darkSurface : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: isUser
                      ? (isDark
                          ? NatureColors.tealLight.withValues(alpha: 0.5)
                          : NatureColors.sageDark.withValues(alpha: 0.3))
                      : (isDark ? NatureColors.darkBorderSubtle : NatureColors.sandBorder),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : const Color(0xFF2C3E50).withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  color: isUser
                      ? Colors.white
                      : (isDark ? NatureColors.textDarkPrimary : NatureColors.textLightPrimary),
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: isUser ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingBubble(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark
                  ? NatureColors.tealLight.withValues(alpha: 0.25)
                  : NatureColors.sage.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: CoachEmblem(
              size: 16,
              color: isDark ? NatureColors.tealLight : NatureColors.sageDark,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? NatureColors.darkSurface : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(
                color: isDark ? NatureColors.darkBorderSubtle : NatureColors.sandBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                      isDark ? NatureColors.tealLight : NatureColors.sage,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Coach sta analizzando i tuoi dati...',
                  style: TextStyle(
                    color: isDark ? NatureColors.textDarkMuted : NatureColors.textLightMuted,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
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
