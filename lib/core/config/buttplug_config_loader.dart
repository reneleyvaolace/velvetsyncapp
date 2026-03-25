// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/core/config/buttplug_config_loader.dart
// Cargador de Configuración de Dispositivos Buttplug v4
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/services.dart';
import '../../devices/models/toy_model.dart';
import '../../utils/logger.dart';

// ═══════════════════════════════════════════════════════════════
// Modelos de Configuración Buttplug
// ═══════════════════════════════════════════════════════════════

/// Configuración de dispositivo Buttplug v4
class ButtplugDeviceConfig {
  /// Identificador del dispositivo
  final ButtplugIdentifier identifier;

  /// Configuración específica
  final ButtplugConfig config;

  const ButtplugDeviceConfig({
    required this.identifier,
    required this.config,
  });

  factory ButtplugDeviceConfig.fromJson(Map<String, dynamic> json) {
    return ButtplugDeviceConfig(
      identifier: ButtplugIdentifier.fromJson(json['identifier']),
      config: ButtplugConfig.fromJson(json['config']),
    );
  }

  /// Convierte a ToyModel para compatibilidad
  ToyModel toToyModel() {
    return ToyModel(
      id: identifier.address.isNotEmpty ? identifier.address : identifier.identifier,
      name: config.name.isNotEmpty ? config.name : identifier.identifier,
      usageType: 'Universal',
      targetAnatomy: 'Universal',
      stimulationType: config.getStimulationType(),
      motorLogic: config.getMotorLogic(),
      imageUrl: '',
      qrCodeUrl: '',
      supportedFuncs: config.getSupportedFuncs(),
      isPrecise: true,
      broadcastPrefix: 'BUTTPLUG_${identifier.protocol}',
    );
  }
}

/// Identificador de dispositivo Buttplug
class ButtplugIdentifier {
  /// Protocolo del dispositivo (ej: 'lovense', 'wevibe', 'kiiroo')
  final String protocol;

  /// Identificador único (nombre del dispositivo)
  final String identifier;

  /// Dirección MAC o Bluetooth address
  final String address;

  const ButtplugIdentifier({
    required this.protocol,
    required this.identifier,
    this.address = '',
  });

  factory ButtplugIdentifier.fromJson(Map<String, dynamic> json) {
    return ButtplugIdentifier(
      protocol: json['protocol'] ?? '',
      identifier: json['identifier'] ?? '',
      address: json['address'] ?? '',
    );
  }
}

/// Configuración específica de dispositivo
class ButtplugConfig {
  /// ID único de configuración
  final String id;

  /// ID base del tipo de dispositivo
  final String baseId;

  /// Nombre amigable del dispositivo
  final String name;

  /// Lista de features/actuadores
  final List<ButtplugFeature> features;

  /// Configuración de usuario
  final ButtplugUserConfig userConfig;

  const ButtplugConfig({
    required this.id,
    required this.baseId,
    this.name = '',
    this.features = const [],
    this.userConfig = const ButtplugUserConfig(),
  });

  factory ButtplugConfig.fromJson(Map<String, dynamic> json) {
    final featuresJson = json['features'] as List<dynamic>? ?? [];
    final features = featuresJson
        .map((f) => ButtplugFeature.fromJson(f))
        .toList();

    return ButtplugConfig(
      id: json['id'] ?? '',
      baseId: json['base_id'] ?? '',
      name: json['name'] ?? '',
      features: features,
      userConfig: ButtplugUserConfig.fromJson(json['user_config'] ?? {}),
    );
  }

  /// Obtiene el tipo de estimulación basado en features
  String getStimulationType() {
    final types = <String>[];
    
    for (final feature in features) {
      if (feature.hasVibrate) types.add('Vibración');
      if (feature.hasRotate) types.add('Rotación');
      if (feature.hasSuction) types.add('Succión');
      if (feature.hasThrust) types.add('Empuje');
      if (feature.hasOscillate) types.add('Oscilación');
    }
    
    if (types.isEmpty) return 'Vibración';
    
    // Eliminar duplicados
    return types.toSet().join(' + ');
  }

  /// Obtiene la lógica de motores
  String getMotorLogic() {
    final vibrateCount = features.where((f) => f.hasVibrate).length;
    
    if (vibrateCount == 0) return 'Single Channel';
    if (vibrateCount == 1) return 'Single Channel';
    return 'Dual Channel';
  }

  /// Obtiene funciones soportadas
  String getSupportedFuncs() {
    final funcs = <String>{};
    
    for (final feature in features) {
      if (feature.hasVibrate) funcs.add('vibrate');
      if (feature.hasRotate) funcs.add('rotate');
      if (feature.hasSuction) funcs.add('suction');
      if (feature.hasThrust) funcs.add('thrust');
      if (feature.hasOscillate) funcs.add('oscillate');
    }
    
    return funcs.join(',');
  }

  /// Número de actuadores de vibración
  int get vibrateCount {
    return features.where((f) => f.hasVibrate).length;
  }
}

/// Feature/Actuador de dispositivo
class ButtplugFeature {
  /// ID único del feature
  final String id;

  /// ID base del feature
  final String baseId;

  /// Configuración de salida
  final ButtplugOutput output;

  const ButtplugFeature({
    required this.id,
    required this.baseId,
    required this.output,
  });

  factory ButtplugFeature.fromJson(Map<String, dynamic> json) {
    return ButtplugFeature(
      id: json['id'] ?? '',
      baseId: json['base_id'] ?? '',
      output: ButtplugOutput.fromJson(json['output'] ?? {}),
    );
  }

  bool get hasVibrate => baseId.contains('vibrate');
  bool get hasRotate => baseId.contains('rotate') || baseId.contains('oscillate');
  bool get hasSuction => baseId.contains('suction');
  bool get hasThrust => baseId.contains('thrust');
  bool get hasOscillate => baseId.contains('oscillate');
}

/// Configuración de salida de feature
class ButtplugOutput {
  /// Si la vibración está habilitada
  final bool vibrateEnabled;

  /// Si la vibración está deshabilitada
  final bool vibrateDisabled;

  const ButtplugOutput({
    this.vibrateEnabled = false,
    this.vibrateDisabled = false,
  });

  factory ButtplugOutput.fromJson(Map<String, dynamic> json) {
    final vibrate = json['vibrate'] as Map<String, dynamic>?;
    
    return ButtplugOutput(
      vibrateEnabled: vibrate?['disabled'] == false,
      vibrateDisabled: vibrate?['disabled'] == true,
    );
  }
}

/// Configuración de usuario
class ButtplugUserConfig {
  /// Si el dispositivo está permitido
  final bool allow;

  /// Si el dispositivo está denegado
  final bool deny;

  /// Índice de ordenamiento
  final int index;

  const ButtplugUserConfig({
    this.allow = true,
    this.deny = false,
    this.index = 0,
  });

  factory ButtplugUserConfig.fromJson(Map<String, dynamic> json) {
    return ButtplugUserConfig(
      allow: json['allow'] ?? true,
      deny: json['deny'] ?? false,
      index: json['index'] ?? 0,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Buttplug Config Loader
// ═══════════════════════════════════════════════════════════════

/// Cargador de configuración de dispositivos Buttplug v4
///
/// Carga y parsea el archivo JSON de configuración de Buttplug
/// para obtener información de 200+ dispositivos soportados.
class ButtplugConfigLoader {
  static final ButtplugConfigLoader _instance =
      ButtplugConfigLoader._internal();
  factory ButtplugConfigLoader() => _instance;
  ButtplugConfigLoader._internal();

  final List<ButtplugDeviceConfig> _deviceConfigs = [];
  bool _isLoading = false;
  bool _isLoaded = false;

  /// Lista de configuraciones cargadas
  List<ButtplugDeviceConfig> get deviceConfigs =>
      List.unmodifiable(_deviceConfigs);

  /// Si está cargando configuraciones
  bool get isLoading => _isLoading;

  /// Si las configuraciones están cargadas
  bool get isLoaded => _isLoaded;

  /// Número de dispositivos en la configuración
  int get deviceCount => _deviceConfigs.length;

  // ═══════════════════════════════════════════════════════════════
  // Carga de Configuración
  // ═══════════════════════════════════════════════════════════════

  /// Carga configuración desde archivo JSON
  ///
  /// [assetPath] - Ruta del archivo JSON en assets (ej: 'assets/buttplug-config.json')
  Future<void> loadFromAsset(String assetPath) async {
    if (_isLoading) {
      lvsLog('Ya hay carga en progreso', tag: 'BUTTPLUG');
      return;
    }

    _isLoading = true;
    _deviceConfigs.clear();

    try {
      lvsLog('Cargando configuración Buttplug desde $assetPath...', tag: 'BUTTPLUG');
      
      // Leer archivo JSON desde assets
      final jsonString = await rootBundle.loadString(assetPath);
      _parseJson(jsonString);
      
      _isLoaded = true;
      lvsLog('✅ Configuración Buttplug cargada: ${_deviceConfigs.length} dispositivos', tag: 'BUTTPLUG');
    } catch (e) {
      lvsLog('❌ Error cargando configuración Buttplug: $e', tag: 'BUTTPLUG');
      _isLoaded = false;
      rethrow;
    } finally {
      _isLoading = false;
    }
  }

  /// Carga configuración desde string JSON
  ///
  /// [jsonString] - JSON de configuración Buttplug v4
  Future<void> loadFromJsonString(String jsonString) async {
    _isLoading = true;
    _deviceConfigs.clear();

    try {
      lvsLog('Parseando configuración Buttplug...', tag: 'BUTTPLUG');
      _parseJson(jsonString);
      
      _isLoaded = true;
      lvsLog('✅ Configuración Buttplug parseada: ${_deviceConfigs.length} dispositivos', tag: 'BUTTPLUG');
    } catch (e) {
      lvsLog('❌ Error parseando configuración Buttplug: $e', tag: 'BUTTPLUG');
      _isLoaded = false;
      rethrow;
    } finally {
      _isLoading = false;
    }
  }

  /// Parsea JSON de configuración
  void _parseJson(String jsonString) {
    final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
    
    // Verificar versión
    final version = jsonData['version'] as Map<String, dynamic>?;
    if (version != null) {
      final major = version['major'] ?? 0;
      final minor = version['minor'] ?? 0;
      lvsLog('Versión de configuración Buttplug: $major.$minor', tag: 'BUTTPLUG');
      
      if (major != 4) {
        lvsLog('⚠️ Versión mayor diferente a 4, puede haber incompatibilidades', tag: 'BUTTPLUG');
      }
    }
    
    // Parsear dispositivos
    final userConfigs = jsonData['user_configs'] as Map<String, dynamic>?;
    if (userConfigs == null) {
      lvsLog('No se encontró user_configs en el JSON', tag: 'BUTTPLUG');
      return;
    }
    
    final devicesJson = userConfigs['devices'] as List<dynamic>?;
    if (devicesJson == null) {
      lvsLog('No se encontró devices en user_configs', tag: 'BUTTPLUG');
      return;
    }
    
    for (final deviceJson in devicesJson) {
      try {
        final config = ButtplugDeviceConfig.fromJson(deviceJson as Map<String, dynamic>);
        _deviceConfigs.add(config);
      } catch (e) {
        lvsLog('Error parseando dispositivo: $e', tag: 'BUTTPLUG');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Búsqueda de Dispositivos
  // ═══════════════════════════════════════════════════════════════

  /// Busca configuración por identificador
  ///
  /// [identifier] - Identificador del dispositivo (nombre o ID)
  ButtplugDeviceConfig? getConfigByIdentifier(String identifier) {
    try {
      return _deviceConfigs.firstWhere(
        (config) =>
            config.identifier.identifier.toLowerCase() == identifier.toLowerCase() ||
            config.identifier.address.toLowerCase() == identifier.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Busca configuración por protocolo
  ///
  /// [protocol] - Protocolo del dispositivo (ej: 'lovense', 'wevibe')
  List<ButtplugDeviceConfig> getConfigsByProtocol(String protocol) {
    return _deviceConfigs
        .where((config) =>
            config.identifier.protocol.toLowerCase() == protocol.toLowerCase())
        .toList();
  }

  /// Busca configuración por nombre
  ///
  /// [name] - Nombre del dispositivo (búsqueda parcial, case-insensitive)
  List<ButtplugDeviceConfig> getConfigsByName(String name) {
    final nameLower = name.toLowerCase();
    return _deviceConfigs
        .where((config) =>
            config.config.name.toLowerCase().contains(nameLower) ||
            config.identifier.identifier.toLowerCase().contains(nameLower))
        .toList();
  }

  /// Obtiene todos los dispositivos de un fabricante/protocolo
  List<String> getProtocols() {
    final protocols = <String>{};
    for (final config in _deviceConfigs) {
      protocols.add(config.identifier.protocol);
    }
    return protocols.toList()..sort();
  }

  /// Obtiene lista de todos los nombres de dispositivos
  List<String> getDeviceNames() {
    final names = <String>{};
    for (final config in _deviceConfigs) {
      final name = config.config.name.isNotEmpty
          ? config.config.name
          : config.identifier.identifier;
      names.add(name);
    }
    return names.toList()..sort();
  }

  // ═══════════════════════════════════════════════════════════════
  // Conversión a ToyModel
  // ═══════════════════════════════════════════════════════════════

  /// Convierte todas las configuraciones a ToyModel
  List<ToyModel> toToyModels() {
    return _deviceConfigs.map((config) => config.toToyModel()).toList();
  }

  /// Convierte configuraciones filtradas por protocolo a ToyModel
  List<ToyModel> toToyModelsByProtocol(String protocol) {
    return getConfigsByProtocol(protocol)
        .map((config) => config.toToyModel())
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════
  // Limpieza
  // ═══════════════════════════════════════════════════════════════

  /// Limpia las configuraciones cargadas
  void clear() {
    _deviceConfigs.clear();
    _isLoaded = false;
    lvsLog('Configuración Buttplug limpiada', tag: 'BUTTPLUG');
  }
}

// ═══════════════════════════════════════════════════════════════
// Ejemplo de Uso
// ═══════════════════════════════════════════════════════════════

/*
// Cargar configuración desde assets
final loader = ButtplugConfigLoader();
await loader.loadFromAsset('assets/buttplug-config.json');

// Buscar dispositivo por nombre
final configs = loader.getConfigsByName('Lovense Nora');
for (final config in configs) {
  lvsLog('Dispositivo: ${config.config.name}');
  lvsLog('Protocolo: ${config.identifier.protocol}');
  lvsLog('Features: ${config.config.getStimulationType()}');
}

// Obtener todos los dispositivos Lovense
final lovenseDevices = loader.getConfigsByProtocol('lovense');
lvsLog('Dispositivos Lovense: ${lovenseDevices.length}');

// Convertir a ToyModel
final toyModel = configs.first.toToyModel();
lvsLog('ToyModel: ${toyModel.name}');
lvsLog('Motor Logic: ${toyModel.motorLogic}');
*/
