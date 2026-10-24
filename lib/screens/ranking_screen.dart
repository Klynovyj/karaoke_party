import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';

class RankingScreen extends ConsumerWidget {
  const RankingScreen({super.key});

  static const _medals = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ranking = ref.watch(rankingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rangliste'),
        actions: [
          IconButton(icon: const Icon(Icons.home), onPressed: () => context.go('/')),
        ],
      ),
      body: ranking.isEmpty
          ? const Center(child: Text('Noch keine Ergebnisse'))
          : ListView.builder(
              itemCount: ranking.length,
              itemBuilder: (context, i) {
                final e = ranking[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: e.player.color,
                    child: Text(i < 3 ? _medals[i] : '${i + 1}'),
                  ),
                  title: Text(e.player.name),
                  subtitle: Text('${e.songs} Songs · Bester: ${e.best}'),
                  trailing: Text('${e.total}',
                      style: Theme.of(context).textTheme.titleLarge),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/search'),
        icon: const Icon(Icons.skip_next),
        label: const Text('Weiter singen'),
      ),
    );
  }
}
