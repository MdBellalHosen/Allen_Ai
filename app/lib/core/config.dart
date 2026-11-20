/// Build-time config. Pass with --dart-define=BACKEND_URL=https://...
class AppConfig {
  static const backendUrl =
      String.fromEnvironment('BACKEND_URL', defaultValue: 'http://10.0.2.2:8000');
}
