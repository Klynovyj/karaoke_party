import 'performance.dart';
import 'player.dart';

/// Ein laufender Karaoke-Abend: Teilnehmer, gesungene Runden und wer gerade dran ist.
class GameSession {
  final String id;
  final DateTime startedAt;
  final List<Player> players;
  final List<Performance> performances;
  final String? currentSingerId;

  const GameSession({
    required this.id,
    required this.startedAt,
    required this.players,
    required this.performances,
    this.currentSingerId,
  });

  GameSession copyWith({
    List<Player>? players,
    List<Performance>? performances,
    String? currentSingerId,
  }) {
    return GameSession(
      id: id,
      startedAt: startedAt,
      players: players ?? this.players,
      performances: performances ?? this.performances,
      currentSingerId: currentSingerId ?? this.currentSingerId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'players': players.map((e) => e.toJson()).toList(),
        'performances': performances.map((e) => e.toJson()).toList(),
        'currentSingerId': currentSingerId,
      };

  factory GameSession.fromJson(Map<String, dynamic> j) => GameSession(
        id: j['id'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String),
        players: (j['players'] as List)
            .map((e) => Player.fromJson(e as Map<String, dynamic>))
            .toList(),
        performances: (j['performances'] as List)
            .map((e) => Performance.fromJson(e as Map<String, dynamic>))
            .toList(),
        currentSingerId: j['currentSingerId'] as String?,
      );
}
