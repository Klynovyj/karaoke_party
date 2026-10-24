import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
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
  bool _scoring = false;
  bool _stage = false; // lokaler Bühnen-Modus (für Mirroring)
  bool? _micGranted;
  PitchSample? _last;

  late final StageServer _stageServer;
  bool _streaming = false; // TV-Streaming (LAN) aktiv?

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
    final granted = await _analyzer.hasPermission();
    if (!mounted) return;
    setState(() => _micGranted = granted);
    if (!granted) return;
    await _analyzer.start();
    _sampleSub = _analyzer.samples.listen(_onSample);
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
    if (_streaming) _stageServer.setIdle();
    _sampleSub?.cancel();
    _analyzer.dispose();
    _controller?.close();
    super.dispose();
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
    if (_streaming) _pushScoreboard();
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
            onPressed: () => setState(() => _stage = true),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Bühnen-Modus beenden',
                  icon: const Icon(Icons.fullscreen_exit),
                  onPressed: () => setState(() => _stage = false),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildVideoArea(context),
              ),
              const SizedBox(height: 16),
              GradientText(
                singer.name,
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(note,
                      style: theme.textTheme.displayMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(width: 16),
                  Text(freq == null ? '' : '${freq.toStringAsFixed(0)} Hz',
                      style: theme.textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: level, minHeight: 12),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 2,
                      child: CustomPaint(
                        painter: _PitchSparkline(
                            history: _history, color: theme.colorScheme.primary),
                        size: Size.infinite,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(flex: 1, child: _buildScoreboard(context)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _finishButton(),
            ],
          ),
        ),
      ),
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
    if (_streaming) {
      return _videoPlaceholder(theme, Icons.cast_connected,
          'Läuft auf dem TV 📺\nSing ins Mikrofon.');
    }
    final controller = _controller;
    if (_supportsVideo && controller != null) {
      return YoutubePlayer(controller: controller, aspectRatio: 16 / 9);
    }
    return _videoPlaceholder(theme, Icons.desktop_windows,
        'Video-Wiedergabe nur auf Android/iOS.\nDer Mikrofon-Test läuft hier trotzdem.');
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
            const Text('Mikrofon-Berechtigung nötig, um den Gesang zu erfassen.',
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: _initMic, child: const Text('Erneut anfragen')),
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
