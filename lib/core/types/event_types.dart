// ═══════════════════════════════════════════════════════════════
// Velvet Sync Platform · lib/core/types/event_types.dart
// Eventos del sistema para comunicación asíncrona
// ═══════════════════════════════════════════════════════════════

import 'package:velvet_sync/types/device_types.dart';
import 'package:velvet_sync/types/command_types.dart';

/// Evento base para todos los eventos del sistema
abstract class PlatformEvent {
  /// Timestamp del evento
  final DateTime timestamp;
  
  /// ID único del evento
  final String eventId;
  
  PlatformEvent({
    DateTime? timestamp,
    String? eventId,
  })  : timestamp = timestamp ?? DateTime.now(),
        eventId = eventId ?? 'evt_${DateTime.now().millisecondsSinceEpoch}';
  
  /// Tipo de evento
  String get eventType;
  
  /// Convertir a mapa JSON
  Map<String, dynamic> toJson();
}

// ═══════════════════════════════════════════════════════════════
// EVENTOS DE DISPOSITIVO
// ═══════════════════════════════════════════════════════════════

/// Evento de dispositivo descubierto
class DeviceDiscoveredEvent extends PlatformEvent {
  /// ID del dispositivo
  final String deviceId;
  
  /// Nombre del dispositivo
  final String name;
  
  /// Tipo de dispositivo
  final DeviceType deviceType;
  
  /// Tipo de conexión
  final ConnectionType connectionType;
  
  /// Señal RSSI (dBm)
  final int rssi;
  
  /// Dirección MAC o identificador único
  final String address;
  
  /// Protocolo detectado
  final String? protocol;
  
  DeviceDiscoveredEvent({
    required this.deviceId,
    required this.name,
    required this.deviceType,
    required this.connectionType,
    required this.rssi,
    required this.address,
    this.protocol,
    super.timestamp,
    super.eventId,
  });
  
  @override
  String get eventType => 'device_discovered';
  
  @override
  Map<String, dynamic> toJson() {
    return {
      'eventType': eventType,
      'deviceId': deviceId,
      'name': name,
      'deviceType': deviceType.name,
      'connectionType': connectionType.name,
      'rssi': rssi,
      'address': address,
      'protocol': protocol,
      'timestamp': timestamp.toIso8601String(),
      'eventId': eventId,
    };
  }
}

/// Evento de dispositivo conectado
class DeviceConnectedEvent extends PlatformEvent {
  /// ID del dispositivo
  final String deviceId;
  
  /// Nombre del dispositivo
  final String name;
  
  /// Tiempo de conexión en ms
  final int connectionTimeMs;
  
  DeviceConnectedEvent({
    required this.deviceId,
    required this.name,
    required this.connectionTimeMs,
    super.timestamp,
    super.eventId,
  });
  
  @override
  String get eventType => 'device_connected';
  
  @override
  Map<String, dynamic> toJson() {
    return {
      'eventType': eventType,
      'deviceId': deviceId,
      'name': name,
      'connectionTimeMs': connectionTimeMs,
      'timestamp': timestamp.toIso8601String(),
      'eventId': eventId,
    };
  }
}

/// Evento de dispositivo desconectado
class DeviceDisconnectedEvent extends PlatformEvent {
  /// ID del dispositivo
  final String deviceId;
  
  /// Nombre del dispositivo
  final String name;
  
  /// Razón de la desconexión
  final DisconnectReason reason;
  
  DeviceDisconnectedEvent({
    required this.deviceId,
    required this.name,
    required this.reason,
    super.timestamp,
    super.eventId,
  });
  
  @override
  String get eventType => 'device_disconnected';
  
  @override
  Map<String, dynamic> toJson() {
    return {
      'eventType': eventType,
      'deviceId': deviceId,
      'name': name,
      'reason': reason.name,
      'timestamp': timestamp.toIso8601String(),
      'eventId': eventId,
    };
  }
}

/// Razón de desconexión
enum DisconnectReason {
  /// Desconexión normal (usuario)
  normal,
  
  /// Desconexión por error
  error,
  
  /// Desconexión por timeout
  timeout,
  
  /// Dispositivo fuera de rango
  outOfRange,
  
  /// Dispositivo apagado
  poweredOff,
  
  /// Error de protocolo
  protocolError,
}

/// Evento de cambio de estado del dispositivo
class DeviceStateChangedEvent extends PlatformEvent {
  /// ID del dispositivo
  final String deviceId;
  
  /// Estado anterior
  final DeviceStatus previousState;
  
  /// Estado actual
  final DeviceStatus currentState;
  
  DeviceStateChangedEvent({
    required this.deviceId,
    required this.previousState,
    required this.currentState,
    super.timestamp,
    super.eventId,
  });
  
  @override
  String get eventType => 'device_state_changed';
  
  @override
  Map<String, dynamic> toJson() {
    return {
      'eventType': eventType,
      'deviceId': deviceId,
      'previousState': previousState.name,
      'currentState': currentState.name,
      'timestamp': timestamp.toIso8601String(),
      'eventId': eventId,
    };
  }
}

/// Evento de batería actualizada
class BatteryLevelChangedEvent extends PlatformEvent {
  /// ID del dispositivo
  final String deviceId;
  
  /// Nivel de batería (0.0 - 1.0)
  final double batteryLevel;
  
  /// Si está cargando
  final bool isCharging;
  
  BatteryLevelChangedEvent({
    required this.deviceId,
    required this.batteryLevel,
    required this.isCharging,
    super.timestamp,
    super.eventId,
  });
  
  @override
  String get eventType => 'battery_changed';
  
  @override
  Map<String, dynamic> toJson() {
    return {
      'eventType': eventType,
      'deviceId': deviceId,
      'batteryLevel': batteryLevel,
      'isCharging': isCharging,
      'timestamp': timestamp.toIso8601String(),
      'eventId': eventId,
    };
  }
}

// ═══════════════════════════════════════════════════════════════
// EVENTOS DE COMANDO
// ═══════════════════════════════════════════════════════════════

/// Evento de comando enviado
class CommandSentEvent extends PlatformEvent {
  /// ID del comando
  final String commandId;
  
  /// ID del dispositivo
  final String deviceId;
  
  /// Tipo de comando
  final CommandType commandType;
  
  /// Intensidad
  final double intensity;
  
  CommandSentEvent({
    required this.commandId,
    required this.deviceId,
    required this.commandType,
    required this.intensity,
    super.timestamp,
    super.eventId,
  });
  
  @override
  String get eventType => 'command_sent';
  
  @override
  Map<String, dynamic> toJson() {
    return {
      'eventType': eventType,
      'commandId': commandId,
      'deviceId': deviceId,
      'commandType': commandType.name,
      'intensity': intensity,
      'timestamp': timestamp.toIso8601String(),
      'eventId': eventId,
    };
  }
}

/// Evento de comando completado
class CommandCompletedEvent extends PlatformEvent {
  /// ID del comando
  final String commandId;
  
  /// ID del dispositivo
  final String deviceId;
  
  /// Si se completó exitosamente
  final bool success;
  
  /// Error si falló
  final String? error;
  
  CommandCompletedEvent({
    required this.commandId,
    required this.deviceId,
    required this.success,
    this.error,
    super.timestamp,
    super.eventId,
  });
  
  @override
  String get eventType => 'command_completed';
  
  @override
  Map<String, dynamic> toJson() {
    return {
      'eventType': eventType,
      'commandId': commandId,
      'deviceId': deviceId,
      'success': success,
      'error': error,
      'timestamp': timestamp.toIso8601String(),
      'eventId': eventId,
    };
  }
}

// ═══════════════════════════════════════════════════════════════
// EVENTOS DE ESCANEO
// ═══════════════════════════════════════════════════════════════

/// Evento de escaneo iniciado
class ScanStartedEvent extends PlatformEvent {
  /// Tipos de dispositivo a escanear
  final List<DeviceType> deviceTypes;
  
  ScanStartedEvent({
    required this.deviceTypes,
    super.timestamp,
    super.eventId,
  });
  
  @override
  String get eventType => 'scan_started';
  
  @override
  Map<String, dynamic> toJson() {
    return {
      'eventType': eventType,
      'deviceTypes': deviceTypes.map((t) => t.name).toList(),
      'timestamp': timestamp.toIso8601String(),
      'eventId': eventId,
    };
  }
}

/// Evento de escaneo finalizado
class ScanFinishedEvent extends PlatformEvent {
  /// Número de dispositivos encontrados
  final int devicesFound;
  
  ScanFinishedEvent({
    required this.devicesFound,
    super.timestamp,
    super.eventId,
  });
  
  @override
  String get eventType => 'scan_finished';
  
  @override
  Map<String, dynamic> toJson() {
    return {
      'eventType': eventType,
      'devicesFound': devicesFound,
      'timestamp': timestamp.toIso8601String(),
      'eventId': eventId,
    };
  }
}

// ═══════════════════════════════════════════════════════════════
// EVENTOS DE ERROR
// ═══════════════════════════════════════════════════════════════

/// Evento de error del sistema
class ErrorEvent extends PlatformEvent {
  /// Código de error
  final ErrorCode errorCode;
  
  /// Mensaje de error
  final String message;
  
  /// Stack trace si disponible
  final String? stackTrace;
  
  /// Componente donde ocurrió el error
  final String? component;
  
  ErrorEvent({
    required this.errorCode,
    required this.message,
    this.stackTrace,
    this.component,
    super.timestamp,
    super.eventId,
  });
  
  @override
  String get eventType => 'error';
  
  @override
  Map<String, dynamic> toJson() {
    return {
      'eventType': eventType,
      'errorCode': errorCode.name,
      'message': message,
      'stackTrace': stackTrace,
      'component': component,
      'timestamp': timestamp.toIso8601String(),
      'eventId': eventId,
    };
  }
}

/// Códigos de error
enum ErrorCode {
  /// Bluetooth no disponible
  bluetoothUnavailable,
  
  /// Permiso denegado
  permissionDenied,
  
  /// Dispositivo no encontrado
  deviceNotFound,
  
  /// Error de conexión
  connectionError,
  
  /// Timeout de operación
  timeout,
  
  /// Protocolo no soportado
  unsupportedProtocol,
  
  /// Comando inválido
  invalidCommand,
  
  /// Error de hardware
  hardwareError,
  
  /// Error interno
  internalError,
  
  /// Configuración inválida
  invalidConfiguration,
}
