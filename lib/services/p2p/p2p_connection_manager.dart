// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/p2p/p2p_connection_manager.dart
// Gestor de Conexión P2P con Fallback a Supabase Broadcast
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velvet_sync/services/backend/supabase_service.dart';
import 'package:velvet_sync/services/p2p/p2p_signaling_service.dart';
import 'package:velvet_sync/services/p2p/direct_websocket_transport.dart';
import 'package:velvet_sync/services/p2p/supabase_broadcast_transport.dart';
import 'package:velvet_sync/utils/logger.dart';

// ═══════════════════════════════════════════════════════════════
// Providers
// ═══════════════════════════════════════════════════════════════

final p2pConnectionManagerProvider = Provider<P2PConnectionManager>((ref) {
  return P2PConnectionManager();
});

final p2pConnectionStateProvider = StateProvider<P2PConnectionState>((ref) => P2PConnectionState.idle);

// ═══════════════════════════════════════════════════════════════
// P2P Connection State
// ═══════════════════════════════════════════════════════════════

enum P2PConnectionState {
  idle,
  connecting,
  p2p,
  fallback,
  error,
}

// ═══════════════════════════════════════════════════════════════
// P2P Transport Abstract Interface
// ═══════════════════════════════════════════════════════════════

abstract class P2PTransport {
  Future<bool> connect(Map<String, dynamic> peerInfo);
  Future<void> send(Map<String, dynamic> message);
  Stream<Map<String, dynamic>> get onMessage;
  Future<void> disconnect();
  P2PConnectionState get state;
}

// ═══════════════════════════════════════════════════════════════
// P2P Connection Manager
// ═══════════════════════════════════════════════════════════════

class P2PConnectionManager extends ChangeNotifier {
  static final P2PConnectionManager _instance = P2PConnectionManager._internal();
  factory P2PConnectionManager() => _instance;
  P2PConnectionManager._internal();

  static const Duration _offerTimeout = Duration(seconds: 5);
  static const Duration _reconnectDelay = Duration(milliseconds: 500);

  P2PTransport? _activeTransport;
  P2PTransport? _fallbackTransport;
  P2pSignalingService? _signalingService;
  DirectWebSocketTransport? _directTransport;
  SupabaseService? _supabaseService;

  P2PConnectionState _state = P2PConnectionState.idle;
  String? _sessionId;
  String? _lastError;
  bool _isHost = false;

  final Completer<Map<String, dynamic>> _offerCompleter = Completer();
  final StreamController<Map<String, dynamic>> _commandController =
      StreamController<Map<String, dynamic>>.broadcast();

  StreamSubscription<Map<String, dynamic>>? _transportSubscription;
  Timer? _connectionTimer;

  // ═══════════════════════════════════════════════════════════════
  // Getters
  // ═══════════════════════════════════════════════════════════════

  P2PConnectionState get state => _state;
  String? get lastError => _lastError;
  String? get sessionId => _sessionId;
  bool get isHost => _isHost;
  bool get isP2PActive => _state == P2PConnectionState.p2p;
  bool get isConnected =>
      _state == P2PConnectionState.p2p || _state == P2PConnectionState.fallback;
  Stream<Map<String, dynamic>> get onCommandReceived => _commandController.stream;

  // ═══════════════════════════════════════════════════════════════
  // Inicialización
  // ═══════════════════════════════════════════════════════════════

  void initialize(SupabaseService supabaseService) {
    _supabaseService = supabaseService;
    _signalingService = P2pSignalingService();
    _fallbackTransport = SupabaseBroadcastTransport(supabaseService);
    lvsLog('P2PConnectionManager inicializado', tag: 'P2P');
  }

  // ═══════════════════════════════════════════════════════════════
  // Establecer Conexión
  // ═══════════════════════════════════════════════════════════════

  Future<bool> establishConnection({
    required String sessionId,
    required bool isHost,
    required String deviceId,
  }) async {
    _sessionId = sessionId;
    _isHost = isHost;
    _setState(P2PConnectionState.connecting);

    lvsLog(
      'Estableciendo conexión P2P para sesión $sessionId (${isHost ? "host" : "guest"})',
      tag: 'P2P',
    );

    try {
      if (_signalingService == null || _supabaseService == null) {
        _lastError = 'P2PConnectionManager no inicializado';
        lvsLog(_lastError!, tag: 'P2P');
        return false;
      }

      final signalingReady = _signalingService!.initialize(
        supabaseService: _supabaseService!,
        sessionId: sessionId,
        isHost: isHost,
        deviceId: deviceId,
        onP2pOffer: _handleP2pOffer,
        onP2pAnswer: _handleP2pAnswer,
        onP2pError: _handleP2pError,
      );

      if (!signalingReady) {
        lvsLog('No se pudo iniciar signaling, usando fallback', tag: 'P2P');
        return _activateFallback(sessionId);
      }

      if (isHost) {
        return _establishAsHost();
      } else {
        return _establishAsGuest();
      }
    } catch (e) {
      _lastError = 'Error en establishConnection: $e';
      lvsLog(_lastError!, tag: 'P2P');
      return _activateFallback(sessionId);
    }
  }

  Future<bool> _establishAsHost() async {
    if (_sessionId == null) return false;

    final transport = DirectWebSocketTransport();
    final listenResult = await transport.listen();

    if (listenResult != null) {
      _directTransport = transport;
      _signalingService!.sendOffer(listenResult);

      final connected = await _waitForDirectConnection(transport);

      if (connected) {
        _activeTransport = transport;
        _setupTransportListener(transport);
        _signalingService!.markConnected();
        _setState(P2PConnectionState.p2p);
        lvsLog('✅ P2P establecido como host', tag: 'P2P');
        return true;
      }

      lvsLog('⏱️ Timeout esperando conexión directa, usando fallback', tag: 'P2P');
      await transport.disconnect();
    }

    return _activateFallback(_sessionId!);
  }

  Future<bool> _establishAsGuest() async {
    if (_sessionId == null) return false;

    final offer = await _waitForOffer();

    if (offer != null) {
      final transport = DirectWebSocketTransport();
      final connected = await transport.connect(offer);

      if (connected) {
        _activeTransport = transport;
        _directTransport = transport;
        _setupTransportListener(transport);
        _signalingService!.sendAnswer({'status': 'connected'});
        _signalingService!.markConnected();
        _setState(P2PConnectionState.p2p);
        lvsLog('✅ P2P establecido como guest', tag: 'P2P');
        return true;
      }

      lvsLog('Falló conexión directa, usando fallback', tag: 'P2P');
      await transport.disconnect();
    } else {
      lvsLog('⏱️ No se recibió offer, usando fallback', tag: 'P2P');
    }

    return _activateFallback(_sessionId!);
  }

  Future<bool> _waitForDirectConnection(DirectWebSocketTransport transport) async {
    try {
      await transport.firstConnection();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> _waitForOffer() async {
    try {
      return await _offerCompleter.future.timeout(_offerTimeout);
    } on TimeoutException {
      return null;
    } catch (e) {
      return null;
    }
  }

  void _handleP2pOffer(Map<String, dynamic> offer) {
    if (!_offerCompleter.isCompleted) {
      _offerCompleter.complete(offer);
    }
  }

  void _handleP2pAnswer(Map<String, dynamic> answer) {
    lvsLog('Respuesta P2P recibida: $answer', tag: 'P2P');
  }

  void _handleP2pError(Map<String, dynamic> error) {
    _lastError = 'Error en signaling: ${error['reason']}';
    lvsLog(_lastError!, tag: 'P2P');
  }

  Future<bool> _activateFallback(String sessionId) async {
    lvsLog('Activando fallback a Supabase Broadcast', tag: 'P2P');

    try {
      final fallback = _fallbackTransport;
      if (fallback == null) return false;

      final connected = await fallback.connect({
        'sessionId': sessionId,
        'isHost': _isHost,
      });

      if (connected) {
        _activeTransport = fallback;
        _setupTransportListener(fallback);
        _setState(P2PConnectionState.fallback);
        lvsLog('Fallback a Supabase Broadcast activado', tag: 'P2P');
        return true;
      }

      _setState(P2PConnectionState.error);
      return false;
    } catch (e) {
      _lastError = 'Error activando fallback: $e';
      lvsLog(_lastError!, tag: 'P2P');
      _setState(P2PConnectionState.error);
      return false;
    }
  }

  void _setupTransportListener(P2PTransport transport) {
    _transportSubscription?.cancel();
    _transportSubscription = transport.onMessage.listen((msg) {
      if (msg['type'] == 'control_command') {
        _commandController.add(msg);
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // Envío de Comandos
  // ═══════════════════════════════════════════════════════════════

  Future<void> sendCommand({
    required int intensityCh1,
    required int intensityCh2,
    String? commandType,
  }) async {
    final transport = _activeTransport;

    if (transport == null) {
      lvsLog('No hay transporte activo para enviar comando', tag: 'P2P');
      return;
    }

    final payload = <String, dynamic>{
      'type': 'control_command',
      'intensity_ch1': intensityCh1,
      'intensity_ch2': intensityCh2,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    if (commandType != null) {
      payload['command_type'] = commandType;
    }

    try {
      await transport.send(payload);
      lvsLog(
        'Comando enviado: CH1=$intensityCh1 CH2=$intensityCh2 vía ${_state == P2PConnectionState.p2p ? "P2P" : "Broadcast"}',
        tag: 'P2P',
      );
    } catch (e) {
      _lastError = 'Error enviando comando: $e';
      lvsLog(_lastError!, tag: 'P2P');

      if (_state == P2PConnectionState.p2p && _sessionId != null) {
        lvsLog('P2P falló al enviar, reintentando con fallback', tag: 'P2P');
        await _activateFallback(_sessionId!);
        final fbTransport = _activeTransport;
        if (fbTransport != null) {
          await fbTransport.send(payload);
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Cerrar Conexión
  // ═══════════════════════════════════════════════════════════════

  Future<void> closeConnection() async {
    lvsLog('Cerrando conexión P2P', tag: 'P2P');

    _connectionTimer?.cancel();
    _transportSubscription?.cancel();

    if (_directTransport != null) {
      await _directTransport!.disconnect();
      _directTransport = null;
    }

    if (_activeTransport != null && _activeTransport != _directTransport) {
      await _activeTransport!.disconnect();
    }
    _activeTransport = null;

    _signalingService?.cancelSignaling();

    if (!_offerCompleter.isCompleted) {
      _offerCompleter.completeError(StateError('Connection closed'));
    }

    _setState(P2PConnectionState.idle);
    lvsLog('Conexión P2P cerrada', tag: 'P2P');
  }

  // ═══════════════════════════════════════════════════════════════
  // Reintento de Conexión
  // ═══════════════════════════════════════════════════════════════

  Future<bool> reconnection({
    required String sessionId,
    required bool isHost,
    required String deviceId,
  }) async {
    lvsLog('🔄 Reintentando conexión P2P...', tag: 'P2P');

    await closeConnection();
    await Future.delayed(_reconnectDelay);

    return establishConnection(
      sessionId: sessionId,
      isHost: isHost,
      deviceId: deviceId,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Estado
  // ═══════════════════════════════════════════════════════════════

  void _setState(P2PConnectionState newState) {
    _state = newState;
    notifyListeners();
    lvsLog('Estado P2P: $newState', tag: 'P2P');
  }

  @override
  void dispose() {
    closeConnection();
    _commandController.close();
    super.dispose();
  }
}
