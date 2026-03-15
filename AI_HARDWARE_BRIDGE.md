# 🌉 Puente IA-Hardware (AI Hardware Bridge)

## Resumen de la Implementación

Se ha implementado el puente final que conecta la IA de la web con el hardware físico a través de la aplicación Velvet Sync. Este puente escucha eventos `APPLY_AI_PROFILE` del servicio de sincronización y los traduce a comandos BLE usando el `ProtocolTranslator`.

---

## 📁 Archivos Creados

| Archivo | Descripción |
|---------|-------------|
| `lib/services/ai_hardware_bridge_service.dart` | Puente IA-Hardware |
| `lib/ble/ble_service.dart` | Actualizado con notificación al AI Bridge |
| `lib/main.dart` | Inicialización del AIHardwareBridge |

---

## 🏗️ Arquitectura del Flujo

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  IA Web         │────▶│  Supabase DB     │────▶│  SyncService    │
│  (Comandos)     │     │  device_sync     │     │  (Realtime)     │
└─────────────────┘     └──────────────────┘     └────────┬────────┘
                                                          │
                                                          ▼
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Hardware BLE   │◀────│  ProtocolTranslator │◀───│  AIHardwareBridge │
│  (Dispositivo)  │     │  (Traductor)      │     │  (Manejador)    │
└─────────────────┘     └──────────────────┘     └─────────────────┘
```

---

## 🎯 Componentes Principales

### 1. AIHardwareBridge

Escucha eventos `APPLY_AI_PROFILE` y los procesa:

```dart
class AIHardwareBridge extends ChangeNotifier {
  // Escucha eventos del SyncService
  void _handleAIProfile(DeviceSyncEvent event) {
    // 1. Extraer intensity_map
    // 2. Verificar Guards
    // 3. Traducir protocolo
    // 4. Enviar a BLE
  }
}
```

### 2. PreciseControlGuard

Verifica si el dispositivo admite control preciso (0-255):

```dart
class PreciseControlGuardResult {
  final bool isPrecise;      // Si admite 0-255
  final bool allowed;        // Si el guard permitió el envío
  final String? reason;      // Razón si fue bloqueado
  final int adjustedIntensity; // Intensidad ajustada
}
```

### 3. ProtocolTranslator

Traduce intensidad a bytes específicos del dispositivo:

```dart
final command = ProtocolTranslator.translate(
  toy: toy,
  intensity: 75,
  channel: 1,  // 1 = Empuje, 2 = Vibración
);
// Retorna: List<int> bytes listos para BLE
```

---

## 🚀 Flujo de Ejecución

### Paso 1: IA Envía Comando

La IA web inserta un evento en Supabase:

```sql
INSERT INTO device_sync (device_id, command, payload)
VALUES (
  'device_123',
  'APPLY_AI_PROFILE',
  '{"intensity": 75, "intensity_ch1": 50, "intensity_ch2": 80}'
);
```

### Paso 2: SyncService Detecta Cambio

El canal de realtime detecta el INSERT:

```dart
// En SyncService
_channel.onPostgresChanges(
  event: PostgresChangeEvent.insert,
  callback: _onDatabaseChange,
);
```

### Paso 3: AIHardwareBridge Procesa

El bridge recibe el evento:

```dart
// En AIHardwareBridge
_syncService.addAiProfileListener(_handleAIProfile);

void _handleAIProfile(DeviceSyncEvent event) {
  // 1. Extraer intensity_map
  final intensityMap = _extractIntensityMap(event.payload);
  
  // 2. Verificar Guard
  final guardResult = _preciseControlGuard(
    toy: _currentToy!,
    intensity: intensityMap['intensity'] ?? 0,
  );
  
  if (!guardResult.allowed) return;
  
  // 3. Traducir protocolo
  final command = ProtocolTranslator.translate(
    toy: _currentToy!,
    intensity: guardResult.adjustedIntensity,
  );
  
  // 4. Enviar a BLE
  await _sendBleCommand(command.bytes, 'AI');
}
```

### Paso 4: BLE Envía al Hardware

El BleService envía los bytes:

```dart
// En BleService
await writeCommand(bytes, label: 'AI', silent: false);
```

---

## 📊 Formatos de Payload Soportados

El AIHardwareBridge soporta múltiples formatos de payload:

### Formato 1: Intensidad Única

```json
{
  "intensity": 75
}
```

### Formato 2: Dual Channel

```json
{
  "intensity_ch1": 50,
  "intensity_ch2": 80
}
```

### Formato 3: Intensity Map Anidado

```json
{
  "intensity_map": {
    "ch1": 50,
    "ch2": 80
  }
}
```

### Formato 4: Con Patrón

```json
{
  "pattern": 3,
  "intensity": 60
}
```

---

## 🔒 Guards de Seguridad

### 1. Precise Control Guard

Verifica la propiedad `isPrecise` del modelo:

```dart
PreciseControlGuardResult _preciseControlGuard({
  required ToyModel toy,
  required int intensity,
}) {
  if (toy.isPrecise) {
    // Dispositivo preciso: permite 0-255
    return PreciseControlGuardResult.allowed(intensity, true);
  }
  
  // Dispositivo no preciso: limitar a 0-100
  if (intensity > 100) {
    return PreciseControlGuardResult(
      isPrecise: false,
      allowed: true,
      reason: null,
      adjustedIntensity: 100,  // Ajustar
    );
  }
  
  return PreciseControlGuardResult.allowed(intensity, false);
}
```

### 2. Safety Guard (Cooldown)

Verifica cooldown y estado de conexión:

```dart
bool _safetyGuard() {
  // Verificar cooldown
  if (_bleService?.isCooldownActive == true) {
    return false;  // Bloqueado
  }
  
  // Verificar conexión BLE
  if (_bleService?.isConnected != true) {
    return false;  // Bloqueado
  }
  
  return true;  // Permitido
}
```

---

## 🔧 Uso del AIHardwareBridge

### Inicialización (Automática en main.dart)

```dart
void main() async {
  // ... otras inicializaciones
  
  // Inicializar Puente IA-Hardware
  final aiBridge = AIHardwareBridge();
  await aiBridge.init();
  
  runApp(...);
}
```

### Ejecutar Comando Manualmente

```dart
// Obtener el bridge desde Riverpod
final aiBridge = ref.read(aiHardwareBridgeProvider);

// Ejecutar comando
await aiBridge.executeAICommand(
  intensity: 75,
  channel: 1,  // Opcional: 1 = Empuje, 2 = Vibración
  pattern: 3,  // Opcional: patrón 1-9
);
```

### Escuchar Estado del Puente

```dart
class MiWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiBridgeStateProvider);
    final lastEvent = ref.watch(lastProcessedAIEventProvider);
    
    return Column(
      children: [
        Text('Estado: ${state.name}'),
        if (lastEvent != null)
          Text('Último evento: ${lastEvent.command}'),
      ],
    );
  }
}
```

---

## 📡 Integración con BleService

El BleService notifica automáticamente al AIHardwareBridge cuando se conecta un dispositivo:

```dart
// En BleService.setActiveToy()
void setActiveToy(ToyModel toy) {
  activeToy = toy;
  
  // Notificar al AI Hardware Bridge
  _notifyAIBridge(toy);
  
  notifyListeners();
}

void _notifyAIBridge(ToyModel toy) {
  final aiBridge = AIHardwareBridge();
  aiBridge.setCurrentToy(toy);
}
```

---

## 🧪 Ejemplo de Flujo Completo

### 1. Usuario Conecta Dispositivo

```dart
// En la UI
final ble = ref.read(bleProvider);
ble.setActiveToy(toyModel);  // toyModel desde catálogo
```

### 2. IA Envía Comando desde Web

```javascript
// En la web de IA
await supabase
  .from('device_sync')
  .insert({
    device_id: 'device_123',
    command: 'APPLY_AI_PROFILE',
    payload: {
      intensity: 75,
      intensity_ch1: 50,
      intensity_ch2: 80
    }
  });
```

### 3. App Procesa y Ejecuta

```
[Supabase] → [SyncService] → [AIHardwareBridge] → [ProtocolTranslator] → [BleService] → [Hardware]
```

**Logs esperados:**

```
[SYNC] Canal public:device_sync suscrito
[SYNC] APPLY_AI_PROFILE -> device_123
[AI_BRIDGE] Evento AI Profile recibido: abc123
[AI_BRIDGE] Intensity Map: {intensity_ch1: 50, intensity_ch2: 80}
[AI_BRIDGE Guard] Dispositivo PRECISE - Permitido 0-255
[AIHardwareBridge] Dual Channel: CH1=50, CH2=80
[AIHardwareBridge] CH1 Bytes: [213, 50, 163]
[AIHardwareBridge] CH2 Bytes: [165, 80, 245]
[AI_BRIDGE] AI Dual: CH1=wbMSE Canal 1 (Empuje)...
```

---

## ⚠️ Consideraciones Importantes

### 1. isPrecise del Catálogo

La propiedad `isPrecise` del `ToyModel` determina si el dispositivo admite 0-255:

```dart
// Desde Supabase
{
  "is_precise_new": true,  // o "0-255" en CSV
  "broadcast_prefix": "77 62 4d 53 45"
}
```

### 2. Dual Channel

Si `motorLogic` contiene "dual", se manejan canales separados:

```dart
if (toy.hasDualChannel) {  // motorLogic.contains('dual')
  // Enviar a CH1 y CH2 por separado
} else {
  // Enviar único comando
}
```

### 3. Cooldown

El cooldown bloquea eventos durante 60 segundos después de una parada de emergencia:

```dart
if (_bleService?.isCooldownActive == true) {
  // Evento bloqueado hasta que cooldown termine
}
```

---

## 🔍 Depuración

### Logs del Puente

```dart
// Habilitar logs detallados
[AI_BRIDGE] Puente IA-Hardware conectado
[AI_BRIDGE] AI Profile: APPLY_AI_PROFILE para device_123
[AI_BRIDGE] Intensity Map: {intensity: 75}
[AI_BRIDGE] Guard bloqueó AI: Dispositivo no preciso
[AI_BRIDGE] AI Dual: CH1=[...], CH2=[...]
[AI_BRIDGE] AI Profile ejecutado exitosamente
```

### Ver Estado del Puente

```dart
final aiBridge = ref.read(aiHardwareBridgeProvider);

print('Estado: ${aiBridge.state}');
print('Último evento: ${aiBridge.lastProcessedEvent}');
print('Ejecutando: ${aiBridge.isExecuting}');
```

---

## 📚 Providers de Riverpod

| Provider | Tipo | Descripción |
|----------|------|-------------|
| `aiHardwareBridgeProvider` | `Provider<AIHardwareBridge>` | Singleton del puente |
| `aiBridgeStateProvider` | `StateProvider<AIBridgeState>` | Estado actual |
| `lastProcessedAIEventProvider` | `StateProvider<DeviceSyncEvent?>` | Último evento procesado |

---

## ✅ Checklist de Implementación

- [x] AIHardwareBridge creado
- [x] Manejador `_handleAIProfile` implementado
- [x] Extracción de `intensity_map` del payload
- [x] Integración con `ProtocolTranslator`
- [x] Guard de Precise Control (`isPrecise`)
- [x] Soporte Dual Channel (CH1/CH2)
- [x] Envío de bytes a BLE
- [x] Notificación desde BleService
- [x] Inicialización en `main.dart`
- [x] Documentación completada

---

## 🔗 Recursos Adicionales

- [Sync Service Documentation](./SYNC_SERVICE.md)
- [Protocol Translator Documentation](./PROTOCOL_TRANSLATOR.md)
- [Deep Linking Documentation](./DEEP_LINKING.md)
