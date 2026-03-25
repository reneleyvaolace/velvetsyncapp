// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/funscript_loader.dart
// Servicio de Carga y Gestión de Funscripts
// 
// Carga, cachea y gestiona scripts Funscript para sincronización
// de video con juguetes hápticos.
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:velvet_sync/devices/models/funscript.dart';
import 'package:velvet_sync/utils/logger.dart';

// ═══════════════════════════════════════════════════════════════
// Funscript Loader Service
// ═══════════════════════════════════════════════════════════════

/// Servicio de carga y gestión de scripts Funscript
class FunscriptLoader extends ChangeNotifier {
  static final FunscriptLoader _instance = FunscriptLoader._internal();
  factory FunscriptLoader() => _instance;
  FunscriptLoader._internal();

  /// Cache de scripts cargados
  final Map<String, Funscript> _cache = {};

  /// Script actualmente cargado
  Funscript? _currentScript;

  /// ¿Está cargando actualmente?
  bool _isLoading = false;

  /// Último error ocurrido
  String? _lastError;

  // ═══════════════════════════════════════════════════════════════
  // Getters de Estado
  // ═══════════════════════════════════════════════════════════════

  /// Script actualmente cargado
  Funscript? get currentScript => _currentScript;

  /// ¿Está cargando?
  bool get isLoading => _isLoading;

  /// Último error
  String? get lastError => _lastError;

  /// ¿Hay script cargado?
  bool get hasScript => _currentScript != null;

  /// Cantidad de scripts en cache
  int get cacheSize => _cache.length;

  // ═══════════════════════════════════════════════════════════════
  // Métodos de Carga
  // ═══════════════════════════════════════════════════════════════

  /// Cargar script desde archivo
  ///
  /// [path] - Ruta del archivo .funscript
  /// [useCache] - ¿Usar cache si ya está cargado?
  Future<Funscript?> load({
    required String path,
    bool useCache = true,
  }) async {
    if (_isLoading) {
      lvsLog('Ya hay carga en progreso', tag: 'FUNSCRIPT');
      return null;
    }

    try {
      _isLoading = true;
      _lastError = null;
      notifyListeners();

      lvsLog('Cargando funscript: $path', tag: 'FUNSCRIPT');

      // Verificar cache
      if (useCache && _cache.containsKey(path)) {
        lvsLog('Usando cache para: $path', tag: 'FUNSCRIPT');
        _currentScript = _cache[path];
        _isLoading = false;
        notifyListeners();
        return _currentScript;
      }

      // Verificar archivo
      final file = File(path);
      if (!await file.exists()) {
        _lastError = 'Archivo no encontrado: $path';
        lvsLog(_lastError!, tag: 'FUNSCRIPT');
        _isLoading = false;
        notifyListeners();
        return null;
      }

      // Cargar script
      _currentScript = await Funscript.fromFile(path);
      
      // Agregar a cache
      _cache[path] = _currentScript!;

      lvsLog(
        '✅ Funscript cargado: ${_currentScript!.actionCount} acciones, '
        '${_currentScript!.duration.inSeconds}s',
        tag: 'FUNSCRIPT',
      );

      _isLoading = false;
      notifyListeners();
      return _currentScript;
    } catch (e) {
      _lastError = 'Error cargando funscript: $e';
      lvsLog(_lastError!, tag: 'FUNSCRIPT');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Cargar script desde string JSON
  Future<Funscript?> loadFromString(String jsonString) async {
    try {
      _currentScript = Funscript.fromString(jsonString);
      notifyListeners();
      return _currentScript;
    } catch (e) {
      _lastError = 'Error parseando JSON: $e';
      lvsLog(_lastError!, tag: 'FUNSCRIPT');
      notifyListeners();
      return null;
    }
  }

  /// Cargar script desde URL (requiere internet)
  Future<Funscript?> loadFromUrl(String url) async {
    try {
      // TODO: Implementar descarga desde URL
      lvsLog('Carga desde URL no implementada aún', tag: 'FUNSCRIPT');
      return null;
    } catch (e) {
      _lastError = 'Error cargando desde URL: $e';
      lvsLog(_lastError!, tag: 'FUNSCRIPT');
      notifyListeners();
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Métodos de Descarga
  // ═══════════════════════════════════════════════════════════════

  /// Descargar script actual de memoria
  void unload() {
    _currentScript = null;
    notifyListeners();
    lvsLog('Script descargado', tag: 'FUNSCRIPT');
  }

  /// Limpiar cache
  void clearCache() {
    _cache.clear();
    lvsLog('Cache limpiada (${_cache.length} scripts eliminados)', tag: 'FUNSCRIPT');
  }

  /// Eliminar script específico de cache
  void removeFromCache(String path) {
    _cache.remove(path);
    lvsLog('Script eliminado de cache: $path', tag: 'FUNSCRIPT');
  }

  // ═══════════════════════════════════════════════════════════════
  // Métodos de Utilidad
  // ═══════════════════════════════════════════════════════════════

  /// Obtener ruta de script para video
  ///
  /// Busca archivo .funscript con mismo nombre que video
  static Future<String?> findScriptForVideo(String videoPath) async {
    final directory = Directory(videoPath).parent;
    final videoName = p.basenameWithoutExtension(videoPath);
    
    // Intentar my-video.funscript
    final scriptPath = p.join(directory.path, '$videoName.funscript');
    final file = File(scriptPath);
    
    if (await file.exists()) {
      lvsLog('Script encontrado: $scriptPath', tag: 'FUNSCRIPT');
      return scriptPath;
    }
    
    // Buscar variantes (my-video (1).funscript, etc.)
    final entries = await directory.list().toList();
    for (final entry in entries) {
      if (entry is File && 
          entry.path.endsWith('.funscript') &&
          p.basenameWithoutExtension(entry.path).startsWith(videoName)) {
        lvsLog('Script variante encontrado: ${entry.path}', tag: 'FUNSCRIPT');
        return entry.path;
      }
    }
    
    lvsLog('No se encontró script para: $videoPath', tag: 'FUNSCRIPT');
    return null;
  }

  /// Obtener lista de scripts en directorio
  static Future<List<String>> listScriptsInDirectory(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      return [];
    }

    final scripts = <String>[];
    await for (final entry in directory.list()) {
      if (entry is File && entry.path.endsWith('.funscript')) {
        scripts.add(entry.path);
      }
    }

    lvsLog('Encontrados ${scripts.length} scripts en: $directoryPath', tag: 'FUNSCRIPT');
    return scripts;
  }

  /// Obtener directorio de scripts por defecto
  static Future<String> getDefaultScriptsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final scriptsDir = Directory(p.join(appDir.path, 'funscripts'));
    
    if (!await scriptsDir.exists()) {
      await scriptsDir.create(recursive: true);
    }
    
    return scriptsDir.path;
  }

  /// Exportar script a archivo
  Future<bool> exportScript({
    required Funscript script,
    required String path,
  }) async {
    try {
      await script.toFile(path);
      lvsLog('✅ Script exportado: $path', tag: 'FUNSCRIPT');
      return true;
    } catch (e) {
      _lastError = 'Error exportando script: $e';
      lvsLog(_lastError!, tag: 'FUNSCRIPT');
      return false;
    }
  }

  /// Importar script desde archivo
  Future<Funscript?> importScript(String path) async {
    return await load(path: path, useCache: false);
  }

  // ═══════════════════════════════════════════════════════════════
  // Métodos de Estadísticas
  // ═══════════════════════════════════════════════════════════════

  /// Obtener estadísticas de scripts en cache
  Map<String, dynamic> getCacheStats() {
    if (_cache.isEmpty) {
      return {'count': 0};
    }

    final totalActions = _cache.values.fold<int>(
      0,
      (sum, script) => sum + script.actionCount,
    );

    final totalDuration = _cache.values.fold<int>(
      0,
      (sum, script) => sum + script.durationMs,
    );

    return {
      'count': _cache.length,
      'totalActions': totalActions,
      'totalDurationMs': totalDuration,
      'totalDurationSeconds': (totalDuration / 1000).round(),
      'averageActionsPerScript': (totalActions / _cache.length).round(),
    };
  }

  @override
  String toString() {
    return 'FunscriptLoader(cache: ${_cache.length} scripts, current: ${_currentScript != null ? "loaded" : "none"})';
  }
}

// ═══════════════════════════════════════════════════════════════
// Provider de Riverpod (opcional)
// ═══════════════════════════════════════════════════════════════

/*
// Si usas Riverpod:
import 'package:flutter_riverpod/flutter_riverpod.dart';

final funscriptLoaderProvider = Provider<FunscriptLoader>((ref) {
  return FunscriptLoader();
});

final currentFunscriptProvider = StateProvider<Funscript?>((ref) => null);
final isFunscriptLoadingProvider = StateProvider<bool>((ref) => false);

// Uso:
// final loader = ref.watch(funscriptLoaderProvider);
// await loader.load(path: scriptPath);
*/
