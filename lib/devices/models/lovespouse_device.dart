// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/models/lovespouse_device.dart
// Modelo de datos para dispositivos LoveSpouse
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'toy_model.dart';

/// Representa un dispositivo del catálogo técnico LoveSpouse
class LovespouseDevice {
  final int id;
  final int userId;
  final String title;
  final String name;
  final String deviceTitle;
  final String barcode;
  final int cateId;
  final int factoryId;
  final int sellerId;
  final String wireless;
  final int createTime;
  final int updateTime;
  final int status;
  final String pics;
  final String func;
  final Map<String, dynamic> funcObj;
  final List<ProductFunction> productFuncs;
  final String broadcastPrefix;
  final String bleName;
  final int isBlacklist;
  final String qrcode;
  final String gamePath;
  final int isNewCommand;
  final int isPrivateProtocol;
  final String sb;
  final int isEncrypt;
  final String encryptCommand;
  final int isPrecise;
  final List<ClassicMode> classicModes;

  LovespouseDevice({
    required this.id,
    required this.userId,
    required this.title,
    required this.name,
    required this.deviceTitle,
    required this.barcode,
    required this.cateId,
    required this.factoryId,
    required this.sellerId,
    required this.wireless,
    required this.createTime,
    required this.updateTime,
    required this.status,
    required this.pics,
    required this.func,
    required this.funcObj,
    required this.productFuncs,
    required this.broadcastPrefix,
    required this.bleName,
    required this.isBlacklist,
    required this.qrcode,
    required this.gamePath,
    required this.isNewCommand,
    required this.isPrivateProtocol,
    required this.sb,
    required this.isEncrypt,
    required this.encryptCommand,
    required this.isPrecise,
    required this.classicModes,
  });

  /// Crea un dispositivo Lovespouse desde un JSON optimizado (formato comprimido)
  /// Campos: id, dt, bn, w, bp, f, p, pic, qr
  factory LovespouseDevice.fromJsonOptimized(Map<String, dynamic> json) {
    // Extraer funciones del string comprimido
    final funcsString = json['f']?.toString() ?? '';
    final funcCodes = funcsString.isNotEmpty
        ? funcsString.split(',')
        : <String>[];

    // Construir Func string para compatibilidad
    final funcBuffer = StringBuffer('{');
    for (var func in funcCodes) {
      if (funcBuffer.length > 1) funcBuffer.write(',');
      funcBuffer.write('"$func":true');
    }
    funcBuffer.write('}');

    // Reconstruir QR URL
    var qrcode = json['qr']?.toString() ?? '';
    if (qrcode.isNotEmpty && !qrcode.contains('http')) {
      qrcode = 'https://image.zlmicro.com/images/product/qrcode/$qrcode.png';
    }

    // Reconstruir Pics URL
    var pics = json['pic']?.toString() ?? '';
    if (pics.isNotEmpty && !pics.contains('http')) {
      pics = 'https://image.zlmicro.com/images/product/$pics';
    }

    return LovespouseDevice(
      id: 0,
      userId: 0,
      title: '',
      name: '',
      deviceTitle: json['dt']?.toString() ?? '',
      barcode: json['id']?.toString() ?? '',
      cateId: 0,
      factoryId: 0,
      sellerId: 0,
      wireless: json['w']?.toString() ?? '',
      createTime: 0,
      updateTime: 0,
      status: 1,
      pics: pics,
      func: funcBuffer.toString(),
      funcObj: {},
      productFuncs: funcCodes.map((code) => ProductFunction(id: 0, name: code, code: code)).toList(),
      broadcastPrefix: json['bp']?.toString() ?? '',
      bleName: json['bn']?.toString() ?? '',
      isBlacklist: 0,
      qrcode: qrcode,
      gamePath: '',
      isNewCommand: 0,
      isPrivateProtocol: 0,
      sb: '',
      isEncrypt: 0,
      encryptCommand: '',
      isPrecise: (json['p'] == true || json['p'] == 1) ? 1 : 0,
      classicModes: [],
    );
  }

  /// Crea un dispositivo Lovespouse desde un JSON
  factory LovespouseDevice.fromJson(Map<String, dynamic> json) {
    // Parsear ClassicId
    final classicModes = <ClassicMode>[];
    if (json['ClassicId'] != null && json['ClassicId'] is List) {
      for (var classic in json['ClassicId']) {
        classicModes.add(ClassicMode.fromJson(classic));
      }
    }

    // Parsear ProductFuncs
    final productFuncs = <ProductFunction>[];
    if (json['ProductFuncs'] != null && json['ProductFuncs'] is List) {
      for (var func in json['ProductFuncs']) {
        productFuncs.add(ProductFunction.fromJson(func));
      }
    }

    // Parsear FuncObj (puede venir como String o Map)
    var funcObj = <String, dynamic>{};
    if (json['FuncObj'] != null) {
      if (json['FuncObj'] is String) {
        funcObj = jsonDecode(json['FuncObj']);
      } else if (json['FuncObj'] is Map) {
        funcObj = Map<String, dynamic>.from(json['FuncObj']);
      }
    }

    return LovespouseDevice(
      id: json['Id'] ?? 0,
      userId: json['Userid'] ?? 0,
      title: json['Title']?.toString() ?? '',
      name: json['Name']?.toString() ?? '',
      deviceTitle: json['DeviceTitle']?.toString() ?? '',
      barcode: json['BarCode']?.toString() ?? '',
      cateId: json['CateId'] ?? 0,
      factoryId: json['FactoryId'] ?? 0,
      sellerId: json['SellerId'] ?? 0,
      wireless: json['Wireless']?.toString() ?? '',
      createTime: json['CreateTime'] ?? 0,
      updateTime: json['UpdateTime'] ?? 0,
      status: json['Status'] ?? 1,
      pics: json['Pics']?.toString() ?? '',
      func: json['Func']?.toString() ?? '{}',
      funcObj: funcObj,
      productFuncs: productFuncs,
      broadcastPrefix: json['BroadcastPrefix']?.toString() ?? '',
      bleName: json['BleName']?.toString() ?? '',
      isBlacklist: json['IsBlacklist'] ?? 0,
      qrcode: json['Qrcode']?.toString() ?? '',
      gamePath: json['GamePath']?.toString() ?? '',
      isNewCommand: json['IsNewCommand'] ?? 0,
      isPrivateProtocol: json['IsPrivateProtocol'] ?? 0,
      sb: json['SB']?.toString() ?? '',
      isEncrypt: json['IsEncrypt'] ?? 0,
      encryptCommand: json['EncryptCommand']?.toString() ?? '',
      isPrecise: json['IsPrecise'] ?? 0,
      classicModes: classicModes,
    );
  }

  /// Convierte el dispositivo a JSON
  Map<String, dynamic> toJson() => {
        'Id': id,
        'Userid': userId,
        'Title': title,
        'Name': name,
        'DeviceTitle': deviceTitle,
        'BarCode': barcode,
        'CateId': cateId,
        'FactoryId': factoryId,
        'SellerId': sellerId,
        'Wireless': wireless,
        'CreateTime': createTime,
        'UpdateTime': updateTime,
        'Status': status,
        'Pics': pics,
        'Func': func,
        'FuncObj': funcObj,
        'ProductFuncs': productFuncs.map((f) => f.toJson()).toList(),
        'BroadcastPrefix': broadcastPrefix,
        'BleName': bleName,
        'IsBlacklist': isBlacklist,
        'Qrcode': qrcode,
        'GamePath': gamePath,
        'IsNewCommand': isNewCommand,
        'IsPrivateProtocol': isPrivateProtocol,
        'SB': sb,
        'IsEncrypt': isEncrypt,
        'EncryptCommand': encryptCommand,
        'IsPrecise': isPrecise,
        'ClassicId': classicModes.map((c) => c.toJson()).toList(),
      };

  /// Indica si el dispositivo tiene canal dual (basado en los modos clásicos)
  bool get hasDualChannel {
    // Si hay más de un grupo de botones o el nombre del modo indica dual
    for (var mode in classicModes) {
      if (mode.groups.isNotEmpty) {
        return true;
      }
      // Nombres comunes para modos duales en chino/inglés
      final nameLower = mode.name.toLowerCase();
      if (nameLower.contains('dual') ||
          nameLower.contains('双马达') || // "dual motor" en chino
          nameLower.contains('上面') && nameLower.contains('下面')) {
        // "arriba" y "abajo"
        return true;
      }
    }
    return false;
  }

  /// Obtiene el nombre amigable del dispositivo
  String get displayName {
    if (title.isNotEmpty) return title;
    if (deviceTitle.isNotEmpty) return deviceTitle;
    if (name.isNotEmpty) return name;
    if (bleName.isNotEmpty) return bleName;
    return 'Dispositivo $barcode';
  }

  /// Verifica si tiene una función específica (heating, music, shake, etc.)
  bool hasFunction(String funcCode) {
    return productFuncs.any((f) => f.code == funcCode);
  }

  /// Lista de códigos de funciones soportadas
  List<String> get supportedFuncCodes {
    return productFuncs.map((f) => f.code).toList();
  }

  // ═══════════════════════════════════════════════════════════════
  // CONVERSIÓN A ToyModel
  // ═══════════════════════════════════════════════════════════════

  /// Convierte este dispositivo LoveSpouse a un ToyModel
  ToyModel toToyModel() {
    return ToyModel(
      id: barcode,
      name: displayName,
      usageType: _inferUsageType(),
      targetAnatomy: _inferTargetAnatomy(),
      stimulationType: _inferStimulationType(),
      motorLogic: hasDualChannel ? 'Dual Channel' : 'Single Channel',
      imageUrl: pics.isNotEmpty ? pics : qrcode.replaceAll('qrcode/', 'product/').replaceAll('.png', '.png'),
      qrCodeUrl: qrcode,
      supportedFuncs: supportedFuncCodes.join(','),
      isPrecise: isPrecise == 1,
      broadcastPrefix: broadcastPrefix.isNotEmpty ? broadcastPrefix : '77 62 4d 53 45',
    );
  }

  /// Infiere el tipo de uso basado en las funciones y categoría
  String _inferUsageType() {
    // Basado en categoría (cateId)
    // 1: Insertable, 2: Wearable, 3: Dual, 8: Ring, 10: Thrust, 13: Combo
    switch (cateId) {
      case 1:
      case 2:
        return 'Insertable';
      case 3:
      case 13:
        return 'Dual/Combo';
      case 8:
        return 'Wearable';
      case 10:
        return 'Thrust';
      default:
        // Inferir por funciones
        if (hasFunction('heating')) return 'Insertable';
        if (hasDualChannel) return 'Dual/Combo';
        return 'Universal';
    }
  }

  /// Infiere la anatomía objetivo basada en funciones y título
  String _inferTargetAnatomy() {
    final titleLower = title.toLowerCase();
    final deviceTitleLower = deviceTitle.toLowerCase();

    // Buscar palabras clave en títulos
    if (titleLower.contains('prostat') || deviceTitleLower.contains('prostat')) {
      return 'Prostático';
    }
    if (titleLower.contains('kegel')) {
      return 'Kegel';
    }
    if (titleLower.contains('anal') || titleLower.contains('zen')) {
      return 'Anal';
    }
    if (titleLower.contains('clitor') || titleLower.contains('luna')) {
      return 'Clitoral';
    }
    if (titleLower.contains('penian') || titleLower.contains('ring')) {
      return 'Peniano';
    }

    // Basado en categoría
    switch (cateId) {
      case 1:
        return 'Vaginal';
      case 2:
        return 'Clitoral';
      case 3:
        return 'Dual';
      case 8:
        return 'Peniano';
      case 10:
        return 'Anal';
      default:
        return 'Universal';
    }
  }

  /// Infiere el tipo de estimulación basado en funciones
  String _inferStimulationType() {
    final types = <String>[];

    if (hasFunction('heating')) types.add('Calor');
    if (hasFunction('finger')) types.add('Táctil');
    if (hasFunction('shake')) types.add('Movimiento');
    if (hasFunction('strike')) types.add('Golpeteo');

    // Basado en modos clásicos
    for (var mode in classicModes) {
      final nameLower = mode.name.toLowerCase();
      if (nameLower.contains('thrust') || nameLower.contains('empuje')) {
        types.add('Empuje');
      }
      if (nameLower.contains('wave') || nameLower.contains('onda')) {
        types.add('Onda');
      }
      if (nameLower.contains('suc') || nameLower.contains('succión')) {
        types.add('Succión');
      }
    }

    if (types.isEmpty) {
      return 'Vibración';
    }

    return types.join(' + ');
  }
}

/// Función disponible para el producto (modos)
class ProductFunction {
  final int id;
  final String name;
  final String code;

  ProductFunction({
    required this.id,
    required this.name,
    required this.code,
  });

  factory ProductFunction.fromJson(Map<String, dynamic> json) {
    return ProductFunction(
      id: json['Id'] ?? 0,
      name: json['Name']?.toString() ?? '',
      code: json['Code']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'Id': id,
        'Name': name,
        'Code': code,
      };
}

/// Modo clásico con configuraciones de botones y grupos
class ClassicMode {
  final int id;
  final String name;
  final List<ClassicGroup> groups;
  final List<dynamic> classicGroups;

  ClassicMode({
    required this.id,
    required this.name,
    required this.groups,
    required this.classicGroups,
  });

  factory ClassicMode.fromJson(Map<String, dynamic> json) {
    final groups = <ClassicGroup>[];
    if (json['Groups'] != null && json['Groups'] is List) {
      for (var group in json['Groups']) {
        groups.add(ClassicGroup.fromJson(group));
      }
    }

    return ClassicMode(
      id: json['Id'] ?? 0,
      name: json['Name']?.toString() ?? '',
      groups: groups,
      classicGroups: json['ClassicGroups'] ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
        'Id': id,
        'Name': name,
        'Groups': groups.map((g) => g.toJson()).toList(),
        'ClassicGroups': classicGroups,
      };

  /// Obtiene todos los botones de todos los grupos
  List<ModeButton> getAllButtons() {
    final allButtons = <ModeButton>[];
    for (var group in groups) {
      allButtons.addAll(group.buttons);
    }
    return allButtons;
  }

  /// Número total de botones
  int get totalButtons {
    return groups.fold(0, (sum, group) => sum + group.buttons.length);
  }
}

/// Grupo de botones dentro de un modo clásico
class ClassicGroup {
  final int id;
  final String name;
  final int special;
  final int type;
  final List<ModeButton> buttons;
  final List<dynamic> groupButtons;

  ClassicGroup({
    required this.id,
    required this.name,
    required this.special,
    required this.type,
    required this.buttons,
    required this.groupButtons,
  });

  factory ClassicGroup.fromJson(Map<String, dynamic> json) {
    final buttons = <ModeButton>[];
    if (json['Buttons'] != null && json['Buttons'] is List) {
      for (var button in json['Buttons']) {
        buttons.add(ModeButton.fromJson(button));
      }
    }

    return ClassicGroup(
      id: json['Id'] ?? 0,
      name: json['Name']?.toString() ?? '',
      special: json['Special'] ?? 0,
      type: json['Type'] ?? 0,
      buttons: buttons,
      groupButtons: json['GroupButtons'] ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
        'Id': id,
        'Name': name,
        'Special': special,
        'Type': type,
        'Buttons': buttons.map((b) => b.toJson()).toList(),
        'GroupButtons': groupButtons,
      };
}

/// Botón de modo con comando e imagen
class ModeButton {
  final int id;
  final String name;
  final String image;
  final String imageClick;
  final dynamic command; // Puede ser int o String
  final String newCommand;
  final String stopCommand;

  ModeButton({
    required this.id,
    required this.name,
    required this.image,
    required this.imageClick,
    required this.command,
    required this.newCommand,
    required this.stopCommand,
  });

  factory ModeButton.fromJson(Map<String, dynamic> json) {
    return ModeButton(
      id: json['Id'] ?? 0,
      name: json['Name']?.toString() ?? '',
      image: json['Image']?.toString() ?? '',
      imageClick: json['ImageClick']?.toString() ?? '',
      command: json['Command'] ?? json['NewCommand'] ?? 0,
      newCommand: json['NewCommand']?.toString() ?? '',
      stopCommand: json['StopCommand']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'Id': id,
        'Name': name,
        'Image': image,
        'ImageClick': imageClick,
        'Command': command,
        'NewCommand': newCommand,
        'StopCommand': stopCommand,
      };

  /// Obtiene el comando como string hexadecimal para enviar por BLE
  String get commandHex {
    if (command is int) {
      return command.toRadixString(16).toUpperCase().padLeft(2, '0');
    }
    return newCommand;
  }
}
