// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/ble/lovespouse_protocol.dart
// Protocolo BLE LoveSpouse (8154 / wbMSE)
// Basado en ingeniería inversa del APK LoveSpouseRemote v4.2.3
// ═══════════════════════════════════════════════════════════════

import 'package:velvet_sync/services/ble/lvs_commands.dart';

/// UUIDs GATT específicos de LoveSpouse
class LoveSpouseUuids {
  // Servicio principal LoveSpouse (Company ID: 0xFFF0)
  static const String service = '0000fff0-0000-1000-8000-00805f9b34fb';
  
  // Característica de escritura (Classic)
  static const String classicWrite = '0000fff1-0000-1000-8000-00805f9b34fb';
  static const String classicWriteExtended = '0000fff3-0000-1000-8000-00805f9b34fb';
  
  // Advertising Service (para private protocol)
  static const String advService = '0000fff0-0000-1000-8000-00805f9b34fb';
  
  // Prefijo de advertising LoveSpouse: "wbMSE" = 77 62 4D 53 45
  static const List<int> advPrefix = [0x77, 0x62, 0x4D, 0x53, 0x45];
  
  // Company ID LoveSpouse
  static const int companyId = 0xFFF0;
}

/// Comandos específicos LoveSpouse
/// 
/// Estructura de comandos (3 bytes):
/// - Byte 0: Prefijo de canal (0xD=CH1, 0xE/0xA=CH2, 0xF=Funciones especiales)
/// - Byte 1: Sub-comando / intensidad
/// - Byte 2: Checksum / valor de intensidad
class LoveSpouseCommands {
  // ─────────────────────────────────────────────────────────────────
  // HANDSHAKE / VERIFICACIÓN DE HARDWARE
  // ─────────────────────────────────────────────────────────────────
  
  /// Ping de verificación: [0x01, 0x01, 0x01]
  static const List<int> handshakePing = [0x01, 0x01, 0x01];
  
  /// Pong esperado: [0x02, 0x02, 0x02]
  static const List<int> handshakePong = [0x02, 0x02, 0x02];
  
  /// Finalización handshake: [0x00, 0x00, 0x00]
  static const List<int> handshakeFinal = [0x00, 0x00, 0x00];
  
  /// ACK de confirmación (recibido del dispositivo)
  static const int expectedAck = 0x06;

  // ─────────────────────────────────────────────────────────────────
  // COMANDOS DE MOTOR - CANAL 1 (Empuje / Thrust) - Prefijo 0xD
  // ─────────────────────────────────────────────────────────────────
  
  static const List<int> ch1Stop   = [0xD5, 0x96, 0x4C];
  static const List<int> ch1Low    = [0xD4, 0x1F, 0x5D];
  static const List<int> ch1Med    = [0xD7, 0x84, 0x6F];
  static const List<int> ch1High   = [0xD6, 0x0D, 0x7E];
  
  // ─────────────────────────────────────────────────────────────────
  // COMANDOS DE MOTOR - CANAL 2 (Vibración) - Prefijo 0xE / 0xA
  // ─────────────────────────────────────────────────────────────────
  // Para 8154 Multimedia: Canal 2 usa prefijo 0xA (0xA6, 0x8E, intensity)
  // Para otros: prefijo 0xE
  
  static const List<int> ch2Stop   = [0xE5, 0x15, 0x7D];
  static const List<int> ch2Low    = [0xE4, 0x9C, 0x6C];
  static const List<int> ch2Med    = [0xE7, 0x07, 0x5E];
  static const List<int> ch2High   = [0xE6, 0x8E, 0x4F];
  
  // Versión Multimedia (8154) - Prefijo 0xA para Canal 2
  static const List<int> ch2StopMm  = [0xA5, 0x15, 0x7D];
  static const List<int> ch2LowMm   = [0xA4, 0x9C, 0x6C];
  static const List<int> ch2MedMm   = [0xA7, 0x07, 0x5E];
  static const List<int> ch2HighMm  = [0xA6, 0x8E, 0x4F];

  // ─────────────────────────────────────────────────────────────────
  // PATRONES RÍTMICOS - CANAL 1 (Prefijo 0xD)
  // ─────────────────────────────────────────────────────────────────
  static const List<int> ch1Pat1 = [0xD1, 0x31, 0x3B];
  static const List<int> ch1Pat2 = [0xD0, 0xB8, 0x2A];
  static const List<int> ch1Pat3 = [0xD3, 0x23, 0x18];
  static const List<int> ch1Pat4 = [0xD2, 0xAA, 0x09];
  static const List<int> ch1Pat5 = [0xDD, 0x5D, 0xF1];
  static const List<int> ch1Pat6 = [0xDC, 0xD4, 0xE0];
  static const List<int> ch1Pat7 = [0xDF, 0x4B, 0xD2];
  static const List<int> ch1Pat8 = [0xDE, 0xC2, 0xC3];
  static const List<int> ch1Pat9 = [0xD9, 0x19, 0xB5];

  // ─────────────────────────────────────────────────────────────────
  // PATRONES RÍTMICOS - CANAL 2 (Prefijo 0xE / 0xA)
  // ─────────────────────────────────────────────────────────────────
  static const List<int> ch2Pat1 = [0xE1, 0x31, 0x3B];
  static const List<int> ch2Pat2 = [0xE0, 0xB8, 0x2A];
  static const List<int> ch2Pat3 = [0xE3, 0x23, 0x18];
  static const List<int> ch2Pat4 = [0xE2, 0xAA, 0x09];
  static const List<int> ch2Pat5 = [0xED, 0x5D, 0xF1];
  static const List<int> ch2Pat6 = [0xEC, 0xD4, 0xE0];
  static const List<int> ch2Pat7 = [0xEF, 0x4B, 0xD2];
  static const List<int> ch2Pat8 = [0xEE, 0xC2, 0xC3];
  static const List<int> ch2Pat9 = [0xE9, 0x19, 0xB5];

  // Versión Multimedia (8154)
  static const List<int> ch2Pat1Mm = [0xA1, 0x31, 0x3B];
  static const List<int> ch2Pat2Mm = [0xA0, 0xB8, 0x2A];
  static const List<int> ch2Pat3Mm = [0xA3, 0x23, 0x18];
  static const List<int> ch2Pat4Mm = [0xA2, 0xAA, 0x09];
  static const List<int> ch2Pat5Mm = [0xAD, 0x5D, 0xF1];
  static const List<int> ch2Pat6Mm = [0xAC, 0xD4, 0xE0];
  static const List<int> ch2Pat7Mm = [0xAF, 0x4B, 0xD2];
  static const List<int> ch2Pat8Mm = [0xAE, 0xC2, 0xC3];
  static const List<int> ch2Pat9Mm = [0xA9, 0x19, 0xB5];

  // ─────────────────────────────────────────────────────────────────
  // COMANDOS GENERALES (Velocidad)
  // ─────────────────────────────────────────────────────────────────
  static const List<int> cmdStop   = [0xE5, 0x15, 0x7D];
  static const List<int> cmdLow    = [0xE4, 0x9C, 0x6C];
  static const List<int> cmdMed    = [0xE7, 0x07, 0x5E];
  static const List<int> cmdHigh   = [0xE6, 0x8E, 0x4F];

  // ─────────────────────────────────────────────────────────────────
  // FUNCIONES ESPECIALES (Descubiertas por RE del APK)
  // ─────────────────────────────────────────────────────────────────
  // Prefijos: 0xF1 = Heating, 0xF2 = Strike, 0xF3 = Suction
  
  static const List<int> heatingOn    = [0xF1, 0x01, 0x01];
  static const List<int> heatingOff   = [0xF1, 0x00, 0x00];
  static const List<int> strikeOn     = [0xF2, 0x01, 0x01];
  static const List<int> strikeOff    = [0xF2, 0x00, 0x00];
  static const List<int> suctionOn    = [0xF3, 0x01, 0x01];
  static const List<int> suctionOff   = [0xF3, 0x00, 0x00];

  static List<int> heatingLevel(int level) {
    final b = level.clamp(0, 255);
    return [0xF1, b, b ^ 0xF1];
  }

  static List<int> strikePattern(int index) {
    final p = (index.clamp(0, 8)) + 1;
    return [0xF2, p, p ^ 0xF2];
  }

  static List<int> suctionLevel(int level) {
    final b = level.clamp(0, 255);
    return [0xF3, b, b ^ 0xF3];
  }

  // ─────────────────────────────────────────────────────────────────
  // COMANDO DUAL MOTOR (Multimedia Sync) - Prefijo 0xF6
  // ─────────────────────────────────────────────────────────────────
  /// Controla ambos motores en un solo paquete: [0xF6, m1, m2]
  /// m1: Canal 1 (Empuje 0-255), m2: Canal 2 (Vibración 0-255)
  static List<int> dualMotor(int m1, int m2) {
    return [0xF6, m1.clamp(0, 255), m2.clamp(0, 255)];
  }

  // ─────────────────────────────────────────────────────────────────
  // INTENSIDAD PRECISA (0-255)
  // ─────────────────────────────────────────────────────────────────
  
  /// Motor 1 (CH1 - Empuje) - Prefijo 0xD6
  static List<int> preciseChannel1(int intensity) {
    final intensityByte = intensity.clamp(0, 255);
    return [0xD6, 0x0D, intensityByte];
  }

  /// Motor 2 (CH2 - Vibración) - Prefijo 0xA6 para 8154 Multimedia
  static List<int> preciseChannel2(int intensity) {
    final intensityByte = intensity.clamp(0, 255);
    return [0xA6, 0x8E, intensityByte];
  }

  // ─────────────────────────────────────────────────────────────────
  // TELEMETRÍA
  // ─────────────────────────────────────────────────────────────────
  
  /// Telemetría de Batería: 0x8A
  /// Formato respuesta: [0x8A, level(0-100), charging(0/1), checksum]
  static const int telemetryBatteryCmd = 0x8A;

  /// Telemetría de Kegel: 0x8B
  /// Formato respuesta: [0x8B, pressure(0-255), reps, checksum]
  static const int telemetryKegelCmd = 0x8B;

  /// Parsea notificación de telemetría entrante
  static Map<String, dynamic>? parseTelemetry(List<int> bytes) {
    if (bytes.isEmpty) return null;

    final cmd = bytes[0];
    switch (cmd) {
      case telemetryBatteryCmd:
        if (bytes.length >= 3) {
          return {
            'type': 'battery',
            'level': bytes[1].clamp(0, 100),
            'charging': bytes.length > 2 ? bytes[2] == 1 : false,
            'raw': bytes,
          };
        }
        break;
      case telemetryKegelCmd:
        if (bytes.length >= 3) {
          return {
            'type': 'kegel',
            'pressure': bytes[1],
            'reps': bytes.length > 2 ? bytes[2] : 0,
            'raw': bytes,
          };
        }
        break;
    }
    return null;
  }
}

/// ═══════════════════════════════════════════════════════════════
/// NEW COMMAND FORMAT (isNewCommand = 1)
/// ═══════════════════════════════════════════════════════════════
/// 
/// El formato NewCommand usa una estructura diferente:
/// - Byte 0: Comando principal (0x10=Motor, 0x20=Función, 0x30=Patrón)
/// - Byte 1: Sub-comando / Canal
/// - Byte 2: Valor / Intensidad
/// - Byte 3: Checksum XOR
class LoveSpouseNewCommands {
  // ─────────────────────────────────────────────────────────────────
  // COMANDOS MOTOR (0x10)
  // ─────────────────────────────────────────────────────────────────
  
  /// Motor individual: [0x10, canal, intensidad, checksum]
  /// canal: 0x01=CH1, 0x02=CH2, 0x03=Dual
  static List<int> motor(int channel, int intensity) {
    final ch = channel.clamp(1, 3);
    final val = intensity.clamp(0, 255);
    final checksum = 0x10 ^ ch ^ val;
    return [0x10, ch, val, checksum];
  }
  
  /// Motor dual: [0x10, 0x03, ch1, ch2, checksum]
  static List<int> dualMotorNew(int ch1, int ch2) {
    final v1 = ch1.clamp(0, 255);
    final v2 = ch2.clamp(0, 255);
    final checksum = 0x10 ^ 0x03 ^ v1 ^ v2;
    return [0x10, 0x03, v1, v2, checksum];
  }
  
  /// Stop todos: [0x10, 0x00, 0x00, 0x10]
  static const List<int> stopAll = [0x10, 0x00, 0x00, 0x10];
  
  // ─────────────────────────────────────────────────────────────────
  // FUNCIONES ESPECIALES (0x20)
  // ─────────────────────────────────────────────────────────────────
  
  /// Heating: [0x20, 0x01, nivel, checksum]
  static List<int> heating(int level) {
    final val = level.clamp(0, 255);
    final checksum = 0x20 ^ 0x01 ^ val;
    return [0x20, 0x01, val, checksum];
  }
  
  /// Strike: [0x20, 0x02, patrón, checksum]
  static List<int> strike(int pattern) {
    final val = (pattern.clamp(0, 8) + 1);
    final checksum = 0x20 ^ 0x02 ^ val;
    return [0x20, 0x02, val, checksum];
  }
  
  /// Suction: [0x20, 0x03, nivel, checksum]
  static List<int> suction(int level) {
    final val = level.clamp(0, 255);
    final checksum = 0x20 ^ 0x03 ^ val;
    return [0x20, 0x03, val, checksum];
  }
  
  // ─────────────────────────────────────────────────────────────────
  // PATRONES (0x30)
  // ─────────────────────────────────────────────────────────────────
  
  /// Patrón canal: [0x30, canal, índice, checksum]
  static List<int> pattern(int channel, int index) {
    final ch = channel.clamp(1, 2);
    final idx = index.clamp(0, 8) + 1;
    final checksum = 0x30 ^ ch ^ idx;
    return [0x30, ch, idx, checksum];
  }
  
  // ─────────────────────────────────────────────────────────────────
  // TELEMETRÍA (0x40)
  // ─────────────────────────────────────────────────────────────────
  
  /// Request battery: [0x40, 0x01, 0x00, 0x41]
  static const List<int> requestBattery = [0x40, 0x01, 0x00, 0x41];
  
  /// Request kegel: [0x40, 0x02, 0x00, 0x42]
  static const List<int> requestKegel = [0x40, 0x02, 0x00, 0x42];
  
  // ─────────────────────────────────────────────────────────────────
  // HANDSHAKE NEW COMMAND
  // ─────────────────────────────────────────────────────────────────
  
  static const List<int> handshakePing = [0x01, 0x01, 0x01, 0x01];
  static const List<int> handshakePong = [0x02, 0x02, 0x02, 0x02];
  static const List<int> handshakeFinal = [0x00, 0x00, 0x00, 0x00];
  static const int expectedAck = 0x06;
}

/// Convierte comando legacy a NewCommand si el dispositivo lo soporta
List<int> convertToNewCommand(List<int> legacyCmd, {bool isDualChannel = false}) {
  // Si ya es NewCommand (4+ bytes), devolver as-is
  if (legacyCmd.length >= 4) return legacyCmd;
  
  // Legacy: [prefijo, sub, valor] -> NewCommand
  if (legacyCmd.length == 3) {
    final prefix = legacyCmd[0];
    final sub = legacyCmd[1];
    final val = legacyCmd[2];
    
    // Mapear prefijos legacy a NewCommand
    // PRIMERO: Casos específicos de motor preciso (excluidos de patrones)
    switch (prefix) {
      case 0xD6: // CH1 preciso
        return LoveSpouseNewCommands.motor(1, val);
      case 0xA6: // CH2 preciso multimedia
        return LoveSpouseNewCommands.motor(2, val);
      case 0xD: // CH1 legacy
        return LoveSpouseNewCommands.motor(1, val);
      case 0xE: // CH2 legacy
      case 0xA: // CH2 multimedia
        return LoveSpouseNewCommands.motor(2, val);
      case 0xF6: // Dual motor legacy
        return LoveSpouseNewCommands.dualMotorNew(
          prefix == 0xF6 ? sub : 0, 
          prefix == 0xF6 ? val : 0
        );
      case 0xF1: // Heating: legacy [0xF1, level, checksum] -> level en sub (byte 1)
        return LoveSpouseNewCommands.heating(sub);
      case 0xF2: // Strike: legacy [0xF2, pattern, checksum] -> pattern en sub (byte 1), strike() suma 1
        return LoveSpouseNewCommands.strike(sub - 1);
      case 0xF3: // Suction: legacy [0xF3, level, checksum] -> level en sub (byte 1)
        return LoveSpouseNewCommands.suction(sub);
      default:
        // LUEGO: Patrones (rango 0xD1-0xD9, 0xE1-0xE9, 0xA1-0xA9) - excluyendo 0xD6, 0xA6
        if (prefix >= 0xD1 && prefix <= 0xD9 && prefix != 0xD6) {
          return LoveSpouseNewCommands.pattern(1, prefix - 0xD1);
        }
        if (prefix >= 0xE1 && prefix <= 0xE9) {
          return LoveSpouseNewCommands.pattern(2, prefix - 0xE1);
        }
        if (prefix >= 0xA1 && prefix <= 0xA9 && prefix != 0xA6) {
          return LoveSpouseNewCommands.pattern(2, prefix - 0xA1);
        }
        return legacyCmd; // fallback
    }
  }
  return legacyCmd;
}

/// Parser de comandos hex para NewCommand (formato: "F1 01 01" o "F10101")
List<int>? parseLoveSpouseHexCommand(String hex) {
  if (hex.isEmpty) return null;
  try {
    final cleaned = hex
        .replaceAll('0x', '')
        .replaceAll('0X', '')
        .trim();
    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.length == 1 && parts[0].isNotEmpty) {
      if (parts[0].length % 2 == 0 && parts[0].length > 2) {
        return List.generate(
          parts[0].length ~/ 2,
          (i) => int.parse(parts[0].substring(i * 2, i * 2 + 2), radix: 16),
        );
      }
    }
    return parts
        .where((p) => p.isNotEmpty)
        .map((p) => int.parse(p, radix: 16))
        .toList();
  } catch (_) {
    return null;
  }
}

/// Encriptación XOR para comandos LoveSpouse (si usa encryptCommand)
List<int> encryptLoveSpouseCommand(List<int> bytes, String encryptCommand) {
  if (encryptCommand.isEmpty) return bytes;
  final key = parseLoveSpouseHexCommand(encryptCommand);
  if (key == null || key.isEmpty) return bytes;
  return List.generate(bytes.length, (i) => bytes[i] ^ key[i % key.length]);
}

/// Detecta si un dispositivo es LoveSpouse por nombre BLE
bool isLoveSpouseDevice(String bleName) {
  final name = bleName.toLowerCase();
  return name.contains('wbms') || 
         name.contains('lovespouse') || 
         name.contains('8154') ||
         name.contains('zv') ||
         name.startsWith('ls');
}

/// Obtiene el broadcast prefix estándar LoveSpouse
List<int> getLoveSpouseBroadcastPrefix([String? customPrefix]) {
  if (customPrefix != null && customPrefix.isNotEmpty) {
    return parseLoveSpouseHexCommand(customPrefix) ?? LoveSpouseUuids.advPrefix;
  }
  return LoveSpouseUuids.advPrefix; // 77 62 4D 53 45
}

/// Construye paquete publicitario LoveSpouse (modo advertising)
/// 
/// Para dispositivos que usan protocolo private/advertising:
/// - Service UUID: 0xFFF0
/// - Manufacturer ID: 0xFFF0
/// - Manufacturer Data: [advPrefix] + [command]
List<int> buildLoveSpouseAdvertisingPacket(List<int> command, {List<int>? advPrefix}) {
  final prefix = advPrefix ?? LoveSpouseUuids.advPrefix;
  return [...prefix, ...command];
}

/// Obtiene comando por nivel de velocidad (SpeedLevel)
List<int> getLoveSpouseSpeedCommand(SpeedLevel level, {bool isMultimedia = false}) {
  if (isMultimedia) {
    switch (level) {
      case SpeedLevel.stop: return LoveSpouseCommands.ch2StopMm;
      case SpeedLevel.low:  return LoveSpouseCommands.ch2LowMm;
      case SpeedLevel.medium: return LoveSpouseCommands.ch2MedMm;
      case SpeedLevel.high: return LoveSpouseCommands.ch2HighMm;
    }
  }
  
  switch (level) {
    case SpeedLevel.stop: return LoveSpouseCommands.cmdStop;
    case SpeedLevel.low:  return LoveSpouseCommands.cmdLow;
    case SpeedLevel.medium: return LoveSpouseCommands.cmdMed;
    case SpeedLevel.high: return LoveSpouseCommands.cmdHigh;
  }
}

/// Obtiene comando para Canal 1 (Empuje)
List<int> getLoveSpouseChannel1Command(SpeedLevel level) {
  switch (level) {
    case SpeedLevel.stop: return LoveSpouseCommands.ch1Stop;
    case SpeedLevel.low:  return LoveSpouseCommands.ch1Low;
    case SpeedLevel.medium: return LoveSpouseCommands.ch1Med;
    case SpeedLevel.high: return LoveSpouseCommands.ch1High;
  }
}

/// Obtiene comando para Canal 2 (Vibración)
List<int> getLoveSpouseChannel2Command(SpeedLevel level, {bool isMultimedia = false}) {
  if (isMultimedia) {
    switch (level) {
      case SpeedLevel.stop: return LoveSpouseCommands.ch2StopMm;
      case SpeedLevel.low:  return LoveSpouseCommands.ch2LowMm;
      case SpeedLevel.medium: return LoveSpouseCommands.ch2MedMm;
      case SpeedLevel.high: return LoveSpouseCommands.ch2HighMm;
    }
  }
  
  switch (level) {
    case SpeedLevel.stop: return LoveSpouseCommands.ch2Stop;
    case SpeedLevel.low:  return LoveSpouseCommands.ch2Low;
    case SpeedLevel.medium: return LoveSpouseCommands.ch2Med;
    case SpeedLevel.high: return LoveSpouseCommands.ch2High;
  }
}

/// Obtiene patrón para Canal 1 (9 patrones)
List<int> getLoveSpouseChannel1Pattern(int patternIndex) {
  const patterns = [
    LoveSpouseCommands.ch1Pat1,
    LoveSpouseCommands.ch1Pat2,
    LoveSpouseCommands.ch1Pat3,
    LoveSpouseCommands.ch1Pat4,
    LoveSpouseCommands.ch1Pat5,
    LoveSpouseCommands.ch1Pat6,
    LoveSpouseCommands.ch1Pat7,
    LoveSpouseCommands.ch1Pat8,
    LoveSpouseCommands.ch1Pat9,
  ];
  
  if (patternIndex < 0 || patternIndex >= patterns.length) {
    return LoveSpouseCommands.ch1Stop;
  }
  return patterns[patternIndex];
}

/// Obtiene patrón para Canal 2 (9 patrones)
List<int> getLoveSpouseChannel2Pattern(int patternIndex, {bool isMultimedia = false}) {
  const patterns = [
    LoveSpouseCommands.ch2Pat1,
    LoveSpouseCommands.ch2Pat2,
    LoveSpouseCommands.ch2Pat3,
    LoveSpouseCommands.ch2Pat4,
    LoveSpouseCommands.ch2Pat5,
    LoveSpouseCommands.ch2Pat6,
    LoveSpouseCommands.ch2Pat7,
    LoveSpouseCommands.ch2Pat8,
    LoveSpouseCommands.ch2Pat9,
  ];
  
  const patternsMm = [
    LoveSpouseCommands.ch2Pat1Mm,
    LoveSpouseCommands.ch2Pat2Mm,
    LoveSpouseCommands.ch2Pat3Mm,
    LoveSpouseCommands.ch2Pat4Mm,
    LoveSpouseCommands.ch2Pat5Mm,
    LoveSpouseCommands.ch2Pat6Mm,
    LoveSpouseCommands.ch2Pat7Mm,
    LoveSpouseCommands.ch2Pat8Mm,
    LoveSpouseCommands.ch2Pat9Mm,
  ];
  
  final list = isMultimedia ? patternsMm : patterns;
  
  if (patternIndex < 0 || patternIndex >= list.length) {
    return isMultimedia ? LoveSpouseCommands.ch2StopMm : LoveSpouseCommands.ch2Stop;
  }
  return list[patternIndex];
}