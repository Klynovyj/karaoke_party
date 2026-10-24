import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../core/pitch_util.dart';
import '../providers.dart';
import '../router.dart';
import '../services/audio_analyzer.dart';
import '../services/stage_server.dart';
import '../widgets/brand.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final PlayArgs args;
  const PlayerScreen({super.key, required this.args});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  YoutubePlayerController? _controller;
  final AudioAnalyzer _analyzer = AudioAnalyzer();

  /// WebView-Player gibt es nur auf Android/iOS. Auf Desktop zeigen wir einen
  /// Platzhalter, der Mikrofon-Teil (M2) läuft aber trotzdem.
  final bool _supportsVideo = Platform.isAndroid || Platform.isIOS;

  StreamSubscription<PitchSample>? _sampleSub;
  StreamSubscription? _framesSub;
  bool _scoring = false;
  bool _stage = false; // lokaler Bühnen-Modus (für Mirroring)
  bool? _micGranted;
  String? _micMessage;
  PitchSample? _last;

  late final StageServer _stageServer;
  bool _streaming = false; // TV-Streaming (LAN) aktiv?
  bool _finishedWithResult = false;

  final List<double?> _history = [];
  final List<PitchSample> _collected = [];

  @override
  void initState() {
    super.initState();
    _stageServer = ref.read(stageServerProvider);
    _streaming = _stageServer.isRunning;
    // Beim TV-Streaming läuft das Video auf dem TV – lokal kein zweiter Ton.
    if (_supportsVideo && !_streaming) {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: widget.args.song.youtubeId,
        autoPlay: true,
        params: const YoutubePlayerParams(showFullscreenButton: true),
      );
    }
    if (_streaming) {
      _stageServer.setVideo(widget.args.song.youtubeId, widget.args.singer.name);
      _pushScoreboard();
    }
    _initMic();
  }

  Future<void> _initMic() async {
    bool granted = false;
    try {
      granted = await _analyzer.hasPermission();
    } catch (_) {
      granted = false;
    }
    if (!mounted) return;
    setState(() {
      _micGranted = granted;
      _micMessage = granted
          ? null
          : 'Mikrofon-Berechtigung nötig, um den Gesang zu erfassen.';
    });
    if (!granted) return;
    try {
      await _analyzer.start();
      _sampleSub = _analyzer.samples.listen(_onSample);
      _framesSub = _analyzer.frames.listen((frame) {
        if (_streaming && ref.read(paEnabledProvider)) {
          _stageServer.sendAudio(frame);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _micGranted = false;
        _micMessage = 'Kein Mikrofon gefunden – ohne Aufnahmegerät gibt es keine Bewertung.';
      });
    }
  }

  void _onSample(PitchSample s) {
    if (!mounted) return;
    _collected.add(s);
    if (_streaming) {
      _stageServer.setPitch(
        note: noteNameFromHz(s.frequencyHz),
        freq: s.frequencyHz,
        level: (s.level * 4).clamp(0.0, 1.0),
      );
    }
    setState(() {
      _last = s;
      _history.add(s.hasPitch ? s.frequencyHz : null);
      if (_history.length > 90) _history.removeAt(0);
    });
  }

  @override
  void dispose() {
    if (_streaming && !_finishedWithResult) _stageServer.setIdle();
    _restoreSystemUi();
    _sampleSub?.cancel();
    _framesSub?.cancel();
    _analyzer.dispose();
    _controller?.close();
    super.dispose();
  }

  void _enterStage() {
    setState(() => _stage = true);
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _exitStage() {
    setState(() => _stage = false);
    _restoreSystemUi();
  }

  void _restoreSystemUi() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _pushScoreboard() {
    final ranking = ref.read(rankingProvider);
    _stageServer.setScoreboard([
      for (final r in ranking)
        {
          'name': r.player.name,
          'color':
              '#${(r.player.colorValue & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
          'total': r.total,
        }
    ]);
  }

  Future<void> _finish() async {
    setState(() => _scoring = true);
    await _analyzer.stop();
    await _controller?.pauseVideo();
    final result = ref.read(scoringServiceProvider).analyze(_collected);
    final perf = ref.read(sessionProvider.notifier).recordPerformance(
          playerId: widget.args.singer.id,
          song: widget.args.song,
          result: result,
        );
    if (_streaming) {
      _pushScoreboard();
      _stageServer.setResult(
        singer: widget.args.singer.name,
        song: widget.args.song.title,
        score: result.score,
        mitsing: result.mitsingAnteil,
        ton: result.tonstabilitaet,
        klar: result.klarheit,
      );
      _finishedWithResult = true;
    }
    if (!mounted) return;
    context.pushReplacement('/result', extra: perf);
  }

  @override
  Widget build(BuildContext context) {
    return _stage ? _buildStage(context) : _buildNormal(context);
  }

  // --- Normaler Modus -------------------------------------------------------

  Widget _buildNormal(BuildContext context) {
    final singer = widget.args.singer;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.args.song.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Bühnen-Modus (für TV)',
            icon: const Icon(Icons.fullscreen),
            onPressed: _enterStage,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildVideoArea(context),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: singer.color,
                  child: Text(singer.name[0].toUpperCase()),
                ),
                const SizedBox(width: 12),
                Text('Jetzt singt: ${singer.name}',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          Expanded(child: _buildMicSection()),
          Padding(
            padding: const EdgeInsets.all(24),
            child: _finishButton(),
          ),
        ],
      ),
    );
  }

  // --- Bühnen-/TV-Modus -----------------------------------------------------

  Widget _buildStage(BuildContext context) {
    final theme = Theme.of(context);
    final singer = widget.args.singer;
    final freq = _last?.frequencyHz;
    final note = noteNameFromHz(freq);
    final level = ((_last?.level ?? 0) * 4).clamp(0.0, 1.0);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Video + Tonhöhe links (groß fürs TV)
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                    child: Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _stageMedia(context),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(note,
                                style: theme.textTheme.displaySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(width: 12),
                            Text(
                                freq == null
                                    ? ''
                                    : '${freq.toStringAsFixed(0)} Hz',
                                style: theme.textTheme.titleMedium),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                    value: level, minHeight: 14),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Sänger + Scoreboard rechts
                Expanded(
                  flex: 2,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(8, 16, 16, 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('singt gerade',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.6))),
                        const SizedBox(height: 2),
                        GradientText(
                          singer.name,
                          style: theme.textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 16),
                        Expanded(child: _buildScoreboard(context)),
                        const SizedBox(height: 8),
                        _finishButton(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: 'Bühnen-Modus beenden',
                icon: const Icon(Icons.fullscreen_exit),
                onPressed: _exitStage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stageMedia(BuildContext context) {
    final controller = _controller;
    if (!_streaming && _supportsVideo && controller != null) {
      return YoutubePlayer(controller: controller, aspectRatio: 16 / 9);
    }
    return _videoPlaceholder(
      Theme.of(context),
      _streaming ? Icons.cast_connected : Icons.desktop_windows,
      _streaming
          ? 'Läuft auf dem TV 📺'
          : 'Video-Wiedergabe nur auf Android/iOS.',
    );
  }

  Widget _buildScoreboard(BuildContext context) {
    final ranking = ref.watch(rankingProvider);
    final theme = Theme.of(context);
    if (ranking.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Punktestand', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: ranking
                .take(6)
                .map((r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          CircleAvatar(radius: 9, backgroundColor: r.player.color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(r.player.name,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          Text('${r.total}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  // --- Gemeinsame Bausteine -------------------------------------------------

  Widget _finishButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _scoring ? null : _finish,
        icon: _scoring
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.check),
        label: Text(_scoring ? 'Bewerte…' : 'Fertig & bewerten'),
      ),
    );
  }

  Widget _buildVideoArea(BuildContext context) {
    final theme = Theme.of(context);
    // Video-Höhe begrenzen, sonst überläuft die Spalte auf breiten Fenstern.
    final maxH = MediaQuery.sizeOf(context).height * 0.42;
    Widget media;
    if (_streaming) {
      media = _videoPlaceholder(theme, Icons.cast_connected,
          'Läuft auf dem TV 📺\nSing ins Mikrofon.');
    } else {
      final controller = _controller;
      media = (_supportsVideo && controller != null)
          ? YoutubePlayer(controller: controller, aspectRatio: 16 / 9)
          : _videoPlaceholder(theme, Icons.desktop_windows,
              'Video-Wiedergabe nur auf Android/iOS.\nDer Mikrofon-Test läuft hier trotzdem.');
    }
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: media,
      ),
    );
  }

  Widget _videoPlaceholder(ThemeData theme, IconData icon, String text) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.white.withValues(alpha: 0.05),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 40, color: theme.colorScheme.primary),
                const SizedBox(height: 8),
                Text(text, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMicSection() {
    if (_micGranted == false) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mic_off, size: 48),
            const SizedBox(height: 12),
            Text(_micMessage ?? 'Mikrofon nicht verfügbar.',
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: _initMic, child: const Text('Erneut versuchen')),
          ],
        ),
      );
    }
    if (_micGranted == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return _PitchPanel(last: _last, history: _history);
  }
}

/// Live-Anzeige: aktueller Ton, Pegel und eine kleine Tonhöhen-Kurve.
class _PitchPanel extends StatelessWidget {
  final PitchSample? last;
  final List<double?> history;
  const _PitchPanel({required this.last, required this.history});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final freq = last?.frequencyHz;
    final note = noteNameFromHz(freq);
    final level = ((last?.level ?? 0) * 4).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 110,
                child: Text(note,
                    style: theme.textTheme.displaySmall
                        ?.copyWith(color: theme.colorScheme.primary)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(freq == null ? '— Hz' : '${freq.toStringAsFixed(1)} Hz'),
                    const SizedBox(height: 4),
                    Text(
                      'Konfidenz: ${((last?.probability ?? 0) * 100).round()}%',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.mic, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(value: level, minHeight: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: CustomPaint(
              painter: _PitchSparkline(
                history: history,
                color: theme.colorScheme.primary,
              ),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PitchSparkline extends CustomPainter {
  final List<double?> history;
  final Color color;
  const _PitchSparkline({required this.history, required this.color});

  static const _minHz = 80.0;
  static const _maxHz = 1000.0;

  double? _y(double? f, double h) {
    if (f == null || f <= 0) return null;
    final t =
        ((log(f) - log(_minHz)) / (log(_maxHz) - log(_minHz))).clamp(0.0, 1.0);
    return h - t * h; // höhere Töne weiter oben
  }

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(0, size.height), Offset(size.width, size.height), baseline);

    if (history.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dx = size.width / (history.length - 1);
    Path? path;
    for (var i = 0; i < history.length; i++) {
      final y = _y(history[i], size.height);
      if (y == null) {
        path = null; // Lücke bei Stille
        continue;
      }
      final p = Offset(i * dx, y);
      if (path == null) {
        path = Path()..moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
      if (i == history.length - 1 || _y(history[i + 1], size.height) == null) {
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PitchSparkline old) => true;
}
