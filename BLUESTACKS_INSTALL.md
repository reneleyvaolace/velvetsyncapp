# 🧪 Instalación en BlueStacks - Velvet Sync

## 📦 Build de Debug Disponible

**Archivos generados:**
```
build\app\outputs\flutter-apk\
├── app-arm64-v8a-debug.apk    (254 MB) ← Usar para BlueStacks 64-bit
├── app-armeabi-v7a-debug.apk  (232 MB) ← Usar para BlueStacks 32-bit
└── app-x86_64-debug.apk       (241 MB) ← Alternativa para PC
```

---

## 🚀 Instalación Rápida en BlueStacks

### **Opción 1: Arrastrar y Soltar (Más Fácil)**

1. **Abrir BlueStacks**
2. **Arrastrar** el archivo `app-arm64-v8a-debug.apk` a la ventana de BlueStacks
3. Esperar a que se complete la instalación
4. **Hacer clic** en el ícono de Velvet Sync para abrir

---

### **Opción 2: Usando ADB**

```powershell
# 1. Conectar ADB a BlueStacks
adb connect 127.0.0.1:5555

# 2. Verificar conexión
adb devices
# Debería mostrar: 127.0.0.1:5555    device

# 3. Instalar APK (BlueStacks 64-bit)
adb install c:\Projects\velvetsync\velvetsyncapp\build\app\outputs\flutter-apk\app-arm64-v8a-debug.apk

# 4. Si falla, intentar con la versión 32-bit
adb install c:\Projects\velvetsync\velvetsyncapp\build\app\outputs\flutter-apk\app-armeabi-v7a-debug.apk

# 5. Abrir la app
adb shell am start -n com.velvetsync.app/.MainActivity
```

---

## 🔍 Ver Logs en Tiempo Real

### **Mientras la app se ejecuta en BlueStacks:**

```powershell
# Opción 1: Flutter logs (recomendado)
flutter logs

# Opción 2: ADB logcat filtrado
adb logcat | grep -i "INIT\|LVS"

# Opción 3: Ver todos los logs
adb logcat -s Flutter:* LVS:* INIT:*
```

---

## ⚙️ Configuración Recomendada para BlueStacks

### **Requisitos Mínimos:**
- ✅ Android 11 o superior (Pie 64-bit)
- ✅ 4 GB de RAM asignados
- ✅ 4 núcleos de CPU
- ✅ Modo de alto rendimiento activado

### **Configuración en BlueStacks:**
1. ⚙️ **Configuración** (engranaje)
2. **Rendimiento**
   - Asignación de CPU: **Alto (4 núcleos)**
   - Asignación de memoria: **Alto (4 GB)**
   - Modo de rendimiento: **Alto rendimiento**
3. **Gráficos**
   - Motor gráfico: **Rendimiento**
   - GPU preferida: **Tu tarjeta gráfica dedicada**
4. **Guardar cambios** y reiniciar BlueStacks

---

## 🐛 Solución de Problemas

### **Problema: "App se cierra inmediatamente"**

**Causa:** Arquitectura incorrecta del APK.

**Solución:**
```powershell
# Probar con diferente arquitectura
adb uninstall com.velvetsync.app
adb install build\app\outputs\flutter-apk\app-armeabi-v7a-debug.apk
```

---

### **Problema: "Pantalla en blanco/negra"**

**Causa:** Error en inicialización de servicios.

**Solución:**
1. **Ver logs** para ver el error específico:
   ```powershell
   adb logcat | grep -i "error\|fatal\|exception"
   ```

2. **Activar modo emulador** (omite BLE):
   - Editar `lib/main.dart`
   - Cambiar: `const bool kEmulatorMode = true;`
   - Rebuild: `flutter build apk --debug --split-per-abi`
   - Reinstalar

---

### **Problema: "ADB no reconoce el dispositivo"**

**Solución:**
```powershell
# 1. Reiniciar ADB
adb kill-server
adb start-server

# 2. Reconectar a BlueStacks
adb connect 127.0.0.1:5555
adb devices

# 3. Si aún falla, reiniciar BlueStacks completamente
```

---

### **Problema: "Instalación fallida"**

**Causas posibles:**
- Espacio insuficiente en BlueStacks
- APK corrupto
- Conflicto con versión anterior

**Solución:**
```powershell
# 1. Limpiar espacio en BlueStacks
# 2. Desinstalar versión anterior
adb uninstall com.velvetsync.app

# 3. Limpiar caché de BlueStacks
# Configuración → Apps → Administrador de Apps → Velvet Sync → Borrar datos

# 4. Reintentar instalación
adb install -r build\app\outputs\flutter-apk\app-arm64-v8a-debug.apk
```

---

## 📊 Qué Esperar en BlueStacks

### **Funcionalidades que SÍ funcionan:**
- ✅ UI/UX de la app
- ✅ Navegación entre pantallas
- ✅ Catálogo de dispositivos (Supabase)
- ✅ Deep Linking
- ✅ Sync Service (tiempo real)

### **Funcionalidades que NO funcionan:**
- ❌ **Bluetooth/BLE** - BlueStacks no tiene hardware Bluetooth
- ❌ **Conexión a dispositivos físicos** - Requiere hardware real
- ❌ **Foreground Service completo** - Limitado en emulador

---

## 🎯 Próximos Pasos

### **1. Probar la app en BlueStacks:**
```powershell
# Instalar
adb install build\app\outputs\flutter-apk\app-arm64-v8a-debug.apk

# Abrir
adb shell am start -n com.velvetsync.app/.MainActivity

# Ver logs
flutter logs
```

### **2. Si hay errores, revisar logs:**
```powershell
adb logcat | grep -i "INIT"
```

### **3. Para testing completo de BLE:**
- Usar **dispositivo físico Android**
- Activar depuración USB
- Conectar vía USB o WiFi

---

## 📝 Comandos Útiles

| Comando | Propósito |
|---------|-----------|
| `adb devices` | Ver dispositivos conectados |
| `adb install <apk>` | Instalar APK |
| `adb uninstall <package>` | Desinstalar app |
| `flutter logs` | Ver logs de Flutter |
| `adb logcat` | Ver todos los logs de Android |
| `adb shell am start -n <package>/<activity>` | Abrir app específicamente |
| `adb shell screencap -p /sdcard/s.png` | Capturar pantalla |
| `adb pull /sdcard/s.png` | Descargar captura |

---

## 🔗 Recursos Adicionales

- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - Guía completa de solución de problemas
- [RELEASE_CONFIG.md](./RELEASE_CONFIG.md) - Configuración de release
- [Flutter Debugging Guide](https://docs.flutter.dev/testing/debugging)

---

**Última actualización:** Marzo 2026  
**Versión del build:** Debug (v2.1.1)  
**Arquitecturas:** ARM64, ARMv7, x86_64
