// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/session_chat_service.dart
// Servicio de Chat para Sesiones Multi-Usuario
// 
// Chat en tiempo real dentro de sesiones compartidas,
// integrado con video y control de dispositivos.
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/logger.dart';

// ═══════════════════════════════════════════════════════════════
// Providers
// ═══════════════════════════════════════════════════════════════

final sessionChatServiceProvider = Provider<SessionChatService>((ref) {
  return SessionChatService();
});

final chatMessagesProvider = StateProvider<List<ChatMessage>>((ref) => []);
final isTypingProvider = StateProvider<Map<String, bool>>((ref) => {});

// ═══════════════════════════════════════════════════════════════
// Chat Message Model
// ═══════════════════════════════════════════════════════════════

/// Mensaje de chat en sesión
class ChatMessage {
  final String id;
  final String sessionId;
  final String userId;
  final String displayName;
  final String message;
  final DateTime timestamp;
  final MessageType type;
  final String? imageUrl;
  final String? videoUrl;

  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.displayName,
    required this.message,
    required this.timestamp,
    this.type = MessageType.text,
    this.imageUrl,
    this.videoUrl,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      sessionId: json['sessionId'] ?? '',
      userId: json['userId'] ?? '',
      displayName: json['displayName'] ?? 'Anonymous',
      message: json['message'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      type: MessageType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => MessageType.text,
      ),
      imageUrl: json['imageUrl'],
      videoUrl: json['videoUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'userId': userId,
      'displayName': displayName,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (videoUrl != null) 'videoUrl': videoUrl,
    };
  }

  /// ¿Es mensaje del usuario actual?
  bool isFromCurrentUser(String currentUserId) => userId == currentUserId;

  /// ¿Es mensaje de sistema?
  bool get isSystemMessage => type == MessageType.system;

  /// ¿Contiene media?
  bool get hasMedia => type == MessageType.image || type == MessageType.video;
}

/// Tipos de mensaje
enum MessageType {
  text,
  image,
  video,
  system,
  control, // Comandos de dispositivo
}

// ═══════════════════════════════════════════════════════════════
// Session Chat Service
// ═══════════════════════════════════════════════════════════════

/// Servicio de chat para sesiones multi-usuario
class SessionChatService extends ChangeNotifier {
  static final SessionChatService _instance = SessionChatService._internal();
  factory SessionChatService() => _instance;
  SessionChatService._internal();

  final List<ChatMessage> _messages = [];
  final Map<String, bool> _typingUsers = {};
  String? _currentSessionId;
  String? _currentUserId;
  final StreamController<ChatMessage> _messageController =
      StreamController<ChatMessage>.broadcast();

  // ═══════════════════════════════════════════════════════════════
  // Getters de Estado
  // ═══════════════════════════════════════════════════════════════

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  Stream<ChatMessage> get messageStream => _messageController.stream;
  Map<String, bool> get typingUsers => Map.unmodifiable(_typingUsers);
  String? get currentSessionId => _currentSessionId;

  // ═══════════════════════════════════════════════════════════════
  // Inicialización
  // ═══════════════════════════════════════════════════════════════

  /// Inicializar chat para sesión
  void initialize({
    required String sessionId,
    required String userId,
  }) {
    _currentSessionId = sessionId;
    _currentUserId = userId;
    lvsLog('Chat inicializado para sesión: $sessionId', tag: 'CHAT');
  }

  // ═══════════════════════════════════════════════════════════════
  // Envío de Mensajes
  // ═══════════════════════════════════════════════════════════════

  /// Enviar mensaje de texto
  Future<void> sendMessage(String message) async {
    if (_currentSessionId == null || _currentUserId == null) {
      lvsLog('Chat no inicializado', tag: 'CHAT');
      return;
    }

    if (message.trim().isEmpty) return;

    final chatMessage = ChatMessage(
      id: _generateId(),
      sessionId: _currentSessionId!,
      userId: _currentUserId!,
      displayName: 'User', // TODO: Get from user profile
      message: message,
      timestamp: DateTime.now(),
    );

    await _addMessage(chatMessage);
    lvsLog('Mensaje enviado: $message', tag: 'CHAT');
  }

  /// Enviar mensaje de sistema
  Future<void> sendSystemMessage(String message) async {
    final chatMessage = ChatMessage(
      id: _generateId(),
      sessionId: _currentSessionId!,
      userId: 'system',
      displayName: 'Sistema',
      message: message,
      timestamp: DateTime.now(),
      type: MessageType.system,
    );

    await _addMessage(chatMessage);
  }

  /// Enviar mensaje de control (comando de dispositivo)
  Future<void> sendControlMessage({
    required String deviceId,
    required double intensity,
    required String action,
  }) async {
    final chatMessage = ChatMessage(
      id: _generateId(),
      sessionId: _currentSessionId!,
      userId: 'system',
      displayName: 'Control',
      message: '$action dispositivo: ${(intensity * 100).round()}%',
      timestamp: DateTime.now(),
      type: MessageType.control,
    );

    await _addMessage(chatMessage);
  }

  /// Enviar imagen
  Future<void> sendImage(String imageUrl) async {
    final chatMessage = ChatMessage(
      id: _generateId(),
      sessionId: _currentSessionId!,
      userId: _currentUserId!,
      displayName: 'User',
      message: 'Imagen compartida',
      timestamp: DateTime.now(),
      type: MessageType.image,
      imageUrl: imageUrl,
    );

    await _addMessage(chatMessage);
  }

  // ═══════════════════════════════════════════════════════════════
  // Recepción de Mensajes
  // ═══════════════════════════════════════════════════════════════

  /// Agregar mensaje localmente
  Future<void> _addMessage(ChatMessage message) async {
    _messages.add(message);
    _messageController.add(message);
    notifyListeners();

    // TODO: Send to backend (Supabase Realtime / WebSocket)
  }

  /// Recibir mensaje de otro usuario
  void onMessageReceived(ChatMessage message) {
    _messages.add(message);
    _messageController.add(message);
    notifyListeners();
    lvsLog('Mensaje recibido de ${message.displayName}: ${message.message}', tag: 'CHAT');
  }

  // ═══════════════════════════════════════════════════════════════
  // Typing Indicators
  // ═══════════════════════════════════════════════════════════════

  /// Usuario está escribiendo
  void startTyping(String userId) {
    _typingUsers[userId] = true;
    notifyListeners();

    // Auto-clear después de 3 segundos
    Future.delayed(const Duration(seconds: 3), () {
      stopTyping(userId);
    });
  }

  /// Usuario dejó de escribir
  void stopTyping(String userId) {
    _typingUsers.remove(userId);
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════
  // Gestión de Mensajes
  // ═══════════════════════════════════════════════════════════════

  /// Limpiar historial
  void clearHistory() {
    _messages.clear();
    notifyListeners();
    lvsLog('Historial de chat limpiado', tag: 'CHAT');
  }

  /// Eliminar mensaje
  void deleteMessage(String messageId) {
    _messages.removeWhere((m) => m.id == messageId);
    notifyListeners();
  }

  /// Obtener mensajes por tipo
  List<ChatMessage> getMessagesByType(MessageType type) {
    return _messages.where((m) => m.type == type).toList();
  }

  /// Obtener mensajes de usuario
  List<ChatMessage> getMessagesFromUser(String userId) {
    return _messages.where((m) => m.userId == userId).toList();
  }

  // ═══════════════════════════════════════════════════════════════
  // Utilidades
  // ═══════════════════════════════════════════════════════════════

  String _generateId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Contar mensajes no leídos
  int getUnreadCount(String lastReadTimestamp) {
    final lastRead = DateTime.tryParse(lastReadTimestamp) ?? DateTime(2000);
    return _messages.where((m) => m.timestamp.isAfter(lastRead)).length;
  }

  @override
  void dispose() {
    _messageController.close();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════
// Ejemplos de Uso
// ═══════════════════════════════════════════════════════════════

/*
// Ejemplo 1: Inicializar
final chatService = SessionChatService();
chatService.initialize(
  sessionId: 'session-123',
  userId: 'user-456',
);

// Ejemplo 2: Enviar mensaje
await chatService.sendMessage('¡Hola a todos!');

// Ejemplo 3: Enviar mensaje de sistema
await chatService.sendSystemMessage('Usuario se unió a la sesión');

// Ejemplo 4: Enviar comando de control
await chatService.sendControlMessage(
  deviceId: 'device-1',
  intensity: 0.75,
  action: 'Vibrar',
);

// Ejemplo 5: Escuchar mensajes
chatService.messageStream.listen((message) {
  lvsLog('${message.displayName}: ${message.message}');
});

// Ejemplo 6: Typing indicator
chatService.startTyping('user-123');
// ... después de 3 segundos, auto-clear ...

// Ejemplo 7: Filtrar mensajes
final systemMessages = chatService.getMessagesByType(MessageType.system);
final userMessages = chatService.getMessagesFromUser('user-123');
*/
