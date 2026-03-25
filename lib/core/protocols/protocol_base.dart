// ═══════════════════════════════════════════════════════════════
// Velvet Sync Platform · lib/core/protocols/protocol_base.dart
// Clase base para todos los protocolos
// ═══════════════════════════════════════════════════════════════

import 'package:velvet_sync/types/command_types.dart';
import 'package:velvet_sync/types/device_types.dart';
import 'package:velvet_sync/types/result_types.dart';
import 'package:velvet_sync/hal/protocol_adapter.dart';

/// Clase base para todos los protocolos
/// 
/// Define la interfaz común que deben implementar todos los protocolos
/// (LVS, Lovense, WeVibe, Buttplug, etc.)
abstract class ProtocolBase {
  /// Nombre del protocolo
  String get name;
  
  /// Descripción del protocolo
  String get description;
  
  /// Versión del protocolo
  String get version;
  
  /// Transportes soportados (BLE, USB, Serial, etc.)
  List<ConnectionType> get supportedTransports;
  
  /// Features soportadas
  List<DeviceFeature> get supportedFeatures;
  
  /// Nivel de precisión
  ControlPrecision get precision;
  
  /// Referencia al adapter (se setea automáticamente)
  ProtocolAdapter? adapter;
  
  // ═══════════════════════════════════════════════════════════
  // MÉTODOS DE TRADUCCIÓN
  // ═══════════════════════════════════════════════════════════
  
  /// Traducir comando genérico a comando específico
  /// 
  /// [command] Comando genérico a traducir
  /// 
  /// Returns: [Success] con comando específico, [Failure] con error
  Result<SpecificCommand, ProtocolError> translate(GenericCommand command);
  
  /// Traducir comando de vibración
  /// 
  /// [intensity] Intensidad (0.0 - 1.0)
  /// [channel] Canal (para dual-channel)
  SpecificCommand translateVibrate(double intensity, {DeviceChannel channel = DeviceChannel.single});
  
  /// Traducir comando de rotación
  /// 
  /// [intensity] Intensidad (0.0 - 1.0)
  SpecificCommand translateRotate(double intensity);
  
  /// Traducir comando de parada
  SpecificCommand translateStop({DeviceChannel channel = DeviceChannel.single});
  
  /// Traducir comando de patrón
  /// 
  /// [patternId] ID del patrón
  SpecificCommand translatePattern(String patternId);
  
  // ═══════════════════════════════════════════════════════════
  // MÉTODOS DE ENVÍO
  // ═══════════════════════════════════════════════════════════
  
  /// Enviar comando específico al dispositivo
  /// 
  /// [command] Comando específico a enviar
  /// 
  /// Returns: [Success] si envía, [Failure] con error
  Future<Result<void, DeviceError>> send(SpecificCommand command);
  
  /// Enviar comandos en secuencia
  /// 
  /// [commands] Lista de comandos
  /// [delayMs] Delay entre comandos en ms
  Future<Result<void, DeviceError>> sendSequence(
    List<SpecificCommand> commands, {
    int delayMs = 50,
  }) async {
    for (final command in commands) {
      final result = await send(command);
      if (result.isFailure) {
        return result;
      }
      if (delayMs > 0) {
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
    return const Success(null);
  }
  
  // ═══════════════════════════════════════════════════════════
  // MÉTODOS DE INFORMACIÓN
  // ═══════════════════════════════════════════════════════════
  
  /// Obtener información del protocolo
  ProtocolInfo get info {
    return ProtocolInfo(
      name: name,
      description: description,
      version: version,
      supportedTransports: supportedTransports,
      supportedFeatures: supportedFeatures,
      precision: precision,
    );
  }
  
  // ═══════════════════════════════════════════════════════════
  // MÉTODOS DE CONFIGURACIÓN
  // ═══════════════════════════════════════════════════════════
  
  /// Configurar protocolo
  /// 
  /// [config] Configuración específica del protocolo
  Future<void> configure(Map<String, dynamic> config);
  
  /// Obtener configuración actual
  Map<String, dynamic> getConfiguration();
  
  // ═══════════════════════════════════════════════════════════
  // VALIDACIÓN
  // ═══════════════════════════════════════════════════════════
  
  /// Verificar si el protocolo soporta una feature
  bool supportsFeature(DeviceFeature feature) {
    return supportedFeatures.contains(feature);
  }
  
  /// Verificar si el protocolo soporta un transporte
  bool supportsTransport(ConnectionType transport) {
    return supportedTransports.contains(transport);
  }
  
  /// Verificar si el comando es válido para este protocolo
  bool isValidCommand(GenericCommand command) {
    // Verificar feature requerida
    DeviceFeature? requiredFeature;
    
    switch (command.type) {
      case CommandType.vibrate:
        requiredFeature = DeviceFeature.vibrate;
        break;
      case CommandType.rotate:
        requiredFeature = DeviceFeature.rotate;
        break;
      case CommandType.oscillate:
        requiredFeature = DeviceFeature.oscillate;
        break;
      case CommandType.thrust:
        requiredFeature = DeviceFeature.thrust;
        break;
      case CommandType.suction:
        requiredFeature = DeviceFeature.suction;
        break;
      default:
        return true; // Otros comandos siempre son válidos
    }
    
    return supportsFeature(requiredFeature);
  }
  
  // ═══════════════════════════════════════════════════════════
  // CLEANUP
  // ═══════════════════════════════════════════════════════════
  
  /// Liberar recursos
  void dispose();
}

/// Información del protocolo
class ProtocolInfo {
  /// Nombre
  final String name;
  
  /// Descripción
  final String description;
  
  /// Versión
  final String version;
  
  /// Transportes soportados
  final List<ConnectionType> supportedTransports;
  
  /// Features soportadas
  final List<DeviceFeature> supportedFeatures;
  
  /// Precisión
  final ControlPrecision precision;
  
  ProtocolInfo({
    required this.name,
    required this.description,
    required this.version,
    required this.supportedTransports,
    required this.supportedFeatures,
    required this.precision,
  });
  
  /// Convertir a mapa JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'version': version,
      'supportedTransports': supportedTransports.map((t) => t.name).toList(),
      'supportedFeatures': supportedFeatures.map((f) => f.name).toList(),
      'precision': precision.name,
    };
  }
  
  @override
  String toString() => 'ProtocolInfo($name v$version)';
}

/// Extensión para utilidad de construcción de comandos
extension ProtocolCommandBuilder on ProtocolBase {
  /// Crear comando de vibración directamente
  SpecificCommand vibrateCmd(double intensity, {DeviceChannel channel = DeviceChannel.single}) {
    return translateVibrate(intensity, channel: channel);
  }
  
  /// Crear comando de rotación directamente
  SpecificCommand rotateCmd(double intensity) {
    return translateRotate(intensity);
  }
  
  /// Crear comando de parada directamente
  SpecificCommand stopCmd({DeviceChannel channel = DeviceChannel.single}) {
    return translateStop(channel: channel);
  }
  
  /// Crear comando de patrón directamente
  SpecificCommand patternCmd(String patternId) {
    return translatePattern(patternId);
  }
}
