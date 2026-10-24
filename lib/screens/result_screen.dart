import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/performance.dart';
import '../providers.dart';

class ResultScreen extends ConsumerWidget {
  final Performance performance;
  const ResultScreen({super.key, required this.performance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final matches =
        session?.players.where((p) => p.id == performance.playerId).toList() ??
            const [];
    final singer = matches.isEmpty ? null : matches.first;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
          title: const Text('Ergebnis'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            if (singer != null)
              Text(singer.name,
                  textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
            Text(performance.song.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            Text('${performance.score}',
                textAlign: TextAlign.center,
                style: theme.textTheme.displayLarge
                    ?.copyWith(color: theme.colorScheme.primary)),
            const Text('Punkte', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            _Bar(label: 'Mitsing-Anteil', value: performance.mitsingAnteil),
            _Bar(label: 'Tonstabilität', value: performance.tonstabilitaet),
            _Bar(label: 'Klarheit', value: performance.klarheit),
            const SizedBox(height: 16),
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Demo-Score (M1). Die echte Mikrofon-Bewertung kommt in M2/M3.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => context.go('/search'),
              icon: const Icon(Icons.skip_next),
              label: const Text('Nächster Song'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.go('/ranking'),
              icon: const Icon(Icons.leaderboard),
              label: const Text('Rangliste'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final double value;
  const _Bar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text('${(value * 100).round()}%'),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: value.clamp(0, 1), minHeight: 8),
          ),
        ],
      ),
    );
  }
}
