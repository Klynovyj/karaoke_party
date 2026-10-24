import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

class HighscoresScreen extends ConsumerWidget {
  const HighscoresScreen({super.key});

  static const _medals = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(highscoresProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Highscores')),
      body: entries.isEmpty
          ? const Center(child: Text('Noch keine Highscores'))
          : ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final e = entries[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: e.player?.color,
                    child: Text(i < 3 ? _medals[i] : '${i + 1}'),
                  ),
                  title: Text(e.player?.name ?? 'Unbekannt'),
                  subtitle: Text(e.performance.song.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text('${e.performance.score}',
                      style: Theme.of(context).textTheme.titleLarge),
                );
              },
            ),
    );
  }
}
