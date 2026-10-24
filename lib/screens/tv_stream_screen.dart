import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../providers.dart';
import '../services/stage_server.dart';
import '../services/tv_scanner.dart';

class TvStreamScreen extends ConsumerStatefulWidget {
  const TvStreamScreen({super.key});

  @override
  ConsumerState<TvStreamScreen> createState() => _TvStreamScreenState();
}

class _TvStreamScreenState extends ConsumerState<TvStreamScreen> {
  late final StageServer _server;
  StreamSubscription<void>? _sub;
  TvScanner? _scanner;
  StreamSubscription<List<TvDevice>>? _scanSub;
  List<TvDevice> _tvs = [];
  bool _busy = false;
  List<String> _ips = [];
  String? _ip;

  String? get _url => _ip == null ? null : 'http://$_ip:${_server.port}';

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _server = ref.read(stageServerProvider);
    _sub = _server.changes.listen((_) {
      if (mounted) setState(() {});
    });
    if (_server.isRunning) {
      _refreshIps();
      _startScan();
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    // Server bewusst NICHT stoppen – er soll beim Singen weiterlaufen.
    _sub?.cancel();
    _scanSub?.cancel();
    _scanner?.stop();
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

  void _startScan() {
    _scanSub?.cancel();
    _scanner?.stop();
    final scanner = TvScanner();
    _scanner = scanner;
    _scanSub = scanner.devices.listen((list) {
      if (mounted) setState(() => _tvs = list);
    });
    scanner.start();
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    await _server.start();
    await _refreshIps();
    _startScan();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _stop() async {
    setState(() => _busy = true);
    await _server.stop();
    await _scanner?.stop();
    _scanner = null;
    if (mounted) {
      setState(() {
        _ips = [];
        _ip = null;
        _tvs = [];
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
                      '2. waipu-Stick: Karaoke-Party-App öffnen – er findet das '
                      'Handy automatisch.\n'
                      '3. Oder einen TV mit Browser auf die Adresse öffnen '
                      '(QR scannen).',
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
                      QrImageView(data: url, version: QrVersions.auto, size: 200),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(url,
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center),
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: ref.watch(paEnabledProvider),
                onChanged: (v) => ref.read(paEnabledProvider.notifier).set(v),
                title: const Text('Stimme über TV (PA) – experimentell'),
                subtitle: const Text(
                    'Deine Stimme kommt aus dem TV. Achtung: spürbare Verzögerung '
                    'und Echo-Gefahr – Mikro nah am Mund, TV nicht zu laut.'),
              ),
              _buildTvList(theme),
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

  void _showDeviceInfo(TvDevice d) {
    final n = d.name.toLowerCase();
    final isTv = n.contains('waipu') || n.contains('tv') || n.contains('bravia');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(d.name),
        content: Text(isTv
            ? 'Android-TV-Gerät. So verbindest du es: Installiere die '
                'Karaoke-Party-App auf dem Gerät (z.B. per „Downloader"-App) und '
                'öffne sie dort. Der TV findet das Handy dann automatisch und '
                'zeigt die Bühne – ein direktes Anwählen vom Handy ist bei '
                'Android-TV nicht möglich.'
            : 'Dieses Gerät kann den Karaoke-Stream nicht empfangen (kein '
                'passender Empfänger, z.B. ein Lautsprecher). Es funktionieren '
                'der waipu-Stick (mit App) und TVs mit Browser.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildTvList(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            Text('Gefundene TVs im Netzwerk',
                style: theme.textTheme.titleSmall),
            const SizedBox(width: 8),
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (_tvs.isEmpty)
          Text('Suche läuft…', style: theme.textTheme.bodySmall)
        else
          ..._tvs.map((d) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.tv),
                title: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [d.brand, if (d.address != null) d.address!].join(' · '),
                ),
                trailing: const Icon(Icons.info_outline),
                onTap: () => _showDeviceInfo(d),
              )),
        const SizedBox(height: 4),
        Text(
          'Tippe ein Gerät an für die Verbindungs-Info. Den Stream empfangen '
          'nur der waipu-Stick (mit installierter App) und TVs mit Browser; '
          'Samsung/LG ohne Browser nur per Mirroring.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
