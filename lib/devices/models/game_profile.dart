// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/models/game_profile.dart
// Perfil de Configuración Háptica por Juego
// 
// Guarda configuraciones específicas para cada videojuego,
// permitiendo ajustes personalizados de mapeo háptico.
// ═══════════════════════════════════════════════════════════════


import '../../services/media/game_haptics_mapper.dart';

// ═══════════════════════════════════════════════════════════════
// Game Profile Model
// ═══════════════════════════════════════════════════════════════

/// Perfil de configuración háptica para un videojuego específico
class GameProfile {
  /// ID único del perfil
  final String id;

  /// Nombre del juego
  final String gameName;

  /// Nombre del proceso (ej: "eldenring.exe")
  final String? processName;

  /// Género del juego (para sugerir curvas predefinidas)
  final GameGenre genre;

  /// Configuración del mapeador
  final Map<String, dynamic> mapperConfig;

  /// Dispositivos activos para este juego
  final List<String> activeDeviceIds;

  /// ¿Perfil activado?
  final bool isEnabled;

  /// Notas del usuario
  final String? notes;

  /// Fecha de creación
  final DateTime createdAt;

  /// Fecha de última modificación
  final DateTime updatedAt;

  GameProfile({
    required this.id,
    required this.gameName,
    this.processName,
    this.genre = GameGenre.action,
    required this.mapperConfig,
    this.activeDeviceIds = const [],
    this.isEnabled = true,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Crear perfil con configuración por defecto
  factory GameProfile.defaults({
    required String gameName,
    String? processName,
    GameGenre genre = GameGenre.action,
  }) {
    final mapper = GameHapticsMapper(
      curveConfig: _getDefaultCurveForGenre(genre),
    );

    return GameProfile(
      id: _generateId(gameName),
      gameName: gameName,
      processName: processName,
      genre: genre,
      mapperConfig: mapper.toJson(),
      activeDeviceIds: [],
    );
  }

  /// Obtener curva predefinida para género
  static ResponseCurveConfig _getDefaultCurveForGenre(GameGenre genre) {
    switch (genre) {
      case GameGenre.action:
        return ResponseCurveConfig.action;
      case GameGenre.racing:
        return ResponseCurveConfig.racing;
      case GameGenre.rhythm:
        return ResponseCurveConfig.rhythm;
      default:
        return const ResponseCurveConfig();
    }
  }

  /// Generar ID único desde nombre del juego
  static String _generateId(String gameName) {
    return gameName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
  }

  /// Crear desde JSON
  factory GameProfile.fromJson(Map<String, dynamic> json) {
    return GameProfile(
      id: json['id'] ?? '',
      gameName: json['gameName'] ?? '',
      processName: json['processName'],
      genre: GameGenre.values.firstWhere(
        (e) => e.name == json['genre'],
        orElse: () => GameGenre.action,
      ),
      mapperConfig: Map<String, dynamic>.from(json['mapperConfig'] ?? {}),
      activeDeviceIds: List<String>.from(json['activeDeviceIds'] ?? []),
      isEnabled: json['isEnabled'] ?? true,
      notes: json['notes'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gameName': gameName,
      'processName': processName,
      'genre': genre.name,
      'mapperConfig': mapperConfig,
      'activeDeviceIds': activeDeviceIds,
      'isEnabled': isEnabled,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Crear copia con campos modificados
  GameProfile copyWith({
    String? gameName,
    String? processName,
    GameGenre? genre,
    Map<String, dynamic>? mapperConfig,
    List<String>? activeDeviceIds,
    bool? isEnabled,
    String? notes,
  }) {
    return GameProfile(
      id: id,
      gameName: gameName ?? this.gameName,
      processName: processName ?? this.processName,
      genre: genre ?? this.genre,
      mapperConfig: mapperConfig ?? this.mapperConfig,
      activeDeviceIds: activeDeviceIds ?? this.activeDeviceIds,
      isEnabled: isEnabled ?? this.isEnabled,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Obtener configuración del mapeador
  GameHapticsMapper getMapper() {
    final mapper = GameHapticsMapper();
    if (mapperConfig.isNotEmpty) {
      mapper.fromJson(mapperConfig);
    }
    return mapper;
  }

  @override
  String toString() {
    return 'GameProfile($gameName, ${genre.name}, enabled: $isEnabled)';
  }
}

// ═══════════════════════════════════════════════════════════════
// Game Genre Enum
// ═══════════════════════════════════════════════════════════════

/// Géneros de juegos con curvas de respuesta predefinidas
enum GameGenre {
  /// Acción, aventura, shooters
  action,

  /// Carreras, conducción
  racing,

  /// Ritmo, música
  rhythm,

  /// RPG, aventuras gráficas
  rpg,

  /// Deportes
  sports,

  /// Terror, survival
  horror,

  /// Simulación
  simulation,

  /// Otros
  other,
}

// ═══════════════════════════════════════════════════════════════
// Extensiones
// ═══════════════════════════════════════════════════════════════

extension GameGenreExtension on GameGenre {
  /// Nombre legible del género
  String get displayName {
    switch (this) {
      case GameGenre.action:
        return 'Acción / Aventura';
      case GameGenre.racing:
        return 'Carreras / Conducción';
      case GameGenre.rhythm:
        return 'Ritmo / Música';
      case GameGenre.rpg:
        return 'RPG / Aventura';
      case GameGenre.sports:
        return 'Deportes';
      case GameGenre.horror:
        return 'Terror / Survival';
      case GameGenre.simulation:
        return 'Simulación';
      case GameGenre.other:
        return 'Otros';
    }
  }

  /// Curva de respuesta recomendada
  ResponseCurveConfig get recommendedCurve {
    switch (this) {
      case GameGenre.action:
        return ResponseCurveConfig.action;
      case GameGenre.racing:
        return ResponseCurveConfig.racing;
      case GameGenre.rhythm:
        return ResponseCurveConfig.rhythm;
      default:
        return const ResponseCurveConfig();
    }
  }

  /// Descripción del género
  String get description {
    switch (this) {
      case GameGenre.action:
        return 'Respuesta rápida y sensible para combates y disparos';
      case GameGenre.racing:
        return 'Respuesta progresiva para aceleración y curvas';
      case GameGenre.rhythm:
        return 'Respuesta precisa para sincronización musical';
      default:
        return 'Configuración estándar balanceada';
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// Ejemplos de Uso
// ═══════════════════════════════════════════════════════════════

/*
// Ejemplo 1: Crear perfil por defecto
final profile = GameProfile.defaults(
  gameName: 'Elden Ring',
  processName: 'eldenring.exe',
  genre: GameGenre.action,
);

// Ejemplo 2: Personalizar configuración
final customized = profile.copyWith(
  mapperConfig: {
    'leftSensitivity': 1.5,
    'rightSensitivity': 1.2,
    'deadZone': 0.1,
    'curveType': 'exponential',
  },
  activeDeviceIds: ['device-1', 'device-2'],
  notes: 'Usar para boss fights',
);

// Ejemplo 3: Guardar/Cargar
final json = customized.toJson();
await prefs.setString('profile_${customized.id}', jsonEncode(json));

final loadedJson = jsonDecode(await prefs.getString('profile_${customized.id}'));
final loaded = GameProfile.fromJson(loadedJson);

// Ejemplo 4: Obtener mapeador configurado
final mapper = customized.getMapper();
final output = mapper.mapDualMotors(32768, 65535);
*/
