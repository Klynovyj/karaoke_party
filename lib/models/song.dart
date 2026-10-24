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
}
