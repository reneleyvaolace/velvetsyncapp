// ═══════════════════════════════════════════════════════════════
// Velvet Sync Platform · lib/utils/logger.dart
// Sistema de logging unificado
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Nivel de log
enum LogLevel {
  /// Debug (detallado)
  debug,
  
  /// Información
  info,
  
  /// Advertencia
  warning,
  
  /// Error
  error,
  
  /// Error crítico
  critical,
}

/// Entrada de log
class LogEntry {
  /// Timestamp
  final DateTime timestamp;
  
  /// Nivel del log
  final LogLevel level;
  
  /// Mensaje
  final String message;
  
  /// Tag/categoría
  final String? tag;
  
  /// Fuente (archivo, línea)
  final String? source;
  
  /// Datos adicionales
  final Map<String, dynamic>? data;
  
  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.tag,
    this.source,
    this.data,
  });
  
  /// Convertir a string formateado
  @override
  String toString() {
    final time = _formatTime(timestamp);
    final levelStr = _formatLevel(level);
    final tagStr = tag != null ? '[$tag]' : '';
    final sourceStr = source != null ? '($source)' : '';
    
    return '$time $levelStr $tagStr $sourceStr: $message';
  }
  
  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'message': message,
      'tag': tag,
      'source': source,
      'data': data,
    };
  }
  
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
           '${time.minute.toString().padLeft(2, '0')}:'
           '${time.second.toString().padLeft(2, '0')}.'
           '${time.millisecond.toString().padLeft(3, '0')}';
  }
  
  String _formatLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🔍 DEBUG';
      case LogLevel.info:
        return 'ℹ️  INFO';
      case LogLevel.warning:
        return '⚠️  WARN';
      case LogLevel.error:
        return '❌ ERROR';
      case LogLevel.critical:
        return '🔥 CRITICAL';
    }
  }
}

/// Sistema de logging unificado
class Logger {
  static final Logger _instance = Logger._internal();
  factory Logger() => _instance;
  Logger._internal();
  
  /// Entradas de log (máximo 500 en memoria)
  final List<LogEntry> _logs = [];
  
  /// Nivel mínimo de log
  LogLevel _minLevel = LogLevel.debug;
  
  /// Si está habilitado
  bool _enabled = true;
  
  /// Ruta del archivo de log
  String? _logFilePath;
  
  /// Tamaño máximo del archivo (bytes)
  static const int _maxFileSize = 10 * 1024 * 1024; // 10MB
  
  /// Número máximo de entradas en memoria
  static const int _maxInMemory = 500;
  
  /// Stream controller para listeners en tiempo real
  final _logController = StreamController<LogEntry>.broadcast();
  
  /// Stream de logs en tiempo real
  Stream<LogEntry> get logStream => _logController.stream;
  
  /// Habilitar o deshabilitar logging
  set enabled(bool value) => _enabled = value;
  
  /// Establecer nivel mínimo
  set minLevel(LogLevel level) => _minLevel = level;
  
  /// Obtener logs recientes
  List<LogEntry> get recentLogs {
    return List.unmodifiable(_logs);
  }
  
  /// Obtener logs filtrados por nivel
  List<LogEntry> getLogsByLevel(LogLevel level) {
    return _logs.where((log) => log.level == level).toList();
  }
  
  /// Obtener logs filtrados por tag
  List<LogEntry> getLogsByTag(String tag) {
    return _logs.where((log) => log.tag == tag).toList();
  }
  
  /// Buscar logs por mensaje
  List<LogEntry> searchLogs(String query) {
    return _logs.where((log) => 
      log.message.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }
  
  // ═══════════════════════════════════════════════════════════
  // MÉTODOS DE LOGGING
  // ═══════════════════════════════════════════════════════════
  
  /// Loggear mensaje
  void log(
    String message, {
    LogLevel level = LogLevel.info,
    String? tag,
    String? source,
    Map<String, dynamic>? data,
  }) {
    if (!_enabled) return;
    if (level.index < _minLevel.index) return;
    
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      tag: tag,
      source: source,
      data: data,
    );
    
    // Agregar a memoria
    _logs.add(entry);
    
    // Limitar tamaño en memoria
    if (_logs.length > _maxInMemory) {
      _logs.removeAt(0);
    }
    
    // Imprimir en consola (solo debug)
    if (kDebugMode) {
      debugPrint(entry.toString());
    }
    
    // Emitir a stream
    _logController.add(entry);
    
    // Guardar en archivo (async)
    _saveToFile(entry);
  }
  
  /// Log debug
  void debug(
    String message, {
    String? tag,
    String? source,
    Map<String, dynamic>? data,
  }) {
    log(message, level: LogLevel.debug, tag: tag, source: source, data: data);
  }
  
  /// Log info
  void info(
    String message, {
    String? tag,
    String? source,
    Map<String, dynamic>? data,
  }) {
    log(message, level: LogLevel.info, tag: tag, source: source, data: data);
  }
  
  /// Log warning
  void warning(
    String message, {
    String? tag,
    String? source,
    Map<String, dynamic>? data,
  }) {
    log(message, level: LogLevel.warning, tag: tag, source: source, data: data);
  }
  
  /// Log error
  void error(
    String message, {
    String? tag,
    String? source,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    final data = <String, dynamic>{};
    if (exception != null) {
      data['exception'] = exception.toString();
    }
    if (stackTrace != null) {
      data['stackTrace'] = stackTrace.toString();
    }
    
    log(message, level: LogLevel.error, tag: tag, source: source, data: data);
  }
  
  /// Log critical
  void critical(
    String message, {
    String? tag,
    String? source,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    final data = <String, dynamic>{};
    if (exception != null) {
      data['exception'] = exception.toString();
    }
    if (stackTrace != null) {
      data['stackTrace'] = stackTrace.toString();
    }
    
    log(message, level: LogLevel.critical, tag: tag, source: source, data: data);
  }
  
  // ═══════════════════════════════════════════════════════════
  // GESTIÓN DE ARCHIVOS
  // ═══════════════════════════════════════════════════════════
  
  /// Inicializar logging a archivo
  Future<void> initFileLogging({String? customPath}) async {
    if (kIsWeb) {
      debugPrint('[LOGGER] File logging is disabled on Web');
      return;
    }
    
    try {
      final directory = customPath != null
          ? Directory(customPath)
          : await getApplicationDocumentsDirectory();
      
      final file = File('${directory.path}/velvet_sync.log');
      _logFilePath = file.path;
      
      // Rotar archivo si es muy grande
      if (file.existsSync()) {
        final size = file.lengthSync();
        if (size > _maxFileSize) {
          await file.rename('${directory.path}/velvet_sync.old.log');
        }
      }
      
      info('Logging a archivo inicializado: $_logFilePath', tag: 'LOGGER');
    } catch (e) {
      lvsLog('Error inicializando logging a archivo: $e');
    }
  }
  
  /// Guardar entrada en archivo
  Future<void> _saveToFile(LogEntry entry) async {
    if (_logFilePath == null) return;
    
    try {
      final file = File(_logFilePath!);
      final line = '${jsonEncode(entry.toJson())}\n';
      
      await file.writeAsString(line, mode: FileMode.append);
    } catch (e) {
      // Silenciar errores de I/O
    }
  }
  
  /// Exportar logs a archivo
  Future<String?> exportLogs({String? filename}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/${filename ?? 'velvet_sync_export_${DateTime.now().millisecondsSinceEpoch}.log'}',
      );
      
      final lines = _logs.map((e) => jsonEncode(e.toJson())).join('\n');
      await file.writeAsString(lines);
      
      info('Logs exportados: ${file.path}', tag: 'LOGGER');
      return file.path;
    } catch (e) {
      error('Error exportando logs: $e', tag: 'LOGGER');
      return null;
    }
  }
  
  /// Limpiar logs
  void clear() {
    _logs.clear();
    info('Logs limpiados', tag: 'LOGGER');
  }
  
  /// Limpiar archivo de logs
  Future<void> clearLogFile() async {
    if (_logFilePath == null) return;
    
    try {
      final file = File(_logFilePath!);
      if (file.existsSync()) {
        await file.writeAsString('');
        info('Archivo de logs limpiado', tag: 'LOGGER');
      }
    } catch (e) {
      error('Error limpiando archivo de logs: $e', tag: 'LOGGER');
    }
  }
  
  // ═══════════════════════════════════════════════════════════
  // UTILIDADES
  // ═══════════════════════════════════════════════════════════
  
  /// Obtener estadísticas de logs
  Map<String, int> getStats() {
    final stats = <String, int>{};
    
    for (final entry in _logs) {
      final key = entry.level.name;
      stats[key] = (stats[key] ?? 0) + 1;
    }
    
    stats['total'] = _logs.length;
    return stats;
  }
  
  /// Obtener logs por rango de tiempo
  List<LogEntry> getLogsByTimeRange({
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return _logs.where((entry) {
      if (startTime != null && entry.timestamp.isBefore(startTime)) {
        return false;
      }
      if (endTime != null && entry.timestamp.isAfter(endTime)) {
        return false;
      }
      return true;
    }).toList();
  }
  
  /// Dispose
  void dispose() {
    _logController.close();
  }
}

// ═══════════════════════════════════════════════════════════
// EXTENSIONES PARA LOGGER
// ═══════════════════════════════════════════════════════════

/// Extensión para logging con contexto
extension LoggerContext on Object {
  /// Obtener logger con tag de la clase
  Logger get logger {
    final tag = runtimeType.toString();
    return Logger()..info('Logger inicializado para $tag', tag: tag);
  }
  
  /// Log debug
  void logDebug(String message, {Map<String, dynamic>? data}) {
    Logger().debug(message, tag: runtimeType.toString(), data: data);
  }
  
  /// Log info
  void logInfo(String message, {Map<String, dynamic>? data}) {
    Logger().info(message, tag: runtimeType.toString(), data: data);
  }
  
  /// Log warning
  void logWarning(String message, {Map<String, dynamic>? data}) {
    Logger().warning(message, tag: runtimeType.toString(), data: data);
  }
  
  /// Log error
  void logError(String message, {Object? exception, StackTrace? stackTrace}) {
    Logger().error(
      message,
      tag: runtimeType.toString(),
      exception: exception,
      stackTrace: stackTrace,
    );
  }
}

// ═══════════════════════════════════════════════════════════
// LOGGER GLOBAL
// ═══════════════════════════════════════════════════════════

/// Logger global para uso rápido
final lvsLog = Logger().log;
final lvsDebug = Logger().debug;
final lvsInfo = Logger().info;
final lvsWarning = Logger().warning;
final lvsError = Logger().error;
final lvsCritical = Logger().critical;
