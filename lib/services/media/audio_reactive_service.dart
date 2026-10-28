// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/media/audio_reactive_service.dart
// Audio Reactive Service - Reactividad a micrófono/archivo de audio
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velvet_sync/services/ble/ble_service.dart';
import 'package:velvet_sync/services/ble/lovespouse_protocol.dart';
import 'package:velvet_sync/services/ble/lvs_commands.dart';
import 'package:velvet_sync/services/ble/ble_protocol.dart';
import 'package:velvet_sync/utils/logger.dart';

/// Configuración de reactividad
class AudioReactiveConfig {
  final double sensitivity;        // 0.0 - 1.0
  final double smoothing;          // 0.0 - 1.0 (suavizado temporal)
  final double minIntensity;       // 0.0 - 1.0 (intensidad mínima)
  final double maxIntensity;       // 0.0 - 1.0 (intensidad máxima)
  final int fftSize;               // Tamaño FFT (256, 512, 1024, 2048)
  final int sampleRate;            // Sample rate (44100, 48000)
  final bool useBassOnly;          // Solo frecuencias bajas (bass)
  final double bassThreshold;      // Umbral frecuencia grave (Hz)
  final int updateIntervalMs;      // Intervalo actualización BLE (ms)

  const AudioReactiveConfig({
    this.sensitivity = 0.5,
    this.smoothing = 0.3,
    this.minIntensity = 0.1,
    this.maxIntensity = 1.0,
    this.fftSize = 1024,
    this.sampleRate = 44100,
    this.useBassOnly = true,
    this.bassThreshold = 250.0,    // Hz
    this.updateIntervalMs = 50,
  });

  AudioReactiveConfig copyWith({
    double? sensitivity,
    double? smoothing,
    double? minIntensity,
    double? maxIntensity,
    int? fftSize,
    int? sampleRate,
    bool? useBassOnly,
    double? bassThreshold,
    int? updateIntervalMs,
  }) {
    return AudioReactiveConfig(
      sensitivity: sensitivity ?? this.sensitivity,
      smoothing: smoothing ?? this.smoothing,
      minIntensity: minIntensity ?? this.minIntensity,
      maxIntensity: maxIntensity ?? this.maxIntensity,
      fftSize: fftSize ?? this.fftSize,
      sampleRate: sampleRate ?? this.sampleRate,
      useBassOnly: useBassOnly ?? this.useBassOnly,
      bassThreshold: bassThreshold ?? this.bassThreshold,
      updateIntervalMs: updateIntervalMs ?? this.updateIntervalMs,
    );
  }
}

/// Datos de análisis de audio
class AudioAnalysisData {
  final double rms;               // Root Mean Square (volumen general)
  final double peak;              // Pico máximo
  final double bassEnergy;        // Energía en frecuencias graves
  final double midEnergy;         // Energía en medios
  final double trebleEnergy;      // Energía en agudos
  final List<double> spectrum;    // Espectro completo (normalizado 0-1)
  final double centroid;          // Centroide espectral
  final double flux;              // Flux espectral (cambio)
  final DateTime timestamp;

  const AudioAnalysisData({
    required this.rms,
    required this.peak,
    required this.bassEnergy,
    required this.midEnergy,
    required this.trebleEnergy,
    required this.spectrum,
    required this.centroid,
    required this.flux,
    required this.timestamp,
  });

  /// Obtiene intensidad mapeada para BLE (0-255)
  int getBleIntensity(AudioReactiveConfig config) {
    double source = config.useBassOnly ? bassEnergy : rms;
    final mapped = config.minIntensity + (source * (config.maxIntensity - config.minIntensity));
    return (mapped.clamp(0.0, 1.0) * 255).round();
  }

  /// Obtiene intensidades por canal (CH1=bass, CH2=mid/treble)
  (int ch1, int ch2) getBleDualIntensity(AudioReactiveConfig config) {
    final ch1 = (config.minIntensity + bassEnergy * (config.maxIntensity - config.minIntensity)).clamp(0.0, 1.0);
    final ch2 = (config.minIntensity + (midEnergy + trebleEnergy) / 2 * (config.maxIntensity - config.minIntensity)).clamp(0.0, 1.0);
    return ((ch1 * 255).round(), (ch2 * 255).round());
  }
}

/// Fuente de audio
enum AudioSource {
  microphone,    // Micrófono del dispositivo
  file,          // Archivo de audio local
  stream,        // Stream de audio (URL)
  system,        // Audio del sistema (requiere root/permisos especiales)
}

/// Servicio de reactividad de audio
class AudioReactiveService {
  final AudioReactiveConfig config;
  final BleService _bleService;

  AudioSource _source = AudioSource.microphone;
  StreamSubscription<Uint8List>? _audioSubscription;
  Timer? _analysisTimer;
  Timer? _bleUpdateTimer;
  AudioAnalysisData? _lastAnalysis;
  AudioAnalysisData? _smoothedAnalysis;
  bool _isActive = false;
  bool _isProcessing = false;

  // Para análisis de archivo
  String? _currentAudioFile;
  double _filePosition = 0.0;

  // Callbacks
  Function(AudioAnalysisData)? onAnalysisUpdate;
  Function(bool)? onStateChange;
  Function(String)? onError;

  AudioReactiveService(this.config, this._bleService);

  bool get isActive => _isActive;
  AudioSource get source => _source;
  AudioAnalysisData? get lastAnalysis => _smoothedAnalysis ?? _lastAnalysis;
  double get currentRms => _smoothedAnalysis?.rms ?? _lastAnalysis?.rms ?? 0.0;
  double get currentBass => _smoothedAnalysis?.bassEnergy ?? _lastAnalysis?.bassEnergy ?? 0.0;
  bool get isProcessing => _isProcessing;

  /// Inicializa y solicita permisos
  Future<bool> initialize({AudioSource source = AudioSource.microphone}) async {
    _source = source;

    if (source == AudioSource.microphone) {
      lvsLog('AudioReactiveService inicializado (fuente: ${source.name})', tag: 'AUDIO_REACTIVE');
      return true;
    }

    return true;
  }

  /// Inicia análisis de audio
  Future<void> start() async {
    if (_isActive) return;

    _isActive = true;
    _isProcessing = true;
    onStateChange?.call(true);

    try {
      switch (_source) {
        case AudioSource.microphone:
          await _startMicrophone();
          break;
        case AudioSource.file:
          await _startFileAnalysis();
          break;
        case AudioSource.stream:
          await _startStreamAnalysis();
          break;
        case AudioSource.system:
          onError?.call('Audio del sistema no disponible en esta versión');
          break;
      }

      // Timer para envío BLE
      _bleUpdateTimer = Timer.periodic(
        Duration(milliseconds: config.updateIntervalMs),
        (_) => _sendBleUpdate(),
      );

    } catch (e) {
      _isActive = false;
      _isProcessing = false;
      onError?.call('Error iniciando análisis: $e');
      onStateChange?.call(false);
    }
  }

  /// Inicia captura de micrófono
  Future<void> _startMicrophone() async {
    // NOTA: En producción usarías un paquete como:
    // - flutter_audio_capture
    // - record
    // - audio_waveforms (para visualización)
    // Por ahora simulamos para demo
    
    _simulateMicrophone();
  }

  /// Simulación de micrófono para demo (reemplazar con captura real)
  void _simulateMicrophone() {
    final random = math.Random();
    _analysisTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_isActive) return;
      
      // Simular datos de audio con patrones realistas
      final baseRms = 0.2 + 0.3 * math.sin(DateTime.now().millisecondsSinceEpoch / 500.0);
      final bass = 0.3 + 0.4 * math.sin(DateTime.now().millisecondsSinceEpoch / 300.0);
      final noise = (random.nextDouble() - 0.5) * 0.1;
      
      final rms = (baseRms + noise).clamp(0.0, 1.0);
      final bassEnergy = (bass + noise).clamp(0.0, 1.0);
      final midEnergy = (0.4 + 0.2 * math.sin(DateTime.now().millisecondsSinceEpoch / 700.0)).clamp(0.0, 1.0);
      final trebleEnergy = (0.2 + 0.3 * math.sin(DateTime.now().millisecondsSinceEpoch / 1100.0)).clamp(0.0, 1.0);

      _processAudioFrame(
        rms: rms,
        bass: bassEnergy,
        mid: midEnergy,
        treble: trebleEnergy,
      );
    });
  }

  /// Inicia análisis de archivo de audio
  Future<void> _startFileAnalysis() async {
    if (_currentAudioFile == null) {
      onError?.call('No hay archivo de audio seleccionado');
      return;
    }

    // NOTA: Para análisis real de archivo usarías:
    // - just_audio para reproducción + análisis FFT
    // - ffmpeg.dart para decodificar y analizar
    // - O un paquete como audio_waveforms
    
    lvsLog('Análisis de archivo: $_currentAudioFile', tag: 'AUDIO_REACTIVE');
    _simulateFileAnalysis();
  }

  void _simulateFileAnalysis() {
    _analysisTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!_isActive || _currentAudioFile == null) {
        _analysisTimer?.cancel();
        return;
      }

      // Simular progreso de archivo
      _filePosition += 0.1;
      if (_filePosition >= 1.0) {
        _filePosition = 0.0; // Loop
      }

      final progress = _filePosition;
      final rms = 0.3 + 0.4 * math.sin(progress * 2 * math.pi * 3);
      final bass = 0.4 + 0.3 * math.sin(progress * 2 * math.pi * 5);
      
      _processAudioFrame(
        rms: rms.clamp(0.0, 1.0),
        bass: bass.clamp(0.0, 1.0),
        mid: (0.3 + 0.2 * math.sin(progress * 2 * math.pi * 2)).clamp(0.0, 1.0),
        treble: (0.2 + 0.3 * math.sin(progress * 2 * math.pi * 4)).clamp(0.0, 1.0),
      );
    });
  }

  /// Inicia análisis de stream
  Future<void> _startStreamAnalysis() async {
    onError?.call('Stream analysis no implementado aún');
  }

  /// Procesa un frame de audio y actualiza análisis
  void _processAudioFrame({
    required double rms,
    required double bass,
    required double mid,
    required double treble,
  }) {
    // Calcular espectro simulado (en producción: FFT real)
    final spectrum = _generateSpectrum(rms, bass, mid, treble);
    
    // Calcular métricas
    final peak = rms * 1.2;
    final centroid = _calculateCentroid(spectrum);
    final flux = _calculateFlux(spectrum);

    final analysis = AudioAnalysisData(
      rms: rms.clamp(0.0, 1.0),
      peak: peak.clamp(0.0, 1.0),
      bassEnergy: bass.clamp(0.0, 1.0),
      midEnergy: mid.clamp(0.0, 1.0),
      trebleEnergy: treble.clamp(0.0, 1.0),
      spectrum: spectrum,
      centroid: centroid,
      flux: flux,
      timestamp: DateTime.now(),
    );

    _lastAnalysis = analysis;
    _applySmoothing(analysis);
    onAnalysisUpdate?.call(_smoothedAnalysis!);
  }

  /// Aplica suavizado temporal
  void _applySmoothing(AudioAnalysisData current) {
    if (_smoothedAnalysis == null) {
      _smoothedAnalysis = current;
      return;
    }

    final s = config.smoothing.clamp(0.0, 1.0);
    _smoothedAnalysis = AudioAnalysisData(
      rms: _lerp(_smoothedAnalysis!.rms, current.rms, s),
      peak: _lerp(_smoothedAnalysis!.peak, current.peak, s),
      bassEnergy: _lerp(_smoothedAnalysis!.bassEnergy, current.bassEnergy, s),
      midEnergy: _lerp(_smoothedAnalysis!.midEnergy, current.midEnergy, s),
      trebleEnergy: _lerp(_smoothedAnalysis!.trebleEnergy, current.trebleEnergy, s),
      spectrum: _lerpList(_smoothedAnalysis!.spectrum, current.spectrum, s),
      centroid: _lerp(_smoothedAnalysis!.centroid, current.centroid, s),
      flux: _lerp(_smoothedAnalysis!.flux, current.flux, s),
      timestamp: current.timestamp,
    );
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  List<double> _lerpList(List<double> a, List<double> b, double t) {
    return List.generate(a.length, (i) => _lerp(a[i], b[i], t));
  }

  /// Genera espectro simulado basado en energías
  List<double> _generateSpectrum(double rms, double bass, double mid, double treble) {
    const size = 64; // 64 bins
    final spectrum = List<double>.filled(size, 0.0);
    
    // Distribuir energías en bins
    // Bass: bins 0-15 (~0-250Hz)
    for (int i = 0; i < 16; i++) {
      spectrum[i] = bass * (1.0 - i / 16.0) * 0.8 + rms * 0.2;
    }
    // Mid: bins 16-39 (~250-2000Hz)
    for (int i = 16; i < 40; i++) {
      spectrum[i] = mid * (1.0 - (i - 16) / 24.0) * 0.8 + rms * 0.2;
    }
    // Treble: bins 40-63 (~2000-8000Hz)
    for (int i = 40; i < 64; i++) {
      spectrum[i] = treble * (1.0 - (i - 40) / 24.0) * 0.7 + rms * 0.3;
    }
    
    // Normalizar
    final maxVal = spectrum.reduce(math.max);
    if (maxVal > 0) {
      for (int i = 0; i < size; i++) {
        spectrum[i] = (spectrum[i] / maxVal).clamp(0.0, 1.0);
      }
    }
    
    return spectrum;
  }

  double _calculateCentroid(List<double> spectrum) {
    double weightedSum = 0;
    double magnitudeSum = 0;
    for (int i = 0; i < spectrum.length; i++) {
      weightedSum += i * spectrum[i];
      magnitudeSum += spectrum[i];
    }
    return magnitudeSum > 0 ? weightedSum / magnitudeSum : 0;
  }

  double _calculateFlux(List<double> spectrum) {
    if (_lastSpectrum == null) {
      _lastSpectrum = spectrum;
      return 0;
    }
    double sum = 0;
    for (int i = 0; i < spectrum.length; i++) {
      sum += math.pow(spectrum[i] - _lastSpectrum![i], 2);
    }
    _lastSpectrum = spectrum;
    return math.sqrt(sum / spectrum.length);
  }

  List<double>? _lastSpectrum;
  Duration _fileDuration = Duration.zero;

  /// Envía actualización BLE basada en análisis
  void _sendBleUpdate() {
    if (!_isActive || _smoothedAnalysis == null) return;
    
    try {
      final (ch1, ch2) = _smoothedAnalysis!.getBleDualIntensity(config);
      
      // Enviar comando dual motor
      final cmd = LvsCommands.dualMotor(ch1, ch2);
      
      _bleService.writeCommand(cmd, label: 'AUDIO_REACTIVE', silent: true);
    } catch (e) {
      // Silenciar errores de BLE en modo reactivo
    }
  }

  /// Selecciona archivo de audio para análisis
  Future<void> selectAudioFile(String path) async {
    _currentAudioFile = path;
    _filePosition = 0.0;
    
    // Obtener duración (simulado)
    _fileDuration = const Duration(minutes: 3);
    lvsLog('Archivo de audio seleccionado: $path', tag: 'AUDIO_REACTIVE');
  }

  /// Actualiza configuración en caliente
  void updateConfig(AudioReactiveConfig newConfig) {
    // config es final, así que creamos nueva instancia si es necesario
    // En producción usarías un StateNotifier o similar
  }

  /// Detiene análisis
  void stop() {
    _isActive = false;
    _isProcessing = false;
    _analysisTimer?.cancel();
    _bleUpdateTimer?.cancel();
    _audioSubscription?.cancel();
    onStateChange?.call(false);
    lvsLog('AudioReactiveService detenido', tag: 'AUDIO_REACTIVE');
  }

  void dispose() {
    stop();
  }
}

/// Provider para Riverpod
final audioReactiveServiceProvider = Provider<AudioReactiveService>((ref) {
  final ble = ref.read(bleProvider);
  return AudioReactiveService(const AudioReactiveConfig(), ble);
});