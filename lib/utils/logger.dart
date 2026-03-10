import 'package:flutter/foundation.dart';

/// Logger seguro que solo imprime en modo Debug.
/// Protege contra la fuga de información sensible en producción.
void lvsLog(String message, {String? tag}) {
  if (kDebugMode) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final prefix = tag != null ? '[$tag]' : '[LVS]';
    debugPrint('$timestamp $prefix $message');
  }
}
