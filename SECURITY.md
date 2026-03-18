# 🔒 Velvet Sync · Security & Build Guide

## Build Flavors

Velvet Sync ahora soporta **build flavors** para separar entornos de desarrollo y producción.

### 📱 Flavors Disponibles

| Flavor | Application ID | Uso |
|--------|----------------|-----|
| `dev` | `com.velvetsync.app.dev` | Desarrollo y testing |
| `prod` | `com.velvetsync.app` | Producción (release) |

### 🚀 Comandos de Build

```bash
# Desarrollo
flutter run --flavor dev
flutter build apk --flavor dev --debug

# Producción
flutter run --flavor prod
flutter build apk --flavor prod --release
flutter build appbundle --flavor prod --release
```

### 📁 Estructura de Archivos

```
velvetsyncapp/
├── .env                    # 🔒 TU archivo local (NO COMMIT)
├── .env.template           # Plantilla segura (COMMIT)
├── .env.example            # Ejemplo alternativo
├── flavors.yaml            # Configuración de flavors
├── android/
│   └── app/
│       └── build.gradle.kts # Configuración Android flavors
└── lib/
    └── main.dart           # Entry point único
```

---

## 🔐 Seguridad de Credenciales

### NUNCA commites `.env`

El archivo `.env` está en `.gitignore`. Usa `.env.template` como referencia.

### Rotación de API Keys

| Servicio | URL de Rotación | Frecuencia Recomendada |
|----------|-----------------|------------------------|
| OpenRouter | https://openrouter.ai/keys | 90 días |
| Google Gemini | https://console.cloud.google.com/apis/credentials | 90 días |
| Supabase | https://app.supabase.com/project/settings/api | 180 días |

---

## ✅ Checklist de Release

Antes de publicar:

```markdown
- [ ] Build de producción: `flutter build apk --flavor prod --release`
- [ ] Tests en dispositivo real Android
- [ ] Verificar que Debug Screen no esté accesible
- [ ] Confirmar que no hay logging de datos sensibles
- [ ] API Keys rotadas y actualizadas en servidor
- [ ] `.env` NO está en git (verificar con `git status`)
- [ ] Firmar APK con keystore de producción
```

---

## 🛡️ Mejoras de Seguridad Implementadas

### CRITICAL (7/7 ✅)
- [x] Eliminar credenciales hardcodeadas
- [x] Fail fast si `.env` no carga
- [x] Autenticación requerida para sync
- [x] Validación de expiración de tokens
- [x] Sin logging de API keys
- [x] Rate limiting en creación de sesiones

### HIGH (3/3 ✅)
- [x] Validación de parámetros deep link
- [x] Debug screen bloqueado en producción
- [x] Certificate pinning (ver nota abajo)

### MEDIUM (8/8 ✅)
- [x] Network security configuration
- [x] Cleartext traffic bloqueado
- [x] Reemplazar debugPrint con lvsLog
- [x] Validación de avatar paths
- [x] Session timer con FlutterSecureStorage
- [x] Security lint rules
- [x] Dependencias actualizadas
- [x] Build flavors configurados

---

## 📝 Notas

### Certificate Pinning

**No implementado** (complejidad 7/10). Considerar solo si:
- Manejas datos bancarios
- Requisito de compliance empresarial
- Datos médicos sensibles

Para Velvet Sync, HTTPS + Network Security Config es suficiente.

### Próximas Mejoras (Opcionales)

1. Tests automatizados de seguridad
2. CI/CD con security scanning
3. Biometric authentication para settings sensibles

---

*Última actualización: Marzo 2026*
*Versión: 1.4.0*
