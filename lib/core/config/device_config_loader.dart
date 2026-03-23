// ═══════════════════════════════════════════════════════════════
// Velvet Sync Platform · lib/core/config/device_config_loader.dart
// Cargador de configuraciones de dispositivos desde JSON/CSV
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/services.dart';
import 'device_config.dart';
import '../types/device_types.dart' show DeviceType, DeviceFeature;
import '../types/result_types.dart';

/// Cargador de configuraciones de dispositivos
/// 
/// Carga configuraciones desde múltiples fuentes:
/// - JSON (formato Buttplug v4)
/// - CSV (formato personalizado LVS)
/// - Memoria (configuraciones en tiempo de ejecución)
class DeviceConfigLoader {
  static final DeviceConfigLoader _instance = DeviceConfigLoader._internal();
  factory DeviceConfigLoader() => _instance;
  DeviceConfigLoader._internal();
  
  /// Configuraciones cargadas
  final Map<String, DeviceConfig> _configs = {};
  
  /// Configuraciones de Buttplug (formato v4)
  // Map<String, dynamic>? _buttplugConfig;
  
  /// Número de configuraciones cargadas
  int get configCount => _configs.length;
  
  /// Obtener todas las configuraciones
  List<DeviceConfig> get allConfigs => _configs.values.toList();
  
  // ═══════════════════════════════════════════════════════════
  // CARGA DESDE JSON
  // ═══════════════════════════════════════════════════════════
  
  /// Cargar configuraciones desde archivo JSON
  /// 
  /// [assetPath] Ruta del asset (ej: 'assets/configs/devices.json')
  /// [merge] Si true, fusiona con configuraciones existentes
  Future<Result<void, String>> loadFromJson(
    String assetPath, {
    bool merge = true,
  }) async {
    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      
      if (!_isButtplugFormat(jsonData)) {
        // Formato personalizado
        return _loadCustomJson(jsonData, merge: merge);
      } else {
        // Formato Buttplug v4
        return _loadButtplugJson(jsonData, merge: merge);
      }
    } catch (e) {
      return Failure('Error cargando JSON: $e');
    }
  }
  
  /// Verificar si es formato Buttplug v4
  bool _isButtplugFormat(Map<String, dynamic> data) {
    return data.containsKey('version') && 
           data.containsKey('user_configs');
  }
  
  /// Cargar formato Buttplug v4
  Result<void, String> _loadButtplugJson(
    Map<String, dynamic> data, {
    bool merge = true,
  }) {
    try {
      // _buttplugConfig = data;
      
      if (!merge) {
        _configs.clear();
      }
      
      final userConfigs = data['user_configs'] as Map<String, dynamic>?;
      if (userConfigs == null) return const Success(null);
      
      final devices = userConfigs['devices'] as List? ?? [];
      
      for (final deviceData in devices) {
        final config = _parseButtplugDevice(deviceData as Map<String, dynamic>);
        if (config != null) {
          _configs[config.id] = config;
        }
      }
      
      return const Success(null);
    } catch (e) {
      return Failure('Error parseando Buttplug JSON: $e');
    }
  }
  
  /// Parsear dispositivo de formato Buttplug
  DeviceConfig? _parseButtplugDevice(Map<String, dynamic> data) {
    try {
      final identifier = data['identifier'] as Map<String, dynamic>?;
      final config = data['config'] as Map<String, dynamic>?;
      
      if (identifier == null || config == null) return null;
      
      final protocol = identifier['protocol'] as String? ?? 'unknown';
      final deviceIdentifier = identifier['identifier'] as String? ?? '';
      final address = identifier['address'] as String?;
      
      final features = <DeviceFeature>[];
      final configFeatures = config['features'] as List? ?? [];
      
      for (final feature in configFeatures) {
        final baseId = feature['base_id'] as String?;
        if (baseId != null) {
          features.add(_parseFeature(baseId));
        }
      }
      
      return DeviceConfig(
        id: config['id'] as String? ?? _generateId(),
        baseId: config['base_id'] as String? ?? 'unknown',
        name: deviceIdentifier,
        displayName: deviceIdentifier,
        deviceType: DeviceType.unknown,
        protocol: protocol,
        identifier: deviceIdentifier,
        address: address,
        features: features.isNotEmpty ? features : [DeviceFeature.vibrate],
        protocolConfig: {},
        allow: config['user_config']?['allow'] as bool? ?? true,
        deny: config['user_config']?['deny'] as bool? ?? false,
        index: config['user_config']?['index'] as int? ?? 0,
      );
    } catch (e) {
      return null;
    }
  }
  
  /// Cargar formato JSON personalizado
  Result<void, String> _loadCustomJson(
    Map<String, dynamic> data, {
    bool merge = true,
  }) {
    try {
      if (!merge) {
        _configs.clear();
      }
      
      final devices = data['devices'] as List? ?? [];
      
      for (final deviceData in devices) {
        final config = DeviceConfig.fromJson(deviceData as Map<String, dynamic>);
        _configs[config.id] = config;
      }
      
      return const Success(null);
    } catch (e) {
      return Failure('Error parseando JSON personalizado: $e');
    }
  }
  
  // ═══════════════════════════════════════════════════════════
  // CARGA DESDE CSV
  // ═══════════════════════════════════════════════════════════
  
  /// Cargar configuraciones desde archivo CSV
  /// 
  /// [assetPath] Ruta del asset (ej: 'assets/configs/devices.csv')
  /// [merge] Si true, fusiona con configuraciones existentes
  Future<Result<void, String>> loadFromCsv(
    String assetPath, {
    bool merge = true,
  }) async {
    try {
      final csvString = await rootBundle.loadString(assetPath);
      return _parseCsv(csvString, merge: merge);
    } catch (e) {
      return Failure('Error cargando CSV: $e');
    }
  }
  
  /// Parsear CSV
  Result<void, String> _parseCsv(
    String csv, {
    bool merge = true,
  }) {
    try {
      if (!merge) {
        _configs.clear();
      }
      
      final lines = csv.split('\n');
      if (lines.isEmpty) return const Success(null);
      
      // Parsear header
      final headers = lines.first.split(',').map((h) => h.trim()).toList();
      
      // Parsear filas
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        
        final values = _parseCsvLine(line);
        if (values.length != headers.length) continue;
        
        final row = <String, String>{};
        for (var j = 0; j < headers.length; j++) {
          row[headers[j]] = values[j];
        }
        
        final config = _parseCsvRow(row);
        if (config != null) {
          _configs[config.id] = config;
        }
      }
      
      return const Success(null);
    } catch (e) {
      return Failure('Error parseando CSV: $e');
    }
  }
  
  /// Parsear línea CSV
  List<String> _parseCsvLine(String line) {
    final values = <String>[];
    var inQuotes = false;
    final buffer = StringBuffer();
    
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        values.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    
    values.add(buffer.toString().trim());
    return values;
  }
  
  /// Parsear fila CSV a DeviceConfig
  DeviceConfig? _parseCsvRow(Map<String, String> row) {
    try {
      // Formato esperado (LVS):
      // 0:ID, 1:Barcode, 2:Nombre, 3:UsageType, 4:TargetAnatomy, 5:StimulationType,
      // 6:MotorLogic, 7:DB_Id, 8:RealTitle, 9:Pics, 10:CateId, 11:Qrcode,
      // 12:SupportedFuncs, 13:Wireless, 14:FactoryId, 15:IsEncrypt,
      // 16:IsPrecise, 17:BroadcastPrefix, 18:BleName
      
      final id = row['ID'] ?? row['id'] ?? _generateId();
      final name = row['Nombre'] ?? row['name'] ?? row['BleName'] ?? 'Unknown';
      final identifier = row['BroadcastPrefix'] ?? row['identifier'] ?? '';
      final isPrecise = row['IsPrecise'] == '0-255';
      
      return DeviceConfig(
        id: id,
        baseId: row['CateId'] ?? row['category'] ?? 'lvs',
        name: name,
        displayName: name,
        deviceType: _parseDeviceTypeFromCsv(row),
        protocol: 'LVS',
        identifier: identifier,
        features: [DeviceFeature.vibrate],
        protocolConfig: {
          'isPrecise': isPrecise,
          'motorLogic': row['MotorLogic'] ?? 'Single Channel',
        },
        metadata: {
          'usageType': row['UsageType'] ?? '',
          'targetAnatomy': row['TargetAnatomy'] ?? '',
          'stimulationType': row['StimulationType'] ?? '',
          'imageUrl': row['Pics'] ?? '',
          'qrCodeUrl': row['Qrcode'] ?? '',
        },
      );
    } catch (e) {
      return null;
    }
  }
  
  DeviceType _parseDeviceTypeFromCsv(Map<String, String> row) {
    final anatomy = (row['TargetAnatomy'] ?? '').toLowerCase();
    final stimulation = (row['StimulationType'] ?? '').toLowerCase();
    final motorLogic = (row['MotorLogic'] ?? '').toLowerCase();
    
    if (anatomy.contains('kegel')) return DeviceType.kegel;
    if (anatomy.contains('anal')) return DeviceType.anal;
    if (anatomy.contains('prostat')) return DeviceType.prostate;
    if (anatomy.contains('clitor')) return DeviceType.clitoral;
    if (anatomy.contains('penian') || anatomy.contains('ring')) return DeviceType.ring;
    
    if (stimulation.contains('onda') || stimulation.contains('pulse')) {
      return DeviceType.vibrator;
    }
    if (stimulation.contains('succión')) return DeviceType.suction;
    if (stimulation.contains('empuje')) return DeviceType.thrusting;
    
    if (motorLogic.contains('dual')) return DeviceType.multi;
    
    return DeviceType.vibrator;
  }
  
  // ═══════════════════════════════════════════════════════════
  // BÚSQUEDA Y GESTIÓN
  // ═══════════════════════════════════════════════════════════
  
  /// Obtener configuración para un dispositivo
  DeviceConfig? getConfigForDevice(DeviceIdentifier identifier) {
    // Buscar por address
    for (final config in _configs.values) {
      if (config.address == identifier.address) {
        return config;
      }
    }
    
    // Buscar por nombre/identifier
    for (final config in _configs.values) {
      if (identifier.name.contains(config.identifier) ||
          config.name.toLowerCase().contains(identifier.name.toLowerCase())) {
        return config;
      }
    }
    
    // Buscar por protocolo
    for (final config in _configs.values) {
      if (identifier.protocol == config.protocol) {
        return config;
      }
    }
    
    // No encontrado, retornar default
    return DeviceConfig.defaultConfig();
  }
  
  /// Obtener configuración por ID
  DeviceConfig? getConfigById(String id) {
    return _configs[id];
  }
  
  /// Agregar configuración
  void addConfig(DeviceConfig config) {
    _configs[config.id] = config;
  }
  
  /// Remover configuración
  void removeConfig(String id) {
    _configs.remove(id);
  }
  
  /// Limpiar todas las configuraciones
  void clear() {
    _configs.clear();
    // _buttplugConfig = null;
  }
  
  /// Exportar configuraciones a JSON
  String toJson() {
    final data = {
      'version': {'major': 1, 'minor': 0},
      'devices': _configs.values.map((c) => c.toJson()).toList(),
    };
    return jsonEncode(data);
  }
  
  /// Importar configuraciones desde JSON string
  Result<void, String> fromJsonString(String jsonString) {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      return _loadCustomJson(data, merge: true);
    } catch (e) {
      return Failure('Error parseando JSON: $e');
    }
  }
  
  static DeviceFeature _parseFeature(String name) {
    switch (name.toLowerCase()) {
      case 'vibrate':
        return DeviceFeature.vibrate;
      case 'rotate':
        return DeviceFeature.rotate;
      case 'oscillate':
        return DeviceFeature.oscillate;
      default:
        return DeviceFeature.vibrate;
    }
  }
  
  static String _generateId() {
    return 'config_${DateTime.now().millisecondsSinceEpoch}';
  }
}

