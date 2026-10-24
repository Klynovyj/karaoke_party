import 'dart:async';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';

/// Ein im Netzwerk gefundener Fernseher / Cast-Empfänger.
class TvDevice {
  final String name;
  final String brand; // z.B. "Chromecast / Android TV", "Samsung", "LG"
  final String? address;

  const TvDevice({required this.name, required this.brand, this.address});

  String get key => '$brand|$name|${address ?? ''}';
}

/// Sucht TVs im WLAN: per mDNS (Cast/AirPlay/Samsung) und per SSDP/UPnP
/// (DLNA-fähige TVs, u.a. viele Samsung/LG). Liefert eine Live-Liste.
class TvScanner {
  final List<BonsoirDiscovery> _discoveries = [];
  RawDatagramSocket? _ssdp;
  final Map<String, TvDevice> _devices = {};
  final StreamController<List<TvDevice>> _controller =
      StreamController<List<TvDevice>>.broadcast();
  bool _running = false;

  Stream<List<TvDevice>> get devices => _controller.stream;
  List<TvDevice> get current => _devices.values.toList();

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _mdns('_googlecast._tcp', 'Chromecast / Android TV');
    _mdns('_airplay._tcp', 'AirPlay (Apple/Samsung/LG)');
    _mdns('_samsungmsf._tcp', 'Samsung');
    _ssdpSearch();
  }

  void _add(TvDevice device) {
    _devices[device.key] = device;
    if (!_controller.isClosed) _controller.add(current);
  }

  Future<void> _mdns(String type, String brand) async {
    try {
      final discovery = BonsoirDiscovery(type: type);
      _discoveries.add(discovery);
      await discovery.initialize();
      discovery.eventStream?.listen((event) {
        if (event is BonsoirDiscoveryServiceFoundEvent) {
          discovery.serviceResolver.resolveService(event.service);
          _add(TvDevice(name: event.service.name, brand: brand));
        } else if (event is BonsoirDiscoveryServiceResolvedEvent) {
          _add(TvDevice(
            name: event.service.name,
            brand: brand,
            address: event.service.hostAddress,
          ));
        }
      });
      await discovery.start();
    } catch (_) {}
  }

  Future<void> _ssdpSearch() async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _ssdp = socket;
      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket.receive();
        if (datagram == null) return;
        final text = String.fromCharCodes(datagram.data);
        final brand = _brandFromServer(_header(text, 'SERVER'));
        _add(TvDevice(
          name: brand == 'TV' ? 'TV (${datagram.address.address})' : '$brand-TV',
          brand: brand,
          address: datagram.address.address,
        ));
      });
      const msearch = 'M-SEARCH * HTTP/1.1\r\n'
          'HOST: 239.255.255.250:1900\r\n'
          'MAN: "ssdp:discover"\r\n'
          'MX: 2\r\n'
          'ST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n\r\n';
      socket.send(
          msearch.codeUnits, InternetAddress('239.255.255.250'), 1900);
    } catch (_) {}
  }

  String? _header(String data, String name) {
    for (final line in data.split('\r\n')) {
      final i = line.indexOf(':');
      if (i > 0 && line.substring(0, i).trim().toUpperCase() == name) {
        return line.substring(i + 1).trim();
      }
    }
    return null;
  }

  String _brandFromServer(String? server) {
    final s = (server ?? '').toLowerCase();
    if (s.contains('samsung') || s.contains('tizen')) return 'Samsung';
    if (s.contains('lg') || s.contains('webos')) return 'LG';
    return 'TV';
  }

  Future<void> stop() async {
    _running = false;
    for (final discovery in _discoveries) {
      try {
        await discovery.stop();
      } catch (_) {}
    }
    _discoveries.clear();
    _ssdp?.close();
    _ssdp = null;
    _devices.clear();
    await _controller.close();
  }
}
