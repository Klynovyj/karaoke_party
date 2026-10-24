import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'models/game_session.dart';
import 'models/performance.dart';
import 'models/player.dart';
import 'models/song.dart';
import 'services/persistence_service.dart';
import 'services/scoring_service.dart';
import 'services/youtube_service.dart';

const _uuid = Uuid();

// --- Services ---------------------------------------------------------------

final youtubeServiceProvider = Provider<YoutubeService>((ref) => YoutubeService());

final scoringServiceProvider =
    Provider<ScoringService>((ref) => HeuristicScoringService());

/// Wird in main() mit der von der Festplatte geladenen Instanz überschrieben.
final persistenceProvider = Provider<PersistenceService>((ref) => PersistenceService());

// --- Spieler (global über Abende hinweg) ------------------------------------

const _avatarColors = <int>[
  0xFFEF5350, 0xFF42A5F5, 0xFF66BB6A, 0xFFFFCA28,
  0xFFAB47BC, 0xFFFF7043, 0xFF26C6DA, 0xFFEC407A,
];

class PlayersNotifier extends Notifier<List<Player>> {
  @override
  List<Player> build() => List.of(ref.read(persistenceProvider).players);

  void add(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final color = _avatarColors[state.length % _avatarColors.length];
    state = [...state, Player(id: _uuid.v4(), name: trimmed, colorValue: color)];
    _save();
  }

  void remove(String id) {
    state = state.where((p) => p.id != id).toList();
    _save();
  }

  void _save() => ref.read(persistenceProvider).setPlayers(state);
}

final playersProvider =
    NotifierProvider<PlayersNotifier, List<Player>>(PlayersNotifier.new);

// --- Aktueller Abend --------------------------------------------------------

class SessionNotifier extends Notifier<GameSession?> {
  @override
  GameSession? build() => null;

  void start(List<Player> players) {
    state = GameSession(
      id: _uuid.v4(),
      startedAt: DateTime.now(),
      players: List.of(players),
      performances: const [],
      currentSingerId: players.isNotEmpty ? players.first.id : null,
    );
  }

  void setSinger(String playerId) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(currentSingerId: playerId);
  }

  /// Speichert eine Runde und rotiert zum nächsten Sänger.
  Performance recordPerformance({
    required String playerId,
    required Song song,
    required ScoreResult result,
  }) {
    final perf = Performance(
      id: _uuid.v4(),
      playerId: playerId,
      song: song,
      score: result.score,
      mitsingAnteil: result.mitsingAnteil,
      tonstabilitaet: result.tonstabilitaet,
      klarheit: result.klarheit,
      timestamp: DateTime.now(),
    );
    final s = state;
    if (s != null) {
      final idx = s.players.indexWhere((p) => p.id == playerId);
      final nextSinger =
          s.players.isEmpty ? null : s.players[(idx + 1) % s.players.length].id;
      state = s.copyWith(
        performances: [...s.performances, perf],
        currentSingerId: nextSinger,
      );
    }
    return perf;
  }

  /// Beendet den Abend und archiviert ihn (wenn gesungen wurde) im Verlauf.
  void end() {
    final s = state;
    if (s != null && s.performances.isNotEmpty) {
      ref.read(persistenceProvider).addSession(s);
      ref.read(historyProvider.notifier).reload();
    }
    state = null;
  }
}

final sessionProvider =
    NotifierProvider<SessionNotifier, GameSession?>(SessionNotifier.new);

// --- Rangliste --------------------------------------------------------------

class RankEntry {
  final Player player;
  final int total;
  final int songs;
  final int best;
  const RankEntry({
    required this.player,
    required this.total,
    required this.songs,
    required this.best,
  });
}

List<RankEntry> rankSession(GameSession s) {
  final entries = s.players.map((p) {
    final perfs = s.performances.where((e) => e.playerId == p.id).toList();
    final total = perfs.fold<int>(0, (a, b) => a + b.score);
    final best = perfs.isEmpty ? 0 : perfs.map((e) => e.score).reduce(max);
    return RankEntry(player: p, total: total, songs: perfs.length, best: best);
  }).toList();
  entries.sort((a, b) => b.total.compareTo(a.total));
  return entries;
}

final rankingProvider = Provider<List<RankEntry>>((ref) {
  final s = ref.watch(sessionProvider);
  if (s == null) return const [];
  return rankSession(s);
});

// --- Verlauf ----------------------------------------------------------------

class HistoryNotifier extends Notifier<List<GameSession>> {
  @override
  List<GameSession> build() => List.of(ref.read(persistenceProvider).history);

  void reload() => state = List.of(ref.read(persistenceProvider).history);
}

final historyProvider =
    NotifierProvider<HistoryNotifier, List<GameSession>>(HistoryNotifier.new);

// --- Highscores -------------------------------------------------------------

class HighscoreEntry {
  final Performance performance;
  final Player? player;
  const HighscoreEntry({required this.performance, this.player});
}

final highscoresProvider = Provider<List<HighscoreEntry>>((ref) {
  final history = ref.watch(historyProvider);
  final entries = <HighscoreEntry>[];
  for (final s in history) {
    for (final p in s.performances) {
      final found = s.players.where((x) => x.id == p.playerId).toList();
      entries.add(HighscoreEntry(
        performance: p,
        player: found.isEmpty ? null : found.first,
      ));
    }
  }
  entries.sort((a, b) => b.performance.score.compareTo(a.performance.score));
  return entries.take(20).toList();
});

// --- Suche ------------------------------------------------------------------

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String q) => state = q;
}

final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

final searchResultsProvider = FutureProvider<List<Song>>((ref) async {
  final q = ref.watch(searchQueryProvider).trim();
  if (q.isEmpty) return const [];
  return ref.watch(youtubeServiceProvider).search(q);
});
