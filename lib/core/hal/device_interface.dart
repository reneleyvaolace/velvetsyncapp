// ═══════════════════════════════════════════════════════════════
// Velvet Sync Platform · lib/src/core/hal/device_interface.dart
// Interfaz común para todos los dispositivos
// ═══════════════════════════════════════════════════════════════

import 'dart:math' as math;
import '../types/device_types.dart';
import '../types/command_types.dart';
import '../types/result_types.dart';

/// Interfaz común para todos los dispositivos
/// 
/// Esta interfaz abstrae las diferencias entre protocolos y transportes,
/// permitiendo controlar cualquier dispositivo con la misma API.
abstract class DeviceInterface {
  /// ID único del dispositivo
  String get id;
  
  /// Nombre legible del dispositivo
  String get name;
  
  /// Tipo de dispositivo
  DeviceType get type;
  
  /// Tipo de conexión
  ConnectionType get connectionType;
  
  /// Estado de la conexión
  ConnectionStatus get status;
  
  /// Estado del dispositivo
  DeviceStatus get deviceStatus;
  
  /// Protocolo que usa el dispositivo
  String get protocolName;
  
  /// Features soportadas
  List<DeviceFeature> get supportedFeatures;
  
  /// Nivel de precisión del control
  ControlPrecision get precision;
  
  /// Si tiene dual-channel
  bool get hasDualChannel;
  
  /// Dirección MAC o identificador único
  String get address;
  
  /// Nivel de batería (0.0 - 1.0)
  double get batteryLevel;
  
  /// Si está cargando
  bool get isCharging;
  
  /// Señal RSSI (dBm)
  double get rssi;
  
  /// Metadata adicional
  Map<String, dynamic> get metadata;
  
  // ═══════════════════════════════════════════════════════════
  // MÉTODOS DE CONEXIÓN
  // ═══════════════════════════════════════════════════════════
  
  /// Conectar al dispositivo
  /// 
  /// Returns: [Success] si conecta, [Failure] con [DeviceError] si falla
  Future<Result<void, DeviceError>> connect();
  
  /// Desconectar del dispositivo
  /// 
  /// Returns: [Success] si desconecta, [Failure] con [DeviceError] si falla
  Future<Result<void, DeviceError>> disconnect();
  
  /// Verificar si está conectado
  /// 
  /// Returns: true si está conectado y listo para usar
  Future<bool> isConnected();
  
  // ═══════════════════════════════════════════════════════════
  // MÉTODOS DE CONTROL BÁSICO
  // ═══════════════════════════════════════════════════════════
  
  /// Detener todas las operaciones
  /// 
  /// Returns: [Success] si para, [Failure] con [DeviceError] si falla
  Future<Result<void, DeviceError>> stop();
  
  /// Detener operación específica
  /// 
  /// [feature] Feature a detener
  /// [channel] Canal específico (para dual-channel)
  Future<Result<void, DeviceError>> stopFeature(
    DeviceFeature feature, {
    DeviceChannel channel = DeviceChannel.single,
  });
  
  // ═══════════════════════════════════════════════════════════
  // MÉTODOS DE CONTROL DE FEATURES
  // ═══════════════════════════════════════════════════════════
  
  /// Controlar vibración
  /// 
  /// [intensity] Intensidad (0.0 - 1.0)
  /// [channel] Canal específico (para dual-channel)
  /// 
  /// Returns: [Success] si ejecuta, [Failure] con [DeviceError] si falla
  Future<Result<void, DeviceError>> vibrate(
    double intensity, {
    DeviceChannel channel = DeviceChannel.single,
  });
  
  /// Controlar rotación
  /// 
  /// [intensity] Intensidad (0.0 - 1.0)
  /// [channel] Canal específico (para dual-channel)
  Future<Result<void, DeviceError>> rotate(
    double intensity, {
    DeviceChannel channel = DeviceChannel.single,
  });
  
  /// Controlar oscilación
  /// 
  /// [intensity] Intensidad (0.0 - 1.0)
  /// [channel] Canal específico (para dual-channel)
  Future<Result<void, DeviceError>> oscillate(
    double intensity, {
    DeviceChannel channel = DeviceChannel.single,
  });
  
  /// Controlar embestida (thrusting)
  /// 
  /// [intensity] Intensidad (0.0 - 1.0)
  /// [speed] Velocidad (0.0 - 1.0)
  Future<Result<void, DeviceError>> thrust(
    double intensity, {
    double speed = 0.5,
  });
  
  /// Controlar succión
  /// 
  /// [intensity] Intensidad (0.0 - 1.0)
  /// [pattern] Patrón de succión
  Future<Result<void, DeviceError>> suction(
    double intensity, {
    String? pattern,
  });
  
  // ═══════════════════════════════════════════════════════════
  // MÉTODOS DE PATRONES
  // ═══════════════════════════════════════════════════════════
  
  /// Ejecutar patrón predefinido
  /// 
  /// [patternId] ID del patrón
  /// [channel] Canal específico
  Future<Result<void, DeviceError>> executePattern(
    String patternId, {
    DeviceChannel channel = DeviceChannel.single,
  });
  
  /// Ejecutar secuencia de comandos
  /// 
  /// [sequence] Secuencia a ejecutar
  Future<Result<void, DeviceError>> executeSequence(CommandSequence sequence);
  
  // ═══════════════════════════════════════════════════════════
  // MÉTODOS DE INFORMACIÓN
  // ═══════════════════════════════════════════════════════════
  
  /// Leer nivel de batería
  /// 
  /// Returns: [Success] con nivel (0.0 - 1.0), [Failure] con [DeviceError]
  Future<Result<double, DeviceError>> getBatteryLevel();
  
  /// Leer fuerza de señal (RSSI)
  /// 
  /// Returns: [Success] con RSSI en dBm, [Failure] con [DeviceError]
  Future<Result<double, DeviceError>> getRssi();
  
  /// Leer estado de carga
  /// 
  /// Returns: [Success] con estado de carga, [Failure] con [DeviceError]
  Future<Result<bool, DeviceError>> getChargingStatus();
  
  // ═══════════════════════════════════════════════════════════
  // MÉTODOS DE CONFIGURACIÓN
  // ═══════════════════════════════════════════════════════════
  
  /// Actualizar configuración del dispositivo
  /// 
  /// [config] Nueva configuración
  Future<Result<void, DeviceError>> updateConfiguration(
    Map<String, dynamic> config,
  );
  
  /// Obtener configuración actual
  /// 
  /// Returns: [Success] con configuración, [Failure] con [DeviceError]
  Future<Result<Map<String, dynamic>, DeviceError>> getConfiguration();
  
  // ═══════════════════════════════════════════════════════════
  // MÉTODOS DE DIAGNÓSTICO
  // ═══════════════════════════════════════════════════════════
  
  /// Ejecutar diagnóstico del dispositivo
  /// 
  /// Returns: [Success] con resultados, [Failure] con [DeviceError]
  Future<Result<DeviceDiagnosticResult, DeviceError>> runDiagnostic();
  
  /// Obtener información del firmware
  /// 
  /// Returns: [Success] con información, [Failure] con [DeviceError]
  Future<Result<FirmwareInfo, DeviceError>> getFirmwareInfo();
  
  // ═══════════════════════════════════════════════════════════
  // CLEANUP
  // ═══════════════════════════════════════════════════════════
  
  /// Liberar recursos
  void dispose();
}

/// Resultado de diagnóstico
class DeviceDiagnosticResult {
  /// Si el diagnóstico pasó
  final bool passed;
  
  /// Mensajes de error
  final List<String> errors;
  
  /// Mensajes de advertencia
  final List<String> warnings;
  
  /// Métricas de rendimiento
  final Map<String, double> metrics;
  
  DeviceDiagnosticResult({
    required this.passed,
    this.errors = const [],
    this.warnings = const [],
    this.metrics = const {},
  });
  
  /// Crear resultado exitoso
  factory DeviceDiagnosticResult.success({Map<String, double>? metrics}) {
    return DeviceDiagnosticResult(
      passed: true,
      metrics: metrics ?? {},
    );
  }
  
  /// Crear resultado fallido
  factory DeviceDiagnosticResult.failure({
    List<String>? errors,
    List<String>? warnings,
  }) {
    return DeviceDiagnosticResult(
      passed: false,
      errors: errors ?? [],
      warnings: warnings ?? [],
    );
  }
}

/// Información del firmware
class FirmwareInfo {
  /// Versión del firmware
  final String version;
  
  /// Fecha de compilación
  final DateTime? buildDate;
  
  /// Número de build
  final String? buildNumber;
  
  /// Región
  final String? region;
  
  FirmwareInfo({
    required this.version,
    this.buildDate,
    this.buildNumber,
    this.region,
  });
  
  /// Crear desde mapa JSON
  factory FirmwareInfo.fromJson(Map<String, dynamic> json) {
    return FirmwareInfo(
      version: json['version'] as String,
      buildDate: DateTime.tryParse(json['buildDate'] as String),
      buildNumber: json['buildNumber'] as String?,
      region: json['region'] as String?,
    );
  }
  
  /// Convertir a mapa JSON
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'buildDate': buildDate?.toIso8601String(),
      'buildNumber': buildNumber,
      'region': region,
    };
  }
  
  @override
  String toString() => 'FirmwareInfo(version: $version)';
}

/// Interfaz para dispositivos con dual-channel
abstract class DualChannelDevice implements DeviceInterface {
  @override
  bool get hasDualChannel => true;
  
  /// Controlar canal 1
  Future<Result<void, DeviceError>> controlChannel1(double intensity);
  
  /// Controlar canal 2
  Future<Result<void, DeviceError>> controlChannel2(double intensity);
  
  /// Controlar ambos canales sincronizados
  Future<Result<void, DeviceError>> controlBothChannels(
    double intensity1,
    double intensity2,
  );
}

/// Interfaz para dispositivos con sensor de batería
abstract class BatteryDevice implements DeviceInterface {
  @override
  double get batteryLevel;
  
  @override
  bool get isCharging;
  
  /// Evento de cambio de batería
  Stream<double> get onBatteryLevelChanged;
}

/// Interfaz para dispositivos con sensor de movimiento
abstract class MotionDevice implements DeviceInterface {
  /// Evento de movimiento detectado
  Stream<MotionEvent> get onMotionDetected;
}

/// Evento de movimiento
class MotionEvent {
  /// Timestamp del evento
  final DateTime timestamp;
  
  /// Aceleración en eje X
  final double accelerationX;
  
  /// Aceleración en eje Y
  final double accelerationY;
  
  /// Aceleración en eje Z
  final double accelerationZ;
  
  MotionEvent({
    required this.timestamp,
    required this.accelerationX,
    required this.accelerationY,
    required this.accelerationZ,
  });
  
  /// Magnitud de la aceleración
  double get magnitude {
    return math.sqrt(accelerationX * accelerationX +
            accelerationY * accelerationY +
            accelerationZ * accelerationZ);
  }
}

// Extensión para obtener sqrt
// extension on double {
//   double get sqrt => this < 0 ? double.nan : _sqrt(this);
//   
//   static double _sqrt(double x) {
//     if (x == 0) return 0;
//     double guess = x / 2;
//     for (int i = 0; i < 10; i++) {
//       guess = (guess + x / guess) / 2;
//     }
//     return guess;
//   }
// }
