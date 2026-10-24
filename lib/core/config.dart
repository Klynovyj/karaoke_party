/// App-Konfiguration. Secrets werden per --dart-define übergeben, damit sie
/// nicht im Repo landen. Beispiel:
///   flutter run --dart-define-from-file=dart_define.json
class AppConfig {
  /// YouTube Data API v3 Key. Leer, wenn nicht übergeben.
  static const String youtubeApiKey = String.fromEnvironment('YT_API_KEY');

  static bool get hasYoutubeApiKey => youtubeApiKey.isNotEmpty;
}
