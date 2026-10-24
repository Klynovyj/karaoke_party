import 'dart:math';

/// Ergebnis einer Gesangs-Analyse. Teilwerte 0..1, Gesamt-Score 0..100.
class ScoreResult {
  final int score;
  final double mitsingAnteil;
  final double tonstabilitaet;
  final double klarheit;

  const ScoreResult({
    required this.score,
    required this.mitsingAnteil,
    required this.tonstabilitaet,
    required this.klarheit,
  });
}

/// Abstrakte Bewertung. In M2/M3 ersetzt durch echte Mikrofon-/Pitch-Heuristik.
abstract class ScoringService {
  Future<ScoreResult> analyze();
}

/// Platzhalter fürs Gerüst (M1): liefert einen zufälligen Demo-Score,
/// damit der Party-Flow und die Rangliste bereits durchspielbar sind.
class DemoScoringService implements ScoringService {
  final Random _rng = Random();

  @override
  Future<ScoreResult> analyze() async {
    double between(double min, double max) => min + _rng.nextDouble() * (max - min);
    final mitsing = between(0.5, 1.0);
    final ton = between(0.4, 0.95);
    final klar = between(0.4, 0.95);
    final score = ((mitsing * 0.4 + ton * 0.35 + klar * 0.25) * 100).round();
    return ScoreResult(
      score: score,
      mitsingAnteil: mitsing,
      tonstabilitaet: ton,
      klarheit: klar,
    );
  }
}
