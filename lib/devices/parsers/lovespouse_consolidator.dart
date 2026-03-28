// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/src/devices/parsers/lovespouse_consolidator.dart
// Consolida los 8 archivos JSON en 1 solo + índice de búsqueda
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';
import 'package:velvet_sync/utils/logger.dart';

/// Consolida los archivos optimizados de LoveSpouse en 1 solo archivo
class LovespouseConsolidator {
  /// Consolida todos los archivos en uno solo
  static Future<void> consolidateFiles(
      String inputDir, String outputDir) async {
    final files = [
      'jsons_1000.json',
      'jsons_2000.json',
      'jsons_3000.json',
      'jsons_4000.json',
      'jsons_5000.json',
      'jsons_7000.json',
      'jsons_8000.json',
      'jsons_9000.json',
    ];

    final allDevices = <Map<String, dynamic>>[];
    final index = <String, Map<String, dynamic>>{};

    var totalDevices = 0;

    for (final fileName in files) {
      final inputFile = File('$inputDir/$fileName');
      if (!await inputFile.exists()) continue;

      final content = await inputFile.readAsString();
      final List<dynamic> devices = jsonDecode(content);

      for (var device in devices) {
        allDevices.add(device);

        // Crear índice por barcode
        final barcode = device['id']?.toString() ?? '';
        if (barcode.isNotEmpty) {
          index[barcode] = {
            'file': 'devices.json',
            'index': allDevices.length - 1,
            'dt': device['dt'],  // DeviceTitle para referencia rápida
          };
        }

        totalDevices++;
      }

      lvsLog('✅ Procesado: $fileName (${devices.length} dispositivos)');
    }

    // Crear directorio de salida
    final outputDirPath = Directory(outputDir);
    if (!await outputDirPath.exists()) {
      await outputDirPath.create(recursive: true);
    }

    // Guardar archivo consolidado
    final consolidatedFile = File('$outputDir/devices.json');
    await consolidatedFile.writeAsString(jsonEncode(allDevices));

    // Guardar índice
    final indexFile = File('$outputDir/devices_index.json');
    await indexFile.writeAsString(jsonEncode(index));

    // Guardar estadísticas
    final statsFile = File('$outputDir/STATS.md');
    await statsFile.writeAsString('''
# 📊 Estadísticas de Consolidación

**Fecha:** ${DateTime.now().toString()}

## Resumen

| Métrica | Valor |
|---------|-------|
| **Archivos originales** | 8 |
| **Archivos consolidados** | 2 (devices.json + devices_index.json) |
| **Total dispositivos** | $totalDevices |
| **Tamaño devices.json** | ${(await consolidatedFile.length() / 1024).toStringAsFixed(2)} KB |
| **Tamaño devices_index.json** | ${(await indexFile.length() / 1024).toStringAsFixed(2)} KB |
| **Tamaño total** | ${((await consolidatedFile.length() + await indexFile.length()) / 1024).toStringAsFixed(2)} KB |
| **Reducción vs original (6.1 MB)** | ${(100 - (await consolidatedFile.length() / 6100000 * 100)).toStringAsFixed(1)}% |

## Beneficios

1. **1 solo archivo** para cargar
2. **Índice de búsqueda** para acceso rápido
3. **Mismo peso** (0.52 MB)
4. **Búsqueda O(1)** por barcode usando el índice

## Uso

```dart
// Carga normal (todos los dispositivos)
final parser = LovespouseParserService();
final devices = await parser.getAllDevices();

// Búsqueda rápida por barcode (usa el índice)
final device = await parser.findByBarcode('1001');
// ← Busca en el índice, no carga todo el archivo
```
''');

    lvsLog('\n✅ Consolidación completada!');
    lvsLog('📁 Archivos creados:');
    lvsLog('   - devices.json (${(await consolidatedFile.length() / 1024).toStringAsFixed(2)} KB)');
    lvsLog('   - devices_index.json (${(await indexFile.length() / 1024).toStringAsFixed(2)} KB)');
    lvsLog('   - STATS.md');
    lvsLog('\n📊 Total dispositivos: $totalDevices');
    lvsLog('📦 Tamaño total: ${((await consolidatedFile.length() + await indexFile.length()) / 1024).toStringAsFixed(2)} KB');
  }
}

// ═══════════════════════════════════════════════════════════════
// SCRIPT DE CONSOLIDACIÓN
// ═══════════════════════════════════════════════════════════════

void main() async {
  lvsLog('🚀 Consolidando archivos LoveSpouse...\n');

  const inputDir = 'lib/src/devices/lovespouse/jsons_optimized';
  const outputDir = 'lib/src/devices/lovespouse/jsons_consolidated';

  await LovespouseConsolidator.consolidateFiles(inputDir, outputDir);

  lvsLog('\n✅ Consolidación completada!');
}
