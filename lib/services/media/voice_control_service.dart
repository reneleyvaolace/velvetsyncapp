// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/media/voice_control_service.dart
// Voice Control Service - Control por voz del juguete
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velvet_sync/services/ble/ble_service.dart';
import 'package:velvet_sync/services/ble/lovespouse_protocol.dart';
import 'package:velvet_sync/services/ble/lvs_commands.dart';
import 'package:velvet_sync/services/ble/ble_protocol.dart';
import 'package:velvet_sync/devices/models/toy_model.dart';
import 'package:velvet_sync/utils/logger.dart';

/// Comando de voz reconocido
class VoiceCommand {
  final String rawText;
  final VoiceCommandType type;
  final Map<String, dynamic> parameters;
  final double confidence;
  final DateTime timestamp;

  VoiceCommand({
    required this.rawText,
    required this.type,
    required this.parameters,
    required this.confidence,
    required this.timestamp,
  });

  @override
  String toString() => 'VoiceCommand(type: $type, params: $parameters, confidence: ${confidence.toStringAsFixed(2)})';
}

/// Tipos de comandos de voz soportados
enum VoiceCommandType {
  // Control básico
  stop,           // "para", "detente", "stop"
  start,          // "inicia", "empieza", "start"
  
  // Intensidad
  increase,       // "más fuerte", "sube", "más intensidad", "up"
  decrease,       // "más suave", "baja", "menos intensidad", "down"
  setIntensity,   // "intensidad 50", "ponlo al 80", "nivel 3"
  
  // Patrones
  pattern,        // "patrón 3", "cambia a patrón 2", "siguiente patrón"
  nextPattern,    // "siguiente", "next"
  previousPattern,// "anterior", "previous"
  
  // Canales
  channel1,       // "canal 1", "solo empuje", "solo canal 1"
  channel2,       // "canal 2", "solo vibración", "solo canal 2"
  bothChannels,   // "ambos", "los dos", "dual"
  
  // Funciones especiales
  heating,        // "calor", "calefacción", "heating on"
  heatingOff,     // "sin calor", "apaga calor", "heating off"
  heatingLevel,   // "calor 3", "nivel de calor 2"
  strike,         // "golpeteo", "strike", "golpea"
  strikeOff,      // "para golpeteo", "stop strike"
  strikePattern,  // "golpeteo 3"
  suction,        // "succión", "suction on"
  suctionOff,     // "para succión", "suction off"
  suctionLevel,   // "succión 2"
  
  // Modos
  modeGame,       // "modo juego", "juego"
  modeMusic,      // "modo música", "reactivo"
  modeVideo,      // "modo video", "sync video"
  
  // Sincronización
  syncVideo,      // "sincroniza video", "play video"
  syncMusic,      // "sincroniza música", "reactivo audio"
  
  // Consultas
  battery,        // "batería", "cuánta batería", "nivel batería"
  status,         // "estado", "cómo estás", "qué tal"
  
  // Desconocido
  unknown,
}

/// Configuración de comandos de voz
class VoiceControlConfig {
  final String language;           // 'es-ES', 'en-US', etc.
  final double confidenceThreshold; // 0.0 - 1.0
  final bool continuousListening;  // Escucha continua vs push-to-talk
  final Duration silenceTimeout;   // Timeout silencio para auto-stop
  final bool requireWakeWord;      // Requiere palabra de activación
  final List<String> wakeWords;    // Palabras de activación
  final bool hapticFeedback;       // Feedback háptico en comandos
  final bool audioFeedback;        // Feedback de audio (TTS)

  const VoiceControlConfig({
    this.language = 'es-ES',
    this.confidenceThreshold = 0.7,
    this.continuousListening = false,
    this.silenceTimeout = const Duration(seconds: 5),
    this.requireWakeWord = true,
    this.wakeWords = const ['velvet', 'hey velvet', 'ok velvet'],
    this.hapticFeedback = true,
    this.audioFeedback = false,
  });

  VoiceControlConfig copyWith({
    String? language,
    double? confidenceThreshold,
    bool? continuousListening,
    Duration? silenceTimeout,
    bool? requireWakeWord,
    List<String>? wakeWords,
    bool? hapticFeedback,
    bool? audioFeedback,
  }) {
    return VoiceControlConfig(
      language: language ?? this.language,
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      continuousListening: continuousListening ?? this.continuousListening,
      silenceTimeout: silenceTimeout ?? this.silenceTimeout,
      requireWakeWord: requireWakeWord ?? this.requireWakeWord,
      wakeWords: wakeWords ?? this.wakeWords,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      audioFeedback: audioFeedback ?? this.audioFeedback,
    );
  }
}

/// Resultado de procesamiento de voz
class VoiceResult {
  final VoiceCommand? command;
  final String? error;
  final bool isWakeWord;

  VoiceResult._(this.command, this.error, this.isWakeWord);

  factory VoiceResult.success(VoiceCommand command, {bool isWakeWord = false}) {
    return VoiceResult._(command, null, isWakeWord);
  }

  factory VoiceResult.error(String error) {
    return VoiceResult._(null, error, false);
  }

  bool get success => command != null;
}

/// Servicio de control por voz
class VoiceControlService {
  final VoiceControlConfig config;
  final BleService _bleService;
  final ToyModel? _activeToy;

  StreamSubscription? _speechSubscription;
  Timer? _silenceTimer;
  bool _isListening = false;
  bool _wakeWordDetected = false;
  DateTime? _lastCommandTime;

  // Callbacks
  Function(VoiceCommand)? onCommandRecognized;
  Function(String)? onError;
  Function(bool)? onListeningStateChange;
  Function(String)? onPartialResult; // Para resultados parciales (streaming)

  VoiceControlService({
    required this.config,
    required BleService bleService,
    ToyModel? activeToy,
  }) : _bleService = bleService,
       _activeToy = activeToy;

  bool get isListening => _isListening;
  bool get wakeWordActive => _wakeWordDetected;

  /// Inicializa el servicio de voz
  Future<bool> initialize() async {
    // NOTA: En producción usarías:
    // - speech_to_text (package:speech_to_text)
    // - flutter_speech (para streaming)
    // - google_ml_kit / ml_kit (on-device)
    // - Vosk / PocketSphinx (offline)
    // - Platform channels para SpeechRecognizer nativo
    
    lvsLog('VoiceControlService inicializado', tag: 'VOICE_CONTROL');
    return true;
  }

  /// Inicia escucha
  Future<void> startListening() async {
    if (_isListening) return;
    
    _isListening = true;
    _wakeWordDetected = config.requireWakeWord ? false : true;
    onListeningStateChange?.call(true);
    
    lvsLog('Iniciando escucha de voz', tag: 'VOICE_CONTROL');
    
    // NOTA: Implementación real usaría speech_to_text:
    /*
    final speech = SpeechToText();
    await speech.initialize();
    speech.listen(
      onResult: _onSpeechResult,
      listenFor: config.silenceTimeout,
      localeId: config.language,
      partialResults: true,
    );
    */
    
    // Simulación para demo
    _simulateListening();
  }

  /// Simulación de escucha para demo
  void _simulateListening() {
    final testCommands = [
      'velvet para',
      'velvet más fuerte',
      'velvet patrón 3',
      'velvet canal 1',
      'velvet calor 2',
      'velvet golpeteo',
      'velvet batería',
      'velvet stop',
    ];
    
    int index = 0;
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isListening) {
        timer.cancel();
        return;
      }
      
      if (index < testCommands.length) {
        _processVoiceInput(testCommands[index]);
        index++;
      } else {
        timer.cancel();
        stopListening();
      }
    });
  }

  /// Procesa entrada de voz
  void _processVoiceInput(String text) {
    final command = _parseVoiceCommand(text);
    
    if (command != null) {
      if (command.type == VoiceCommandType.unknown) return;
      
      _lastCommandTime = DateTime.now();
      _executeCommand(command);
      onCommandRecognized?.call(command);
      
      // Reset silence timer
      _resetSilenceTimer();
    }
    
    onPartialResult?.call(text);
  }

  /// Parsea texto a comando estructurado
  VoiceCommand? _parseVoiceCommand(String text) {
    final lower = text.toLowerCase().trim();
    
    // Verificar wake word si es requerido
    if (config.requireWakeWord && !_wakeWordDetected) {
      for (final wakeWord in config.wakeWords) {
        if (lower.contains(wakeWord.toLowerCase())) {
          _wakeWordDetected = true;
          // Remover wake word del texto para parsing
          final cleaned = lower.replaceFirst(wakeWord.toLowerCase(), '').trim();
          return _parseCommand(cleaned, text, 0.9);
        }
      }
      return null; // No wake word detectada
    }
    
    return _parseCommand(lower, text, 0.85);
  }

  VoiceCommand? _parseCommand(String text, String original, double baseConfidence) {
    // Patrones de comandos (ordenados por prioridad)
    final patterns = <VoiceCommandType, List<RegExp>>{
      // Stop - máxima prioridad
      VoiceCommandType.stop: [
        RegExp(r'\b(para|detente|stop|alto|quieto)\b'),
      ],
      
      // Intensidad
      VoiceCommandType.increase: [
        RegExp(r'\b(m[aá]s fuerte|sube|m[aá]s intensidad|up|aumenta|m[aá]ximo)\b'),
      ],
      VoiceCommandType.decrease: [
        RegExp(r'\b(m[aá]s suave|baja|menos intensidad|down|disminuye|m[ií]nimo)\b'),
      ],
      VoiceCommandType.setIntensity: [
        RegExp(r'\b(intensidad|nivel|ponlo al?)\s+(\d{1,3})\b'),
        RegExp(r'\b(\d{1,3})\s*(%|por ciento)\b'),
      ],
      
      // Patrones
      VoiceCommandType.pattern: [
        RegExp(r'\b(patr[oó]n|modo)\s+(\d{1,2})\b'),
        RegExp(r'\bcambia a patr[oó]n\s+(\d{1,2})\b'),
      ],
      VoiceCommandType.nextPattern: [
        RegExp(r'\b(siguiente|next|otro patr[oó]n)\b'),
      ],
      VoiceCommandType.previousPattern: [
        RegExp(r'\b(anterior|previous|patr[oó]n anterior)\b'),
      ],
      
      // Canales
      VoiceCommandType.channel1: [
        RegExp(r'\b(canal 1|solo empuje|solo canal 1|empuje)\b'),
      ],
      VoiceCommandType.channel2: [
        RegExp(r'\b(canal 2|solo vibraci[oó]n|solo canal 2|vibraci[oó]n)\b'),
      ],
      VoiceCommandType.bothChannels: [
        RegExp(r'\b(ambos|los dos|dual|los dos canales)\b'),
      ],
      
      // Funciones especiales
      VoiceCommandType.heating: [
        RegExp(r'\b(calor|calefacci[oó]n|heating on|enciende calor)\b'),
      ],
      VoiceCommandType.heatingOff: [
        RegExp(r'\b(sin calor|apaga calor|heating off|apaga calefacci[oó]n)\b'),
      ],
      VoiceCommandType.heatingLevel: [
        RegExp(r'\b(calor|nivel de calor)\s+(\d{1,2})\b'),
      ],
      VoiceCommandType.strike: [
        RegExp(r'\b(golpeteo|strike|golpea)\b'),
      ],
      VoiceCommandType.strikeOff: [
        RegExp(r'\b(para golpeteo|stop strike|apaga golpeteo)\b'),
      ],
      VoiceCommandType.strikePattern: [
        RegExp(r'\b(golpeteo|strike)\s+(\d{1,2})\b'),
      ],
      VoiceCommandType.suction: [
        RegExp(r'\b(succi[oó]n|suction on|enciende succi[oó]n)\b'),
      ],
      VoiceCommandType.suctionOff: [
        RegExp(r'\b(para succi[oó]n|suction off|apaga succi[oó]n)\b'),
      ],
      VoiceCommandType.suctionLevel: [
        RegExp(r'\b(succi[oó]n)\s+(\d{1,2})\b'),
      ],
      
      // Modos
      VoiceCommandType.modeGame: [
        RegExp(r'\b(modo juego|juego|game mode)\b'),
      ],
      VoiceCommandType.modeMusic: [
        RegExp(r'\b(modo m[uo]sica|reactivo|music mode|audio reactivo)\b'),
      ],
      VoiceCommandType.modeVideo: [
        RegExp(r'\b(modo video|video sync|video mode)\b'),
      ],
      
      // Sincronización
      VoiceCommandType.syncVideo: [
        RegExp(r'\b(sincroniza video|play video|reproduce video)\b'),
      ],
      VoiceCommandType.syncMusic: [
        RegExp(r'\b(sincroniza m[uo]sica|reactivo audio|music sync)\b'),
      ],
      
      // Consultas
      VoiceCommandType.battery: [
        RegExp(r'\b(bater[ii]a|cu[aá]nta bater[ii]a|nivel bater[ii]a)\b'),
      ],
      VoiceCommandType.status: [
        RegExp(r'\b(estado|c[oó]mo est[aá]s|qu[eé] tal)\b'),
      ],
    };

    for (final entry in patterns.entries) {
      for (final pattern in entry.value) {
        final match = pattern.firstMatch(text);
        if (match != null) {
          return _buildCommand(entry.key, match, text);
        }
      }
    }

    return VoiceCommand(
      rawText: text,
      type: VoiceCommandType.unknown,
      parameters: {},
      confidence: 0.0,
      timestamp: DateTime.now(),
    );
  }

  VoiceCommand _buildCommand(VoiceCommandType type, Match match, String original) {
    final params = <String, dynamic>{};
    
    // Extraer parámetros numéricos
    for (int i = 1; i <= match.groupCount; i++) {
      final group = match.group(i);
      if (group != null) {
        final numVal = int.tryParse(group);
        if (numVal != null) {
          params['value'] = numVal.clamp(0, 255);
          params['valuePercent'] = (numVal / 100.0).clamp(0.0, 1.0);
        }
      }
    }

    return VoiceCommand(
      rawText: match.input,
      type: type,
      parameters: params,
      confidence: 0.85,
      timestamp: DateTime.now(),
    );
  }

  /// Ejecuta comando en el juguete
  Future<void> _executeCommand(VoiceCommand command) async {
    if (_activeToy == null) {
      lvsLog('No hay juguete activo para comando de voz', tag: 'VOICE_CONTROL');
      return;
    }

    try {
      final proto = detectBleProtocol(_activeToy!);
      
      switch (command.type) {
        case VoiceCommandType.stop:
          await _bleService.emergencyStop();
          break;
          
        case VoiceCommandType.increase:
          _increaseIntensity();
          break;
          
        case VoiceCommandType.decrease:
          _decreaseIntensity();
          break;
          
        case VoiceCommandType.setIntensity:
          final value = command.parameters['value'] ?? 128;
          await _setIntensity(value);
          break;
          
        case VoiceCommandType.pattern:
          final pattern = command.parameters['value'] ?? 1;
          await _setPattern(pattern);
          break;
          
        case VoiceCommandType.nextPattern:
          _nextPattern();
          break;
          
        case VoiceCommandType.previousPattern:
          _previousPattern();
          break;
          
        case VoiceCommandType.channel1:
          await _setChannel(1);
          break;
          
        case VoiceCommandType.channel2:
          await _setChannel(2);
          break;
          
        case VoiceCommandType.bothChannels:
          await _setChannel(0); // 0 = ambos
          break;
          
        case VoiceCommandType.heating:
          await _setHeating(true);
          break;
          
        case VoiceCommandType.heatingOff:
          await _setHeating(false);
          break;
          
        case VoiceCommandType.heatingLevel:
          final level = command.parameters['value'] ?? 128;
          await _setHeatingLevel(level);
          break;
          
        case VoiceCommandType.strike:
          await _setStrike(true);
          break;
          
        case VoiceCommandType.strikeOff:
          await _setStrike(false);
          break;
          
        case VoiceCommandType.strikePattern:
          final pattern = command.parameters['value'] ?? 1;
          await _setStrikePattern(pattern);
          break;
          
        case VoiceCommandType.suction:
          await _setSuction(true);
          break;
          
        case VoiceCommandType.suctionOff:
          await _setSuction(false);
          break;
          
        case VoiceCommandType.suctionLevel:
          final level = command.parameters['value'] ?? 128;
          await _setSuctionLevel(level);
          break;
          
        case VoiceCommandType.battery:
          // Solicitar telemetría de batería
          if (_activeToy?.bleProtocol == BleProtocolType.loveSpouse) {
            await _bleService.writeCommand([LoveSpouseCommands.telemetryBatteryCmd, 0x00, 0x00], label: 'BATTERY_REQUEST');
          }
          break;
          
        case VoiceCommandType.status:
          // Respuesta de estado por TTS si está habilitado
          break;
          
        default:
          lvsLog('Comando no implementado: ${command.type}', tag: 'VOICE_CONTROL');
      }
      
      // Feedback háptico
      if (config.hapticFeedback) {
        await _bleService.writeCommand(LvsCommands.patternFor(LvsPattern.pat1), label: 'VOICE_FEEDBACK', silent: true);
      }
      
    } catch (e) {
      lvsLog('Error ejecutando comando de voz: $e', tag: 'VOICE_CONTROL');
      onError?.call('Error ejecutando comando: $e');
    }
  }

  // Métodos helper para comandos
  void _increaseIntensity() {
    final current = _bleService.displayIntensity;
    final newIntensity = (current + 20).clamp(0, 100);
    _bleService.setProportionalIntensity(newIntensity);
  }

  void _decreaseIntensity() {
    final current = _bleService.displayIntensity;
    final newIntensity = (current - 20).clamp(0, 100);
    _bleService.setProportionalIntensity(newIntensity);
  }

  Future<void> _setIntensity(int value) async {
    await _bleService.setProportionalIntensity(value);
  }

  Future<void> _setPattern(int pattern) async {
    if (_activeToy?.hasDualChannel == true) {
      await _bleService.setDevicePatternCh1(PatternButton(
        id: pattern,
        name: 'Pattern $pattern',
        command: pattern,
        stopCommand: 0,
        imageUrl: '',
        newCommand: '',
      ), pattern);
      await _bleService.setDevicePatternCh2(PatternButton(
        id: pattern,
        name: 'Pattern $pattern',
        command: pattern,
        stopCommand: 0,
        imageUrl: '',
        newCommand: '',
      ), pattern);
    } else {
      await _bleService.selectPattern(LvsPattern.values[pattern.clamp(1, 9) - 1]);
    }
  }

  void _nextPattern() {
    if (_activeToy?.hasDualChannel == true) {
      final current = _bleService.activePatternCh1 ?? 0;
      _setPattern((current % 9) + 1);
    }
  }

  void _previousPattern() {
    if (_activeToy?.hasDualChannel == true) {
      final current = _bleService.activePatternCh1 ?? 1;
      _setPattern(current > 1 ? current - 1 : 9);
    }
  }

  Future<void> _setChannel(int channel) async {
    // 0 = ambos, 1 = CH1, 2 = CH2
    // Implementar según protocolo
  }

  Future<void> _setHeating(bool on) async {
    if (_activeToy?.bleProtocol == BleProtocolType.loveSpouse) {
      await _bleService.writeCommand(
        on ? LoveSpouseCommands.heatingOn : LoveSpouseCommands.heatingOff,
        label: 'VOICE_HEATING',
      );
    } else {
      await _bleService.writeCommand(
        on ? LvsCommands.heatingOn : LvsCommands.heatingOff,
        label: 'VOICE_HEATING',
      );
    }
  }

  Future<void> _setHeatingLevel(int level) async {
    if (_activeToy?.bleProtocol == BleProtocolType.loveSpouse) {
      await _bleService.writeCommand(
        LoveSpouseCommands.heatingLevel(level),
        label: 'VOICE_HEATING_LVL',
      );
    }
  }

  Future<void> _setStrike(bool on) async {
    if (_activeToy?.bleProtocol == BleProtocolType.loveSpouse) {
      await _bleService.writeCommand(
        on ? LoveSpouseCommands.strikeOn : LoveSpouseCommands.strikeOff,
        label: on ? 'VOICE_STRIKE_ON' : 'VOICE_STRIKE_OFF',
      );
    }
  }

  Future<void> _setStrikePattern(int pattern) async {
    if (_activeToy?.bleProtocol == BleProtocolType.loveSpouse) {
      await _bleService.writeCommand(
        LoveSpouseCommands.strikePattern(pattern - 1),
        label: 'VOICE_STRIKE_PAT',
      );
    }
  }

  Future<void> _setSuction(bool on) async {
    if (_activeToy?.bleProtocol == BleProtocolType.loveSpouse) {
      await _bleService.writeCommand(
        on ? LoveSpouseCommands.suctionOn : LoveSpouseCommands.suctionOff,
        label: on ? 'VOICE_SUCTION_ON' : 'VOICE_SUCTION_OFF',
      );
    }
  }

  Future<void> _setSuctionLevel(int level) async {
    if (_activeToy?.bleProtocol == BleProtocolType.loveSpouse) {
      await _bleService.writeCommand(
        LoveSpouseCommands.suctionLevel(level),
        label: 'VOICE_SUCTION_LVL',
      );
    }
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    if (config.continuousListening) {
      _silenceTimer = Timer(config.silenceTimeout, () {
        if (config.continuousListening && _isListening) {
          lvsLog('Timeout de silencio, deteniendo escucha', tag: 'VOICE_CONTROL');
          stopListening();
        }
      });
    }
  }

  /// Detiene escucha
  void stopListening() {
    _isListening = false;
    _wakeWordDetected = false;
    _silenceTimer?.cancel();
    onListeningStateChange?.call(false);
    lvsLog('Escucha de voz detenida', tag: 'VOICE_CONTROL');
  }

  /// Alterna escucha
  void toggleListening() {
    if (_isListening) {
      stopListening();
    } else {
      startListening();
    }
  }

  void dispose() {
    stopListening();
    _silenceTimer?.cancel();
  }
}

/// Provider para Riverpod
final voiceControlServiceProvider = Provider.family<VoiceControlService, ToyModel?>((ref, toy) {
  final ble = ref.read(bleProvider);
  return VoiceControlService(
    config: const VoiceControlConfig(),
    bleService: ble,
    activeToy: toy,
  );
});