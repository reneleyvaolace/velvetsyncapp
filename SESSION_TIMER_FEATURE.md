# ⏱️ Temporizador de Sesión - Velvet Sync

## 📋 Resumen

El **Temporizador de Sesión** es una funcionalidad de seguridad que permite configurar un tiempo máximo para cada sesión de uso. Al finalizar el tiempo, el dispositivo se detiene automáticamente.

---

## 🎯 Características

| Característica | Descripción |
|----------------|-------------|
| **Duración configurable** | 5 a 120 minutos (en incrementos de 5) |
| **Auto-stop** | Detiene el dispositivo BLE automáticamente |
| **Cuenta regresiva** | Visualización en tiempo real (MM:SS) |
| **Barra de progreso** | Indicador visual del avance |
| **Advertencias** | Notificaciones a los 60s y 10s restantes |
| **Persistencia** | Guarda configuración en SharedPreferences |
| **Pausar/Reanudar** | Control total durante la sesión |
| **Seguridad** | Previene uso excesivo prolongado |

---

## 🚀 Cómo Usar

### **1. Configurar Temporizador**

1. Ir a **Settings Tab** (pestaña Sistema)
2. Tocar **"TEMPORIZADOR DE SESIÓN"**
3. Seleccionar duración en el selector (5-120 minutos)
4. Tocar **"INICIAR"**

### **2. Durante la Sesión**

La UI mostrará:
- ⏱️ Ícono de timer activo (animado)
- 🔴/🟢 Indicador de estado
- ⏰ Tiempo restante grande (MM:SS)
- ▓▓▓▓▓▓▓▓ Barra de progreso
- 📝 Texto "Auto-desconexión en XX:XX"

**Opciones disponibles:**
- **Pausar:** Detiene temporalmente la cuenta regresiva
- **Detener:** Cancela y resetea el temporizador

### **3. Al Expirar**

Cuando el tiempo llega a cero:
1. 🔴 **Auto-stop:** El dispositivo BLE se detiene
2. 🔔 **Notificación:** SnackBar "⏰ TIEMPO EXPIRADO - Sesión finalizada"
3. 📊 **UI:** Vuelve al estado inicial

---

## 🏗️ Arquitectura Técnica

### **Componentes**

```
┌─────────────────────────────────────────────────────────────┐
│                    SettingsTab (UI)                         │
│  - Muestra estado del temporizador                          │
│  - Dialog de configuración                                  │
│  - Botones de acción (iniciar/pausar/detener)               │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              SessionTimerService (Lógica)                   │
│  - Timer periódico (1 segundo)                              │
│  - Persistencia SharedPreferences                           │
│  - Callback de expiración                                   │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              BleService (Ejecución)                         │
│  - emergencyStop() al expirar                               │
│  - Detiene burst + sequencer                                │
│  - Envía comando STOP al dispositivo                        │
└─────────────────────────────────────────────────────────────┘
```

---

## 📁 Archivos

| Archivo | Propósito |
|---------|-----------|
| `lib/services/session_timer_service.dart` | Servicio principal con lógica y providers |
| `lib/screens/tabs/settings_tab.dart` | UI integrada en Settings Tab |
| `pubspec.yaml` | Dependencia `shared_preferences` |

---

## 🔧 API del Servicio

### **SessionTimerService**

```dart
// Obtener servicio
final timerService = ref.read(sessionTimerServiceProvider);

// Escuchar estado
final timerState = ref.watch(sessionTimerStateProvider);
```

### **Métodos Principales**

| Método | Parámetros | Descripción |
|--------|------------|-------------|
| `setDurationMinutes(int)` | `minutes` (1-120) | Configura duración |
| `start()` | - | Inicia cuenta regresiva |
| `pause()` | - | Pausa temporalmente |
| `resume()` | - | Reanuda desde pausa |
| `stop()` | - | Detiene y resetea |
| `cancel()` | - | Cancela completamente |

### **Propiedades**

| Propiedad | Tipo | Descripción |
|-----------|------|-------------|
| `durationSeconds` | `int` | Duración total configurada |
| `remainingSeconds` | `int` | Tiempo restante actual |
| `isActive` | `bool` | Si está corriendo |
| `isWarning` | `bool` | Si queda < 1 minuto |

---

## 📊 SessionTimerState

### **Estado del Temporizador**

```dart
enum SessionTimerStatus {
  inactive,      // Apagado
  running,       // En cuenta regresiva
  paused,        // Pausado
  completed,     // Completado
}
```

### **Propiedades del Estado**

```dart
class SessionTimerState {
  final SessionTimerStatus status;
  final int durationSeconds;
  final int remainingSeconds;
  final bool isWarning;
  
  // Helpers
  String get formattedRemaining;  // "05:30"
  String get formattedDuration;   // "15:00"
  double get progress;            // 0.0 - 1.0
}
```

---

## 💾 Persistencia

El temporizador guarda su estado en `SharedPreferences`:

```dart
// Keys
'session_timer_duration'    // Duración total (segundos)
'session_timer_remaining'   // Tiempo restante (segundos)
'session_timer_active'      // ¿Está activo? (bool)
```

**Nota:** Por seguridad, el temporizador **no se auto-inicia** al cargar la app, incluso si estaba activo.

---

## 🔔 Notificaciones y Advertencias

### **Logs del Sistema**

```
[TIMER] Temporizador configurado: 30 minutos (1800 segundos)
[TIMER] Temporizador iniciado: 30 minutos
[TIMER] ⚠️ ADVERTENCIA: Queda 1 minuto de sesión
[TIMER] ⚠️ ATENCIÓN: Quedan 10 segundos
[TIMER] ⏰ TIEMPO EXPIRADO - Ejecutando callback
```

### **Notificaciones Visuales**

**Último minuto (< 60s):**
- 🔴 Color rojo en UI
- ⚠️ Ícono de advertencia
- Timer parpadea (opcional)

**Últimos 10 segundos:**
- 🔴 Rojo intenso
- ⚠️ Advertencia en logs

---

## 🎨 UI/UX

### **Estado Inactivo**
```
┌────────────────────────────────────────────┐
│ ⏱️  TEMPORIZADOR DE SESIÓN          ›     │
│     Auto-desconexión de seguridad          │
│     Configurado: 30:00                     │
└────────────────────────────────────────────┘
```

### **Estado Activo (Normal)**
```
┌────────────────────────────────────────────┐
│ ⏱️ ● TEMPORIZADOR DE SESIÓN         ⏱️    │
│     25:43                                  │
│     ▓▓▓▓▓▓▓▓░░░░░░░░░░  85%               │
│     Auto-desconexión en 25:43              │
└────────────────────────────────────────────┘
```

### **Estado Activo (Advertencia)**
```
┌────────────────────────────────────────────┐
│ ⏱️ ⚠️ TEMPORIZADOR DE SESIÓN        ⏹️    │
│     00:45                                  │
│     ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░  95%                 │
│     Auto-desconexión en 00:45              │
└────────────────────────────────────────────┘
```

---

## 🔒 Consideraciones de Seguridad

### **Auto-Stop**

Cuando el temporizador expira:
1. Se llama a `ble.emergencyStop()`
2. Detiene burst mode
3. Detiene sequencer
4. Envía comando STOP al dispositivo
5. Limpia estado

### **Coexistencia con Cooldown**

El temporizador **no interfiere** con el cooldown de emergencia:
- Si el cooldown está activo, el timer sigue corriendo
- Si el timer expira durante cooldown, no hay acción adicional

---

## 🧪 Testing

### **Pruebas Recomendadas**

```dart
// 1. Configurar temporizador corto (1 minuto)
timerService.setDurationMinutes(1);
timerService.start();

// 2. Verificar que el estado cambia
expect(timerState.status, SessionTimerStatus.running);

// 3. Esperar expiración
await Future.delayed(Duration(seconds: 61));

// 4. Verificar auto-stop
expect(timerState.status, SessionTimerStatus.completed);
expect(ble.isConnected, false); // Si estaba conectado
```

### **Casos de Borde**

| Caso | Comportamiento Esperado |
|------|------------------------|
| App en background | Timer continúa corriendo |
| App cerrada | Timer se pausa (no persistente) |
| Reinicio de app | Timer cargado pero inactivo |
| Sin dispositivo BLE | Timer corre, pero no hay auto-stop |
| Cooldown activo | Timer corre normal |

---

## 📝 Flujo de Uso Típico

```
1. Usuario abre Settings Tab
2. Toca "TEMPORIZADOR DE SESIÓN"
3. Selecciona 30 minutos
4. Toca "INICIAR"
5. UI muestra cuenta regresiva: 30:00, 29:59, 29:58...
6. Usuario usa la app normalmente
7. Queda 1 minuto → Advertencia visual
8. Quedan 10 segundos → Advertencia intensificada
9. Tiempo expira → Auto-stop + Notificación
10. UI vuelve a estado inicial
```

---

## 🔗 Integración con Otras Funcionalidades

### **Con BLE Service**
- ✅ Auto-stop al expirar
- ✅ Funciona con burst mode
- ✅ Funciona con sequencer
- ✅ Compatible con cooldown

### **Con AI Hardware Bridge**
- ⚠️ El timer detiene comandos de IA
- ✅ No interfiere con perfiles guardados

### **Con Remote Sessions**
- ⚠️ El timer es local (no se sincroniza)
- ✅ Cada usuario puede tener su propio timer

---

## 🚀 Próximas Mejoras (Opcional)

- [ ] Notificación push en Android/iOS
- [ ] Sonido de advertencia al expirar
- [ ] Opción de "Snooze" (5 min extra)
- [ ] Historial de sesiones con timer
- [ ] Estadísticas de uso por tiempo
- [ ] Temporizador personalizado (segundos exactos)
- [ ] Integración con modos (Roulette, Kegel, etc.)

---

## 📚 Recursos Adicionales

- [SharedPreferences Package](https://pub.dev/packages/shared_preferences)
- [Riverpod StateNotifier](https://riverpod.dev/docs/concepts/state_notifier)
- [Flutter Timer Tutorial](https://docs.flutter.dev/cookbook/basic-apps/timer)

---

**Implementado:** Marzo 2026  
**Versión:** 1.0  
**Estado:** ✅ Completado e Implementado
