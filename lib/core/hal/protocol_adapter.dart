// ═══════════════════════════════════════════════════════════════
// Velvet Sync Platform · lib/core/hal/protocol_adapter.dart
// Adaptador que traduce comandos genéricos a protocolos específicos
// ═══════════════════════════════════════════════════════════════

import 'package:velvet_sync/types/command_types.dart';

import 'package:velvet_sync/types/result_types.dart';
import 'package:velvet_sync/protocols/protocol_base.dart';

/// Adaptador de protocolos
/// 
/// Traduce comandos genéricos a comandos específicos según el protocolo
/// del dispositivo (LVS, Lovense, WeVibe, Buttplug, etc.)
class ProtocolAdapter {
  static final ProtocolAdapter _instance = ProtocolAdapter._internal();
  factory ProtocolAdapter() => _instance;
  ProtocolAdapter._internal();
  
  /// Protocolos registrados
  final Map<String, ProtocolBase> _protocols = {};
  
  /// Protocolo por defecto
  ProtocolBase? _defaultProtocol;
  
  /// Registrar un protocolo
  /// 
  /// [name] Nombre único del protocolo
  /// [protocol] Implementación del protocolo
  void registerProtocol(String name, ProtocolBase protocol) {
    _protocols[name] = protocol;
    protocol.adapter = this;
  }
  
  /// Obtener protocolo por nombre
  ProtocolBase? getProtocol(String name) {
    return _protocols[name];
  }
  
  /// Establecer protocolo por defecto
  void setDefaultProtocol(ProtocolBase protocol) {
    _defaultProtocol = protocol;
    protocol.adapter = this;
  }
  
  /// Obtener protocolo por defecto
  ProtocolBase? getDefaultProtocol() {
    return _defaultProtocol;
  }
  
  /// Traducir comando genérico a comando específico
  /// 
  /// [command] Comando genérico
  /// [protocolName] Nombre del protocolo a usar
  /// 
  /// Returns: Comando específico del protocolo
  Result<SpecificCommand, ProtocolError> translate(
    GenericCommand command, {
    String? protocolName,
  }) {
    ProtocolBase? protocol;
    
    if (protocolName != null) {
      protocol = _protocols[protocolName];
    } else {
      protocol = _defaultProtocol;
    }
    
    if (protocol == null) {
      return const Failure(ProtocolError.unknownProtocol);
    }
    
    return protocol.translate(command);
  }
  
  /// Traducir y enviar comando
  /// 
  /// [command] Comando genérico
  /// [protocolName] Nombre del protocolo
  /// [sendCallback] Callback para enviar el comando traducido
  Future<Result<void, DeviceError>> translateAndSend(
    GenericCommand command,
    String protocolName,
    Future<void> Function(SpecificCommand specificCommand) sendCallback,
  ) async {
    final translationResult = translate(command, protocolName: protocolName);
    
    return translationResult.fold(
      (error) => const Failure(DeviceError.unsupportedProtocol),
      (specificCommand) async {
        try {
          await sendCallback(specificCommand);
          return const Success(null);
        } catch (e) {
          return const Failure(DeviceError.connectionError);
        }
      },
    );
  }
  
  /// Obtener todos los protocolos registrados
  List<String> get registeredProtocols => _protocols.keys.toList();
  
  /// Verificar si un protocolo está registrado
  bool isProtocolRegistered(String name) => _protocols.containsKey(name);
  
  /// Limpiar todos los protocolos
  void clearProtocols() {
    _protocols.clear();
    _defaultProtocol = null;
  }
  
  /// Dispose
  void dispose() {
    clearProtocols();
  }
}

/// Comando específico de protocolo
/// 
/// Representa un comando ya traducido a formato específico
class SpecificCommand {
  /// Protocolo que generó este comando
  final String protocolName;
  
  /// Bytes del comando (para protocolos binarios)
  final List<int> bytes;
  
  /// Comando en formato texto (para protocolos basados en texto)
  final String? textCommand;
  
  /// Parámetros adicionales
  final Map<String, dynamic>? parameters;
  
  /// Metadata
  final Map<String, dynamic> metadata;
  
  SpecificCommand({
    required this.protocolName,
    required this.bytes,
    this.textCommand,
    this.parameters,
    this.metadata = const {},
  });
  
  /// Crear comando binario
  factory SpecificCommand.bytes({
    required String protocolName,
    required List<int> bytes,
    Map<String, dynamic>? parameters,
  }) {
    return SpecificCommand(
      protocolName: protocolName,
      bytes: bytes,
      parameters: parameters,
    );
  }
  
  /// Crear comando de texto
  factory SpecificCommand.text({
    required String protocolName,
    required String command,
    Map<String, dynamic>? parameters,
  }) {
    return SpecificCommand(
      protocolName: protocolName,
      bytes: command.codeUnits,
      textCommand: command,
      parameters: parameters,
    );
  }
  
  /// Convertir a bytes
  List<int> toBytes() {
    return bytes;
  }
  
  /// Convertir a hex string
  String toHexString() {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
  }
  
  @override
  String toString() {
    return 'SpecificCommand($protocolName: ${toHexString()})';
  }
}

/// Extensión para construir comandos específicos fácilmente
extension SpecificCommandBuilder on SpecificCommand {
  /// Agregar metadata
  SpecificCommand withMetadata(Map<String, dynamic> metadata) {
    return SpecificCommand(
      protocolName: protocolName,
      bytes: bytes,
      textCommand: textCommand,
      parameters: parameters,
      metadata: {...this.metadata, ...metadata},
    );
  }
  
  /// Verificar si tiene bytes
  bool get hasBytes => bytes.isNotEmpty;
  
  /// Verificar si tiene comando de texto
  bool get hasTextCommand => textCommand != null && textCommand!.isNotEmpty;
}
