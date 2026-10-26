// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/devices/models/device_capabilities.dart
// Capacidades y modos declarados por el catálogo (modelo dirigido
// por datos, al estilo de Love Spouse: `funcObj` + `classicId`).
// ═══════════════════════════════════════════════════════════════

/// Modo de un dispositivo, tal como lo publica el catálogo.
///
/// `code` es el byte/código de protocolo que entiende el juguete
/// (p. ej. "11".."19", "26".."29", "31".."39", "41".."49").
class DeviceMode {
  final int id;
  final String name;
  final String code;
  final String group;

  const DeviceMode({
    required this.id,
    required this.name,
    required this.code,
    this.group = '',
  });

  factory DeviceMode.fromJson(Map<String, dynamic> json) => DeviceMode(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        group: json['group']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'group': group,
      };
}

/// Rasgos de producto declarados por el fabricante.
///
/// Se guardan como `features` en el catálogo y sustituyen a los
/// `supportedFuncs` en texto libre: la UI decide qué pestañas y
/// botones mostrar a partir de aquí.
class DeviceFeatures {
  static const kegel = 'kegel';
  static const inflation = 'inflation';
  static const discharge = 'discharge';
  static const heating = 'heating';
  static const shake = 'shake';
  static const strike = 'strike';
  static const video = 'video';
  static const video2 = 'video2';
  static const scene = 'scene';
  static const script = 'script';
  static const music = 'music';
  static const training = 'training';
  static const trends = 'trends';
  static const game = 'game';
  static const voice = 'voice';
  static const kill = 'kill'; // parada de emergencia
  static const battery = 'battery';

  static const all = <String>{
    kegel,
    inflation,
    discharge,
    heating,
    shake,
    strike,
    video,
    video2,
    scene,
    script,
    music,
    training,
    trends,
    game,
    voice,
    kill,
    battery,
  };

  /// Normaliza `supported_funcs` (texto libre legacy) a un conjunto.
  static Set<String> parse(dynamic raw) {
    if (raw == null) return <String>{};
    if (raw is List) {
      return raw.map((e) => e.toString().trim().toLowerCase()).where((e) => e.isNotEmpty).toSet();
    }
    final s = raw.toString().toLowerCase();
    final out = <String>{};
    for (final token in s.split(RegExp(r'[,|;/ ]+'))) {
      final t = token.trim();
      if (t.isEmpty) continue;
      for (final f in all) {
        if (t == f || t.contains(f)) out.add(f);
      }
    }
    return out;
  }
}
