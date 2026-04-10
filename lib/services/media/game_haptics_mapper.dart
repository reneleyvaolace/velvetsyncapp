// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/game_haptics_mapper.dart
// Mapeador de Señales Hápticas de Juegos a Juguetes
// 
// Inspirado en Intiface Game Haptics Router (GHR)
// Mapea valores de rumble de gamepads (0-65535) a intensidad
// de juguetes (0-100%) para control háptico en videojuegos.
//
// Referencia: https://github.com/intiface/intiface-game-haptics-router
// ═══════════════════════════════════════════════════════════════

import 'dart:math' as math;

// ═══════════════════════════════════════════════════════════════
// Modelos de Datos
// ═══════════════════════════════════════════════════════════════

/// Entrada háptica de juego (valores de rumble de gamepad)
class HapticsInput {
  /// Motor izquierdo/large (0-65535 en XInput)
  final int leftMotor;

  /// Motor derecho/small (0-65535 en XInput)
  final int rightMotor;

  /// Timestamp de la entrada
  final DateTime timestamp;

  const HapticsInput({
    required this.leftMotor,
    required this.rightMotor,
    required this.timestamp,
  });

  /// Valor normalizado del motor izquierdo (0.0-1.0)
  double get leftNormalized => leftMotor / 65535;

  /// Valor normalizado del motor derecho (0.0-1.0)
  double get rightNormalized => rightMotor / 65535;

  /// Intensidad promedio (0.0-1.0)
  double get averageIntensity => (leftNormalized + rightNormalized) / 2;

  /// Intensidad máxima (0.0-1.0)
  double get maxIntensity => math.max(leftNormalized, rightNormalized);

  /// Crear desde valores XInput
  factory HapticsInput.fromXInput({
    required int leftMotor,
    required int rightMotor,
  }) {
    return HapticsInput(
      leftMotor: leftMotor.clamp(0, 65535),
      rightMotor: rightMotor.clamp(0, 65535),
      timestamp: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'HapticsInput(left: ${(leftNormalized * 100).round()}%, right: ${(rightNormalized * 100).round()}%)';
  }
}

/// Salida háptica para juguete (intensidad por canal)
class HapticsOutput {
  /// Canal 1: Empuje/Thrust (0.0-1.0)
  final double channel1;

  /// Canal 2: Vibración/Vibrate (0.0-1.0)
  final double channel2;

  /// Canal 3: Rotación/Rotate (0.0-1.0, opcional)
  final double? channel3;

  /// Canal 4: Succión/Suction (0.0-1.0, opcional)
  final double? channel4;

  const HapticsOutput({
    required this.channel1,
    required this.channel2,
    this.channel3,
    this.channel4,
  });

  /// ¿Es salida dual channel?
  bool get isDualChannel => channel3 == null && channel4 == null;

  /// ¿Es salida multi channel?
  bool get isMultiChannel => channel3 != null || channel4 != null;

  @override
  String toString() {
    return 'HapticsOutput(ch1: ${(channel1 * 100).round()}%, ch2: ${(channel2 * 100).round()}%)';
  }
}

// ═══════════════════════════════════════════════════════════════
// Curvas de Respuesta
// ═══════════════════════════════════════════════════════════════

/// Tipo de curva de respuesta para mapeo
enum ResponseCurve {
  /// Lineal: 1:1 mapping, sin modificación
  linear,

  /// Exponencial: Más sensible a bajos valores
  exponential,

  /// Logarítmica: Más sensible a altos valores
  logarithmic,

  /// S-curve: Sensibilidad balanceada
  sCurve,

  /// Personalizada: Definida por usuario
  custom,
}

/// Curva de respuesta configurable
class ResponseCurveConfig {
  final ResponseCurve type;
  final double exponent;  // Para exponential/logarithmic
  final List<double> customPoints;  // Para custom curve

  const ResponseCurveConfig({
    this.type = ResponseCurve.linear,
    this.exponent = 0.8,
    this.customPoints = const [],
  });

  /// Aplicar curva a valor normalizado
  double apply(double value) {
    switch (type) {
      case ResponseCurve.linear:
        return value;

      case ResponseCurve.exponential:
        return math.pow(value, exponent).toDouble();

      case ResponseCurve.logarithmic:
        if (value <= 0) return 0;
        return math.log(1 + value * 9) / math.log(10);

      case ResponseCurve.sCurve:
        // Suavizar con función sigmoide modificada
        return 1 / (1 + math.exp(-12 * (value - 0.5)));

      case ResponseCurve.custom:
        if (customPoints.isEmpty) return value;
        return _applyCustomCurve(value);
    }
  }

  /// Aplicar curva personalizada (interpolación lineal)
  double _applyCustomCurve(double value) {
    if (customPoints.length < 2) return value;

    // Encontrar segmento
    final x = value * (customPoints.length - 1);
    final i = x.floor();
    final frac = x - i;

    if (i >= customPoints.length - 1) {
      return customPoints.last;
    }

    // Interpolar
    return customPoints[i] + (customPoints[i + 1] - customPoints[i]) * frac;
  }

  /// Curva predefinida para juegos de acción
  static const ResponseCurveConfig action = ResponseCurveConfig(
    type: ResponseCurve.exponential,
    exponent: 0.7,
  );

  /// Curva predefinida para juegos de carreras
  static const ResponseCurveConfig racing = ResponseCurveConfig(
    type: ResponseCurve.logarithmic,
    exponent: 1.0,
  );

  /// Curva predefinida para juegos de ritmo
  static const ResponseCurveConfig rhythm = ResponseCurveConfig(
    type: ResponseCurve.sCurve,
  );
}

// ═══════════════════════════════════════════════════════════════
// Game Haptics Mapper
// ═══════════════════════════════════════════════════════════════

/// Mapeador de señales hápticas de juegos a juguetes
///
/// Convierte valores de rumble de gamepads (XInput: 0-65535)
/// a intensidades de juguetes (0.0-1.0) para control háptico.
///
/// Inspirado en Intiface Game Haptics Router (GHR)
class GameHapticsMapper {
  /// Curva de respuesta actual
  ResponseCurveConfig curveConfig;

  /// Sensibilidad del motor izquierdo (0.0-2.0)
  double _leftSensitivity;

  /// Sensibilidad del motor derecho (0.0-2.0)
  double _rightSensitivity;

  /// ¿Invertir motores?
  bool invertMotors;

  /// Zona muerta mínima (0.0-0.5)
  double _deadZone;

  /// Intensidad máxima (0.0-1.0)
  double _maxIntensity;

  GameHapticsMapper({
    this.curveConfig = const ResponseCurveConfig(),
    double leftSensitivity = 1.0,
    double rightSensitivity = 1.0,
    this.invertMotors = false,
    double deadZone = 0.05,
    double maxIntensity = 1.0,
  })  : _leftSensitivity = leftSensitivity.clamp(0.0, 2.0),
        _rightSensitivity = rightSensitivity.clamp(0.0, 2.0),
        _deadZone = deadZone.clamp(0.0, 0.5),
        _maxIntensity = maxIntensity.clamp(0.0, 1.0);

  // ═══════════════════════════════════════════════════════════════
  // Getters y Setters
  // ═══════════════════════════════════════════════════════════════

  double get leftSensitivity => _leftSensitivity;
  set leftSensitivity(double value) =>
      _leftSensitivity = value.clamp(0.0, 2.0);

  double get rightSensitivity => _rightSensitivity;
  set rightSensitivity(double value) =>
      _rightSensitivity = value.clamp(0.0, 2.0);

  double get deadZone => _deadZone;
  set deadZone(double value) => _deadZone = value.clamp(0.0, 0.5);

  double get maxIntensity => _maxIntensity;
  set maxIntensity(double value) => _maxIntensity = value.clamp(0.0, 1.0);

  // ═══════════════════════════════════════════════════════════════
  // Métodos de Mapeo
  // ═══════════════════════════════════════════════════════════════

  /// Mapea valor de rumble a intensidad de juguete
  ///
  /// [rumbleValue] - Valor de rumble (0-65535 en XInput)
  /// [sensitivity] - Sensibilidad adicional (0.0-2.0)
  double mapRumbleToIntensity(int rumbleValue, {double? sensitivity}) {
    // Normalizar a 0.0-1.0
    var normalized = rumbleValue / 65535;

    // Aplicar zona muerta
    if (normalized < _deadZone) {
      return 0.0;
    }

    // Remover zona muerta del rango
    normalized = (normalized - _deadZone) / (1.0 - _deadZone);

    // Aplicar sensibilidad
    final sens = sensitivity ?? 1.0;
    normalized = (normalized * sens).clamp(0.0, 1.0);

    // Aplicar curva de respuesta
    normalized = curveConfig.apply(normalized);

    // Aplicar intensidad máxima
    return (normalized * _maxIntensity).clamp(0.0, 1.0);
  }

  /// Mapea motores duales a salida dual channel
  ///
  /// [leftMotor] - Motor izquierdo (0-65535)
  /// [rightMotor] - Motor derecho (0-65535)
  HapticsOutput mapDualMotors(int leftMotor, int rightMotor) {
    final left = invertMotors ? rightMotor : leftMotor;
    final right = invertMotors ? leftMotor : rightMotor;

    return HapticsOutput(
      channel1: mapRumbleToIntensity(left, sensitivity: _leftSensitivity),
      channel2: mapRumbleToIntensity(right, sensitivity: _rightSensitivity),
    );
  }

  /// Mapea entrada háptica a salida de juguete
  ///
  /// [input] - Entrada háptica del juego
  HapticsOutput mapHapticsInput(HapticsInput input) {
    return mapDualMotors(input.leftMotor, input.rightMotor);
  }

  /// Mapea a salida multi-channel (4 motores virtuales)
  ///
  /// [leftMotor] - Motor izquierdo (0-65535)
  /// [rightMotor] - Motor derecho (0-65535)
  HapticsOutput mapMultiChannel(int leftMotor, int rightMotor) {
    final left = mapRumbleToIntensity(leftMotor, sensitivity: _leftSensitivity);
    final right = mapRumbleToIntensity(rightMotor, sensitivity: _rightSensitivity);

    // Distribuir a 4 canales
    return HapticsOutput(
      channel1: left * 0.7,   // Empuje (70% del izquierdo)
      channel2: right,         // Vibración (100% del derecho)
      channel3: left * 0.3,   // Rotación (30% del izquierdo)
      channel4: right * 0.5,  // Succión (50% del derecho)
    );
  }

  /// Mapeo promedio (ambos motores a un solo canal)
  ///
  /// [leftMotor] - Motor izquierdo (0-65535)
  /// [rightMotor] - Motor derecho (0-65535)
  double mapAverage(int leftMotor, int rightMotor) {
    final left = mapRumbleToIntensity(leftMotor);
    final right = mapRumbleToIntensity(rightMotor);
    return (left + right) / 2;
  }

  /// Mapeo máximo (el motor más fuerte domina)
  ///
  /// [leftMotor] - Motor izquierdo (0-65535)
  /// [rightMotor] - Motor derecho (0-65535)
  double mapMax(int leftMotor, int rightMotor) {
    final left = mapRumbleToIntensity(leftMotor);
    final right = mapRumbleToIntensity(rightMotor);
    return math.max(left, right);
  }

  // ═══════════════════════════════════════════════════════════════
  // Métodos de Utilidad
  // ═══════════════════════════════════════════════════════════════

  /// Resetear configuración a valores por defecto
  void resetToDefaults() {
    curveConfig = const ResponseCurveConfig();
    _leftSensitivity = 1.0;
    _rightSensitivity = 1.0;
    invertMotors = false;
    _deadZone = 0.05;
    _maxIntensity = 1.0;
  }

  /// Obtener configuración actual como mapa
  Map<String, dynamic> toJson() {
    return {
      'curveType': curveConfig.type.name,
      'exponent': curveConfig.exponent,
      'leftSensitivity': _leftSensitivity,
      'rightSensitivity': _rightSensitivity,
      'invertMotors': invertMotors,
      'deadZone': _deadZone,
      'maxIntensity': _maxIntensity,
    };
  }

  /// Cargar configuración desde mapa
  void fromJson(Map<String, dynamic> json) {
    curveConfig = ResponseCurveConfig(
      type: ResponseCurve.values.firstWhere(
        (e) => e.name == json['curveType'],
        orElse: () => ResponseCurve.linear,
      ),
      exponent: json['exponent'] ?? 0.8,
    );
    _leftSensitivity = (json['leftSensitivity'] ?? 1.0).clamp(0.0, 2.0);
    _rightSensitivity = (json['rightSensitivity'] ?? 1.0).clamp(0.0, 2.0);
    invertMotors = json['invertMotors'] ?? false;
    _deadZone = (json['deadZone'] ?? 0.05).clamp(0.0, 0.5);
    _maxIntensity = (json['maxIntensity'] ?? 1.0).clamp(0.0, 1.0);
  }

  @override
  String toString() {
    return 'GameHapticsMapper(curve: ${curveConfig.type}, '
        'leftSens: ${_leftSensitivity.toStringAsFixed(2)}, '
        'rightSens: ${_rightSensitivity.toStringAsFixed(2)}, '
        'deadZone: ${_deadZone.toStringAsFixed(2)})';
  }
}

// ═══════════════════════════════════════════════════════════════
// Ejemplos de Uso
// ═══════════════════════════════════════════════════════════════

/*
// Ejemplo 1: Mapeo básico
final mapper = GameHapticsMapper();

// Juego envía rumble: left=32768 (50%), right=65535 (100%)
final output = mapper.mapDualMotors(32768, 65535);

// Resultado:
// output.channel1 = 0.5 (50%) → Empuje
// output.channel2 = 1.0 (100%) → Vibración

await toy.thrust(output.channel1);
await toy.vibrate(output.channel2);


// Ejemplo 2: Con curva exponencial (más sensible)
final mapper = GameHapticsMapper(
  curveConfig: ResponseCurveConfig.action,  // Exponencial
  leftSensitivity: 1.5,  // 50% más sensible
  deadZone: 0.1,  // Zona muerta del 10%
);

final output = mapper.mapDualMotors(16384, 32768);
// output.channel1 = ~0.4 (40%)
// output.channel2 = ~0.6 (60%)


// Ejemplo 3: Guardar/cargar configuración
final mapper = GameHapticsMapper();

// Guardar
final config = mapper.toJson();
await prefs.setString('haptics_config', jsonEncode(config));

// Cargar
final loaded = jsonDecode(await prefs.getString('haptics_config'));
mapper.fromJson(loaded);


// Ejemplo 4: Mapeo para juego de carreras
final mapper = GameHapticsMapper(
  curveConfig: ResponseCurveConfig.racing,  // Logarítmica
  invertMotors: true,  // Invertir para este juego
);

// En el game loop del juego
void onRumble(int left, int right) {
  final output = mapper.mapDualMotors(left, right);
  // Enviar a juguete...
}
*/
