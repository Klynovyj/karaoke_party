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
