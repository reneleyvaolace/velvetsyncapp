# 🔗 Deep Linking - Velvet Sync

## Resumen de la Implementación

Se ha configurado el soporte para **Deep Linking** con el esquema `velvetsync://` en la aplicación Velvet Sync.

---

## 📁 Archivos Modificados/Creados

| Archivo | Cambios |
|---------|---------|
| `pubspec.yaml` | Añadida dependencia `app_links: ^6.4.0` |
| `android/app/src/main/AndroidManifest.xml` | Intent-filter para `velvetsync://device` |
| `ios/Runner/Info.plist` | CFBundleURLTypes con esquema `velvetsync` |
| `lib/services/link_service.dart` | **Nuevo** - Servicio de Deep Linking |
| `lib/main.dart` | Inicialización del LinkService |

---

## 🚀 Esquema de Deep Links

### Formato General
```
velvetsync://device/{accion}?{parametros}
```

### Acciones Soportadas

#### 1. Conectar Dispositivo
```
velvetsync://device/connect?id=DEVICE_ID
```
**Parámetros:**
- `id` (requerido): ID del dispositivo BLE

**Ejemplo:**
```
velvetsync://device/connect?id=wbMSE_8154
```

---

#### 2. Unirse a Sesión Remota
```
velvetsync://device/session?token=SESSION_TOKEN
```
**Parámetros:**
- `token` (requerido): Token de sesión de Supabase

**Ejemplo:**
```
velvetsync://device/session?token=abc123xyz
```

---

#### 3. Control Directo
```
velvetsync://device/control?intensity=50
```
**Parámetros:**
- `intensity` (requerido): Nivel de intensidad (0-255)

**Ejemplo:**
```
velvetsync://device/control?intensity=128
```

---

## 📱 Cómo Probar los Deep Links

### Android

#### Método 1: ADB (Recomendado para testing)
```bash
# App instalada pero cerrada
adb shell am start -W -a android.intent.action.VIEW \
  -c android.intent.category.BROWSABLE \
  -d "velvetsync://device/connect?id=test123" com.example.lvs_control

# App en primer plano
adb shell am start -W -a android.intent.action.VIEW \
  -c android.intent.category.DEFAULT \
  -d "velvetsync://device/session?token=abc123" com.example.lvs_control
```

#### Método 2: Desde el navegador
1. Abre Chrome en tu dispositivo Android
2. Navega a una página con un link: `<a href="velvetsync://device/connect?id=123">Conectar</a>`
3. Haz clic en el enlace

---

### iOS

#### Método 1: Safari
1. Abre Safari en tu dispositivo iOS
2. Navega a una página con un link deep link
3. O usa la terminal:
```bash
xcrun simctl openurl booted "velvetsync://device/connect?id=test123"
```

#### Método 2: Desde otra app
Crea un enlace en una página web o email que abra tu app.

---

## 🔧 Integración con Otros Servicios

### BLE Service (Conexión Automática)
El `LinkService` está diseñado para integrarse con el `BleService`:

```dart
// En lib/services/link_service.dart
Future<void> _handleConnect(Map<String, String> params) async {
  final deviceId = params['id'];
  if (deviceId == null) return;
  
  // Integración futura:
  // final ble = ref.read(bleProvider);
  // ble.connectToDevice(deviceId: deviceId);
}
```

### Supabase (Sesiones Remotas)
Para unirse a sesiones remotas automáticamente:

```dart
Future<void> _handleSession(Map<String, String> params) async {
  final token = params['token'];
  if (token == null) return;
  
  // Integración futura:
  // final supabase = ref.read(supabaseServiceProvider);
  // final session = await supabase.joinSession(token);
}
```

---

## 📊 Logs y Actividad

El servicio registra toda la actividad de deep linking:

```
[LinkService] Iniciando escucha de deep links...
[LinkService] Link inicial detectado: velvetsync://device/connect?id=123
[LinkService] Deep link recibido: velvetsync://device/connect?id=123
[LinkService Activity] LINK: velvetsync://device/connect?id=123
[LinkService Activity] ACTION: connect with {id: 123}
```

### Archivo activity.log
Los logs se escriben en tiempo real. Para habilitar escritura a archivo:

1. Añade `path_provider` a `pubspec.yaml`
2. Descomenta la escritura a archivo en `_writeToLogFile()`

---

## 🔍 Verificación del Estado

El `LinkService` es un `ChangeNotifier`, por lo que puedes escuchar cambios:

```dart
// En un widget Consumer
final linkService = ref.watch(linkServiceProvider);

// Escuchar cambios
linkService.addListener(() {
  print('Último link: ${linkService.lastLink}');
  print('Historial: ${linkService.linkHistory}');
});
```

---

## ⚠️ Consideraciones de Seguridad

1. **Validación de Tokens**: Los tokens de sesión deben validarse en el servidor
2. **HTTPS para App Links**: En producción, configura [Digital Asset Links](https://developer.android.com/training/app-links) para verificación automática
3. **Rate Limiting**: Implementa límite de intentos para prevenir abuso

---

## 🛠️ Troubleshooting

### Android: "No Activity found to handle Intent"
- Verifica que el `intent-filter` esté en `AndroidManifest.xml`
- Asegúrate de que el `applicationId` coincida con el package name
- Reinstala la app después de modificar el manifest

### iOS: "Cannot open page"
- Verifica `CFBundleURLTypes` en `Info.plist`
- Asegúrate de que el scheme sea único
- Rebuild de la app después de cambios en Info.plist

### Links no llegan al servicio
- Verifica que `LinkService.init()` se llame en `main()`
- Revisa los logs con `flutter logs`
- En Android, verifica `android:autoVerify="true"` en el intent-filter

---

## 📚 Recursos Adicionales

- [app_links package](https://pub.dev/packages/app_links)
- [Android Deep Links Guide](https://developer.android.com/training/app-links)
- [iOS Universal Links Guide](https://developer.apple.com/ios/universal-links/)

---

## ✅ Checklist de Implementación

- [x] Dependencia `app_links` añadida
- [x] Intent-filter Android configurado
- [x] CFBundleURLTypes iOS configurado
- [x] LinkService creado
- [x] Inicialización en main.dart
- [x] Logs de actividad implementados
- [x] Documentación completada
