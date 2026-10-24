# 🎤 Karaoke Party

Flutter-Karaoke-App (Android). Karaoke-Videos kommen aus YouTube (offizielles
IFrame-Embed), der Gesang wird **nach jedem Lied bewertet**. Party-Modus:
mehrere Spieler singen abwechselnd, am Ende gibt es eine Rangliste.

## Konzept

- **Songquelle:** YouTube Data API v3 (Suche) + `youtube_player_iframe` (Wiedergabe).
  Es wird gezielt nach „<Song> karaoke"-Videos gesucht.
- **Bewertung (Hybrid):** Start mit referenzloser Heuristik für *alle* Songs
  (Mitsing-Anteil, Tonstabilität, Klarheit aus Mikrofon-Pitch). Später für
  kuratierte Songs echte Melodie-Referenz.
- **Wichtig – Kopfhörer:** Für saubere Scores Kopfhörer nutzen, sonst hört das
  Mikrofon den Backing-Track mit. (Acoustic Echo Cancellation kommt später.)

## Setup

1. YouTube Data API v3 Key besorgen (Google Cloud Console → API aktivieren → Key).
2. `dart_define.example.json` nach `dart_define.json` kopieren und den Key eintragen.
   (`dart_define.json` ist in `.gitignore` und wird **nicht** committet.)
3. Starten:

   ```bash
   flutter run --dart-define-from-file=dart_define.json
   ```

## Architektur

```
lib/
  main.dart            App-Einstieg (ProviderScope)
  app.dart             MaterialApp.router + Theme
  router.dart          go_router-Routen
  core/                config (API-Key), theme
  models/              Player, Song, Performance, GameSession
  services/            YoutubeService, ScoringService (Demo → echte Heuristik)
  providers.dart       Riverpod-State (Spieler, Session, Suche, Rangliste)
  screens/             Home, Spieler, Suche, Player, Ergebnis, Rangliste
```

State: **Riverpod** · Navigation: **go_router** · DSP später im Isolate.

## Roadmap

- [x] **M1 – Gerüst:** Projekt, Navigation, YouTube-Suche + Player, Spieler-Verwaltung,
  Party-Flow mit Demo-Score + Rangliste
- [ ] **M2 – Mic-Pipeline:** PCM-Stream → Pitch-Detection (YIN) im Isolate → Live-Anzeige
- [ ] **M3 – Scoring:** echte Heuristik, Ergebnis nach jedem Lied
- [ ] **M4 – Persistenz:** Abende/Verlauf/Highscores (Isar/Drift)
- [ ] **M5 – Politur:** Kopfhörer-Hinweis, Kalibrierung, Animationen
- [ ] **Später:** Referenz-Phase für kuratierte Songs

> Hinweis: Das Audio aus YouTube zu extrahieren oder Vocals rauszurechnen wäre ein
> Verstoß gegen die YouTube-ToS und ist bewusst nicht Teil der App.
