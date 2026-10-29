// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/game/game_mode_service.dart
// Game Mode Service - Modo Juego Mejorado con desafíos, logros, multijugador
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velvet_sync/services/ble/ble_service.dart';
import 'package:velvet_sync/devices/models/toy_model.dart';
import 'package:velvet_sync/utils/logger.dart';

/// Tipo de juego
enum GameType {
  solo,           // Solo contra la app
  versus,         // 1v1 contra otro usuario
  coOp,           // Cooperativo (ambos controlan)
  challenge,      // Desafío diario/semanal
  endurance,      // Resistencia (aguantar patrón)
  rhythm,         // Ritmo/música
  dice,           // Dados (aleatorio)
  roulette,       // Ruleta (aleatorio con apuestas)
  memory,         // Memoria (secuencia de patrones)
  reaction,       // Reacción (respuesta rápida)
}

/// Estado del juego
enum GameStatus {
  idle,           // Sin juego activo
  lobby,          // En lobby (esperando jugadores)
  countdown,      // Cuenta regresiva
  playing,        // Jugando
  paused,         // Pausado
  finished,       // Terminado
  cancelled,      // Cancelado
}

/// Rol del jugador
enum PlayerRole {
  host,           // Anfitrión (controla settings)
  guest,          // Invitado
  spectator,      // Espectador
}

/// Tipo de logro
enum AchievementType {
  firstWin,           // Primera victoria
  winStreak,          // Racha de victorias
  enduranceMaster,    // Resistencia (tiempo)
  patternMaster,      // Dominio de patrones
  reactionKing,       // Rey de reacciones
  socialButterfly,    // Jugadas multijugador
  earlyBird,          // Juega temprano
  nightOwl,           // Juega tarde
  comeback,           // Victoria remontada
  perfectGame,        // Juego perfecto
  marathon,           // Sesión larga
  collector,          // Colecciona juguetes
  explorer,           // Prueba muchos modos
}

/// Logro desbloqueable
class Achievement {
  final String id;
  final String name;
  final String description;
  final String iconPath;
  final AchievementType type;
  final int requiredValue;
  final int rewardXp;
  final bool isSecret;
  final DateTime? unlockedAt;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.iconPath,
    required this.type,
    required this.requiredValue,
    required this.rewardXp,
    this.isSecret = false,
    this.unlockedAt,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
    id: json['id'],
    name: json['name'],
    description: json['description'],
    iconPath: json['iconPath'],
    type: AchievementType.values.firstWhere((e) => e.name == json['type']),
    requiredValue: json['requiredValue'],
    rewardXp: json['rewardXp'],
    isSecret: json['isSecret'] ?? false,
    unlockedAt: json['unlockedAt'] != null ? DateTime.parse(json['unlockedAt']) : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'iconPath': iconPath,
    'type': type.name,
    'requiredValue': requiredValue,
    'rewardXp': rewardXp,
    'isSecret': isSecret,
    'unlockedAt': unlockedAt?.toIso8601String(),
  };

  Achievement copyWith({DateTime? unlockedAt}) => Achievement(
    id: id,
    name: name,
    description: description,
    iconPath: iconPath,
    type: type,
    requiredValue: requiredValue,
    rewardXp: rewardXp,
    isSecret: isSecret,
    unlockedAt: unlockedAt ?? this.unlockedAt,
  );

  bool get isUnlocked => unlockedAt != null;
  double get progress => unlockedAt != null ? 1.0 : 0.0; // Simplificado
}

/// Estadísticas de jugador
class PlayerStats {
  final String userId;
  final String displayName;
  final int level;
  final int xp;
  final int xpToNextLevel;
  final int totalWins;
  final int totalLosses;
  final int totalGames;
  final int currentStreak;
  final int bestStreak;
  final int totalPlayTimeMinutes;
  final Map<String, int> gamesByType;
  final Map<String, int> winsByType;
  final int favoriteToyId; // Referencia a ToyModel
  final DateTime? lastPlayedAt;
  final List<Achievement> achievements;

  PlayerStats({
    required this.userId,
    required this.displayName,
    this.level = 1,
    this.xp = 0,
    this.xpToNextLevel = 100,
    this.totalWins = 0,
    this.totalLosses = 0,
    this.totalGames = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.totalPlayTimeMinutes = 0,
    this.gamesByType = const {},
    this.winsByType = const {},
    this.favoriteToyId = 0,
    this.lastPlayedAt,
    this.achievements = const [],
  });

  double get winRate => totalGames > 0 ? totalWins / totalGames : 0.0;
  int get xpForNextLevel => 100 * level; // Fórmula simple

  factory PlayerStats.fromJson(Map<String, dynamic> json) => PlayerStats(
    userId: json['userId'],
    displayName: json['displayName'],
    level: json['level'] ?? 1,
    xp: json['xp'] ?? 0,
    xpToNextLevel: json['xpToNextLevel'] ?? 100,
    totalWins: json['totalWins'] ?? 0,
    totalLosses: json['totalLosses'] ?? 0,
    totalGames: json['totalGames'] ?? 0,
    currentStreak: json['currentStreak'] ?? 0,
    bestStreak: json['bestStreak'] ?? 0,
    totalPlayTimeMinutes: json['totalPlayTimeMinutes'] ?? 0,
    gamesByType: Map<String, int>.from(json['gamesByType'] ?? {}),
    winsByType: Map<String, int>.from(json['winsByType'] ?? {}),
    favoriteToyId: json['favoriteToyId'] ?? 0,
    lastPlayedAt: json['lastPlayedAt'] != null ? DateTime.parse(json['lastPlayedAt']) : null,
    achievements: (json['achievements'] as List?)
        ?.map((a) => Achievement.fromJson(a))
        .toList() ?? [],
  );

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'displayName': displayName,
    'level': level,
    'xp': xp,
    'xpToNextLevel': xpToNextLevel,
    'totalWins': totalWins,
    'totalLosses': totalLosses,
    'totalGames': totalGames,
    'currentStreak': currentStreak,
    'bestStreak': bestStreak,
    'totalPlayTimeMinutes': totalPlayTimeMinutes,
    'gamesByType': gamesByType,
    'winsByType': winsByType,
    'favoriteToyId': favoriteToyId,
    'lastPlayedAt': lastPlayedAt?.toIso8601String(),
    'achievements': achievements.map((a) => a.toJson()).toList(),
  };
}

/// Estado de una partida
class GameSession {
  String id;
  GameType type;
  GameStatus status;
  String hostId;
  List<GamePlayer> players;
  GameSettings settings;
  GameState state;
  DateTime? startedAt;
  DateTime? finishedAt;
  GameResult? result;

  GameSession({
    required this.id,
    required this.type,
    this.status = GameStatus.idle,
    required this.hostId,
    required this.players,
    required this.settings,
    required this.state,
    this.startedAt,
    this.finishedAt,
    this.result,
  });

  factory GameSession.create({
    required String hostId,
    required GameType type,
    required GameSettings settings,
  }) => GameSession(
    id: 'game_${DateTime.now().millisecondsSinceEpoch}',
    type: type,
    hostId: hostId,
    players: [],
    settings: settings,
    state: GameState.initial(type),
  );

  factory GameSession.fromJson(Map<String, dynamic> json) => GameSession(
    id: json['id'],
    type: GameType.values.firstWhere((e) => e.name == json['type']),
    status: GameStatus.values.firstWhere((e) => e.name == json['status']),
    hostId: json['hostId'],
    players: (json['players'] as List).map((p) => GamePlayer.fromJson(p)).toList(),
    settings: GameSettings.fromJson(json['settings']),
    state: GameState.fromJson(json['state']),
    startedAt: json['startedAt'] != null ? DateTime.parse(json['startedAt']) : null,
    finishedAt: json['finishedAt'] != null ? DateTime.parse(json['finishedAt']) : null,
    result: json['result'] != null ? GameResult.fromJson(json['result']) : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'status': status.name,
    'hostId': hostId,
    'players': players.map((p) => p.toJson()).toList(),
    'settings': settings.toJson(),
    'state': state.toJson(),
    'startedAt': startedAt?.toIso8601String(),
    'finishedAt': finishedAt?.toIso8601String(),
    'result': result?.toJson(),
  };
}

/// Jugador en partida
class GamePlayer {
  final String userId;
  final String displayName;
  final PlayerRole role;
  final int score;
  final bool isConnected;
  final int? toyId; // ID del juguete usado

  GamePlayer({
    required this.userId,
    required this.displayName,
    this.role = PlayerRole.guest,
    this.score = 0,
    this.isConnected = true,
    this.toyId,
  });

  factory GamePlayer.fromJson(Map<String, dynamic> json) => GamePlayer(
    userId: json['userId'],
    displayName: json['displayName'],
    role: PlayerRole.values.firstWhere((e) => e.name == json['role']),
    score: json['score'] ?? 0,
    isConnected: json['isConnected'] ?? true,
    toyId: json['toyId'],
  );

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'displayName': displayName,
    'role': role.name,
    'score': score,
    'isConnected': isConnected,
    'toyId': toyId,
  };
}

/// Configuración de juego
class GameSettings {
  final int maxPlayers;
  final int roundDurationSeconds;
  final int maxRounds;
  final bool allowSpectators;
  final bool isRanked;
  final bool allowToys;
  final Map<String, dynamic> customRules;

  GameSettings({
    this.maxPlayers = 2,
    this.roundDurationSeconds = 60,
    this.maxRounds = 3,
    this.allowSpectators = true,
    this.isRanked = false,
    this.allowToys = true,
    this.customRules = const {},
  });

  factory GameSettings.fromJson(Map<String, dynamic> json) => GameSettings(
    maxPlayers: json['maxPlayers'] ?? 2,
    roundDurationSeconds: json['roundDurationSeconds'] ?? 60,
    maxRounds: json['maxRounds'] ?? 3,
    allowSpectators: json['allowSpectators'] ?? true,
    isRanked: json['isRanked'] ?? false,
    allowToys: json['allowToys'] ?? true,
    customRules: Map<String, dynamic>.from(json['customRules'] ?? {}),
  );

  Map<String, dynamic> toJson() => {
    'maxPlayers': maxPlayers,
    'roundDurationSeconds': roundDurationSeconds,
    'maxRounds': maxRounds,
    'allowSpectators': allowSpectators,
    'isRanked': isRanked,
    'allowToys': allowToys,
    'customRules': customRules,
  };
}

/// Estado del juego (varía por tipo)
class GameState {
  int currentRound;
  int roundTimeRemaining;
  Map<String, dynamic> data; // Datos específicos por tipo

  GameState({
    this.currentRound = 0,
    this.roundTimeRemaining = 0,
    Map<String, dynamic>? data,
  }) : data = data ?? {};

  factory GameState.initial(GameType type) => GameState(
    currentRound: 0,
    roundTimeRemaining: 0,
    data: _getInitialData(type),
  );

  static Map<String, dynamic> _getInitialData(GameType type) {
    switch (type) {
      case GameType.dice:
        return {'diceValues': [1, 1], 'turn': 0};
      case GameType.roulette:
        return {'wheelPosition': 0, 'bets': {}};
      case GameType.memory:
        return {'sequence': [], 'playerSequence': [], 'showing': false};
      case GameType.reaction:
        return {'targetTime': 0, 'reactionTimes': []};
      case GameType.endurance:
        return {'startTime': 0, 'lastChange': 0};
      case GameType.rhythm:
        return {'beatIndex': 0, 'pattern': []};
      default:
        return {};
    }
  }

  factory GameState.fromJson(Map<String, dynamic> json) => GameState(
    currentRound: json['currentRound'] ?? 0,
    roundTimeRemaining: json['roundTimeRemaining'] ?? 0,
    data: Map<String, dynamic>.from(json['data'] ?? {}),
  );

  Map<String, dynamic> toJson() => {
    'currentRound': currentRound,
    'roundTimeRemaining': roundTimeRemaining,
    'data': data,
  };
}

/// Resultado de partida
class GameResult {
  final String winnerId;
  final Map<String, int> scores;
  final Map<String, int> xpGained;
  final List<Achievement> unlockedAchievements;
  final int durationSeconds;
  final Map<String, dynamic> metadata;

  GameResult({
    required this.winnerId,
    required this.scores,
    required this.xpGained,
    this.unlockedAchievements = const [],
    required this.durationSeconds,
    this.metadata = const {},
  });

  factory GameResult.fromJson(Map<String, dynamic> json) => GameResult(
    winnerId: json['winnerId'],
    scores: Map<String, int>.from(json['scores']),
    xpGained: Map<String, int>.from(json['xpGained']),
    unlockedAchievements: (json['unlockedAchievements'] as List)
        .map((a) => Achievement.fromJson(a))
        .toList(),
    durationSeconds: json['durationSeconds'],
    metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
  );

  Map<String, dynamic> toJson() => {
    'winnerId': winnerId,
    'scores': scores,
    'xpGained': xpGained,
    'unlockedAchievements': unlockedAchievements.map((a) => a.toJson()).toList(),
    'durationSeconds': durationSeconds,
    'metadata': metadata,
  };
}

/// Desafío diario/semanal
class DailyChallenge {
  final String id;
  final String name;
  final String description;
  final GameType type;
  final GameSettings settings;
  final int rewardXp;
  final int rewardCoins;
  final DateTime validFrom;
  final DateTime validUntil;
  final Map<String, dynamic> requirements;
  bool isCompleted;

  DailyChallenge({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.settings,
    this.rewardXp = 100,
    this.rewardCoins = 10,
    required this.validFrom,
    required this.validUntil,
    this.requirements = const {},
    this.isCompleted = false,
  });

  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(validFrom) && now.isBefore(validUntil);
  }

  factory DailyChallenge.fromJson(Map<String, dynamic> json) => DailyChallenge(
    id: json['id'],
    name: json['name'],
    description: json['description'],
    type: GameType.values.firstWhere((e) => e.name == json['type']),
    settings: GameSettings.fromJson(json['settings']),
    rewardXp: json['rewardXp'] ?? 100,
    rewardCoins: json['rewardCoins'] ?? 10,
    validFrom: DateTime.parse(json['validFrom']),
    validUntil: DateTime.parse(json['validUntil']),
    requirements: Map<String, dynamic>.from(json['requirements'] ?? {}),
    isCompleted: json['isCompleted'] ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'type': type.name,
    'settings': settings.toJson(),
    'rewardXp': rewardXp,
    'rewardCoins': rewardCoins,
    'validFrom': validFrom.toIso8601String(),
    'validUntil': validUntil.toIso8601String(),
    'requirements': requirements,
    'isCompleted': isCompleted,
  };
}

/// Servicio principal de modo juego
class GameModeService {
  final BleService _bleService;
  final ToyModel? _activeToy;

  GameSession? _currentSession;
  PlayerStats? _localPlayerStats;
  List<Achievement> _allAchievements = [];
  List<DailyChallenge> _dailyChallenges = [];
  Timer? _gameTimer;
  Timer? _roundTimer;
  Timer? _matchmakingTimer;

  // Callbacks
  Function(GameSession)? onSessionStateChange;
  Function(GamePlayer)? onPlayerJoined;
  Function(GamePlayer)? onPlayerLeft;
  Function(GameState)? onGameStateChange;
  Function(String)? onError;
  Function(Achievement)? onAchievementUnlocked;
  Function(int, int)? onXpGained; // xp, newLevel
  Function(GameResult)? onGameFinished;

  GameModeService({
    required BleService bleService,
    ToyModel? activeToy,
  }) : _bleService = bleService, _activeToy = null;

  GameSession? get currentSession => _currentSession;
  PlayerStats? get localPlayerStats => _localPlayerStats;
  List<Achievement> get allAchievements => _allAchievements;
  List<DailyChallenge> get dailyChallenges => _dailyChallenges;
  bool get isInGame => _currentSession != null && _currentSession!.status == GameStatus.playing;

  /// Inicializa el servicio
  Future<void> initialize() async {
    _loadAchievements();
    _generateDailyChallenges();
    _loadLocalStats();
    lvsLog('GameModeService inicializado', tag: 'GAME_MODE');
  }

  // ═══════════════════════════════════════════════════════════════
  // CREACIÓN DE PARTIDAS
  // ═══════════════════════════════════════════════════════════════

  /// Crea partida solo
  GameSession createSoloGame({
    required GameType type,
    GameSettings? settings,
  }) {
    final session = GameSession.create(
      hostId: 'local',
      type: type,
      settings: settings ?? _getDefaultSettings(type),
    );
    _startSession(session);
    return session;
  }

  /// Crea partida multijugador (host)
  GameSession createMultiplayerGame({
    required GameType type,
    required GameSettings settings,
  }) {
    final session = GameSession.create(
      hostId: 'local',
      type: type,
      settings: settings,
    );
    // Agregar host como jugador
    session.players.add(GamePlayer(
      userId: 'local',
      displayName: 'Tú',
      role: PlayerRole.host,
    ));
    _startSession(session);
    return session;
  }

  /// Une a partida (guest)
  Future<bool> joinGame(String sessionId, String userId, String displayName) async {
    // En producción: conectar via P2P/Supabase
    lvsLog('Uniendo a partida: $sessionId', tag: 'GAME_MODE');
    return true;
  }

  // ═══════════════════════════════════════════════════════════════
  // LÓGICA DE JUEGO POR TIPO
  // ═══════════════════════════════════════════════════════════════

  void _startSession(GameSession session) {
    _currentSession = session;
    session.status = GameStatus.countdown;
    session.startedAt = DateTime.now();
    onSessionStateChange?.call(session);

    // Cuenta regresiva 3-2-1
    int count = 3;
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (count > 0) {
        count--;
        // Notificar countdown
      } else {
        timer.cancel();
        _beginGame(session);
      }
    });
  }

  void _beginGame(GameSession session) {
    session.status = GameStatus.playing;
    session.state.currentRound = 1;
    onSessionStateChange?.call(session);
    _startRoundTimer(session);
  }

  void _startRoundTimer(GameSession session) {
    final duration = session.settings.roundDurationSeconds;
    session.state.roundTimeRemaining = duration;

    _roundTimer?.cancel();
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isSessionActive()) {
        timer.cancel();
        return;
      }

      session.state.roundTimeRemaining--;
      onGameStateChange?.call(_currentSession!.state);

      if (session.state.roundTimeRemaining <= 0) {
        timer.cancel();
        _endRound(_currentSession!);
      }
    });
  }

  bool _isSessionActive() {
    return _currentSession != null && _currentSession!.status == GameStatus.playing;
  }

  void _endRound(GameSession session) {
    session.state.currentRound++;
    
    if (session.state.currentRound >= session.settings.maxRounds) {
      _finishGame(session);
    } else {
      // Pausa entre rondas
      session.status = GameStatus.paused;
      onSessionStateChange?.call(session);
      
      Timer(const Duration(seconds: 3), () {
        if (_isSessionActive()) {
          session.status = GameStatus.playing;
          _startRoundTimer(session);
        }
      });
    }
  }

  void _finishGame(GameSession session) {
    session.status = GameStatus.finished;
    session.finishedAt = DateTime.now();
    session.state.roundTimeRemaining = 0;

    // Calcular resultado
    final result = _calculateResult(session);
    session.result = result;

    // Actualizar stats
    _updateStats(result);

    // Verificar logros
    _checkAchievements();

    onGameFinished?.call(result);
    onSessionStateChange?.call(session);
    
    _cleanupTimers();
    _currentSession = null;
  }

  GameResult _calculateResult(GameSession session) {
    // Lógica de victoria según tipo de juego
    final winnerId = session.players
        .reduce((a, b) => a.score > b.score ? a : b)
        .userId;

    final scores = {for (var p in session.players) p.userId: p.score};
    
    // XP basado en rendimiento
    final xpGained = <String, int>{};
    for (final player in session.players) {
      int baseXp = 50;
      if (player.userId == winnerId) baseXp += 50;
      baseXp += player.score;
      xpGained[player.userId] = baseXp;
    }

    return GameResult(
      winnerId: winnerId,
      scores: Map.fromEntries(session.players.map((p) => MapEntry(p.userId, p.score))),
      xpGained: xpGained,
      durationSeconds: session.finishedAt!.difference(session.startedAt!).inSeconds,
    );
  }

  void _cleanupTimers() {
    _gameTimer?.cancel();
    _roundTimer?.cancel();
    _matchmakingTimer?.cancel();
  }

  // ═══════════════════════════════════════════════════════════════
  // LÓGICA ESPECÍFICA POR TIPO DE JUEGO
  // ═══════════════════════════════════════════════════════════════

  void _executeGameLogic(GameSession session) {
    switch (session.type) {
      case GameType.dice:
        _updateDiceGame(session);
        break;
      case GameType.roulette:
        _updateRouletteGame(session);
        break;
      case GameType.memory:
        _updateMemoryGame(session);
        break;
      case GameType.reaction:
        _updateReactionGame(session);
        break;
      case GameType.endurance:
        _updateEnduranceGame(session);
        break;
      case GameType.rhythm:
        _updateRhythmGame(session);
        break;
      case GameType.versus:
      case GameType.coOp:
        _updateVersusGame(session);
        break;
      case GameType.challenge:
        _updateChallengeGame(session);
        break;
      default:
        break;
    }
    onGameStateChange?.call(session.state);
  }

  void _updateDiceGame(GameSession session) {
    // Lógica de dados: tirar dados, mover, efectos
    // En producción: integrar con BLE para vibrar en ciertos resultados
  }

  void _updateRouletteGame(GameSession session) {
    // Ruleta: girar, apuestas, pagos
  }

  void _updateMemoryGame(GameSession session) {
    // Memoria: mostrar secuencia, jugador repite
    // Vibrar en cada paso de la secuencia
  }

  void _updateReactionGame(GameSession session) {
    // Reacción: mostrar señal, medir tiempo respuesta
    // Vibrar cuando aparece señal
  }

  void _updateEnduranceGame(session) {
    // Resistencia: mantener patrón el mayor tiempo
    // Aumentar intensidad progresivamente
  }

  void _updateRhythmGame(session) {
    // Ritmo: seguir patrón musical
    // Sincronizar con BPM de canción
  }

  void _updateVersusGame(session) {
    // 1v1: sincronizar estado entre jugadores via P2P
  }

  void _updateChallengeGame(session) {
    // Desafío diario: objetivo específico
  }

  // ═══════════════════════════════════════════════════════════════
  // ESTADÍSTICAS Y LOGROS
  // ═══════════════════════════════════════════════════════════════

  void _loadAchievements() {
    _allAchievements = [
      // Logros básicos
      Achievement(
        id: 'first_win',
        name: 'Primera Victoria',
        description: 'Gana tu primera partida',
        iconPath: 'assets/icons/achievement_first_win.png',
        type: AchievementType.firstWin,
        requiredValue: 1,
        rewardXp: 50,
      ),
      Achievement(
        id: 'win_streak_3',
        name: 'En Racha',
        description: 'Gana 3 partidas seguidas',
        iconPath: 'assets/icons/achievement_streak.png',
        type: AchievementType.winStreak,
        requiredValue: 3,
        rewardXp: 100,
      ),
      Achievement(
        id: 'win_streak_10',
        name: 'Imparable',
        description: 'Gana 10 partidas seguidas',
        iconPath: 'assets/icons/achievement_streak_10.png',
        type: AchievementType.winStreak,
        requiredValue: 10,
        rewardXp: 500,
      ),
      Achievement(
        id: 'endurance_10min',
        name: 'Resistente',
        description: 'Aguanta 10 minutos en modo resistencia',
        iconPath: 'assets/icons/achievement_endurance.png',
        type: AchievementType.enduranceMaster,
        requiredValue: 600, // segundos
        rewardXp: 200,
      ),
      Achievement(
        id: 'pattern_master',
        name: 'Maestro de Patrones',
        description: 'Usa todos los 9 patrones en una partida',
        iconPath: 'assets/icons/achievement_patterns.png',
        type: AchievementType.patternMaster,
        requiredValue: 9,
        rewardXp: 150,
      ),
      Achievement(
        id: 'reaction_king',
        name: 'Rey de la Reacción',
        description: 'Tiempo de reacción < 200ms en modo reacción',
        iconPath: 'assets/icons/achievement_reaction.png',
        type: AchievementType.reactionKing,
        requiredValue: 200, // ms
        rewardXp: 200,
      ),
      Achievement(
        id: 'social_butterfly',
        name: 'Mariposa Social',
        description: 'Juega 10 partidas multijugador',
        iconPath: 'assets/icons/achievement_social.png',
        type: AchievementType.socialButterfly,
        requiredValue: 10,
        rewardXp: 100,
      ),
      Achievement(
        id: 'early_bird',
        name: 'Madrugador',
        description: 'Juega una partida antes de las 8 AM',
        iconPath: 'assets/icons/achievement_early.png',
        type: AchievementType.earlyBird,
        requiredValue: 1,
        rewardXp: 50,
      ),
      Achievement(
        id: 'night_owl',
        name: 'Noctámbulo',
        description: 'Juega una partida después de medianoche',
        iconPath: 'assets/icons/achievement_night.png',
        type: AchievementType.nightOwl,
        requiredValue: 1,
        rewardXp: 50,
      ),
      Achievement(
        id: 'comeback',
        name: 'Remontada',
        description: 'Gana perdiendo 0-2 en mejor de 3',
        iconPath: 'assets/icons/achievement_comeback.png',
        type: AchievementType.comeback,
        requiredValue: 1,
        rewardXp: 200,
      ),
      Achievement(
        id: 'perfect_game',
        name: 'Partida Perfecta',
        description: 'Gana sin recibir puntos en contra',
        iconPath: 'assets/icons/achievement_perfect.png',
        type: AchievementType.perfectGame,
        requiredValue: 1,
        rewardXp: 300,
      ),
      Achievement(
        id: 'marathon',
        name: 'Maratón',
        description: 'Juega 2 horas seguidas',
        iconPath: 'assets/icons/achievement_marathon.png',
        type: AchievementType.marathon,
        requiredValue: 120, // minutos
        rewardXp: 300,
      ),
    ];

    // Cargar estado desbloqueado desde storage
    _loadAchievementProgress();
  }

  void _loadAchievementProgress() {
    // Cargar desde SharedPreferences/SecureStorage
  }

  void _checkAchievements() {
    if (_currentSession == null || _localPlayerStats == null) return;

    for (final achievement in _allAchievements) {
      if (achievement.isUnlocked) continue;

      bool unlocked = false;
      
      switch (achievement.type) {
        case AchievementType.firstWin:
          unlocked = _localPlayerStats!.totalWins >= 1;
          break;
        case AchievementType.winStreak:
          unlocked = _localPlayerStats!.currentStreak >= achievement.requiredValue;
          break;
        case AchievementType.enduranceMaster:
          // Verificar tiempo en modo endurance
          break;
        case AchievementType.patternMaster:
          // Verificar patrones únicos usados
          break;
        case AchievementType.reactionKing:
          // Verificar tiempo reacción
          break;
        case AchievementType.socialButterfly:
          // Verificar partidas multijugador
          break;
        case AchievementType.earlyBird:
          final hour = DateTime.now().hour;
          unlocked = hour < 8;
          break;
        case AchievementType.nightOwl:
          final hour = DateTime.now().hour;
          unlocked = hour >= 0 && hour < 6;
          break;
        default:
          break;
      }

      if (unlocked) {
        _unlockAchievement(achievement);
      }
    }
  }

  void _unlockAchievement(Achievement achievement) {
    final unlocked = achievement.copyWith(unlockedAt: DateTime.now());
    final index = _allAchievements.indexWhere((a) => a.id == achievement.id);
    if (index != -1) {
      _allAchievements[index] = unlocked;
    }

    if (_localPlayerStats != null) {
      _localPlayerStats = PlayerStats(
        userId: _localPlayerStats!.userId,
        displayName: _localPlayerStats!.displayName,
        level: _localPlayerStats!.level,
        xp: _localPlayerStats!.xp + achievement.rewardXp,
        xpToNextLevel: _localPlayerStats!.xpToNextLevel,
        totalWins: _localPlayerStats!.totalWins,
        totalLosses: _localPlayerStats!.totalLosses,
        totalGames: _localPlayerStats!.totalGames,
        currentStreak: _localPlayerStats!.currentStreak,
        bestStreak: _localPlayerStats!.bestStreak,
        totalPlayTimeMinutes: _localPlayerStats!.totalPlayTimeMinutes,
        gamesByType: _localPlayerStats!.gamesByType,
        winsByType: _localPlayerStats!.winsByType,
        favoriteToyId: _localPlayerStats!.favoriteToyId,
        lastPlayedAt: _localPlayerStats!.lastPlayedAt,
        achievements: [..._localPlayerStats!.achievements, unlocked],
      );
      _saveLocalStats();
    }

    onAchievementUnlocked?.call(unlocked);
    lvsLog('¡Logro desbloqueado: ${achievement.name}!', tag: 'GAME_MODE');
  }

  // ═══════════════════════════════════════════════════════════════
  // DESAFÍOS DIARIOS
  // ═══════════════════════════════════════════════════════════════

  void _generateDailyChallenges() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    _dailyChallenges = [
      DailyChallenge(
        id: 'daily_${today.millisecondsSinceEpoch}',
        name: 'Desafío Diario',
        description: 'Gana 3 partidas de cualquier tipo',
        type: GameType.versus,
        settings: GameSettings(maxRounds: 3),
        rewardXp: 200,
        rewardCoins: 50,
        validFrom: today,
        validUntil: tomorrow,
        requirements: {'wins': 3},
      ),
      DailyChallenge(
        id: 'daily_endurance_${today.millisecondsSinceEpoch}',
        name: 'Resistencia Diaria',
        description: 'Aguanta 5 minutos en modo resistencia',
        type: GameType.endurance,
        settings: GameSettings(roundDurationSeconds: 300),
        rewardXp: 150,
        rewardCoins: 30,
        validFrom: today,
        validUntil: tomorrow,
        requirements: {'duration_seconds': 300},
      ),
    ];
  }

  // ═══════════════════════════════════════════════════════════════
  // ESTADÍSTICAS LOCALES
  // ═══════════════════════════════════════════════════════════════

  void _loadLocalStats() {
    // Cargar desde SharedPreferences
    _localPlayerStats = PlayerStats(
      userId: 'local',
      displayName: 'Jugador',
    );
  }

  void _saveLocalStats() {
    // Guardar en SharedPreferences
  }

  void _updateStats(GameResult result) {
    if (_localPlayerStats == null) return;

    final isWin = result.winnerId == 'local';
    _localPlayerStats = PlayerStats(
      userId: _localPlayerStats!.userId,
      displayName: _localPlayerStats!.displayName,
      level: _localPlayerStats!.level,
      xp: _localPlayerStats!.xp + (result.xpGained['local'] ?? 0),
      xpToNextLevel: _localPlayerStats!.xpToNextLevel,
      totalWins: _localPlayerStats!.totalWins + (isWin ? 1 : 0),
      totalLosses: _localPlayerStats!.totalLosses + (isWin ? 0 : 1),
      totalGames: _localPlayerStats!.totalGames + 1,
      currentStreak: isWin ? _localPlayerStats!.currentStreak + 1 : 0,
      bestStreak: math.max(_localPlayerStats!.bestStreak, isWin ? _localPlayerStats!.currentStreak + 1 : 0),
      totalPlayTimeMinutes: _localPlayerStats!.totalPlayTimeMinutes + (result.durationSeconds ~/ 60),
      gamesByType: Map.from(_localPlayerStats!.gamesByType)
        ..update(_currentSession!.type.name, (v) => v + 1, ifAbsent: () => 1),
      winsByType: isWin
          ? (() {
              final m = Map<String, int>.from(_localPlayerStats!.winsByType);
              m.update(_currentSession!.type.name, (v) => v + 1, ifAbsent: () => 1);
              return m;
            }())
          : _localPlayerStats!.winsByType,
      lastPlayedAt: DateTime.now(),
      achievements: _localPlayerStats!.achievements,
    );

    _saveLocalStats();
    
    // Verificar subida de nivel
    if (_localPlayerStats!.xp >= _localPlayerStats!.xpToNextLevel) {
      _levelUp();
    }
  }

  void _levelUp() {
    if (_localPlayerStats == null) return;
    
    _localPlayerStats = PlayerStats(
      userId: _localPlayerStats!.userId,
      displayName: _localPlayerStats!.displayName,
      level: _localPlayerStats!.level + 1,
      xp: _localPlayerStats!.xp - _localPlayerStats!.xpToNextLevel,
      xpToNextLevel: (_localPlayerStats!.level + 1) * 100,
      totalWins: _localPlayerStats!.totalWins,
      totalLosses: _localPlayerStats!.totalLosses,
      totalGames: _localPlayerStats!.totalGames,
      currentStreak: _localPlayerStats!.currentStreak,
      bestStreak: _localPlayerStats!.bestStreak,
      totalPlayTimeMinutes: _localPlayerStats!.totalPlayTimeMinutes,
      gamesByType: _localPlayerStats!.gamesByType,
      winsByType: _localPlayerStats!.winsByType,
      favoriteToyId: _localPlayerStats!.favoriteToyId,
      lastPlayedAt: _localPlayerStats!.lastPlayedAt,
      achievements: _localPlayerStats!.achievements,
    );
    
    onXpGained?.call(_localPlayerStats!.xp, _localPlayerStats!.level);
    lvsLog('¡Subiste al nivel ${_localPlayerStats!.level}!', tag: 'GAME_MODE');
  }

  // ═══════════════════════════════════════════════════════════════
  // CONFIGURACIONES POR DEFECTO
  // ═══════════════════════════════════════════════════════════════

  GameSettings _getDefaultSettings(GameType type) {
    switch (type) {
      case GameType.dice:
        return GameSettings(maxRounds: 5, roundDurationSeconds: 30);
      case GameType.roulette:
        return GameSettings(maxRounds: 10, roundDurationSeconds: 20);
      case GameType.memory:
        return GameSettings(maxRounds: 3, roundDurationSeconds: 60);
      case GameType.reaction:
        return GameSettings(maxRounds: 10, roundDurationSeconds: 5);
      case GameType.endurance:
        return GameSettings(maxRounds: 1, roundDurationSeconds: 300);
      case GameType.rhythm:
        return GameSettings(maxRounds: 1, roundDurationSeconds: 180);
      case GameType.versus:
      case GameType.coOp:
        return GameSettings(maxRounds: 3, roundDurationSeconds: 60, isRanked: true);
      case GameType.challenge:
        return GameSettings(maxRounds: 1, roundDurationSeconds: 300);
      default:
        return GameSettings();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // UTILIDADES PÚBLICAS
  // ═══════════════════════════════════════════════════════════════

  /// Obtiene configuración por defecto para tipo
  static GameSettings getDefaultSettingsForType(GameType type) {
    final service = GameModeService(bleService: BleService());
    return service._getDefaultSettings(type);
  }

  /// Obtiene todos los logros (para UI)
  List<Achievement> getAchievements({bool onlyUnlocked = false}) {
    return onlyUnlocked 
        ? _allAchievements.where((a) => a.isUnlocked).toList()
        : _allAchievements;
  }

  /// Obtiene desafíos activos
  List<DailyChallenge> getActiveChallenges() {
    final now = DateTime.now();
    return _dailyChallenges.where((c) => c.isActive && !c.isCompleted).toList();
  }

  /// Obtiene progreso hacia siguiente nivel
  double get levelProgress {
    if (_localPlayerStats == null) return 0.0;
    return _localPlayerStats!.xp / _localPlayerStats!.xpToNextLevel;
  }

  /// Cancela partida actual
  void cancelGame() {
    if (_currentSession != null) {
      _currentSession!.status = GameStatus.cancelled;
      _currentSession!.finishedAt = DateTime.now();
      onSessionStateChange?.call(_currentSession!);
      _cleanupTimers();
      _currentSession = null;
    }
  }

  void dispose() {
    _cleanupTimers();
  }
}

/// Provider para Riverpod
final gameModeServiceProvider = Provider.family<GameModeService, ToyModel?>((ref, toy) {
  final ble = ref.read(bleProvider);
  return GameModeService(
    bleService: ble,
    activeToy: toy,
  );
});