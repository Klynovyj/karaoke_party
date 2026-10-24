import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers.dart';
import '../services/stage_server.dart';

class TvStreamScreen extends ConsumerStatefulWidget {
  const TvStreamScreen({super.key});

  @override
  ConsumerState<TvStreamScreen> createState() => _TvStreamScreenState();
}

class _TvStreamScreenState extends ConsumerState<TvStreamScreen> {
  late final StageServer _server;
  StreamSubscription<void>? _sub;
  bool _busy = false;
  String? _url;

  @override
  void initState() {
    super.initState();
    _server = ref.read(stageServerProvider);
    _sub = _server.changes.listen((_) {
      if (mounted) setState(() {});
    });
    if (_server.isRunning) _refreshUrl();
  }

  @override
  void dispose() {
    // Server bewusst NICHT stoppen – er soll beim Singen weiterlaufen.
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _refreshUrl() async {
    final ip = await _server.localIp();
    if (!mounted) return;
    setState(() => _url = ip == null ? null : 'http://$ip:${_server.port}');
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    await _server.start();
    await _refreshUrl();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _stop() async {
    setState(() => _busy = true);
    await _server.stop();
    if (mounted) {
      setState(() {
        _url = null;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final running = _server.isRunning;

    return Scaffold(
      appBar: AppBar(title: const Text('Auf TV streamen')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('So geht\'s', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Streaming starten.\n'
                      '2. Am Fernseher die Adresse im Browser öffnen '
                      '(oder den QR-Code scannen).\n'
                      '3. Song wählen und lossingen – Video, Tonhöhe und '
                      'Punktestand erscheinen auf dem TV.',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Handy und TV müssen im selben WLAN sein.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (running && _url != null) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(data: _url!, version: QrVersions.auto, size: 220),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      _url!,
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Adresse kopieren',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _url!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Adresse kopiert')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${_server.clientCount} TV(s) verbunden',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ] else if (running && _url == null) ...[
              const Text(
                'Keine WLAN-Adresse gefunden. Ist das Gerät mit dem WLAN verbunden?',
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : (running ? _stop : _start),
              icon: Icon(running ? Icons.stop : Icons.cast),
              label: Text(running ? 'Streaming stoppen' : 'Streaming starten'),
            ),
          ],
        ),
      ),
    );
  }
}
