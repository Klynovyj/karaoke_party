import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'models/game_session.dart';
import 'models/performance.dart';
import 'models/player.dart';
import 'models/song.dart';
import 'services/scoring_service.dart';
import 'services/youtube_service.dart';

const _uuid = Uuid();

// --- Services ---------------------------------------------------------------

final youtubeServiceProvider = Provider<YoutubeService>((ref) => YoutubeService());

final scoringServiceProvider = Provider<ScoringService>((ref) => DemoScoringService());

// --- Spieler (global über Abende hinweg) ------------------------------------

const _avatarColors = <int>[
  0xFFEF5350, 0xFF42A5F5, 0xFF66BB6A, 0xFFFFCA28,
  0xFFAB47BC, 0xFFFF7043, 0xFF26C6DA, 0xFFEC407A,
];

class PlayersNotifier extends Notifier<List<Player>> {
  @override
  List<Player> build() => const [];

  void add(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final color = _avatarColors[state.length % _avatarColors.length];
    state = [...state, Player(id: _uuid.v4(), name: trimmed, colorValue: color)];
  }

  void remove(String id) => state = state.where((p) => p.id != id).toList();
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

  void end() => state = null;
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

final rankingProvider = Provider<List<RankEntry>>((ref) {
  final s = ref.watch(sessionProvider);
  if (s == null) return const [];
  final entries = s.players.map((p) {
    final perfs = s.performances.where((e) => e.playerId == p.id).toList();
    final total = perfs.fold<int>(0, (a, b) => a + b.score);
    final best = perfs.isEmpty ? 0 : perfs.map((e) => e.score).reduce(max);
    return RankEntry(player: p, total: total, songs: perfs.length, best: best);
  }).toList();
  entries.sort((a, b) => b.total.compareTo(a.total));
  return entries;
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
