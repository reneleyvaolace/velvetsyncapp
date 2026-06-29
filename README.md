# Velvet Sync — Flutter App
## Guía de Instalación y Compilación

> **Versión:** 1.4.0+1 | **Plataforma:** Velvet Sync AI-Powered | **Protocolo:** Love Spouse 8154 (wbMSE) | **BLE + Background**

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

### 3 · Configurar variables de entorno
Crea un archivo `.env` en la raíz del proyecto basado en `.env.example`:
```powershell
cp .env.example .env
# Luego edita .env con tus credenciales de Supabase
```

### 4 · Verificar entorno
```powershell
flutter doctor -v
# Debe mostrar ✓ en Flutter, Android toolchain, y Android Studio
```

---

## 🚀 Compilar y ejecutar

### Instalar dependencias
```powershell
cd c:\Proyectos\velvet-sync
flutter pub get
```

### Ejecutar con Flavors (Entornos)
```powershell
# Desarrollo (Paquete: com.velvetsync.app.dev)
flutter run --flavor dev

# Producción (Paquete: com.velvetsync.app)
flutter run --flavor prod
```

### Compilar APK de release
```powershell
# Es necesario especificar el flavor prod para la versión final
flutter build apk --flavor prod --release
# Salida: build/app/outputs/flutter-apk/app-prod-release.apk
```

### Compilar AAB para Google Play
```powershell
flutter build appbundle --flavor prod --release
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
               "Velvet Sync activo • wbMSE/8154"  [notificación]
                   ↓
           Proceso continúa → BLE sigue enviando comandos
```

**Permisos Android configurados:**
 Permiso | Propósito | SDK |
---|---|---|
 `BLUETOOTH_SCAN` | Escanear dispositivos BLE | API 31+ |
 `BLUETOOTH_CONNECT` | Conectar/escribir GATT | API 31+ |
 `BLUETOOTH` + `BLUETOOTH_ADMIN` | Compatibilidad API ≤30 | API ≤30 |
 `FOREGROUND_SERVICE` | Servicio en segundo plano | Todos |
 `FOREGROUND_SERVICE_CONNECTED_DEVICE` | Tipo específico BLE BG | API 34+ |
 `WAKE_LOCK` | Evitar sleep durante burst | Todos |
 `POST_NOTIFICATIONS` | Notificación del servicio | API 33+ |

### iOS — bluetooth-central Background Mode
En `Info.plist` se declara `UIBackgroundModes: [bluetooth-central]`. Esto instriye a iOS para que CoreBluetooth pueda:
- Mantener conexiones GATT activas en background
- Recibir notificaciones de desconexión
- Enviar comandos de escritura cuando la app está suspendida

> **Límite iOS:** Apple puede suspender la app si el sistema tiene poca memoria. Se recomienda reconectar automáticamente desde `connectionState.listen`.

---

## 📁 Estructura del proyecto

```
c:\Proyectos\velvet-sync\
├── lib/
│   ├── main.dart              # Entrypoint + Inicialización (Riverpod)
│   ├── theme.dart             # Sistema de diseño (Outfit font, ThemeData)
│   ├── services/
│   │   ├── ble/               # BLE: scanning, GATT, lvs_commands
│   │   ├── backend/           # SyncService & LinkService (Supabase)
│   │   └── ai/                # AI Hardware Bridge Service
│   ├── providers/             # Riverpod providers (State management)
│   ├── screens/               # UI: Home, Navigation, Debug, Settings
│   └── utils/                 # Logger, Helpers, Constants
├── assets/                    # .env, Fuentes, Iconos, Imágenes
├── directivas/                # Guías de diseño, desarrollo y procesos
├── android/
│   ├── app/
│   │   ├── build.gradle.kts   # Configuración de minSdk, flavors y firma
│   │   └── src/main/
│   │       ├── AndroidManifest.xml   ← PERMISOS BLE COMPLETOS
│   │       └── kotlin/com/velvetsync/app/
│   │           └── MainActivity.kt
│   └── build.gradle.kts
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
`Ajustes → Apps → Velvet Sync → Permisos → Bluetooth → Permitir`

### No encuentra el dispositivo wbMSE
1. Asegúrate que el dispositivo esté encendido y en modo pairing (LED parpadeando)
2. El dispositivo puede tardar hasta 20 segundos en aparecer
3. Intenta olvidar el dispositivo en Bluetooth del sistema y volver a escanear desde la app

### App se desconecta en background (Android)
- Confirmar que la notificación "Velvet Sync activo" esté visible en la barra de notificaciones
- `Ajustes → Batería → Velvet Sync → Sin restricciones`
- Si usas un fabricante con RAM agresiva (Xiaomi, Huawei, Samsung), agregar la app a la lista blanca de batería

### Compilación falla: "flutter_foreground_task requires minSdkVersion >= 21"
```powershell
# Verificar que android/app/build.gradle.kts tenga:
minSdk = 21 (o flutter.minSdkVersion configurado correctamente)
```

---

## 📦 Dependencias principales

 Paquete | Versión | Propósito |
---|---|---|
 `flutter_blue_plus` | ^2.2.1 | BLE scanning y GATT |
 `permission_handler` | ^12.0.1 | Permisos de runtime |
 `flutter_foreground_task` | ^9.2.1 | Servicio Android en background |
 `sensors_plus` | ^7.0.0 | Acelerómetro (Shake Mode) |
 `flutter_riverpod` | ^2.6.1 | State management (moderno) |
 `supabase_flutter` | ^2.12.0 | Backend, Auth y Realtime |
 `just_audio` | ^0.9.46 | Motor de audio y efectos |
 `shared_preferences` | ^2.3.3 | Persistencia de ajustes locales |
 `wakelock_plus` | ^1.4.0 | Prevenir sleep durante sesiones activas |
