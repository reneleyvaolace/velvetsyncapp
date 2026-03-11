// ═══════════════════════════════════════════════════════════════
// LVS Control · lib/ble/toy_profile.dart · v3.0.0
// Perfil del dispositivo — auto-vínculo con pre-registrados
// ═══════════════════════════════════════════════════════════════

import '../models/toy_model.dart';

class ToyProfile {
  final String name;        // Nombre amigable (puede ser el del catálogo o BLE)
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
    // Si el nombre sugiere una familia específica, lo marcamos como Dual Channel si aplica,
    // pero respetamos el nombre y el ID real detectado.
    final bool isDual = deviceName.contains('8154') ||
        deviceName.startsWith('wbMSE') ||
        deviceName.toLowerCase().contains('knight');

    return ToyProfile(
      name: deviceName.isNotEmpty ? deviceName : 'Dispositivo LVS',
      identifier: deviceName, // Usar el nombre/ID real como identificador
      hasDualChannel: isDual,
    );
  }

  /// Busca en el catálogo (incluyendo pre-registrados) por coincidencia de nombre/ID/prefix.
  /// Prioridad de matching:
  ///   1. ID exacto dentro del nombre BLE
  ///   2. Nombre BLE dentro del nombre del dispositivo del catálogo
  ///   3. BroadcastPrefix (para detectar por advertising sin nombre)
  ///   4. Nombre del catálogo == nombre BLE (insensible a mayúsculas)
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

      // 2. Nombre BLE dentro del nombre del toy (ej: "wbMSE8154" → "Knight No. 3")
      if (toy.name.isNotEmpty &&
          deviceName.toLowerCase().contains(toy.name.toLowerCase())) {
        return ToyProfile(
          name: toy.name,
          identifier: toy.id,
          hasDualChannel: toy.hasDualChannel,
        );
      }

      // 3. BroadcastPrefix (útil para detectar por advertising data)
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
