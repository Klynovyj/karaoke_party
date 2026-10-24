import 'dart:math';

const _noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

/// Wandelt eine Frequenz (Hz) in einen Notennamen wie "A4" um.
/// Gibt "–" zurück, wenn keine gültige Tonhöhe vorliegt.
String noteNameFromHz(double? freq) {
  if (freq == null || freq <= 0) return '–';
  final midi = (69 + 12 * (log(freq / 440.0) / ln2)).round();
  if (midi < 0 || midi > 127) return '–';
  final name = _noteNames[midi % 12];
  final octave = (midi ~/ 12) - 1;
  return '$name$octave';
}

/// Note + Abweichung in Cent (-50..+50) zur nächsten echten Note.
/// Für die Stimmgerät-Anzeige: zeigt, ob der Ton sauber / zu tief / zu hoch ist.
({String note, int cents})? pitchReading(double? freq) {
  if (freq == null || freq <= 0) return null;
  final midi = 69 + 12 * (log(freq / 440.0) / ln2);
  final nearest = midi.round();
  if (nearest < 0 || nearest > 127) return null;
  final cents = ((midi - nearest) * 100).round();
  final name = _noteNames[nearest % 12];
  final octave = (nearest ~/ 12) - 1;
  return (note: '$name$octave', cents: cents);
}
