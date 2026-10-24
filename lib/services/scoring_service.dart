import 'dart:math';

import 'audio_analyzer.dart';

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

/// Bewertet eine Runde anhand der während des Songs gesammelten [PitchSample]s.
abstract class ScoringService {
  ScoreResult analyze(List<PitchSample> samples);
}

/// Referenzlose Heuristik (M3): bewertet den Gesang ohne Melodie-Vorlage anhand
/// von Mitsing-Anteil, Tonstabilität und Klarheit. Gewichtung 40/35/25.
class HeuristicScoringService implements ScoringService {
  /// RMS-Schwelle, ab der ein Fenster als "es wird gesungen" zählt.
  static const double _voiceLevel = 0.02;

  /// Durchschnittlicher Halbton-Sprung zwischen Fenstern, ab dem die Tonhöhe
  /// als komplett unstabil gilt (→ 0 Punkte in dieser Kategorie).
  static const double _maxSemitoneJump = 1.5;

  /// Aktiv-Anteil, ab dem es die volle Mitsing-Punktzahl gibt (Pausen sind normal).
  static const double _mitsingTarget = 0.5;

  @override
  ScoreResult analyze(List<PitchSample> samples) {
    if (samples.isEmpty) {
      return const ScoreResult(
          score: 0, mitsingAnteil: 0, tonstabilitaet: 0, klarheit: 0);
    }

    final total = samples.length;
    final voiced = samples.where((s) => s.level >= _voiceLevel).toList();
    final pitched = voiced.where((s) => s.hasPitch).toList();

    // 1) Mitsing-Anteil: Anteil der Zeit, in der tatsächlich gesungen wurde.
    final activeFraction = voiced.length / total;
    final mitsing = (activeFraction / _mitsingTarget).clamp(0.0, 1.0);

    // 2) Klarheit: durchschnittliche Konfidenz der erkannten Töne.
    final klarheit = pitched.isEmpty
        ? 0.0
        : pitched.map((s) => s.probability).reduce((a, b) => a + b) /
            pitched.length;

    // 3) Tonstabilität: kleine Tonhöhen-Sprünge zwischen direkt
    //    aufeinanderfolgenden (gesungenen) Fenstern → ruhiger, sauberer Ton.
    var sumJump = 0.0;
    var jumpCount = 0;
    for (var i = 1; i < samples.length; i++) {
      final a = samples[i - 1];
      final b = samples[i];
      if (a.hasPitch &&
          b.hasPitch &&
          a.level >= _voiceLevel &&
          b.level >= _voiceLevel) {
        final f1 = a.frequencyHz!;
        final f2 = b.frequencyHz!;
        if (f1 > 0 && f2 > 0) {
          sumJump += (12 * (log(f2 / f1) / ln2)).abs();
          jumpCount++;
        }
      }
    }
    final tonstabilitaet = jumpCount == 0
        ? 0.0
        : (1 - (sumJump / jumpCount) / _maxSemitoneJump).clamp(0.0, 1.0);

    final score =
        ((mitsing * 0.4 + tonstabilitaet * 0.35 + klarheit * 0.25) * 100)
            .round();

    return ScoreResult(
      score: score,
      mitsingAnteil: mitsing,
      tonstabilitaet: tonstabilitaet,
      klarheit: klarheit.clamp(0.0, 1.0),
    );
  }
}
