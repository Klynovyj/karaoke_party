import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/game_session.dart';
import '../models/player.dart';

/// Einfache JSON-Datei-Persistenz für Spieler-Liste und vergangene Abende.
/// Bewusst ohne Codegen/native DB – läuft auf Android und Windows gleichermaßen.
class PersistenceService {
  List<Player> players = [];
  List<GameSession> history = [];
  File? _file;

  /// Lädt den gespeicherten Zustand (einmalig in main() aufrufen).
  Future<void> init() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _file = File('${dir.path}/karaoke_party_data.json');
      if (await _file!.exists()) {
        final map = jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;
        players = ((map['players'] as List?) ?? const [])
            .map((e) => Player.fromJson(e as Map<String, dynamic>))
            .toList();
        history = ((map['history'] as List?) ?? const [])
            .map((e) => GameSession.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Bei Lese-/Parse-Fehlern mit leerem Zustand starten.
      players = [];
      history = [];
    }
  }

  Future<void> setPlayers(List<Player> p) async {
    players = List.of(p);
    await _persist();
  }

  Future<void> addSession(GameSession s) async {
    history = [s, ...history];
    await _persist();
  }

  Future<void> _persist() async {
    final f = _file;
    if (f == null) return;
    try {
      await f.writeAsString(jsonEncode({
        'players': players.map((e) => e.toJson()).toList(),
        'history': history.map((e) => e.toJson()).toList(),
      }));
    } catch (_) {
      // Schreibfehler ignorieren – der In-Memory-Zustand bleibt gültig.
    }
  }
}
