// ═══════════════════════════════════════════════════════════════
// LVS Control · lib/ble/lvs_commands.dart · v1.4.0
// Protocolo BLE — comandos, modos de paquete y constructores
//
// Protocolo Love Spouse 8154 (wbMSE):
//   Empresa (Company ID): 0xFFF0
//   Name prefix de advertising: wbMSE (77 62 4D 53 45)
//
//   Modo 11B: [PREFIX 8B: 6D B6 43 CE 97 FE 42 7C] + [CMD 3B]
//   Modo 18B: [FF FF 00] + prefix + [CMD 3B] + [03 03 8F AE]
// ═══════════════════════════════════════════════════════════════

// Modo de construcción del paquete
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
  static const List<int> ch2Stop   = [0xE5, 0x15, 0x7D]; // Antes A5, corregido para 8154
  static const List<int> ch2Low    = [0xE4, 0x9C, 0x6C];
  static const List<int> ch2Med    = [0xE7, 0x07, 0x5E];
  static const List<int> ch2High   = [0xE6, 0x8E, 0x4F];

  // ── Modos Rítmicos ──────────────────────────────────────────
  static const List<int> pat1      = [0xE1, 0x31, 0x3B];
  static const List<int> pat2      = [0xE0, 0xB8, 0x2A]; // Fast pulse
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
      default: return ch2Stop;
    }
  }

  // NUEVO (Preciso 0-255): Motor 1 (CH1 - Empuje - Prefijo 0xD)
  static List<int> preciseChannel1(int intensity) {
    final intensityByte = intensity.clamp(0, 255);
    return [0xD6, 0x0D, intensityByte];
  }

  // NUEVO (Preciso 0-255): Motor 2 (CH2 - Vibración - Prefijo 0xA)
  static List<int> preciseChannel2(int intensity) {
    final intensityByte = intensity.clamp(0, 255);
    // Siguiendo el requerimiento Multimedia para el 8154 (Canal 0xA)
    return [0xA6, 0x8E, intensityByte];
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

  // Motor 2 (CH2 - Vibración)
  static List<int> proportionalChannel2(int intensityLevel) {
    final intensityByte = intensityLevel.clamp(0, 100);
    return [0xE6, 0x8E, intensityByte];
  }

  // ── Construir el paquete completo ────────────────────────────
  static List<int> buildPacket(List<int> cmdBytes, {PacketMode mode = PacketMode.b11}) {
    if (mode == PacketMode.b11) {
      return [...prefix, ...cmdBytes];
    } else {
      return [...header, ...prefix, ...cmdBytes, ...appendix];
    }
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

