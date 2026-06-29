import 'package:flutter_test/flutter_test.dart';
import 'package:velvet_sync/types/device_types.dart';

void main() {
  group('DeviceType - displayName', () {
    test('returns correct Spanish names', () {
      expect(DeviceType.vibrator.displayName, 'Vibrador');
      expect(DeviceType.egg.displayName, 'Huevo');
      expect(DeviceType.bullet.displayName, 'Bala');
      expect(DeviceType.ring.displayName, 'Anillo');
      expect(DeviceType.clitoral.displayName, 'Estimulador Clitoriano');
      expect(DeviceType.prostate.displayName, 'Estimulador de Próstata');
      expect(DeviceType.anal.displayName, 'Estimulador Anal');
      expect(DeviceType.penis.displayName, 'Estimulador Peneano');
      expect(DeviceType.kegel.displayName, 'Multifunción');
      expect(DeviceType.unknown.displayName, 'Desconocido');
    });
  });

  group('DeviceType - iconAsset', () {
    test('returns correct asset paths', () {
      expect(DeviceType.vibrator.iconAsset, 'assets/icons/icon_vibrator.png');
      expect(DeviceType.egg.iconAsset, 'assets/icons_icon_egg.png');
      expect(DeviceType.bullet.iconAsset, 'assets/icons/icon_bullet.png');
    });
  });

  group('DeviceFeature - displayName', () {
    test('returns correct Spanish names', () {
      expect(DeviceFeature.vibrate.displayName, 'Vibración');
      expect(DeviceFeature.rotate.displayName, 'Rotación');
      expect(DeviceFeature.thrust.displayName, 'Embestida');
      expect(DeviceFeature.suction.displayName, 'Succión');
      expect(DeviceFeature.heat.displayName, 'Calentamiento');
    });
  });

  group('ConnectionStatus', () {
    test('has all required values', () {
      expect(ConnectionStatus.values, hasLength(5));
      expect(ConnectionStatus.values, containsAll([
        ConnectionStatus.disconnected,
        ConnectionStatus.connecting,
        ConnectionStatus.connected,
        ConnectionStatus.disconnecting,
        ConnectionStatus.error,
      ]));
    });
  });

  group('DeviceStatus', () {
    test('has all required values', () {
      expect(DeviceStatus.values, hasLength(5));
    });
  });

  group('ConnectionType', () {
    test('has virtual type', () {
      expect(ConnectionType.virtual, isA<ConnectionType>());
    });
  });
}
