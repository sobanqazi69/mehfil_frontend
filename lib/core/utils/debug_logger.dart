import 'package:flutter/foundation.dart';

class DebugLogger {
  DebugLogger._();

  static void log(String message, {String? tag}) {
    if (kDebugMode) debugPrint('[${tag ?? 'LOG'}] $message');
  }

  static void error(String message, {Object? error, String? tag}) {
    if (kDebugMode) debugPrint('[${tag ?? 'ERROR'}] $message${error != null ? ' | $error' : ''}');
  }

  static void socket(String event, [Object? data]) {
    if (kDebugMode) debugPrint('[SOCKET] $event${data != null ? ' → $data' : ''}');
  }
}
