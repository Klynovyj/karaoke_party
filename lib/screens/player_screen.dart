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
  bool? _micGranted;
  PitchSample? _last;

  /// Letzte erkannte Frequenzen (null = Stille) für die Live-Kurve.
  final List<double?> _history = [];

  /// Alle Samples dieser Runde – Grundlage für die Bewertung ab M3.
  final List<PitchSample> _collected = [];

  @override
  void initState() {
    super.initState();
    if (_supportsVideo) {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: widget.args.song.youtubeId,
        autoPlay: true,
        params: const YoutubePlayerParams(showFullscreenButton: true),
      );
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
    setState(() {
      _last = s;
      _history.add(s.hasPitch ? s.frequencyHz : null);
      if (_history.length > 90) _history.removeAt(0);
    });
  }

  @override
  void dispose() {
    _sampleSub?.cancel();
    _analyzer.dispose();
    _controller?.close();
    super.dispose();
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
    if (!mounted) return;
    context.pushReplacement('/result', extra: perf);
  }

  @override
  Widget build(BuildContext context) {
    final singer = widget.args.singer;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.args.song.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
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
            child: SizedBox(
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoArea(BuildContext context) {
    final controller = _controller;
    if (_supportsVideo && controller != null) {
      return YoutubePlayer(controller: controller, aspectRatio: 16 / 9);
    }
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.desktop_windows, size: 40),
                SizedBox(height: 8),
                Text(
                  'Video-Wiedergabe nur auf Android/iOS.\n'
                  'Der Mikrofon-Test läuft hier trotzdem.',
                  textAlign: TextAlign.center,
                ),
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
            OutlinedButton(onPressed: _initMic, child: const Text('Erneut anfragen')),
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
    // RMS ist klein – für die Anzeige etwas verstärken.
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
    final t = ((log(f) - log(_minHz)) / (log(_maxHz) - log(_minHz))).clamp(0.0, 1.0);
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
