// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/media/url_sync_service.dart
// URL Sync Service - Reproduce URL y el juguete reacciona en sync
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:velvet_sync/services/media/video_cache_service.dart';
import 'package:velvet_sync/services/media/funscript_loader.dart';
import 'package:velvet_sync/services/media/haptic_video_sync_service.dart';
import 'package:velvet_sync/services/ble/ble_service.dart';
import 'package:velvet_sync/devices/models/funscript.dart';
import 'package:velvet_sync/devices/models/toy_model.dart';
import 'package:velvet_sync/utils/logger.dart';

/// Tipo de fuente de video soportada
enum VideoSourceType {
  directMp4,      // .mp4, .mov, .webm directo
  hls,            // .m3u8
  dash,           // .mpd
  youtube,        // youtube.com, youtu.be
  vimeo,          // vimeo.com
  unknown,
}

/// Metadatos de video extraídos de URL
class VideoMetadata {
  final String url;
  final VideoSourceType type;
  final String? title;
  final String? thumbnailUrl;
  final Duration? duration;
  final String? directVideoUrl; // URL directa para video_player
  final Map<String, dynamic> rawData;
  final String? error;

  VideoMetadata({
    required this.url,
    required this.type,
    this.title,
    this.thumbnailUrl,
    this.duration,
    this.directVideoUrl,
    this.rawData = const {},
    this.error,
  });

  bool get isPlayable => directVideoUrl != null && directVideoUrl!.isNotEmpty;
}

/// Resultado de sincronización URL
class UrlSyncResult {
  final bool success;
  final String? videoPath;
  final Funscript? funscript;
  final VideoMetadata? metadata;
  final String? error;

  UrlSyncResult.success({
    required this.videoPath,
    this.funscript,
    this.metadata,
  }) : success = true, error = null;

  UrlSyncResult.failure(this.error)
      : success = false,
        videoPath = null,
        funscript = null,
        metadata = null;
}

/// Servicio principal de URL Sync
class UrlSyncService {
  final VideoCacheService _cacheService = VideoCacheService();
  final FunscriptLoader _funscriptLoader = FunscriptLoader();
  final HapticVideoSyncService _syncService = HapticVideoSyncService();

  VideoPlayerController? _controller;
  Funscript? _currentFunscript;
  VideoMetadata? _currentMetadata;
  bool _isInitialized = false;

  // Callbacks
  Function()? onStateChange;
  Function()? onProgressUpdate;
  Function(String)? onError;
  Function(VideoMetadata)? onMetadataLoaded;

  bool get isInitialized => _isInitialized;
  VideoPlayerController? get controller => _controller;
  Funscript? get currentFunscript => _currentFunscript;
  VideoMetadata? get currentMetadata => _currentMetadata;
  bool get isPlaying => _controller?.value.isPlaying ?? false;
  Duration get position => _controller?.value.position ?? Duration.zero;
  Duration get duration => _controller?.value.duration ?? Duration.zero;
  bool get hasFunscript => _currentFunscript != null;

  /// Inicializa el servicio
  Future<void> init() async {
    await _cacheService.init();
    lvsLog('UrlSyncService inicializado', tag: 'URL_SYNC');
  }

  /// Procesa una URL y prepara todo para reproducción con sync
  Future<UrlSyncResult> processUrl(String url) async {
    if (url.isEmpty) {
      return UrlSyncResult.failure('URL vacía');
    }

    lvsLog('Procesando URL: $url', tag: 'URL_SYNC');

    try {
      // 1. Detectar tipo de fuente y extraer metadatos
      final metadata = await _extractMetadata(url);
      _currentMetadata = metadata;
      onMetadataLoaded?.call(metadata);

      if (!metadata.isPlayable) {
        return UrlSyncResult.failure('Tipo de video no soportado: ${metadata.type}');
      }

      // 2. Descargar/cachear video
      final videoPath = await _cacheService.getVideoPath(metadata.directVideoUrl!);
      if (videoPath == null) {
        return UrlSyncResult.failure('No se pudo descargar el video');
      }

      // 3. Cargar video
      await _loadVideo(videoPath);

      // 4. Buscar/cargar Funscript asociado
      Funscript? funscript;
      if (metadata.type == VideoSourceType.directMp4) {
        funscript = await _discoverFunscript(videoPath);
      } else {
        // Para YouTube/Vimeo, intentar buscar por título/ID
        funscript = await _findFunscriptForMetadata(metadata);
      }
      _currentFunscript = funscript;

      // 4. Configurar sincronización
      _initSync();

      _isInitialized = true;
      onStateChange?.call();

      return UrlSyncResult.success(
        videoPath: videoPath,
        funscript: funscript,
        metadata: metadata,
      );
    } catch (e, stack) {
      lvsLog('Error procesando URL: $e\n$stack', tag: 'URL_SYNC');
      onError?.call(e.toString());
      return UrlSyncResult.failure(e.toString());
    }
  }

  /// Procesa una URL y prepara todo para reproducción con sync
  Future<VideoMetadata> _extractMetadata(String url) async {
    final type = _detectSourceType(url);

    switch (type) {
      case VideoSourceType.youtube:
        return await _extractYouTubeMetadata(url);
      case VideoSourceType.vimeo:
        return await _extractVimeoMetadata(url);
      case VideoSourceType.hls:
      case VideoSourceType.dash:
      case VideoSourceType.directMp4:
        return await _extractDirectMetadata(url);
      default:
        // Intentar como directo
        return await _extractDirectMetadata(url);
    }
  }

  VideoSourceType _detectSourceType(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return VideoSourceType.youtube;
    }
    if (lower.contains('vimeo.com')) {
      return VideoSourceType.vimeo;
    }
    if (lower.contains('.m3u8')) {
      return VideoSourceType.hls;
    }
    if (lower.contains('.mpd')) {
      return VideoSourceType.dash;
    }
    if (lower.contains('.mp4') || lower.contains('.mov') || lower.contains('.webm') || lower.contains('.mkv')) {
      return VideoSourceType.directMp4;
    }
    return VideoSourceType.unknown;
  }

  /// YouTube: Extraer ID y usar yewtube/noembed para metadatos
  Future<VideoMetadata> _extractYouTubeMetadata(String url) async {
    final videoId = _extractYouTubeId(url);
    if (videoId == null) {
      return VideoMetadata(
        url: url,
        type: VideoSourceType.youtube,
        error: 'ID no válido',
      );
    }

    // Usar noembed.com o yewtube para obtener metadatos sin API key
    // Por ahora retornamos metadatos básicos
    return VideoMetadata(
      url: url,
      type: VideoSourceType.youtube,
      title: 'YouTube: $videoId',
      directVideoUrl: 'https://yewtu.be/watch?v=$videoId&local=true',
      rawData: {'videoId': videoId},
    );
  }

  String? _extractYouTubeId(String url) {
    final patterns = [
      RegExp(r'(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com\/embed\/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com\/v\/([a-zA-Z0-9_-]{11})'),
    ];
    for (final p in patterns) {
      final match = p.firstMatch(url);
      if (match != null) return match.group(1);
    }
    return null;
  }

  /// Vimeo: Extraer ID y usar oEmbed
  Future<VideoMetadata> _extractVimeoMetadata(String url) async {
    final videoId = _extractVimeoId(url);
    if (videoId == null) {
      return VideoMetadata(
        url: url,
        type: VideoSourceType.vimeo,
        error: 'ID no válido',
      );
    }

    try {
      final oembedUrl = 'https://vimeo.com/api/oembed.json?url=https://vimeo.com/$videoId';
      final response = await http.get(Uri.parse(oembedUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return VideoMetadata(
          url: url,
          type: VideoSourceType.vimeo,
          title: data['title'],
          thumbnailUrl: data['thumbnail_url'],
          duration: Duration(seconds: (data['duration'] as num?)?.toInt() ?? 0),
          rawData: data,
        );
      }
    } catch (_) {}

    return VideoMetadata(
      url: url,
      type: VideoSourceType.vimeo,
      title: 'Vimeo: $videoId',
      rawData: {'videoId': videoId},
    );
  }

  String? _extractVimeoId(String url) {
    final match = RegExp(r'vimeo\.com\/(?:video\/)?(\d+)').firstMatch(url);
    return match?.group(1);
  }

  /// Directo/HLS/DASH: Verificar accesibilidad
  Future<VideoMetadata> _extractDirectMetadata(String url) async {
    try {
      final response = await http.head(Uri.parse(url)).timeout(const Duration(seconds: 10));
      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      final contentLength = response.headers['content-length'];

      VideoSourceType detectedType = VideoSourceType.directMp4;
      if (url.contains('.m3u8') || contentType.contains('mpegurl') || contentType.contains('vnd.apple.mpegurl')) {
        detectedType = VideoSourceType.hls;
      } else if (url.contains('.mpd') || contentType.contains('dash')) {
        detectedType = VideoSourceType.dash;
      }

      return VideoMetadata(
        url: url,
        type: detectedType,
        directVideoUrl: url,
        duration: contentLength != null ? Duration(milliseconds: int.parse(contentLength) ~/ 100) : null,
        rawData: {'contentType': contentType, 'contentLength': contentLength},
      );
    } catch (e) {
      return VideoMetadata(
        url: url,
        type: VideoSourceType.directMp4,
        directVideoUrl: url,
        error: e.toString(),
      );
    }
  }

  /// Carga video en player
  Future<void> _loadVideo(String path) async {
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();

    _controller = VideoPlayerController.file(File(path));
    _controller!.addListener(_onVideoUpdate);
    await _controller!.initialize();

    onStateChange?.call();
  }

  /// Descubre funscript local para video
  Future<Funscript?> _discoverFunscript(String videoPath) async {
    try {
      final scriptPath = await FunscriptLoader.findScriptForVideo(videoPath);
      if (scriptPath != null) {
        final loader = FunscriptLoader();
        return await loader.load(path: scriptPath, useCache: true);
      }
    } catch (e) {
      lvsLog('Error buscando funscript local: $e', tag: 'URL_SYNC');
    }
    return null;
  }

  /// Busca funscript por metadatos (título, ID)
  Future<Funscript?> _findFunscriptForMetadata(VideoMetadata metadata) async {
    // Buscar en caché local por título
    if (metadata.title != null) {
      try {
        // Aquí podrías implementar búsqueda en base de datos local o API
        // Por ahora retornamos null
      } catch (_) {}
    }
    return null;
  }

  void _initSync() {
    if (_controller == null || _currentFunscript == null) return;
    _syncService.configure(
      controller: _controller!,
      funscript: _currentFunscript!,
      ble: BleService(),
      enableP2P: false,
    );
  }

  void _onVideoUpdate() {
    if (!mounted) return;
    if (_controller == null || !_controller!.value.isInitialized) return;
    onProgressUpdate?.call();
  }

  void play() {
    _controller?.play();
    _syncService.start();
    onStateChange?.call();
  }

  void pause() {
    _controller?.pause();
    _syncService.pause();
    onStateChange?.call();
  }

  void seekTo(Duration position) {
    _controller?.seekTo(position);
  }

  void dispose() {
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    _syncService.dispose();
    _isInitialized = false;
    onStateChange?.call();
  }

  bool get mounted => _controller != null;
}

/// Provider para Riverpod
final urlSyncServiceProvider = Provider<UrlSyncService>((ref) => UrlSyncService());