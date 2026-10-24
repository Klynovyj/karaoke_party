import 'dart:async';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:http/http.dart' as http;

import 'stage_server.dart' show kStageServiceType, kStagePingBody;

/// Findet das Handy (Karaoke-Server) im WLAN: zuerst per mDNS, parallel ein
/// Netz-Scan als Fallback, falls der Router Multicast/mDNS blockt.
class TvDiscovery {
  BonsoirDiscovery? _discovery;
  final Completer<String> _completer = Completer<String>();
  bool _stopped = false;

  Future<String?> find({Duration timeout = const Duration(seconds: 15)}) async {
    _mdns();
    _scan();
    try {
      return await _completer.future.timeout(timeout);
    } catch (_) {
      return null;
    } finally {
      await stop();
    }
  }

  void _found(String url) {
    if (!_completer.isCompleted) _completer.complete(url);
  }

  Future<void> _mdns() async {
    try {
      final discovery = BonsoirDiscovery(type: kStageServiceType);
      _discovery = discovery;
      await discovery.initialize();
      discovery.eventStream?.listen((event) {
        if (event is BonsoirDiscoveryServiceFoundEvent) {
          discovery.serviceResolver.resolveService(event.service);
        } else if (event is BonsoirDiscoveryServiceResolvedEvent) {
          final host = event.service.hostAddress;
          if (host != null) _found('http://$host:${event.service.port}');
        }
      });
      await discovery.start();
    } catch (_) {}
  }

  Future<void> _scan() async {
    for (final base in await _subnetBases()) {
      for (var i = 1; i <= 254; i++) {
        _probe('$base$i');
      }
    }
  }

  Future<void> _probe(String host) async {
    if (_stopped || _completer.isCompleted) return;
    try {
      final res = await http
          .get(Uri.parse('http://$host:8080/ping'))
          .timeout(const Duration(milliseconds: 600));
      if (res.statusCode == 200 && res.body.trim() == kStagePingBody) {
        _found('http://$host:8080');
      }
    } catch (_) {}
  }

  Future<List<String>> _subnetBases() async {
    final bases = <String>{};
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final nif in interfaces) {
        for (final addr in nif.addresses) {
          final ip = addr.address;
          if (ip.startsWith('192.168.') ||
              ip.startsWith('10.') ||
              ip.startsWith('172.')) {
            final idx = ip.lastIndexOf('.');
            if (idx > 0) bases.add(ip.substring(0, idx + 1));
          }
        }
      }
    } catch (_) {}
    return bases.toList();
  }

  Future<void> stop() async {
    _stopped = true;
    try {
      await _discovery?.stop();
    } catch (_) {}
    _discovery = null;
  }
}
