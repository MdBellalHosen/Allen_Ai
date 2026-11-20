/// Build-time config. Pass with --dart-define=KEY=value
class AppConfig {
  static const backendUrl =
      String.fromEnvironment('BACKEND_URL', defaultValue: 'http://10.0.2.2:8000');
  static const registrationCode = String.fromEnvironment('REGISTRATION_CODE');
  // Wake word key is a per-app Picovoice AccessKey (not a backend secret).
  static const picovoiceAccessKey = String.fromEnvironment('PICOVOICE_ACCESS_KEY');
  static const wakeWordAsset = 'assets/wakeword/hey_maya_android.ppn';
}
