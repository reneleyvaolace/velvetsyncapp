import 'package:flutter_test/flutter_test.dart';
import 'package:velvet_sync/services/ble/lovespouse_protocol.dart';
import 'package:velvet_sync/devices/models/toy_model.dart';

void main() {
  group('LoveSpouseUuids', () {
    test('service UUID is correct', () {
      expect(LoveSpouseUuids.service, '0000fff0-0000-1000-8000-00805f9b34fb');
    });

    test('classicWrite UUID is correct', () {
      expect(LoveSpouseUuids.classicWrite, '0000fff1-0000-1000-8000-00805f9b34fb');
    });

    test('advPrefix is wbMSE', () {
      expect(LoveSpouseUuids.advPrefix, [0x77, 0x62, 0x4D, 0x53, 0x45]);
    });

    test('companyId is 0xFFF0', () {
      expect(LoveSpouseUuids.companyId, 0xFFF0);
    });
  });

  group('LoveSpouseCommands - Legacy Format', () {
    test('handshake constants are correct', () {
      expect(LoveSpouseCommands.handshakePing, [0x01, 0x01, 0x01]);
      expect(LoveSpouseCommands.handshakePong, [0x02, 0x02, 0x02]);
      expect(LoveSpouseCommands.handshakeFinal, [0x00, 0x00, 0x00]);
      expect(LoveSpouseCommands.expectedAck, 0x06);
    });

    test('CH1 motor commands are correct', () {
      expect(LoveSpouseCommands.ch1Stop, [0xD5, 0x96, 0x4C]);
      expect(LoveSpouseCommands.ch1Low, [0xD4, 0x1F, 0x5D]);
      expect(LoveSpouseCommands.ch1Med, [0xD7, 0x84, 0x6F]);
      expect(LoveSpouseCommands.ch1High, [0xD6, 0x0D, 0x7E]);
    });

    test('CH2 motor commands are correct', () {
      expect(LoveSpouseCommands.ch2Stop, [0xE5, 0x15, 0x7D]);
      expect(LoveSpouseCommands.ch2Low, [0xE4, 0x9C, 0x6C]);
      expect(LoveSpouseCommands.ch2Med, [0xE7, 0x07, 0x5E]);
      expect(LoveSpouseCommands.ch2High, [0xE6, 0x8E, 0x4F]);
    });

    test('Multimedia CH2 commands use 0xA prefix', () {
      expect(LoveSpouseCommands.ch2StopMm, [0xA5, 0x15, 0x7D]);
      expect(LoveSpouseCommands.ch2LowMm, [0xA4, 0x9C, 0x6C]);
      expect(LoveSpouseCommands.ch2MedMm, [0xA7, 0x07, 0x5E]);
      expect(LoveSpouseCommands.ch2HighMm, [0xA6, 0x8E, 0x4F]);
    });

    test('9 patterns for CH1', () {
      expect(LoveSpouseCommands.ch1Pat1, [0xD1, 0x31, 0x3B]);
      expect(LoveSpouseCommands.ch1Pat9, [0xD9, 0x19, 0xB5]);
    });

    test('9 patterns for CH2', () {
      expect(LoveSpouseCommands.ch2Pat1, [0xE1, 0x31, 0x3B]);
      expect(LoveSpouseCommands.ch2Pat9, [0xE9, 0x19, 0xB5]);
    });

    test('Dual motor command F6', () {
      expect(LoveSpouseCommands.dualMotor(100, 200), [0xF6, 100, 200]);
      expect(LoveSpouseCommands.dualMotor(0, 0), [0xF6, 0, 0]);
      expect(LoveSpouseCommands.dualMotor(-5, 300), [0xF6, 0, 255]);
    });

    test('Precise channel commands', () {
      expect(LoveSpouseCommands.preciseChannel1(128), [0xD6, 0x0D, 128]);
      expect(LoveSpouseCommands.preciseChannel2(200), [0xA6, 0x8E, 200]);
    });

    test('Special functions', () {
      expect(LoveSpouseCommands.heatingOn, [0xF1, 0x01, 0x01]);
      expect(LoveSpouseCommands.heatingOff, [0xF1, 0x00, 0x00]);
      expect(LoveSpouseCommands.strikeOn, [0xF2, 0x01, 0x01]);
      expect(LoveSpouseCommands.strikeOff, [0xF2, 0x00, 0x00]);
      expect(LoveSpouseCommands.suctionOn, [0xF3, 0x01, 0x01]);
      expect(LoveSpouseCommands.suctionOff, [0xF3, 0x00, 0x00]);
    });

    test('Telemetry commands', () {
      expect(LoveSpouseCommands.telemetryBatteryCmd, 0x8A);
      expect(LoveSpouseCommands.telemetryKegelCmd, 0x8B);
    });
  });

  group('LoveSpouseNewCommands - NewCommand Format', () {
    test('motor command creates 4-byte packet with checksum', () {
      final cmd = LoveSpouseNewCommands.motor(1, 128);
      expect(cmd.length, 4);
      expect(cmd[0], 0x10);
      expect(cmd[1], 0x01);
      expect(cmd[2], 128);
      expect(cmd[3], 0x10 ^ 0x01 ^ 128);
    });

    test('dualMotorNew creates 5-byte packet', () {
      final cmd = LoveSpouseNewCommands.dualMotorNew(100, 200);
      expect(cmd.length, 5);
      expect(cmd[0], 0x10);
      expect(cmd[1], 0x03);
      expect(cmd[2], 100);
      expect(cmd[3], 200);
      expect(cmd[4], 0x10 ^ 0x03 ^ 100 ^ 200);
    });

    test('stopAll is correct', () {
      expect(LoveSpouseNewCommands.stopAll, [0x10, 0x00, 0x00, 0x10]);
    });

    test('heating command', () {
      final cmd = LoveSpouseNewCommands.heating(128);
      expect(cmd.length, 4);
      expect(cmd[0], 0x20);
      expect(cmd[1], 0x01);
      expect(cmd[2], 128);
      expect(cmd[3], 0x20 ^ 0x01 ^ 128);
    });

    test('strike command maps pattern index correctly', () {
      final cmd = LoveSpouseNewCommands.strike(0); // pattern 1
      expect(cmd[2], 1);
      
      final cmd5 = LoveSpouseNewCommands.strike(4); // pattern 5
      expect(cmd5[2], 5);
    });

    test('suction command', () {
      final cmd = LoveSpouseNewCommands.suction(200);
      expect(cmd[3], 0x20 ^ 0x03 ^ 200);
    });

    test('pattern command', () {
      final cmd = LoveSpouseNewCommands.pattern(1, 0); // CH1, pattern 1
      expect(cmd[0], 0x30);
      expect(cmd[1], 0x01);
      expect(cmd[2], 1);
    });

    test('telemetry requests', () {
      expect(LoveSpouseNewCommands.requestBattery, [0x40, 0x01, 0x00, 0x41]);
      expect(LoveSpouseNewCommands.requestKegel, [0x40, 0x02, 0x00, 0x42]);
    });

    test('handshake constants are 4 bytes', () {
      expect(LoveSpouseNewCommands.handshakePing.length, 4);
      expect(LoveSpouseNewCommands.handshakePong.length, 4);
      expect(LoveSpouseNewCommands.handshakeFinal.length, 4);
    });
  });

  group('convertToNewCommand', () {
    test('returns as-is for already NewCommand (4+ bytes)', () {
      final legacy = [0x10, 0x01, 0x80, 0x91];
      expect(convertToNewCommand(legacy), legacy);
    });

    test('converts CH1 legacy to NewCommand motor', () {
      final legacy = [0xD6, 0x0D, 0x80]; // CH1 precise
      final converted = convertToNewCommand(legacy);
      expect(converted, LoveSpouseNewCommands.motor(1, 128));
    });

    test('converts CH2 legacy to NewCommand motor', () {
      final legacy = [0xA6, 0x8E, 0xC8]; // CH2 precise multimedia
      final converted = convertToNewCommand(legacy);
      expect(converted, LoveSpouseNewCommands.motor(2, 200));
    });

    test('converts dual motor F6', () {
      final legacy = [0xF6, 0x64, 0xC8]; // dual motor
      final converted = convertToNewCommand(legacy);
      expect(converted, LoveSpouseNewCommands.dualMotorNew(100, 200));
    });

    test('converts heating F1', () {
      final legacy = [0xF1, 0x40, 0xBF]; // heating level 64 (byte 1 = 0x40)
      final converted = convertToNewCommand(legacy);
      expect(converted, LoveSpouseNewCommands.heating(64));
    });

    test('converts strike F2', () {
      final legacy = [0xF2, 0x02, 0xF0]; // strike pattern 2 (byte 1 = 0x02, strike() adds 1)
      final converted = convertToNewCommand(legacy);
      expect(converted, LoveSpouseNewCommands.strike(1));
    });

    test('converts suction F3', () {
      final legacy = [0xF3, 0x80, 0x73]; // suction level 128 (byte 1 = 0x80)
      final converted = convertToNewCommand(legacy);
      expect(converted, LoveSpouseNewCommands.suction(128));
    });

    test('converts CH1 patterns (prefixes in D1-D9 range, excl D6)', () {
      // pattern index = prefix - 0xD1
      final testCases = [
        {'prefix': 0xD1, 'patternIndex': 0},  // ch1Pat1: 0xD1 - 0xD1 = 0
        {'prefix': 0xD2, 'patternIndex': 1},  // ch1Pat4: 0xD2 - 0xD1 = 1
        {'prefix': 0xD3, 'patternIndex': 2},  // ch1Pat3: 0xD3 - 0xD1 = 2
        {'prefix': 0xD9, 'patternIndex': 8},  // ch1Pat9: 0xD9 - 0xD1 = 8
      ];
      
      for (final tc in testCases) {
        final prefix = tc['prefix'] as int;
        final patternIndex = tc['patternIndex'] as int;
        final legacy = [prefix, 0x00, 0x00];
        final converted = convertToNewCommand(legacy);
        expect(converted, LoveSpouseNewCommands.pattern(1, patternIndex),
            reason: 'Failed for prefix 0x${prefix.toRadixString(16)}');
      }
    });

    test('converts CH2 patterns (prefixes in E1-E9 range)', () {
      // pattern index = prefix - 0xE1
      final testCases = [
        {'prefix': 0xE1, 'patternIndex': 0},  // ch2Pat1: 0xE1 - 0xE1 = 0
        {'prefix': 0xE2, 'patternIndex': 1},  // ch2Pat4: 0xE2 - 0xE1 = 1
        {'prefix': 0xE3, 'patternIndex': 2},  // ch2Pat3: 0xE3 - 0xE1 = 2
        {'prefix': 0xE9, 'patternIndex': 8},  // ch2Pat9: 0xE9 - 0xE1 = 8
      ];
      
      for (final tc in testCases) {
        final prefix = tc['prefix'] as int;
        final patternIndex = tc['patternIndex'] as int;
        final legacy = [prefix, 0x00, 0x00];
        final converted = convertToNewCommand(legacy);
        expect(converted, LoveSpouseNewCommands.pattern(2, patternIndex),
            reason: 'Failed for prefix 0x${prefix.toRadixString(16)}');
      }
    });

    test('converts CH2 multimedia patterns (prefixes in A1-A9 range, excl A6)', () {
      // pattern index = prefix - 0xA1
      final testCases = [
        {'prefix': 0xA1, 'patternIndex': 0},  // ch2Pat1Mm: 0xA1 - 0xA1 = 0
        {'prefix': 0xA2, 'patternIndex': 1},  // ch2Pat4Mm: 0xA2 - 0xA1 = 1
        {'prefix': 0xA3, 'patternIndex': 2},  // ch2Pat3Mm: 0xA3 - 0xA1 = 2
        {'prefix': 0xA9, 'patternIndex': 8},  // ch2Pat9Mm: 0xA9 - 0xA1 = 8
      ];
      
      for (final tc in testCases) {
        final prefix = tc['prefix'] as int;
        final patternIndex = tc['patternIndex'] as int;
        final legacy = [prefix, 0x00, 0x00];
        final converted = convertToNewCommand(legacy);
        expect(converted, LoveSpouseNewCommands.pattern(2, patternIndex),
            reason: 'Failed for prefix 0x${prefix.toRadixString(16)}');
      }
    });

    test('returns fallback for unknown prefix', () {
      final legacy = [0x99, 0x00, 0x00];
      expect(convertToNewCommand(legacy), legacy);
    });
  });

  group('parseTelemetry', () {
    test('parses battery telemetry', () {
      final bytes = [0x8A, 0x50, 0x01]; // 80%, charging
      final result = LoveSpouseCommands.parseTelemetry(bytes);
      expect(result, isNotNull);
      expect(result!['type'], 'battery');
      expect(result['level'], 80);
      expect(result['charging'], true);
    });

    test('parses kegel telemetry', () {
      final bytes = [0x8B, 0x7F, 0x05]; // pressure 127, 5 reps
      final result = LoveSpouseCommands.parseTelemetry(bytes);
      expect(result, isNotNull);
      expect(result!['type'], 'kegel');
      expect(result['pressure'], 127);
      expect(result['reps'], 5);
    });

    test('returns null for empty bytes', () {
      expect(LoveSpouseCommands.parseTelemetry([]), isNull);
    });

    test('returns null for unknown command', () {
      final bytes = [0x99, 0x00, 0x00];
      expect(LoveSpouseCommands.parseTelemetry(bytes), isNull);
    });
  });

  group('isLoveSpouseDevice', () {
    test('detects wbms in name', () {
      expect(isLoveSpouseDevice('WBMS-123'), true);
      expect(isLoveSpouseDevice('wbms_device'), true);
    });

    test('detects lovespouse in name', () {
      expect(isLoveSpouseDevice('LoveSpouse Toy'), true);
    });

    test('detects 8154 in name', () {
      expect(isLoveSpouseDevice('ZB-8154'), true);
    });

    test('detects zv prefix', () {
      expect(isLoveSpouseDevice('ZV-001'), true);
    });

    test('detects ls prefix', () {
      expect(isLoveSpouseDevice('LS-Toy'), true);
    });

    test('returns false for unknown devices', () {
      expect(isLoveSpouseDevice('LVS-123'), false);
      expect(isLoveSpouseDevice('Generic Toy'), false);
    });
  });

  group('getLoveSpouseBroadcastPrefix', () {
    test('returns default wbMSE prefix', () {
      expect(getLoveSpouseBroadcastPrefix(), [0x77, 0x62, 0x4D, 0x53, 0x45]);
      expect(getLoveSpouseBroadcastPrefix(''), [0x77, 0x62, 0x4D, 0x53, 0x45]);
      expect(getLoveSpouseBroadcastPrefix(null), [0x77, 0x62, 0x4D, 0x53, 0x45]);
    });

    test('parses custom prefix', () {
      expect(getLoveSpouseBroadcastPrefix('AA BB CC'), [0xAA, 0xBB, 0xCC]);
    });

    test('falls back to default for invalid prefix', () {
      expect(getLoveSpouseBroadcastPrefix('GG HH'), [0x77, 0x62, 0x4D, 0x53, 0x45]);
    });
  });

  group('buildLoveSpouseAdvertisingPacket', () {
    test('prepends advPrefix to command', () {
      final cmd = [0xF6, 0x64, 0xC8];
      final packet = buildLoveSpouseAdvertisingPacket(cmd);
      expect(packet.take(5), [0x77, 0x62, 0x4D, 0x53, 0x45]);
      expect(packet.skip(5), cmd);
    });

    test('uses custom advPrefix', () {
      final cmd = [0x01, 0x02];
      final custom = [0xAA, 0xBB];
      final packet = buildLoveSpouseAdvertisingPacket(cmd, advPrefix: custom);
      expect(packet.take(2), custom);
    });
  });

  group('ToyModel LoveSpouse fields', () {
    test('ToyModel has gamePath and isNewCommand fields', () {
      final toy = ToyModel(
        id: 'test',
        name: 'Test Toy',
        usageType: 'Universal',
        targetAnatomy: 'Universal',
        stimulationType: 'Vibration',
        motorLogic: 'Dual Channel',
        imageUrl: '',
        qrCodeUrl: '',
        supportedFuncs: 'vibration',
        isPrecise: false,
        broadcastPrefix: '77 62 4d 53 45',
        bleProtocol: BleProtocolType.loveSpouse,
        isEncrypt: true,
        encryptCommand: 'AA BB',
        gamePath: 'https://example.com/game.zip',
        isNewCommand: true,
      );
      
      expect(toy.gamePath, 'https://example.com/game.zip');
      expect(toy.isNewCommand, true);
      expect(toy.bleProtocol, BleProtocolType.loveSpouse);
    });
  });
}