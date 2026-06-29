import 'package:flutter_test/flutter_test.dart';
import 'package:velvet_sync/services/ble/toy_profile.dart';
import 'package:velvet_sync/devices/models/toy_model.dart';

void main() {
  group('ToyProfile - fromName', () {
    test('detects dual channel from 8154 name', () {
      final profile = ToyProfile.fromName('wbMSE-8154');
      expect(profile.hasDualChannel, true);
    });

    test('detects dual channel from wbMSE prefix', () {
      final profile = ToyProfile.fromName('wbMSE-Knight');
      expect(profile.hasDualChannel, true);
    });

    test('detects dual channel from knight name', () {
      final profile = ToyProfile.fromName('Knight Device');
      expect(profile.hasDualChannel, true);
    });

    test('returns single channel for unknown name', () {
      final profile = ToyProfile.fromName('Generic-Device');
      expect(profile.hasDualChannel, false);
    });

    test('falls back to placeholder for empty name', () {
      final profile = ToyProfile.fromName('');
      expect(profile.name, 'Dispositivo LVS');
    });
  });

  group('ToyProfile - fromCatalog', () {
    final catalog = [
      ToyModel(
        id: '8154', name: 'Knight No. 3',
        usageType: 'Insertable', targetAnatomy: 'Vaginal',
        stimulationType: 'Vibración', motorLogic: 'Dual Channel',
        imageUrl: '', qrCodeUrl: '', supportedFuncs: '',
        isPrecise: false, broadcastPrefix: '77 62 4d 53 45',
      ),
      ToyModel(
        id: '8039', name: 'Luna Classic',
        usageType: 'Wearable', targetAnatomy: 'Clitoral',
        stimulationType: 'Pulse', motorLogic: 'Single Channel',
        imageUrl: '', qrCodeUrl: '', supportedFuncs: '',
        isPrecise: false, broadcastPrefix: '77 62 4d 53 45',
      ),
    ];

    test('matches device by ID in BLE name', () {
      final profile = ToyProfile.fromCatalog('My-8154-Device', catalog);
      expect(profile, isNotNull);
      expect(profile!.identifier, '8154');
      expect(profile.name, 'Knight No. 3');
      expect(profile.hasDualChannel, true);
    });

    test('matches device by name substring', () {
      final profile = ToyProfile.fromCatalog('Knight No. 3', catalog);
      expect(profile, isNotNull);
      expect(profile!.name, 'Knight No. 3');
    });

    test('matches device by exact name', () {
      final profile = ToyProfile.fromCatalog('Luna Classic', catalog);
      expect(profile, isNotNull);
      expect(profile!.name, 'Luna Classic');
      expect(profile.hasDualChannel, false);
    });

    test('matches by manufacturer data prefix', () {
      final profile = ToyProfile.fromCatalog(
        'Unknown-Device', catalog,
        manufacturerData: '77 62 4d 53 45 extra',
      );
      expect(profile, isNotNull);
      expect(profile!.name, 'Knight No. 3');
    });

    test('returns null when no match', () {
      final profile = ToyProfile.fromCatalog('Unrelated-Device', catalog);
      expect(profile, isNull);
    });

    test('returns null when name and manufacturer data are empty', () {
      final profile = ToyProfile.fromCatalog('', catalog);
      expect(profile, isNull);
    });
  });
}
