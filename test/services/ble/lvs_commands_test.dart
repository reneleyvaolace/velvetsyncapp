import 'package:flutter_test/flutter_test.dart';
import 'package:velvet_sync/devices/models/toy_model.dart';
import 'package:velvet_sync/services/ble/lvs_commands.dart';

void main() {
  group('LvsCommands - Command Constants', () {
    test('cmdStop has correct bytes', () {
      expect(LvsCommands.cmdStop, [0xE5, 0x15, 0x7D]);
    });

    test('cmdLow has correct bytes', () {
      expect(LvsCommands.cmdLow, [0xE4, 0x9C, 0x6C]);
    });

    test('cmdMed has correct bytes', () {
      expect(LvsCommands.cmdMed, [0xE7, 0x07, 0x5E]);
    });

    test('cmdHigh has correct bytes', () {
      expect(LvsCommands.cmdHigh, [0xE6, 0x8E, 0x4F]);
    });

    test('handshake commands have correct bytes', () {
      expect(LvsCommands.handshakePing, [0x01, 0x01, 0x01]);
      expect(LvsCommands.handshakePong, [0x02, 0x02, 0x02]);
      expect(LvsCommands.handshakeFinal, [0x00, 0x00, 0x00]);
    });

    test('prefix is 8 bytes long', () {
      expect(LvsCommands.prefix.length, 8);
      expect(LvsCommands.prefix.first, 0x6D);
      expect(LvsCommands.prefix.last, 0x7C);
    });

    test('companyId is 0xFFF0', () {
      expect(LvsCommands.companyId, 0xFFF0);
    });

    test('serviceUuid is correct', () {
      expect(LvsCommands.serviceUuid, '0000fff0-0000-1000-8000-00805f9b34fb');
    });
  });

  group('LvsCommands - Speed Level Mapping', () {
    test('commandFor returns correct bytes for stop', () {
      expect(LvsCommands.commandFor(SpeedLevel.stop), LvsCommands.cmdStop);
    });

    test('commandFor returns correct bytes for low', () {
      expect(LvsCommands.commandFor(SpeedLevel.low), LvsCommands.cmdLow);
    });

    test('commandFor returns correct bytes for medium', () {
      expect(LvsCommands.commandFor(SpeedLevel.medium), LvsCommands.cmdMed);
    });

    test('commandFor returns correct bytes for high', () {
      expect(LvsCommands.commandFor(SpeedLevel.high), LvsCommands.cmdHigh);
    });
  });

  group('LvsCommands - Pattern Mapping', () {
    test('patternFor returns correct bytes for all patterns', () {
      expect(LvsCommands.patternFor(LvsPattern.pat1), LvsCommands.pat1);
      expect(LvsCommands.patternFor(LvsPattern.pat2), LvsCommands.pat2);
      expect(LvsCommands.patternFor(LvsPattern.pat3), LvsCommands.pat3);
      expect(LvsCommands.patternFor(LvsPattern.pat4), LvsCommands.pat4);
      expect(LvsCommands.patternFor(LvsPattern.pat5), LvsCommands.pat5);
      expect(LvsCommands.patternFor(LvsPattern.pat6), LvsCommands.pat6);
    });

    test('patternFor returns correct bytes for ch1 patterns', () {
      expect(LvsCommands.patternFor(LvsPattern.ch1Stop), LvsCommands.ch1Stop);
      expect(LvsCommands.patternFor(LvsPattern.ch1Low), LvsCommands.ch1Low);
      expect(LvsCommands.patternFor(LvsPattern.ch1Med), LvsCommands.ch1Med);
      expect(LvsCommands.patternFor(LvsPattern.ch1High), LvsCommands.ch1High);
    });

    test('patternFor returns correct bytes for ch2 patterns', () {
      expect(LvsCommands.patternFor(LvsPattern.ch2Stop), LvsCommands.ch2Stop);
      expect(LvsCommands.patternFor(LvsPattern.ch2Low), LvsCommands.ch2Low);
      expect(LvsCommands.patternFor(LvsPattern.ch2Med), LvsCommands.ch2Med);
      expect(LvsCommands.patternFor(LvsPattern.ch2High), LvsCommands.ch2High);
    });
  });

  group('LvsCommands - Channel Pattern Mappings', () {
    test('ch1PatternFor handles values 1-12 correctly', () {
      expect(LvsCommands.ch1PatternFor(1), LvsCommands.ch1Low);
      expect(LvsCommands.ch1PatternFor(2), LvsCommands.ch1Med);
      expect(LvsCommands.ch1PatternFor(3), LvsCommands.ch1High);
      expect(LvsCommands.ch1PatternFor(4), LvsCommands.ch1Pat1);
      expect(LvsCommands.ch1PatternFor(5), LvsCommands.ch1Pat2);
      expect(LvsCommands.ch1PatternFor(6), LvsCommands.ch1Pat3);
      expect(LvsCommands.ch1PatternFor(7), LvsCommands.ch1Pat4);
      expect(LvsCommands.ch1PatternFor(8), LvsCommands.ch1Pat5);
      expect(LvsCommands.ch1PatternFor(9), LvsCommands.ch1Pat6);
      expect(LvsCommands.ch1PatternFor(10), LvsCommands.ch1Pat7);
      expect(LvsCommands.ch1PatternFor(11), LvsCommands.ch1Pat8);
      expect(LvsCommands.ch1PatternFor(12), LvsCommands.ch1Pat9);
    });

    test('ch1PatternFor returns ch1Stop for unknown value', () {
      expect(LvsCommands.ch1PatternFor(0), LvsCommands.ch1Stop);
      expect(LvsCommands.ch1PatternFor(99), LvsCommands.ch1Stop);
    });

    test('ch2PatternFor handles values 1-12 correctly', () {
      expect(LvsCommands.ch2PatternFor(1), LvsCommands.cmdLow);
      expect(LvsCommands.ch2PatternFor(2), LvsCommands.cmdMed);
      expect(LvsCommands.ch2PatternFor(3), LvsCommands.cmdHigh);
      expect(LvsCommands.ch2PatternFor(4), LvsCommands.ch2Pat1);
      expect(LvsCommands.ch2PatternFor(5), LvsCommands.ch2Pat2);
      expect(LvsCommands.ch2PatternFor(6), LvsCommands.ch2Pat3);
      expect(LvsCommands.ch2PatternFor(7), LvsCommands.ch2Pat4);
      expect(LvsCommands.ch2PatternFor(8), LvsCommands.ch2Pat5);
      expect(LvsCommands.ch2PatternFor(9), LvsCommands.ch2Pat6);
      expect(LvsCommands.ch2PatternFor(10), LvsCommands.ch2Pat7);
      expect(LvsCommands.ch2PatternFor(11), LvsCommands.ch2Pat8);
      expect(LvsCommands.ch2PatternFor(12), LvsCommands.ch2Pat9);
    });

    test('ch2PatternFor returns ch2Stop for unknown value', () {
      expect(LvsCommands.ch2PatternFor(0), LvsCommands.ch2Stop);
      expect(LvsCommands.ch2PatternFor(99), LvsCommands.ch2Stop);
    });
  });

  group('LvsCommands - Proportional Commands', () {
    test('proportional clamps to 0-100 range', () {
      final cmd = LvsCommands.proportional(150);
      expect(cmd[2], 100);
    });

    test('proportional accepts valid range', () {
      final cmd = LvsCommands.proportional(50);
      expect(cmd, [0xE6, 0x8E, 50]);
    });

    test('proportional lower bound is 0', () {
      final cmd = LvsCommands.proportional(-5);
      expect(cmd[2], 0);
    });

    test('proportionalChannel1 clamps correctly', () {
      final cmd = LvsCommands.proportionalChannel1(200);
      expect(cmd[2], 100);
    });

    test('proportionalChannel2 clamps correctly', () => expect(LvsCommands.proportionalChannel2(200)[2], 100));
  });

  group('LvsCommands - Precise Commands', () {
    test('preciseChannel1 clamps to 0-255', () {
      expect(LvsCommands.preciseChannel1(300)[2], 255);
    });

    test('preciseChannel1 accepts 0-255 range', () {
      expect(LvsCommands.preciseChannel1(128), [0xD6, 0x0D, 128]);
    });

    test('preciseChannel2 clamps to 0-255', () {
      expect(LvsCommands.preciseChannel2(300)[2], 255);
    });

    test('preciseChannel2 accepts 0-255 range', () {
      expect(LvsCommands.preciseChannel2(200), [0xA6, 0x8E, 200]);
    });
  });

  group('LvsCommands - Dual Motor Command', () {
    test('dualMotor creates correct 3-byte command', () {
      expect(LvsCommands.dualMotor(100, 200), [0xF6, 100, 200]);
    });

    test('dualMotor clamps both channels', () {
      expect(LvsCommands.dualMotor(-5, 300), [0xF6, 0, 255]);
    });

    test('dualMotor handles zero values', () {
      expect(LvsCommands.dualMotor(0, 0), [0xF6, 0, 0]);
    });
  });

  group('LvsCommands - Packet Building', () {
    test('buildPacket b11 creates 11-byte packet', () {
      final packet = LvsCommands.buildPacket([0x01, 0x02, 0x03], mode: PacketMode.b11);
      expect(packet.length, 11);
      expect(packet.take(8), LvsCommands.prefix);
      expect(packet.sublist(8), [0x01, 0x02, 0x03]);
    });

    test('buildPacket b18 creates 18-byte packet', () {
      final cmd = [0xE6, 0x8E, 0x4F];
      final packet = LvsCommands.buildPacket(cmd, mode: PacketMode.b18);
      expect(packet.length, 18);
      expect(packet.sublist(0, 3), [0xFF, 0xFF, 0x00]);
      expect(packet.sublist(3, 11), LvsCommands.prefix);
      expect(packet.sublist(11, 14), cmd);
      expect(packet.sublist(14, 18), [0x03, 0x03, 0x8F, 0xAE]);
    });

    test('buildPacket defaults to b11 mode', () {
      final packet = LvsCommands.buildPacket([0x00, 0x00, 0x00]);
      expect(packet.length, 11);
    });
  });

  group('LvsCommands - bytesToHex', () {
    test('formats single bytes correctly', () {
      expect(LvsCommands.bytesToHex([0xAB]), 'AB');
    });

    test('formats multiple bytes correctly', () {
      expect(LvsCommands.bytesToHex([0xE5, 0x15, 0x7D]), 'E5 15 7D');
    });

    test('handles empty list', () {
      expect(LvsCommands.bytesToHex([]), '');
    });

    test('pads single digit hex values', () {
      expect(LvsCommands.bytesToHex([0x01, 0x0A]), '01 0A');
    });
  });

  group('LvsCommands - debugPresets', () {
    test('contains correct values for all speed levels', () {
      expect(LvsCommands.debugPresets[SpeedLevel.stop], {'b0': 0xE5, 'b1': 0x15, 'b2': 0x7D});
      expect(LvsCommands.debugPresets[SpeedLevel.low], {'b0': 0xE4, 'b1': 0x9C, 'b2': 0x6C});
      expect(LvsCommands.debugPresets[SpeedLevel.medium], {'b0': 0xE7, 'b1': 0x07, 'b2': 0x5E});
      expect(LvsCommands.debugPresets[SpeedLevel.high], {'b0': 0xE6, 'b1': 0x8E, 'b2': 0x4F});
    });
  });

  group('LvsCommands - parseHexCommand', () {
    test('parses space-separated hex string', () {
      expect(LvsCommands.parseHexCommand('F1 01 01'), [0xF1, 0x01, 0x01]);
    });

    test('parses concatenated hex string', () {
      expect(LvsCommands.parseHexCommand('F10101'), [0xF1, 0x01, 0x01]);
    });

    test('parses 0x-prefixed hex string', () {
      expect(LvsCommands.parseHexCommand('0xF1 0x01 0x01'), [0xF1, 0x01, 0x01]);
    });

    test('parses mixed case hex', () {
      expect(LvsCommands.parseHexCommand('f1 aB Cd'), [0xF1, 0xAB, 0xCD]);
    });

    test('returns null for empty string', () {
      expect(LvsCommands.parseHexCommand(''), isNull);
    });

    test('returns null for invalid hex', () {
      expect(LvsCommands.parseHexCommand('ZZ ZZ'), isNull);
    });
  });

  group('LvsCommands - commandForButton', () {
    test('uses newCommand when available', () {
      final btn = PatternButton(id: 1, name: 'Test', command: 0, stopCommand: 0, newCommand: 'F1 01 01');
      expect(LvsCommands.commandForButton(btn, 1, 0), [0xF1, 0x01, 0x01]);
    });

    test('falls back to positional when newCommand is empty', () {
      final btn = PatternButton(id: 1, name: 'Test', command: 0, stopCommand: 0);
      final cmd = LvsCommands.commandForButton(btn, 1, 0);
      expect(cmd, LvsCommands.ch1PatternFor(4));
    });

    test('falls back to positional when newCommand is invalid', () {
      final btn = PatternButton(id: 1, name: 'Test', command: 0, stopCommand: 0, newCommand: 'ZZZ');
      final cmd = LvsCommands.commandForButton(btn, 2, 0);
      expect(cmd, LvsCommands.ch2PatternFor(4));
    });
  });

  group('LvsCommands - commandForButtonStop', () {
    test('uses stopCommand when > 0', () {
      final btn = PatternButton(id: 1, name: 'Test', command: 0, stopCommand: 0xE5, newCommand: '');
      expect(LvsCommands.commandForButtonStop(btn, 1), [0xE5]);
    });

    test('falls back to channel stop when stopCommand is 0', () {
      final btn = PatternButton(id: 1, name: 'Test', command: 0, stopCommand: 0);
      expect(LvsCommands.commandForButtonStop(btn, 1), LvsCommands.ch1Stop);
      expect(LvsCommands.commandForButtonStop(btn, 2), LvsCommands.ch2Stop);
    });
  });

  group('LvsCommands - encrypt', () {
    test('returns bytes unchanged when encryptCommand is empty', () {
      expect(LvsCommands.encrypt([0xE5, 0x15, 0x7D], ''), [0xE5, 0x15, 0x7D]);
    });

    test('XORs bytes with key cyclically', () {
      final result = LvsCommands.encrypt([0xAA, 0xBB, 0xCC], '12 34');
      expect(result, [0xAA ^ 0x12, 0xBB ^ 0x34, 0xCC ^ 0x12]);
    });

    test('handles key shorter than data', () {
      final result = LvsCommands.encrypt([0x01, 0x02, 0x03, 0x04], 'FF');
      expect(result, [0xFE, 0xFD, 0xFC, 0xFB]);
    });
  });

  group('LvsCommands - parseBroadcastPrefix', () {
    test('returns parsed bytes for valid hex prefix', () {
      expect(LvsCommands.parseBroadcastPrefix('77 62 4d 53 45'), [0x77, 0x62, 0x4D, 0x53, 0x45]);
    });

    test('returns default prefix for empty string', () {
      expect(LvsCommands.parseBroadcastPrefix(''), LvsCommands.prefix);
    });

    test('returns default prefix for invalid string', () {
      expect(LvsCommands.parseBroadcastPrefix('GG HH'), LvsCommands.prefix);
    });
  });

  group('LvsCommands - buildPacket with custom prefix', () {
    test('uses custom prefix when provided', () {
      final customPrefix = [0x77, 0x62, 0x4D, 0x53, 0x45];
      final packet = LvsCommands.buildPacket([0x01, 0x02, 0x03], prefixBytes: customPrefix);
      expect(packet.length, 8); // 5 prefix + 3 cmd
      expect(packet.take(5), customPrefix);
      expect(packet.skip(5), [0x01, 0x02, 0x03]);
    });

    test('uses default prefix when custom is null', () {
      final packet = LvsCommands.buildPacket([0x01, 0x02, 0x03]);
      expect(packet.take(8), LvsCommands.prefix);
    });
  });
}
