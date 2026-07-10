/// Protocolo IPAO - Comandos BLE con header 0xAA
///
/// Basado en el APK descompilado de LoveSpouse (BleIpaoUtils.java).
/// Formato: [0xAA, cmd_type, param1, param2]
/// Tipos: 1=vibración, 5=calor, 9=succión
///
/// Los comandos se mapean desde caracteres ASCII:
///   '0'=stop, '1'..'9'=niveles 1-9, '@'=heating stop, 'P'=suction stop
library;

/// Construye comandos IPAO para el protocolo LoveSpouse.
class IpaoProtocol {
  static const int _header = 0xAA;

  // Tipos de comando
  static const int _cmdVibration = 0x01;
  static const int _cmdHeating = 0x05;
  static const int _cmdSuction = 0x09;

  // Intensidades por nivel
  static const int _intensityStop = 0;
  static const int _intensityLevel1 = 60;
  static const int _intensityLevel2 = 80;
  static const int _intensityLevel3Plus = 100;

  // Comandos base (raw bytes)
  static const List<int> _vibrationStop = [0xAA, 1, 0, 0];
  static const List<int> _heatingStop = [0xAA, 5, 0, 0];
  static const List<int> _suctionStop = [0xAA, 9, 0, 0];

  /// Niveles de intensidad que entiende IPAO (0-9)
  static const int maxLevel = 9;

  /// Mapea un nivel 0-9 a intensidad 0/60/80/100
  static int _intensityForLevel(int level) {
    if (level <= 0) return _intensityStop;
    if (level == 1) return _intensityLevel1;
    if (level == 2) return _intensityLevel2;
    return _intensityLevel3Plus;
  }

  /// Convierte intensidad 0-255 a nivel IPAO 0-9
  static int _levelForIntensity(int intensity) {
    if (intensity <= 0) return 0;
    if (intensity <= 10) return 1;
    if (intensity <= 20) return 2;
    if (intensity <= 30) return 3;
    if (intensity <= 40) return 4;
    if (intensity <= 55) return 5;
    if (intensity <= 70) return 6;
    if (intensity <= 85) return 7;
    if (intensity <= 100) return 8;
    return 9;
  }

  /// Comando de vibración (CH1) para un nivel 0-9
  static List<int> vibrationLevel(int level) {
    final l = level.clamp(0, 9);
    if (l == 0) return List.from(_vibrationStop);
    return [_header, _cmdVibration, l, _intensityForLevel(l)];
  }

  /// Comando de vibración por intensidad 0-255
  static List<int> vibrationIntensity(int intensity) {
    return vibrationLevel(_levelForIntensity(intensity));
  }

  /// Comando de calentamiento (heating) para un nivel 0-9
  static List<int> heatingLevel(int level) {
    final l = level.clamp(0, 9);
    if (l == 0) return List.from(_heatingStop);
    return [_header, _cmdHeating, l, _intensityForLevel(l)];
  }

  /// Comando de calentamiento por intensidad 0-255
  static List<int> heatingIntensity(int intensity) {
    return heatingLevel(_levelForIntensity(intensity));
  }

  /// Comando de succión para un nivel 0-9
  static List<int> suctionLevel(int level) {
    final l = level.clamp(0, 9);
    if (l == 0) return List.from(_suctionStop);
    return [_header, _cmdSuction, l, _intensityForLevel(l)];
  }

  /// Comando de succión por intensidad 0-255
  static List<int> suctionIntensity(int intensity) {
    return suctionLevel(_levelForIntensity(intensity));
  }

  /// Comando dual: envía vibración + succión simultáneamente.
  /// Usado en modo custom cuando b1=1.
  static List<int> dualCommand(int vibLevel, int _) {
    return vibrationLevel(vibLevel.clamp(0, 9));
  }

  /// Comando de parada total (stop all motors)
  static List<int> stopAll() {
    return List.from(_vibrationStop);
  }

  /// Convierte un comando IPAO (0xAA header) a string hex para debug
  static String toHex(List<int> cmd) {
    return cmd.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
  }
}
