import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  final String version; // z.B. "0.5.0"
  final String apkUrl;
  const UpdateInfo({required this.version, required this.apkUrl});
}

/// Prüft das neueste GitHub-Release und installiert die APK (nur Android).
class UpdateService {
  static const _releasesApi =
      'https://api.github.com/repos/Klynovyj/karaoke_party/releases/latest';

  Future<UpdateInfo?> check() async {
    if (!Platform.isAndroid) return null;
    try {
      final res = await http.get(
        Uri.parse(_releasesApi),
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final tag = (data['tag_name'] as String?)?.replaceFirst('v', '') ?? '';
      final assets = (data['assets'] as List?) ?? const [];
      String? apkUrl;
      for (final a in assets) {
        final m = a as Map<String, dynamic>;
        if ((m['name'] as String?)?.endsWith('.apk') ?? false) {
          apkUrl = m['browser_download_url'] as String?;
          break;
        }
      }
      if (tag.isEmpty || apkUrl == null) return null;

      final info = await PackageInfo.fromPlatform();
      if (!_isNewer(tag, info.version)) return null;
      return UpdateInfo(version: tag, apkUrl: apkUrl);
    } catch (_) {
      return null;
    }
  }

  Future<void> downloadAndInstall(UpdateInfo update) async {
    final res = await http.get(Uri.parse(update.apkUrl));
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/karaoke_party_${update.version}.apk');
    await file.writeAsBytes(res.bodyBytes);
    await OpenFilex.open(
      file.path,
      type: 'application/vnd.android.package-archive',
    );
  }

  bool _isNewer(String remote, String local) {
    final r = _parse(remote);
    final l = _parse(local);
    for (var i = 0; i < 3; i++) {
      if (r[i] != l[i]) return r[i] > l[i];
    }
    return false;
  }

  List<int> _parse(String v) {
    final parts = v.split('.');
    return [
      for (var i = 0; i < 3; i++)
        i < parts.length ? (int.tryParse(parts[i].split('+').first) ?? 0) : 0,
    ];
  }
}
