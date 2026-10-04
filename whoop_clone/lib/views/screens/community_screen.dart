import 'package:flutter/material.dart';
import '../../core/constants/whoop_theme.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: WhoopTheme.background,
        appBar: AppBar(
          title: const Text(
            'COMMUNITY & TEAMS',
            style: TextStyle(
              color: WhoopTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          bottom: const TabBar(
            indicatorColor: WhoopTheme.strainBlue,
            labelColor: WhoopTheme.textPrimary,
            unselectedLabelColor: WhoopTheme.textSecondary,
            tabs: [
              Tab(text: 'Classifiche'),
              Tab(text: 'I Miei Team'),
              Tab(text: 'Chat di Gruppo'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Leaderboard Classifiche
            _buildLeaderboardTab(),

            // Tab 2: I Miei Team
            _buildTeamsTab(context),

            // Tab 3: Chat di Gruppo
            _buildGroupChatTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardTab() {
    final athletes = [
      {'rank': 1, 'name': 'Marco R.', 'strain': 18.2, 'recovery': 92, 'isUser': false},
      {'rank': 2, 'name': 'Gianmarco (Tu)', 'strain': 17.5, 'recovery': 88, 'isUser': true},
      {'rank': 3, 'name': 'Elena V.', 'strain': 16.8, 'recovery': 84, 'isUser': false},
      {'rank': 4, 'name': 'Alessandro T.', 'strain': 15.4, 'recovery': 78, 'isUser': false},
      {'rank': 5, 'name': 'Sofia M.', 'strain': 14.9, 'recovery': 75, 'isUser': false},
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CLASSIFICA SETTIMANALE (TEAM TRIATHLON)',
                style: TextStyle(color: WhoopTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Chip(
                label: const Text('Sforzo Totale'),
                backgroundColor: WhoopTheme.strainBlue,
                labelStyle: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ...athletes.map((a) {
            final isUser = a['isUser'] as bool;
            return Card(
              color: isUser ? WhoopTheme.cardBorder : WhoopTheme.cardSurface,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isUser ? WhoopTheme.strainBlue : WhoopTheme.background,
                  child: Text(
                    '#${a['rank']}',
                    style: TextStyle(
                      color: isUser ? Colors.black : WhoopTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  a['name'] as String,
                  style: TextStyle(
                    color: isUser ? WhoopTheme.strainBlue : WhoopTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text('Recupero Medio: ${a['recovery']}%'),
                trailing: Text(
                  '${a['strain']} Sforzo',
                  style: const TextStyle(color: WhoopTheme.strainBlue, fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTeamsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      physics: const BouncingScrollPhysics(),
      children: [
        Card(
          color: WhoopTheme.cardSurface,
          child: ListTile(
            leading: const Icon(Icons.groups, color: WhoopTheme.strainBlue, size: 28),
            title: const Text('TEAM TRIATHLON ITALIA', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('24 Atleti attivi | Codice: COMM-8842'),
            trailing: const Icon(Icons.chevron_right, color: WhoopTheme.textMuted),
          ),
        ),
        Card(
          color: WhoopTheme.cardSurface,
          child: ListTile(
            leading: const Icon(Icons.fitness_center, color: WhoopTheme.recoveryGreen, size: 28),
            title: const Text('CROSSFIT COMMUNITY', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('18 Atleti attivi | Codice: CF-WHOOP-99'),
            trailing: const Icon(Icons.chevron_right, color: WhoopTheme.textMuted),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add, color: Colors.black),
          label: const Text('CREA O UNISCITI A UN TEAM', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(backgroundColor: WhoopTheme.strainBlue),
        ),
      ],
    );
  }

  Widget _buildGroupChatTab() {
    final messages = [
      {'user': 'Marco R.', 'text': 'Oggi 18.2 di Strain dopo 90km di bici! Voi?', 'time': '14:20'},
      {'user': 'Elena V.', 'text': 'Io 16.8 nel CrossFit. Recupero a 84%!', 'time': '14:22'},
      {'user': 'Gianmarco (Tu)', 'text': 'Recupero all\'88% (Verde) e 17.5 di Strain!', 'time': '14:25'},
    ];

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            physics: const BouncingScrollPhysics(),
            itemCount: messages.length,
            itemBuilder: (context, i) {
              final m = messages[i];
              return Card(
                color: WhoopTheme.cardSurface,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(m['user']!, style: const TextStyle(color: WhoopTheme.strainBlue, fontWeight: FontWeight.bold, fontSize: 12)),
                  subtitle: Text(m['text']!, style: const TextStyle(color: WhoopTheme.textPrimary, fontSize: 13)),
                  trailing: Text(m['time']!, style: const TextStyle(color: WhoopTheme.textMuted, fontSize: 10)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
