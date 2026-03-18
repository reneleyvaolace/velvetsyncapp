// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/link_service.dart
// Servicio de Deep Linking con app_links
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';

/// Servicio de Deep Linking para Velvet Sync
/// Escucha enlaces entrantes con el esquema velvetsync://
class LinkService extends ChangeNotifier {
  static final LinkService _instance = LinkService._internal();
  factory LinkService() => _instance;
  LinkService._internal();

  final AppLinks _appLinks = AppLinks();

  StreamSubscription? _linkSubscription;

  bool _isListening = false;
  String? _lastLink;
  final List<String> _linkHistory = [];

  /// Último deep link recibido
  String? get lastLink => _lastLink;

  /// Historial de links recibidos
  List<String> get linkHistory => List.unmodifiable(_linkHistory);

  /// Estado de escucha
  bool get isListening => _isListening;

  // ═══════════════════════════════════════════════════════════════
  // 🔒 SECURITY: Validación de parámetros de Deep Links
  // ═══════════════════════════════════════════════════════════════

  /// Valida formato de token de sesión
  bool _isValidToken(String token) {
    // Token debe ser alfanumérico, 16-255 caracteres
    return RegExp(r'^[a-zA-Z0-9_-]{16,255}$').hasMatch(token);
  }

  /// Valida formato de device ID
  bool _isValidDeviceId(String deviceId) {
    // Device ID: 1-50 caracteres alfanuméricos
    return RegExp(r'^[a-zA-Z0-9_-]{1,50}$').hasMatch(deviceId);
  }

  /// Valida intensidad (0-255)
  bool _isValidIntensity(String intensity) {
    final value = int.tryParse(intensity);
    return value != null && value >= 0 && value <= 255;
  }

  /// Inicia la escucha de deep links
  /// Debe llamarse después de que la app esté inicializada
  Future<void> init() async {
    if (_isListening) {
      lvsLog('Deep linking ya está escuchando', tag: 'LINK');
      return;
    }

    lvsLog('Iniciando escucha de deep links...', tag: 'LINK');

    try {
      // Escuchar links en frío (app cerrada o en background)
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        await _handleLink(initialLink);
        lvsLog('Link inicial detectado', tag: 'LINK');
      }

      // Escuchar links en caliente (app en primer plano)
      _linkSubscription = _appLinks.uriLinkStream.listen(
        (uri) async {
          if (uri != null) {
            await _handleLink(uri);
          }
        },
        onError: (err) {
          lvsLog('Error en stream: $err', tag: 'LINK');
          _logActivity('ERROR: $err');
        },
      );

      _isListening = true;
      lvsLog('Escucha de deep links activa', tag: 'LINK');
      _logActivity('Deep Linking iniciado');

      notifyListeners();
    } catch (e) {
      lvsLog('Error al iniciar deep linking: $e', tag: 'LINK');
      _logActivity('ERROR al iniciar: $e');
    }
  }

  /// Procesa un deep link recibido
  Future<void> _handleLink(Uri uri) async {
    lvsLog('Deep link recibido: ${uri.toString()}', tag: 'LINK');

    _lastLink = uri.toString();
    _linkHistory.add(_lastLink!);

    // Mantener historial limitado a 50 entradas
    if (_linkHistory.length > 50) {
      _linkHistory.removeAt(0);
    }

    _logActivity('LINK: $uri');

    // Parsear el link y ejecutar acción correspondiente
    await _parseAndExecute(uri);

    notifyListeners();
  }

  /// Parsea el deep link y ejecuta la acción correspondiente
  Future<void> _parseAndExecute(Uri uri) async {
    // Esquema: velvetsync://device/{action}?params
    // Ejemplos:
    // - velvetsync://device/connect?id=DEVICE_ID
    // - velvetsync://device/session?token=SESSION_TOKEN
    // - velvetsync://device/control?intensity=50

    if (uri.host != 'device') {
      lvsLog('Host no reconocido: ${uri.host}', tag: 'LINK');
      return;
    }

    final path = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    final params = uri.queryParameters;

    lvsLog('Path: $path, Params: $params', tag: 'LINK');
    _logActivity('ACTION: $path with $params');

    switch (path) {
      case 'connect':
        await _handleConnect(params);
        break;
      case 'session':
        await _handleSession(params);
        break;
      case 'control':
        await _handleControl(params);
        break;
      default:
        lvsLog('Acción no reconocida: $path', tag: 'LINK');
    }
  }

  /// Maneja acción de conexión: velvetsync://device/connect?id=xxx
  Future<void> _handleConnect(Map<String, String> params) async {
    final deviceId = params['id'];
    if (deviceId == null) {
      lvsLog('Connect sin ID de dispositivo', tag: 'LINK');
      return;
    }

    // 🔒 SECURITY: Validar formato de device ID
    if (!_isValidDeviceId(deviceId)) {
      lvsLog('⚠️ Device ID inválido: $deviceId (posible ataque)', tag: 'LINK');
      return;
    }

    lvsLog('Solicitud de conexión al dispositivo: $deviceId', tag: 'LINK');
    // Aquí se podría integrar con el BLE service para auto-conectar
    // ble.connectToDevice(deviceId: deviceId);
  }

  /// Maneja acción de sesión remota: velvetsync://device/session?token=xxx
  Future<void> _handleSession(Map<String, String> params) async {
    final token = params['token'];
    if (token == null) {
      lvsLog('Session sin token', tag: 'LINK');
      return;
    }

    // 🔒 SECURITY: Validar formato de token
    if (!_isValidToken(token)) {
      lvsLog('⚠️ Token inválido: ${token.substring(0, token.length.clamp(0, 8))}... (posible ataque)', tag: 'LINK');
      return;
    }

    lvsLog('Solicitud de sesión remota con token válido', tag: 'LINK');
    // Aquí se podría integrar con Supabase para unirse a sesión
    // supabase.joinSession(token);
  }

  /// Maneja acción de control directo: velvetsync://device/control?intensity=50
  Future<void> _handleControl(Map<String, String> params) async {
    final intensity = params['intensity'];
    if (intensity == null) {
      lvsLog('Control sin intensidad', tag: 'LINK');
      return;
    }

    // 🔒 SECURITY: Validar intensidad (0-255)
    if (!_isValidIntensity(intensity)) {
      lvsLog('⚠️ Intensidad inválida: $intensity (posible ataque)', tag: 'LINK');
      return;
    }

    lvsLog('Control de intensidad: $intensity', tag: 'LINK');
    // Aquí se podría enviar comando BLE directo
    // ble.setIntensity(int.parse(intensity));
  }

  /// Registra actividad en el log
  void _logActivity(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $message\n';

    // 🔒 SECURITY: No loguear en producción para evitar leakage
    if (kDebugMode) {
      lvsLog('Activity: $message', tag: 'LINK');
    }

    // Escribir a archivo (opcional, requiere permisos)
    _writeToLogFile(logEntry);
  }

  /// Escribe entrada al archivo activity.log
  Future<void> _writeToLogFile(String entry) async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        // Nota: Requiere configuración de path_provider y permisos
        // Implementación básica para referencia futura
        if (kDebugMode) {
          lvsLog('Log: $entry', tag: 'LINK');
        }
      } catch (e) {
        if (kDebugMode) {
          lvsLog('Error escribiendo log: $e', tag: 'LINK');
        }
      }
    }
  }

  /// Verifica si un link es de Velvet Sync
  static bool isVelvetSyncLink(Uri uri) {
    return uri.scheme == 'velvetsync';
  }

  /// Detiene la escucha de deep links
  @override
  void dispose() {
    _linkSubscription?.cancel();
    _isListening = false;
    lvsLog('Escucha detenida', tag: 'LINK');
    super.dispose();
  }
}
