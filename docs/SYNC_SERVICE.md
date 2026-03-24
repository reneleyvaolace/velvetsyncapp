# 🔄 Sincronización en Tiempo Real con Supabase

## Resumen de la Implementación

Se ha implementado un sistema de sincronización en tiempo real utilizando **Supabase Realtime** para escuchar cambios en la tabla `device_sync` y emitir eventos al sistema cuando se reciben comandos, especialmente `APPLY_AI_PROFILE`.

---

## 📁 Archivos Creados

| Archivo | Descripción |
|---------|-------------|
| `lib/models/device_sync_model.dart` | Modelo `DeviceSyncEvent` para eventos de sincronización |
| `lib/services/sync_service.dart` | Servicio con providers Riverpod para sincronización |
| `lib/main.dart` | Actualizado con inicialización del SyncService |

---

## 🏗️ Arquitectura

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Supabase DB   │────▶│  SyncService     │────▶│  System Events  │
│  device_sync    │     │  (Realtime)      │     │  (AI Profile)   │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                               │
                               ▼
                        ┌──────────────────┐
                        │  Riverpod        │
                        │  Providers       │
                        └──────────────────┘
```

---

## 📊 Modelo de Datos: DeviceSyncEvent

### Propiedades

```dart
class DeviceSyncEvent {
  final String id;           // ID único del evento
  final String deviceId;     // ID del dispositivo destino
  final String command;      // Tipo de comando
  final Map<String, dynamic> payload;  // Datos adicionales
  final DateTime timestamp;  // Timestamp del evento
  final String? sessionId;   // ID de sesión (opcional)
  final String? userId;      // ID de usuario (opcional)
}
```

### Comandos Soportados

| Comando | Descripción | Payload Ejemplo |
|---------|-------------|-----------------|
| `APPLY_AI_PROFILE` | Aplicar perfil de IA | `{"intensity": 75, "pattern": 3}` |
| `SET_INTENSITY` | Establecer intensidad | `{"intensity": 50}` |
| `SET_PATTERN` | Establecer patrón | `{"pattern": 2}` |
| `SET_SPEED` | Establecer velocidad | `{"speed": "medium"}` |
| `STOP` | Detener dispositivo | `{}` |
| `EMERGENCY_STOP` | Parada de emergencia | `{}` |
| `SYNC_STATE` | Sincronizar estado | `{"state": "active"}` |

---

## 🚀 Uso del Servicio

### 1. Inicialización (Automática)

El servicio se inicializa automáticamente en `main.dart`:

```dart
void main() async {
  // ... otras inicializaciones
  
  // Inicializar Sincronización en Tiempo Real
  final syncService = SyncService();
  await syncService.init();
  
  runApp(...);
}
```

### 2. Escuchar Eventos con Riverpod

#### Stream de Todos los Eventos

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lvs_control/services/sync_service.dart';

class MiWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escuchar stream de eventos
    final eventsAsync = ref.watch(syncEventsProvider);
    
    return eventsAsync.when(
      data: (events) => ListView.builder(
        itemCount: events.length,
        itemBuilder: (_, i) => Text(events[i].command),
      ),
      loading: () => CircularProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
    );
  }
}
```

#### Último Evento Recibido

```dart
class MiWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastEvent = ref.watch(lastSyncEventProvider);
    
    if (lastEvent == null) return Text('Sin eventos');
    
    return Text('Último: ${lastEvent.command}');
  }
}
```

#### Estado del Canal

```dart
class MiWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncChannelStateProvider);
    
    switch (state) {
      case SyncChannelState.receiving:
        return Text('🟢 Conectado');
      case SyncChannelState.error:
        return Text('🔴 Error');
      default:
        return Text('🟡 Conectando...');
    }
  }
}
```

---

## 🎯 Escuchar Eventos APPLY_AI_PROFILE

### Método 1: Usando addAiProfileListener

```dart
class MiComponente extends ConsumerStatefulWidget {
  @override
  _MiComponenteState createState() => _MiComponenteState();
}

class _MiComponenteState extends ConsumerState<MiComponente> {
  @override
  void initState() {
    super.initState();
    
    // Registrar listener para eventos AI Profile
    final syncService = ref.read(syncServiceProvider);
    syncService.addAiProfileListener(_onAiProfile);
  }
  
  @override
  void dispose() {
    final syncService = ref.read(syncServiceProvider);
    syncService.removeAiProfileListener(_onAiProfile);
    super.dispose();
  }
  
  void _onAiProfile(DeviceSyncEvent event) {
    // El comando es APPLY_AI_PROFILE
    final intensity = event.intensity;
    final pattern = event.pattern;
    
    print('AI Profile: intensidad=$intensity, patrón=$pattern');
    
    // Aplicar el perfil al dispositivo
    // ble.setProfile(intensity, pattern);
  }
}
```

### Método 2: Filtrando del Stream

```dart
class MiComponente extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(syncEventsProvider);
    
    return eventsAsync.when(
      data: (events) {
        // Filtrar solo eventos AI Profile
        final aiEvents = events
            .where((e) => e.command == 'APPLY_AI_PROFILE')
            .toList();
        
        return ListView.builder(
          itemCount: aiEvents.length,
          itemBuilder: (_, i) {
            final event = aiEvents[i];
            return ListTile(
              title: Text('AI Profile #${event.intensity}'),
              subtitle: Text('Device: ${event.deviceId}'),
            );
          },
        );
      },
      loading: () => CircularProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
    );
  }
}
```

---

## 📡 Base de Datos: Tabla device_sync

### Estructura Recomendada

```sql
CREATE TABLE device_sync (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id TEXT NOT NULL,
  command TEXT NOT NULL,
  payload JSONB DEFAULT '{}',
  session_id UUID,
  user_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índice para consultas rápidas
CREATE INDEX idx_device_sync_device_id ON device_sync(device_id);
CREATE INDEX idx_device_sync_command ON device_sync(command);
CREATE INDEX idx_device_sync_created_at ON device_sync(created_at DESC);

-- Habilitar Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE device_sync;
```

### Insertar un Evento (Ejemplo)

```sql
-- Insertar comando APPLY_AI_PROFILE
INSERT INTO device_sync (device_id, command, payload, session_id)
VALUES (
  'device_123',
  'APPLY_AI_PROFILE',
  '{"intensity": 75, "pattern": 3, "duration": 300}',
  'session_abc'
);
```

---

## 🔧 Métodos del SyncService

### Públicos

| Método | Descripción |
|--------|-------------|
| `init()` | Inicializa el servicio |
| `dispose()` | Cierra el canal y limpia recursos |
| `addAiProfileListener(callback)` | Registra listener para AI Profile |
| `removeAiProfileListener(callback)` | Remueve listener |
| `getEventsForDevice(deviceId)` | Obtiene eventos de un dispositivo |
| `getEventsByCommand(command)` | Obtiene eventos por comando |
| `clearHistory()` | Limpia el historial de eventos |
| `pruneOldEvents()` | Remueve eventos antiguos (>5 min) |

### Propiedades

| Propiedad | Tipo | Descripción |
|-----------|------|-------------|
| `recentEvents` | `List<DeviceSyncEvent>` | Últimos 50 eventos |
| `lastEvent` | `DeviceSyncEvent?` | Último evento |
| `state` | `SyncChannelState` | Estado del canal |
| `isInitialized` | `bool` | Si está inicializado |
| `isReceiving` | `bool` | Si está recibiendo eventos |

---

## 📊 Logs y Actividad

El servicio registra toda la actividad:

```
[SyncService] Iniciando servicio de sincronización...
[SyncService] Canal suscrito exitosamente
[SYNC] Canal public:device_sync suscrito
[SyncService] Cambio detectado
[SyncService] Evento recibido: APPLY_AI_PROFILE para device_123
[SYNC] APPLY_AI_PROFILE -> device_123
[SyncService] Notificando 2 listeners de AI Profile
```

---

## ⚠️ Consideraciones Importantes

### 1. Permisos de Supabase (RLS)

Configura Row Level Policies apropiadas:

```sql
-- Permitir lectura a todos los usuarios autenticados
CREATE POLICY "Usuarios autenticados pueden leer device_sync"
  ON device_sync FOR SELECT
  TO authenticated
  USING (true);

-- Permitir inserción solo a usuarios autenticados
CREATE POLICY "Usuarios autenticados pueden insertar en device_sync"
  ON device_sync FOR INSERT
  TO authenticated
  WITH CHECK (true);
```

### 2. Manejo de Errores

El servicio maneja errores automáticamente, pero es recomendable:

```dart
try {
  final syncService = ref.read(syncServiceProvider);
  await syncService.init();
} catch (e) {
  print('Error inicializando SyncService: $e');
  // Mostrar mensaje al usuario
}
```

### 3. Memoria y Performance

- El servicio mantiene solo los últimos **50 eventos** en memoria
- Los eventos mayores a **5 minutos** se eliminan automáticamente
- El canal usa **heartbeat** cada 30 segundos para mantener conexión

---

## 🧪 Testing

### Insertar Evento de Prueba

```sql
-- Desde SQL Editor de Supabase
INSERT INTO device_sync (device_id, command, payload)
VALUES (
  'test_device',
  'APPLY_AI_PROFILE',
  '{"intensity": 50, "pattern": 2}'
);
```

### Ver Logs en Tiempo Real

```bash
flutter run | grep -i "SYNC\|SyncService"
```

---

## 🔗 Integración con Otros Servicios

### BLE Service

```dart
// En el listener de AI Profile
void _onAiProfile(DeviceSyncEvent event) {
  final ble = ref.read(bleProvider);
  
  if (ble.isConnected) {
    // Aplicar intensidad y patrón
    ble.setProportionalChannel1(event.intensity ?? 50);
    ble.setPatternChannel1(event.pattern ?? 1);
  }
}
```

### AI Service

```dart
// Cuando AI Service genera un perfil
final aiService = ref.read(aiServiceProvider);
final profile = await aiService.generateProfile(context);

// Insertar en Supabase para sincronizar
await supabase.client.from('device_sync').insert({
  'device_id': ble.activeToy?.id,
  'command': 'APPLY_AI_PROFILE',
  'payload': {
    'intensity': profile.intensity,
    'pattern': profile.pattern,
    'source': 'ai_service'
  }
});
```

---

## ✅ Checklist de Implementación

- [x] Modelo `DeviceSyncEvent` creado
- [x] `fromMap()` y `toMap()` implementados
- [x] `SyncService` con Riverpod providers
- [x] Canal `public:device_sync` configurado
- [x] Filtrado de eventos INSERT
- [x] Emisión de eventos `APPLY_AI_PROFILE`
- [x] Listeners específicos para AI Profile
- [x] Integración en `main.dart`
- [x] Documentación completada

---

## 📚 Recursos Adicionales

- [Supabase Realtime Documentation](https://supabase.com/docs/guides/realtime)
- [realtime_client Package](https://pub.dev/packages/realtime_client)
- [Riverpod Documentation](https://riverpod.dev/)
