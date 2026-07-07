// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/models/toy_model.dart
// Modelo de datos para dispositivos del catálogo
// ═══════════════════════════════════════════════════════════════
import 'dart:convert';
import 'package:flutter/material.dart';

/// Botón de patrón individual del ClassicId
class PatternButton {
  final int id;
  final String name;
  final int command;
  final int stopCommand;
  final String imageUrl;
  final String newCommand;

  const PatternButton({
    required this.id,
    required this.name,
    required this.command,
    required this.stopCommand,
    this.imageUrl = '',
    this.newCommand = '',
  });

  factory PatternButton.fromJson(Map<String, dynamic> json) => PatternButton(
    id: int.tryParse(json['Id']?.toString() ?? '') ?? 0,
    name: json['Name']?.toString() ?? 'Modo',
    command: int.tryParse(json['Command']?.toString() ?? '') ?? 0,
    stopCommand: int.tryParse(json['StopCommand']?.toString() ?? '') ?? 0,
    imageUrl: json['Image']?.toString() ?? '',
    newCommand: json['NewCommand']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {
    'Id': id, 'Name': name, 'Command': command,
    'StopCommand': stopCommand, 'Image': imageUrl,
    'NewCommand': newCommand,
  };
}

/// Grupo de patrones (un grupo = un canal en dispositivos duales)
class PatternGroup {
  final int id;
  final String name;
  final int type;
  final List<PatternButton> buttons;

  const PatternGroup({
    required this.id,
    required this.name,
    this.type = 0,
    this.buttons = const [],
  });

  bool get isEmpty => buttons.isEmpty;

  factory PatternGroup.fromJson(Map<String, dynamic> json) {
    final buttons = (json['Buttons'] as List? ?? [])
        .map((b) => PatternButton.fromJson(b))
        .toList();
    return PatternGroup(
      id: json['Id'] ?? 0,
      name: json['Name']?.toString() ?? '',
      type: json['Type'] ?? 0,
      buttons: buttons,
    );
  }

  Map<String, dynamic> toJson() => {
    'Id': id, 'Name': name, 'Type': type,
    'Buttons': buttons.map((b) => b.toJson()).toList(),
  };
}

class ToyModel {
  final String id;
  final String name;
  final String usageType;
  final String targetAnatomy;
  final String stimulationType;
  final String motorLogic;
  final String imageUrl;
  final String qrCodeUrl;
  final String supportedFuncs;
  final bool isPrecise;
  final String broadcastPrefix;
  final String bleName;
  final bool isEncrypt;
  final String encryptCommand;
  final List<PatternGroup> patternGroups;

  ToyModel({
    required this.id,
    required this.name,
    required this.usageType,
    required this.targetAnatomy,
    required this.stimulationType,
    required this.motorLogic,
    required this.imageUrl,
    required this.qrCodeUrl,
    required this.supportedFuncs,
    required this.isPrecise,
    required this.broadcastPrefix,
    this.bleName = '',
    this.isEncrypt = false,
    this.encryptCommand = '',
    this.patternGroups = const [],
  });

  bool get hasDualChannel => motorLogic.toLowerCase().contains('dual');

  /// Check if this device supports a specific feature.
  /// [feature] is a feature code like 'music', 'shake', 'video', 'game', 'kegel', etc.
  /// Parses `supportedFuncs` which is pipe (`|`) or comma (`,`) delimited.
  /// Returns `true` if `supportedFuncs` is empty (backward compatible fallback).
  bool supports(String feature) {
    if (supportedFuncs.isEmpty) return true;
    final lower = feature.toLowerCase();
    return supportedFuncs.toLowerCase().split(RegExp(r'[,|]')).any((f) => f.trim() == lower);
  }

  /// Icono Vectorial Nativo (Material Icons) para la app, escalable y tintable
  IconData get materialIcon {
    final nameLower = name.toLowerCase();
    final typeLower = usageType.toLowerCase();
    final anatomyLower = targetAnatomy.toLowerCase();
    final stimLower = stimulationType.toLowerCase();

    // 1. Prioridad por Anatomía Específica
    if (anatomyLower.contains('kegel') || nameLower.contains('kegel')) return Icons.spa;
    if (anatomyLower.contains('anal') || anatomyLower.contains('zen')) return Icons.adjust;
    if (anatomyLower.contains('prostat') || anatomyLower.contains('prostático')) return Icons.gamepad; // Joystick-like
    if (anatomyLower.contains('clitor') || anatomyLower.contains('luna')) return Icons.flare;
    if (anatomyLower.contains('peneano') || anatomyLower.contains('ring') || anatomyLower.contains('anillo')) return Icons.donut_large;

    // 2. Prioridad por Tipo de Estimulación / Mecanismo
    if (stimLower.contains('onda') || stimLower.contains('pulse') || stimLower.contains('wave')) return Icons.waves;
    if (stimLower.contains('succión') || stimLower.contains('suction')) return Icons.cyclone;
    if (stimLower.contains('empuje') || stimLower.contains('thrust')) return Icons.unfold_more;
    if (hasDualChannel || stimLower.contains('dual')) return Icons.hub;

    // 3. Casos por Forma
    if (nameLower.contains('egg') || nameLower.contains('huevo') || typeLower.contains('egg')) return Icons.egg;
    if (nameLower.contains('wand') || nameLower.contains('varita')) return Icons.auto_fix_high;
    if (nameLower.contains('bullet') || nameLower.contains('bala')) return Icons.rocket_launch;

    return Icons.vibration; // Default genérico
  }

  /// Ícono representativo del dispositivo (PNG original - Obsoleto)
  String get iconAsset {
    final nameLower = name.toLowerCase();
    final typeLower = usageType.toLowerCase();
    final anatomyLower = targetAnatomy.toLowerCase();
    final stimLower = stimulationType.toLowerCase();

    // 1. Prioridad por Anatomía Específica / Tipo de Ejercitador
    if (anatomyLower.contains('kegel') || nameLower.contains('kegel')) return 'assets/icons/icon_kegel.png';
    if (anatomyLower.contains('anal') || anatomyLower.contains('zen')) return 'assets/icons/icon_anal.png';
    if (anatomyLower.contains('prostat') || anatomyLower.contains('prostático')) return 'assets/icons/icon_prostate.png';
    if (anatomyLower.contains('clitor') || anatomyLower.contains('luna')) return 'assets/icons/icon_clitoral.png';
    if (anatomyLower.contains('peneano') || anatomyLower.contains('ring') || anatomyLower.contains('anillo')) return 'assets/icons/icon_ring.png';

    // 2. Prioridad por Tipo de Estimulación / Mecanismo
    if (stimLower.contains('onda') || stimLower.contains('pulse') || stimLower.contains('wave')) return 'assets/icons/icon_pulse_waves.png';
    if (stimLower.contains('succión') || stimLower.contains('suction')) return 'assets/icons/icon_suction.png';
    if (stimLower.contains('empuje') || stimLower.contains('thrust')) return 'assets/icons/icon_thrust.png';
    if (hasDualChannel || stimLower.contains('dual')) return 'assets/icons/icon_dual_motor.png';

    // 3. Casos por Género o Anatomía General
    if (anatomyLower.contains('female') || typeLower.contains('female')) return 'assets/icons/icon_female_anatomy.png';
    if (anatomyLower.contains('male') || typeLower.contains('male')) return 'assets/icons/icon_male_anatomy.png';

    // 4. Casos por Forma (Fallbacks)
    if (nameLower.contains('egg') || nameLower.contains('huevo') || typeLower.contains('egg')) return 'assets/icons/icon_egg.png';
    if (nameLower.contains('bullet') || nameLower.contains('bala') || typeLower.contains('bullet')) return 'assets/icons/icon_bullet.png';

    // 5. Default
    return 'assets/icons/icon_vibrator.png';
  }


  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToyModel &&
          id == other.id &&
          name == other.name &&
          usageType == other.usageType &&
          targetAnatomy == other.targetAnatomy &&
          stimulationType == other.stimulationType &&
          motorLogic == other.motorLogic &&
          imageUrl == other.imageUrl &&
          qrCodeUrl == other.qrCodeUrl &&
          supportedFuncs == other.supportedFuncs &&
          isPrecise == other.isPrecise &&
          broadcastPrefix == other.broadcastPrefix &&
          bleName == other.bleName &&
          isEncrypt == other.isEncrypt &&
          encryptCommand == other.encryptCommand &&
          _listEquals(patternGroups, other.patternGroups);

  static bool _listEquals(List<PatternGroup>? a, List<PatternGroup>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || 
          a[i].name != b[i].name || 
          a[i].type != b[i].type ||
          a[i].buttons.length != b[i].buttons.length) {
        return false;
      }
      for (var j = 0; j < a[i].buttons.length; j++) {
        if (a[i].buttons[j].id != b[i].buttons[j].id ||
            a[i].buttons[j].name != b[i].buttons[j].name ||
            a[i].buttons[j].command != b[i].buttons[j].command) {
          return false;
        }
      }
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, usageType, targetAnatomy, stimulationType,
          motorLogic, imageUrl, qrCodeUrl, supportedFuncs, isPrecise, broadcastPrefix,
          bleName, isEncrypt, encryptCommand,
          Object.hashAll(patternGroups.map((g) =>
              Object.hash(g.id, g.name, g.type, g.buttons.length))));

  factory ToyModel.fromCsv(List<dynamic> row) {
    // Estructura esperada segun el CSV:
    // 0:ID, 1:Barcode, 2:Nombre, 3:UsageType, 4:TargetAnatomy, 5:StimulationType,
    // 6:MotorLogic, 7:DB_Id, 8:RealTitle, 9:Pics, 10:CateId, 11:Qrcode,
    // 12:SupportedFuncs, 13:Wireless, 14:FactoryId, 15:IsEncrypt,
    // 16:IsPrecise, 17:BroadcastPrefix, 18:BleName

    String safeGet(List<dynamic> row, int index) {
      if (index >= row.length) return '';
      return row[index]?.toString() ?? '';
    }

    return ToyModel(
      id: safeGet(row, 0),
      name: safeGet(row, 2) == '' ? 'Unknown' : safeGet(row, 2),
      usageType: safeGet(row, 3) == '' ? 'Universal' : safeGet(row, 3),
      targetAnatomy: safeGet(row, 4) == '' ? 'Universal' : safeGet(row, 4),
      stimulationType: safeGet(row, 5) == '' ? 'Vibración' : safeGet(row, 5),
      motorLogic: safeGet(row, 6) == '' ? 'Single Channel' : safeGet(row, 6),
      imageUrl: safeGet(row, 9),
      qrCodeUrl: safeGet(row, 11),
      supportedFuncs: safeGet(row, 12),
      isPrecise: safeGet(row, 16) == '0-255',
      broadcastPrefix: safeGet(row, 17) == '' ? '77 62 4d 53 45' : safeGet(row, 17),
      isEncrypt: safeGet(row, 15) == '1',
      bleName: safeGet(row, 18),
    );
  }

  /// Extrae texto de un campo que puede venir como String, List o JSON array string
  static String _extractText(dynamic val, String defaultVal) {
    if (val == null) return defaultVal;
    if (val is List) {
      if (val.isEmpty) return defaultVal;
      return val.map((e) => e.toString()).join(', ');
    }
    final s = val.toString().replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').replaceAll('\\', '');
    if (s.isEmpty) return defaultVal;
    return s;
  }

  /// Normaliza motor_logic: single→Single Channel, dual→Dual Channel
  static String _normalizeMotorLogic(dynamic val) {
    if (val == null) return 'Single Channel';
    final s = val.toString().toLowerCase();
    if (s.contains('dual')) return 'Dual Channel';
    if (s.contains('single') || s == '1') return 'Single Channel';
    return val.toString();
  }

  /// Toma el primer valor no vacío y no "N/A" de una lista de campos
  static String _pickName(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final val = row[key]?.toString() ?? '';
      if (val.isNotEmpty && val != 'N/A') return val;
    }
    return 'Generic LVS';
  }

  /// Extrae el ClassicId del raw_json_data (Groups → patrones por canal)
  static List<PatternGroup> _extractPatterns(dynamic rawJson) {
    if (rawJson == null) return [];
    try {
      final data = rawJson is Map ? rawJson : jsonDecode(rawJson.toString());
      final classicId = data['ClassicId'];
      if (classicId == null || classicId is! List) return [];
      final groups = <PatternGroup>[];
      for (final entry in classicId) {
        final entryGroups = entry['Groups'] as List? ?? [];
        for (final g in entryGroups) {
          groups.add(PatternGroup.fromJson(g));
        }
      }
      return groups;
    } catch (_) {
      return [];
    }
  }

  factory ToyModel.fromSupabase(Map<String, dynamic> row) {
    return ToyModel(
      id: row['id']?.toString() ?? '',
      name: _pickName(row, ['model_name', 'factory_model', 'name', 'id']),
      usageType: _extractText(row['usage_type'], 'Universal'),
      targetAnatomy: _extractText(row['target_anatomy'], 'Universal'),
      stimulationType: _extractText(row['stimulation_type'], 'Vibración'),
      motorLogic: _normalizeMotorLogic(row['motor_logic']),
      imageUrl: row['image_url']?.toString() ?? '',
      qrCodeUrl: row['qr_code_url']?.toString() ?? '',
      supportedFuncs: row['supported_funcs']?.toString() ?? '',
      isPrecise: row['is_precise_new'] == true || row['is_precise'] == true,
      broadcastPrefix: row['broadcast_prefix']?.toString() ?? '77 62 4d 53 45',
      bleName: row['ble_name']?.toString() ?? '',
      isEncrypt: row['is_encrypt'] == true || row['is_encrypt'] == 1,
      encryptCommand: row['encrypt_command']?.toString() ?? '',
      patternGroups: _extractPatterns(row['raw_json_data']),
    );
  }

  // ── Persistencia JSON (Secure Storage) ──────────────────────
  factory ToyModel.fromJson(Map<String, dynamic> json) {
    return ToyModel(
      id            : json['id']?.toString() ?? '',
      name          : json['name']?.toString() ?? 'Dispositivo',
      usageType     : json['usageType']?.toString() ?? 'Universal',
      targetAnatomy : json['targetAnatomy']?.toString() ?? 'Universal',
      stimulationType: json['stimulationType']?.toString() ?? 'Vibración',
      motorLogic    : json['motorLogic']?.toString() ?? 'Single Channel',
      imageUrl      : json['imageUrl']?.toString() ?? '',
      qrCodeUrl     : json['qrCodeUrl']?.toString() ?? '',
      supportedFuncs: json['supportedFuncs']?.toString() ?? '',
      isPrecise     : json['isPrecise'] == true,
      broadcastPrefix: json['broadcastPrefix']?.toString() ?? '77 62 4d 53 45',
      isEncrypt     : json['isEncrypt'] == true,
      encryptCommand: json['encryptCommand']?.toString() ?? '',
      bleName       : json['bleName']?.toString() ?? '',
      patternGroups : (json['patternGroups'] as List?)
          ?.map((g) => PatternGroup.fromJson(g))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id'             : id,
    'name'           : name,
    'usageType'      : usageType,
    'targetAnatomy'  : targetAnatomy,
    'stimulationType': stimulationType,
    'motorLogic'     : motorLogic,
    'imageUrl'       : imageUrl,
    'qrCodeUrl'      : qrCodeUrl,
    'supportedFuncs' : supportedFuncs,
    'isPrecise'      : isPrecise,
    'broadcastPrefix': broadcastPrefix,
    'isEncrypt'      : isEncrypt,
    if (bleName.isNotEmpty)
      'bleName'      : bleName,
    if (encryptCommand.isNotEmpty)
      'encryptCommand': encryptCommand,
    if (patternGroups.isNotEmpty)
      'patternGroups': patternGroups.map((g) => g.toJson()).toList(),
  };
}
