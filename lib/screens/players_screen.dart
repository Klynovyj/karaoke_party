import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

class PlayersScreen extends ConsumerStatefulWidget {
  const PlayersScreen({super.key});

  @override
  ConsumerState<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends ConsumerState<PlayersScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    ref.read(playersProvider.notifier).add(_controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final players = ref.watch(playersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Spieler')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(onPressed: _add, child: const Text('Hinzufügen')),
              ],
            ),
          ),
          Expanded(
            child: players.isEmpty
                ? const Center(child: Text('Noch keine Spieler'))
                : ListView.builder(
                    itemCount: players.length,
                    itemBuilder: (context, i) {
                      final p = players[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: p.color,
                          child: Text(p.name[0].toUpperCase()),
                        ),
                        title: Text(p.name),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              ref.read(playersProvider.notifier).remove(p.id),
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
