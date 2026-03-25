// ═══════════════════════════════════════════════════════════════
// Velvet Sync Platform · lib/core/types/command_types.dart
// Tipos de comandos para control de dispositivos
// ═══════════════════════════════════════════════════════════════

import '../types/device_types.dart';

/// Comando genérico para control de dispositivos
/// 
/// Este comando se traduce a comandos específicos según el protocolo
/// del dispositivo (LVS, Lovense, WeVibe, etc.)
class GenericCommand {
  /// ID del dispositivo destino
  final String deviceId;
  
  /// Tipo de comando
  final CommandType type;
  
  /// Canal al que aplica (para dispositivos dual-channel)
  final DeviceChannel channel;
  
  /// Intensidad del comando (0.0 - 1.0)
  final double intensity;
  
  /// Duración en milisegundos (null = indefinido)
  final int? durationMs;
  
  /// Parámetros adicionales específicos del comando
  final Map<String, dynamic>? parameters;
  
  /// Timestamp de creación del comando
  final DateTime timestamp;
  
  /// ID único del comando para tracking
  final String commandId;
  
  GenericCommand({
    required this.deviceId,
    required this.type,
    this.channel = DeviceChannel.single,
    required this.intensity,
    this.durationMs,
    this.parameters,
    DateTime? timestamp,
    String? commandId,
  })  : timestamp = timestamp ?? DateTime.now(),
        commandId = commandId ?? _generateId();
  
  /// Crear comando de vibración
  factory GenericCommand.vibrate({
    required String deviceId,
    required double intensity,
    DeviceChannel channel = DeviceChannel.single,
    int? durationMs,
  }) {
    return GenericCommand(
      deviceId: deviceId,
      type: CommandType.vibrate,
      channel: channel,
      intensity: intensity.clamp(0.0, 1.0),
      durationMs: durationMs,
    );
  }
  
  /// Crear comando de rotación
  factory GenericCommand.rotate({
    required String deviceId,
    required double intensity,
    DeviceChannel channel = DeviceChannel.single,
    int? durationMs,
  }) {
    return GenericCommand(
      deviceId: deviceId,
      type: CommandType.rotate,
      channel: channel,
      intensity: intensity.clamp(0.0, 1.0),
      durationMs: durationMs,
    );
  }
  
  /// Crear comando de oscilación
  factory GenericCommand.oscillate({
    required String deviceId,
    required double intensity,
    DeviceChannel channel = DeviceChannel.single,
    int? durationMs,
  }) {
    return GenericCommand(
      deviceId: deviceId,
      type: CommandType.oscillate,
      channel: channel,
      intensity: intensity.clamp(0.0, 1.0),
      durationMs: durationMs,
    );
  }
  
  /// Crear comando de parada de emergencia
  factory GenericCommand.stop({
    required String deviceId,
    DeviceChannel channel = DeviceChannel.single,
  }) {
    return GenericCommand(
      deviceId: deviceId,
      type: CommandType.stop,
      channel: channel,
      intensity: 0.0,
    );
  }
  
  /// Crear comando de patrón/predefinido
  factory GenericCommand.pattern({
    required String deviceId,
    required String patternId,
    DeviceChannel channel = DeviceChannel.single,
  }) {
    return GenericCommand(
      deviceId: deviceId,
      type: CommandType.pattern,
      channel: channel,
      intensity: 0.0,
      parameters: {'patternId': patternId},
    );
  }
  
  /// Convertir a mapa JSON
  Map<String, dynamic> toJson() {
    return {
      'commandId': commandId,
      'deviceId': deviceId,
      'type': type.name,
      'channel': channel.name,
      'intensity': intensity,
      'durationMs': durationMs,
      'parameters': parameters,
      'timestamp': timestamp.toIso8601String(),
    };
  }
  
  /// Crear desde JSON
  factory GenericCommand.fromJson(Map<String, dynamic> json) {
    return GenericCommand(
      deviceId: json['deviceId'] as String,
      type: CommandType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CommandType.vibrate,
      ),
      channel: DeviceChannel.values.firstWhere(
        (e) => e.name == json['channel'],
        orElse: () => DeviceChannel.single,
      ),
      intensity: (json['intensity'] as num?)?.toDouble() ?? 0.0,
      durationMs: json['durationMs'] as int?,
      parameters: json['parameters'] as Map<String, dynamic>?,
      timestamp: DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now(),
      commandId: json['commandId'] as String?,
    );
  }
  
  /// Copiar con cambios
  GenericCommand copyWith({
    String? deviceId,
    CommandType? type,
    DeviceChannel? channel,
    double? intensity,
    int? durationMs,
    Map<String, dynamic>? parameters,
    DateTime? timestamp,
    String? commandId,
  }) {
    return GenericCommand(
      deviceId: deviceId ?? this.deviceId,
      type: type ?? this.type,
      channel: channel ?? this.channel,
      intensity: intensity ?? this.intensity,
      durationMs: durationMs ?? this.durationMs,
      parameters: parameters ?? this.parameters,
      timestamp: timestamp ?? this.timestamp,
      commandId: commandId ?? this.commandId,
    );
  }
  
  @override
  String toString() {
    return 'GenericCommand(id: $commandId, device: $deviceId, type: $type, intensity: $intensity)';
  }
  
  static String _generateId() {
    return 'cmd_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }
}

/// Tipo de comando
enum CommandType {
  /// Vibración
  vibrate,
  
  /// Rotación
  rotate,
  
  /// Oscilación
  oscillate,
  
  /// Embestida (thrusting)
  thrust,
  
  /// Succión
  suction,
  
  /// Patrón/predefinido
  pattern,
  
  /// Secuencia de comandos
  sequence,
  
  /// Parada
  stop,
  
  /// Leer batería
  readBattery,
  
  /// Leer RSSI
  readRssi,
  
  /// Personalizado
  custom,
}

/// Secuencia de comandos para ejecutar en orden
class CommandSequence {
  /// ID de la secuencia
  final String sequenceId;
  
  /// Lista de comandos en orden
  final List<GenericCommand> commands;
  
  /// Si se debe repetir en bucle
  final bool loop;
  
  /// Duración total de la secuencia en ms
  final int? totalDurationMs;
  
  CommandSequence({
    required this.sequenceId,
    required this.commands,
    this.loop = false,
    this.totalDurationMs,
  });
  
  /// Crear secuencia desde una lista de comandos
  factory CommandSequence.fromCommands(List<GenericCommand> commands) {
    return CommandSequence(
      sequenceId: 'seq_${DateTime.now().millisecondsSinceEpoch}',
      commands: commands,
    );
  }
  
  /// Agregar comando a la secuencia
  void addCommand(GenericCommand command) {
    commands.add(command);
  }
  
  /// Obtener comando en índice específico
  GenericCommand? getCommandAt(int index) {
    if (index >= 0 && index < commands.length) {
      return commands[index];
    }
    return null;
  }
  
  /// Número de comandos en la secuencia
  int get length => commands.length;
  
  /// Convertir a mapa JSON
  Map<String, dynamic> toJson() {
    return {
      'sequenceId': sequenceId,
      'commands': commands.map((c) => c.toJson()).toList(),
      'loop': loop,
      'totalDurationMs': totalDurationMs,
    };
  }
  
  /// Crear desde JSON
  factory CommandSequence.fromJson(Map<String, dynamic> json) {
    final commands = (json['commands'] as List)
        .map((c) => GenericCommand.fromJson(c as Map<String, dynamic>))
        .toList();
    
    return CommandSequence(
      sequenceId: json['sequenceId'] as String,
      commands: commands,
      loop: json['loop'] as bool? ?? false,
      totalDurationMs: json['totalDurationMs'] as int?,
    );
  }
}

/// Patrón predefinido con secuencia temporal
class Pattern {
  /// ID único del patrón
  final String patternId;
  
  /// Nombre legible del patrón
  final String name;
  
  /// Descripción del patrón
  final String description;
  
  /// Secuencia de intensidades con timestamps
  final List<PatternStep> steps;
  
  /// Si el patrón se debe repetir
  final bool loop;
  
  Pattern({
    required this.patternId,
    required this.name,
    required this.description,
    required this.steps,
    this.loop = false,
  });
  
  /// Duración total del patrón en ms
  int get totalDurationMs {
    if (steps.isEmpty) return 0;
    return steps.last.timestampMs + (steps.last.durationMs ?? 0);
  }
  
  /// Convertir a comando genérico
  GenericCommand toCommand(String deviceId) {
    return GenericCommand.pattern(
      deviceId: deviceId,
      patternId: patternId,
    );
  }
}

/// Paso individual dentro de un patrón
class PatternStep {
  /// Timestamp relativo en ms desde el inicio
  final int timestampMs;
  
  /// Intensidad en este paso (0.0 - 1.0)
  final double intensity;
  
  /// Duración de este paso en ms
  final int? durationMs;
  
  PatternStep({
    required this.timestampMs,
    required this.intensity,
    this.durationMs,
  });
  
  /// Crear paso con duración fija
  factory PatternStep.fixed({
    required int timestampMs,
    required double intensity,
    required int durationMs,
  }) {
    return PatternStep(
      timestampMs: timestampMs,
      intensity: intensity,
      durationMs: durationMs,
    );
  }
  
  /// Convertir a mapa JSON
  Map<String, dynamic> toJson() {
    return {
      'timestampMs': timestampMs,
      'intensity': intensity,
      'durationMs': durationMs,
    };
  }
  
  /// Crear desde JSON
  factory PatternStep.fromJson(Map<String, dynamic> json) {
    return PatternStep(
      timestampMs: json['timestampMs'] as int,
      intensity: (json['intensity'] as num).toDouble(),
      durationMs: json['durationMs'] as int?,
    );
  }
}
