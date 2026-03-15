// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/utils/protocol_translator.dart
// Traductor de Protocolo Universal para dispositivos BLE
// ═══════════════════════════════════════════════════════════════

import '../models/toy_model.dart';

/// Resultado de la traducción de protocolo
class ProtocolCommand {
  /// Bytes del comando listos para enviar vía BLE
  final List<int> bytes;

  /// Canal al que va dirigido (1 = Empuje, 2 = Vibración, 0 = Ambos)
  final int channel;

  /// Intensidad traducida (0-255)
  final int intensity;

  /// Tipo de protocolo detectado
  final ProtocolType protocolType;

  /// Descripción del comando
  final String description;

  const ProtocolCommand({
    required this.bytes,
    required this.channel,
    required this.intensity,
    required this.protocolType,
    required this.description,
  });

  /// Verifica si el comando es para canal dual
  bool get isDualChannel => channel == 0;

  /// Verifica si el comando es solo para canal 1
  bool get isChannel1 => channel == 1;

  /// Verifica si el comando es solo para canal 2
  bool get isChannel2 => channel == 2;
}

/// Tipos de protocolo soportados
enum ProtocolType {
  /// Protocolo wbMSE estándar (3 bytes)
  wbMSE,

  /// Protocolo wbMSE con prefijo personalizado
  wbMSECustom,

  /// Protocolo de canal dual (CH1 + CH2)
  wbMSEDual,

  /// Protocolo genérico (single byte)
  generic,

  /// Protocolo preciso (0-255 directo)
  precise,

  /// Protocolo desconocido
  unknown,
}

/// Prefijos de canal para dispositivos Dual Channel
class ChannelPrefix {
  static const int ch1Thrust = 0xD5;  // Canal 1: Empuje
  static const int ch2Vibration = 0xA5;  // Canal 2: Vibración
}

/// Prefijos wbMSE conocidos
class WbMSEPrefix {
  static const String standard = '77 62 4d 53 45';  // "wbMSE" en hex
  static const List<int> standardBytes = [0x77, 0x62, 0x4D, 0x53, 0x45];
  
  // Prefijos de modelos específicos
  static const String model8154 = '77 62 4d 53 45';  // Love Spouse 8154
  static const String model8039 = '77 62 4d 53 45';  // Love Spouse 8039
}

/// Traductor de Protocolo Universal
/// 
/// Convierte comandos de alto nivel (intensidad, patrón) en bytes
/// específicos para cada dispositivo según su metadata del catálogo.
class ProtocolTranslator {
  /// Traduce una intensidad deseada a bytes BLE para un dispositivo específico
  /// 
  /// [toy] - Modelo del dispositivo con metadata del catálogo
  /// [intensity] - Intensidad deseada (0-100 o 0-255)
  /// [channel] - Canal opcional (1 = Empuje, 2 = Vibración, null = Ambos)
  /// 
  /// Retorna [ProtocolCommand] con los bytes listos para enviar
  static ProtocolCommand translate({
    required ToyModel toy,
    required int intensity,
    int? channel,
  }) {
    // Normalizar intensidad a 0-255
    final normalizedIntensity = _normalizeIntensity(intensity, toy.isPrecise);

    // Detectar tipo de protocolo según metadata
    final protocolType = _detectProtocolType(toy);

    // Traducir según el protocolo detectado
    switch (protocolType) {
      case ProtocolType.wbMSE:
        return _translateWbMSE(toy, normalizedIntensity, channel);
      
      case ProtocolType.wbMSECustom:
        return _translateWbMSECustom(toy, normalizedIntensity, channel);
      
      case ProtocolType.wbMSEDual:
        return _translateWbMSEDual(toy, normalizedIntensity, channel);
      
      case ProtocolType.precise:
        return _translatePrecise(toy, normalizedIntensity, channel);
      
      case ProtocolType.generic:
      default:
        return _translateGeneric(toy, normalizedIntensity, channel);
    }
  }

  /// Traduce comando de patrón (1-9) para un dispositivo
  static ProtocolCommand translatePattern({
    required ToyModel toy,
    required int pattern,
    int? channel,
  }) {
    // Los patrones wbMSE usan el mismo formato pero con valores específicos
    return translate(
      toy: toy,
      intensity: pattern,
      channel: channel,
    );
  }

  /// Traduce comando de parada de emergencia
  static ProtocolCommand translateStop({required ToyModel toy}) {
    return translate(
      toy: toy,
      intensity: 0,
      channel: null,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Métodos de Traducción por Protocolo
  // ═══════════════════════════════════════════════════════════════

  /// Protocolo wbMSE Estándar (3 bytes)
  /// Formato: [Prefijo, Intensidad, Checksum]
  static ProtocolCommand _translateWbMSE(
    ToyModel toy,
    int intensity,
    int? channel,
  ) {
    // Obtener prefijo del modelo (primer byte)
    final prefixBytes = _parseHexPrefix(toy.broadcastPrefix);
    final prefix = prefixBytes.isNotEmpty ? prefixBytes.first : 0xE6;

    // Calcular checksum (XOR de prefix e intensity)
    final checksum = prefix ^ intensity;

    // Comando de 3 bytes: [Prefijo, Intensidad, Checksum]
    final bytes = [prefix, intensity, checksum];

    return ProtocolCommand(
      bytes: bytes,
      channel: channel ?? 0,
      intensity: intensity,
      protocolType: ProtocolType.wbMSE,
      description: 'wbMSE Standard: [0x${prefix.toRadixString(16).padLeft(2, '0')}, 0x${intensity.toRadixString(16).padLeft(2, '0')}, 0x${checksum.toRadixString(16).padLeft(2, '0')}]',
    );
  }

  /// Protocolo wbMSE con prefijo personalizado
  static ProtocolCommand _translateWbMSECustom(
    ToyModel toy,
    int intensity,
    int? channel,
  ) {
    final prefixBytes = _parseHexPrefix(toy.broadcastPrefix);
    
    if (prefixBytes.isEmpty) {
      return _translateWbMSE(toy, intensity, channel);
    }

    // Usar todo el prefijo personalizado + intensidad + checksum
    final checksum = _calculateChecksum(prefixBytes, intensity);
    final bytes = [...prefixBytes, intensity, checksum];

    return ProtocolCommand(
      bytes: bytes,
      channel: channel ?? 0,
      intensity: intensity,
      protocolType: ProtocolType.wbMSECustom,
      description: 'wbMSE Custom: ${bytes.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}',
    );
  }

  /// Protocolo wbMSE Dual Channel
  /// Permite enviar comandos independientes a cada canal
  static ProtocolCommand _translateWbMSEDual(
    ToyModel toy,
    int intensity,
    int? channel,
  ) {
    // Si se especifica un canal, enviar solo a ese canal
    if (channel != null && channel != 0) {
      return _translateWbMSEDualChannel(toy, intensity, channel);
    }

    // Si no se especifica canal, enviar a ambos (comando dual)
    // El prefijo base se usa como referencia pero no se envía directamente

    // Comandos separados para cada canal
    final ch1Prefix = ChannelPrefix.ch1Thrust;
    final ch2Prefix = ChannelPrefix.ch2Vibration;

    // Si el dispositivo usa prefijos específicos del catálogo
    final customPrefixes = _parseCustomPrefixes(toy.supportedFuncs);
    final effectiveCh1Prefix = customPrefixes['ch1'] ?? ch1Prefix;
    final effectiveCh2Prefix = customPrefixes['ch2'] ?? ch2Prefix;

    // Calcular checksums
    final ch1Checksum = effectiveCh1Prefix ^ intensity;
    final ch2Checksum = effectiveCh2Prefix ^ intensity;

    // Bytes combinados para dual channel
    final bytes = [
      effectiveCh1Prefix, intensity, ch1Checksum,  // Canal 1
      effectiveCh2Prefix, intensity, ch2Checksum,  // Canal 2
    ];

    return ProtocolCommand(
      bytes: bytes,
      channel: 0,  // Dual channel
      intensity: intensity,
      protocolType: ProtocolType.wbMSEDual,
      description: 'wbMSE Dual: CH1=[0x${effectiveCh1Prefix.toRadixString(16)}, 0x${intensity.toRadixString(16)}, 0x${ch1Checksum.toRadixString(16)}] CH2=[0x${effectiveCh2Prefix.toRadixString(16)}, 0x${intensity.toRadixString(16)}, 0x${ch2Checksum.toRadixString(16)}]',
    );
  }

  /// Traduce para un canal específico en modo Dual Channel
  static ProtocolCommand _translateWbMSEDualChannel(
    ToyModel toy,
    int intensity,
    int channel,
  ) {
    final customPrefixes = _parseCustomPrefixes(toy.supportedFuncs);
    
    // Seleccionar prefijo según canal
    final prefix = channel == 1 
        ? (customPrefixes['ch1'] ?? ChannelPrefix.ch1Thrust)
        : (customPrefixes['ch2'] ?? ChannelPrefix.ch2Vibration);

    final checksum = prefix ^ intensity;
    final bytes = [prefix, intensity, checksum];

    final channelName = channel == 1 ? 'Empuje' : 'Vibración';

    return ProtocolCommand(
      bytes: bytes,
      channel: channel,
      intensity: intensity,
      protocolType: ProtocolType.wbMSE,
      description: 'wbMSE Canal $channel ($channelName): [0x${prefix.toRadixString(16)}, 0x${intensity.toRadixString(16)}, 0x${checksum.toRadixString(16)}]',
    );
  }

  /// Protocolo Preciso (0-255 directo)
  static ProtocolCommand _translatePrecise(
    ToyModel toy,
    int intensity,
    int? channel,
  ) {
    // Dispositivos precisos aceptan intensidad directa
    final bytes = [intensity];

    return ProtocolCommand(
      bytes: bytes,
      channel: channel ?? 0,
      intensity: intensity,
      protocolType: ProtocolType.precise,
      description: 'Precise: 0x${intensity.toRadixString(16).padLeft(2, '0')} ($intensity)',
    );
  }

  /// Protocolo Genérico (single byte)
  static ProtocolCommand _translateGeneric(
    ToyModel toy,
    int intensity,
    int? channel,
  ) {
    // Para dispositivos genéricos, usar byte único
    // Mapear 0-255 a niveles discretos si es necesario
    final genericByte = _mapToGenericLevel(intensity);
    final bytes = [genericByte];

    return ProtocolCommand(
      bytes: bytes,
      channel: channel ?? 0,
      intensity: intensity,
      protocolType: ProtocolType.generic,
      description: 'Generic: 0x${genericByte.toRadixString(16).padLeft(2, '0')} (nivel $genericByte)',
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Métodos Auxiliares
  // ═══════════════════════════════════════════════════════════════

  /// Detecta el tipo de protocolo según la metadata del dispositivo
  static ProtocolType _detectProtocolType(ToyModel toy) {
    final prefix = toy.broadcastPrefix.toLowerCase();
    final modelId = toy.id.toLowerCase();
    final motorLogic = toy.motorLogic.toLowerCase();
    final supportedFuncs = toy.supportedFuncs.toLowerCase();

    // Verificar si es dispositivo preciso (0-255)
    if (toy.isPrecise) {
      return ProtocolType.precise;
    }

    // Verificar si es Dual Channel
    if (motorLogic.contains('dual') || motorLogic.contains('doble')) {
      return ProtocolType.wbMSEDual;
    }

    // Verificar prefijos wbMSE conocidos
    if (prefix.contains('wbmse') || 
        prefix.contains('77 62 4d 53 45') ||
        modelId.contains('8154') || 
        modelId.contains('8039')) {
      
      // Verificar si tiene prefijo personalizado
      if (prefix.isNotEmpty && !WbMSEPrefix.standard.contains(prefix)) {
        return ProtocolType.wbMSECustom;
      }
      return ProtocolType.wbMSE;
    }

    // Verificar funciones específicas que indican protocolo especial
    if (supportedFuncs.contains('dual') || 
        supportedFuncs.contains('ch1') || 
        supportedFuncs.contains('ch2')) {
      return ProtocolType.wbMSEDual;
    }

    // Default: wbMSE estándar
    return ProtocolType.wbMSE;
  }

  /// Normaliza la intensidad a 0-255
  static int _normalizeIntensity(int intensity, bool isPrecise) {
    // Si ya está en rango 0-255, retornar como está
    if (intensity >= 0 && intensity <= 255) {
      return intensity;
    }

    // Si está en rango 0-100, escalar a 0-255
    if (intensity >= 0 && intensity <= 100) {
      return ((intensity / 100) * 255).round();
    }

    // Si es mayor a 255, clamp a 255
    if (intensity > 255) {
      return 255;
    }

    // Si es negativo, retornar 0
    return 0;
  }

  /// Mapea intensidad a niveles genéricos (0-9)
  static int _mapToGenericLevel(int intensity) {
    // Mapear 0-255 a 0-9
    return (intensity / 255 * 9).round();
  }

  /// Parsea prefijo hexadecimal de string a lista de bytes
  static List<int> _parseHexPrefix(String hexString) {
    if (hexString.isEmpty) return [];

    // Remover espacios y convertir a mayúsculas
    final clean = hexString.replaceAll(' ', '').toUpperCase();

    // Validar que sea hex válido
    if (!RegExp(r'^[0-9A-F]+$').hasMatch(clean)) {
      return [];
    }

    // Parsear pares de hex
    final bytes = <int>[];
    for (var i = 0; i < clean.length; i += 2) {
      if (i + 1 < clean.length) {
        final hexPair = clean.substring(i, i + 2);
        bytes.add(int.parse(hexPair, radix: 16));
      }
    }

    return bytes;
  }

  /// Parsea prefijos personalizados de supportedFuncs
  static Map<String, int> _parseCustomPrefixes(String supportedFuncs) {
    final prefixes = <String, int>{};

    // Buscar patrones como "CH1:0xD5" o "CH1=0xD5"
    final ch1Regex = RegExp(r'CH1[:=]\s*0x([0-9A-Fa-f]{2})');
    final ch2Regex = RegExp(r'CH2[:=]\s*0x([0-9A-Fa-f]{2})');

    final ch1Match = ch1Regex.firstMatch(supportedFuncs);
    if (ch1Match != null && ch1Match.groupCount >= 1) {
      prefixes['ch1'] = int.parse(ch1Match.group(1)!, radix: 16);
    }

    final ch2Match = ch2Regex.firstMatch(supportedFuncs);
    if (ch2Match != null && ch2Match.groupCount >= 1) {
      prefixes['ch2'] = int.parse(ch2Match.group(2)!, radix: 16);
    }

    return prefixes;
  }

  /// Calcula checksum XOR para un comando
  static int _calculateChecksum(List<int> prefixBytes, int intensity) {
    // XOR de todos los bytes del prefijo con la intensidad
    int checksum = 0;
    for (final byte in prefixBytes) {
      checksum ^= byte;
    }
    checksum ^= intensity;
    return checksum;
  }

  /// Genera comando de parada para cualquier protocolo
  static ProtocolCommand generateStopCommand(ToyModel toy) {
    return translateStop(toy: toy);
  }

  /// Genera comando de emergencia (máxima intensidad por tiempo limitado)
  static ProtocolCommand generateEmergencyCommand(ToyModel toy) {
    return translate(
      toy: toy,
      intensity: 255,
      channel: null,
    );
  }

  /// Genera comando de pulsación (tap)
  static ProtocolCommand generateTapCommand(ToyModel toy, {int intensity = 50}) {
    return translate(
      toy: toy,
      intensity: intensity,
      channel: null,
    );
  }
}

/// Extensión para envío directo vía flutter_blue_plus
extension ProtocolCommandExtension on ProtocolCommand {
  /// Convierte los bytes a Uint8List para flutter_blue_plus
  // ignore: avoid_unused_constructor_parameters
  // Uint8List toWriteCharacteristic() {
  //   return Uint8List.fromList(bytes);
  // }

  /// Verifica si el comando es válido
  bool get isValid => bytes.isNotEmpty && intensity >= 0;

  /// Obtiene el primer byte (prefijo/comando)
  int get commandByte => bytes.isNotEmpty ? bytes.first : 0;

  /// Obtiene el último byte (checksum o dato)
  int get lastByte => bytes.isNotEmpty ? bytes.last : 0;
}
