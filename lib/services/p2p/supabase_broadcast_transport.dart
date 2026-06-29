// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/p2p/supabase_broadcast_transport.dart
// Transporte Fallback vía Supabase Realtime Broadcast
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:velvet_sync/services/backend/supabase_service.dart';
import 'package:velvet_sync/services/p2p/p2p_connection_manager.dart';
import 'package:velvet_sync/utils/logger.dart';

// ═══════════════════════════════════════════════════════════════
// Supabase Broadcast Transport
// ═══════════════════════════════════════════════════════════════

class SupabaseBroadcastTransport extends ChangeNotifier implements P2PTransport {
  final SupabaseService _supabaseService;
  String? _sessionId;
  bool _isConnected = false;

  P2PConnectionState _state = P2PConnectionState.idle;
  String? _lastError;

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  // ═══════════════════════════════════════════════════════════════
  // Constructor
  // ═══════════════════════════════════════════════════════════════

  SupabaseBroadcastTransport(this._supabaseService);

  // ═══════════════════════════════════════════════════════════════
  // Getters
  // ═══════════════════════════════════════════════════════════════

  @override
  P2PConnectionState get state => _state;
  String? get lastError => _lastError;
  bool get isConnected => _isConnected;
  String? get sessionId => _sessionId;

  @override
  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;

  // ═══════════════════════════════════════════════════════════════
  // Conexión (unirse a sala de broadcast)
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<bool> connect(Map<String, dynamic> peerInfo) async {
    try {
      final sessionId = peerInfo['sessionId'] as String?;
      if (sessionId == null || sessionId.isEmpty) {
        _lastError = 'sessionId requerido para broadcast transport';
        lvsLog(_lastError!, tag: 'BROADCAST');
        _setState(P2PConnectionState.error);
        return false;
      }

      _sessionId = sessionId;
      _setState(P2PConnectionState.connecting);

      _supabaseService.joinControlRoom(sessionId, (payload, isSelf) {
        if (isSelf) return;

        // Filtrar solo mensajes de control_command
        if (payload.containsKey('type') && payload['type'] == 'control_command') {
          _messageController.add(payload);
        }
      });

      _isConnected = true;
      _setState(P2PConnectionState.fallback);
      lvsLog('✅ Broadcast conectado a sesión: $sessionId', tag: 'BROADCAST');
      return true;
    } catch (e) {
      _lastError = 'Error conectando broadcast: $e';
      lvsLog(_lastError!, tag: 'BROADCAST');
      _setState(P2PConnectionState.error);
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Envío de Mensajes
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<void> send(Map<String, dynamic> message) async {
    if (_sessionId == null || !_isConnected) {
      lvsLog('Broadcast no conectado, no se puede enviar', tag: 'BROADCAST');
      return;
    }

    try {
      final key1 = message['intensity_ch1'] as int?;
      final key2 = message['intensity_ch2'] as int?;

      if (key1 != null) {
        await _supabaseService.sendBroadcastCommand(
          _sessionId!,
          'intensity_ch1',
          key1,
        );
      }

      if (key2 != null) {
        await _supabaseService.sendBroadcastCommand(
          _sessionId!,
          'intensity_ch2',
          key2,
        );
      }
    } catch (e) {
      _lastError = 'Error enviando broadcast: $e';
      lvsLog(_lastError!, tag: 'BROADCAST');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Desconexión
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<void> disconnect() async {
    lvsLog('Desconectando broadcast transport', tag: 'BROADCAST');

    if (_sessionId != null) {
      _supabaseService.leaveControlRoom();
    }

    _sessionId = null;
    _isConnected = false;
    _setState(P2PConnectionState.idle);
    lvsLog('Broadcast transport desconectado', tag: 'BROADCAST');
  }

  // ═══════════════════════════════════════════════════════════════
  // Estado
  // ═══════════════════════════════════════════════════════════════

  void _setState(P2PConnectionState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _messageController.close();
    super.dispose();
  }
}
