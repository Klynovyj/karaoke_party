import 'song.dart';

/// Eine gesungene Runde eines Spielers inkl. Bewertung.
class Performance {
  final String id;
  final String playerId;
  final Song song;

  /// Gesamt-Score 0..100.
  final int score;

  /// Teilwerte der Heuristik, jeweils 0..1.
  final double mitsingAnteil;
  final double tonstabilitaet;
  final double klarheit;

  final DateTime timestamp;

  const Performance({
    required this.id,
    required this.playerId,
    required this.song,
    required this.score,
    required this.mitsingAnteil,
    required this.tonstabilitaet,
    required this.klarheit,
    required this.timestamp,
  });
}
