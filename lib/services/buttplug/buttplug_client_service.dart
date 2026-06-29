// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/buttplug/buttplug_client_service.dart
// Cliente Buttplug para Intiface Central v3 (WebSocket)
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:velvet_sync/utils/logger.dart';

// ═══════════════════════════════════════════════════════════════
// Tipos de estado de conexión
// ═══════════════════════════════════════════════════════════════

enum ButtplugConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

// ═══════════════════════════════════════════════════════════════
// Información de dispositivo Buttplug (recibida vía DeviceAdded)
// ═══════════════════════════════════════════════════════════════

class ButtplugDeviceInfo {
  final int deviceIndex;
  final String deviceName;
  final Map<String, dynamic> deviceMessages;

  ButtplugDeviceInfo({
    required this.deviceIndex,
    required this.deviceName,
    required this.deviceMessages,
  });

  bool get supportsVibrate => deviceMessages.containsKey('VibrateCmd');
  bool get supportsRotate => deviceMessages.containsKey('RotateCmd');
  bool get supportsLinear => deviceMessages.containsKey('LinearCmd');
  bool get supportsStop => deviceMessages.containsKey('StopDeviceCmd');

  int get vibrateFeatureCount {
    final cmd = deviceMessages['VibrateCmd'];
    if (cmd is Map) return cmd['FeatureCount'] as int? ?? 1;
    return 1;
  }

  int get rotateFeatureCount {
    final cmd = deviceMessages['RotateCmd'];
    if (cmd is Map) return cmd['FeatureCount'] as int? ?? 1;
    return 1;
  }

  int get linearFeatureCount {
    final cmd = deviceMessages['LinearCmd'];
    if (cmd is Map) return cmd['FeatureCount'] as int? ?? 1;
    return 1;
  }

  @override
  String toString() => 'ButtplugDeviceInfo($deviceIndex: $deviceName)';
}

// ═══════════════════════════════════════════════════════════════
// Servicio Cliente Buttplug
// ═══════════════════════════════════════════════════════════════

class ButtplugClientService extends ChangeNotifier {
  static final ButtplugClientService _instance = ButtplugClientService._internal();
  factory ButtplugClientService() => _instance;
  ButtplugClientService._internal();

  // ── Configuración ──────────────────────────────────────────
  String _wsUrl = 'ws://localhost:12345';
  String _clientName = 'Velvet Sync';
  int _messageVersion = 3;

  // ── Estado ─────────────────────────────────────────────────
  ButtplugConnectionState _connectionState = ButtplugConnectionState.disconnected;
  ButtplugConnectionState get connectionState => _connectionState;

  final List<ButtplugDeviceInfo> _devices = [];
  List<ButtplugDeviceInfo> get devices => List.unmodifiable(_devices);

  int _nextId = 1;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _messageSub;

  // ── Reconnection ───────────────────────────────────────────
  bool _shouldReconnect = false;
  int _reconnectAttempt = 0;
  static const int _maxReconnectAttempts = 10;
  Timer? _reconnectTimer;

  // ── Ping Keep-Alive ────────────────────────────────────────
  Timer? _pingTimer;
  int _maxPingTimeMs = 0;

  // ── Completions ────────────────────────────────────────────
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};

  // ═══════════════════════════════════════════════════════════
  // Getters
  // ═══════════════════════════════════════════════════════════

  bool get isConnected => _connectionState == ButtplugConnectionState.connected;
  int get deviceCount => _devices.length;
  String get wsUrl => _wsUrl;

  // ═══════════════════════════════════════════════════════════
  // Configuración
  // ═══════════════════════════════════════════════════════════

  void setWsUrl(String url) {
    _wsUrl = url;
    lvsLog('Buttplug WebSocket URL configurada: $url', tag: 'BUTTPLUG');
  }

  void setClientName(String name) {
    _clientName = name;
  }

  // ═══════════════════════════════════════════════════════════
  // Conexión / Desconexión
  // ═══════════════════════════════════════════════════════════

  Future<void> connect() async {
    if (_connectionState == ButtplugConnectionState.connecting) {
      lvsLog('Ya hay una conexión en progreso', tag: 'BUTTPLUG');
      return;
    }

    _setState(ButtplugConnectionState.connecting);
    _shouldReconnect = true;

    try {
      lvsLog('Conectando a Intiface Central: $_wsUrl', tag: 'BUTTPLUG');

      final uri = Uri.parse(_wsUrl);
      _channel = WebSocketChannel.connect(uri);

      _messageSub = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      await _handshake();

      _reconnectAttempt = 0;
      _setState(ButtplugConnectionState.connected);
      lvsLog('Conectado a Intiface Central correctamente', tag: 'BUTTPLUG');
    } catch (e) {
      lvsLog('Error conectando a Intiface: $e', tag: 'BUTTPLUG');
      _setState(ButtplugConnectionState.error);
      _scheduleReconnect();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();

    _messageSub?.cancel();
    _messageSub = null;

    try {
      await _channel?.sink.close();
    } catch (_) {}

    _channel = null;

    _devices.clear();
    _pending.clear();

    _setState(ButtplugConnectionState.disconnected);
    lvsLog('Desconectado de Intiface Central', tag: 'BUTTPLUG');
  }

  // ═══════════════════════════════════════════════════════════
  // Handshake
  // ═══════════════════════════════════════════════════════════

  Future<void> _handshake() async {
    final completer = Completer<Map<String, dynamic>>();
    final id = _nextId++;

    _pending[id] = completer;

    _send([
      {
        'RequestServerInfo': {
          'Id': id,
          'ClientName': _clientName,
          'MessageVersion': _messageVersion,
        }
      }
    ]);

    final response = await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('Handshake timeout'),
    );

    final serverInfo = response['ServerInfo'] as Map<String, dynamic>?;
    if (serverInfo == null) {
      throw Exception('Respuesta ServerInfo inválida');
    }

    _messageVersion = serverInfo['MessageVersion'] as int? ?? 3;
    _maxPingTimeMs = serverInfo['MaximumPingTime'] as int? ?? 0;

    lvsLog('Handshake OK — Servidor: ${serverInfo['ServerName']}, '
        'Version: $_messageVersion, Ping: ${_maxPingTimeMs}ms',
        tag: 'BUTTPLUG');

    if (_maxPingTimeMs > 0) {
      _startPing();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Ping / Keep-Alive
  // ═══════════════════════════════════════════════════════════

  void _startPing() {
    _pingTimer?.cancel();
    final interval = math.max(_maxPingTimeMs ~/ 2, 1000);
    _pingTimer = Timer.periodic(Duration(milliseconds: interval), (_) {
      if (_connectionState == ButtplugConnectionState.connected) {
        _send([
          {'Ping': {'Id': _nextId++}}
        ]);
      }
    });
  }

  // ═══════════════════════════════════════════════════════════
  // Escaneo de dispositivos
  // ═══════════════════════════════════════════════════════════

  Future<void> startScanning() async {
    if (_connectionState != ButtplugConnectionState.connected) {
      lvsLog('No se puede escanear: no conectado', tag: 'BUTTPLUG');
      return;
    }

    final completer = Completer<Map<String, dynamic>>();
    final id = _nextId++;
    _pending[id] = completer;

    _send([
      {'StartScanning': {'Id': id}}
    ]);

    await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('StartScanning timeout'),
    );

    lvsLog('Escaneo iniciado', tag: 'BUTTPLUG');
  }

  Future<void> stopScanning() async {
    if (_connectionState != ButtplugConnectionState.connected) return;

    final completer = Completer<Map<String, dynamic>>();
    final id = _nextId++;
    _pending[id] = completer;

    _send([
      {'StopScanning': {'Id': id}}
    ]);

    await completer.future.timeout(const Duration(seconds: 10));
    lvsLog('Escaneo detenido', tag: 'BUTTPLUG');
  }

  // ═══════════════════════════════════════════════════════════
  // Comandos de control
  // ═══════════════════════════════════════════════════════════

  Future<void> vibrate(int deviceIndex, double speed, {int feature = 0}) async {
    if (_connectionState != ButtplugConnectionState.connected) return;

    final id = _nextId++;
    _send([
      {
        'VibrateCmd': {
          'Id': id,
          'DeviceIndex': deviceIndex,
          'Speeds': [
            {'Index': feature, 'Speed': speed.clamp(0.0, 1.0)}
          ],
        }
      }
    ]);
  }

  Future<void> rotate(int deviceIndex, double speed, {bool clockwise = true, int feature = 0}) async {
    if (_connectionState != ButtplugConnectionState.connected) return;

    final id = _nextId++;
    _send([
      {
        'RotateCmd': {
          'Id': id,
          'DeviceIndex': deviceIndex,
          'Rotations': [
            {'Index': feature, 'Speed': speed.clamp(0.0, 1.0), 'Clockwise': clockwise}
          ],
        }
      }
    ]);
  }

  Future<void> linear(int deviceIndex, int durationMs, double position, {int feature = 0}) async {
    if (_connectionState != ButtplugConnectionState.connected) return;

    final id = _nextId++;
    _send([
      {
        'LinearCmd': {
          'Id': id,
          'DeviceIndex': deviceIndex,
          'Vectors': [
            {'Index': feature, 'Duration': durationMs, 'Position': position.clamp(0.0, 1.0)}
          ],
        }
      }
    ]);
  }

  Future<void> stopDevice(int deviceIndex) async {
    if (_connectionState != ButtplugConnectionState.connected) return;

    final id = _nextId++;
    _send([
      {
        'StopDeviceCmd': {
          'Id': id,
          'DeviceIndex': deviceIndex,
        }
      }
    ]);
  }

  Future<void> stopAllDevices() async {
    if (_connectionState != ButtplugConnectionState.connected) return;

    final id = _nextId++;
    _send([
      {
        'StopAllDevices': {
          'Id': id,
        }
      }
    ]);
  }

  // ═══════════════════════════════════════════════════════════
  // Envío de mensajes
  // ═══════════════════════════════════════════════════════════

  void _send(List<Map<String, dynamic>> messages) {
    if (_channel == null) {
      lvsLog('No se puede enviar: canal nulo', tag: 'BUTTPLUG');
      return;
    }

    final json = jsonEncode(messages);
    lvsLog('>> $json', tag: 'BUTTPLUG');
    _channel!.sink.add(json);
  }

  // ═══════════════════════════════════════════════════════════
  // Recepción de mensajes
  // ═══════════════════════════════════════════════════════════

  void _onMessage(dynamic data) {
    try {
      final raw = data is String ? data : utf8.decode(data as List<int>);
      lvsLog('<< $raw', tag: 'BUTTPLUG');

      final messages = jsonDecode(raw) as List<dynamic>;
      for (final msg in messages) {
        _handleMessage(msg as Map<String, dynamic>);
      }
    } catch (e) {
      lvsLog('Error parseando mensaje: $e', tag: 'BUTTPLUG');
    }
  }

  void _handleMessage(Map<String, dynamic> msg) {
    for (final entry in msg.entries) {
      final type = entry.key;
      final payload = entry.value as Map<String, dynamic>;

      switch (type) {
        case 'ServerInfo':
          _completePending(payload);
          break;

        case 'Ok':
          _completePending(payload);
          break;

        case 'Error':
          _handleError(payload);
          break;

        case 'DeviceAdded':
          _handleDeviceAdded(payload);
          break;

        case 'DeviceRemoved':
          _handleDeviceRemoved(payload);
          break;

        case 'Ping':
          _completePending(payload);
          break;

        case 'ScanningFinished':
          _completePending(payload);
          lvsLog('Escaneo finalizado', tag: 'BUTTPLUG');
          break;

        default:
          lvsLog('Mensaje no manejado: $type', tag: 'BUTTPLUG');
      }
    }
  }

  void _handleDeviceAdded(Map<String, dynamic> payload) {
    final deviceIndex = payload['DeviceIndex'] as int;
    final deviceName = payload['DeviceName'] as String? ?? 'Unknown';
    final deviceMessages = payload['DeviceMessages'] as Map<String, dynamic>? ?? {};

    final info = ButtplugDeviceInfo(
      deviceIndex: deviceIndex,
      deviceName: deviceName,
      deviceMessages: deviceMessages,
    );

    _devices.add(info);
    lvsLog('Dispositivo añadido: $deviceName (idx: $deviceIndex)', tag: 'BUTTPLUG');
    notifyListeners();
  }

  void _handleDeviceRemoved(Map<String, dynamic> payload) {
    final deviceIndex = payload['DeviceIndex'] as int;
    _devices.removeWhere((d) => d.deviceIndex == deviceIndex);
    lvsLog('Dispositivo removido: idx $deviceIndex', tag: 'BUTTPLUG');
    notifyListeners();
  }

  void _handleError(Map<String, dynamic> payload) {
    final id = payload['Id'] as int?;
    final errorMessage = payload['ErrorMessage'] as String? ?? 'Unknown error';
    lvsLog('Error Buttplug (id: $id): $errorMessage', tag: 'BUTTPLUG');

    if (id != null && _pending.containsKey(id)) {
      _pending.remove(id)?.completeError(Exception(errorMessage));
    }
  }

  void _completePending(Map<String, dynamic> payload) {
    final id = payload['Id'] as int?;
    if (id != null && _pending.containsKey(id)) {
      _pending.remove(id)?.complete(payload);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Manejo de errores / cierre
  // ═══════════════════════════════════════════════════════════

  void _onError(dynamic error) {
    lvsLog('Error WebSocket: $error', tag: 'BUTTPLUG');
    _setState(ButtplugConnectionState.error);
    _scheduleReconnect();
  }

  void _onDone() {
    lvsLog('Conexión WebSocket cerrada', tag: 'BUTTPLUG');
    _completeAllPending('Connection closed');

    if (_shouldReconnect) {
      _scheduleReconnect();
    } else {
      _setState(ButtplugConnectionState.disconnected);
    }
  }

  void _completeAllPending(String reason) {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(Exception(reason));
      }
    }
    _pending.clear();
  }

  // ═══════════════════════════════════════════════════════════
  // Reconnection con exponential backoff
  // ═══════════════════════════════════════════════════════════

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    if (_connectionState == ButtplugConnectionState.connecting) return;

    _reconnectAttempt++;
    if (_reconnectAttempt > _maxReconnectAttempts) {
      lvsLog('Máximo de reintentos alcanzado ($_maxReconnectAttempts)', tag: 'BUTTPLUG');
      _setState(ButtplugConnectionState.error);
      return;
    }

    final delay = Duration(
      milliseconds: math.min(1000 * math.pow(2, _reconnectAttempt - 1).toInt(), 30000),
    );

    lvsLog('Reconexión en ${delay.inSeconds}s (intento $_reconnectAttempt)', tag: 'BUTTPLUG');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      try {
        await connect();
      } catch (e) {
        lvsLog('Reconexión fallida: $e', tag: 'BUTTPLUG');
      }
    });
  }

  void resetReconnect() {
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
  }

  // ═══════════════════════════════════════════════════════════
  // Utilidades
  // ═══════════════════════════════════════════════════════════

  ButtplugDeviceInfo? getDeviceByIndex(int index) {
    try {
      return _devices.firstWhere((d) => d.deviceIndex == index);
    } catch (_) {
      return null;
    }
  }

  ButtplugDeviceInfo? getDeviceByName(String name) {
    try {
      return _devices.firstWhere(
        (d) => d.deviceName.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  void _setState(ButtplugConnectionState state) {
    _connectionState = state;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════
  // Cleanup
  // ═══════════════════════════════════════════════════════════

  @override
  void dispose() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _messageSub?.cancel();
    _channel?.sink.close();
    _pending.clear();
    _devices.clear();
    super.dispose();
  }
}
