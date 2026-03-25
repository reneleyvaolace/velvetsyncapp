// ═══════════════════════════════════════════════════════════════
// Velvet Sync Platform · lib/core/config/device_config.dart
// Configuración de dispositivos
// ═══════════════════════════════════════════════════════════════

import 'package:velvet_sync/types/device_types.dart';


/// Configuración de un dispositivo
/// 
/// Define las características y capacidades de un dispositivo específico
class DeviceConfig {
  /// ID único de la configuración
  final String id;
  
  /// ID base (tipo de dispositivo)
  final String baseId;
  
  /// Nombre del dispositivo
  final String name;
  
  /// Nombre para mostrar
  final String displayName;
  
  /// Tipo de dispositivo
  final DeviceType deviceType;
  
  /// Protocolo que usa
  final String protocol;
  
  /// Identificador del dispositivo (nombre BLE, MAC, etc.)
  final String identifier;
  
  /// Dirección física (MAC address)
  final String? address;
  
  /// Features soportadas
  final List<DeviceFeature> features;
  
  /// Configuración específica del protocolo
  final Map<String, dynamic> protocolConfig;
  
  /// Si está permitido usar este dispositivo
  final bool allow;
  
  /// Si está denegado (prioridad sobre allow)
  final bool deny;
  
  /// Índice de ordenamiento
  final int index;
  
  /// Metadata adicional
  final Map<String, dynamic> metadata;
  
  DeviceConfig({
    required this.id,
    required this.baseId,
    required this.name,
    required this.displayName,
    required this.deviceType,
    required this.protocol,
    required this.identifier,
    this.address,
    required this.features,
    this.protocolConfig = const {},
    this.allow = true,
    this.deny = false,
    this.index = 0,
    this.metadata = const {},
  });
  
  /// Verificar si coincide con un identificador
  bool matches(DeviceIdentifier identifier) {
    // Verificar por address
    if (address != null && identifier.address == address) {
      return true;
    }
    
    // Verificar por nombre/identifier
    if (this.identifier.isNotEmpty && 
        identifier.name.contains(this.identifier)) {
      return true;
    }
    
    // Verificar por protocolo
    if (identifier.protocol.isNotEmpty &&
        identifier.protocol == protocol) {
      return true;
    }
    
    return false;
  }
  
  /// Verificar si soporta una feature
  bool supportsFeature(DeviceFeature feature) {
    return features.contains(feature);
  }
  
  /// Obtener configuración específica
  T? getProtocolConfig<T>(String key, {T? defaultValue}) {
    final value = protocolConfig[key];
    if (value == null) return defaultValue;
    return value as T;
  }
  
  /// Crear configuración por defecto
  factory DeviceConfig.defaultConfig() {
    return DeviceConfig(
      id: 'default',
      baseId: 'default',
      name: 'Unknown',
      displayName: 'Dispositivo Desconocido',
      deviceType: DeviceType.unknown,
      protocol: 'unknown',
      identifier: '',
      features: [DeviceFeature.vibrate],
    );
  }
  
  /// Crear desde mapa JSON
  factory DeviceConfig.fromJson(Map<String, dynamic> json) {
    final features = <DeviceFeature>[];
    final featuresJson = json['features'] as List? ?? [];
    
    for (final feature in featuresJson) {
      final featureName = feature['base_id'] as String? ?? feature as String;
      features.add(_parseFeature(featureName));
    }
    
    return DeviceConfig(
      id: json['id'] as String,
      baseId: json['base_id'] as String,
      name: json['name'] as String? ?? 'Unknown',
      displayName: json['display_name'] as String? ?? json['name'] as String? ?? 'Unknown',
      deviceType: _parseDeviceType(json['device_type'] as String? ?? ''),
      protocol: json['protocol'] as String? ?? 'unknown',
      identifier: json['identifier'] as String? ?? '',
      address: json['address'] as String?,
      features: features.isNotEmpty ? features : [DeviceFeature.vibrate],
      protocolConfig: json['protocol_config'] as Map<String, dynamic>? ?? {},
      allow: json['allow'] as bool? ?? true,
      deny: json['deny'] as bool? ?? false,
      index: json['index'] as int? ?? 0,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }
  
  /// Convertir a mapa JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'base_id': baseId,
      'name': name,
      'display_name': displayName,
      'device_type': deviceType.name,
      'protocol': protocol,
      'identifier': identifier,
      'address': address,
      'features': features.map((f) => f.name).toList(),
      'protocol_config': protocolConfig,
      'allow': allow,
      'deny': deny,
      'index': index,
      'metadata': metadata,
    };
  }
  
  /// Copiar con cambios
  DeviceConfig copyWith({
    String? id,
    String? baseId,
    String? name,
    String? displayName,
    DeviceType? deviceType,
    String? protocol,
    String? identifier,
    String? address,
    List<DeviceFeature>? features,
    Map<String, dynamic>? protocolConfig,
    bool? allow,
    bool? deny,
    int? index,
    Map<String, dynamic>? metadata,
  }) {
    return DeviceConfig(
      id: id ?? this.id,
      baseId: baseId ?? this.baseId,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      deviceType: deviceType ?? this.deviceType,
      protocol: protocol ?? this.protocol,
      identifier: identifier ?? this.identifier,
      address: address ?? this.address,
      features: features ?? this.features,
      protocolConfig: protocolConfig ?? this.protocolConfig,
      allow: allow ?? this.allow,
      deny: deny ?? this.deny,
      index: index ?? this.index,
      metadata: metadata ?? this.metadata,
    );
  }
  
  static DeviceFeature _parseFeature(String name) {
    switch (name.toLowerCase()) {
      case 'vibrate':
        return DeviceFeature.vibrate;
      case 'rotate':
        return DeviceFeature.rotate;
      case 'oscillate':
        return DeviceFeature.oscillate;
      case 'thrust':
        return DeviceFeature.thrust;
      case 'suction':
        return DeviceFeature.suction;
      case 'ems':
        return DeviceFeature.ems;
      case 'battery':
        return DeviceFeature.battery;
      default:
        return DeviceFeature.vibrate;
    }
  }
  
  static DeviceType _parseDeviceType(String name) {
    final nameLower = name.toLowerCase();
    
    if (nameLower.contains('vibrat')) return DeviceType.vibrator;
    if (nameLower.contains('egg')) return DeviceType.egg;
    if (nameLower.contains('bullet')) return DeviceType.bullet;
    if (nameLower.contains('ring')) return DeviceType.ring;
    if (nameLower.contains('clitor')) return DeviceType.clitoral;
    if (nameLower.contains('prostat')) return DeviceType.prostate;
    if (nameLower.contains('anal')) return DeviceType.anal;
    if (nameLower.contains('penis')) return DeviceType.penis;
    if (nameLower.contains('suction')) return DeviceType.suction;
    if (nameLower.contains('lovense')) return DeviceType.multi;
    if (nameLower.contains('wevibe')) return DeviceType.multi;
    if (nameLower.contains('kiiroo')) return DeviceType.multi;
    if (nameLower.contains('lvs') || nameLower.contains('wbmse')) return DeviceType.vibrator;
    
    return DeviceType.unknown;
  }
}

/// Identificador de dispositivo
class DeviceIdentifier {
  /// Nombre del dispositivo (BLE name)
  final String name;
  
  /// Dirección MAC o identificador único
  final String address;
  
  /// Protocolo detectado
  final String protocol;
  
  /// RSSI de la señal
  final int rssi;
  
  DeviceIdentifier({
    required this.name,
    required this.address,
    required this.protocol,
    required this.rssi,
  });
  
  /// Crear desde datos BLE
  factory DeviceIdentifier.fromBle({
    required String name,
    required String address,
    required int rssi,
  }) {
    // Detectar protocolo desde el nombre
    var protocol = 'unknown';
    
    if (name.contains('LVS') || name.contains('wbMSE')) {
      protocol = 'LVS';
    } else if (name.startsWith('LVS-') || name.startsWith('LOVE-')) {
      protocol = 'Lovense';
    } else if (name.startsWith('WeVibe')) {
      protocol = 'WeVibe';
    } else if (name.startsWith('Kiiroo')) {
      protocol = 'Kiiroo';
    } else if (name.startsWith('Satisfyer')) {
      protocol = 'Satisfyer';
    }
    
    return DeviceIdentifier(
      name: name,
      address: address,
      protocol: protocol,
      rssi: rssi,
    );
  }
  
  /// Convertir a mapa JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'protocol': protocol,
      'rssi': rssi,
    };
  }
  
  @override
  String toString() => 'DeviceIdentifier($name [$address] - $protocol)';
}
