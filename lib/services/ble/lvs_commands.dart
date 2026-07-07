// ═══════════════════════════════════════════════════════════════
// LVS Control · lib/ble/lvs_commands.dart · v1.5.0
// Protocolo BLE — comandos, modos de paquete y constructores
//
// Protocolo Love Spouse 8154 (wbMSE):
//   Empresa (Company ID): 0xFFF0
//   Name prefix de advertising: wbMSE (77 62 4D 53 45)
//
//   Modo 11B: [PREFIX 8B: 6D B6 43 CE 97 FE 42 7C] + [CMD 3B]
//   Modo 18B: [FF FF 00] + prefix + [CMD 3B] + [03 03 8F AE]
// ═══════════════════════════════════════════════════════════════

import 'package:velvet_sync/devices/models/toy_model.dart';// Modo de construcción del paquete
enum PacketMode { b11, b18 }

// Niveles de velocidad estándar
enum SpeedLevel { stop, low, medium, high }

// Canales y Modos Rítmicos
enum LvsPattern {
  pat1, pat2, pat3, pat4, pat5, pat6,
  ch1Stop, ch1Low, ch1Med, ch1High,
  ch2Stop, ch2Low, ch2Med, ch2High,
}

class LvsCommands {
  // ── Segmentos del protocolo ──────────────────────────────────
  static const List<int> prefix    = [0x6D, 0xB6, 0x43, 0xCE, 0x97, 0xFE, 0x42, 0x7C];
  static const List<int> header    = [0xFF, 0xFF, 0x00];
  static const List<int> appendix  = [0x03, 0x03, 0x8F, 0xAE];

  // ── Funciones especiales (heating, strike, suction) ────────
  // Prefijos: 0xF1 = heating, 0xF2 = strike, 0xF3 = suction
  // Estos son valores tentativos — descubiertos por RE del APK
  // TODO: confirmar con dispositivo físico
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

  // ── Comandos de velocidad (Classic) ──────────────────────────
  static const List<int> cmdStop   = [0xE5, 0x15, 0x7D];
  static const List<int> cmdLow    = [0xE4, 0x9C, 0x6C];
  static const List<int> cmdMed    = [0xE7, 0x07, 0x5E];
  static const List<int> cmdHigh   = [0xE6, 0x8E, 0x4F];

  // ── Canal 1 ──────────────────────────────────────────────────
  static const List<int> ch1Stop   = [0xD5, 0x96, 0x4C];
  static const List<int> ch1Low    = [0xD4, 0x1F, 0x5D];
  static const List<int> ch1Med    = [0xD7, 0x84, 0x6F];
  static const List<int> ch1High   = [0xD6, 0x0D, 0x7E];

  // ── Canal 2 ──────────────────────────────────────────────────
  // Nota: Para 8154, Canal 2 usa prefijo 0xE (mismo que comando principal)
  // Antes se usaba 0xA5, pero el correcto es 0xE5 para stop
  static const List<int> ch2Stop   = [0xE5, 0x15, 0x7D]; // Antes A5, corregido para 8154
  static const List<int> ch2Low    = [0xE4, 0x9C, 0x6C];
  static const List<int> ch2Med    = [0xE7, 0x07, 0x5E];
  static const List<int> ch2High   = [0xE6, 0x8E, 0x4F];

  // ── Modos Rítmicos ──────────────────────────────────────────
  static const List<int> pat1      = [0xE1, 0x31, 0x3B];
  static const List<int> pat2      = [0xE0, 0xB8, 0x2A];
  static const List<int> pat3      = [0xE3, 0x23, 0x18];
  static const List<int> pat4      = [0xE2, 0xAA, 0x09];
  static const List<int> pat5      = [0xED, 0x5D, 0xF1];
  static const List<int> pat6      = [0xEC, 0xD4, 0xE0];

  // ── Canal 1 - Ritmos (9 Modos) ───────────────────────────────
  static const List<int> ch1Pat1 = [0xD1, 0x31, 0x3B];
  static const List<int> ch1Pat2 = [0xD0, 0xB8, 0x2A];
  static const List<int> ch1Pat3 = [0xD3, 0x23, 0x18];
  static const List<int> ch1Pat4 = [0xD2, 0xAA, 0x09];
  static const List<int> ch1Pat5 = [0xDD, 0x5D, 0xF1];
  static const List<int> ch1Pat6 = [0xDC, 0xD4, 0xE0];
  static const List<int> ch1Pat7 = [0xDF, 0x4B, 0xD2];
  static const List<int> ch1Pat8 = [0xDE, 0xC2, 0xC3];
  static const List<int> ch1Pat9 = [0xD9, 0x19, 0xB5];

  // ── Canal 2 - Ritmos (9 Modos) ───────────────────────────────
  static const List<int> ch2Pat1 = [0xE1, 0x31, 0x3B];
  static const List<int> ch2Pat2 = [0xE0, 0xB8, 0x2A];
  static const List<int> ch2Pat3 = [0xE3, 0x23, 0x18];
  static const List<int> ch2Pat4 = [0xE2, 0xAA, 0x09];
  static const List<int> ch2Pat5 = [0xED, 0x5D, 0xF1];
  static const List<int> ch2Pat6 = [0xEC, 0xD4, 0xE0];
  static const List<int> ch2Pat7 = [0xEF, 0x4B, 0xD2];
  static const List<int> ch2Pat8 = [0xEE, 0xC2, 0xC3];
  static const List<int> ch2Pat9 = [0xE9, 0x19, 0xB5];

  static const int companyId = 0xFFF0;
  static const String serviceUuid  = '0000fff0-0000-1000-8000-00805f9b34fb';

  // ── Handshake y Verificación ──────────────────────────────────
  static const List<int> handshakePing = [0x01, 0x01, 0x01];
  static const List<int> handshakePong = [0x02, 0x02, 0x02];
  static const List<int> handshakeFinal = [0x00, 0x00, 0x00];

  // ── Obtener bytes por nivel ──────────────────────────────────
  static List<int> commandFor(SpeedLevel level) {
    switch (level) {
      case SpeedLevel.stop:   return cmdStop;
      case SpeedLevel.low:    return cmdLow;
      case SpeedLevel.medium: return cmdMed;
      case SpeedLevel.high:   return cmdHigh;
    }
  }

  // ── Obtener bytes por patrón ────────────────────────────────
  static List<int> patternFor(LvsPattern pattern) {
    switch (pattern) {
      case LvsPattern.pat1:     return pat1;
      case LvsPattern.pat2:     return pat2;
      case LvsPattern.pat3:     return pat3;
      case LvsPattern.pat4:     return pat4;
      case LvsPattern.pat5:     return pat5;
      case LvsPattern.pat6:     return pat6;
      case LvsPattern.ch1Stop:  return ch1Stop;
      case LvsPattern.ch1Low:   return ch1Low;
      case LvsPattern.ch1Med:   return ch1Med;
      case LvsPattern.ch1High:  return ch1High;
      case LvsPattern.ch2Stop:  return ch2Stop;
      case LvsPattern.ch2Low:   return ch2Low;
      case LvsPattern.ch2Med:   return ch2Med;
      case LvsPattern.ch2High:  return ch2High;
    }
  }

  static List<int> ch1PatternFor(int p) {
    switch (p) {
      case 1: return ch1Low;
      case 2: return ch1Med;
      case 3: return ch1High;
      case 4: return ch1Pat1;
      case 5: return ch1Pat2;
      case 6: return ch1Pat3;
      case 7: return ch1Pat4;
      case 8: return ch1Pat5;
      case 9: return ch1Pat6;
      case 10: return ch1Pat7;
      case 11: return ch1Pat8;
      case 12: return ch1Pat9;
      default: return ch1Stop;
    }
  }

  static List<int> ch2PatternFor(int p) {
    switch (p) {
      case 1: return cmdLow;
      case 2: return cmdMed;
      case 3: return cmdHigh;
      case 4: return ch2Pat1;
      case 5: return ch2Pat2;
      case 6: return ch2Pat3;
      case 7: return ch2Pat4;
      case 8: return ch2Pat5;
      case 9: return ch2Pat6;
      case 10: return ch2Pat7;
      case 11: return ch2Pat8;
      case 12: return ch2Pat9;
      default: return ch2Stop;
    }
  }

  // NUEVO (Preciso 0-255): Motor 1 (CH1 - Empuje - Prefijo 0xD)
  static List<int> preciseChannel1(int intensity) {
    final intensityByte = intensity.clamp(0, 255);
    return [0xD6, 0x0D, intensityByte];
  }

  // NUEVO (Preciso 0-255): Motor 2 (CH2 - Vibración - Prefijo 0xA)
  // Para 8154: Canal 2 (Vibración) usa prefijo 0xA según protocolo Multimedia
  static List<int> preciseChannel2(int intensity) {
    final intensityByte = intensity.clamp(0, 255);
    // Siguiendo el requerimiento Multimedia para el 8154 (Canal 0xA)
    return [0xA6, 0x8E, intensityByte];
  }

  // NUEVO: Comando Dual Sincronizado (Prefijo 0xF6)
  // Permite controlar ambos motores en un solo paquete de 3 bytes.
  // [0xF6, intensidad_m1, intensidad_m2]
  // M1: Empuje (0-255), M2: Vibración (0-255)
  static List<int> dualMotor(int m1, int m2) {
    return [0xF6, m1.clamp(0, 255), m2.clamp(0, 255)];
  }

  // ── Encryption ─────────────────────────────────────────────
  /// Applies XOR encryption to command bytes using [encryptCommand] as key.
  /// If [encryptCommand] is empty, returns bytes unchanged.
  /// The key is parsed as hex and XORed cyclically with the command bytes.
  static List<int> encrypt(List<int> bytes, String encryptCommand) {
    if (encryptCommand.isEmpty) return bytes;
    final key = parseHexCommand(encryptCommand);
    if (key == null || key.isEmpty) return bytes;
    return List.generate(bytes.length, (i) => bytes[i] ^ key[i % key.length]);
  }

  // ── NewCommand hex parser ───────────────────────────────────
  /// Parses a hex string like "F1 01 01" or "F10101" or "0xF1 0x01 0x01"
  /// into a list of int bytes. Returns null if parsing fails.
  static List<int>? parseHexCommand(String hex) {
    if (hex.isEmpty) return null;
    try {
      final cleaned = hex
          .replaceAll('0x', '')
          .replaceAll('0X', '')
          .trim();
      final parts = cleaned.split(RegExp(r'\s+'));
      if (parts.length == 1 && parts[0].isNotEmpty) {
        // Could be concatenated hex "F10101"
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

  /// Returns the BLE command for a ClassicId button.
  /// Uses [btn.newCommand] if available (NewCommand protocol),
  /// otherwise falls back to positional mapping via [channel] and [index].
  static List<int> commandForButton(PatternButton btn, int channel, int index) {
    if (btn.newCommand.isNotEmpty) {
      final parsed = parseHexCommand(btn.newCommand);
      if (parsed != null && parsed.isNotEmpty) return parsed;
    }
    // Fallback to positional mapping
    final p = (index.clamp(0, 8)) + 4;
    return channel == 1 ? ch1PatternFor(p) : ch2PatternFor(p);
  }

  static List<int> commandForButtonStop(PatternButton btn, int channel) {
    if (btn.stopCommand > 0) {
      return [btn.stopCommand];
    }
    return channel == 1 ? ch1Stop : ch2Stop;
  }

  // ── Device-specific patterns (from ClassicId) ─────────────
  /// Maps a device pattern index (within a ClassicId group) to a BLE command.
  /// [channel] 1 (0xDx prefix) or 2 (0xEx prefix), [index] 0-8 (position in group).
  static List<int> devicePatternFor(int channel, int index) {
    final p = (index.clamp(0, 8)) + 4;
    return channel == 1 ? ch1PatternFor(p) : ch2PatternFor(p);
  }

  static List<int> deviceStopFor(int channel) {
    return channel == 1 ? ch1Stop : ch2Stop;
  }

  // ── Generar comando proporcional (0-100) ───────────────────
  static List<int> proportional(int intensityLevel) {
    final intensityByte = intensityLevel.clamp(0, 100);
    return [0xE6, 0x8E, intensityByte];
  }

  // Motor 1 (CH1 - Empuje/Vibración 1)
  static List<int> proportionalChannel1(int intensityLevel) {
    final intensityByte = intensityLevel.clamp(0, 100);
    return [0xD6, 0x0D, intensityByte];
  }

  // Motor 2 (CH2 - Vibración) - Corregido prefijo 0xA para 8154 Multimedia
  static List<int> proportionalChannel2(int intensityLevel) {
    final intensityByte = intensityLevel.clamp(0, 100);
    return [0xA6, 0x8E, intensityByte];
  }

  // ── Construir el paquete completo ────────────────────────────
  static List<int> buildPacket(List<int> cmdBytes, {PacketMode mode = PacketMode.b11, List<int>? prefixBytes}) {
    final p = prefixBytes ?? prefix;
    if (mode == PacketMode.b11) {
      return [...p, ...cmdBytes];
    } else {
      return [...header, ...p, ...cmdBytes, ...appendix];
    }
  }

  /// Parses a hex broadcast prefix string (e.g. "77 62 4d 53 45") to bytes.
  /// Returns the default [prefix] if parsing fails or [prefixStr] is empty.
  static List<int> parseBroadcastPrefix(String prefixStr) {
    if (prefixStr.isEmpty) return prefix;
    final parsed = parseHexCommand(prefixStr);
    return (parsed != null && parsed.isNotEmpty) ? parsed : prefix;
  }

  static List<int> buildDebugPacket(int b0, int b1, int b2, {PacketMode mode = PacketMode.b11}) {
    return buildPacket([b0, b1, b2], mode: mode);
  }

  static String bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
  }

  // ── Presets para el modo debug (b0, b1, b2 conocido) ────────
  static const Map<SpeedLevel, Map<String, int>> debugPresets = {
    SpeedLevel.stop:   {'b0': 0xE5, 'b1': 0x15, 'b2': 0x7D},
    SpeedLevel.low:    {'b0': 0xE4, 'b1': 0x9C, 'b2': 0x6C},
    SpeedLevel.medium: {'b0': 0xE7, 'b1': 0x07, 'b2': 0x5E},
    SpeedLevel.high:   {'b0': 0xE6, 'b1': 0x8E, 'b2': 0x4F},
  };
}
