import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../api/backend_client.dart';

/// Keeps a per-install device id and the backend token.
class AuthRepo {
  AuthRepo(this._prefs);
  final SharedPreferences _prefs;
  late BackendClient backend;

  String get deviceId {
    var id = _prefs.getString('deviceId');
    if (id == null) {
      final r = Random.secure();
      id = List.generate(24, (_) => r.nextInt(16).toRadixString(16)).join();
      _prefs.setString('deviceId', id);
    }
    return id;
  }

  Future<String> token() async {
    final cached = _prefs.getString('token');
    if (cached != null) return cached;
    final t = await backend.registerDevice(deviceId);
    await _prefs.setString('token', t);
    return t;
  }

  Future<void> clearToken() => _prefs.remove('token');
}
