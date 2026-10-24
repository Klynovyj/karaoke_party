import 'package:flutter/material.dart';

/// Ein Teilnehmer des Karaoke-Abends.
class Player {
  final String id;
  final String name;
  final int colorValue;

  const Player({
    required this.id,
    required this.name,
    required this.colorValue,
  });

  Color get color => Color(colorValue);
}
