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

  Map<String, dynamic> toJson() => {
        'id': id,
        'playerId': playerId,
        'song': song.toJson(),
        'score': score,
        'mitsingAnteil': mitsingAnteil,
        'tonstabilitaet': tonstabilitaet,
        'klarheit': klarheit,
        'timestamp': timestamp.toIso8601String(),
      };

  factory Performance.fromJson(Map<String, dynamic> j) => Performance(
        id: j['id'] as String,
        playerId: j['playerId'] as String,
        song: Song.fromJson(j['song'] as Map<String, dynamic>),
        score: j['score'] as int,
        mitsingAnteil: (j['mitsingAnteil'] as num).toDouble(),
        tonstabilitaet: (j['tonstabilitaet'] as num).toDouble(),
        klarheit: (j['klarheit'] as num).toDouble(),
        timestamp: DateTime.parse(j['timestamp'] as String),
      );
}
