import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../models/song.dart';

class YoutubeApiException implements Exception {
  final String message;
  YoutubeApiException(this.message);
  @override
  String toString() => message;
}

/// Sucht Karaoke-Videos über die offizielle YouTube Data API v3.
class YoutubeService {
  final http.Client _client;
  YoutubeService([http.Client? client]) : _client = client ?? http.Client();

  Future<List<Song>> search(String query) async {
    if (!AppConfig.hasYoutubeApiKey) {
      throw YoutubeApiException(
        'Kein YouTube-API-Key gesetzt. Starte die App mit '
        '--dart-define-from-file=dart_define.json',
      );
    }

    final uri = Uri.https('www.googleapis.com', '/youtube/v3/search', {
      'part': 'snippet',
      'q': '$query karaoke',
      'type': 'video',
      'videoEmbeddable': 'true',
      'maxResults': '20',
      'key': AppConfig.youtubeApiKey,
    });

    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw YoutubeApiException('YouTube-Suche fehlgeschlagen (${res.statusCode}).');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (data['items'] as List?) ?? const [];

    return items
        .map((raw) {
          final item = raw as Map<String, dynamic>;
          final id = (item['id'] as Map<String, dynamic>?)?['videoId'] as String?;
          final snippet = item['snippet'] as Map<String, dynamic>? ?? const {};
          final thumbs = snippet['thumbnails'] as Map<String, dynamic>? ?? const {};
          final thumb = (thumbs['medium'] ?? thumbs['default']) as Map<String, dynamic>?;
          return Song(
            youtubeId: id ?? '',
            title: _unescape(snippet['title'] as String? ?? ''),
            artist: _unescape(snippet['channelTitle'] as String? ?? ''),
            thumbnailUrl: thumb?['url'] as String? ?? '',
          );
        })
        .where((s) => s.youtubeId.isNotEmpty)
        .toList();
  }

  String _unescape(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}
