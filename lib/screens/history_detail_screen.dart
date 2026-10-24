import 'package:flutter/material.dart';

import '../core/format.dart';
import '../models/game_session.dart';
import '../providers.dart';

class HistoryDetailScreen extends StatelessWidget {
  final GameSession session;
  const HistoryDetailScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final ranking = rankSession(session);
    final perfs = [...session.performances]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    String nameOf(String id) {
      final found = session.players.where((p) => p.id == id).toList();
      return found.isEmpty ? '?' : found.first.name;
    }

    return Scaffold(
      appBar: AppBar(title: Text(formatDateTime(session.startedAt))),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Rangliste', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ...ranking.asMap().entries.map((e) {
            final r = e.value;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: r.player.color,
                child: Text('${e.key + 1}'),
              ),
              title: Text(r.player.name),
              subtitle: Text('${r.songs} Songs · Bester: ${r.best}'),
              trailing: Text('${r.total}',
                  style: Theme.of(context).textTheme.titleMedium),
            );
          }),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('Songs', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ...perfs.map((p) => ListTile(
                title: Text(p.song.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(nameOf(p.playerId)),
                trailing: Text('${p.score}'),
              )),
        ],
      ),
    );
  }
}
