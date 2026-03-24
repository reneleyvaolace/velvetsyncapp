# 🔧 Troubleshooting - Velvet Sync

## 📱 Problemas Comunes y Soluciones

---

## 🖥️ **Pantalla en Blanco en Emuladores (BlueStacks, Nox, etc.)**

### Síntomas
- La app se queda en pantalla blanca/negra después de iniciar
- Splash screen se muestra pero no navega a la pantalla principal
- No hay respuesta al tocar la pantalla

### Causas Probables

#### 1. **BlueStacks no detectado por ADB** ❌

**Problema:** Flutter no puede conectar al emulador.

**Solución:**
```powershell
# Conectar ADB a BlueStacks
adb connect 127.0.0.1:5555

# Verificar dispositivos conectados
adb devices

# Si el puerto 5555 no funciona, intentar alternativas:
adb connect 127.0.0.1:5556
adb connect 127.0.0.1:5557
adb connect 127.0.0.1:5558
```

**Verificación:**
```powershell
flutter devices
# Debería mostrar el emulador en la lista
```

---

#### 2. **Servicios de Google Play desactualizados** ❌

**Problema:** Supabase/Firebase requieren Google Play Services actualizados.

**Solución:**
1. En BlueStacks, abre **Configuración**
2. Ve a **Apps → Google Play Services**
3. Si hay actualización disponible, instálala
4. Reinicia BlueStacks

---

#### 3. **Hardware BLE no disponible en emulador** ⚠️ **CRÍTICO**

**Problema:** La app usa `flutter_blue_plus` que requiere **hardware Bluetooth real**.

**Los emuladores NO tienen Bluetooth físico**, lo que causa:
- Crash silencioso al inicializar BLE
- Foreground service falla
- La app se queda colgada en la inicialización

**Solución recomendada:**
> ✅ **Usa un dispositivo físico Android** para testing de funcionalidades BLE.
>
> Los emuladores solo son útiles para testing de UI básica.

**Workaround para debugging:**
Si necesitas testear sin BLE, comenta temporalmente la inicialización del AI Bridge en `main.dart`:

```dart
// Comentar temporalmente para testing en emulador
// final aiBridge = AIHardwareBridge();
// await aiBridge.init();
```

---

#### 4. **Error de inicialización silencioso** ❌

**Problema:** Los servicios fallan al iniciar pero no se muestra el error.

**Solución:** El `main.dart` actual ya incluye manejo de errores con logs.

**Ver logs en tiempo real:**
```powershell
# Conectar a dispositivo/emulador
flutter devices

# Ver logs
flutter logs

# O filtrar por tag
adb logcat | grep -i "INIT\|SUPABASE\|AI_BRIDGE"
```

---

### **Pasos de Diagnóstico**

#### Paso 1: Verificar conexión ADB
```powershell
adb devices
```

**Resultado esperado:**
```
List of devices attached
127.0.0.1:5555    device
```

---

#### Paso 2: Instalar APK manualmente
```powershell
# Build de debug
flutter build apk --debug

# Instalar en emulador
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

---

#### Paso 3: Verificar logs de crash
```powershell
adb logcat -c && adb logcat | grep -i "flutter\|fatal"
```

---

#### Paso 4: Limpiar caché del emulador
1. En BlueStacks: **Configuración → Apps → Velvet Sync**
2. **Forzar detención**
3. **Borrar datos** y **Borrar caché**
4. Reiniciar la app

---

#### Paso 5: Probar en dispositivo físico (RECOMENDADO)
```powershell
# Activar depuración USB en el dispositivo
# Conectar vía USB
# Ejecutar:
flutter devices
flutter run
```

---

## 📡 **Problemas de Conexión BLE**

### El dispositivo no aparece en el escaneo

**Causas:**
1. **Permisos no concedidos** - Android 12+ requiere permisos en tiempo de ejecución
2. **Bluetooth apagado** - Verificar que Bluetooth esté activado
3. **Dispositivo no en modo pairing** - El LED debe estar parpadeando
4. **Distancia excesiva** - Acercar el dispositivo (< 1 metro)

**Solución:**
```
1. Ir a: Ajustes → Apps → Velvet Sync → Permisos
2. Conceder: Ubicación, Bluetooth, Notificaciones
3. Reiniciar la app
4. Mantener el dispositivo cerca durante el escaneo
```

---

### La app se desconecta en segundo plano

**Causa:** El sistema Android mata el proceso para ahorrar batería.

**Solución:**
1. Verificar que la notificación "Velvet Sync activo" esté visible
2. Ir a: **Ajustes → Batería → Velvet Sync → Sin restricciones**
3. En fabricantes con RAM agresiva (Xiaomi, Huawei, Samsung):
   - Agregar la app a la **lista blanca de batería**
   - Bloquear la app en la vista de **apps recientes**

---

## 🔐 **Problemas de Supabase**

### Error de conexión a Supabase

**Síntomas:**
- Catálogo no carga
- Errores de red en logs

**Solución:**
1. Verificar conexión a internet
2. Verificar que `.env` tenga las credenciales correctas:
   ```env
   SUPABASE_URL=https://tu-proyecto.supabase.co
   SUPABASE_ANON_KEY=tu-key-anon
   ```
3. Verificar que las políticas RLS permitan lectura

---

## 🏗️ **Problemas de Build**

### "Build failed with exception"

**Causa común:** NDK corrupto o Java versión incorrecta.

**Solución:**
```powershell
# 1. Limpiar build
flutter clean

# 2. Eliminar NDK corrupto (si existe)
rd /s /q "%ANDROID_HOME%\ndk\28.2.13676358"

# 3. Rebuild (descargará NDK automáticamente)
flutter build apk --release
```

---

### "Java 8 JVM no es compatible"

**Solución:** En `android/gradle.properties`:
```properties
org.gradle.java.home=C:\\Program Files\\Android\\Android Studio\\jbr
```

---

## 📊 **Comandos Útiles de Debugging**

### Ver logs en tiempo real
```powershell
flutter logs
```

### Ver logs filtrados por tag
```powershell
adb logcat | grep -i "INIT\|SUPABASE\|AI_BRIDGE\|BLE"
```

### Reiniciar ADB server
```powershell
adb kill-server
adb start-server
```

### Ver información del dispositivo
```powershell
adb shell getprop
```

### Capturar screenshot desde adb
```powershell
adb shell screencap -p /sdcard/screenshot.png
adb pull /sdcard/screenshot.png
```

### Instalar APK manualmente
```powershell
adb install -r path/to/app.apk
```

---

## 🧪 **Testing en Diferentes Entornos**

| Entorno | BLE | Foreground Service | Recomendado para |
|---------|-----|-------------------|------------------|
| **Dispositivo Físico** | ✅ Sí | ✅ Sí | Testing completo |
| **BlueStacks/Nox** | ❌ No | ⚠️ Limitado | UI básica |
| **Android Studio Emulator** | ❌ No | ⚠️ Limitado | Desarrollo UI |
| **Windows/Web** | ❌ No | ❌ No | Prototipado |

---

## 📞 **Soporte Adicional**

Si el problema persiste:

1. **Recolectar información:**
   ```powershell
   flutter doctor -v > flutter_doctor.txt
   adb logcat > device_logs.txt
   ```

2. **Verificar versión de la app:**
   ```
   Ajustes → Apps → Velvet Sync → Versión
   ```

3. **Reinstalar desde cero:**
   ```powershell
   flutter clean
   flutter pub get
   flutter build apk --debug
   adb install -r build/app/outputs/flutter-apk/app-debug.apk
   ```

---

## 📚 **Recursos Adicionales**

- [Flutter Debugging Guide](https://docs.flutter.dev/testing/debugging)
- [Android ADB Reference](https://developer.android.com/studio/command-line/adb)
- [Supabase Flutter SDK](https://supabase.com/docs/reference/flutter/introduction)

---

**Última actualización:** Marzo 2026  
**Versión del documento:** 1.0
