# 🔀 Traductor de Protocolo Universal

## Resumen de la Implementación

Se ha implementado un traductor de protocolos universal que convierte comandos de alto nivel (intensidad, patrón) en bytes específicos para cada dispositivo BLE según su metadata del catálogo de Supabase.

---

## 📁 Archivos Creados

| Archivo | Descripción |
|---------|-------------|
| `lib/utils/protocol_translator.dart` | Traductor de protocolos universal |

---

## 🏗️ Arquitectura

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  ToyModel       │────▶│  ProtocolTranslator │────▶│  List<int>      │
│  (Metadata)     │     │  (Traductor)      │     │  (Bytes BLE)    │
└─────────────────┘     └──────────────────┘     └─────────────────┘
       │                        │
       │                        │
  - broadcastPrefix       - wbMSE (3 bytes)
  - motorLogic            - Dual Channel
  - isPrecise             - Prefijos personalizados
  - supportedFuncs        - Checksum XOR
```

---

## 🎯 Protocolos Soportados

### 1. wbMSE Estándar (3 bytes)

**Formato:** `[Prefijo, Intensidad, Checksum]`

```dart
// Ejemplo: Love Spouse 8154
final command = ProtocolTranslator.translate(
  toy: toyModel8154,
  intensity: 75,  // 0-100 o 0-255
);

// Resultado: [0xE6, 0x4B, 0xAD]
// - 0xE6 = Prefijo wbMSE
// - 0x4B = Intensidad 75
// - 0xAD = Checksum (0xE6 ^ 0x4B)
```

**Checksum:** `prefix XOR intensity`

---

### 2. wbMSE Dual Channel

**Formato:** `[CH1_Prefix, Intensity, CH1_Checksum, CH2_Prefix, Intensity, CH2_Checksum]`

```dart
// Dispositivo con motorLogic = "Dual Channel"
final command = ProtocolTranslator.translate(
  toy: dualDevice,
  intensity: 100,
  channel: 1,  // 1 = Empuje, 2 = Vibración, null = Ambos
);

// Canal 1 (Empuje): [0xD5, 0x64, 0xB1]
// Canal 2 (Vibración): [0xA5, 0x64, 0xC1]
```

**Prefijos de Canal:**
| Canal | Función | Prefijo |
|-------|---------|---------|
| CH1 | Empuje/Thrust | `0xD5` |
| CH2 | Vibración | `0xA5` |

---

### 3. wbMSE con Prefijo Personalizado

```dart
// Dispositivo con broadcastPrefix = "E5 15 7D"
final command = ProtocolTranslator.translate(
  toy: customDevice,
  intensity: 128,
);

// Resultado: [0xE5, 0x15, 0x7D, 0x80, 0xXX]
// - Prefijo completo + intensidad + checksum
```

---

### 4. Protocolo Preciso (0-255 directo)

```dart
// Dispositivo con isPrecise = true
final command = ProtocolTranslator.translate(
  toy: preciseDevice,
  intensity: 200,
);

// Resultado: [0xC8] (200 en hex)
```

---

### 5. Protocolo Genérico

```dart
// Dispositivo genérico sin protocolo específico
final command = ProtocolTranslator.translate(
  toy: genericDevice,
  intensity: 150,
);

// Resultado: [0x05] (nivel 5 de 9)
```

---

## 🚀 Uso del Traductor

### Ejemplo Básico

```dart
import 'package:lvs_control/utils/protocol_translator.dart';
import 'package:lvs_control/models/toy_model.dart';

// Obtener modelo del dispositivo
final ToyModel toy = ...;  // Desde catálogo o BLE

// Traducir intensidad a bytes
final command = ProtocolTranslator.translate(
  toy: toy,
  intensity: 75,  // 0-100
);

// Enviar vía flutter_blue_plus
await bleDevice.writeCharacteristic(
  characteristic,
  command.bytes,  // List<int>
);
```

### Ejemplo Dual Channel

```dart
// Enviar solo al canal de empuje (CH1)
final ch1Command = ProtocolTranslator.translate(
  toy: toy,
  intensity: 100,
  channel: 1,  // 1 = Empuje
);

// Enviar solo al canal de vibración (CH2)
final ch2Command = ProtocolTranslator.translate(
  toy: toy,
  intensity: 50,
  channel: 2,  // 2 = Vibración
);

// Enviar a ambos canales
final dualCommand = ProtocolTranslator.translate(
  toy: toy,
  intensity: 75,
  channel: null,  // Ambos
);
```

### Comandos Especiales

```dart
// Parada de emergencia
final stopCommand = ProtocolTranslator.translateStop(toy: toy);

// Pulsación (tap)
final tapCommand = ProtocolTranslator.generateTapCommand(
  toy: toy,
  intensity: 30,
);

// Emergencia (máxima intensidad)
final emergencyCommand = ProtocolTranslator.generateEmergencyCommand(toy: toy);
```

---

## 📊 Detección Automática de Protocolo

El traductor detecta automáticamente el protocolo según:

### 1. `isPrecise` (Protocolo Preciso)
```dart
if (toy.isPrecise) {
  // Usa ProtocolType.precise
  // Intensidad directa 0-255
}
```

### 2. `motorLogic` (Dual Channel)
```dart
if (toy.motorLogic.toLowerCase().contains('dual')) {
  // Usa ProtocolType.wbMSEDual
  // Canales independientes CH1/CH2
}
```

### 3. `broadcastPrefix` (wbMSE)
```dart
if (prefix.contains('wbmse') || 
    prefix.contains('77 62 4d 53 45') ||
    modelId.contains('8154') || 
    modelId.contains('8039')) {
  // Usa ProtocolType.wbMSE o wbMSECustom
}
```

### 4. `supportedFuncs` (Prefijos Personalizados)
```dart
// Soporta patrones como "CH1:0xD5" o "CH2:0xA5"
final prefixes = _parseCustomPrefixes(toy.supportedFuncs);
```

---

## 🔧 Clase ProtocolCommand

### Propiedades

```dart
class ProtocolCommand {
  final List<int> bytes;           // Bytes listos para BLE
  final int channel;               // 0 = Dual, 1 = CH1, 2 = CH2
  final int intensity;             // Intensidad 0-255
  final ProtocolType protocolType; // Tipo detectado
  final String description;        // Descripción legible
}
```

### Métodos de Utilidad

```dart
final command = ProtocolTranslator.translate(...);

command.isValid;        // true si bytes.isNotEmpty
command.commandByte;    // Primer byte (prefijo)
command.lastByte;       // Último byte (checksum)
command.isDualChannel;  // true si channel == 0
command.isChannel1;     // true si channel == 1
command.isChannel2;     // true si channel == 2
```

---

## 📡 Integración con BLE Service

### Ejemplo Completo

```dart
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:lvs_control/utils/protocol_translator.dart';

class BleService {
  final BluetoothDevice? _device;
  
  Future<void> setIntensity(int intensity, ToyModel toy) async {
    // Traducir protocolo
    final command = ProtocolTranslator.translate(
      toy: toy,
      intensity: intensity,
    );
    
    // Enviar vía BLE
    await _device?.writeCharacteristic(
      _characteristic,
      command.bytes,
      withoutResponse: true,
    );
    
    print('Enviado: ${command.description}');
  }
  
  Future<void> setDualChannel(
    int ch1Intensity,
    int ch2Intensity,
    ToyModel toy,
  ) async {
    // Canal 1 (Empuje)
    final ch1Command = ProtocolTranslator.translate(
      toy: toy,
      intensity: ch1Intensity,
      channel: 1,
    );
    
    // Canal 2 (Vibración)
    final ch2Command = ProtocolTranslator.translate(
      toy: toy,
      intensity: ch2Intensity,
      channel: 2,
    );
    
    // Enviar ambos
    await _device?.writeCharacteristic(
      _characteristic,
      [...ch1Command.bytes, ...ch2Command.bytes],
      withoutResponse: true,
    );
  }
}
```

---

## 🔍 Depuración

### Logs de Comandos

```dart
final command = ProtocolTranslator.translate(
  toy: toy,
  intensity: 75,
);

print(command.description);
// Salida: "wbMSE Standard: [0xe6, 0x4b, 0xad]"
```

### Verificación de Protocolo

```dart
final protocolType = ProtocolTranslator.detectProtocolType(toy);

switch (protocolType) {
  case ProtocolType.wbMSE:
    print('Protocolo: wbMSE Estándar');
  case ProtocolType.wbMSEDual:
    print('Protocolo: Dual Channel');
  case ProtocolType.precise:
    print('Protocolo: Preciso 0-255');
  default:
    print('Protocolo: Genérico');
}
```

---

## ⚠️ Consideraciones Importantes

### 1. Normalización de Intensidad

El traductor normaliza automáticamente:
- **0-100** → Escala a **0-255**
- **0-255** → Mantiene sin cambios
- **>255** → Clamp a **255**
- **<0** → Clamp a **0**

```dart
// Estos son equivalentes
ProtocolTranslator.translate(toy: toy, intensity: 50);   // 50%
ProtocolTranslator.translate(toy: toy, intensity: 128);  // ~50% en 0-255
```

### 2. Checksum XOR

El checksum se calcula como:
```
checksum = prefix XOR intensity
```

Esto permite validar la integridad del comando en el dispositivo.

### 3. Prefijos Hexadecimales

El traductor soporta múltiples formatos:
```dart
// Válidos:
"77 62 4d 53 45"     // Con espacios
"77624d5345"         // Sin espacios
"wbmse"              // Nombre legible
```

---

## 🧪 Testing

### Prueba con Dispositivo Real

```dart
// Love Spouse 8154
final toy8154 = ToyModel(
  id: '8154',
  name: 'Love Spouse 8154',
  broadcastPrefix: '77 62 4d 53 45',
  motorLogic: 'Single Channel',
  isPrecise: false,
  supportedFuncs: '',
);

final command = ProtocolTranslator.translate(
  toy: toy8154,
  intensity: 100,
);

assert(command.bytes.length == 3);
assert(command.bytes[0] == 0xE6);  // Prefijo wbMSE
assert(command.protocolType == ProtocolType.wbMSE);
```

### Prueba Dual Channel

```dart
final dualToy = ToyModel(
  id: 'dual_001',
  name: 'Dual Motor Device',
  broadcastPrefix: '77 62 4d 53 45',
  motorLogic: 'Dual Channel',
  isPrecise: false,
  supportedFuncs: 'CH1:0xD5,CH2:0xA5',
);

// Canal 1
final ch1 = ProtocolTranslator.translate(
  toy: dualToy,
  intensity: 150,
  channel: 1,
);
assert(ch1.bytes[0] == 0xD5);

// Canal 2
final ch2 = ProtocolTranslator.translate(
  toy: dualToy,
  intensity: 100,
  channel: 2,
);
assert(ch2.bytes[0] == 0xA5);
```

---

## 📚 Referencias de Protocolos

### Modelos Soportados

| Modelo | Protocolo | Prefijo | Canales |
|--------|-----------|---------|---------|
| Love Spouse 8154 | wbMSE | 0xE6 | Single |
| Love Spouse 8039 | wbMSE | 0xE6 | Single |
| THERM_MAX_80 | wbMSE Custom | Variable | Dual |
| Genéricos | Generic | - | Single |

### Prefijos Conocidos

| Prefijo (Hex) | Función |
|---------------|---------|
| `0xE6` | wbMSE Standard |
| `0xD5` | Dual Channel CH1 (Empuje) |
| `0xA5` | Dual Channel CH2 (Vibración) |
| `0xE5` | wbMSE Custom (algunos modelos) |

---

## ✅ Checklist de Implementación

- [x] Clase `ProtocolTranslator` creada
- [x] Lógica wbMSE (3 bytes) implementada
- [x] Mapeo de canales Dual Channel
- [x] Soporte para prefijos personalizados
- [x] Cálculo de checksum XOR
- [x] Detección automática de protocolo
- [x] Normalización de intensidad (0-100 → 0-255)
- [x] Comandos especiales (stop, emergency, tap)
- [x] Documentación completada

---

## 🔗 Recursos Adicionales

- [flutter_blue_plus Package](https://pub.dev/packages/flutter_blue_plus)
- [Protocolo wbMSE Documentation](https://github.com/wbmse/protocol)
- [BLE Characteristic Writing Guide](https://developer.android.com/guide/topics/connectivity/bluetooth-le)
