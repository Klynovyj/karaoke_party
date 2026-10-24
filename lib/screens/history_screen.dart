import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Verlauf')),
      body: history.isEmpty
          ? const Center(child: Text('Noch keine gespeicherten Abende'))
          : ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, i) {
                final s = history[i];
                final ranking = rankSession(s);
                final winner = ranking.isEmpty ? null : ranking.first;
                return ListTile(
                  leading: const Icon(Icons.event),
                  title: Text(formatDateTime(s.startedAt)),
                  subtitle: Text(
                      '${s.players.length} Spieler · ${s.performances.length} Songs'),
                  trailing: winner == null ? null : Text('🏆 ${winner.player.name}'),
                  onTap: () => context.push('/history-detail', extra: s),
                );
              },
            ),
    );
  }
}
