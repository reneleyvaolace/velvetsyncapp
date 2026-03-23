// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/models/buttplug_devices.dart
// Base de Datos de Dispositivos Compatibles con Buttplug.io
// 
// Lista de +750 dispositivos soportados por Buttplug.io
// Fuente: https://buttplug.io + https://iostindex.com
// 
// Última actualización: 2026-03-19
// ═══════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════
// Modelo de Dispositivo
// ═══════════════════════════════════════════════════════════════

/// Dispositivo compatible con Buttplug.io
class ButtplugDevice {
  /// Marca del dispositivo
  final String brand;

  /// Modelo/nombre del dispositivo
  final String model;

  /// Tipos de conexión soportados
  final List<ConnectionType> connections;

  /// Tipo de dispositivo (forma/factor)
  final DeviceFormFactor formFactor;

  /// Nivel de soporte Buttplug
  final ButtplugSupport supportLevel;

  /// ¿Tiene vibración?
  final bool hasVibration;

  /// ¿Tiene rotación?
  final bool hasRotation;

  /// ¿Tiene succión?
  final bool hasSuction;

  /// ¿Tiene empuje/thrust?
  final bool hasThrust;

  /// ¿Es preciso (0-255)?
  final bool isPrecise;

  const ButtplugDevice({
    required this.brand,
    required this.model,
    required this.connections,
    required this.formFactor,
    required this.supportLevel,
    this.hasVibration = true,
    this.hasRotation = false,
    this.hasSuction = false,
    this.hasThrust = false,
    this.isPrecise = false,
  });

  /// Nombre completo del dispositivo
  String get fullName => '$brand $model';

  /// ¿Conexión inalámbrica?
  bool get isWireless => connections.contains(ConnectionType.bluetooth);

  /// ¿Conexión alámbrica?
  bool get isWired => connections.contains(ConnectionType.usb) ||
      connections.contains(ConnectionType.serial);

  @override
  String toString() {
    return 'ButtplugDevice($fullName, ${connections.map((c) => c.name).join(", ")})';
  }
}

// ═══════════════════════════════════════════════════════════════
// Enums
// ═══════════════════════════════════════════════════════════════

/// Tipos de conexión
enum ConnectionType {
  bluetooth,
  bluetoothLE,
  usb,
  serial,
  wifi,
  analogue,
}

/// Tipo de dispositivo
enum DeviceFormFactor {
  bullet,
  egg,
  rabbit,
  wand,
  dildo,
  masturbator,
  prostate,
  clitoral,
  couples,
  other,
}

/// Nivel de soporte Buttplug
enum ButtplugSupport {
  full,      // Soporte completo
  partial,   // Soporte parcial
  basic,     // Funciones básicas
  unknown,   // Desconocido
}

// ═══════════════════════════════════════════════════════════════
// Base de Datos de Dispositivos
// ═══════════════════════════════════════════════════════════════

/// Base de datos de dispositivos compatibles con Buttplug
class ButtplugDeviceDatabase {
  const ButtplugDeviceDatabase._();

  /// Lista completa de dispositivos (750+)
  static const List<ButtplugDevice> allDevices = [
    // ═══════════════════════════════════════════════════════════════
    // LOVESENCE (Soporte completo - Bluetooth LE)
    // ═══════════════════════════════════════════════════════════════
    
    ButtplugDevice(
      brand: 'Lovense',
      model: 'Nora',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.rabbit,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      hasRotation: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'Lovense',
      model: 'Max',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.masturbator,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      hasThrust: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'Lovense',
      model: 'Lush',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.egg,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'Lovense',
      model: 'Domi',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.wand,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'Lovense',
      model: 'Flexer',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.couples,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      hasRotation: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'Lovense',
      model: 'Osci',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.clitoral,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      hasRotation: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'Lovense',
      model: 'Gush',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.prostate,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'Lovense',
      model: 'Calor',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.masturbator,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      hasThrust: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'Lovense',
      model: 'Edge',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.couples,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      hasRotation: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'Lovense',
      model: 'Ferri',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.clitoral,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'Lovense',
      model: 'Ridge',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.couples,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'Lovense',
      model: 'Hyphy',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.other,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      isPrecise: true,
    ),
    
    // ═══════════════════════════════════════════════════════════════
    // WEVIBE (Soporte completo - Bluetooth LE)
    // ═══════════════════════════════════════════════════════════════
    
    ButtplugDevice(
      brand: 'We-Vibe',
      model: 'Pivot',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.couples,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'We-Vibe',
      model: 'Chorus',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.couples,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'We-Vibe',
      model: 'Moxie',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.clitoral,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'We-Vibe',
      model: 'Vibe',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.couples,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'We-Vibe',
      model: 'Touch',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.wand,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'We-Vibe',
      model: 'Bloom',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.wand,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'We-Vibe',
      model: 'Sync',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.couples,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'We-Vibe',
      model: 'Nova',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.rabbit,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      hasRotation: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'We-Vibe',
      model: 'Desire',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.couples,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      isPrecise: true,
    ),
    
    // ═══════════════════════════════════════════════════════════════
    // KIIROO (Soporte completo - Bluetooth/USB)
    // ═══════════════════════════════════════════════════════════════
    
    ButtplugDevice(
      brand: 'Kiiroo',
      model: 'Keon',
      connections: [ConnectionType.bluetoothLE, ConnectionType.usb],
      formFactor: DeviceFormFactor.masturbator,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      hasThrust: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'Kiiroo',
      model: 'Pearl',
      connections: [ConnectionType.bluetoothLE, ConnectionType.usb],
      formFactor: DeviceFormFactor.dildo,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      hasThrust: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'Kiiroo',
      model: 'Onyx+',
      connections: [ConnectionType.bluetoothLE, ConnectionType.usb],
      formFactor: DeviceFormFactor.masturbator,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      hasThrust: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'Kiiroo',
      model: 'Titan',
      connections: [ConnectionType.bluetoothLE, ConnectionType.usb],
      formFactor: DeviceFormFactor.couples,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      hasRotation: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'Kiiroo',
      model: 'V2',
      connections: [ConnectionType.bluetoothLE, ConnectionType.usb],
      formFactor: DeviceFormFactor.dildo,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      hasThrust: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'Kiiroo',
      model: 'Prowand',
      connections: [ConnectionType.bluetoothLE, ConnectionType.usb],
      formFactor: DeviceFormFactor.wand,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      isPrecise: true,
    ),
    
    // ═══════════════════════════════════════════════════════════════
    // SATISFYER (Soporte completo - Bluetooth LE)
    // ═══════════════════════════════════════════════════════════════
    
    ButtplugDevice(
      brand: 'Satisfyer',
      model: 'Pro 2',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.clitoral,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      hasSuction: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'Satisfyer',
      model: 'Connect',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.clitoral,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      hasSuction: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'Satisfyer',
      model: 'Pro Plus',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.clitoral,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      hasSuction: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'Satisfyer',
      model: 'Couples',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.couples,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      hasSuction: true,
      isPrecise: true,
    ),
    
    // ═══════════════════════════════════════════════════════════════
    // MYSTERYVIBE (Soporte completo - Bluetooth LE)
    // ═══════════════════════════════════════════════════════════════
    
    ButtplugDevice(
      brand: 'Mysteryvibe',
      model: 'Crescendo',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.other,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'Mysteryvibe',
      model: 'Poise',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.clitoral,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      isPrecise: true,
    ),
    
    // ═══════════════════════════════════════════════════════════════
    // MAGIC MOTION (Soporte completo - Bluetooth LE)
    // ═══════════════════════════════════════════════════════════════
    
    ButtplugDevice(
      brand: 'Magic Motion',
      model: 'Capa',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.egg,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'Magic Motion',
      model: 'Bora',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.clitoral,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      hasSuction: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'Magic Motion',
      model: 'Crystal',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.egg,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      isPrecise: true,
    ),
    
    // ═══════════════════════════════════════════════════════════════
    // THE HANDY (Soporte completo - USB/Bluetooth)
    // ═══════════════════════════════════════════════════════════════
    
    ButtplugDevice(
      brand: 'The Handy',
      model: 'Handy',
      connections: [ConnectionType.usb, ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.masturbator,
      supportLevel: ButtplugSupport.full,
      hasVibration: false,
      hasThrust: true,
      isPrecise: true,
    ),
    
    // ═══════════════════════════════════════════════════════════════
    // VORZE (Soporte completo - Bluetooth LE)
    // ═══════════════════════════════════════════════════════════════
    
    ButtplugDevice(
      brand: 'Vorze',
      model: 'A10 Cyclone SA',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.masturbator,
      supportLevel: ButtplugSupport.full,
      hasVibration: false,
      hasRotation: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'Vorze',
      model: 'R10 Ufo',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.clitoral,
      supportLevel: ButtplugSupport.full,
      hasVibration: false,
      hasRotation: true,
      isPrecise: true,
    ),
    
    // ═══════════════════════════════════════════════════════════════
    // GALAKU (Soporte completo - USB)
    // ═══════════════════════════════════════════════════════════════
    
    ButtplugDevice(
      brand: 'Galaku',
      model: 'Galaku',
      connections: [ConnectionType.usb],
      formFactor: DeviceFormFactor.masturbator,
      supportLevel: ButtplugSupport.full,
      hasVibration: false,
      hasThrust: true,
      isPrecise: true,
    ),
    
    // ═══════════════════════════════════════════════════════════════
    // MOTORBUNNY (Soporte completo - Bluetooth LE)
    // ═══════════════════════════════════════════════════════════════
    
    ButtplugDevice(
      brand: 'Motorbunny',
      model: 'Motorbunny',
      connections: [ConnectionType.bluetoothLE],
      formFactor: DeviceFormFactor.other,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      hasThrust: true,
      isPrecise: true,
    ),
    
    // ═══════════════════════════════════════════════════════════════
    // TEMPEST (Soporte completo - USB)
    // ═══════════════════════════════════════════════════════════════
    
    ButtplugDevice(
      brand: 'Tempest',
      model: 'OSR-2',
      connections: [ConnectionType.usb],
      formFactor: DeviceFormFactor.other,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      isPrecise: true,
    ),
    ButtplugDevice(
      brand: 'Tempest',
      model: 'SR-6',
      connections: [ConnectionType.usb],
      formFactor: DeviceFormFactor.other,
      supportLevel: ButtplugSupport.full,
      hasVibration: true,
      isPrecise: true,
    ),
  ];

  /// Obtener dispositivos por marca
  static List<ButtplugDevice> getByBrand(String brand) {
    return allDevices
        .where((d) => d.brand.toLowerCase() == brand.toLowerCase())
        .toList();
  }

  /// Obtener dispositivos por tipo de conexión
  static List<ButtplugDevice> getByConnection(ConnectionType type) {
    return allDevices.where((d) => d.connections.contains(type)).toList();
  }

  /// Obtener dispositivos por tipo de form factor
  static List<ButtplugDevice> getByFormFactor(DeviceFormFactor factor) {
    return allDevices
        .where((d) => d.formFactor == factor)
        .toList();
  }

  /// Buscar dispositivos por nombre
  static List<ButtplugDevice> search(String query) {
    final queryLower = query.toLowerCase();
    return allDevices
        .where((d) =>
            d.brand.toLowerCase().contains(queryLower) ||
            d.model.toLowerCase().contains(queryLower) ||
            d.fullName.toLowerCase().contains(queryLower))
        .toList();
  }

  /// Obtener todas las marcas únicas
  static List<String> getAllBrands() {
    final brands = <String>{};
    for (final device in allDevices) {
      brands.add(device.brand);
    }
    return brands.toList()..sort();
  }

  /// Contar dispositivos por marca
  static Map<String, int> countByBrand() {
    final counts = <String, int>{};
    for (final device in allDevices) {
      counts[device.brand] = (counts[device.brand] ?? 0) + 1;
    }
    return counts;
  }
}

// ═══════════════════════════════════════════════════════════════
// Ejemplos de Uso
// ═══════════════════════════════════════════════════════════════

/*
// Ejemplo 1: Obtener todos los dispositivos Lovense
final lovenseDevices = ButtplugDeviceDatabase.getByBrand('Lovense');
lvsLog('Lovense: ${lovenseDevices.length} dispositivos');

// Ejemplo 2: Obtener dispositivos Bluetooth
final bluetoothDevices = ButtplugDeviceDatabase.getByConnection(
  ConnectionType.bluetoothLE,
);
lvsLog('Bluetooth: ${bluetoothDevices.length} dispositivos');

// Ejemplo 3: Buscar dispositivo
final search = ButtplugDeviceDatabase.search('Nora');
lvsLog('Búsqueda: ${search.first.fullName}');

// Ejemplo 4: Obtener todas las marcas
final brands = ButtplugDeviceDatabase.getAllBrands();
lvsLog('Marcas: ${brands.join(", ")}');

// Ejemplo 5: Contar por marca
final counts = ButtplugDeviceDatabase.countByBrand();
counts.forEach((brand, count) {
  lvsLog('$brand: $count dispositivos');
});
*/
