import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config.dart';
import '../providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final players = ref.watch(playersProvider);
    final session = ref.watch(sessionProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('🎤 Karaoke Party')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!AppConfig.hasYoutubeApiKey)
              Card(
                color: theme.colorScheme.errorContainer,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Kein YouTube-API-Key gesetzt.\n'
                    'Start mit: flutter run --dart-define-from-file=dart_define.json',
                  ),
                ),
              ),
            const Spacer(),
            Text('Karaoke Party',
                style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('${players.length} Spieler angelegt',
                textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.push('/players'),
              icon: const Icon(Icons.group),
              label: const Text('Spieler verwalten'),
            ),
            const SizedBox(height: 12),
            if (session == null)
              FilledButton.icon(
                onPressed: players.isEmpty
                    ? null
                    : () {
                        ref.read(sessionProvider.notifier).start(players);
                        context.push('/search');
                      },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Abend starten'),
              )
            else ...[
              FilledButton.icon(
                onPressed: () => context.push('/search'),
                icon: const Icon(Icons.library_music),
                label: const Text('Song wählen'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.push('/ranking'),
                icon: const Icon(Icons.leaderboard),
                label: const Text('Rangliste'),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => ref.read(sessionProvider.notifier).end(),
                icon: const Icon(Icons.stop),
                label: const Text('Abend beenden'),
              ),
            ],
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => context.push('/history'),
              icon: const Icon(Icons.history),
              label: const Text('Verlauf'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/highscores'),
              icon: const Icon(Icons.emoji_events),
              label: const Text('Highscores'),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
