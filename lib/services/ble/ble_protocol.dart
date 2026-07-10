import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:velvet_sync/devices/models/toy_model.dart';

/// UUIDs GATT para cada protocolo BLE
class BleUuids {
  // Classic (directo)
  static const String classicService = '0000aaa0-0000-1000-8000-00805f9b34fb';
  static const String classicWrite = '0000aaa1-0000-1000-8000-00805f9b34fb';
  static const String classicWriteExtended = '0000aaa3-0000-1000-8000-00805f9b34fb';

  // IPAO
  static const String ipaoService = '00008ac0-0000-1000-8000-00805f9b34fb';
  static const String ipaoWrite = '00008ac1-0000-1000-8000-00805f9b34fb';

  // CryptBle
  static const String cryptService = '0000f6c0-0000-1000-8000-00805f9b34fb';
  static const String cryptWrite = '0000f6c2-0000-1000-8000-00805f9b34fb';

  // Advertising (private protocol legacy)
  static const String advService = '0000fff0-0000-1000-8000-00805f9b34fb';
}

/// Obtiene el UUID de escritura según el tipo de protocolo
String writeUuidFor(BleProtocolType type) {
  switch (type) {
    case BleProtocolType.ipao:
      return BleUuids.ipaoWrite;
    case BleProtocolType.cryptBle:
      return BleUuids.cryptWrite;
    case BleProtocolType.classic:
      return BleUuids.classicWrite;
  }
}

/// Escribe un comando BLE al dispositivo por el UUID correcto.
Future<bool> writeBleCommand({
  required BluetoothDevice device,
  required List<int> command,
  required BleProtocolType protocol,
  String? overrideUuid,
}) async {
  try {
    final services = await device.discoverServices();
    final targetUuid = overrideUuid ?? writeUuidFor(protocol);

    for (final s in services) {
      final sUuid = s.uuid.toString().toLowerCase();
      final matchService = sUuid.contains(targetUuid.substring(0, 8));

      if (!matchService) continue;

      for (final c in s.characteristics) {
        final cUuid = c.uuid.toString().toLowerCase();
        if (cUuid == targetUuid.toLowerCase() &&
            (c.properties.write || c.properties.writeWithoutResponse)) {
          await c.write(command, withoutResponse: !c.properties.write);
          return true;
        }
      }
    }
    return false;
  } catch (e) {
    return false;
  }
}

/// Escribe un comando a todos los dispositivos conectados que tengan el UUID
Future<bool> writeToAllDevices({
  required List<BluetoothDevice> devices,
  required List<int> command,
  required BleProtocolType protocol,
  String? overrideUuid,
}) async {
  for (final dev in devices) {
    final ok = await writeBleCommand(
      device: dev,
      command: command,
      protocol: protocol,
      overrideUuid: overrideUuid,
    );
    if (ok) return true;
  }
  return false;
}

/// Detecta el protocolo BLE desde un ToyModel.
/// Usa el campo explícito si está definido, o infiere por heurística.
BleProtocolType detectBleProtocol(ToyModel toy) {
  if (toy.bleProtocol != BleProtocolType.classic) {
    return toy.bleProtocol;
  }

  if (toy.encryptCommand.isNotEmpty) {
    return BleProtocolType.cryptBle;
  }

  final id = toy.id.toLowerCase();
  final name = toy.name.toLowerCase();

  if (id.contains('omysky') || name.contains('omysky') || name.contains('ipao')) {
    return BleProtocolType.ipao;
  }

  return BleProtocolType.classic;
}
