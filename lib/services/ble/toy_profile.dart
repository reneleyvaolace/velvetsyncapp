// ═══════════════════════════════════════════════════════════════
// LVS Control · lib/ble/toy_profile.dart · v3.0.0
// Perfil del dispositivo — auto-vínculo con pre-registrados
// ═══════════════════════════════════════════════════════════════

import 'package:velvet_sync/devices/models/toy_model.dart';

class ToyProfile {
  final String name;        // Nombre amigable
  final String identifier;  // ID corto detectado
  final bool hasDualChannel;

  const ToyProfile({
    required this.name,
    required this.identifier,
    this.hasDualChannel = false,
  });

  static const ToyProfile dummy = ToyProfile(name: 'Desconocido', identifier: '???');

  /// Construye el perfil a partir del nombre BLE real del hardware.
  static ToyProfile fromName(String deviceName) {
    final isDual = deviceName.contains('8154') ||
        deviceName.startsWith('wbMSE') ||
        deviceName.toLowerCase().contains('knight');

    return ToyProfile(
      name: deviceName.isNotEmpty ? deviceName : 'Dispositivo LVS',
      identifier: deviceName,
      hasDualChannel: isDual,
    );
  }

  /// Busca en el catálogo (incluyendo pre-registrados) por coincidencia de nombre/ID/prefix.
  static ToyProfile? fromCatalog(String deviceName, List<ToyModel> toys,
      {String? manufacturerData}) {

    if (deviceName.isEmpty && (manufacturerData == null || manufacturerData.isEmpty)) {
      return null;
    }

    for (var toy in toys) {
      // 1. ID dentro del nombre BLE
      if (toy.id.isNotEmpty && deviceName.contains(toy.id)) {
        return ToyProfile(
          name: toy.name,
          identifier: toy.id,
          hasDualChannel: toy.hasDualChannel,
        );
      }

      // 2. Nombre BLE dentro del nombre del toy
      if (toy.name.isNotEmpty &&
          deviceName.toLowerCase().contains(toy.name.toLowerCase())) {
        return ToyProfile(
          name: toy.name,
          identifier: toy.id,
          hasDualChannel: toy.hasDualChannel,
        );
      }

      // 3. BroadcastPrefix
      if (manufacturerData != null &&
          toy.broadcastPrefix.isNotEmpty &&
          manufacturerData
              .toLowerCase()
              .contains(toy.broadcastPrefix.toLowerCase())) {
        return ToyProfile(
          name: toy.name,
          identifier: toy.id,
          hasDualChannel: toy.hasDualChannel,
        );
      }

      // 4. Nombre exacto
      if (toy.name.toLowerCase() == deviceName.toLowerCase()) {
        return ToyProfile(
          name: toy.name,
          identifier: toy.id,
          hasDualChannel: toy.hasDualChannel,
        );
      }
    }
    return null;
  }
}
