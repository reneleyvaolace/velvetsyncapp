// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/sensors/sensors_service.dart
// Sensores nativos: inclinación, shake, volumen, gamepad
// ════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:velvet_sync/services/ble/ble_service.dart';
import 'package:velvet_sync/utils/logger.dart';

/// Tipos de sensor
enum SensorType { tilt, shake, volume, gamepad }

/// Configuración de sensores
class SensorsConfig {
  final bool tiltEnabled;
  final bool shakeEnabled;
  final bool volumeButtonsEnabled;
  final bool gamepadEnabled;
  final double tiltSensitivity; // 0.0 - 1.0
  final double shakeThreshold; // aceleración umbral

  const SensorsConfig({
    this.tiltEnabled = true,
    this.shakeEnabled = true,
    this.volumeButtonsEnabled = false,
    this.gamepadEnabled = false,
    this.tiltSensitivity = 0.5,
    this.shakeThreshold = 2.5,
  });

  SensorsConfig copyWith({
    bool? tiltEnabled,
    bool? shakeEnabled,
    bool? volumeButtonsEnabled,
    bool? gamepadEnabled,
    double? tiltSensitivity,
    double? shakeThreshold,
  }) {
    return SensorsConfig(
      tiltEnabled: tiltEnabled ?? this.tiltEnabled,
      shakeEnabled: shakeEnabled ?? this.shakeEnabled,
      volumeButtonsEnabled: volumeButtonsEnabled ?? this.volumeButtonsEnabled,
      gamepadEnabled: gamepadEnabled ?? this.gamepadEnabled,
      tiltSensitivity: tiltSensitivity ?? this.tiltSensitivity,
      shakeThreshold: shakeThreshold ?? this.shakeThreshold,
    );
  }
}

/// Estado de sensores
class SensorsState {
  final bool isActive;
  final double tiltX; // -1.0 a 1.0
  final double tiltY; // -1.0 a 1.0
  final bool shakeDetected;
  final int volumePressCount;
  final String? errorMessage;
  final SensorsConfig config;

  const SensorsState({
    this.isActive = false,
    this.tiltX = 0.0,
    this.tiltY = 0.0,
    this.shakeDetected = false,
    this.volumePressCount = 0,
    this.errorMessage,
    required this.config,
  });

  SensorsState copyWith({
    bool? isActive,
    double? tiltX,
    double? tiltY,
    bool? shakeDetected,
    int? volumePressCount,
    String? errorMessage,
    SensorsConfig? config,
  }) {
    return SensorsState(
      isActive: isActive ?? this.isActive,
      tiltX: tiltX ?? this.tiltX,
      tiltY: tiltY ?? this.tiltY,
      shakeDetected: shakeDetected ?? this.shakeDetected,
      volumePressCount: volumePressCount ?? this.volumePressCount,
      errorMessage: errorMessage ?? this.errorMessage,
      config: config ?? this.config,
    );
  }
}

/// Servicio de Sensores nativos
class SensorsService extends ChangeNotifier {
  final BleService _bleService;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  Timer? _shakeDebounce;

  SensorsState _state = SensorsState(config: const SensorsConfig());

  SensorsState get state => _state;
  bool get isActive => _state.isActive;

  SensorsService(this._bleService);

  Future<void> initialize() async {
    try {
      lvsLog('✅ SensorsService inicializado', tag: 'SENSORS');
    } catch (e) {
      lvsError('Error inicializando Sensors: $e', tag: 'SENSORS');
    }
  }

  Future<void> start() async {
    if (_state.isActive) return;

    try {
      _updateState(isActive: true, errorMessage: null);

      if (_state.config.tiltEnabled || _state.config.shakeEnabled) {
        await _startAccelerometer();
      }

      lvsLog('🎯 Sensores INICIADOS', tag: 'SENSORS');
    } catch (e) {
      _updateState(isActive: false, errorMessage: 'Error: $e');
      lvsError('Error iniciando sensores: $e', tag: 'SENSORS');
    }
  }

  Future<void> stop() async {
    await _accelSub?.cancel();
    await _gyroSub?.cancel();
    _shakeDebounce?.cancel();

    _updateState(
      isActive: false,
      tiltX: 0,
      tiltY: 0,
      shakeDetected: false,
    );

    lvsLog('⏹️ Sensores DETENIDOS', tag: 'SENSORS');
  }

  Future<void> _startAccelerometer() async {
    _accelSub = accelerometerEventStream().listen((AccelerometerEvent event) {
      if (!_state.isActive) return;

      final x = event.x;
      final y = event.y;
      final z = event.z;
      final magnitude = math.sqrt(x * x + y * y + z * z);

      // Shake detection
      if (_state.config.shakeEnabled && magnitude > _state.config.shakeThreshold * 9.8) {
        _shakeDebounce?.cancel();
        _shakeDebounce = Timer(const Duration(milliseconds: 500), () {
          _updateState(shakeDetected: false);
        });
        _updateState(shakeDetected: true);
        lvsLog('📳 SHAKE detectado', tag: 'SENSORS');
        // Enviar comando de parada por shake
        unawaited(_bleService.stopAllMotors());
      }

      // Tilt (inclinación)
      if (_state.config.tiltEnabled) {
        final tiltX = (x / 9.8).clamp(-1.0, 1.0);
        final tiltY = (y / 9.8).clamp(-1.0, 1.0);
        _updateState(tiltX: tiltX, tiltY: tiltY);

        // Mapear tilt a intensidad BLE (0-255)
        final intensity = ((tiltY.abs() * _state.config.tiltSensitivity) * 255).round().clamp(0, 255);
        if (_state.isActive) {
          unawaited(_bleService.sendMultimediaSync(intensity, 0));
        }
      }
    });
  }

  void updateConfig(SensorsConfig config) {
    _updateState(config: config);
  }

  void _updateState({
    bool? isActive,
    double? tiltX,
    double? tiltY,
    bool? shakeDetected,
    int? volumePressCount,
    String? errorMessage,
    SensorsConfig? config,
  }) {
    _state = _state.copyWith(
      isActive: isActive,
      tiltX: tiltX,
      tiltY: tiltY,
      shakeDetected: shakeDetected,
      volumePressCount: volumePressCount,
      errorMessage: errorMessage,
      config: config,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

/// Provider para Riverpod
final sensorsServiceProvider = Provider<SensorsService>((ref) {
  final bleService = ref.read(bleProvider);
  return SensorsService(bleService);
});

/// Provider de estado
final sensorsStateProvider = StreamProvider<SensorsState>((ref) {
  final service = ref.watch(sensorsServiceProvider);
  final controller = StreamController<SensorsState>.broadcast();
  service.addListener(() => controller.add(service.state));
  return controller.stream;
});
