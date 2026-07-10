import 'package:velvet_sync/devices/models/toy_model.dart';
import 'package:velvet_sync/services/ble/ipao_protocol.dart';
import 'package:velvet_sync/services/ble/crypt_ble.dart';
import 'package:velvet_sync/services/ble/ble_protocol.dart';

class ProtocolCommand {
  final List<int> bytes;
  final int channel;
  final int intensity;
  final ProtocolType protocolType;
  final String description;
  final BleProtocolType bleProtocol;

  const ProtocolCommand({
    required this.bytes,
    required this.channel,
    required this.intensity,
    required this.protocolType,
    required this.description,
    this.bleProtocol = BleProtocolType.classic,
  });

  bool get isDualChannel => channel == 0;
  bool get isChannel1 => channel == 1;
  bool get isChannel2 => channel == 2;
}

enum ProtocolType {
  wbMSE,
  wbMSECustom,
  wbMSEDual,
  generic,
  precise,
  ipao,
  cryptBle,
  unknown,
}

class ChannelPrefix {
  static const int ch1Thrust = 0xD5;
  static const int ch2Vibration = 0xA5;
}

class WbMSEPrefix {
  static const String standard = '77 62 4d 53 45';
  static const List<int> standardBytes = [0x77, 0x62, 0x4D, 0x53, 0x45];
  static const String model8154 = '77 62 4d 53 45';
  static const String model8039 = '77 62 4d 53 45';
}

class ProtocolTranslator {
  static ProtocolCommand translate({
    required ToyModel toy,
    required int intensity,
    int? channel,
  }) {
    final normalizedIntensity = _normalizeIntensity(intensity, toy.isPrecise);
    final bleProtocol = detectBleProtocol(toy);

    if (bleProtocol == BleProtocolType.ipao) {
      return _translateIpao(toy, normalizedIntensity, channel);
    }

    if (bleProtocol == BleProtocolType.cryptBle) {
      return _translateCryptBle(toy, normalizedIntensity, channel);
    }

    final protocolType = _detectProtocolType(toy);
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

  static ProtocolCommand translatePattern({
    required ToyModel toy,
    required int pattern,
    int? channel,
  }) {
    return translate(toy: toy, intensity: pattern, channel: channel);
  }

  static ProtocolCommand translateStop({required ToyModel toy}) {
    return translate(toy: toy, intensity: 0, channel: null);
  }

  static ProtocolCommand _translateIpao(
    ToyModel toy,
    int intensity,
    int? channel,
  ) {
    final cmd = IpaoProtocol.vibrationIntensity(intensity);

    return ProtocolCommand(
      bytes: cmd,
      channel: channel ?? 0,
      intensity: intensity,
      protocolType: ProtocolType.ipao,
      bleProtocol: BleProtocolType.ipao,
      description: 'IPAO: ${IpaoProtocol.toHex(cmd)}',
    );
  }

  static ProtocolCommand _translateCryptBle(
    ToyModel toy,
    int intensity,
    int? channel,
  ) {
    final value = intensity ~/ 25; // 0-10 range
    final cmd = CryptBle.encryptCommand(value, channel != null ? 1 : 0, [
      0x01, 0x02, 0x03, 0x04
    ]);

    return ProtocolCommand(
      bytes: cmd,
      channel: channel ?? 0,
      intensity: intensity,
      protocolType: ProtocolType.cryptBle,
      bleProtocol: BleProtocolType.cryptBle,
      description: 'CryptBle: len=${cmd.length}',
    );
  }

  // ── WbMSE ──────────────────────────────────────────────────

  static ProtocolCommand _translateWbMSE(
    ToyModel toy,
    int intensity,
    int? channel,
  ) {
    final prefixBytes = _parseHexPrefix(toy.broadcastPrefix);
    final prefix = prefixBytes.isNotEmpty ? prefixBytes.first : 0xE6;
    final checksum = prefix ^ intensity;
    final bytes = [prefix, intensity, checksum];

    return ProtocolCommand(
      bytes: bytes,
      channel: channel ?? 0,
      intensity: intensity,
      protocolType: ProtocolType.wbMSE,
      description: 'wbMSE Standard: [0x${prefix.toRadixString(16).padLeft(2, '0')}, 0x${intensity.toRadixString(16).padLeft(2, '0')}, 0x${checksum.toRadixString(16).padLeft(2, '0')}]',
    );
  }

  static ProtocolCommand _translateWbMSECustom(
    ToyModel toy,
    int intensity,
    int? channel,
  ) {
    final prefixBytes = _parseHexPrefix(toy.broadcastPrefix);
    if (prefixBytes.isEmpty) {
      return _translateWbMSE(toy, intensity, channel);
    }
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

  static ProtocolCommand _translateWbMSEDual(
    ToyModel toy,
    int intensity,
    int? channel,
  ) {
    if (channel != null && channel != 0) {
      return _translateWbMSEDualChannel(toy, intensity, channel);
    }
    const ch1Prefix = ChannelPrefix.ch1Thrust;
    const ch2Prefix = ChannelPrefix.ch2Vibration;
    final customPrefixes = _parseCustomPrefixes(toy.supportedFuncs);
    final effectiveCh1Prefix = customPrefixes['ch1'] ?? ch1Prefix;
    final effectiveCh2Prefix = customPrefixes['ch2'] ?? ch2Prefix;
    final ch1Checksum = effectiveCh1Prefix ^ intensity;
    final ch2Checksum = effectiveCh2Prefix ^ intensity;
    final bytes = [effectiveCh1Prefix, intensity, ch1Checksum, effectiveCh2Prefix, intensity, ch2Checksum];

    return ProtocolCommand(
      bytes: bytes,
      channel: 0,
      intensity: intensity,
      protocolType: ProtocolType.wbMSEDual,
      description: 'wbMSE Dual: CH1=[0x${effectiveCh1Prefix.toRadixString(16)}, 0x${intensity.toRadixString(16)}, 0x${ch1Checksum.toRadixString(16)}] CH2=[0x${effectiveCh2Prefix.toRadixString(16)}, 0x${intensity.toRadixString(16)}, 0x${ch2Checksum.toRadixString(16)}]',
    );
  }

  static ProtocolCommand _translateWbMSEDualChannel(
    ToyModel toy,
    int intensity,
    int channel,
  ) {
    final customPrefixes = _parseCustomPrefixes(toy.supportedFuncs);
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

  static ProtocolCommand _translatePrecise(
    ToyModel toy,
    int intensity,
    int? channel,
  ) {
    final bytes = [intensity];
    return ProtocolCommand(
      bytes: bytes,
      channel: channel ?? 0,
      intensity: intensity,
      protocolType: ProtocolType.precise,
      description: 'Precise: 0x${intensity.toRadixString(16).padLeft(2, '0')} ($intensity)',
    );
  }

  static ProtocolCommand _translateGeneric(
    ToyModel toy,
    int intensity,
    int? channel,
  ) {
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

  // ── Helpers ─────────────────────────────────────────────────

  static ProtocolType _detectProtocolType(ToyModel toy) {
    final prefix = toy.broadcastPrefix.toLowerCase();
    final modelId = toy.id.toLowerCase();
    final motorLogic = toy.motorLogic.toLowerCase();
    final supportedFuncs = toy.supportedFuncs.toLowerCase();

    if (toy.isPrecise) return ProtocolType.precise;
    if (motorLogic.contains('dual') || motorLogic.contains('doble')) return ProtocolType.wbMSEDual;
    if (prefix.contains('wbmse') || prefix.contains('77 62 4d 53 45') || modelId.contains('8154') || modelId.contains('8039')) {
      if (prefix.isNotEmpty && !WbMSEPrefix.standard.contains(prefix)) return ProtocolType.wbMSECustom;
      return ProtocolType.wbMSE;
    }
    if (supportedFuncs.contains('dual') || supportedFuncs.contains('ch1') || supportedFuncs.contains('ch2')) return ProtocolType.wbMSEDual;
    return ProtocolType.wbMSE;
  }

  static int _normalizeIntensity(int intensity, bool isPrecise) {
    if (intensity > 255) return 255;
    if (isPrecise || intensity > 100) return intensity.clamp(0, 255);
    return ((intensity / 100) * 255).round();
  }

  static int _mapToGenericLevel(int intensity) {
    return (intensity / 255 * 9).round();
  }

  static List<int> _parseHexPrefix(String hexString) {
    if (hexString.isEmpty) return [];
    final clean = hexString.replaceAll(' ', '').toUpperCase();
    if (!RegExp(r'^[0-9A-F]+$').hasMatch(clean)) return [];
    final bytes = <int>[];
    for (var i = 0; i < clean.length; i += 2) {
      if (i + 1 < clean.length) bytes.add(int.parse(clean.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  static Map<String, int> _parseCustomPrefixes(String supportedFuncs) {
    final prefixes = <String, int>{};
    final ch1Match = RegExp(r'CH1[:=]\s*0x([0-9A-Fa-f]{2})').firstMatch(supportedFuncs);
    if (ch1Match != null && ch1Match.groupCount >= 1) prefixes['ch1'] = int.parse(ch1Match.group(1)!, radix: 16);
    final ch2Match = RegExp(r'CH2[:=]\s*0x([0-9A-Fa-f]{2})').firstMatch(supportedFuncs);
    if (ch2Match != null && ch2Match.groupCount >= 1) prefixes['ch2'] = int.parse(ch2Match.group(2)!, radix: 16);
    return prefixes;
  }

  static int _calculateChecksum(List<int> prefixBytes, int intensity) {
    var checksum = 0;
    for (final byte in prefixBytes) { checksum ^= byte; }
    checksum ^= intensity;
    return checksum;
  }

  static ProtocolCommand generateStopCommand(ToyModel toy) {
    return translateStop(toy: toy);
  }

  static ProtocolCommand generateEmergencyCommand(ToyModel toy) {
    return translate(toy: toy, intensity: 255, channel: null);
  }

  static ProtocolCommand generateTapCommand(ToyModel toy, {int intensity = 50}) {
    return translate(toy: toy, intensity: intensity, channel: null);
  }
}

extension ProtocolCommandExtension on ProtocolCommand {
  bool get isValid => bytes.isNotEmpty && intensity >= 0;
  int get commandByte => bytes.isNotEmpty ? bytes.first : 0;
  int get lastByte => bytes.isNotEmpty ? bytes.last : 0;
}
