// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/media/video_cache_service.dart
// Servicio de caché y descarga de videos multimedia (gamePath)
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:velvet_sync/utils/logger.dart';

class VideoCacheService {
  static final VideoCacheService _instance = VideoCacheService._internal();
  factory VideoCacheService() => _instance;
  VideoCacheService._internal();

  Directory? _cacheDir;
  final Map<String, String> _memoryCache = {};

  /// Inicializa el directorio de caché
  Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${appDir.path}/video_cache');
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
    lvsLog('VideoCacheService inicializado: ${_cacheDir!.path}', tag: 'VIDEO_CACHE');
  }

  /// Obtiene la ruta local de un video (descarga si no existe en caché)
  Future<String?> getVideoPath(String url) async {
    if (url.isEmpty) return null;

    // Verificar caché en memoria
    if (_memoryCache.containsKey(url)) {
      final path = _memoryCache[url]!;
      if (await File(path).exists()) {
        lvsLog('Video cache HIT (memoria): $url', tag: 'VIDEO_CACHE');
        return path;
      }
      _memoryCache.remove(url);
    }

    // Verificar caché en disco
    final fileName = _urlToFileName(url);
    final localPath = '${_cacheDir!.path}/$fileName';
    final file = File(localPath);

    if (await file.exists()) {
      final stat = await file.stat();
      // Verificar que el archivo no esté corrupto (tamaño > 1KB)
      if (stat.size > 1024) {
        _memoryCache[url] = localPath;
        lvsLog('Video cache HIT (disco): $url', tag: 'VIDEO_CACHE');
        return localPath;
      } else {
        await file.delete(); // Archivo corrupto
      }
    }

    // Descargar
    lvsLog('Descargando video: $url', tag: 'VIDEO_CACHE');
    try {
      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'VelvetSync/1.0'})
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        await file.writeAsBytes(response.bodyBytes, flush: true);
        _memoryCache[url] = localPath;
        lvsLog('Video descargado y cacheado: $url (${response.bodyBytes.length} bytes)', tag: 'VIDEO_CACHE');
        return localPath;
      } else {
        lvsLog('Error descargando video: HTTP ${response.statusCode}', tag: 'VIDEO_CACHE');
        return null;
      }
    } catch (e) {
      lvsLog('Excepción descargando video: $e', tag: 'VIDEO_CACHE');
      return null;
    }
  }

  /// Convierte URL a nombre de archivo seguro
  String _urlToFileName(String url) {
    final uri = Uri.parse(url);
    final path = uri.path;
    final name = path.split('/').last;
    // Sanitizar nombre
    final safeName = name
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .substring(0, name.length > 100 ? 100 : name.length);
    // Agregar hash para evitar colisiones
    final hash = url.hashCode.abs().toString().substring(0, 8);
    return '${hash}_$safeName';
  }

  /// Precarga un video en segundo plano
  Future<void> precacheVideo(String url) async {
    if (url.isEmpty) return;
    // Fire-and-forget: no await, errores se loggean internamente
    getVideoPath(url).catchError((e) {
      lvsLog('Precache error: $e', tag: 'VIDEO_CACHE');
      return null;
    });
  }

  /// Limpia la caché antigua (archivos > 30 días)
  Future<void> cleanOldCache({int maxAgeDays = 30}) async {
    if (_cacheDir == null) return;
    final cutoff = DateTime.now().subtract(Duration(days: maxAgeDays));
    int deleted = 0;
    int freed = 0;

    try {
      await for (final entity in _cacheDir!.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) {
            freed += stat.size;
            await entity.delete();
            deleted++;
          }
        }
      }
      // Limpiar memoria
      _memoryCache.clear();
      lvsLog('Limpieza caché: $deleted archivos eliminados, ${(freed / 1024 / 1024).toStringAsFixed(1)} MB liberados', tag: 'VIDEO_CACHE');
    } catch (e) {
      lvsLog('Error limpiando caché: $e', tag: 'VIDEO_CACHE');
    }
  }

  /// Obtiene tamaño total de la caché
  Future<int> getCacheSize() async {
    if (_cacheDir == null) return 0;
    int size = 0;
    try {
      await for (final entity in _cacheDir!.list()) {
        if (entity is File) {
          size += (await entity.stat()).size;
        }
      }
    } catch (_) {}
    return size;
  }

  void clearMemoryCache() {
    _memoryCache.clear();
  }
}