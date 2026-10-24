/// Ein YouTube-Karaoke-Video.
class Song {
  final String youtubeId;
  final String title;
  final String artist;
  final String thumbnailUrl;

  const Song({
    required this.youtubeId,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
  });

  Map<String, dynamic> toJson() => {
        'youtubeId': youtubeId,
        'title': title,
        'artist': artist,
        'thumbnailUrl': thumbnailUrl,
      };

  factory Song.fromJson(Map<String, dynamic> j) => Song(
        youtubeId: j['youtubeId'] as String,
        title: j['title'] as String,
        artist: j['artist'] as String? ?? '',
        thumbnailUrl: j['thumbnailUrl'] as String? ?? '',
      );
}
