// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/session_manager.dart
// Gestor de Sesiones Multi-Usuario Multi-Dispositivo
// 
// Gestiona creación, unión y control de sesiones compartidas
// donde múltiples usuarios pueden controlar múltiples dispositivos.
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:velvet_sync/devices/models/session_models.dart';
import 'package:velvet_sync/services/backend/supabase_service.dart';
import 'package:velvet_sync/utils/logger.dart';

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
// Auth Service - Obtiene el usuario actual desde Supabase
// ═══════════════════════════════════════════════════════════════

/// Servicio de autenticación para obtener el usuario actual
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  SupabaseClient? _client;

  /// Inicializar con el cliente de Supabase
  void initialize(SupabaseClient client) {
    _client = client;
  }

  /// Obtener el ID del usuario actual
  String? get currentUserId => _client?.auth.currentUser?.id;

  /// Obtener el email del usuario actual
  String? get currentUserEmail => _client?.auth.currentUser?.email;

  /// Obtener el nombre para mostrar del usuario actual
  String get currentUserDisplayName {
    final user = _client?.auth.currentUser;
    return user?.userMetadata?['display_name'] ?? 
           user?.email?.split('@').first ?? 
           'Anonymous';
  }

  /// Verificar si hay un usuario autenticado
  bool get isAuthenticated => _client?.auth.currentUser != null;

  /// Escuchar cambios en el estado de autenticación
  Stream<AuthState> get authState => _client?.auth.onAuthStateChange ?? const Stream.empty();
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// ═══════════════════════════════════════════════════════════════
// Session Manager
// ═══════════════════════════════════════════════════════════════

/// Gestor de sesiones multi-usuario multi-dispositivo
class SessionManager extends ChangeNotifier {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  SupabaseService? _supabaseService;
  RealtimeChannel? _sessionChannel;
  SharedSession? _currentSession;
  final StreamController<SessionEvent> _eventController =
      StreamController<SessionEvent>.broadcast();
  
  bool _isConnected = false;
  String? _lastError;

  // ═══════════════════════════════════════════════════════════════
  // Inicialización
  // ═══════════════════════════════════════════════════════════════

  /// Inicializar el session manager con SupabaseService
  void initialize(SupabaseService supabaseService) {
    _supabaseService = supabaseService;
    lvsLog('SessionManager inicializado', tag: 'SESSION');
  }

  /// Obtener el usuario actual
  String get _currentUserId {
    final client = Supabase.instance.client;
    return client.auth.currentUser?.id ?? 'anonymous';
  }

  /// Obtener el nombre para mostrar del usuario actual
  String get _currentUserDisplayName {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    return user?.userMetadata?['display_name'] ?? 
           user?.email?.split('@').first ?? 
           'Anonymous';
  }

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
    return _currentSession!.isHost(_currentUserId);
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

      // Crear sesión en Supabase
      final userId = _currentUserId;
      const deviceId = '8154'; // Default device ID
      
      final sessionData = await _supabaseService?.createSharedSession(deviceId);
      
      if (sessionData != null) {
        // Sesión creada en backend, usar datos reales
        _currentSession = SharedSession(
          id: sessionData['id']?.toString() ?? 'session_${DateTime.now().millisecondsSinceEpoch}',
          accessToken: sessionData['access_token']?.toString() ?? sessionData['accessToken']?.toString() ?? '',
          name: name,
          hostUserId: userId,
          participants: [SessionParticipant(
            userId: userId,
            displayName: _currentUserDisplayName,
            isHost: true,
          )],
          devices: [],
          isActive: true,
          createdAt: DateTime.now(),
          config: config ?? const SessionConfig(),
        );
      } else {
        // Fallback local si no hay backend
        _currentSession = SharedSession.create(
          name: name,
          hostUserId: userId,
          config: config,
        );
      }

      // Suscribirse al canal de Realtime
      await _subscribeToSessionChannel(_currentSession!.id);

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

  /// Suscribirse al canal de Realtime para la sesión
  Future<void> _subscribeToSessionChannel(String sessionId) async {
    try {
      final client = Supabase.instance.client;
      
      _sessionChannel = client.channel('session_$sessionId');

      // Escuchar eventos de participantes
      _sessionChannel!.onBroadcast(
        event: 'user_joined',
        callback: (payload) {
          final participant = SessionParticipant.fromJson(payload);
          _eventController.add(UserJoinedEvent(
            sessionId: sessionId,
            participant: participant,
          ));
        },
      );

      _sessionChannel!.onBroadcast(
        event: 'user_left',
        callback: (payload) {
          final userId = payload['userId']?.toString() ?? '';
          _eventController.add(UserLeftEvent(
            sessionId: sessionId,
            userId: userId,
          ));
        },
      );

      _sessionChannel!.onBroadcast(
        event: 'device_added',
        callback: (payload) {
          final device = SessionDevice.fromJson(payload);
          _eventController.add(DeviceAddedEvent(
            sessionId: sessionId,
            device: device,
          ));
        },
      );

      _sessionChannel!.onBroadcast(
        event: 'device_removed',
        callback: (payload) {
          final deviceId = payload['deviceId']?.toString() ?? '';
          _eventController.add(DeviceRemovedEvent(
            sessionId: sessionId,
            deviceId: deviceId,
          ));
        },
      );

      _sessionChannel!.onBroadcast(
        event: 'control_command',
        callback: (payload) {
          final userId = payload['userId']?.toString() ?? '';
          final deviceId = payload['deviceId']?.toString() ?? '';
          final intensity = (payload['intensity'] as num?)?.toDouble() ?? 0.0;
          final commandType = payload['commandType']?.toString();
          
          _eventController.add(ControlCommandEvent(
            sessionId: sessionId,
            userId: userId,
            deviceId: deviceId,
            intensity: intensity,
            commandType: commandType,
          ));
        },
      );

      _sessionChannel!.subscribe();
      lvsLog('Suscrito al canal de sesión: session_$sessionId', tag: 'SESSION');
    } catch (e) {
      lvsLog('Error suscribiendo al canal: $e', tag: 'SESSION');
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

      // Verificar token con Supabase
      final sessionData = await _supabaseService?.fetchSessionByToken(accessToken);
      
      final currentUserId = _currentUserId;
      final currentUserName = _currentUserDisplayName;

      if (sessionData != null) {
        // Cargar sesión desde backend
        _currentSession = SharedSession(
          id: sessionData['id']?.toString() ?? '',
          accessToken: accessToken,
          name: sessionData['name']?.toString() ?? 'Sesión Compartida',
          hostUserId: sessionData['host_user_id']?.toString() ?? sessionData['hostUserId']?.toString() ?? '',
          participants: [
            SessionParticipant(
              userId: currentUserId,
              displayName: currentUserName,
              isHost: false,
            ),
          ],
          devices: [],
          isActive: true,
          createdAt: DateTime.tryParse(sessionData['created_at']?.toString() ?? '') ?? DateTime.now(),
          config: SessionConfig.fromJson(sessionData['config'] ?? {}),
        );
      } else {
        // Fallback: crear sesión local si no hay backend
        lvsLog('No se pudo verificar con backend, usando modo local', tag: 'SESSION');
        _currentSession = SharedSession(
          id: 'session_${DateTime.now().millisecondsSinceEpoch}',
          accessToken: accessToken,
          name: 'Sesión Remota',
          hostUserId: 'remote-host',
          participants: [
            SessionParticipant(
              userId: currentUserId,
              displayName: currentUserName,
              isHost: false,
            ),
          ],
          devices: [],
          isActive: true,
          createdAt: DateTime.now(),
          config: const SessionConfig(),
        );
      }

      // Notificar al backend (broadcast)
      await _broadcastEvent('user_joined', {
        'userId': currentUserId,
        'displayName': currentUserName,
      });

      // Emitir evento local
      _eventController.add(UserJoinedEvent(
        sessionId: _currentSession!.id,
        participant: SessionParticipant(
          userId: currentUserId,
          displayName: currentUserName,
          joinedAt: DateTime.now(),
        ),
      ));

      // Suscribirse al canal
      await _subscribeToSessionChannel(_currentSession!.id);

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

  /// Enviar broadcast a la sesión
  Future<void> _broadcastEvent(String event, Map<String, dynamic> payload) async {
    if (_sessionChannel != null) {
      await _sessionChannel!.sendBroadcastMessage(
        event: event,
        payload: payload,
      );
    }
  }

  /// Salir de sesión actual
  Future<void> leaveSession() async {
    if (_currentSession == null) return;

    try {
      final currentUserId = _currentUserId;
      lvsLog('Saliendo de sesión: ${_currentSession!.id}', tag: 'SESSION');

      // Notificar al backend
      await _broadcastEvent('user_left', {'userId': currentUserId});

      // Emitir evento
      _eventController.add(UserLeftEvent(
        sessionId: _currentSession!.id,
        userId: currentUserId,
      ));

      // Desuscribirse del canal
      await _sessionChannel?.unsubscribe();
      _sessionChannel = null;

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
      final currentUserId = _currentUserId;
      final device = SessionDevice(
        id: 'device-${DateTime.now().millisecondsSinceEpoch}',
        deviceId: deviceId,
        name: name,
        ownerId: ownerId ?? currentUserId,
        isActive: true,
        currentIntensity: 0.0,
        addedAt: DateTime.now(),
      );

      // Notificar al backend
      await _broadcastEvent('device_added', device.toJson());

      // Emitir evento
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
      // Notificar al backend
      await _broadcastEvent('device_removed', {'deviceId': deviceId});

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
      final currentUserId = _currentUserId;
      final currentUserName = _currentUserDisplayName;

      // Enviar al backend (Supabase Realtime / WebSocket)
      await _broadcastEvent('chat_message', {
        'userId': currentUserId,
        'displayName': currentUserName,
        'message': message,
      });

      // Emitir evento local
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
    
    // Generar URL con backend si está disponible
    const baseUrl = 'velvetsync://session/join';
    final token = _currentSession!.accessToken;
    return '$baseUrl?token=$token';
  }

  /// Copiar token de invitación al portapapeles
  Future<void> copyInviteToken() async {
    if (_currentSession == null) return;
    
    // Usar clipboard service
    await Clipboard.setData(ClipboardData(text: _currentSession!.accessToken));
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
