import 'package:flutter/foundation.dart';

/// Local logging only. Nothing is sent to the cloud (privacy rule).
void logd(String tag, Object? msg) {
  if (kDebugMode) debugPrint('[$tag] $msg');
}
