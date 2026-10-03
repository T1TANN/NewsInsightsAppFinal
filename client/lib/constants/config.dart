// Values come from client/.env at build time:
//   flutter run -d chrome --dart-define-from-file=.env
// NewsAPI and Groq keys live only on the backend; the app talks to the backend alone.
class Config {
  static const String _apiBase =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000/');

  /// Backend base URL, always with a trailing slash.
  static String get apiBase => _apiBase.endsWith('/') ? _apiBase : '$_apiBase/';
}
