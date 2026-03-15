// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/models/device_sync_model.dart
// Modelo para eventos de sincronización en tiempo real
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';

/// Evento de sincronización de dispositivo en tiempo real
/// Representa un comando recibido desde Supabase para un dispositivo
class DeviceSyncEvent {
  /// ID único del evento (desde Supabase)
  final String id;

  /// ID del dispositivo destino
  final String deviceId;

  /// Tipo de comando a ejecutar
  final String command;

  /// Payload del comando (datos adicionales en formato JSON)
  final Map<String, dynamic> payload;

  /// Timestamp del evento (desde Supabase)
  final DateTime timestamp;

  /// ID de la sesión que originó el evento
  final String? sessionId;

  /// Usuario que originó el evento
  final String? userId;

  const DeviceSyncEvent({
    required this.id,
    required this.deviceId,
    required this.command,
    required this.payload,
    required this.timestamp,
    this.sessionId,
    this.userId,
  });

  /// Crea un DeviceSyncEvent desde un mapa de Supabase
  factory DeviceSyncEvent.fromMap(Map<String, dynamic> map) {
    // El payload puede venir como String JSON o como Map
    Map<String, dynamic> parsedPayload = {};
    
    final payloadData = map['payload'];
    if (payloadData != null) {
      if (payloadData is String) {
        try {
          parsedPayload = jsonDecode(payloadData) as Map<String, dynamic>;
        } catch (e) {
          parsedPayload = {'raw': payloadData};
        }
      } else if (payloadData is Map<String, dynamic>) {
        parsedPayload = payloadData;
      }
    }

    // Parsear timestamp
    DateTime timestamp = DateTime.now();
    final timestampData = map['created_at'] ?? map['timestamp'];
    if (timestampData != null) {
      if (timestampData is DateTime) {
        timestamp = timestampData;
      } else if (timestampData is String) {
        try {
          timestamp = DateTime.parse(timestampData);
        } catch (e) {
          // Usar timestamp actual si falla el parseo
        }
      }
    }

    return DeviceSyncEvent(
      id: map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      deviceId: map['device_id']?.toString() ?? map['deviceId']?.toString() ?? '',
      command: map['command']?.toString() ?? '',
      payload: parsedPayload,
      timestamp: timestamp,
      sessionId: map['session_id']?.toString() ?? map['sessionId']?.toString(),
      userId: map['user_id']?.toString() ?? map['userId']?.toString(),
    );
  }

  /// Convierte el evento a un mapa para enviar a Supabase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'device_id': deviceId,
      'command': command,
      'payload': jsonEncode(payload),
      'created_at': timestamp.toIso8601String(),
      if (sessionId != null) 'session_id': sessionId,
      if (userId != null) 'user_id': userId,
    };
  }

  /// Crea una copia del evento con campos modificados
  DeviceSyncEvent copyWith({
    String? id,
    String? deviceId,
    String? command,
    Map<String, dynamic>? payload,
    DateTime? timestamp,
    String? sessionId,
    String? userId,
  }) {
    return DeviceSyncEvent(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      command: command ?? this.command,
      payload: payload ?? this.payload,
      timestamp: timestamp ?? this.timestamp,
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
    );
  }

  /// Verifica si el comando es de tipo APPLY_AI_PROFILE
  bool get isAiProfile => command == 'APPLY_AI_PROFILE';

  /// Verifica si el comando es de tipo SET_INTENSITY
  bool get isIntensity => command == 'SET_INTENSITY';

  /// Verifica si el comando es de tipo SET_PATTERN
  bool get isPattern => command == 'SET_PATTERN';

  /// Verifica si el comando es de tipo STOP
  bool get isStop => command == 'STOP';

  /// Obtiene la intensidad del payload (si existe)
  int? get intensity {
    if (isIntensity || isAiProfile) {
      final value = payload['intensity'] ?? payload['intensity_ch1'];
      if (value is int) return value;
      if (value is double) return value.round();
      if (value is String) return int.tryParse(value);
    }
    return null;
  }

  /// Obtiene la intensidad del canal 2 (si existe)
  int? get intensityCh2 {
    final value = payload['intensity_ch2'];
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Obtiene el patrón del payload (si existe)
  int? get pattern {
    if (isPattern) {
      final value = payload['pattern'];
      if (value is int) return value;
      if (value is double) return value.round();
      if (value is String) return int.tryParse(value);
    }
    return null;
  }

  @override
  String toString() {
    return 'DeviceSyncEvent(id: $id, deviceId: $deviceId, command: $command, payload: $payload, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceSyncEvent &&
        other.id == id &&
        other.deviceId == deviceId &&
        other.command == command &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => id.hashCode ^ deviceId.hashCode ^ command.hashCode;
}

/// Tipos de comandos soportados por el sistema de sincronización
class SyncCommands {
  static const String applyAiProfile = 'APPLY_AI_PROFILE';
  static const String setIntensity = 'SET_INTENSITY';
  static const String setPattern = 'SET_PATTERN';
  static const String setSpeed = 'SET_SPEED';
  static const String stop = 'STOP';
  static const String emergencyStop = 'EMERGENCY_STOP';
  static const String syncState = 'SYNC_STATE';
  static const String updateFirmware = 'UPDATE_FIRMWARE';
}
