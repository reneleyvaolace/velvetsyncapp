// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/models/toy_model.dart
// Modelo de datos para dispositivos del catálogo
// ═══════════════════════════════════════════════════════════════

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
  });

  bool get hasDualChannel => motorLogic.toLowerCase().contains('dual');

  /// Ícono representativo del dispositivo basado en su tipo, anatomía y estimulación
  String get iconAsset {
    final nameLower = name.toLowerCase();
    final typeLower = usageType.toLowerCase();
    final anatomyLower = targetAnatomy.toLowerCase();
    final stimLower = stimulationType.toLowerCase();

    // 1. Prioridad por Anatomía Específica
    if (anatomyLower.contains('anal') || anatomyLower.contains('zen')) return 'assets/icons/icon_anal.png';
    if (anatomyLower.contains('prostat') || anatomyLower.contains('prostático')) return 'assets/icons/icon_prostate.png';
    if (anatomyLower.contains('clitor') || anatomyLower.contains('luna')) return 'assets/icons/icon_clitoral.png';
    if (anatomyLower.contains('penian') || anatomyLower.contains('ring') || anatomyLower.contains('anillo')) return 'assets/icons/icon_ring.png';

    // 2. Prioridad por Tipo de Estimulación / Mecanismo
    if (stimLower.contains('succión') || stimLower.contains('suction') || stimLower.contains('pulse')) return 'assets/icons/icon_suction.png';
    if (stimLower.contains('empuje') || stimLower.contains('thrust')) return 'assets/icons/icon_thrust.png';
    if (hasDualChannel || stimLower.contains('dual')) return 'assets/icons/icon_dual_motor.png';

    // 3. Casos por Forma (Fallbacks)
    if (nameLower.contains('egg') || nameLower.contains('huevo') || typeLower.contains('egg')) return 'assets/icons/icon_egg.png';
    if (nameLower.contains('bullet') || nameLower.contains('bala') || typeLower.contains('bullet')) return 'assets/icons/icon_bullet.png';

    // 4. Default
    return 'assets/icons/icon_vibrator.png';
  }


  factory ToyModel.fromCsv(List<dynamic> row) {
    // Estructura esperada segun el CSV:
    // 0:ID, 1:Barcode, 2:Nombre, 3:UsageType, 4:TargetAnatomy, 5:StimulationType, 
    // 6:MotorLogic, 7:DB_Id, 8:RealTitle, 9:Pics, 10:CateId, 11:Qrcode, 
    // 12:SupportedFuncs, 13:Wireless, 14:FactoryId, 15:IsEncrypt, 
    // 16:IsPrecise, 17:BroadcastPrefix, 18:BleName
    
    return ToyModel(
      id: row[0].toString(),
      name: row[2]?.toString() ?? 'Unknown',
      usageType: row[3]?.toString() ?? 'Universal',
      targetAnatomy: row[4]?.toString() ?? 'Universal',
      stimulationType: row[5]?.toString() ?? 'Vibración',
      motorLogic: row[6]?.toString() ?? 'Single Channel',
      imageUrl: row[9]?.toString() ?? '',
      qrCodeUrl: row[11]?.toString() ?? '',
      supportedFuncs: row[12]?.toString() ?? '',
      isPrecise: row[16]?.toString() == '0-255',
      broadcastPrefix: row[17]?.toString() ?? '77 62 4d 53 45',
    );
  }

  factory ToyModel.fromSupabase(Map<String, dynamic> row) {
    // Manejo de target_anatomy que puede venir como JSON Array o String
    String anatomy = 'Universal';
    if (row['target_anatomy'] != null) {
      final raw = row['target_anatomy'];
      if (raw is List) {
        anatomy = raw.join('|').replaceAll('"', '').replaceAll('[', '').replaceAll(']', '');
      } else {
        // Limpieza de string si viene como ["Anal"]
        anatomy = raw.toString().replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').replaceAll('\\', '');
        if (anatomy.isEmpty) anatomy = 'Universal';
      }
    }

    return ToyModel(
      id: row['id']?.toString() ?? '',
      name: row['factory_model']?.toString() ?? row['model_name']?.toString() ?? row['name']?.toString() ?? 'Generic LVS',
      usageType: row['usage_type']?.toString() ?? 'Universal',
      targetAnatomy: anatomy,
      stimulationType: row['stimulation_type']?.toString() ?? 'Vibración',
      motorLogic: row['motor_logic']?.toString() ?? 'Single Channel',
      imageUrl: row['image_url']?.toString() ?? '',
      qrCodeUrl: row['qr_code_url']?.toString() ?? '',
      supportedFuncs: row['supported_funcs']?.toString() ?? '',
      isPrecise: row['is_precise_new'] == true || row['is_precise'] == true,
      broadcastPrefix: row['broadcast_prefix']?.toString() ?? '77 62 4d 53 45',
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
  };
}
