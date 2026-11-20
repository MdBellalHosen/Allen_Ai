import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/config.dart';

class SttResponse {
  SttResponse(this.text, this.language);
  final String text;
  final String language; // bn / en / und ...
}

class BackendException implements Exception {
  BackendException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => 'BackendException($status): $message';
}

class BackendClient {
  BackendClient({this.getToken, this.onUnauthorized, this.baseUrl, this.registrationCode, http.Client? client})
      : _http = client ?? http.Client();
  final http.Client _http;
  final Future<String> Function()? getToken;
  final Future<void> Function()? onUnauthorized; // clears the cached token so the next call re-registers

  /// Read on every call so changing the address in Settings takes effect immediately.
  final String Function()? baseUrl;
  final String Function()? registrationCode;

  Uri _u(String p) => Uri.parse('${(baseUrl ?? () => AppConfig.backendUrl)()}$p');

  Future<bool> health() async {
    try {
      final r = await _http.get(_u('/health')).timeout(const Duration(seconds: 8));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String> registerDevice(String deviceId) async {
    final r = await _http.post(
      _u('/v1/auth/device'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'device_id': deviceId, 'registration_code': (registrationCode ?? () => AppConfig.registrationCode)()}),
    );
    if (r.statusCode != 200) throw BackendException(r.statusCode, r.body);
    return jsonDecode(r.body)['token'] as String;
  }

  /// Authenticated JSON POST. Re-registers the device once if the token was rejected.
  Future<Map<String, dynamic>> postJson(String path, Map<String, Object?> body, {bool retried = false}) async {
    final token = await getToken!();
    final r = await _http
        .post(
          _u(path),
          headers: {'content-type': 'application/json', 'authorization': 'Bearer $token'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 90));
    if (r.statusCode == 401 && !retried && onUnauthorized != null) {
      await onUnauthorized!();
      return postJson(path, body, retried: true);
    }
    if (r.statusCode != 200) throw BackendException(r.statusCode, r.body);
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  Future<SttResponse> transcribe(File audio, {String? languageHint, bool retried = false}) async {
    final token = await getToken!();
    final req = http.MultipartRequest('POST', _u('/v1/stt'))
      ..headers['authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('file', audio.path));
    if (languageHint != null) req.fields['language'] = languageHint;
    final res = await http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 60)));
    if (res.statusCode == 401 && !retried && onUnauthorized != null) {
      await onUnauthorized!();
      return transcribe(audio, languageHint: languageHint, retried: true);
    }
    if (res.statusCode != 200) throw BackendException(res.statusCode, res.body);
    final j = jsonDecode(utf8.decode(res.bodyBytes));
    return SttResponse(j['text'] as String, j['language'] as String);
  }
}
