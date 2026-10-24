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
  List<String> _ips = [];
  String? _ip;

  String? get _url => _ip == null ? null : 'http://$_ip:${_server.port}';

  @override
  void initState() {
    super.initState();
    _server = ref.read(stageServerProvider);
    _sub = _server.changes.listen((_) {
      if (mounted) setState(() {});
    });
    if (_server.isRunning) _refreshIps();
  }

  @override
  void dispose() {
    // Server bewusst NICHT stoppen – er soll beim Singen weiterlaufen.
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _refreshIps() async {
    final ips = await _server.candidateIps();
    if (!mounted) return;
    setState(() {
      _ips = ips;
      if (_ip == null || !ips.contains(_ip)) {
        _ip = ips.isEmpty ? null : ips.first;
      }
    });
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    await _server.start();
    await _refreshIps();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _stop() async {
    setState(() => _busy = true);
    await _server.stop();
    if (mounted) {
      setState(() {
        _ips = [];
        _ip = null;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final running = _server.isRunning;
    final url = _url;

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
                    Text('Handy und TV müssen im selben WLAN sein.',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (running && url != null) ...[
              if (_ips.length > 1) ...[
                Text('Netzwerk-Adresse', style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: _ip,
                  items: [
                    for (final ip in _ips)
                      DropdownMenuItem(value: ip, child: Text(ip)),
                  ],
                  onChanged: (v) => setState(() => _ip = v),
                ),
                const SizedBox(height: 4),
                Text(
                  'Wähle die Adresse deines WLANs (nicht VMware/virtuelle Adapter).',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
              ],
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child:
                      QrImageView(data: url, version: QrVersions.auto, size: 220),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      url,
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Adresse kopieren',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Adresse kopiert')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${_server.clientCount} TV(s) verbunden',
                  textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            ] else if (running && url == null) ...[
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
