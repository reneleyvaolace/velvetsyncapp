// ═══════════════════════════════════════════════════════════════
// Velvet Sync · test/services/ble/ble_service_protocol_test.dart
// Tests: ProtocolTranslator integration in BleService
// ═══════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:velvet_sync/devices/models/toy_model.dart';
import 'package:velvet_sync/services/ble/ble_service_mobile.dart';
import 'package:velvet_sync/services/ble/lvs_commands.dart';
import 'package:velvet_sync/utils/protocol_translator.dart';

void main() {
  group('BleService - ProtocolTranslator Integration', () {
    late BleService service;

    setUp(() {
      service = BleService();
    });

    group('buildIntensityCommand', () {
      test('uses ProtocolTranslator when activeToy is set', () {
        final toy = ToyModel(
          id: 'TEST-001',
          name: 'Test Toy',
          usageType: 'Ambos',
          targetAnatomy: 'Múltiple',
          stimulationType: 'Vibración',
          motorLogic: 'Single',
          imageUrl: '',
          qrCodeUrl: '',
          supportedFuncs: '',
          isPrecise: false,
          broadcastPrefix: '6D B6 43 CE 97 FE 42 7C',
        );
        service.activeToy = toy;

        final result = service.buildIntensityCommand(50);

        final expected = ProtocolTranslator.translate(
          toy: toy,
          intensity: 50,
          channel: null,
        ).bytes;
        expect(result, equals(expected));
      });

      test('uses ProtocolTranslator precise format for precise toy', () {
        final toy = ToyModel(
          id: 'TEST-002',
          name: 'Precise Toy',
          usageType: 'Ambos',
          targetAnatomy: 'Múltiple',
          stimulationType: 'Vibración',
          motorLogic: 'Single',
          imageUrl: '',
          qrCodeUrl: '',
          supportedFuncs: '',
          isPrecise: true,
          broadcastPrefix: '',
        );
        service.activeToy = toy;

        final result = service.buildIntensityCommand(200);

        final expected = ProtocolTranslator.translate(
          toy: toy,
          intensity: 200,
          channel: null,
        ).bytes;
        expect(result, equals(expected));
      });

      test('uses ProtocolTranslator dual channel format for dual motor toy', () {
        final toy = ToyModel(
          id: 'TEST-003',
          name: 'Dual Toy',
          usageType: 'Ambos',
          targetAnatomy: 'Múltiple',
          stimulationType: 'Vibración',
          motorLogic: 'Dual (Canal A y B)',
          imageUrl: '',
          qrCodeUrl: '',
          supportedFuncs: '',
          isPrecise: false,
          broadcastPrefix: '77 62 4d 53 45',
        );
        service.activeToy = toy;

        final result = service.buildIntensityCommand(50);

        final expected = ProtocolTranslator.translate(
          toy: toy,
          intensity: 50,
          channel: null,
        ).bytes;
        expect(result, equals(expected));
      });

      test('falls back to LvsCommands.proportional when activeToy is null', () {
        final result = service.buildIntensityCommand(75);

        expect(result, equals(LvsCommands.proportional(75)));
      });

      test('falls back to LvsCommands.proportional when activeToy is set then cleared', () {
        final toy = ToyModel(
          id: 'TEST-001',
          name: 'Test Toy',
          usageType: 'Ambos',
          targetAnatomy: 'Múltiple',
          stimulationType: 'Vibración',
          motorLogic: 'Single',
          imageUrl: '',
          qrCodeUrl: '',
          supportedFuncs: '',
          isPrecise: false,
          broadcastPrefix: '',
        );
        service.activeToy = toy;
        service.buildIntensityCommand(50);

        service.activeToy = null;

        final result = service.buildIntensityCommand(50);
        expect(result, equals(LvsCommands.proportional(50)));
      });
    });

    group('buildChannel1Command', () {
      test('uses ProtocolTranslator with channel 1 when activeToy is set', () {
        final toy = ToyModel(
          id: 'TEST-CH1',
          name: 'CH1 Toy',
          usageType: 'Ambos',
          targetAnatomy: 'Múltiple',
          stimulationType: 'Vibración',
          motorLogic: 'Single',
          imageUrl: '',
          qrCodeUrl: '',
          supportedFuncs: '',
          isPrecise: false,
          broadcastPrefix: '6D B6 43 CE 97 FE 42 7C',
        );
        service.activeToy = toy;

        final result = service.buildChannel1Command(60);

        final expected = ProtocolTranslator.translate(
          toy: toy,
          intensity: 60,
          channel: 1,
        ).bytes;
        expect(result, equals(expected));
      });

      test('falls back to LvsCommands.proportionalChannel1 when activeToy is null', () {
        final result = service.buildChannel1Command(60);

        expect(result, equals(LvsCommands.proportionalChannel1(60)));
      });
    });

    group('buildChannel2Command', () {
      test('uses ProtocolTranslator with channel 2 when activeToy is set', () {
        final toy = ToyModel(
          id: 'TEST-CH2',
          name: 'CH2 Toy',
          usageType: 'Ambos',
          targetAnatomy: 'Múltiple',
          stimulationType: 'Vibración',
          motorLogic: 'Single',
          imageUrl: '',
          qrCodeUrl: '',
          supportedFuncs: '',
          isPrecise: false,
          broadcastPrefix: '6D B6 43 CE 97 FE 42 7C',
        );
        service.activeToy = toy;

        final result = service.buildChannel2Command(40);

        final expected = ProtocolTranslator.translate(
          toy: toy,
          intensity: 40,
          channel: 2,
        ).bytes;
        expect(result, equals(expected));
      });

      test('falls back to LvsCommands.proportionalChannel2 when activeToy is null', () {
        final result = service.buildChannel2Command(40);

        expect(result, equals(LvsCommands.proportionalChannel2(40)));
      });
    });

    group('Integration with ProtocolTranslator auto-detection', () {
      test('wbMSE toy returns 3-byte command format', () {
        final toy = ToyModel(
          id: '8154',
          name: 'wbMSE Toy',
          usageType: 'Ambos',
          targetAnatomy: 'Múltiple',
          stimulationType: 'Vibración',
          motorLogic: 'Single',
          imageUrl: '',
          qrCodeUrl: '',
          supportedFuncs: '',
          isPrecise: false,
          broadcastPrefix: '77 62 4d 53 45',
        );
        service.activeToy = toy;

        final result = service.buildIntensityCommand(50);

        expect(result.length, equals(3));
        expect(result[1], equals(128)); // 50/100 * 255 = 127.5 → round → 128
      });

      test('precise toy returns 1-byte command format', () {
        final toy = ToyModel(
          id: 'PRECISE',
          name: 'Precise',
          usageType: 'Ambos',
          targetAnatomy: 'Múltiple',
          stimulationType: 'Vibración',
          motorLogic: 'Single',
          imageUrl: '',
          qrCodeUrl: '',
          supportedFuncs: '',
          isPrecise: true,
          broadcastPrefix: '',
        );
        service.activeToy = toy;

        final result = service.buildIntensityCommand(200);

        expect(result.length, equals(1));
        expect(result[0], equals(200));
      });

      test('dual motor toy with wbMSE prefix returns 6-byte format', () {
        final toy = ToyModel(
          id: '8154-DUAL',
          name: 'Dual wbMSE',
          usageType: 'Ambos',
          targetAnatomy: 'Múltiple',
          stimulationType: 'Vibración',
          motorLogic: 'Dual (Canal A y B)',
          imageUrl: '',
          qrCodeUrl: '',
          supportedFuncs: '',
          isPrecise: false,
          broadcastPrefix: '77 62 4d 53 45',
        );
        service.activeToy = toy;

        final result = service.buildIntensityCommand(50);

        expect(result.length, equals(6));
        expect(result[1], equals(128)); // 50/100 * 255 = 127.5 → round → 128
        expect(result[4], equals(128));
      });
    });
  });
}
