import 'package:flutter/material.dart';

import '../models/player_score.dart';
import '../services/auth_service.dart';
import '../services/score_service.dart';

/// La « table des scores » : le classement des joueurs, avec un onglet pour
/// le général (carrière) et un onglet pour le défi du jour.
class LeaderboardPage extends StatefulWidget {
  final AuthService auth;
  final ScoreService scores;

  const LeaderboardPage({super.key, required this.auth, required this.scores});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  Leaderboard _selected = Leaderboard.all;

  @override
  Widget build(BuildContext context) {
    if (!widget.scores.isEnabled) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Classement'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        backgroundColor: Colors.black,
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Connecte-toi avec un compte Google pour apparaître dans le classement des joueurs.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Classement'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          _ModeTabs(
            selected: _selected,
            onChanged: (mode) => setState(() => _selected = mode),
          ),
          Expanded(
            child: StreamBuilder<List<PlayerScore>>(
              stream: widget.scores.watchLeaderboard(_selected),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Impossible de charger le classement. Vérifie ta connexion internet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final players = snapshot.data ?? const <PlayerScore>[];
                if (players.isEmpty) {
                  return Center(
                    child: Text(
                      _selected.emptyMessage,
                      style: const TextStyle(color: Colors.white54),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    // Stream Firestore : se refreshing suffit à redemander.
                    await Future<void>.delayed(const Duration(milliseconds: 300));
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      final player = players[index];
                      final isMe = player.uid == widget.auth.uid;
                      return _PlayerTile(
                        rank: index + 1,
                        player: player,
                        chambers: _selected == Leaderboard.all
                            ? player.bestChambers
                            : player.dailyChambersForToday,
                        isMe: isMe,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeTabs extends StatelessWidget {
  final Leaderboard selected;
  final ValueChanged<Leaderboard> onChanged;

  const _ModeTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: SegmentedButton<Leaderboard>(
        segments: const [
          ButtonSegment(
            value: Leaderboard.all,
            label: Text('Général'),
            icon: Icon(Icons.emoji_events),
          ),
          ButtonSegment(
            value: Leaderboard.daily,
            label: Text('Défi du jour'),
            icon: Icon(Icons.calendar_today),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (values) => onChanged(values.first),
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.cyanAccent
                : Colors.white10,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.black
                : Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final int rank;
  final PlayerScore player;
  final int chambers;
  final bool isMe;

  const _PlayerTile({
    required this.rank,
    required this.player,
    required this.chambers,
    required this.isMe,
  });

  Color get _rankColor {
    switch (rank) {
      case 1:
        return Colors.amberAccent;
      case 2:
        return Colors.white70;
      case 3:
        return Colors.orangeAccent;
      default:
        return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isMe ? Colors.cyanAccent.withOpacity(0.12) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$rank',
              style: TextStyle(
                color: _rankColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          CircleAvatar(
            radius: 18,
            backgroundImage:
                player.photoUrl != null ? NetworkImage(player.photoUrl!) : null,
            child: player.photoUrl != null
                ? null
                : Text(
                    player.displayName.characters.first.toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '${player.displayName} (vous)' : player.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isMe ? Colors.cyanAccent : Colors.white,
                    fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Text(
                  'Chambre $chambers',
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
