import '../hal/protocol_adapter.dart';
// ═══════════════════════════════════════════════════════════════
// Velvet Sync Platform · lib/core/protocols/lvs_protocol.dart
// Protocolo para dispositivos Love Spouse (wbMSE/8154)
// ═══════════════════════════════════════════════════════════════

import '../types/command_types.dart';
import '../types/device_types.dart';
import '../types/result_types.dart';
import '../protocols/protocol_base.dart';

/// Protocolo para dispositivos Love Spouse (wbMSE/8154)
class LvsProtocol extends ProtocolBase {
  @override
  String get name => 'LVS';
  
  @override
  String get description => 'Protocolo para dispositivos Love Spouse (wbMSE/8154)';
  
  @override
  String get version => '1.0.0';
  
  @override
  List<ConnectionType> get supportedTransports => [ConnectionType.ble];
  
  @override
  List<DeviceFeature> get supportedFeatures => [
    DeviceFeature.vibrate,
    DeviceFeature.oscillate,
  ];
  
  @override
  ControlPrecision get precision => ControlPrecision.precise;
  
  PacketMode packetMode = PacketMode.b11;
  
  static const List<int> prefix = [0x6D, 0xB6, 0x43, 0xCE, 0x97, 0xFE, 0x42, 0x7C];
  static const List<int> header18B = [0xFF, 0xFF, 0x00];
  static const List<int> appendix18B = [0x03, 0x03, 0x8F, 0xAE];
  static const int companyId = 0xFFF0;
  static const String serviceUuid = '0000fff0-0000-1000-8000-00805f9b34fb';
  
  static const List<int> cmdStop = [0xE5, 0x15, 0x7D];
  static const List<int> cmdLow = [0xE4, 0x9C, 0x6C];
  static const List<int> cmdMed = [0xE7, 0x07, 0x5E];
  static const List<int> cmdHigh = [0xE6, 0x8E, 0x4F];
  
  static const List<int> ch1Stop = [0xD5, 0x96, 0x4C];
  static const List<int> ch1Low = [0xD4, 0x1F, 0x5D];
  static const List<int> ch1Med = [0xD7, 0x84, 0x6F];
  static const List<int> ch1High = [0xD6, 0x0D, 0x7E];
  
  static const List<int> ch2Stop = [0xE5, 0x15, 0x7D];
  static const List<int> ch2Low = [0xE4, 0x9C, 0x6C];
  static const List<int> ch2Med = [0xE7, 0x07, 0x5E];
  static const List<int> ch2High = [0xE6, 0x8E, 0x4F];
  
  static const List<int> pat1 = [0xE1, 0x31, 0x3B];
  static const List<int> pat2 = [0xE0, 0xB8, 0x2A];
  static const List<int> pat3 = [0xE3, 0x23, 0x18];
  static const List<int> pat4 = [0xE2, 0xAA, 0x09];
  static const List<int> pat5 = [0xED, 0x5D, 0xF1];
  static const List<int> pat6 = [0xEC, 0xD4, 0xE0];

  @override
  Result<SpecificCommand, ProtocolError> translate(GenericCommand command) {
    try {
      List<int> cmdBytes;
      switch (command.type) {
        case CommandType.vibrate:
          cmdBytes = _translateVibrate(command.intensity, command.channel);
          break;
        case CommandType.stop:
          cmdBytes = _translateStop(command.channel);
          break;
        case CommandType.pattern:
          final patternId = command.parameters?['patternId'] as String?;
          if (patternId == null) return const Failure(ProtocolError.invalidPacketFormat);
          cmdBytes = _translatePattern(patternId);
          break;
        case CommandType.custom:
          final bytes = command.parameters?['bytes'] as List<int>?;
          if (bytes == null) return const Failure(ProtocolError.invalidPacketFormat);
          cmdBytes = bytes;
          break;
        default:
          return const Failure(ProtocolError.unrecognizedCommand);
      }
      return Success(SpecificCommand.bytes(
        protocolName: name,
        bytes: _buildPacket(cmdBytes),
        parameters: {'mode': packetMode.name, 'channel': command.channel.name},
      ));
    } catch (e) {
      return const Failure(ProtocolError.invalidPacketFormat);
    }
  }

  List<int> _translateVibrate(double intensity, DeviceChannel channel) {
    final intensityByte = (intensity * 255).clamp(0, 255).toInt();
    switch (channel) {
      case DeviceChannel.channel1: return [0xD6, 0x0D, intensityByte];
      case DeviceChannel.channel2: return [0xE6, 0x8E, intensityByte];
      case DeviceChannel.both: return [0xF6, intensityByte, intensityByte];
      case DeviceChannel.single: return [0xE6, 0x8E, intensityByte];
    }
  }

  List<int> _translateStop(DeviceChannel channel) {
    switch (channel) {
      case DeviceChannel.channel1: return ch1Stop;
      case DeviceChannel.channel2: return ch2Stop;
      case DeviceChannel.both:
      case DeviceChannel.single: return LvsProtocol.cmdStop;
    }
  }

  List<int> _translatePattern(String patternId) {
    switch (patternId.toLowerCase()) {
      case 'pat1':
      case 'pattern1': return pat1;
      case 'pat2':
      case 'pattern2': return pat2;
      case 'pat3':
      case 'pattern3': return pat3;
      case 'pat4':
      case 'pattern4': return pat4;
      case 'pat5':
      case 'pattern5': return pat5;
      case 'pat6':
      case 'pattern6': return pat6;
      case 'ch1_low': return ch1Low;
      case 'ch1_med': return ch1Med;
      case 'ch1_high': return ch1High;
      case 'ch2_low': return ch2Low;
      case 'ch2_med': return ch2Med;
      case 'ch2_high': return ch2High;
      default: return LvsProtocol.cmdStop;
    }
  }

  @override
  SpecificCommand translateVibrate(double intensity, {DeviceChannel channel = DeviceChannel.single}) {
    return SpecificCommand.bytes(
      protocolName: name,
      bytes: _buildPacket(_translateVibrate(intensity, channel)),
      parameters: {'intensity': intensity, 'channel': channel.name},
    );
  }

  @override
  SpecificCommand translateRotate(double intensity) => translateVibrate(intensity);

  @override
  SpecificCommand translateStop({DeviceChannel channel = DeviceChannel.single}) {
    return SpecificCommand.bytes(
      protocolName: name,
      bytes: _buildPacket(_translateStop(channel)),
      parameters: {'channel': channel.name},
    );
  }

  @override
  SpecificCommand translatePattern(String patternId) {
    return SpecificCommand.bytes(
      protocolName: name,
      bytes: _buildPacket(_translatePattern(patternId)),
      parameters: {'patternId': patternId},
    );
  }

  List<int> _buildPacket(List<int> cmdBytes) {
    if (packetMode == PacketMode.b11) return [...prefix, ...cmdBytes];
    return [...header18B, ...prefix, ...cmdBytes, ...appendix18B];
  }

  @override
  Future<Result<void, DeviceError>> send(SpecificCommand command) async => const Success(null);

  @override
  Future<void> configure(Map<String, dynamic> config) async {
    if (config.containsKey('packetMode')) {
      final mode = config['packetMode'] as String;
      packetMode = mode == 'b18' ? PacketMode.b18 : PacketMode.b11;
    }
  }

  @override
  Map<String, dynamic> getConfiguration() => {
    'packetMode': packetMode.name,
    'companyId': companyId,
    'serviceUuid': serviceUuid,
  };

  @override
  void dispose() {}
}

enum PacketMode { b11, b18 }

extension LvsProtocolUtils on LvsProtocol {
  List<int> commandForSpeed(String level) {
    switch (level.toLowerCase()) {
      case 'stop': return LvsProtocol.cmdStop;
      case 'low': return LvsProtocol.cmdLow;
      case 'medium': return LvsProtocol.cmdMed;
      case 'high': return LvsProtocol.cmdHigh;
      default: return LvsProtocol.cmdStop;
    }
  }
}
