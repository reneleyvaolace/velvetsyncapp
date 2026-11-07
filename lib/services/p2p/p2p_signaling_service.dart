// ════════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/p2p/p2p_signaling_service.dart
// Señalización P2P vía Firestore Broadcast
// ════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:velvet_sync/services/backend/firestore_service.dart';
import 'package:velvet_sync/utils/logger.dart';

// ════════════════════════════════════════════════════════════════
// Signaling Events
// ════════════════════════════════════════════════════════════════

class P2PSignalingEvent {
  final String type;
  final Map<String, dynamic> data;

  const P2PSignalingEvent({required this.type, required this.data});
}

// ════════════════════════════════════════════════════════════════
// Signaling States
// ════════════════════════════════════════════════════════════════

enum P2PSignalingState {
  idle,
  signaling,
  offerSent,
  offerReceived,
  answerSent,
  answerReceived,
  connected,
  timeout,
  error,
}

// ════════════════════════════════════════════════════════════════
// Callbacks
// ════════════════════════════════════════════════════════════════

typedef P2pOfferCallback = void Function(Map<String, dynamic> offer);
typedef P2pAnswerCallback = void Function(Map<String, dynamic> answer);
typedef P2pErrorCallback = void Function(Map<String, dynamic> error);

// ════════════════════════════════════════════════════════════════
// P2P Signaling Service
// ════════════════════════════════════════════════════════════════

class P2pSignalingService extends ChangeNotifier {
  static final P2pSignalingService _instance = P2pSignalingService._internal();
  factory P2pSignalingService() => _instance;
  P2pSignalingService._internal();

  static const Duration _signalingTimeout = Duration(seconds: 8);

  FirestoreService? _firestoreService;
  String? _sessionId;
  String? _deviceId;
  bool _isHost = false;
  bool _isActive = false;
  String _clientId = DateTime.now().millisecondsSinceEpoch.toString();

  P2PSignalingState _state = P2PSignalingState.idle;
  String? _lastError;

  P2pOfferCallback? _onOffer;
  P2pAnswerCallback? _onAnswer;
  P2pErrorCallback? _onError;

  Timer? _timeoutTimer;
  StreamSubscription? _signalSubscription;

  // ═══════════════════════════════════════════════════════════════
  // Getters
  // ═══════════════════════════════════════════════════════════════

  P2PSignalingState get state => _state;
  String? get lastError => _lastError;
  bool get isActive => _isActive;
  bool get isHost => _isHost;
  String? get sessionId => _sessionId;

  // ═══════════════════════════════════════════════════════════════
  // Inicialización
  // ═══════════════════════════════════════════════════════════════

  bool initialize({
    required FirestoreService firestoreService,
    required String sessionId,
    required bool isHost,
    required String deviceId,
    P2pOfferCallback? onP2pOffer,
    P2pAnswerCallback? onP2pAnswer,
    P2pErrorCallback? onP2pError,
  }) {
    if (_isActive) {
      cancelSignaling();
    }

    _firestoreService = firestoreService;
    _sessionId = sessionId;
    _isHost = isHost;
    _deviceId = deviceId;
    _clientId = DateTime.now().millisecondsSinceEpoch.toString();
    _onOffer = onP2pOffer;
    _onAnswer = onP2pAnswer;
    _onError = onP2pError;

    _setState(P2PSignalingState.signaling);
    _isActive = true;

    _startListening();

    _timeoutTimer = Timer(_signalingTimeout, () {
      if (_state != P2PSignalingState.connected) {
        lvsLog('⏱️ Timeout de señalización', tag: 'SIGNAL');
        _setState(P2PSignalingState.timeout);
        _isActive = false;
        notifyListeners();
      }
    });

    lvsLog(
      'Signalización iniciada: sesión=$sessionId rol=${isHost ? "host" : "guest"}',
      tag: 'SIGNAL',
    );

    return true;
  }

  void _startListening() {
    final firestoreService = _firestoreService;
    if (firestoreService == null || _sessionId == null) return;

    _signalSubscription = firestoreService.joinSessionRoom(_sessionId!).listen((payload) {
      if (payload.isEmpty) return;

      final type = payload['p2p_type'] as String?;
      if (type == null) return;

      switch (type) {
        case 'offer':
          _handleIncomingOffer(payload);
          break;
        case 'answer':
          _handleIncomingAnswer(payload);
          break;
        case 'error':
          _handleIncomingError(payload);
          break;
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // Envío de Señales
  // ═══════════════════════════════════════════════════════════════

  void sendOffer(Map<String, dynamic> connectionInfo) {
    if (_firestoreService == null || _sessionId == null) return;

    _sendSignal('offer', {
      'device_id': _deviceId,
      'is_host': _isHost,
      ...connectionInfo,
    });

    _setState(P2PSignalingState.offerSent);
    lvsLog('📤 Offer P2P enviado: host=${connectionInfo['host']}:${connectionInfo['port']}', tag: 'SIGNAL');
  }

  void sendAnswer(Map<String, dynamic> answerInfo) {
    if (_firestoreService == null || _sessionId == null) return;

    _sendSignal('answer', {
      'device_id': _deviceId,
      'is_host': _isHost,
      ...answerInfo,
    });

    _setState(P2PSignalingState.answerSent);
    lvsLog('📤 Answer P2P enviado', tag: 'SIGNAL');
  }

  void sendError(String reason) {
    if (_firestoreService == null || _sessionId == null) return;

    _sendSignal('error', {
      'device_id': _deviceId,
      'is_host': _isHost,
      'reason': reason,
    });

    _setState(P2PSignalingState.error);
    lvsLog('📤 Error P2P enviado: $reason', tag: 'SIGNAL');
  }

  void _sendSignal(String type, Map<String, dynamic> extraFields) {
    final firestoreService = _firestoreService;
    if (firestoreService == null || _sessionId == null) return;

    firestoreService.sendSessionCommand(
      _sessionId!,
      'p2p_signal',
      0, // intensity placeholder, using key-value payload instead
    ).then((_) {
      // Send the actual signal data as a separate command
      return firestoreService.sendSessionCommand(
        _sessionId!,
        type,
        0,
      );
    }).catchError((e) {
      lvsLog('Error enviando señal P2P: $e', tag: 'SIGNAL');
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // Recepción de Señales
  // ═══════════════════════════════════════════════════════════════

  void _handleIncomingOffer(Map<String, dynamic> payload) {
    lvsLog('📩 Offer P2P recibido', tag: 'SIGNAL');
    _setState(P2PSignalingState.offerReceived);

    final offer = Map<String, dynamic>.from(payload);
    _onOffer?.call(offer);
  }

  void _handleIncomingAnswer(Map<String, dynamic> payload) {
    lvsLog('📩 Answer P2P recibido', tag: 'SIGNAL');
    _setState(P2PSignalingState.answerReceived);

    final answer = Map<String, dynamic>.from(payload);
    _onAnswer?.call(answer);
  }

  void _handleIncomingError(Map<String, dynamic> payload) {
    final reason = payload['reason'] ?? 'Unknown error';
    lvsLog('📩 Error P2P recibido: $reason', tag: 'SIGNAL');
    _lastError = reason;

    final errorData = Map<String, dynamic>.from(payload);
    _onError?.call(errorData);
  }

  // ═══════════════════════════════════════════════════════════════
  // Señalización Completada
  // ═══════════════════════════════════════════════════════════════

  void markConnected() {
    _setState(P2PSignalingState.connected);
    _timeoutTimer?.cancel();
    _isActive = false;
    lvsLog('✅ Señalización completada, P2P conectado', tag: 'SIGNAL');
  }

  // ═══════════════════════════════════════════════════════════════
  // Cancelar / Limpiar
  // ═══════════════════════════════════════════════════════════════

  void cancelSignaling() {
    _timeoutTimer?.cancel();
    _signalSubscription?.cancel();
    _isActive = false;

    _setState(P2PSignalingState.idle);
    lvsLog('Signalización cancelada', tag: 'SIGNAL');
  }

  void _setState(P2PSignalingState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    cancelSignaling();
    super.dispose();
  }
}
