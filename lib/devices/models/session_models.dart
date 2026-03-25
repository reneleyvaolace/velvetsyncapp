// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/models/session_models.dart
// Modelos para Sesiones Multi-Usuario Multi-Dispositivo
// 
// Soporte para sesiones compartidas donde múltiples usuarios
// pueden controlar múltiples dispositivos simultáneamente.
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';

// ═══════════════════════════════════════════════════════════════
// Session Models
// ═══════════════════════════════════════════════════════════════

/// Sesión compartida multi-usuario multi-dispositivo
class SharedSession {
  /// ID único de la sesión
  final String id;

  /// Token de acceso para unirse
  final String accessToken;

  /// Nombre de la sesión
  final String name;

  /// Usuario creador (host)
  final String hostUserId;

  /// Lista de participantes
  final List<SessionParticipant> participants;

  /// Dispositivos en la sesión
  final List<SessionDevice> devices;

  /// ¿Sesión activa?
  final bool isActive;

  /// Fecha de creación
  final DateTime createdAt;

  /// Fecha de expiración
  final DateTime? expiresAt;

  /// Configuración de la sesión
  final SessionConfig config;

  SharedSession({
    required this.id,
    required this.accessToken,
    required this.name,
    required this.hostUserId,
    required this.participants,
    required this.devices,
    required this.isActive,
    required this.createdAt,
    this.expiresAt,
    required this.config,
  });

  /// Crear sesión vacía
  factory SharedSession.create({
    required String name,
    required String hostUserId,
    SessionConfig? config,
  }) {
    return SharedSession(
      id: _generateId(),
      accessToken: _generateToken(),
      name: name,
      hostUserId: hostUserId,
      participants: [SessionParticipant(userId: hostUserId, isHost: true)],
      devices: [],
      isActive: true,
      createdAt: DateTime.now(),
      config: config ?? const SessionConfig(),
    );
  }

  /// Cargar desde JSON
  factory SharedSession.fromJson(Map<String, dynamic> json) {
    return SharedSession(
      id: json['id'] ?? '',
      accessToken: json['accessToken'] ?? '',
      name: json['name'] ?? '',
      hostUserId: json['hostUserId'] ?? '',
      participants: (json['participants'] as List?)
              ?.map((p) => SessionParticipant.fromJson(p))
              .toList() ??
          [],
      devices: (json['devices'] as List?)
              ?.map((d) => SessionDevice.fromJson(d))
              .toList() ??
          [],
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'])
          : null,
      config: json['config'] != null
          ? SessionConfig.fromJson(json['config'])
          : const SessionConfig(),
    );
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'accessToken': accessToken,
      'name': name,
      'hostUserId': hostUserId,
      'participants': participants.map((p) => p.toJson()).toList(),
      'devices': devices.map((d) => d.toJson()).toList(),
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'config': config.toJson(),
    };
  }

  /// Generar ID único
  static String _generateId() {
    return 'session_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Generar token de acceso
  static String _generateToken() {
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    return base64Encode(utf8.encode(random)).substring(0, 16);
  }

  /// ¿Es host el usuario actual?
  bool isHost(String userId) => hostUserId == userId;

  /// ¿Es participante el usuario actual?
  bool isParticipant(String userId) =>
      participants.any((p) => p.userId == userId);

  /// ¿Puede el usuario controlar un dispositivo?
  bool canControl(String userId, String deviceId, {String? controlledBy}) {
    // Host siempre puede controlar
    if (isHost(userId)) return true;

    // Si el dispositivo tiene controlador asignado
    if (controlledBy != null) {
      return userId == controlledBy;
    }

    // Modo colaborativo: todos pueden controlar
    if (config.collaborativeMode) return true;

    // Modo exclusivo: solo el asignado
    return false;
  }

  /// Duración restante de la sesión
  Duration? get remainingDuration {
    if (expiresAt == null) return null;
    return expiresAt!.difference(DateTime.now());
  }

  /// ¿Sesión expirada?
  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  @override
  String toString() {
    return 'SharedSession($name, ${participants.length} users, ${devices.length} devices)';
  }
}

// ═══════════════════════════════════════════════════════════════
// Participant Model
// ═══════════════════════════════════════════════════════════════

/// Participante en una sesión compartida
class SessionParticipant {
  /// ID del usuario
  final String userId;

  /// Nombre para mostrar
  final String displayName;

  /// ¿Es el host de la sesión?
  final bool isHost;

  /// ¿Puede controlar dispositivos?
  final bool canControl;

  /// Fecha de unión
  final DateTime joinedAt;

  /// Estado del participante
  final ParticipantStatus status;

  SessionParticipant({
    required this.userId,
    this.displayName = 'Anonymous',
    this.isHost = false,
    this.canControl = true,
    DateTime? joinedAt,
    this.status = ParticipantStatus.active,
  }) : joinedAt = joinedAt ?? DateTime.now();

  /// Cargar desde JSON
  factory SessionParticipant.fromJson(Map<String, dynamic> json) {
    return SessionParticipant(
      userId: json['userId'] ?? '',
      displayName: json['displayName'] ?? 'Anonymous',
      isHost: json['isHost'] ?? false,
      canControl: json['canControl'] ?? true,
      joinedAt: json['joinedAt'] != null
          ? DateTime.parse(json['joinedAt'])
          : DateTime.now(),
      status: ParticipantStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => ParticipantStatus.active,
      ),
    );
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'displayName': displayName,
      'isHost': isHost,
      'canControl': canControl,
      'joinedAt': joinedAt.toIso8601String(),
      'status': status.name,
    };
  }

  @override
  String toString() {
    return 'SessionParticipant($displayName, ${isHost ? "host" : "participant"})';
  }
}

/// Estado del participante
enum ParticipantStatus {
  active,
  away,
  disconnected,
  spectating,
}

// ═══════════════════════════════════════════════════════════════
// Session Device Model
// ═══════════════════════════════════════════════════════════════

/// Dispositivo en una sesión compartida
class SessionDevice {
  /// ID único del dispositivo en la sesión
  final String id;

  /// ID del dispositivo físico (Buttplug/device)
  final String deviceId;

  /// Nombre del dispositivo
  final String name;

  /// Usuario que posee el dispositivo
  final String? ownerId;

  /// Usuario que actualmente controla el dispositivo
  final String? controlledBy;

  /// ¿Dispositivo activo?
  final bool isActive;

  /// Intensidad actual (0.0-1.0)
  final double currentIntensity;

  /// Fecha de agregado
  final DateTime addedAt;

  SessionDevice({
    required this.id,
    required this.deviceId,
    required this.name,
    this.ownerId,
    this.controlledBy,
    required this.isActive,
    required this.currentIntensity,
    required this.addedAt,
  });

  /// Cargar desde JSON
  factory SessionDevice.fromJson(Map<String, dynamic> json) {
    return SessionDevice(
      id: json['id'] ?? '',
      deviceId: json['deviceId'] ?? '',
      name: json['name'] ?? '',
      ownerId: json['ownerId'],
      controlledBy: json['controlledBy'],
      isActive: json['isActive'] ?? false,
      currentIntensity: (json['currentIntensity'] ?? 0.0).toDouble(),
      addedAt: json['addedAt'] != null
          ? DateTime.parse(json['addedAt'])
          : DateTime.now(),
    );
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'name': name,
      'ownerId': ownerId,
      'controlledBy': controlledBy,
      'isActive': isActive,
      'currentIntensity': currentIntensity,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  /// ¿Puede ser controlado por el usuario?
  bool isControllableBy(String userId) {
    // Si no hay controlador asignado, cualquiera puede controlar
    if (controlledBy == null) return true;
    return userId == controlledBy;
  }

  @override
  String toString() {
    return 'SessionDevice($name, owner: $ownerId, controlled: $controlledBy)';
  }
}

// ═══════════════════════════════════════════════════════════════
// Session Config
// ═══════════════════════════════════════════════════════════════

/// Configuración de sesión compartida
class SessionConfig {
  /// ¿Modo colaborativo? (todos controlan todos)
  final bool collaborativeMode;

  /// ¿Modo exclusivo? (solo asignados controlan)
  final bool exclusiveMode;

  /// ¿Permitir espectadores?
  final bool allowSpectators;

  /// ¿Requiere aprobación para unirse?
  final bool requireApproval;

  /// Duración máxima en minutos (null = ilimitada)
  final int? maxDurationMinutes;

  /// Máximo de participantes (null = ilimitado)
  final int? maxParticipants;

  /// Máximo de dispositivos (null = ilimitado)
  final int? maxDevices;

  /// ¿Mostrar intensidad de otros usuarios?
  final bool showOthersIntensity;

  /// ¿Permitir chat en sesión?
  final bool allowChat;

  const SessionConfig({
    this.collaborativeMode = true,
    this.exclusiveMode = false,
    this.allowSpectators = true,
    this.requireApproval = false,
    this.maxDurationMinutes,
    this.maxParticipants,
    this.maxDevices,
    this.showOthersIntensity = true,
    this.allowChat = true,
  });

  /// Cargar desde JSON
  factory SessionConfig.fromJson(Map<String, dynamic> json) {
    return SessionConfig(
      collaborativeMode: json['collaborativeMode'] ?? true,
      exclusiveMode: json['exclusiveMode'] ?? false,
      allowSpectators: json['allowSpectators'] ?? true,
      requireApproval: json['requireApproval'] ?? false,
      maxDurationMinutes: json['maxDurationMinutes'],
      maxParticipants: json['maxParticipants'],
      maxDevices: json['maxDevices'],
      showOthersIntensity: json['showOthersIntensity'] ?? true,
      allowChat: json['allowChat'] ?? true,
    );
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'collaborativeMode': collaborativeMode,
      'exclusiveMode': exclusiveMode,
      'allowSpectators': allowSpectators,
      'requireApproval': requireApproval,
      if (maxDurationMinutes != null)
        'maxDurationMinutes': maxDurationMinutes,
      if (maxParticipants != null) 'maxParticipants': maxParticipants,
      if (maxDevices != null) 'maxDevices': maxDevices,
      'showOthersIntensity': showOthersIntensity,
      'allowChat': allowChat,
    };
  }

  /// Configuración por defecto (colaborativa)
  static const defaultConfig = SessionConfig();

  /// Configuración exclusiva (solo host controla)
  static const exclusiveConfig = SessionConfig(
    collaborativeMode: false,
    exclusiveMode: true,
    allowSpectators: false,
  );

  /// Configuración pública (cualquiera puede unirse)
  static const publicConfig = SessionConfig(
    collaborativeMode: true,
    requireApproval: false,
    allowSpectators: true,
  );

  /// Configuración privada (requiere aprobación)
  static const privateConfig = SessionConfig(
    collaborativeMode: false,
    requireApproval: true,
    allowSpectators: false,
  );
}

// ═══════════════════════════════════════════════════════════════
// Session Events
// ═══════════════════════════════════════════════════════════════

/// Eventos de sesión en tiempo real
abstract class SessionEvent {
  final String sessionId;
  final DateTime timestamp;

  SessionEvent({
    required this.sessionId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson();
}

/// Usuario se unió a la sesión
class UserJoinedEvent extends SessionEvent {
  final SessionParticipant participant;

  UserJoinedEvent({
    required super.sessionId,
    required this.participant,
  }) : super(timestamp: DateTime.now());

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'user_joined',
      'sessionId': sessionId,
      'participant': participant.toJson(),
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Usuario salió de la sesión
class UserLeftEvent extends SessionEvent {
  final String userId;

  UserLeftEvent({
    required super.sessionId,
    required this.userId,
  }) : super(timestamp: DateTime.now());

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'user_left',
      'sessionId': sessionId,
      'userId': userId,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Dispositivo agregado a la sesión
class DeviceAddedEvent extends SessionEvent {
  final SessionDevice device;

  DeviceAddedEvent({
    required super.sessionId,
    required this.device,
  }) : super(timestamp: DateTime.now());

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'device_added',
      'sessionId': sessionId,
      'device': device.toJson(),
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Dispositivo removido de la sesión
class DeviceRemovedEvent extends SessionEvent {
  final String deviceId;

  DeviceRemovedEvent({
    required super.sessionId,
    required this.deviceId,
  }) : super(timestamp: DateTime.now());

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'device_removed',
      'sessionId': sessionId,
      'deviceId': deviceId,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Comando de control enviado
class ControlCommandEvent extends SessionEvent {
  final String userId;
  final String deviceId;
  final double intensity;
  final String? commandType;

  ControlCommandEvent({
    required super.sessionId,
    required this.userId,
    required this.deviceId,
    required this.intensity,
    this.commandType,
  }) : super(timestamp: DateTime.now());

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'control_command',
      'sessionId': sessionId,
      'userId': userId,
      'deviceId': deviceId,
      'intensity': intensity,
      'commandType': commandType,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Mensaje de chat
class ChatMessageEvent extends SessionEvent {
  final String userId;
  final String message;

  ChatMessageEvent({
    required super.sessionId,
    required this.userId,
    required this.message,
  }) : super(timestamp: DateTime.now());

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'chat_message',
      'sessionId': sessionId,
      'userId': userId,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

// ═══════════════════════════════════════════════════════════════
// Ejemplos de Uso
// ═══════════════════════════════════════════════════════════════

/*
// Ejemplo 1: Crear sesión
final session = SharedSession.create(
  name: 'Movie Night',
  hostUserId: 'user-123',
  config: SessionConfig.publicConfig,
);

// Ejemplo 2: Unir participante
final participant = SessionParticipant(
  userId: 'user-456',
  displayName: 'Alice',
  joinedAt: DateTime.now(),
);

// Ejemplo 3: Agregar dispositivo
final device = SessionDevice(
  id: 'session-device-1',
  deviceId: 'buttplug-device-1',
  name: 'Lovense Nora',
  ownerId: 'user-456',
  isActive: true,
  currentIntensity: 0.0,
  addedAt: DateTime.now(),
);

// Ejemplo 4: Verificar permisos
if (session.canControl('user-456', 'device-1')) {
  // Enviar comando...
}

// Ejemplo 5: Serializar
final json = session.toJson();
final restored = SharedSession.fromJson(json);
*/
