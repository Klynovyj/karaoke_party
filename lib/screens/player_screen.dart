import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../providers.dart';
import '../router.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final PlayArgs args;
  const PlayerScreen({super.key, required this.args});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final YoutubePlayerController _controller;
  bool _scoring = false;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.args.song.youtubeId,
      autoPlay: true,
      params: const YoutubePlayerParams(showFullscreenButton: true),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() => _scoring = true);
    await _controller.pauseVideo();
    final result = await ref.read(scoringServiceProvider).analyze();
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
          YoutubePlayer(controller: _controller, aspectRatio: 16 / 9),
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
          const Spacer(),
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
}
