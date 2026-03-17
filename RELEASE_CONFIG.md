# 🔐 Configuración de Release - Velvet Sync

## 📋 Resumen

Este documento describe la configuración de firma y publicación de la aplicación Velvet Sync para Android e iOS.

---

## ✅ Configuración Completada

| Elemento | Estado | Fecha |
|----------|--------|-------|
| **Firma de Release (Android)** | ✅ Configurado | Marzo 2026 |
| **Application ID Único** | ✅ `com.velvetsync.app` | Marzo 2026 |
| **Bundle ID iOS** | ✅ `com.velvetsync.app` | Marzo 2026 |
| **Build APK Exitoso** | ✅ Generado | Marzo 2026 |

---

## 🔑 Android - Firma de Release

### Keystore

| Propiedad | Valor |
|-----------|-------|
| **Archivo** | `android/app/velvet-sync-release-key.keystore` |
| **Alias** | `velvet-sync` |
| **Algoritmo** | RSA 2048-bit |
| **Validez** | 10,000 días (~27 años) |
| **Expiración** | ~2053 |
| **Owner** | `CN=Velvet Sync, OU=Development, O=Velvet Sync, L=Madrid, ST=Madrid, C=ES` |

### Credenciales (CONFIDENCIAL)

```
Store Password: VelvetSync2026!
Key Password: VelvetSync2026!
```

> ⚠️ **ADVERTENCIA DE SEGURIDAD:**
> - Estas credenciales **NUNCA** deben subirse al repositorio
> - Los archivos `key.properties` y `*.keystore` están excluidos en `.gitignore`
> - Si pierdes el keystore, **NO podrás actualizar** tu app en Google Play
> - Haz una copia de seguridad en un lugar seguro (ej. administrador de contraseñas)

### Archivos de Configuración

#### `android/key.properties`
```properties
storePassword=VelvetSync2026!
keyPassword=VelvetSync2026!
keyAlias=velvet-sync
storeFile=../app/velvet-sync-release-key.keystore
```

#### `android/app/build.gradle.kts`
```kotlin
// Cargar configuración de firma
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.velvetsync.app"
    
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

---

## 📱 Identificadores de Aplicación

### Android

| Propiedad | Valor |
|-----------|-------|
| **Application ID** | `com.velvetsync.app` |
| **Namespace** | `com.velvetsync.app` |
| **Display Name** | `Velvet Sync` |

**Archivo:** `android/app/build.gradle.kts`

### iOS

| Propiedad | Valor |
|-----------|-------|
| **Bundle Identifier** | `com.velvetsync.app` |
| **Display Name** | `Velvet Sync` |
| **Bundle Name** | `lvs_control` |

**Archivos:**
- `ios/Runner.xcodeproj/project.pbxproj`
- `ios/Runner/Info.plist`

---

## 🛠️ Comandos de Build

### APK de Release (Android)

```bash
# Build APK firmado
flutter build apk --release

# Salida
build/app/outputs/flutter-apk/app-release.apk
```

### AAB para Google Play

```bash
# Build Android App Bundle
flutter build appbundle --release

# Salida
build/app/outputs/bundle/release/app-release.aab
```

### iOS (requiere macOS)

```bash
# Build iOS
flutter build ios --release

# Abrir en Xcode para firmar y publicar
open ios/Runner.xcworkspace
```

---

## 📊 Estado del Build

### Último Build Exitoso

```
✅ app-release.apk (210.9MB)
   Fecha: Marzo 2026
   Commit: 07f0055
   Application ID: com.velvetsync.app
```

### Dependencias del SDK (Android)

| Componente | Versión | Estado |
|------------|---------|--------|
| NDK | 28.2.13676358 | ✅ Instalado |
| Build Tools | 35.0.0 | ✅ Instalado |
| Platform 34 | Android 14 | ✅ Instalado |
| Platform 35 | Android 15 | ✅ Instalado |
| Platform 36 | Android 16 | ✅ Instalado |
| CMake | 3.22.1 | ✅ Instalado |

---

## 🔒 Seguridad

### Archivos Excluidos de Git

El archivo `.gitignore` incluye:

```gitignore
# Secretos
.env
/android/key.properties
/android/app/*.keystore
```

### Verificación de Firma

Para verificar que el APK está firmado correctamente:

```bash
# Usando apksigner (Android SDK)
apksigner verify --verbose build/app/outputs/flutter-apk/app-release.apk

# Usando jarsigner (JDK)
jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-release.apk
```

### Renovación del Keystore

El keystore expira en ~27 años. Para renovarlo antes de la expiración:

```bash
# Generar nuevo keystore
keytool -genkey -v -keystore velvet-sync-release-key-2.keystore \
  -alias velvet-sync -keyalg RSA -keysize 2048 -validity 10000
```

> ⚠️ **Importante:** No puedes cambiar el keystore después de publicar en Play Store sin perder los usuarios existentes.

---

## 📝 Commits Relacionados

| Commit | Descripción | Fecha |
|--------|-------------|-------|
| `07f0055` | chore: Configurar firma de release y applicationId único | Mar 2026 |
| `e571cf4` | refactor: Simplificar inicialización en main.dart | Mar 2026 |

---

## 🚀 Publicación en Google Play

### Pasos para Publicar

1. **Generar AAB**
   ```bash
   flutter build appbundle --release
   ```

2. **Crear Release en Play Console**
   - Ir a [Google Play Console](https://play.google.com/console)
   - Seleccionar la app
   - Ir a "Producción" → "Crear nueva release"

3. **Subir AAB**
   - Arrastrar `build/app/outputs/bundle/release/app-release.aab`
   - Completar notas de la release

4. **Revisar y Publicar**
   - Revisar cambios
   - Enviar a revisión

### Actualización de App Existente

Si ya existe una app con otro `applicationId`:

1. El `applicationId` debe coincidir con la app existente
2. El keystore debe ser el **mismo** que se usó para firmar la versión anterior
3. El `versionCode` debe ser mayor que la versión publicada

---

## 🧪 Testing

### Instalar APK en Dispositivo

```bash
# Instalar APK de release
flutter install --release

# O usando adb
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### Verificar Información de la App

```bash
# Ver applicationId
adb shell dumpsys package com.velvetsync.app | grep version

# Ver firma
adb shell dumpsys package com.velvetsync.app | grep -A 5 "signatures"
```

---

## 📞 Soporte

### Problemas Comunes

#### 1. "Keystore no encontrado"
**Solución:** Verificar que `key.properties` existe y las rutas son correctas.

#### 2. "Firma no coincide"
**Solución:** Asegurarse de usar el mismo keystore que versiones anteriores.

#### 3. "Build falla con error de NDK"
**Solución:** 
```bash
# Eliminar NDK corrupto
rm -rf $ANDROID_HOME/ndk/28.2.13676358
# Reinstalar automáticamente con flutter build
flutter build apk --release
```

#### 4. "Java 8 JVM no es compatible"
**Solución:** Configurar JDK en `gradle.properties`:
```properties
org.gradle.java.home=C:\\Program Files\\Android\\Android Studio\\jbr
```

---

## 📚 Recursos Adicionales

- [Firmar apps - Android Developers](https://developer.android.com/studio/publish/app-signing)
- [Google Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756)
- [Flutter Build and Release](https://docs.flutter.dev/deployment/android)

---

## ✅ Checklist de Release

Antes de cada release, verificar:

- [ ] Keystore disponible y respaldado
- [ ] `versionCode` incrementado en `pubspec.yaml`
- [ ] `versionName` actualizado en `pubspec.yaml`
- [ ] Build de release exitoso
- [ ] APK firmado correctamente
- [ ] Tests pasados
- [ ] CHANGELOG actualizado
- [ ] Git commit y push completados

---

**Última actualización:** Marzo 2026  
**Versión del documento:** 1.0  
**Responsable:** Equipo Velvet Sync
