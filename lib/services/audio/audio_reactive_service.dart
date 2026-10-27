// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/audio/audio_reactive_service.dart
// Audio Reactivo: FFT 7-bandas → Intensidades por banda
// Inspirado en XToys: captura audio sistema + FFT → intensidades
// ════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math' as math;
import 'package:complex/complex.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fft/fft.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:velvet_sync/services/ble/ble_service.dart';
import 'package:velvet_sync/devices/models/toy_model.dart';
import 'package:velvet_sync/utils/logger.dart';

/// Bandas de frecuencia para análisis FFT (7 bandas estándar)
enum FrequencyBand {
  subBass(0, 20, 60),      // Sub-bass: 20-60 Hz
  bass(1, 60, 250),        // Bass: 60-250 Hz
  lowMid(2, 250, 500),     // Low-mid: 250-500 Hz
  mid(3, 500, 2000),       // Mid: 500-2000 Hz
  highMid(4, 2000, 4000),  // High-mid: 2-4 kHz
  presence(5, 4000, 6000), // Presence: 4-6 kHz
  brilliance(6, 6000, 20000); // Brilliance: 6-20 kHz

  const FrequencyBand(this.bandIndex, this.minFreq, this.maxFreq);
  final int bandIndex;
  final int minFreq;
  final int maxFreq;
}

/// Configuración de audio reactivo
class AudioReactiveConfig {
  final bool enabled;
  final double sensitivity;        // 0.0 - 1.0
  final double smoothing;          // 0.0 - 1.0 (suavizado temporal)
  final Map<int, double> bandWeights; // Peso por banda (0-7)
  final int fftSize;               // Tamaño FFT (potencia de 2)
  final int sampleRate;            // Hz
  final bool useSystemAudio;       // true = captura sistema, false = micrófono
  final int deviceId;              // ID de dispositivo para control dual

  const AudioReactiveConfig({
    this.enabled = false,
    this.sensitivity = 0.5,
    this.smoothing = 0.3,
    this.bandWeights = const {
      0: 0.3,  // Sub-bass
      1: 0.8,  // Bass
      2: 0.6,  // Low-mid
      3: 0.5,  // Mid
      4: 0.4,  // High-mid
      5: 0.3,  // Presence
      6: 0.2,  // Brilliance
    },
    this.fftSize = 2048,
    this.sampleRate = 44100,
    this.useSystemAudio = true,
    this.deviceId = 1,
  });

  AudioReactiveConfig copyWith({
    bool? enabled,
    double? sensitivity,
    double? smoothing,
    Map<int, double>? bandWeights,
    int? fftSize,
    int? sampleRate,
    bool? useSystemAudio,
    int? deviceId,
  }) {
    return AudioReactiveConfig(
      enabled: enabled ?? this.enabled,
      sensitivity: sensitivity ?? this.sensitivity,
      smoothing: smoothing ?? this.smoothing,
      bandWeights: bandWeights ?? this.bandWeights,
      fftSize: fftSize ?? this.fftSize,
      sampleRate: sampleRate ?? this.sampleRate,
      useSystemAudio: useSystemAudio ?? this.useSystemAudio,
      deviceId: deviceId ?? this.deviceId,
    );
  }
}

/// Resultado de análisis FFT por banda
class BandAnalysis {
  final int bandIndex;
  final FrequencyBand band;
  final double magnitude;      // 0.0 - 1.0 (normalizado)
  final double intensity;      // 0-255 (para envío BLE)
  final double smoothedMagnitude; // Con suavizado

  const BandAnalysis({
    required this.bandIndex,
    required this.band,
    required this.magnitude,
    required this.intensity,
    required this.smoothedMagnitude,
  });
}

/// Estado del audio reactivo
class AudioReactiveState {
  final bool isActive;
  final bool isListening;
  final List<BandAnalysis> bands;
  final double overallIntensity; // 0-255
  final String? errorMessage;
  final AudioReactiveConfig config;

  const AudioReactiveState({
    this.isActive = false,
    this.isListening = false,
    this.bands = const [],
    this.overallIntensity = 0,
    this.errorMessage,
    required this.config,
  });

  AudioReactiveState copyWith({
    bool? isActive,
    bool? isListening,
    List<BandAnalysis>? bands,
    double? overallIntensity,
    String? errorMessage,
    AudioReactiveConfig? config,
  }) {
    return AudioReactiveState(
      isActive: isActive ?? this.isActive,
      isListening: isListening ?? this.isListening,
      bands: bands ?? this.bands,
      overallIntensity: overallIntensity ?? this.overallIntensity,
      errorMessage: errorMessage ?? this.errorMessage,
      config: config ?? this.config,
    );
  }
}

/// Servicio de Audio Reactivo (FFT 7 bandas → intensidades BLE)
class AudioReactiveService extends ChangeNotifier {
  final BleService _bleService;
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  AudioReactiveState _state = AudioReactiveState(config: AudioReactiveConfig());
  Timer? _analysisTimer;
  Timer? _captureTimer;
  List<double> _previousMagnitudes = List.filled(7, 0.0);
  StreamSubscription? _audioStreamSubscription;

  AudioReactiveService(this._bleService);

  AudioReactiveState get state => _state;
  bool get isActive => _state.isActive;
  List<BandAnalysis> get bands => _state.bands;
  double get overallIntensity => _state.overallIntensity;

  /// Inicializa el servicio
  Future<void> initialize() async {
    try {
      // Solicitar permisos
      if (_state.config.useSystemAudio) {
        // En Android 10+ se usa AudioPlaybackCapture (requiere permiso especial)
        // En iOS no hay captura de audio del sistema nativamente
        await _requestAudioPermissions();
      } else {
        await _requestMicrophonePermission();
      }
      
      lvsLog('✅ AudioReactiveService inicializado', tag: 'AUDIO_REACTIVE');
    } catch (e) {
      _updateState(errorMessage: 'Error inicializando: $e');
      lvsError('Error inicializando AudioReactive: $e', tag: 'AUDIO_REACTIVE');
    }
  }

  Future<void> _requestAudioPermissions() async {
    // En Android 10+ (API 29+), captura de audio del sistema
    // requiere MediaProjection (no permission_handler estándar)
    // Para micrófono:
    await _requestMicrophonePermission();
  }

  Future<void> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      throw Exception('Permiso de micrófono denegado');
    }
  }

  /// Inicia análisis de audio reactivo
  Future<void> start() async {
    if (_state.isActive) return;

    try {
      _updateState(isActive: true, isListening: true, errorMessage: null);
      
      // Configurar fuente de audio
      if (_state.config.useSystemAudio) {
        await _startSystemAudioCapture();
      } else {
        await _startMicrophoneCapture();
      }

      // Timer de análisis FFT periódico
      _analysisTimer = Timer.periodic(
        const Duration(milliseconds: 50), // 20 FPS análisis
        (_) => _analyzeAudio(),
      );

      lvsLog('🎵 Audio reactivo INICIADO', tag: 'AUDIO_REACTIVE');
    } catch (e) {
      _updateState(isActive: false, isListening: false, errorMessage: 'Error: $e');
      lvsError('Error iniciando audio reactivo: $e', tag: 'AUDIO_REACTIVE');
    }
  }

  /// Detiene análisis
  Future<void> stop() async {
    _analysisTimer?.cancel();
    _captureTimer?.cancel();
    await _audioPlayer.stop();
    _audioStreamSubscription?.cancel();

    _updateState(
      isActive: false,
      isListening: false,
      bands: List.filled(7, BandAnalysis(
        bandIndex: 0,
        band: FrequencyBand.values.first,
        magnitude: 0,
        intensity: 0,
        smoothedMagnitude: 0,
      )),
      overallIntensity: 0,
    );

    lvsLog('🔇 Audio reactivo DETENIDO', tag: 'AUDIO_REACTIVE');
  }

  /// Captura audio del sistema (Android 10+ MediaProjection)
  Future<void> _startSystemAudioCapture() async {
    // NOTA: En Flutter no hay API nativa directa para AudioPlaybackCapture
    // Requiere:
    // 1. MediaProjectionManager (Android)
    // 2. AudioRecord con AudioSource.REMOTE_SUBMIX
    // 3. Canal de plataforma (MethodChannel) a código nativo
    
    // Por ahora usamos micrófono como fallback
    lvsLog('⚠️ Captura sistema no implementada nativamente, usando micrófono', tag: 'AUDIO_REACTIVE');
    await _startMicrophoneCapture();
  }

  /// Captura audio del micrófono
  Future<void> _startMicrophoneCapture() async {
    // Usar just_audio para capturar del micrófono
    // Nota: just_audio no expone stream de PCM crudo directamente
    // Alternativa: usar paquete `audio_streamer` o `flutter_sound`
    
    // Placeholder: simular con generador de tonos para testing
    _simulateAudioCapture();
  }

  /// Simula captura de audio para testing (reemplazar con captura real)
  void _simulateAudioCapture() {
    _captureTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      // Generar datos de audio sintéticos para testing
      // En producción: reemplazar con stream real de audio
    });
  }

  /// Análisis FFT principal - llamado cada 50ms
  void _analyzeAudio() {
    if (!_state.isListening) return;

    try {
      // Obtener muestras de audio (PCM 16-bit)
      final samples = _getAudioSamples();
      if (samples.isEmpty) return;

      // Aplicar ventana de Hann
      final windowed = _applyHannWindow(samples);
      
      // FFT
      final complex = FFT.Transform(windowed);
      
      // Calcular magnitudes por banda
      final bands = _calculateBandMagnitudes(complex);
      
      // Suavizado temporal
      final smoothed = _applySmoothing(bands);
      
      // Calcular intensidades 0-255
      final analyses = _calculateIntensities(smoothed);
      
      // Intensidad general
      final overall = analyses.fold<double>(0, (sum, b) => sum + b.intensity) / 7;
      
      _updateState(
        bands: analyses,
        overallIntensity: overall,
        isListening: true,
      );

      // Enviar a BLE si hay dispositivo conectado
      _sendToBLE(analyses);
      
    } catch (e) {
      lvsError('Error en análisis FFT: $e', tag: 'AUDIO_REACTIVE');
    }
  }

  /// Obtiene muestras de audio (placeholder - reemplazar con captura real)
  List<double> _getAudioSamples() {
    // TODO: Implementar captura real de audio
    // Por ahora: generar ruido sintético para testing
    final random = math.Random();
    return List.generate(_state.config.fftSize, (_) => (random.nextDouble() - 0.5) * 0.1);
  }

  /// Ventana de Hann para reducir fugas espectrales
  List<double> _applyHannWindow(List<double> samples) {
    final n = samples.length;
    return List.generate(n, (i) {
      final window = 0.5 * (1 - math.cos(2 * math.pi * i / (n - 1)));
      return samples[i] * window;
    });
  }

  /// Calcula magnitud por banda de frecuencia
  List<double> _calculateBandMagnitudes(List<Complex> fft) {
    final magnitudes = List.filled(7, 0.0);
    final n = fft.length;
    final freqResolution = _state.config.sampleRate / _state.config.fftSize;

    for (int i = 0; i < 7; i++) {
      final band = FrequencyBand.values[i];
      final minBin = (band.minFreq / freqResolution).floor();
      final maxBin = (band.maxFreq / freqResolution).ceil().clamp(0, n ~/ 2);
      
      double sum = 0;
      int count = 0;
      for (int k = minBin; k <= maxBin && k < n ~/ 2; k++) {
        final magnitude = math.sqrt(fft[k].real * fft[k].real + fft[k].imaginary * fft[k].imaginary);
        sum += magnitude;
        count++;
      }
      magnitudes[i] = count > 0 ? sum / count : 0.0;
    }
    return magnitudes;
  }

  /// Suavizado temporal exponencial
  List<double> _applySmoothing(List<double> magnitudes) {
    final alpha = 1.0 - _state.config.smoothing;
    final smoothed = List<double>.generate(7, (i) {
      return _previousMagnitudes[i] * (1 - alpha) + magnitudes[i] * alpha;
    });
    _previousMagnitudes = smoothed;
    return smoothed;
  }

  /// Convierte magnitudes a intensidades 0-255
  List<BandAnalysis> _calculateIntensities(List<double> magnitudes) {
    return List.generate(7, (i) {
      final band = FrequencyBand.values[i];
      final mag = magnitudes[i];
      final weight = _state.config.bandWeights[i] ?? 1.0;
      final sensitivity = _state.config.sensitivity;
      
      // Normalizar y escalar
      final normalized = (mag * weight * sensitivity).clamp(0.0, 1.0);
      final intensity = (normalized * 255).round();
      final smoothed = _previousMagnitudes[i];
      
      return BandAnalysis(
        bandIndex: i,
        band: FrequencyBand.values[i],
        magnitude: normalized,
        intensity: intensity.toDouble(),
        smoothedMagnitude: smoothed,
      );
    });
  }

  /// Envía intensidades a dispositivo BLE
  void _sendToBLE(List<BandAnalysis> analyses) {
    if (!_bleService.isConnected) return;
    
    final deviceId = _state.config.deviceId;
    final ch1Intensity = analyses[1].intensity.round(); // Bass → CH1
    final ch2Intensity = analyses[3].intensity.round(); // Mid → CH2
    
    // Enviar comando dual channel
    unawaited(_bleService.sendMultimediaSync(ch1Intensity, ch2Intensity));
  }

  /// Actualiza configuración
  void updateConfig(AudioReactiveConfig config) {
    _updateState(config: config);
  }

  void _updateState({
    bool? isActive,
    bool? isListening,
    List<BandAnalysis>? bands,
    double? overallIntensity,
    String? errorMessage,
    AudioReactiveConfig? config,
  }) {
    _state = _state.copyWith(
      isActive: isActive,
      isListening: isListening,
      bands: bands,
      overallIntensity: overallIntensity,
      errorMessage: errorMessage,
      config: config,
    );
    notifyListeners();
  }

  /// Limpieza
  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

/// Provider para Riverpod
final audioReactiveServiceProvider = Provider<AudioReactiveService>((ref) {
  final bleService = ref.read(bleProvider);
  return AudioReactiveService(bleService);
});

/// Provider de estado
final audioReactiveStateProvider = StreamProvider<AudioReactiveState>((ref) {
  final service = ref.watch(audioReactiveServiceProvider);
  // Convertir ChangeNotifier a Stream
  final controller = StreamController<AudioReactiveState>.broadcast();
  service.addListener(() => controller.add(service.state));
  return controller.stream;
});
