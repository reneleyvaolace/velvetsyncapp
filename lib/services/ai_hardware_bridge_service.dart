// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/ai_hardware_bridge_service.dart
// Puente entre la IA y el Hardware físico
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device_sync_model.dart';
import '../models/toy_model.dart';
import '../utils/protocol_translator.dart';
import '../ble/ble_service.dart';
import '../ble/lvs_commands.dart';
import 'sync_service.dart';
import '../utils/logger.dart';

// ═══════════════════════════════════════════════════════════════
// Providers de Riverpod
// ═══════════════════════════════════════════════════════════════

/// Provider que expone el AIHardwareBridge como singleton
final aiHardwareBridgeProvider = Provider<AIHardwareBridge>((ref) {
  return AIHardwareBridge();
});

/// Provider que expone el estado del puente IA-Hardware
final aiBridgeStateProvider = StateProvider<AIBridgeState>((ref) {
  return AIBridgeState.disconnected;
});

/// Provider que expone el último evento de IA procesado
final lastProcessedAIEventProvider = StateProvider<DeviceSyncEvent?>((ref) => null);

// ═══════════════════════════════════════════════════════════════
// Estados del puente
// ═══════════════════════════════════════════════════════════════

enum AIBridgeState {
  /// Puente desconectado
  disconnected,
  
  /// Puente conectado y escuchando
  connected,
  
  /// Procesando evento de IA
  processing,
  
  /// Error en el procesamiento
  error,
}

// ═══════════════════════════════════════════════════════════════
// Guard de Precise Control
// ═══════════════════════════════════════════════════════════════

/// Resultado de la verificación del Guard
class PreciseControlGuardResult {
  /// Si el dispositivo admite control preciso (0-255)
  final bool isPrecise;
  
  /// Si el guard permitió el envío
  final bool allowed;
  
  /// Mensaje de razón si fue bloqueado
  final String? reason;
  
  /// Intensidad ajustada según el guard
  final int adjustedIntensity;

  const PreciseControlGuardResult({
    required this.isPrecise,
    required this.allowed,
    required this.reason,
    required this.adjustedIntensity,
  });

  factory PreciseControlGuardResult.allowed(int intensity, bool isPrecise) {
    return PreciseControlGuardResult(
      isPrecise: isPrecise,
      allowed: true,
      reason: null,
      adjustedIntensity: intensity,
    );
  }

  factory PreciseControlGuardResult.blocked(String reason, bool isPrecise) {
    return PreciseControlGuardResult(
      isPrecise: isPrecise,
      allowed: false,
      reason: reason,
      adjustedIntensity: 0,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// AI Hardware Bridge
// ═══════════════════════════════════════════════════════════════

/// Servicio puente que conecta los eventos de IA con el hardware físico
/// 
/// Escucha eventos APPLY_AI_PROFILE del SyncService y los traduce
/// a comandos BLE usando el ProtocolTranslator.
class AIHardwareBridge extends ChangeNotifier {
  static final AIHardwareBridge _instance = AIHardwareBridge._internal();
  factory AIHardwareBridge() => _instance;
  AIHardwareBridge._internal();

  BleService? _bleService;
  SyncService? _syncService;
  ToyModel? _currentToy;
  
  AIBridgeState _state = AIBridgeState.disconnected;
  DeviceSyncEvent? _lastProcessedEvent;
  
  Timer? _executionTimer;
  bool _isExecuting = false;

  /// Estado actual del puente
  AIBridgeState get state => _state;

  /// Último evento de IA procesado
  DeviceSyncEvent? get lastProcessedEvent => _lastProcessedEvent;

  /// Si el puente está activo y escuchando
  bool get isActive => _state == AIBridgeState.connected;

  /// Si está ejecutando un comando actualmente
  bool get isExecuting => _isExecuting;

  /// Inicializa el puente IA-Hardware
  /// Debe llamarse después de que BleService y SyncService estén inicializados
  Future<void> init({
    BleService? bleService,
    SyncService? syncService,
  }) async {
    if (_state == AIBridgeState.connected) {
      debugPrint('[AIHardwareBridge] Ya está conectado');
      return;
    }

    debugPrint('[AIHardwareBridge] Iniciando puente IA-Hardware...');
    _setState(AIBridgeState.disconnected);

    try {
      _bleService = bleService;
      _syncService = syncService;

      // Registrar listener para eventos APPLY_AI_PROFILE
      _syncService?.addAiProfileListener(_handleAIProfile);

      _state = AIBridgeState.connected;
      lvsLog('Puente IA-Hardware conectado', tag: 'AI_BRIDGE');
      debugPrint('[AIHardwareBridge] Escuchando eventos APPLY_AI_PROFILE');
      
      notifyListeners();
    } catch (e) {
      debugPrint('[AIHardwareBridge] Error al iniciar: $e');
      lvsLog('Error al iniciar puente IA-Hardware: $e', tag: 'AI_BRIDGE');
      _setState(AIBridgeState.error);
      rethrow;
    }
  }

  /// Establece el modelo del juguete actualmente conectado
  void setCurrentToy(ToyModel? toy) {
    _currentToy = toy;
    debugPrint('[AIHardwareBridge] Juguete actual: ${toy?.name ?? 'Ninguno'}');
  }

  /// Manejador principal de eventos APPLY_AI_PROFILE
  /// 
  /// Procesa el intensity_map del evento y envía comandos BLE
  void _handleAIProfile(DeviceSyncEvent event) async {
    debugPrint('[AIHardwareBridge] Evento AI Profile recibido: ${event.id}');
    lvsLog('AI Profile: ${event.command} para ${event.deviceId}', tag: 'AI_BRIDGE');

    // Validar que tengamos un juguete conectado
    if (_currentToy == null) {
      debugPrint('[AIHardwareBridge] No hay juguete conectado');
      lvsLog('No hay juguete conectado para aplicar AI Profile', tag: 'AI_BRIDGE');
      return;
    }

    // Validar que el BLE esté conectado
    if (_bleService?.isConnected != true) {
      debugPrint('[AIHardwareBridge] BLE no está conectado');
      lvsLog('BLE no está conectado', tag: 'AI_BRIDGE');
      return;
    }

    _setState(AIBridgeState.processing);
    _isExecuting = true;

    try {
      // Extraer intensity_map del payload
      final intensityMap = _extractIntensityMap(event.payload);
      
      if (intensityMap.isEmpty) {
        debugPrint('[AIHardwareBridge] No hay intensidad en el evento');
        _setState(AIBridgeState.connected);
        _isExecuting = false;
        return;
      }

      debugPrint('[AIHardwareBridge] Intensity Map: $intensityMap');

      // Procesar cada valor en el mapa de intensidad
      await _executeIntensityMap(intensityMap, event);

      // Actualizar último evento procesado
      _lastProcessedEvent = event;
      notifyListeners();

      _setState(AIBridgeState.connected);
      lvsLog('AI Profile ejecutado exitosamente', tag: 'AI_BRIDGE');
    } catch (e) {
      debugPrint('[AIHardwareBridge] Error procesando evento: $e');
      lvsLog('Error procesando AI Profile: $e', tag: 'AI_BRIDGE');
      _setState(AIBridgeState.error);
    } finally {
      _isExecuting = false;
    }
  }

  /// Extrae el mapa de intensidades del payload
  /// 
  /// Soporta formatos:
  /// - {"intensity": 75}
  /// - {"intensity_ch1": 50, "intensity_ch2": 80}
  /// - {"intensity_map": {"ch1": 50, "ch2": 80}}
  Map<String, int> _extractIntensityMap(Map<String, dynamic> payload) {
    final intensityMap = <String, int>{};

    // Formato 1: intensity directo
    if (payload.containsKey('intensity')) {
      final intensity = _parseIntensity(payload['intensity']);
      if (intensity != null) {
        intensityMap['intensity'] = intensity;
      }
    }

    // Formato 2: intensity_ch1 e intensity_ch2
    if (payload.containsKey('intensity_ch1')) {
      final ch1 = _parseIntensity(payload['intensity_ch1']);
      if (ch1 != null) {
        intensityMap['intensity_ch1'] = ch1;
      }
    }

    if (payload.containsKey('intensity_ch2')) {
      final ch2 = _parseIntensity(payload['intensity_ch2']);
      if (ch2 != null) {
        intensityMap['intensity_ch2'] = ch2;
      }
    }

    // Formato 3: intensity_map anidado
    if (payload.containsKey('intensity_map')) {
      final map = payload['intensity_map'];
      if (map is Map<String, dynamic>) {
        if (map.containsKey('ch1')) {
          final ch1 = _parseIntensity(map['ch1']);
          if (ch1 != null) {
            intensityMap['intensity_ch1'] = ch1;
          }
        }
        if (map.containsKey('ch2')) {
          final ch2 = _parseIntensity(map['ch2']);
          if (ch2 != null) {
            intensityMap['intensity_ch2'] = ch2;
          }
        }
      }
    }

    // Formato 4: pattern (para patrones predefinidos)
    if (payload.containsKey('pattern')) {
      final pattern = _parseIntensity(payload['pattern']);
      if (pattern != null) {
        intensityMap['pattern'] = pattern;
      }
    }

    return intensityMap;
  }

  /// Parsea intensidad de cualquier tipo a int
  int? _parseIntensity(dynamic value) {
    if (value == null) return null;
    
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    
    return null;
  }

  /// Ejecuta el mapa de intensidades en el hardware
  Future<void> _executeIntensityMap(
    Map<String, int> intensityMap,
    DeviceSyncEvent event,
  ) async {
    final toy = _currentToy!;
    
    // GUARD: Verificar Precise Control
    final guardResult = _preciseControlGuard(
      toy: toy,
      intensity: intensityMap['intensity'] ?? 
                 intensityMap['intensity_ch1'] ?? 
                 0,
    );

    if (!guardResult.allowed) {
      debugPrint('[AIHardwareBridge] Guard bloqueó el envío: ${guardResult.reason}');
      lvsLog('Guard bloqueó AI: ${guardResult.reason}', tag: 'AI_BRIDGE');
      return;
    }

    // Si el dispositivo es Dual Channel, manejar canales separados
    if (toy.hasDualChannel) {
      await _executeDualChannel(intensityMap, toy, event);
    } else {
      await _executeSingleChannel(intensityMap, toy, event);
    }
  }

  /// Ejecuta comando para dispositivo Dual Channel
  Future<void> _executeDualChannel(
    Map<String, int> intensityMap,
    ToyModel toy,
    DeviceSyncEvent event,
  ) async {
    final ch1Intensity = intensityMap['intensity_ch1'] ?? 
                         intensityMap['intensity'] ?? 
                         50;
    
    final ch2Intensity = intensityMap['intensity_ch2'] ?? 
                         intensityMap['intensity'] ?? 
                         50;

    debugPrint('[AIHardwareBridge] Dual Channel: CH1=$ch1Intensity, CH2=$ch2Intensity');

    // Traducir protocolo para cada canal
    final ch1Command = ProtocolTranslator.translate(
      toy: toy,
      intensity: ch1Intensity,
      channel: 1,  // Canal 1: Empuje
    );

    final ch2Command = ProtocolTranslator.translate(
      toy: toy,
      intensity: ch2Intensity,
      channel: 2,  // Canal 2: Vibración
    );

    debugPrint('[AIHardwareBridge] CH1 Bytes: ${ch1Command.bytes}');
    debugPrint('[AIHardwareBridge] CH2 Bytes: ${ch2Command.bytes}');

    // Enviar comandos BLE
    await _sendBleCommand(ch1Command.bytes, 'AI CH1');
    await Future.delayed(const Duration(milliseconds: 50)); // Pequeño delay entre canales
    await _sendBleCommand(ch2Command.bytes, 'AI CH2');

    lvsLog('AI Dual: CH1=${ch1Command.description}, CH2=${ch2Command.description}', tag: 'AI_BRIDGE');
  }

  /// Ejecuta comando para dispositivo Single Channel
  Future<void> _executeSingleChannel(
    Map<String, int> intensityMap,
    ToyModel toy,
    DeviceSyncEvent event,
  ) async {
    final intensity = intensityMap['intensity'] ?? 
                      intensityMap['intensity_ch1'] ?? 
                      50;

    debugPrint('[AIHardwareBridge] Single Channel: intensity=$intensity');

    // Si hay patrón, usarlo
    if (intensityMap.containsKey('pattern')) {
      final pattern = intensityMap['pattern']!;
      await _executePattern(pattern, toy);
      return;
    }

    // Traducir protocolo
    final command = ProtocolTranslator.translate(
      toy: toy,
      intensity: intensity,
      channel: null,  // Ambos canales (o único canal)
    );

    debugPrint('[AIHardwareBridge] Bytes: ${command.bytes}');

    // Enviar comando BLE
    await _sendBleCommand(command.bytes, 'AI Single');

    lvsLog('AI Single: ${command.description}', tag: 'AI_BRIDGE');
  }

  /// Ejecuta un patrón predefinido
  Future<void> _executePattern(int pattern, ToyModel toy) async {
    debugPrint('[AIHardwareBridge] Ejecutando patrón: $pattern');

    // Usar LvsCommands para patrones (1-9)
    // El patrón se aplica al canal 1 por defecto
    final patternCommand = LvsCommands.ch1PatternFor(pattern);

    await _sendBleCommand(patternCommand, 'AI Pattern');

    lvsLog('AI Pattern: $pattern', tag: 'AI_BRIDGE');
  }

  /// Envía comando BLE
  Future<void> _sendBleCommand(List<int> bytes, String label) async {
    if (_bleService == null) {
      debugPrint('[AIHardwareBridge] BLE Service no está inicializado');
      return;
    }

    try {
      // Usar writeCommand del BleService
      await _bleService!.writeCommand(bytes, label: label, silent: false);
      debugPrint('[AIHardwareBridge] Comando enviado: $label');
    } catch (e) {
      debugPrint('[AIHardwareBridge] Error enviando comando BLE: $e');
      lvsLog('Error enviando comando BLE: $e', tag: 'AI_BRIDGE');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // GUARD: Precise Control
  // ═══════════════════════════════════════════════════════════════

  /// Guard que verifica si el juguete admite Precise Control (0-255)
  /// 
  /// [toy] - Modelo del juguete
  /// [intensity] - Intensidad deseada
  /// 
  /// Retorna [PreciseControlGuardResult] con el resultado de la verificación
  PreciseControlGuardResult _preciseControlGuard({
    required ToyModel toy,
    required int intensity,
  }) {
    // Verificar propiedad isPrecise del modelo
    if (toy.isPrecise) {
      // Dispositivo preciso: permite 0-255 directo
      debugPrint('[AIHardwareBridge Guard] Dispositivo PRECISE - Permitido 0-255');
      return PreciseControlGuardResult.allowed(intensity, true);
    }

    // Dispositivo no preciso: limitar a 0-100
    if (intensity > 100) {
      debugPrint('[AIHardwareBridge Guard] Dispositivo NO PRECISE - Intensidad $intensity > 100, ajustando a 100');
      return PreciseControlGuardResult(
        isPrecise: false,
        allowed: true,
        reason: null,
        adjustedIntensity: 100,  // Ajustar a máximo 100
      );
    }

    debugPrint('[AIHardwareBridge Guard] Dispositivo NO PRECISE - Permitido (intensidad $intensity <= 100)');
    return PreciseControlGuardResult.allowed(intensity, false);
  }

  /// Verificación adicional: cooldown y seguridad
  bool _safetyGuard() {
    // Verificar cooldown
    if (_bleService?.isCooldownActive == true) {
      debugPrint('[AIHardwareBridge Guard] Cooldown activo - Bloqueado');
      return false;
    }

    // Verificar estado de conexión
    if (_bleService?.isConnected != true) {
      debugPrint('[AIHardwareBridge Guard] BLE no conectado - Bloqueado');
      return false;
    }

    return true;
  }

  // ═══════════════════════════════════════════════════════════════
  // Métodos Públicos
  // ═══════════════════════════════════════════════════════════════

  /// Ejecuta manualmente un comando de IA
  Future<void> executeAICommand({
    required int intensity,
    int? channel,
    int? pattern,
  }) async {
    if (_currentToy == null) {
      debugPrint('[AIHardwareBridge] No hay juguete conectado');
      return;
    }

    final payload = <String, dynamic>{
      'intensity': intensity,
      if (channel != null) 'channel': channel,
      if (pattern != null) 'pattern': pattern,
    };

    final event = DeviceSyncEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      deviceId: _currentToy!.id,
      command: SyncCommands.applyAiProfile,
      payload: payload,
      timestamp: DateTime.now(),
    );

    _handleAIProfile(event);
  }

  /// Detiene la ejecución actual
  void stopExecution() {
    if (_isExecuting) {
      debugPrint('[AIHardwareBridge] Deteniendo ejecución...');
      _bleService?.emergencyStop();
      _isExecuting = false;
      _setState(AIBridgeState.connected);
    }
  }

  /// Establece el estado interno
  void _setState(AIBridgeState newState) {
    _state = newState;
    debugPrint('[AIHardwareBridge] Estado: ${newState.name}');
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════
  // Cleanup
  // ═══════════════════════════════════════════════════════════════

  /// Cierra el puente y limpia recursos
  @override
  void dispose() {
    debugPrint('[AIHardwareBridge] Cerrando puente...');
    
    _executionTimer?.cancel();
    _syncService?.removeAiProfileListener(_handleAIProfile);
    
    _state = AIBridgeState.disconnected;
    lvsLog('Puente IA-Hardware cerrado', tag: 'AI_BRIDGE');
    
    super.dispose();
  }
}
