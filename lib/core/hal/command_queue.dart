// ═══════════════════════════════════════════════════════════════
// Velvet Sync Platform · lib/core/hal/command_queue.dart
// Cola de comandos para gestión asíncrona y ordenada
// ═══════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:velvet_sync/types/command_types.dart';
import 'package:velvet_sync/types/result_types.dart';


/// Cola de comandos para ejecución ordenada y asíncrona
/// 
/// Gestiona la ejecución de comandos de forma FIFO (First In, First Out)
/// con soporte para prioridades, timeouts y reintentos.
class CommandQueue {
  Future<void> Function(GenericCommand)? _executor;
  /// Cola interna de comandos
  final _queue = <_QueuedCommand>[];
  
  /// Si está procesando comandos actualmente
  bool _isProcessing = false;
  
  /// StreamController para eventos de la cola
  final _eventController = StreamController<QueueEvent>.broadcast();
  
  /// Stream de eventos de la cola
  Stream<QueueEvent> get eventStream => _eventController.stream;
  
  /// Número de comandos en cola
  int get length => _queue.length;
  
  /// Si la cola está vacía
  bool get isEmpty => _queue.isEmpty;
  
  /// Si la cola no está vacía
  bool get isNotEmpty => _queue.isNotEmpty;
  
  /// Timeout por defecto para comandos (ms)
  int defaultTimeoutMs = 3000;
  
  /// Número máximo de reintentos
  int maxRetries = 3;
  
  /// Delay entre reintentos (ms)
  int retryDelayMs = 100;
  
  /// Si está procesando comandos
  bool get isProcessing => _isProcessing;
  
  // ═══════════════════════════════════════════════════════════
  // ENCOLAR COMANDOS
  // ═══════════════════════════════════════════════════════════
  
  /// Encolar comando para ejecución
  /// 
  /// [command] Comando a ejecutar
  /// [priority] Prioridad del comando (mayor = más prioritario)
  /// [timeout] Timeout específico para este comando
  /// 
  /// Returns: Future que completa cuando el comando se ejecuta
  Future<Result<void, CommandError>> enqueue(
    GenericCommand command, {
    int priority = 0,
    Duration? timeout,
  }) async {
    final completer = Completer<Result<void, CommandError>>();
    
    final queuedCommand = _QueuedCommand(
      command: command,
      priority: priority,
      timeout: timeout ?? Duration(milliseconds: defaultTimeoutMs),
      completer: completer,
    );
    
    // Insertar según prioridad
    _insertByPriority(queuedCommand);
    
    // Iniciar procesamiento si no está activo
    if (!_isProcessing) {
      _processQueue();
    }
    
    _eventController.add(QueueCommandQueuedEvent(
      commandId: command.commandId,
      queueLength: _queue.length,
    ));
    
    return completer.future;
  }
  
  /// Encolar múltiples comandos
  /// 
  /// [commands] Lista de comandos
  /// [executeInOrder] Ejecutar en orden estricto
  Future<List<Result<void, CommandError>>> enqueueAll(
    List<GenericCommand> commands, {
    bool executeInOrder = true,
  }) async {
    final futures = <Future<Result<void, CommandError>>>[];
    
    for (final command in commands) {
      futures.add(enqueue(command));
    }
    
    if (executeInOrder) {
      // Esperar en orden
      final results = <Result<void, CommandError>>[];
      for (final future in futures) {
        results.add(await future);
      }
      return results;
    } else {
      // Esperar todos simultáneamente
      return Future.wait(futures);
    }
  }
  
  /// Encolar secuencia de comandos
  /// 
  /// [sequence] Secuencia a ejecutar
  Future<Result<void, CommandError>> enqueueSequence(
    CommandSequence sequence,
  ) async {
    final results = await enqueueAll(sequence.commands, executeInOrder: true);
    
    final hasErrors = results.any((r) => r.isFailure);
    
    if (hasErrors) {
      return const Failure(CommandError.executionFailed);
    }
    
    return const Success(null);
  }
  
  // ═══════════════════════════════════════════════════════════
  // GESTIÓN DE LA COLA
  // ═══════════════════════════════════════════════════════════
  
  /// Insertar comando según prioridad
  void _insertByPriority(_QueuedCommand command) {
    if (_queue.isEmpty) {
      _queue.add(command);
      return;
    }
    
    // Buscar posición según prioridad
    for (var i = 0; i < _queue.length; i++) {
      if (command.priority > _queue.elementAt(i).priority) {
        _queue.insert(i, command);
        return;
      }
    }
    
    // Agregar al final
    _queue.add(command);
  }
  
  /// Procesar cola de comandos
  Future<void> _processQueue() async {
    if (_isProcessing) return;
    if (_queue.isEmpty) return;
    
    _isProcessing = true;
    _eventController.add(QueueProcessingStarted());
    
    while (_queue.isNotEmpty) {
      final queued = _queue.removeAt(0);
      
      _eventController.add(QueueCommandExecutingEvent(
        commandId: queued.command.commandId,
        queueLength: _queue.length,
      ));
      
      try {
        // Ejecutar comando con timeout
        final result = await _executeWithTimeout(queued).timeout(
          queued.timeout,
          onTimeout: () => const Failure(CommandError.timeout),
        );
        
        queued.completer.complete(result);
        
        _eventController.add(QueueCommandCompletedEvent(
          commandId: queued.command.commandId,
          success: result.isSuccess,
        ));
      } catch (e) {
        queued.completer.complete(const Failure(CommandError.executionFailed));
        
        _eventController.add(QueueCommandFailedEvent(
          commandId: queued.command.commandId,
          error: e.toString(),
        ));
      }
    }
    
    _isProcessing = false;
    _eventController.add(QueueProcessingCompleted());
  }
  
  /// Ejecutar comando con reintentos
  Future<Result<void, CommandError>> _executeWithTimeout(
    _QueuedCommand queued,
  ) async {
    var attempts = 0;
    
    while (attempts <= maxRetries) {
      try {
        // Ejecutar comando
        await (_executor ?? _defaultExecutor)(queued.command);
        return const Success(null);
      } catch (e) {
        attempts++;
        
        if (attempts <= maxRetries) {
          // Esperar antes de reintentar
          await Future.delayed(Duration(milliseconds: retryDelayMs));
        }
      }
    }
    
    return const Failure(CommandError.maxRetriesExceeded);
  }
  
  /// Ejecutar comando individual (a implementar)
  // Future<void> _executeCommand(GenericCommand command) async {
  //   // Este método debe ser implementado por la clase que usa CommandQueue
  //   // Normalmente llamaría a DeviceInterface o ProtocolAdapter
  //   await Future.delayed(Duration.zero);
  // }
  
  // ═══════════════════════════════════════════════════════════
  // CONTROL DE LA COLA
  // ═══════════════════════════════════════════════════════════
  
  /// Limpiar cola
  void clear() {
    _queue.clear();
    _eventController.add(QueueCleared());
  }
  
  /// Pausar procesamiento
  void pause() {
    _isProcessing = false;
    _eventController.add(QueuePaused());
  }
  
  /// Reanudar procesamiento
  void resume() {
    if (_queue.isNotEmpty) {
      _processQueue();
    }
  }
  
  /// Obtener siguiente comando sin remover
  GenericCommand? peek() {
    if (_queue.isEmpty) return null;
    return _queue.first.command;
  }
  
  // ═══════════════════════════════════════════════════════════
  // CONFIGURACIÓN
  // ═══════════════════════════════════════════════════════════
  
  /// Establecer función de ejecución de comandos
  void setExecutor(Future<void> Function(GenericCommand) executor) {
    _executor = executor;
  }
  
  // ═══════════════════════════════════════════════════════════
  // CLEANUP
  // ═══════════════════════════════════════════════════════════
  
  /// Cerrar cola
  Future<void> dispose() async {
    clear();
    await _eventController.close();
  }
}

/// Comando encolado
class _QueuedCommand {
  /// Comando a ejecutar
  final GenericCommand command;
  
  /// Prioridad del comando
  final int priority;
  
  /// Timeout del comando
  final Duration timeout;
  
  /// Completer para completar el futuro
  final Completer<Result<void, CommandError>> completer;
  
  /// Número de intentos realizados
  int attempts = 0;
  
  _QueuedCommand({
    required this.command,
    required this.priority,
    required this.timeout,
    required this.completer,
  });
}

/// Errores de comando
enum CommandError {
  /// Timeout de ejecución
  timeout,
  
  /// Ejecución fallida
  executionFailed,
  
  /// Máximo de reintentos excedido
  maxRetriesExceeded,
  
  /// Comando inválido
  invalidCommand,
  
  /// Dispositivo no disponible
  deviceUnavailable,
  
  /// Cola llena
  queueFull,
  
  /// Cola vacía
  queueEmpty,
}

extension CommandErrorExtension on CommandError {
  String get message {
    switch (this) {
      case CommandError.timeout:
        return 'Timeout de ejecución';
      case CommandError.executionFailed:
        return 'Ejecución fallida';
      case CommandError.maxRetriesExceeded:
        return 'Máximo de reintentos excedido';
      case CommandError.invalidCommand:
        return 'Comando inválido';
      case CommandError.deviceUnavailable:
        return 'Dispositivo no disponible';
      case CommandError.queueFull:
        return 'Cola llena';
      case CommandError.queueEmpty:
        return 'Cola vacía';
    }
  }
}

/// Eventos de la cola
abstract class QueueEvent {
  final DateTime timestamp;
  
  QueueEvent({DateTime? timestamp}) : timestamp = timestamp ?? DateTime.now();
}

/// Comando encolado
class QueueCommandQueuedEvent extends QueueEvent {
  final String commandId;
  final int queueLength;
  
  QueueCommandQueuedEvent({
    required this.commandId,
    required this.queueLength,
  });
}

/// Comando ejecutándose
class QueueCommandExecutingEvent extends QueueEvent {
  final String commandId;
  final int queueLength;
  
  QueueCommandExecutingEvent({
    required this.commandId,
    required this.queueLength,
  });
}

/// Comando completado
class QueueCommandCompletedEvent extends QueueEvent {
  final String commandId;
  final bool success;
  
  QueueCommandCompletedEvent({
    required this.commandId,
    required this.success,
  });
}

/// Comando fallido
class QueueCommandFailedEvent extends QueueEvent {
  final String commandId;
  final String error;
  
  QueueCommandFailedEvent({
    required this.commandId,
    required this.error,
  });
}

/// Procesamiento de cola iniciado
class QueueProcessingStarted extends QueueEvent {}

/// Procesamiento de cola completado
class QueueProcessingCompleted extends QueueEvent {}

/// Cola pausada
class QueuePaused extends QueueEvent {}

/// Cola limpiada
class QueueCleared extends QueueEvent {}

// Variable para almacenar la función de ejecución
// (Se inicializa en tiempo de ejecución)
// ignore: prefer_typing_uninitialized_variables
var _defaultExecutor = (GenericCommand command) async {};
