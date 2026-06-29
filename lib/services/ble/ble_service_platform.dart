// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/ble/ble_service_platform.dart
// Export Condicional de Servicio BLE por Plataforma
//
// Exporta el servicio BLE correcto según la plataforma.
// Solo soporta mobile (Android/iOS) con flutter_blue_plus.
//
// Uso:
//   import 'package:velvet_sync_platform/ble/ble_service_platform.dart';
//
//   final ble = getBleService();
//   await ble.initialize();
// ═══════════════════════════════════════════════════════════════

// Export condicional basado en la plataforma
export 'ble_service_stub.dart'
  if (dart.library.io) 'ble_service.dart';

// ═══════════════════════════════════════════════════════════════
// Función factory unificada
// ═══════════════════════════════════════════════════════════════

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;


import 'ble_service.dart' as real;

/// Obtiene el servicio BLE apropiado para la plataforma actual.
///
/// Retorna:
/// - [real.BleService] para Android/iOS
///
/// Ejemplo:
/// ```dart
/// final ble = getBleService();
/// await ble.initialize();
/// ```
dynamic getBleService() {
  // Web no tiene BLE nativo
  if (kIsWeb) {
    throw UnsupportedError('Web no soporta BLE nativo. Requiere backend.');
  }

  if (Platform.isAndroid || Platform.isIOS) {
    return real.BleService();
  }

  throw UnsupportedError('Plataforma no soportada: ${Platform.operatingSystem}');
}

/// Obtiene información de la plataforma BLE
String getBlePlatformInfo() {
  // Web no tiene BLE nativo
  if (kIsWeb) {
    return 'Web (requiere backend BLE)';
  }

  if (Platform.isAndroid || Platform.isIOS) {
    return 'Mobile (BLE nativo vía flutter_blue_plus)';
  }

  return 'Desconocido';
}

/// Verifica si el BLE está disponible en la plataforma actual
bool isBleAvailable() {
  // Web NO tiene BLE nativo, requiere backend
  if (kIsWeb) return false;

  if (Platform.isAndroid || Platform.isIOS) return true;

  return false;
}

/// Verifica si se requiere backend para BLE
bool requiresBleBackend() {
  return kIsWeb;
}

