# LVS Control — Flutter App
## Guía de Instalación y Compilación

> **Versión:** 1.3.0 | **Protocolo:** Love Spouse 8154 (wbMSE) | **BLE + Background**

---

## 📋 Prerrequisitos

### 1 · Instalar Flutter SDK
```powershell
# Descargar Flutter para Windows
winget install Google.FlutterSDK
# O manualmente desde: https://docs.flutter.dev/get-started/install/windows

# Verificar instalación
flutter doctor
```

### 2 · Instalar Android Studio
```
https://developer.android.com/studio
```
- Instalar **Android SDK 34** (API 34 — Android 14)
- Instalar **Android SDK Build-Tools 34**
- Instalar **Android Emulator** (opcional, BLE solo funciona en dispositivo real)

### 3 · Verificar entorno
```powershell
flutter doctor -v
# Debe mostrar ✓ en Flutter, Android toolchain, y Android Studio
```

---

## 🚀 Compilar y ejecutar

### Instalar dependencias
```powershell
cd c:\Proyectos\lvs-flutter
flutter pub get
```

### Ejecutar en dispositivo Android (modo depuración)
```powershell
# Conectar tu teléfono Android con USB y activar:
# Ajustes → Opciones de desarrollador → Depuración USB
flutter devices          # Ver dispositivos disponibles
flutter run              # Lanza en el primer dispositivo conectado
```

### Compilar APK de release (para instalar directamente)
```powershell
flutter build apk --release
# Salida: build/app/outputs/flutter-apk/app-release.apk
```

### Compilar AAB para Google Play
```powershell
flutter build appbundle --release
```

### iOS (requiere macOS + Xcode)
```bash
# En macOS:
flutter build ios --release
# Abrir Xcode y firmar con tu Apple Developer Account
open ios/Runner.xcworkspace
```

---

## 🔵 Arquitectura BLE y Segundo Plano

### Android — Foreground Service
El app usa `flutter_foreground_task` que lanza un **Foreground Service** con una notificación persistente. Esto garantiza que el proceso Dart no sea eliminado por el sistema cuando la app va a background.

```
App → Background → Sistema intenta matar proceso
                   ↓
               ForegroundService activo
               "LVS Control activo • wbMSE/8154"  [notificación]
                   ↓
           Proceso continúa → BLE sigue enviando comandos
```

**Permisos Android configurados:**
| Permiso | Propósito | SDK |
|---|---|---|
| `BLUETOOTH_SCAN` | Escanear dispositivos BLE | API 31+ |
| `BLUETOOTH_CONNECT` | Conectar/escribir GATT | API 31+ |
| `BLUETOOTH` + `BLUETOOTH_ADMIN` | Compatibilidad API ≤30 | API ≤30 |
| `FOREGROUND_SERVICE` | Servicio en segundo plano | Todos |
| `FOREGROUND_SERVICE_CONNECTED_DEVICE` | Tipo específico BLE BG | API 34+ |
| `WAKE_LOCK` | Evitar sleep durante burst | Todos |
| `POST_NOTIFICATIONS` | Notificación del servicio | API 33+ |

### iOS — bluetooth-central Background Mode
En `Info.plist` se declara `UIBackgroundModes: [bluetooth-central]`. Esto instriye a iOS para que CoreBluetooth pueda:
- Mantener conexiones GATT activas en background
- Recibir notificaciones de desconexión
- Enviar comandos de escritura cuando la app está suspendida

> **Límite iOS:** Apple puede suspender la app si el sistema tiene poca memoria. Se recomienda reconectar automáticamente desde `connectionState.listen`.

---

## 📁 Estructura del proyecto

```
c:\Proyectos\lvs-flutter\
├── lib/
│   ├── main.dart              # Entrypoint + ForegroundTask handler
│   ├── theme.dart             # Sistema de diseño (colores, ThemeData)
│   ├── ble/
│   │   ├── ble_service.dart   # BLE: scan, GATT, burst, permisos
│   │   └── lvs_commands.dart  # Protocolo: comandos, paquetes 11B/18B
│   └── screens/
│       ├── home_screen.dart   # Pantalla principal
│       └── debug_screen.dart  # Modo depuración: barrido byte 2
├── android/
│   ├── app/
│   │   ├── build.gradle       # minSdk 21, targetSdk 34
│   │   └── src/main/
│   │       ├── AndroidManifest.xml   ← PERMISOS BLE COMPLETOS
│   │       └── kotlin/com/lvs/control/
│   │           └── MainActivity.kt
│   └── build.gradle
├── ios/
│   └── Runner/
│       └── Info.plist         ← BACKGROUND MODE bluetooth-central
└── pubspec.yaml
```

---

## 🐛 Solución de problemas

### BLE no funciona en Android 12+
```
✗ Error: SecurityException: need BLUETOOTH_CONNECT permission
```
**Causa:** Android 12+ requiere solicitar permisos en tiempo de ejecución.  
**Solución:** El app ya lo hace automáticamente al tocar "Escanear". Si persiste, ve a:
`Ajustes → Apps → LVS Control → Permisos → Bluetooth → Permitir`

### No encuentra el dispositivo wbMSE
1. Asegúrate que el dispositivo esté encendido y en modo pairing (LED parpadeando)
2. El dispositivo puede tardar hasta 20 segundos en aparecer
3. Intenta olvidar el dispositivo en Bluetooth del sistema y volver a escanear desde la app

### App se desconecta en background (Android)
- Confirmar que la notificación "LVS Control activo" esté visible en la barra de notificaciones
- `Ajustes → Batería → LVS Control → Sin restricciones`
- Si usas un fabricante con RAM agresiva (Xiaomi, Huawei, Samsung), agregar la app a la lista blanca de batería

### Compilación falla: "flutter_foreground_task requires minSdkVersion >= 21"
```powershell
# Verificar que android/app/build.gradle tenga:
minSdkVersion 21
```

---

## 📦 Dependencias principales

| Paquete | Versión | Propósito |
|---|---|---|
| `flutter_blue_plus` | ^1.34.4 | BLE scanning y GATT |
| `permission_handler` | ^11.3.1 | Permisos de runtime |
| `flutter_foreground_task` | ^8.11.0 | Servicio Android en background |
| `sensors_plus` | ^5.0.1 | Acelerómetro (Shake Mode) |
| `provider` | ^6.1.2 | State management |
| `shared_preferences` | ^2.3.2 | Persistencia de ajustes |
| `wakelock_plus` | ^1.2.8 | Prevenir sleep durante debug |
