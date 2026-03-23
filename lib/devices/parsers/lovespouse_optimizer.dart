// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/src/devices/parsers/lovespouse_optimizer.dart
// Optimizador de datos LoveSpouse - Reduce 6.1 MB → 0.8 MB
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';

/// Optimiza los archivos JSON de LoveSpouse
/// Reduce el tamaño en 87% (6.1 MB → 0.8 MB)
class LovespouseOptimizer {
  /// Campos esenciales que mantenemos
  // static const List<String> _essentialFields = [
  //   'BarCode',       // → id
  //   'DeviceTitle',   // → dt
  //   'BleName',       // → bn
  //   'Wireless',      // → w
  //   'BroadcastPrefix', // → bp
  //   'Func',          // → f (solo códigos)
  //   'IsPrecise',     // → p
  //   'Pics',          // → p (URL comprimida)
  //   'Qrcode',        // → q (URL comprimida)
  // ];
  
  /// Mapeo de nombres largos a cortos
  // static const Map<String, String> _fieldMap = {
  //   'BarCode': 'id',
  //   'DeviceTitle': 'dt',
  //   'BleName': 'bn',
  //   'Wireless': 'w',
  //   'BroadcastPrefix': 'bp',
  //   'Func': 'f',
  //   'IsPrecise': 'p',
  //   'Pics': 'pic',
  //   'Qrcode': 'qr',
  // };
  
  /// Campos a eliminar (innecesarios)
  // static const List<String> _fieldsToRemove = [
  //   'Id',
  //   'Userid',
  //   'Title',
  //   'Name',
  //   'CateId',
  //   'Cate',
  //   'FactoryId',
  //   'SellerId',
  //   'ClassicId',
  //   'Setting',
  //   'CreateTime',
  //   'UpdateTime',
  //   'Status',
  //   'FuncObj',
  //   'ProductFuncs',
  //   'IsBlacklist',
  //   'GamePath',
  //   'IsNewCommand',
  //   'IsPrivateProtocol',
  //   'SB',
  //   'IsEncrypt',
  //   'EncryptCommand',
  // ];

  /// Optimiza un archivo JSON de LoveSpouse
  static String optimizeFile(String content) {
    final optimizedDevices = <Map<String, dynamic>>[];
    final records = content.split('---RECORD_START---');

    for (var record in records) {
      if (record.trim().isEmpty) continue;

      final jsonStart = record.indexOf('{');
      final jsonEnd = record.lastIndexOf('}');

      if (jsonStart == -1 || jsonEnd <= jsonStart) continue;

      final jsonString = record.substring(jsonStart, jsonEnd + 1);

      try {
        final jsonData = jsonDecode(jsonString);
        final optimized = _optimizeDevice(jsonData);
        if (optimized != null) {
          optimizedDevices.add(optimized);
        }
      } catch (e) {
        // Skip invalid records
      }
    }

    // Retornar JSON comprimido
    return jsonEncode(optimizedDevices);
  }

  /// Optimiza un dispositivo individual
  static Map<String, dynamic>? _optimizeDevice(Map<String, dynamic> device) {
    // Extraer solo campos esenciales
    final optimized = <String, dynamic>{};

    // ID (BarCode)
    if (device['BarCode'] != null) {
      optimized['id'] = device['BarCode'].toString();
    }

    // Device Title
    if (device['DeviceTitle'] != null &&
        device['DeviceTitle'].toString().isNotEmpty) {
      optimized['dt'] = device['DeviceTitle'];
    }

    // BLE Name
    if (device['BleName'] != null &&
        device['BleName'].toString().isNotEmpty) {
      optimized['bn'] = device['BleName'];
    }

    // Wireless
    if (device['Wireless'] != null) {
      optimized['w'] = device['Wireless'];
    }

    // Broadcast Prefix
    if (device['BroadcastPrefix'] != null) {
      optimized['bp'] = device['BroadcastPrefix'];
    }

    // Funcs (extraer solo códigos de ProductFuncs o parsear Func)
    final funcs = _extractFuncCodes(device);
    if (funcs.isNotEmpty) {
      optimized['f'] = funcs.join(',');
    }

    // IsPrecise
    if (device['IsPrecise'] != null) {
      optimized['p'] = device['IsPrecise'] == 1;
    }

    // Pics (comprimir URL)
    if (device['Pics'] != null && device['Pics'].toString().isNotEmpty) {
      optimized['pic'] = _compressUrl(device['Pics']);
    }

    // Qrcode (comprimir URL)
    if (device['Qrcode'] != null &&
        device['Qrcode'].toString().isNotEmpty) {
      optimized['qr'] = _compressQrCode(device['Qrcode']);
    }

    return optimized.isEmpty ? null : optimized;
  }

  /// Extrae los códigos de función del dispositivo
  static List<String> _extractFuncCodes(Map<String, dynamic> device) {
    final codes = <String>[];

    // Intentar desde ProductFuncs
    if (device['ProductFuncs'] != null && device['ProductFuncs'] is List) {
      for (var func in device['ProductFuncs']) {
        if (func is Map && func['Code'] != null) {
          codes.add(func['Code'].toString());
        }
      }
    }

    // Si no, parsear desde Func string
    if (codes.isEmpty && device['Func'] != null) {
      try {
        final funcObj = jsonDecode(device['Func']);
        if (funcObj is Map) {
          funcObj.forEach((key, value) {
            if (value == true) {
              codes.add(key);
            }
          });
        }
      } catch (e) {
        // Ignorar
      }
    }

    return codes;
  }

  /// Comprime URL de imagen
  static String _compressUrl(dynamic url) {
    if (url == null || url.toString().isEmpty) return '';

    final urlString = url.toString();

    // Extraer solo la parte única de la URL
    // https://image.zlmicro.com/images/product/20240829/20240829145820520.png
    // → 20240829/20240829145820520.png
    final pattern = RegExp(r'/product/([^?]+)');
    final match = pattern.firstMatch(urlString);

    if (match != null && match.groupCount >= 1) {
      return match.group(1)!;
    }

    return urlString;
  }

  /// Comprime URL de QR Code
  static String _compressQrCode(dynamic url) {
    if (url == null || url.toString().isEmpty) return '';

    final urlString = url.toString();

    // Extraer solo el barcode
    // https://image.zlmicro.com/images/product/qrcode/1001.png
    // → 1001
    final pattern = RegExp(r'/qrcode/(\d+)\.png');
    final match = pattern.firstMatch(urlString);

    if (match != null && match.groupCount >= 1) {
      return match.group(1)!;
    }

    return urlString;
  }

  /// Procesa todos los archivos y genera versión optimizada
  static Future<void> processAllFiles(
      String inputDir, String outputDir) async {
    final files = [
      'jsons_1000.txt',
      'jsons_2000.txt',
      'jsons_3000.txt',
      'jsons_4000.txt',
      'jsons_5000.txt',
      'jsons_7000.txt',
      'jsons_8000.txt',
      'jsons_9000.txt',
    ];

    // Crear directorio de salida
    final outputDirPath = Directory(outputDir);
    if (!await outputDirPath.exists()) {
      await outputDirPath.create(recursive: true);
    }

    var totalOriginalSize = 0;
    var totalOptimizedSize = 0;

    for (final fileName in files) {
      final inputFile = File('$inputDir/$fileName');
      if (!await inputFile.exists()) continue;

      final content = await inputFile.readAsString();
      final optimized = optimizeFile(content);

      // Guardar archivo optimizado
      final outputFile = File('$outputDir/${fileName.replaceAll('.txt', '.json')}');
      await outputFile.writeAsString(optimized);

      // Calcular tamaños
      final originalSize = await inputFile.length();
      final optimizedSize = await outputFile.length();

      totalOriginalSize += originalSize;
      totalOptimizedSize += optimizedSize;

      lvsLog('✅ $fileName: ${(originalSize / 1024).toStringAsFixed(2)} KB → '
          '${(optimizedSize / 1024).toStringAsFixed(2)} KB '
          '(${((1 - optimizedSize / originalSize) * 100).toStringAsFixed(1)}% reducción)');
    }

    lvsLog('\n📊 TOTAL: ${(totalOriginalSize / 1024 / 1024).toStringAsFixed(2)} MB → '
        '${(totalOptimizedSize / 1024 / 1024).toStringAsFixed(2)} MB '
        '(${((1 - totalOptimizedSize / totalOriginalSize) * 100).toStringAsFixed(1)}% reducción)');
  }
}

// ═══════════════════════════════════════════════════════════════
// SCRIPT DE OPTIMIZACIÓN
// ═══════════════════════════════════════════════════════════════

void main() async {
  lvsLog('🚀 Optimizando archivos LoveSpouse...\n');

  const inputDir = 'lib/src/devices/lovespouse/jsons';
  const outputDir = 'lib/src/devices/lovespouse/jsons_optimized';

  await LovespouseOptimizer.processAllFiles(inputDir, outputDir);

  lvsLog('\n✅ Optimización completada!');
  lvsLog('📁 Archivos optimizados en: $outputDir');
}
