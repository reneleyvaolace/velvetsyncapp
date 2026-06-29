import 'package:flutter_test/flutter_test.dart';
import 'package:velvet_sync/utils/protocol_translator.dart';
import 'package:velvet_sync/devices/models/toy_model.dart';

ToyModel _makeToy({
  String id = '8154',
  String name = 'Test Toy',
  String broadcastPrefix = '77 62 4d 53 45',
  bool isPrecise = false,
  String motorLogic = 'Single Channel',
  String supportedFuncs = '',
}) {
  return ToyModel(
    id: id, name: name,
    usageType: 'Insertable', targetAnatomy: 'Vaginal',
    stimulationType: 'Vibración', motorLogic: motorLogic,
    imageUrl: '', qrCodeUrl: '', supportedFuncs: supportedFuncs,
    isPrecise: isPrecise, broadcastPrefix: broadcastPrefix,
  );
}

void main() {
  group('ProtocolTranslator - translate', () {
    test('returns wbMSE protocol for wbMSE toy', () {
      final toy = _makeToy();
      final cmd = ProtocolTranslator.translate(toy: toy, intensity: 50);
      expect(cmd.protocolType, ProtocolType.wbMSE);
      expect(cmd.bytes.length, 3);
    });

    test('returns precise protocol for precise toy', () {
      final toy = _makeToy(isPrecise: true);
      final cmd = ProtocolTranslator.translate(toy: toy, intensity: 128);
      expect(cmd.protocolType, ProtocolType.precise);
      expect(cmd.bytes, [128]);
    });

    test('returns wbMSEDual protocol for dual motor logic', () {
      final toy = _makeToy(motorLogic: 'Dual Motor');
      final cmd = ProtocolTranslator.translate(toy: toy, intensity: 50);
      expect(cmd.protocolType, ProtocolType.wbMSEDual);
    });

    test('returns wbMSEDual for dual in supportedFuncs (non-wbMSE prefix)', () {
      final toy = _makeToy(id: '9999', supportedFuncs: 'dual_channel', broadcastPrefix: '');
      final cmd = ProtocolTranslator.translate(toy: toy, intensity: 50);
      expect(cmd.protocolType, ProtocolType.wbMSEDual);
    });

    test('returns correct command for channel 1', () {
      final toy = _makeToy();
      final cmd = ProtocolTranslator.translate(toy: toy, intensity: 80, channel: 1);
      expect(cmd.channel, 1);
      expect(cmd.bytes.length, 3);
    });

    test('returns correct command for channel 2', () {
      final toy = _makeToy();
      final cmd = ProtocolTranslator.translate(toy: toy, intensity: 80, channel: 2);
      expect(cmd.channel, 2);
      expect(cmd.bytes.length, 3);
    });

    test('normalizes intensity from 0-100 to 0-255 for non-precise', () {
      final toy = _makeToy();
      final cmd = ProtocolTranslator.translate(toy: toy, intensity: 50);
      expect(cmd.intensity, 128);
    });
  });

  group('ProtocolTranslator - normalizeIntensity', () {
    test('returns 0-255 value unchanged', () {
      final toy = _makeToy(isPrecise: true);
      final cmd = ProtocolTranslator.translate(toy: toy, intensity: 200);
      expect(cmd.intensity, 200);
    });

    test('caps at 255 for values above 255', () {
      final toy = _makeToy(isPrecise: true);
      final cmd = ProtocolTranslator.translate(toy: toy, intensity: 999);
      expect(cmd.intensity, 255);
    });

    test('passes through raw 101-255 values for non-precise', () {
      final toy = _makeToy(isPrecise: false);
      final cmd = ProtocolTranslator.translate(toy: toy, intensity: 200);
      expect(cmd.intensity, 200);
    });

    test('scales 0-100 percentage to 0-255 for non-precise', () {
      final toy = _makeToy(isPrecise: false);
      final cmd = ProtocolTranslator.translate(toy: toy, intensity: 75);
      expect(cmd.intensity, 191);
    });
  });

  group('ProtocolTranslator - translatePattern', () {
    test('delegates to translate correctly', () {
      final toy = _makeToy();
      final cmd = ProtocolTranslator.translatePattern(toy: toy, pattern: 5);
      expect(cmd, isA<ProtocolCommand>());
    });
  });

  group('ProtocolTranslator - translateStop', () {
    test('creates stop command with 0 intensity', () {
      final toy = _makeToy(isPrecise: true);
      final cmd = ProtocolTranslator.translateStop(toy: toy);
      expect(cmd.intensity, 0);
    });
  });

  group('ProtocolTranslator - generateStopCommand', () {
    test('generates stop command', () {
      final toy = _makeToy();
      final cmd = ProtocolTranslator.generateStopCommand(toy);
      expect(cmd, isA<ProtocolCommand>());
    });
  });

  group('ProtocolTranslator - generateEmergencyCommand', () {
    test('generates emergency command with max intensity', () {
      final toy = _makeToy(isPrecise: true);
      final cmd = ProtocolTranslator.generateEmergencyCommand(toy);
      expect(cmd.intensity, 255);
    });
  });

  group('ProtocolTranslator - generateTapCommand', () {
    test('generates tap command with default intensity 50', () {
      final toy = _makeToy();
      final cmd = ProtocolTranslator.generateTapCommand(toy);
      expect(cmd, isA<ProtocolCommand>());
    });

    test('generates tap command with custom intensity', () {
      final toy = _makeToy();
      final cmd = ProtocolTranslator.generateTapCommand(toy, intensity: 75);
      expect(cmd, isA<ProtocolCommand>());
    });
  });

  group('ProtocolCommand', () {
    test('isDualChannel returns true for channel 0', () {
      const cmd = ProtocolCommand(
        bytes: [0x01], channel: 0, intensity: 50,
        protocolType: ProtocolType.wbMSE, description: 'test',
      );
      expect(cmd.isDualChannel, true);
      expect(cmd.isChannel1, false);
      expect(cmd.isChannel2, false);
    });

    test('isChannel1 returns true for channel 1', () {
      const cmd = ProtocolCommand(
        bytes: [0x01], channel: 1, intensity: 50,
        protocolType: ProtocolType.wbMSE, description: 'test',
      );
      expect(cmd.isChannel1, true);
    });

    test('isChannel2 returns true for channel 2', () {
      const cmd = ProtocolCommand(
        bytes: [0x01], channel: 2, intensity: 50,
        protocolType: ProtocolType.wbMSE, description: 'test',
      );
      expect(cmd.isChannel2, true);
    });
  });

  group('ProtocolCommandExtension', () {
    test('isValid returns true for valid command', () {
      const cmd = ProtocolCommand(
        bytes: [0x01], channel: 0, intensity: 50,
        protocolType: ProtocolType.wbMSE, description: 'test',
      );
      expect(cmd.isValid, true);
    });

    test('isValid returns false for empty bytes', () {
      const cmd = ProtocolCommand(
        bytes: [], channel: 0, intensity: -1,
        protocolType: ProtocolType.unknown, description: 'invalid',
      );
      expect(cmd.isValid, false);
    });

    test('commandByte returns first byte', () {
      const cmd = ProtocolCommand(
        bytes: [0xAB, 0xCD], channel: 0, intensity: 50,
        protocolType: ProtocolType.wbMSE, description: 'test',
      );
      expect(cmd.commandByte, 0xAB);
    });
  });
}
