import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../router.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (session == null || session.players.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Song wählen'),
          actions: [
            IconButton(icon: const Icon(Icons.home), onPressed: () => context.go('/')),
          ],
        ),
        body: const Center(child: Text('Kein aktiver Abend. Bitte zuerst starten.')),
      );
    }

    final singer = session.players.firstWhere(
      (p) => p.id == session.currentSingerId,
      orElse: () => session.players.first,
    );
    final results = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Song wählen'),
        actions: [
          IconButton(icon: const Icon(Icons.home), onPressed: () => context.go('/')),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Wer singt?'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: session.players
                      .map(
                        (p) => ChoiceChip(
                          label: Text(p.name),
                          selected: p.id == singer.id,
                          avatar: CircleAvatar(backgroundColor: p.color, radius: 10),
                          onSelected: (_) =>
                              ref.read(sessionProvider.notifier).setSinger(p.id),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    labelText: 'Song suchen',
                    hintText: 'z.B. Bohemian Rhapsody',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (v) => ref.read(searchQueryProvider.notifier).set(v),
                ),
              ],
            ),
          ),
          Expanded(
            child: results.when(
              data: (songs) {
                if (songs.isEmpty) {
                  return const Center(child: Text('Suche nach einem Karaoke-Song'));
                }
                return ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, i) {
                    final s = songs[i];
                    return ListTile(
                      leading: s.thumbnailUrl.isEmpty
                          ? const Icon(Icons.music_note)
                          : Image.network(s.thumbnailUrl,
                              width: 80, fit: BoxFit.cover),
                      title: Text(s.title,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(s.artist),
                      onTap: () => context.push('/play',
                          extra: PlayArgs(singer: singer, song: s)),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Fehler: $e', textAlign: TextAlign.center),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
