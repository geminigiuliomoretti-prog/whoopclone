import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/whoop_theme.dart';
import '../../data/database/database_helper.dart';
import '../../viewmodels/whoop_viewmodel.dart';

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

  List<CoachChatMessage> _messages = [];
  bool _isLoadingMessages = true;

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

    final viewModel = Provider.of<WhoopViewModel>(context, listen: false);

    Future.delayed(const Duration(milliseconds: 600), () async {
      String responseText = _generateCoachAiResponse(text, viewModel);
      await _dbHelper.insertCoachMessage('coach', responseText);
      if (!mounted) return;
      await _loadCoachMessagesFromSqlite();
    });
  }

  String _generateCoachAiResponse(String userQuery, WhoopViewModel viewModel) {
    final query = userQuery.toLowerCase();
    final ciclo = viewModel.ultimoCiclo;
    final rec = ciclo?.punteggioRecuperoPct?.toInt();
    final hrv = ciclo?.vfcMs?.toInt();
    final rhr = ciclo?.fcrBpm?.toInt();
    final strain = ciclo?.sforzoGiornaliero;
    final name = viewModel.userName.split(' ').first;

    if (query.contains('allenamento') || query.contains('sforzo') || query.contains('allenarmi')) {
      if (rec != null) {
        return 'Oggi il tuo Recupero è al $rec% (${rec >= 67 ? "Zona Verde" : rec >= 34 ? "Zona Gialla" : "Zona Rossa"}). Il tuo target di Sforzo consigliato è calibrato in base al carico cardiovascolare odierno.';
      } else {
        return 'I dati di Recupero notturno sono in attesa di calibrazione. Esegui un allenamento a intensità moderata o ascolta le sensazioni corporee.';
      }
    } else if (query.contains('sonno') || query.contains('dormire') || query.contains('risveglio') || query.contains('fasce')) {
      if (strain != null && strain > 0) {
        return 'Con un Day Strain di ${strain.toStringAsFixed(1)}, mantieni una routine di sonno regolare stasera per massimizzare la rigenerazione cellulare.';
      } else {
        return 'Per ottimizzare il sonno, mantieni un orario di coricamento costante e riduci l\'esposizione agli schermi un\'ora prima di dormire.';
      }
    } else if (query.contains('magnesio') || query.contains('integratori') || query.contains('diario')) {
      return 'L\'analisi del tuo Diario indica che una corretta idratazione e l\'assunzione di Magnesio prima di dormire favoriscono la stabilità della VFC notturna.';
    } else if (query.contains('vfc') || query.contains('hrv')) {
      if (hrv != null && rhr != null) {
        return 'La tua Variabilità della Frequenza Cardiaca (VFC) a ${hrv}ms e FCR a ${rhr}bpm indicano un corretto tono autonomico parasimpatico.';
      } else {
        return 'I valori di VFC e FCR notturni sono in elaborazione. Indossa la fascia durante il riposo per raccogliere i dati fisiologici.';
      }
    } else {
      if (rec != null && hrv != null && rhr != null) {
        return 'Ciao $name, in base ai tuoi dati biometrici correnti (VFC: ${hrv}ms, FCR: ${rhr}bpm, Recupero: $rec%), il tuo organismo è monitorato e pronto per la giornata.';
      } else {
        return 'Ciao $name, i tuoi parametri biometrici sono in sincronizzazione con la fascia. Continua a monitorare i cicli quotidiani per visualizzare i trend storici.';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1116),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1116),
        elevation: 0,
        leading: (widget.onBackToHome != null || Navigator.canPop(context))
            ? IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
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
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: WhoopTheme.strainBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('\\V/', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 6),
                const Text(
                  'WHOOP',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const Text(
              'BETA V5.2',
              style: TextStyle(color: WhoopTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white, size: 22),
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
                    label: Text(prompt, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    backgroundColor: const Color(0xFF161D23),
                    side: const BorderSide(color: WhoopTheme.cardBorder),
                    onPressed: () => _sendMessage(prompt),
                  ),
                );
              },
            ),
          ),

          const Divider(color: WhoopTheme.cardBorder, height: 1),

          // Messages List View
          Expanded(
            child: _isLoadingMessages
                ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(WhoopTheme.strainBlue)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg.sender == 'user';
                      return _buildMessageBubble(msg, isUser);
                    },
                  ),
          ),

          // Input Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            decoration: const BoxDecoration(
              color: Color(0xFF161D23),
              border: Border(top: BorderSide(color: WhoopTheme.cardBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Chiedi al tuo WHOOP Coach AI...',
                      hintStyle: const TextStyle(color: WhoopTheme.textMuted, fontSize: 12),
                      filled: true,
                      fillColor: WhoopTheme.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: WhoopTheme.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: WhoopTheme.cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: WhoopTheme.strainBlue),
                      ),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: WhoopTheme.strainBlue, size: 24),
                  onPressed: () => _sendMessage(_textController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(CoachChatMessage msg, bool isUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: WhoopTheme.strainBlue, shape: BoxShape.circle),
              child: const Text('\\V/', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF1E293B) : const Color(0xFF161D23),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: isUser ? WhoopTheme.strainBlue.withValues(alpha: 0.5) : WhoopTheme.cardBorder,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: isUser ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
