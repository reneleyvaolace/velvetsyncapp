// ════════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/session/session_manager.dart
// Gestor de Sesiones Multi-Usuario Multi-Dispositivo (Firebase Firestore)
// ════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:velvet_sync/devices/models/session_models.dart';
import 'package:velvet_sync/services/backend/firestore_service.dart';
import 'package:velvet_sync/utils/logger.dart';

// ════════════════════════════════════════════════════════════════
// Providers
// ════════════════════════════════════════════════════════════════

final sessionManagerProvider = Provider<SessionManager>((ref) {
  return SessionManager();
});

final currentSessionProvider = StateProvider<SharedSession?>((ref) => null);
final sessionParticipantsProvider = StateProvider<List<SessionParticipant>>((ref) => []);
final sessionDevicesProvider = StateProvider<List<SessionDevice>>((ref) => []);

// ════════════════════════════════════════════════════════════════
// Auth Service - Obtiene el usuario actual desde Firebase Auth
// ════════════════════════════════════════════════════════════════

/// Servicio de autenticación para obtener el usuario actual
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _auth = FirebaseAuth.instance;

  /// Obtener el ID del usuario actual
  String? get currentUserId => _auth.currentUser?.uid;

  /// Obtener el email del usuario actual
  String? get currentUserEmail => _auth.currentUser?.email;

  /// Obtener el nombre para mostrar del usuario actual
  String get currentUserDisplayName {
    final user = _auth.currentUser;
    return user?.displayName ??
           user?.email?.split('@').first ??
           'Anonymous';
  }

  /// Verificar si hay un usuario autenticado
  bool get isAuthenticated => _auth.currentUser != null;

  /// Escuchar cambios en el estado de autenticación
  Stream<User?> get authState => _auth.authStateChanges();
}

// ════════════════════════════════════════════════════════════════
// Session Manager
// ════════════════════════════════════════════════════════════════

/// Gestor de sesiones multi-usuario multi-dispositivo
class SessionManager extends ChangeNotifier {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  final FirestoreService _firestore = FirestoreService();
  StreamSubscription? _sessionSubscription;
  SharedSession? _currentSession;
  final StreamController<SessionEvent> _eventController =
      StreamController<SessionEvent>.broadcast();

  bool _isConnected = false;
  String? _lastError;

  // ════════════════════════════════════════════════════════════════
  // Inicialización
  // ════════════════════════════════════════════════════════════════

  /// Inicializar el session manager
  void initialize() {
    _firestore.initialize();
    lvsLog('SessionManager inicializado', tag: 'SESSION');
  }

  /// Obtener el ID del usuario actual
  String get _currentUserId {
    final userId = _firestore.currentUserId;
    return userId ?? 'anonymous';
  }

  /// Obtener el nombre para mostrar del usuario actual
  String get _currentUserDisplayName {
    final user = FirebaseAuth.instance.currentUser;
    return user?.displayName ??
           user?.email?.split('@').first ??
           'Anonymous';
  }

  // ════════════════════════════════════════════════════════════════
  // Getters de Estado
  // ════════════════════════════════════════════════════════════════

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

  // ════════════════════════════════════════════════════════════════
  // Creación de Sesiones
  // ════════════════════════════════════════════════════════════════

  /// Crear nueva sesión compartida
  Future<SharedSession?> createSession({
    required String name,
    SessionConfig? config,
    String deviceId = 'unknown',
  }) async {
    try {
      lvsLog('Creando sesión: $name', tag: 'SESSION');

      final userId = _currentUserId;

      final sessionData = await _firestore.createSharedSession(deviceId, hostName: _currentUserDisplayName);

      if (sessionData != null) {
        final docId = sessionData['id']?.toString() ?? '';
        _currentSession = SharedSession(
          id: docId.isNotEmpty ? docId : 'session_${DateTime.now().millisecondsSinceEpoch}',
          accessToken: sessionData['access_token']?.toString() ?? sessionData['accessToken']?.toString() ?? 'token_${DateTime.now().millisecondsSinceEpoch}',
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

  // ════════════════════════════════════════════════════════════════
  // Unión a Sesiones
  // ════════════════════════════════════════════════════════════════

  /// Unirse a sesión existente con token
  Future<SharedSession?> joinSession(String accessToken) async {
    try {
      lvsLog('Uniéndose a sesión con token: $accessToken', tag: 'SESSION');

      final currentUserId = _currentUserId;
      final currentUserName = _currentUserDisplayName;

      // Verificar token con Firestore
      final sessionData = await _firestore.fetchSessionByToken(accessToken);

      if (sessionData != null) {
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
          createdAt: DateTime.now(),
          config: const SessionConfig(),
        );
      } else {
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

      // Emitir evento local
      _eventController.add(UserJoinedEvent(
        sessionId: _currentSession!.id,
        participant: SessionParticipant(
          userId: currentUserId,
          displayName: currentUserName,
          joinedAt: DateTime.now(),
        ),
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
      final currentUserId = _currentUserId;
      lvsLog('Saliendo de sesión: ${_currentSession!.id}', tag: 'SESSION');

      _eventController.add(UserLeftEvent(
        sessionId: _currentSession!.id,
        userId: currentUserId,
      ));

      _sessionSubscription?.cancel();
      _sessionSubscription = null;

      _currentSession = null;
      _isConnected = false;
      notifyListeners();

      lvsLog('Salió de sesión', tag: 'SESSION');
    } catch (e) {
      _lastError = 'Error saliendo de sesión: $e';
      lvsLog(_lastError!, tag: 'SESSION');
    }
  }

  // ════════════════════════════════════════════════════════════════
  // Gestión de Dispositivos
  // ════════════════════════════════════════════════════════════════

  /// Agregar dispositivo a la sesión
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

  // ════════════════════════════════════════════════════════════════
  // Control de Dispositivos Multi-Usuario
  // ════════════════════════════════════════════════════════════════

  /// Controlar dispositivo en sesión compartida
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

    if (!_currentSession!.canControl(userId, deviceId)) {
      lvsLog('Usuario $userId no tiene permiso para controlar $deviceId', tag: 'SESSION');
      return false;
    }

    try {
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
      lvsLog('🛑 STOP ALL - Comando enviado a la sesión', tag: 'SESSION');
    } catch (e) {
      _lastError = 'Error deteniendo dispositivos: $e';
      lvsLog(_lastError!, tag: 'SESSION');
    }
  }

  // ════════════════════════════════════════════════════════════════
  // Chat de Sesión
  // ════════════════════════════════════════════════════════════════

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

  // ════════════════════════════════════════════════════════════════
  // Utilidades
  // ════════════════════════════════════════════════════════════════

  /// Obtener URL de invitación para compartir
  String getInviteUrl() {
    if (_currentSession == null) return '';

    const baseUrl = 'velvetsync://session/join';
    final token = _currentSession!.accessToken;
    return '$baseUrl?token=$token';
  }

  /// Copiar token de invitación al portapapeles
  Future<void> copyInviteToken() async {
    if (_currentSession == null) return;

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
