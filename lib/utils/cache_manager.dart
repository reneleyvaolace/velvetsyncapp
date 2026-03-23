// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/utils/cache_manager.dart
// 🔒 PERFORMANCE: Custom Cache Manager para imágenes
// ═══════════════════════════════════════════════════════════════

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Cache manager personalizado para el catálogo de dispositivos
class VelvetCacheManager {
  static final instance = VelvetCacheManager._internal();
  VelvetCacheManager._internal();

  final CacheManager catalogCache = CacheManager(
    Config(
      'velvetsync_catalog',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 100,
      repo: JsonCacheInfoRepository(databaseName: 'velvetsync_catalog'),
      fileService: HttpFileService(),
    ),
  );

  /// Cache para avatares de companion
  final CacheManager avatarCache = CacheManager(
    Config(
      'velvetsync_avatars',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 20,
      repo: JsonCacheInfoRepository(databaseName: 'velvetsync_avatars'),
      fileService: HttpFileService(),
    ),
  );
}
