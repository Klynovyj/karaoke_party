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
}
