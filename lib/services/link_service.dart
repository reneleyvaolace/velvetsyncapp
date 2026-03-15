// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/link_service.dart
// Servicio de Deep Linking con app_links
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

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

  /// Inicia la escucha de deep links
  /// Debe llamarse después de que la app esté inicializada
  Future<void> init() async {
    if (_isListening) {
      debugPrint('[LinkService] Ya está escuchando deep links');
      return;
    }

    debugPrint('[LinkService] Iniciando escucha de deep links...');
    
    try {
      // Escuchar links en frío (app cerrada o en background)
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        await _handleLink(initialLink);
        debugPrint('[LinkService] Link inicial detectado: $initialLink');
      }

      // Escuchar links en caliente (app en primer plano)
      _linkSubscription = _appLinks.uriLinkStream.listen(
        (uri) async {
          if (uri != null) {
            await _handleLink(uri);
          }
        },
        onError: (err) {
          debugPrint('[LinkService] Error en stream: $err');
          _logActivity('ERROR: $err');
        },
      );

      _isListening = true;
      debugPrint('[LinkService] Escucha de deep links activa');
      _logActivity('Deep Linking iniciado');

      notifyListeners();
    } catch (e) {
      debugPrint('[LinkService] Error al iniciar: $e');
      _logActivity('ERROR al iniciar: $e');
    }
  }

  /// Procesa un deep link recibido
  Future<void> _handleLink(Uri uri) async {
    debugPrint('[LinkService] Deep link recibido: $uri');
    
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
      debugPrint('[LinkService] Host no reconocido: ${uri.host}');
      return;
    }

    final path = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    final params = uri.queryParameters;

    debugPrint('[LinkService] Path: $path, Params: $params');
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
        debugPrint('[LinkService] Acción no reconocida: $path');
    }
  }

  /// Maneja acción de conexión: velvetsync://device/connect?id=xxx
  Future<void> _handleConnect(Map<String, String> params) async {
    final deviceId = params['id'];
    if (deviceId == null) {
      debugPrint('[LinkService] Connect sin ID de dispositivo');
      return;
    }
    debugPrint('[LinkService] Solicitud de conexión al dispositivo: $deviceId');
    // Aquí se podría integrar con el BLE service para auto-conectar
    // ble.connectToDevice(deviceId: deviceId);
  }

  /// Maneja acción de sesión remota: velvetsync://device/session?token=xxx
  Future<void> _handleSession(Map<String, String> params) async {
    final token = params['token'];
    if (token == null) {
      debugPrint('[LinkService] Session sin token');
      return;
    }
    debugPrint('[LinkService] Solicitud de sesión remota con token: $token');
    // Aquí se podría integrar con Supabase para unirse a sesión
    // supabase.joinSession(token);
  }

  /// Maneja acción de control directo: velvetsync://device/control?intensity=50
  Future<void> _handleControl(Map<String, String> params) async {
    final intensity = params['intensity'];
    if (intensity == null) {
      debugPrint('[LinkService] Control sin intensidad');
      return;
    }
    debugPrint('[LinkService] Control de intensidad: $intensity');
    // Aquí se podría enviar comando BLE directo
    // ble.setIntensity(int.parse(intensity));
  }

  /// Registra actividad en el log
  void _logActivity(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $message\n';
    
    // En producción, escribir a archivo activity.log
    // Para ahora, solo debug
    debugPrint('[LinkService Activity] $message');
    
    // Escribir a archivo (opcional, requiere permisos)
    _writeToLogFile(logEntry);
  }

  /// Escribe entrada al archivo activity.log
  Future<void> _writeToLogFile(String entry) async {
    if (!kIsWeb && Platform.isAndroid || Platform.isIOS) {
      try {
        // Nota: Requiere configuración de path_provider y permisos
        // Implementación básica para referencia futura
        debugPrint('[LinkService Log] $entry');
      } catch (e) {
        debugPrint('[LinkService] Error escribiendo log: $e');
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
    debugPrint('[LinkService] Escucha detenida');
    super.dispose();
  }
}
