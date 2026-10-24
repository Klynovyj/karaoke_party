import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../services/tv_discovery.dart';
import '../widgets/brand.dart';
import '../widgets/update_prompt.dart';

/// Läuft auf dem Android-TV (waipu-Stick): sucht das Handy automatisch im WLAN
/// und zeigt die Bühnenseite im Vollbild-WebView.
class TvStageScreen extends StatefulWidget {
  const TvStageScreen({super.key});

  @override
  State<TvStageScreen> createState() => _TvStageScreenState();
}

class _TvStageScreenState extends State<TvStageScreen> {
  final TvDiscovery _discovery = TvDiscovery();
  WebViewController? _controller;
  bool _searching = true;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // TV-Bildschirm wachhalten
    _start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybePromptUpdate(context);
    });
  }

  Future<void> _start() async {
    setState(() {
      _searching = true;
      _notFound = false;
    });
    final url = await _discovery.find();
    if (!mounted) return;
    if (url == null) {
      setState(() {
        _searching = false;
        _notFound = true;
      });
      return;
    }
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0E0B14));
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
    }
    controller.loadRequest(Uri.parse(url));
    setState(() {
      _controller = controller;
      _searching = false;
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _discovery.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller != null) {
      return Scaffold(body: WebViewWidget(controller: controller));
    }
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLogo(size: 140),
            const SizedBox(height: 24),
            if (_searching) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Suche Handy im WLAN…'),
            ] else if (_notFound) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Kein Handy gefunden.\n'
                  'Starte am Handy „Auf TV streamen" und versuche es erneut.',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: _start, child: const Text('Erneut suchen')),
            ],
          ],
        ),
      ),
    );
  }
}
