// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/handy/handy_service.dart
// Servicio para Handy - API REST v3
// Basado en: https://www.handyfeeling.com/api/handy-rest/v3/docs/spec.yaml
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../utils/logger.dart';

// ═══════════════════════════════════════════════════════════════
// Handy Service
// ═══════════════════════════════════════════════════════════════

class HandyService extends ChangeNotifier {
  static final HandyService _instance = HandyService._internal();
  factory HandyService() => _instance;
  HandyService._internal();

  String? _apiKey;
  String? _connectionKey;
  String? _token;
  DateTime? _tokenExpiresAt;
  WebSocketChannel? _sseChannel;
  
  bool _isConnected = false;
  final HandyDeviceState _deviceState = HandyDeviceState.disconnected;
  HandyMode _currentMode = HandyMode.idle;
  
  final String _baseUrl = 'https://www.handyfeeling.com/api/handy-rest/v3';

  bool get isConnected => _isConnected;
  HandyDeviceState get deviceState => _deviceState;
  HandyMode get currentMode => _currentMode;

  // ═══════════════════════════════════════════════════════════
  // Autenticación
  // ═══════════════════════════════════════════════════════════

  void setApiKey(String apiKey) {
    _apiKey = apiKey;
    lvsLog('API Key configurada', tag: 'HANDY');
  }

  void setConnectionKey(String connectionKey) {
    _connectionKey = connectionKey;
    lvsLog('Connection Key configurada: $connectionKey', tag: 'HANDY');
  }

  Future<String> _getToken() async {
    // Si el token aún es válido, retornarlo
    if (_token != null && _tokenExpiresAt != null && 
        _tokenExpiresAt!.isAfter(DateTime.now())) {
      return _token!;
    }

    // Obtener nuevo token
    final url = Uri.parse('$_baseUrl/auth/token/issue?to=$_connectionKey&ttl=3600');
    final response = await http.get(
      url,
      headers: {'X-Api-Key': _apiKey ?? ''},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['result']['token'];
      _tokenExpiresAt = DateTime.parse(data['result']['expires_at']);
      lvsLog('Token obtenido, expira: $_tokenExpiresAt', tag: 'HANDY');
      return _token!;
    } else {
      throw Exception('Error obteniendo token: ${response.statusCode}');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Conexión
  // ═══════════════════════════════════════════════════════════

  Future<bool> isConnectedToDevice() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/connected'),
        headers: {
          'X-Connection-Key': _connectionKey ?? '',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _isConnected = data['result']['connected'] ?? false;
        notifyListeners();
        return _isConnected;
      }
      return false;
    } catch (e) {
      lvsLog('Error verificando conexión: $e', tag: 'HANDY');
      return false;
    }
  }

  Future<HandyDeviceInfo> getDeviceInfo() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/info'),
        headers: {
          'X-Connection-Key': _connectionKey ?? '',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return HandyDeviceInfo.fromJson(data['result']);
      }
      throw Exception('Error obteniendo información: ${response.statusCode}');
    } catch (e) {
      lvsLog('Error obteniendo información: $e', tag: 'HANDY');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Control de Modo
  // ═══════════════════════════════════════════════════════════

  Future<void> setMode(HandyMode mode) async {
    try {
      final token = await _getToken();
      final response = await http.put(
        Uri.parse('$_baseUrl/mode2'),
        headers: {
          'X-Connection-Key': _connectionKey ?? '',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'mode': mode.value}),
      );

      if (response.statusCode == 200) {
        _currentMode = mode;
        notifyListeners();
        lvsLog('Modo cambiado a: $mode', tag: 'HANDY');
      } else {
        throw Exception('Error cambiando modo: ${response.statusCode}');
      }
    } catch (e) {
      lvsLog('Error cambiando modo: $e', tag: 'HANDY');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Vibración (HVP)
  // ═══════════════════════════════════════════════════════════

  Future<void> vibrate(double intensity) async {
    try {
      // Activar modo vibración
      await setMode(HandyMode.vibrate);

      final token = await _getToken();
      final response = await http.put(
        Uri.parse('$_baseUrl/hvp/state'),
        headers: {
          'X-Connection-Key': _connectionKey ?? '',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'enabled': true,
          'amplitude': intensity.clamp(0.0, 1.0),
        }),
      );

      if (response.statusCode == 200) {
        lvsLog('Vibración: ${(intensity * 100).round()}%', tag: 'HANDY');
      } else {
        throw Exception('Error vibrando: ${response.statusCode}');
      }
    } catch (e) {
      lvsLog('Error vibrando: $e', tag: 'HANDY');
      rethrow;
    }
  }

  Future<void> stop() async {
    try {
      // Modo idle detiene todo
      await setMode(HandyMode.idle);
      lvsLog('Stop', tag: 'HANDY');
    } catch (e) {
      lvsLog('Error deteniendo: $e', tag: 'HANDY');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Slider (HAMP)
  // ═══════════════════════════════════════════════════════════

  Future<void> startHamp() async {
    try {
      await setMode(HandyMode.hamp);
      
      final token = await _getToken();
      final response = await http.put(
        Uri.parse('$_baseUrl/hamp/start'),
        headers: {
          'X-Connection-Key': _connectionKey ?? '',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        lvsLog('HAMP iniciado', tag: 'HANDY');
      }
    } catch (e) {
      lvsLog('Error iniciando HAMP: $e', tag: 'HANDY');
      rethrow;
    }
  }

  Future<void> setHampVelocity(double velocity) async {
    try {
      final token = await _getToken();
      final response = await http.put(
        Uri.parse('$_baseUrl/hamp/velocity'),
        headers: {
          'X-Connection-Key': _connectionKey ?? '',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'velocity': velocity.clamp(0.0, 1.0)}),
      );

      if (response.statusCode == 200) {
        lvsLog('HAMP velocidad: ${(velocity * 100).round()}%', tag: 'HANDY');
      }
    } catch (e) {
      lvsLog('Error cambiando velocidad HAMP: $e', tag: 'HANDY');
      rethrow;
    }
  }

  Future<void> setHampStroke(double min, double max) async {
    try {
      final token = await _getToken();
      final response = await http.put(
        Uri.parse('$_baseUrl/hamp/stroke'),
        headers: {
          'X-Connection-Key': _connectionKey ?? '',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'min': min.clamp(0.0, 1.0),
          'max': max.clamp(0.0, 1.0),
        }),
      );

      if (response.statusCode == 200) {
        lvsLog('HAMP stroke: $min - $max', tag: 'HANDY');
      }
    } catch (e) {
      lvsLog('Error cambiando stroke HAMP: $e', tag: 'HANDY');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Control Directo (HDSP)
  // ═══════════════════════════════════════════════════════════

  Future<void> moveToPosition(double position, {double? velocity, bool stopOnTarget = false}) async {
    try {
      await setMode(HandyMode.hdsp);

      final token = await _getToken();
      
      Map<String, dynamic> body;
      if (velocity != null) {
        // Posición absoluta + velocidad absoluta
        body = {
          'xa': (position * 100).clamp(0, 100),
          'va': (velocity * 100).clamp(0, 100),
          'stop_on_target': stopOnTarget,
        };
      } else {
        // Solo posición
        body = {
          'xa': (position * 100).clamp(0, 100),
        };
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/hdsp/xava'),
        headers: {
          'X-Connection-Key': _connectionKey ?? '',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        lvsLog('Mover a posición: ${(position * 100).round()}mm', tag: 'HANDY');
      }
    } catch (e) {
      lvsLog('Error moviendo: $e', tag: 'HANDY');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // SSE Events
  // ═══════════════════════════════════════════════════════════

  void startSSEStream(Function(HandyEvent) onEvent) {
    try {
      final uri = Uri.parse('$_baseUrl/sse');
      _sseChannel = WebSocketChannel.connect(uri);

      _sseChannel!.stream.listen((message) {
        // Parsear evento SSE
        final event = _parseSSEEvent(message);
        if (event != null) {
          onEvent(event);
        }
      });

      lvsLog('SSE stream iniciado', tag: 'HANDY');
    } catch (e) {
      lvsLog('Error iniciando SSE: $e', tag: 'HANDY');
    }
  }

  HandyEvent? _parseSSEEvent(dynamic message) {
    try {
      final data = jsonDecode(message);
      return HandyEvent.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  void stopSSEStream() {
    _sseChannel?.sink.close();
    _sseChannel = null;
    lvsLog('SSE stream detenido', tag: 'HANDY');
  }

  @override
  void dispose() {
    stopSSEStream();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════
// Modelos
// ═══════════════════════════════════════════════════════════════

enum HandyMode {
  hamp(0),
  hssp(1),
  hdsp(2),
  hsp(4),
  idle(7),
  vibrate(8);

  final int value;
  const HandyMode(this.value);
}

enum HandyDeviceState {
  disconnected,
  connected,
  error,
}

enum HandyEventType {
  deviceConnected,
  deviceDisconnected,
  modeChanged,
  batteryChanged,
  hampStateChanged,
  hvpStateChanged,
}

class HandyEvent {
  final HandyEventType type;
  final Map<String, dynamic> data;

  HandyEvent({required this.type, required this.data});

  factory HandyEvent.fromJson(Map<String, dynamic> json) {
    final eventType = json['type'] ?? '';
    return HandyEvent(
      type: HandyEventType.values.firstWhere(
        (e) => e.name == eventType,
        orElse: () => HandyEventType.deviceConnected,
      ),
      data: json['data'] ?? {},
    );
  }
}

class HandyDeviceInfo {
  final int fwStatus;
  final String fwVersion;
  final String hwModelName;
  final String sessionId;

  HandyDeviceInfo({
    required this.fwStatus,
    required this.fwVersion,
    required this.hwModelName,
    required this.sessionId,
  });

  factory HandyDeviceInfo.fromJson(Map<String, dynamic> json) {
    return HandyDeviceInfo(
      fwStatus: json['fw_status'] ?? 0,
      fwVersion: json['fw_version'] ?? '',
      hwModelName: json['hw_model_name'] ?? '',
      sessionId: json['session_id'] ?? '',
    );
  }
}
