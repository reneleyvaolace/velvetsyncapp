// Velvet Sync · lib/services/ble/ble_service_platform.dart
// Compat wrapper: reusa ble_service.dart como entrada única BLE.
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'ble_service_mobile.dart' as real;

dynamic getBleService() {
  if (kIsWeb) throw UnsupportedError('Web no soporta BLE nativo. Requiere backend.');
  if (Platform.isAndroid || Platform.isIOS) return real.BleService();
  throw UnsupportedError('Plataforma no soportada: ${Platform.operatingSystem}');
}

String getBlePlatformInfo() {
  if (kIsWeb) return 'Web (requiere backend BLE)';
  if (Platform.isAndroid || Platform.isIOS) return 'Mobile (BLE nativo vía flutter_blue_plus)';
  return 'Desconocido';
}

bool isBleAvailable() {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}

bool requiresBleBackend() => kIsWeb;
