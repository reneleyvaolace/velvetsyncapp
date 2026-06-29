// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/p2p/direct_websocket_transport.dart
// Transporte P2P Directo vía WebSocket (dart:io)
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:velvet_sync/services/p2p/p2p_connection_manager.dart';
import 'package:velvet_sync/utils/logger.dart';

// ═══════════════════════════════════════════════════════════════
// Direct WebSocket Transport
// ═══════════════════════════════════════════════════════════════

class DirectWebSocketTransport extends ChangeNotifier implements P2PTransport {
  HttpServer? _server;
  WebSocketChannel? _channel;
  P2PConnectionState _state = P2PConnectionState.idle;
  String? _lastError;
  String? _peerId;

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  final Completer<WebSocketChannel> _connectionCompleter = Completer();
  StreamSubscription<dynamic>? _channelSubscription;

  static const Duration _connectionTimeout = Duration(seconds: 5);

  // ═══════════════════════════════════════════════════════════════
  // Getters
  // ═══════════════════════════════════════════════════════════════

  @override
  P2PConnectionState get state => _state;
  String? get lastError => _lastError;
  String? get peerId => _peerId;
  bool get isListening => _server != null;
  bool get isConnected => _state == P2PConnectionState.p2p;

  @override
  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;

  // ═══════════════════════════════════════════════════════════════
  // Modo Host: Crear Servidor
  // ═══════════════════════════════════════════════════════════════

  /// Inicia un servidor WebSocket y retorna la info de conexión
  Future<Map<String, dynamic>?> listen() async {
    try {
      _setState(P2PConnectionState.connecting);

      final address = await _getLocalIp();
      final server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        0, // Puerto aleatorio
      );

      _server = server;
      final port = server.port;

      lvsLog('Servidor P2P escuchando en $address:$port', tag: 'WS');

      // Escuchar primera conexión entrante
      server.listen(
        (request) {
          if (request.uri.path == '/p2p') {
            WebSocketTransformer.upgrade(request).then((ws) {
              lvsLog('Cliente P2P conectado al servidor', tag: 'WS');
              final channel = IOWebSocketChannel(ws);
              _channel = channel;
              _peerId = 'remote';
              _setState(P2PConnectionState.p2p);
              _setupChannelListener();

              if (!_connectionCompleter.isCompleted) {
                _connectionCompleter.complete(channel);
              }
            }).catchError((e) {
              lvsLog('Error upgrading to WebSocket: $e', tag: 'WS');
              request.response.statusCode = 500;
              request.response.close();
            });
          } else {
            request.response.statusCode = 404;
            request.response.close();
          }
        },
        onError: (e) {
          _lastError = 'Server error: $e';
          lvsLog(_lastError!, tag: 'WS');
        },
      );

      return {
        'host': address,
        'port': port,
        'path': '/p2p',
        'session_id': DateTime.now().millisecondsSinceEpoch.toString(),
      };
    } catch (e) {
      _lastError = 'Error creando servidor P2P: $e';
      lvsLog(_lastError!, tag: 'WS');
      _setState(P2PConnectionState.error);
      return null;
    }
  }

  /// Espera a que el primer cliente se conecte
  Future<void> firstConnection() async {
    try {
      await _connectionCompleter.future.timeout(_connectionTimeout);
    } catch (e) {
      throw TimeoutException('No se recibió conexión entrante');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Modo Cliente: Conectar a Servidor Remoto
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<bool> connect(Map<String, dynamic> peerInfo) async {
    try {
      _setState(P2PConnectionState.connecting);

      final host = peerInfo['host'] as String? ?? '127.0.0.1';
      final port = peerInfo['port'] as int? ?? 0;
      final path = peerInfo['path'] as String? ?? '/p2p';

      if (port == 0) {
        _lastError = 'Puerto inválido en info de conexión';
        return false;
      }

      final uri = Uri.parse('ws://$host:$port$path');
      lvsLog('Conectando a servidor P2P: $uri', tag: 'WS');

      final channel = IOWebSocketChannel.connect(
        uri,
        pingInterval: const Duration(seconds: 10),
      );

      _channel = channel;
      _peerId = peerInfo['sender_id']?.toString() ?? 'remote';
      _setState(P2PConnectionState.p2p);

      _setupChannelListener();

      lvsLog('✅ Conectado a servidor P2P: $uri', tag: 'WS');
      return true;
    } catch (e) {
      _lastError = 'Error conectando a servidor P2P: $e';
      lvsLog(_lastError!, tag: 'WS');
      _setState(P2PConnectionState.error);
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Escucha de Mensajes
  // ═══════════════════════════════════════════════════════════════

  void _setupChannelListener() {
    _channelSubscription?.cancel();

    _channelSubscription = _channel?.stream.listen(
      (data) {
        try {
          if (data is String) {
            final message = jsonDecode(data) as Map<String, dynamic>;
            _messageController.add(message);
            lvsLog('📩 Mensaje P2P recibido: ${message['type']}', tag: 'WS');
          } else if (data is List<int>) {
            final decoded = utf8.decode(data);
            final message = jsonDecode(decoded) as Map<String, dynamic>;
            _messageController.add(message);
          }
        } catch (e) {
          lvsLog('Error decodificando mensaje P2P: $e', tag: 'WS');
        }
      },
      onError: (error) {
        _lastError = 'Error en canal P2P: $error';
        lvsLog(_lastError!, tag: 'WS');
        _setState(P2PConnectionState.error);
      },
      onDone: () {
        lvsLog('Canal P2P cerrado por el remoto', tag: 'WS');
        _setState(P2PConnectionState.idle);
      },
      cancelOnError: false,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Envío de Mensajes
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<void> send(Map<String, dynamic> message) async {
    if (_channel == null) {
      lvsLog('No hay canal P2P para enviar', tag: 'WS');
      return;
    }

    try {
      final encoded = jsonEncode(message);
      _channel!.sink.add(encoded);
    } catch (e) {
      _lastError = 'Error enviando mensaje P2P: $e';
      lvsLog(_lastError!, tag: 'WS');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Desconexión
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<void> disconnect() async {
    lvsLog('Desconectando transporte P2P', tag: 'WS');

    _channelSubscription?.cancel();
    _channelSubscription = null;

    try {
      await _channel?.sink.close();
    } catch (_) {}

    _channel = null;

    try {
      await _server?.close(force: true);
    } catch (_) {}

    _server = null;

    if (!_connectionCompleter.isCompleted) {
      _connectionCompleter.completeError(StateError('Disconnected'));
    }

    _setState(P2PConnectionState.idle);
    lvsLog('Transporte P2P desconectado', tag: 'WS');
  }

  // ═══════════════════════════════════════════════════════════════
  // Utilidades
  // ═══════════════════════════════════════════════════════════════

  Future<String> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      lvsLog('Error obteniendo IP local: $e', tag: 'WS');
    }
    return '127.0.0.1';
  }

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
