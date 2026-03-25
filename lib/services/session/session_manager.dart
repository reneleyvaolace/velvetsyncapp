// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/session_manager.dart
// Gestor de Sesiones Multi-Usuario Multi-Dispositivo
// 
// Gestiona creación, unión y control de sesiones compartidas
// donde múltiples usuarios pueden controlar múltiples dispositivos.
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../devices/models/session_models.dart';
import '../../utils/logger.dart';

// ═══════════════════════════════════════════════════════════════
// Providers
// ═══════════════════════════════════════════════════════════════

final sessionManagerProvider = Provider<SessionManager>((ref) {
  return SessionManager();
});

final currentSessionProvider = StateProvider<SharedSession?>((ref) => null);
final sessionParticipantsProvider = StateProvider<List<SessionParticipant>>((ref) => []);
final sessionDevicesProvider = StateProvider<List<SessionDevice>>((ref) => []);

// ═══════════════════════════════════════════════════════════════
// Session Manager
// ═══════════════════════════════════════════════════════════════

/// Gestor de sesiones multi-usuario multi-dispositivo
class SessionManager extends ChangeNotifier {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  SharedSession? _currentSession;
  final StreamController<SessionEvent> _eventController =
      StreamController<SessionEvent>.broadcast();
  
  bool _isConnected = false;
  String? _lastError;

  // ═══════════════════════════════════════════════════════════════
  // Getters de Estado
  // ═══════════════════════════════════════════════════════════════

  /// Sesión actual
  SharedSession? get currentSession => _currentSession;

  /// Stream de eventos de sesión
  Stream<SessionEvent> get eventStream => _eventController.stream;

  /// ¿Conectado a sesión?
  bool get isConnected => _isConnected;

  /// ¿Es host de la sesión actual?
  bool get isHost {
    if (_currentSession == null) return false;
    // TODO: Implement current user ID
    return _currentSession!.isHost('current-user');
  }

  /// Participantes en la sesión
  List<SessionParticipant> get participants =>
      _currentSession?.participants ?? [];

  /// Dispositivos en la sesión
  List<SessionDevice> get devices => _currentSession?.devices ?? [];

  /// Último error
  String? get lastError => _lastError;

  // ═══════════════════════════════════════════════════════════════
  // Creación de Sesiones
  // ═══════════════════════════════════════════════════════════════

  /// Crear nueva sesión compartida
  ///
  /// [name] - Nombre de la sesión
  /// [config] - Configuración de la sesión
  Future<SharedSession?> createSession({
    required String name,
    SessionConfig? config,
  }) async {
    try {
      lvsLog('Creando sesión: $name', tag: 'SESSION');

      // TODO: Get current user ID from auth service
      const currentUserId = 'current-user';

      _currentSession = SharedSession.create(
        name: name,
        hostUserId: currentUserId,
        config: config,
      );

      _isConnected = true;
      notifyListeners();

      lvsLog('✅ Sesión creada: ${_currentSession!.id}', tag: 'SESSION');
      return _currentSession;
    } catch (e) {
      _lastError = 'Error creando sesión: $e';
      lvsLog(_lastError!, tag: 'SESSION');
      notifyListeners();
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Unión a Sesiones
  // ═══════════════════════════════════════════════════════════════

  /// Unirse a sesión existente con token
  ///
  /// [accessToken] - Token de acceso a la sesión
  Future<SharedSession?> joinSession(String accessToken) async {
    try {
      lvsLog('Uniéndose a sesión con token: $accessToken', tag: 'SESSION');

      // TODO: Connect to Supabase realtime to join session
      // This is a placeholder implementation

      // Simular unión (remover cuando se implemente backend)
      await Future.delayed(const Duration(milliseconds: 500));

      // TODO: Get current user ID
      const currentUserId = 'current-user';

      final participant = SessionParticipant(
        userId: currentUserId,
        displayName: 'User',
        joinedAt: DateTime.now(),
      );

      // Emitir evento
      _eventController.add(UserJoinedEvent(
        sessionId: _currentSession?.id ?? 'unknown',
        participant: participant,
      ));

      _isConnected = true;
      notifyListeners();

      lvsLog('✅ Unido a sesión', tag: 'SESSION');
      return _currentSession;
    } catch (e) {
      _lastError = 'Error uniéndose a sesión: $e';
      lvsLog(_lastError!, tag: 'SESSION');
      notifyListeners();
      return null;
    }
  }

  /// Salir de sesión actual
  Future<void> leaveSession() async {
    if (_currentSession == null) return;

    try {
      lvsLog('Saliendo de sesión: ${_currentSession!.id}', tag: 'SESSION');

      // TODO: Get current user ID
      const currentUserId = 'current-user';

      // Emitir evento
      _eventController.add(UserLeftEvent(
        sessionId: _currentSession!.id,
        userId: currentUserId,
      ));

      _currentSession = null;
      _isConnected = false;
      notifyListeners();

      lvsLog('Salió de sesión', tag: 'SESSION');
    } catch (e) {
      _lastError = 'Error saliendo de sesión: $e';
      lvsLog(_lastError!, tag: 'SESSION');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Gestión de Dispositivos
  // ═══════════════════════════════════════════════════════════════

  /// Agregar dispositivo a la sesión
  ///
  /// [deviceId] - ID del dispositivo físico
  /// [name] - Nombre del dispositivo
  /// [ownerId] - ID del dueño del dispositivo (opcional)
  Future<SessionDevice?> addDevice({
    required String deviceId,
    required String name,
    String? ownerId,
  }) async {
    if (_currentSession == null) {
      lvsLog('No hay sesión activa para agregar dispositivo', tag: 'SESSION');
      return null;
    }

    try {
      final device = SessionDevice(
        id: 'device-${DateTime.now().millisecondsSinceEpoch}',
        deviceId: deviceId,
        name: name,
        ownerId: ownerId,
        isActive: true,
        currentIntensity: 0.0,
        addedAt: DateTime.now(),
      );

      // TODO: Add to session via backend
      // Placeholder: emit event
      _eventController.add(DeviceAddedEvent(
        sessionId: _currentSession!.id,
        device: device,
      ));

      lvsLog('✅ Dispositivo agregado: $name', tag: 'SESSION');
      return device;
    } catch (e) {
      _lastError = 'Error agregando dispositivo: $e';
      lvsLog(_lastError!, tag: 'SESSION');
      return null;
    }
  }

  /// Remover dispositivo de la sesión
  Future<void> removeDevice(String deviceId) async {
    if (_currentSession == null) return;

    try {
      // TODO: Remove from session via backend
      _eventController.add(DeviceRemovedEvent(
        sessionId: _currentSession!.id,
        deviceId: deviceId,
      ));

      lvsLog('Dispositivo removido: $deviceId', tag: 'SESSION');
    } catch (e) {
      _lastError = 'Error removiendo dispositivo: $e';
      lvsLog(_lastError!, tag: 'SESSION');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Control de Dispositivos Multi-Usuario
  // ═══════════════════════════════════════════════════════════════

  /// Controlar dispositivo en sesión compartida
  ///
  /// [deviceId] - ID del dispositivo a controlar
  /// [intensity] - Intensidad (0.0-1.0)
  /// [userId] - ID del usuario que envía el comando
  Future<bool> controlDevice({
    required String deviceId,
    required double intensity,
    required String userId,
    String? commandType,
  }) async {
    if (_currentSession == null) {
      lvsLog('No hay sesión activa para controlar dispositivo', tag: 'SESSION');
      return false;
    }

    // Verificar permisos
    if (!_currentSession!.canControl(userId, deviceId)) {
      lvsLog('Usuario $userId no tiene permiso para controlar $deviceId', tag: 'SESSION');
      return false;
    }

    try {
      // Emitir evento de control
      _eventController.add(ControlCommandEvent(
        sessionId: _currentSession!.id,
        userId: userId,
        deviceId: deviceId,
        intensity: intensity,
        commandType: commandType,
      ));

      lvsLog('Control: $deviceId @ ${(intensity * 100).round()}% by $userId', tag: 'SESSION');
      return true;
    } catch (e) {
      _lastError = 'Error controlando dispositivo: $e';
      lvsLog(_lastError!, tag: 'SESSION');
      return false;
    }
  }

  /// Detener todos los dispositivos en la sesión
  Future<void> stopAllDevices() async {
    if (_currentSession == null) return;

    try {

      lvsLog('🛑 STOP ALL - Todos los dispositivos detenidos', tag: 'SESSION');
    } catch (e) {
      _lastError = 'Error deteniendo dispositivos: $e';
      lvsLog(_lastError!, tag: 'SESSION');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Chat de Sesión
  // ═══════════════════════════════════════════════════════════════

  /// Enviar mensaje al chat de la sesión
  Future<void> sendChatMessage(String message) async {
    if (_currentSession == null) return;
    if (!_currentSession!.config.allowChat) {
      lvsLog('Chat no permitido en esta sesión', tag: 'SESSION');
      return;
    }

    try {
      // TODO: Get current user ID
      const currentUserId = 'current-user';

      _eventController.add(ChatMessageEvent(
        sessionId: _currentSession!.id,
        userId: currentUserId,
        message: message,
      ));

      lvsLog('Chat: $message', tag: 'SESSION');
    } catch (e) {
      _lastError = 'Error enviando mensaje: $e';
      lvsLog(_lastError!, tag: 'SESSION');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Utilidades
  // ═══════════════════════════════════════════════════════════════

  /// Obtener URL de invitación para compartir
  String getInviteUrl() {
    if (_currentSession == null) return '';
    
    // TODO: Generate proper URL with backend
    return 'velvetsync://session/join?token=${_currentSession!.accessToken}';
  }

  /// Copiar token de invitación al portapapeles
  Future<void> copyInviteToken() async {
    if (_currentSession == null) return;
    
    // TODO: Use clipboard service
    lvsLog('Token copiado: ${_currentSession!.accessToken}', tag: 'SESSION');
  }

  /// Limpiar sesión actual
  void clearSession() {
    _currentSession = null;
    _isConnected = false;
    _lastError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    leaveSession();
    _eventController.close();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════
// Ejemplos de Uso
// ═══════════════════════════════════════════════════════════════

/*
// Ejemplo 1: Crear sesión
final manager = SessionManager();
final session = await manager.createSession(
  name: 'Movie Night',
  config: SessionConfig.publicConfig,
);

// Ejemplo 2: Unirse a sesión
await manager.joinSession(session.accessToken);

// Ejemplo 3: Agregar dispositivo
await manager.addDevice(
  deviceId: 'buttplug-device-1',
  name: 'Lovense Nora',
  ownerId: 'user-123',
);

// Ejemplo 4: Controlar dispositivo (multi-usuario)
await manager.controlDevice(
  deviceId: 'device-1',
  intensity: 0.75,
  userId: 'user-456',
);

// Ejemplo 5: Escuchar eventos
manager.eventStream.listen((event) {
  switch (event) {
    case UserJoinedEvent():
      lvsLog('Usuario unido: ${event.participant.displayName}');
      break;
    case ControlCommandEvent():
      lvsLog('Control: ${event.deviceId} @ ${event.intensity}');
      break;
  }
});

// Ejemplo 6: Salir de sesión
await manager.leaveSession();
*/
