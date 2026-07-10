import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuración remota de UI (ActivityConfig)
/// Permite activar/desactivar features por backend sin release
class ActivityConfig {
  final Map<String, dynamic> _config = {};
  bool _initialized = false;

  static final ActivityConfig _instance = ActivityConfig._internal();
  factory ActivityConfig() => _instance;
  ActivityConfig._internal();

  static ActivityConfig get instance => _instance;

  bool get isInitialized => _initialized;

  /// Carga configuración desde backend (o JSON local si no hay red)
  Future<void> loadFromBackend(Map<String, dynamic>? backendConfig) async {
    if (backendConfig != null) {
      _config.clear();
      _config.addAll(backendConfig);
      _initialized = true;
      await _saveLocal();
    } else {
      await _loadLocal();
    }
  }

  /// Carga configuración desde JSON string local
  void loadFromJson(String jsonString) {
    try {
      final parsed = jsonDecode(jsonString) as Map<String, dynamic>;
      _config.clear();
      _config.addAll(parsed);
      _initialized = true;
    } catch (e) {
      _initialized = false;
    }
  }

  /// Guarda configuración localmente
  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('activity_config', jsonEncode(_config));
  }

  /// Carga configuración guardada localmente
  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('activity_config');
    if (saved != null) {
      try {
        final parsed = jsonDecode(saved) as Map<String, dynamic>;
        _config.clear();
        _config.addAll(parsed);
        _initialized = true;
      } catch (e) {
        _initialized = false;
      }
    }
  }

  /// Obtiene valor de feature flag
  bool getFeatureFlag(String flagName, {bool defaultValue = false}) {
    if (_config.containsKey(flagName)) {
      final value = _config[flagName];
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
      if (value is int) return value != 0;
    }
    return defaultValue;
  }

  /// Obtiene valor de configuración string
  String getConfigString(String key, {String defaultValue = ''}) {
    if (_config.containsKey(key)) {
      return _config[key]?.toString() ?? defaultValue;
    }
    return defaultValue;
  }

  /// Obtiene valor de configuración int
  int getConfigInt(String key, {int defaultValue = 0}) {
    if (_config.containsKey(key)) {
      final value = _config[key];
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  /// Obtiene valor de configuración double
  double getConfigDouble(String key, {double defaultValue = 0.0}) {
    if (_config.containsKey(key)) {
      final value = _config[key];
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  /// Obtiene objeto de configuración anidado
  Map<String, dynamic>? getConfigObject(String key) {
    if (_config.containsKey(key) && _config[key] is Map) {
      return _config[key] as Map<String, dynamic>;
    }
    return null;
  }

  /// Verifica si un banner está habilitado
  bool isBannerEnabled(String bannerId) {
    final banners = getConfigObject('banners');
    if (banners != null && banners.containsKey(bannerId)) {
      final value = banners[bannerId];
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
    }
    return false;
  }

  /// Verifica si un tab está habilitado
  bool isTabEnabled(String tabId) {
    final tabs = getConfigObject('tabs');
    if (tabs != null && tabs.containsKey(tabId)) {
      final value = tabs[tabId];
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
    }
    return true; // Por defecto todos los tabs habilitados
  }

  /// Verifica si un flotante está habilitado
  bool isFloatingEnabled(String floatingId) {
    final floatings = getConfigObject('floatings');
    if (floatings != null && floatings.containsKey(floatingId)) {
      final value = floatings[floatingId];
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
    }
    return false;
  }

  /// Configuración de UI por defecto (fallback local)
  static const String defaultConfigJson = '''
  {
    "banners": {
      "promo_2025": true,
      "new_device": true,
      "discount": false
    },
    "tabs": {
      "control": true,
      "catalog": true,
      "profile": true,
      "remote": true
    },
    "floatings": {
      "quick_stop": true,
      "chat": false
    },
    "features": {
      "video_call": true,
      "voice_control": true,
      "music_sync": true,
      "classic_mode": true
    },
    "ab_test_group": "control"
  }
  ''';
}

/// Provider/Notifier para ActivityConfig (Riverpod-friendly)
class ActivityConfigProvider extends ChangeNotifier {
  final ActivityConfig _config = ActivityConfig.instance;

  ActivityConfig get config => _config;

  bool getFeatureFlag(String flagName, {bool defaultValue = false}) =>
      _config.getFeatureFlag(flagName, defaultValue: defaultValue);

  String getConfigString(String key, {String defaultValue = ''}) =>
      _config.getConfigString(key, defaultValue: defaultValue);

  int getConfigInt(String key, {int defaultValue = 0}) =>
      _config.getConfigInt(key, defaultValue: defaultValue);

  double getConfigDouble(String key, {double defaultValue = 0.0}) =>
      _config.getConfigDouble(key, defaultValue: defaultValue);

  bool isBannerEnabled(String bannerId) => _config.isBannerEnabled(bannerId);
  bool isTabEnabled(String tabId) => _config.isTabEnabled(tabId);
  bool isFloatingEnabled(String floatingId) => _config.isFloatingEnabled(floatingId);

  Future<void> loadFromBackend(Map<String, dynamic>? backendConfig) async {
    await _config.loadFromBackend(backendConfig);
    notifyListeners();
  }

  void loadFromJson(String jsonString) {
    _config.loadFromJson(jsonString);
    notifyListeners();
  }
}