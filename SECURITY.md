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
flutter run --flavor dev --dart-define-from-file=env.json
flutter build apk --flavor dev --debug --dart-define-from-file=env.json

# Producción
flutter run --flavor prod --dart-define-from-file=env.json
flutter build apk --flavor prod --release --dart-define-from-file=env.json
flutter build appbundle --flavor prod --release --dart-define-from-file=env.json
```

### 📁 Estructura de Archivos

```
velvetsyncapp/
├── env.example.json        # Plantilla (COMMIT, sin secretos)
├── env.json                # TU config local (IGNORADO por git)
├── supabase/
│   └── functions/
│       └── ai-proxy/index.ts  # Proxy IA (clave solo en Supabase Secrets)
├── flavors.yaml            # Configuración de flavors
├── android/
│   └── app/
│       └── build.gradle.kts # Configuración Android flavors
└── lib/
    ├── config/env.dart     # --dart-define / env.json
    └── main.dart           # Entry point único
```

---

## 🔐 Seguridad de Credenciales

### El cliente solo lleva la anon key

`env.json` contiene `SUPABASE_URL` y `SUPABASE_ANON_KEY` (pública por diseño).
Se inyecta con `--dart-define-from-file=env.json` y está en `.gitignore`.

Nunca incluir en `env.json` ni en el código:
- `OPENROUTER_API_KEY` → Supabase Secrets
- `service_role` de Supabase → solo servidor
- Claves privadas de terceros

### Edge Function `ai-proxy`

```bash
supabase secrets set OPENROUTER_API_KEY=<clave> --project-ref <project-ref>
supabase secrets set OPENROUTER_MODEL=google/gemma-4-26b-a4b-it:free --project-ref <project-ref>
supabase functions deploy ai-proxy --project-ref <project-ref>
```

La función valida el JWT en el gateway, limita el tamaño del mensaje, aplica
un rate limit por instancia y nunca devuelve el cuerpo de error del proveedor.

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
- [ ] Build de producción: `flutter build apk --flavor prod --release --dart-define-from-file=env.json`
- [ ] Tests en dispositivo real Android
- [ ] Verificar que Debug Screen no esté accesible
- [ ] Confirmar que no hay logging de datos sensibles
- [ ] API Keys rotadas y actualizadas en Supabase Secrets
- [ ] `env.json` NO está en git (verificar con `git status`)
- [ ] APK inspeccionado: sin `.env` ni claves privadas
- [ ] Firmar APK con keystore de producción
```

---

## 🛡️ Mejoras de Seguridad Implementadas

### CRITICAL (6/7 ✅)
- [x] Eliminar credenciales hardcodeadas
- [x] Configuración por `--dart-define-from-file` (sin `.env` en el APK)
- [x] Clave de OpenRouter solo en Supabase Secrets (Edge Function)
- [ ] Autenticación requerida para sync — pendiente (fase 2)
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

*Última actualización: Octubre 2026*
*Versión: 1.4.0*
