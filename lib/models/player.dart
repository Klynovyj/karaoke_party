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

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'colorValue': colorValue};

  factory Player.fromJson(Map<String, dynamic> j) => Player(
        id: j['id'] as String,
        name: j['name'] as String,
        colorValue: j['colorValue'] as int,
      );
}
