import 'package:flutter_test/flutter_test.dart';
import 'package:velvet_sync/devices/models/toy_model.dart';

ToyModel _createToy({
  String id = '8154',
  String name = 'Knight No. 3',
  String usageType = 'Insertable',
  String targetAnatomy = 'Vaginal',
  String stimulationType = 'Vibración',
  String motorLogic = 'Dual Channel',
  String imageUrl = '',
  String qrCodeUrl = '',
  String supportedFuncs = '',
  bool isPrecise = false,
  String broadcastPrefix = '77 62 4d 53 45',
}) {
  return ToyModel(
    id: id,
    name: name,
    usageType: usageType,
    targetAnatomy: targetAnatomy,
    stimulationType: stimulationType,
    motorLogic: motorLogic,
    imageUrl: imageUrl,
    qrCodeUrl: qrCodeUrl,
    supportedFuncs: supportedFuncs,
    isPrecise: isPrecise,
    broadcastPrefix: broadcastPrefix,
  );
}

void main() {
  group('ToyModel - Constructor', () {
    test('creates instance with all required fields', () {
      final toy = _createToy();
      expect(toy.id, '8154');
      expect(toy.name, 'Knight No. 3');
      expect(toy.usageType, 'Insertable');
      expect(toy.targetAnatomy, 'Vaginal');
      expect(toy.stimulationType, 'Vibración');
      expect(toy.motorLogic, 'Dual Channel');
      expect(toy.isPrecise, false);
    });

    test('hasDualChannel returns true when motorLogic contains "dual"', () {
      final toy = _createToy(motorLogic: 'Dual Channel');
      expect(toy.hasDualChannel, true);
    });

    test('hasDualChannel returns false when motorLogic is single', () {
      final toy = _createToy(motorLogic: 'Single Channel');
      expect(toy.hasDualChannel, false);
    });

    test('hasDualChannel is case insensitive', () {
      final toy = _createToy(motorLogic: 'DUAL MOTOR');
      expect(toy.hasDualChannel, true);
    });
  });

  group('ToyModel - iconAsset', () {
    test('returns kegel icon for kegel anatomy', () {
      final toy = _createToy(targetAnatomy: 'Kegel');
      expect(toy.iconAsset, 'assets/icons/icon_kegel.png');
    });

    test('returns anal icon for anal anatomy', () {
      final toy = _createToy(targetAnatomy: 'Anal');
      expect(toy.iconAsset, 'assets/icons/icon_anal.png');
    });

    test('returns prostate icon for prostate anatomy', () {
      final toy = _createToy(targetAnatomy: 'Prostático');
      expect(toy.iconAsset, 'assets/icons/icon_prostate.png');
    });

    test('returns clitoral icon for clitoral anatomy', () {
      final toy = _createToy(targetAnatomy: 'Clitoral');
      expect(toy.iconAsset, 'assets/icons/icon_clitoral.png');
    });

    test('returns ring icon for ring anatomy', () {
      final toy = _createToy(targetAnatomy: 'Anillo', motorLogic: 'Single');
      expect(toy.iconAsset, 'assets/icons/icon_ring.png');
    });

    test('returns pulse waves for wave stimulation', () {
      final toy = _createToy(stimulationType: 'Pulse Wave', motorLogic: 'Single');
      expect(toy.iconAsset, 'assets/icons/icon_pulse_waves.png');
    });

    test('returns suction icon for suction stimulation', () {
      final toy = _createToy(stimulationType: 'Succión', motorLogic: 'Single');
      expect(toy.iconAsset, 'assets/icons/icon_suction.png');
    });

    test('returns thrust icon for thrust stimulation', () {
      final toy = _createToy(stimulationType: 'Empuje', motorLogic: 'Single');
      expect(toy.iconAsset, 'assets/icons/icon_thrust.png');
    });

    test('returns dual motor for dual channel', () {
      final toy = _createToy(motorLogic: 'Dual Channel', stimulationType: 'Dual');
      expect(toy.iconAsset, 'assets/icons/icon_dual_motor.png');
    });

    test('returns female anatomy for female type', () {
      final toy = _createToy(usageType: 'Female', motorLogic: 'Single');
      expect(toy.iconAsset, 'assets/icons/icon_female_anatomy.png');
    });

    test('returns male anatomy for male type', () {
      final toy = _createToy(usageType: 'Male', motorLogic: 'Single');
      expect(toy.iconAsset, 'assets/icons/icon_male_anatomy.png');
    });

    test('returns egg icon for egg name', () {
      final toy = _createToy(name: 'Egg Vibrator', motorLogic: 'Single');
      expect(toy.iconAsset, 'assets/icons/icon_egg.png');
    });

    test('returns bullet icon for bullet name', () {
      final toy = _createToy(name: 'Bullet Classic', motorLogic: 'Single');
      expect(toy.iconAsset, 'assets/icons/icon_bullet.png');
    });

    test('returns default vibrator icon when no match', () {
      final toy = _createToy(
        name: 'Generic Device',
        targetAnatomy: 'Universal',
        stimulationType: 'Vibración',
        motorLogic: 'Single',
      );
      expect(toy.iconAsset, 'assets/icons/icon_vibrator.png');
    });
  });

  group('ToyModel - fromJson', () {
    test('parses valid JSON correctly', () {
      final json = {
        'id': '123',
        'name': 'Test Toy',
        'usageType': 'Insertable',
        'targetAnatomy': 'Vaginal',
        'stimulationType': 'Vibración',
        'motorLogic': 'Single Channel',
        'imageUrl': 'http://example.com/img.png',
        'qrCodeUrl': 'http://example.com/qr.png',
        'supportedFuncs': 'vibrate',
        'isPrecise': true,
        'broadcastPrefix': '77 62 4d 53 45',
      };

      final toy = ToyModel.fromJson(json);
      expect(toy.id, '123');
      expect(toy.name, 'Test Toy');
      expect(toy.isPrecise, true);
      expect(toy.imageUrl, 'http://example.com/img.png');
    });

    test('handles missing fields with defaults', () {
      final toy = ToyModel.fromJson({});
      expect(toy.id, '');
      expect(toy.name, 'Dispositivo');
      expect(toy.isPrecise, false);
      expect(toy.broadcastPrefix, '77 62 4d 53 45');
    });
  });

  group('ToyModel - toJson', () {
    test('serializes correctly', () {
      final toy = _createToy(id: '999', name: 'Serialize Test', isPrecise: true);
      final json = toy.toJson();

      expect(json['id'], '999');
      expect(json['name'], 'Serialize Test');
      expect(json['isPrecise'], true);
      expect(json['broadcastPrefix'], '77 62 4d 53 45');
      expect(json['usageType'], 'Insertable');
    });
  });

  group('ToyModel - fromSupabase', () {
    test('parses Supabase row correctly', () {
      final row = {
        'id': '8154',
        'factory_model': 'Knight No. 3',
        'usage_type': 'Insertable',
        'target_anatomy': 'Vaginal',
        'stimulation_type': 'Vibración',
        'motor_logic': 'Dual Channel',
        'image_url': 'http://img.url',
        'qr_code_url': 'http://qr.url',
        'supported_funcs': 'vibrate',
        'is_precise_new': true,
        'broadcast_prefix': '77 62 4d 53 45',
      };

      final toy = ToyModel.fromSupabase(row);
      expect(toy.id, '8154');
      expect(toy.name, 'Knight No. 3');
      expect(toy.isPrecise, true);
    });

    test('handles target_anatomy as JSON array string', () {
      final row = {'target_anatomy': '["Anal"]'};
      final toy = ToyModel.fromSupabase(row);
      expect(toy.targetAnatomy, 'Anal');
    });

    test('handles fallback field names', () {
      final row = {
        'model_name': 'Fallback Model',
        'name': 'Generic Name',
      };
      final toy = ToyModel.fromSupabase(row);
      expect(toy.name, 'Fallback Model');
    });

    test('handles is_precise (without _new)', () {
      final row = {'is_precise': true};
      final toy = ToyModel.fromSupabase(row);
      expect(toy.isPrecise, true);
    });
  });

  group('ToyModel - fromCsv', () {
    test('parses CSV row correctly', () {
      final row = [
        '101',           // 0: ID
        '123456789',     // 1: Barcode
        'CSV Toy',       // 2: Name
        'Wearable',      // 3: UsageType
        'Clitoral',      // 4: TargetAnatomy
        'Vibración',     // 5: StimulationType
        'Single',        // 6: MotorLogic
        'db_1',          // 7: DB_Id
        'Real Title',    // 8: RealTitle
        '',              // 9: Pics
        '1',             // 10: CateId
        '',              // 11: Qrcode
        '',              // 12: SupportedFuncs
        'true',          // 13: Wireless
        '1',             // 14: FactoryId
        '0',             // 15: IsEncrypt
        '0-255',         // 16: IsPrecise
        '',              // 17: BroadcastPrefix
        'CSV',           // 18: BleName
      ];

      final toy = ToyModel.fromCsv(row);
      expect(toy.id, '101');
      expect(toy.name, 'CSV Toy');
      expect(toy.usageType, 'Wearable');
      expect(toy.isPrecise, true);
    });

    test('handles minimum row gracefully', () {
      final toy = ToyModel.fromCsv(['99']);
      expect(toy.id, '99');
      expect(toy.name, 'Unknown');
      expect(toy.isPrecise, false);
    });
  });

  group('ToyModel - Equality', () {
    test('identical models are equal', () {
      final a = _createToy(id: '1', name: 'Test');
      final b = _createToy(id: '1', name: 'Test');
      expect(a, equals(b));
    });

    test('different models are not equal', () {
      final a = _createToy(id: '1', name: 'Test');
      final b = _createToy(id: '2', name: 'Test');
      expect(a, isNot(equals(b)));
    });

    test('same reference is equal', () {
      final a = _createToy(id: '1', name: 'Test');
      expect(a, same(a));
    });
  });
}
