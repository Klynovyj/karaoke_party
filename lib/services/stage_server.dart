import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_web_socket/shelf_web_socket.dart';

import 'stage_page.dart';

/// Kleiner HTTP+WebSocket-Server im Handy. Serviert die TV-Bühnenseite und
/// streamt den aktuellen Zustand (Video, Tonhöhe, Scoreboard) an alle TVs.
class StageServer {
  HttpServer? _server;
  final Set<dynamic> _clients = {}; // WebSocketChannel-Instanzen
  final StreamController<void> _changes = StreamController<void>.broadcast();

  Map<String, dynamic> _state = {'mode': 'idle', 'scoreboard': <dynamic>[]};

  /// Benachrichtigt die UI über Start/Stop und Verbindungsänderungen.
  Stream<void> get changes => _changes.stream;

  bool get isRunning => _server != null;
  int get port => _server?.port ?? 0;
  int get clientCount => _clients.length;

  /// Beste LAN-IPv4-Adresse (echte Adapter vor virtuellen wie VMware).
  Future<String?> localIp() async {
    final ips = await candidateIps();
    return ips.isEmpty ? null : ips.first;
  }

  /// Alle plausiblen LAN-IPv4-Adressen, reale Adapter zuerst. Nützlich, wenn
  /// mehrere Netzwerke (WLAN, VMware, …) existieren und der Nutzer wählen soll.
  Future<List<String>> candidateIps() async {
    bool isVirtual(String name) {
      final n = name.toLowerCase();
      return n.contains('vmware') ||
          n.contains('vmnet') ||
          n.contains('virtualbox') ||
          n.contains('hyper-v') ||
          n.contains('vethernet') ||
          n.contains('wsl') ||
          n.contains('docker') ||
          n.contains('loopback') ||
          n.contains('tailscale');
    }

    bool isPrivate(String ip) =>
        ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.');

    final result = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      final real = interfaces.where((n) => !isVirtual(n.name));
      final virtual = interfaces.where((n) => isVirtual(n.name));
      for (final nif in [...real, ...virtual]) {
        for (final addr in nif.addresses) {
          if (isPrivate(addr.address)) result.add(addr.address);
        }
      }
      if (result.isEmpty) {
        for (final nif in interfaces) {
          for (final addr in nif.addresses) {
            result.add(addr.address);
          }
        }
      }
    } catch (_) {}
    return result;
  }

  Future<void> start() async {
    if (_server != null) return;

    final wsHandler = webSocketHandler((channel, protocol) {
      _clients.add(channel);
      _notify();
      channel.sink.add(jsonEncode(_state));
      channel.stream.listen(
        (_) {},
        onDone: () {
          _clients.remove(channel);
          _notify();
        },
        onError: (_) {
          _clients.remove(channel);
          _notify();
        },
      );
    });

    FutureOr<Response> handler(Request request) {
      final path = request.url.path;
      if (path == 'ws') return wsHandler(request);
      if (path.isEmpty || path == '/' || path == 'index.html') {
        return Response.ok(stagePageHtml,
            headers: {'content-type': 'text/html; charset=utf-8'});
      }
      return Response.notFound('Not found');
    }

    for (var p = 8080; p <= 8090; p++) {
      try {
        _server = await io.serve(handler, InternetAddress.anyIPv4, p);
        break;
      } catch (_) {
        // Port belegt – nächsten versuchen.
      }
    }
    _notify();
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _clients.clear();
    _state = {'mode': 'idle', 'scoreboard': <dynamic>[]};
    _notify();
  }

  // --- Zustandssteuerung durch den Player ----------------------------------

  void setVideo(String videoId, String singer) {
    _state['mode'] = 'playing';
    _state['videoId'] = videoId;
    _state['singer'] = singer;
    _state['note'] = '–';
    _state['freq'] = null;
    _state['level'] = 0.0;
    _broadcast();
  }

  void setPitch({required String note, double? freq, required double level}) {
    if (_state['mode'] != 'playing') return;
    _state['note'] = note;
    _state['freq'] = freq;
    _state['level'] = level;
    _broadcast();
  }

  void setScoreboard(List<Map<String, dynamic>> entries) {
    _state['scoreboard'] = entries;
    _broadcast();
  }

  void setIdle() {
    _state['mode'] = 'idle';
    _state['videoId'] = null;
    _broadcast();
  }

  void _broadcast() {
    final msg = jsonEncode(_state);
    for (final c in _clients) {
      try {
        c.sink.add(msg);
      } catch (_) {}
    }
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }
}
