# Estado del Proyecto - Velvet Sync
## Fecha: 2026-04-08

---

## ✅ Implementado Recientemente

### 1. Widget LvsModeCard
- **Archivo:** `lib/widgets/lvs_mode_card.dart`
- **Descripción:** Tarjetas de modo reutilizables con glassmorphism, glow effects, estados lock/unlock
- **Tipos soportados:** game, companion, dice, roulette, reader, kegel

### 2. Deep Linking
- **Servicio:** `lib/services/backend/link_service.dart` (ya existía)
- **Inicialización:** Agregado en `lib/main.dart`
- **Esquema:** `velvetsync://device/{accion}?parametros`
- **Acciones:** connect, session, control

### 3. Notificaciones Push
- **Archivo:** `lib/services/backend/notification_service.dart`
- **Dependencia:** `flutter_local_notifications: ^18.0.1`
- **Funcionalidades:**
  - Notificaciones foreground persistentes
  - Invitaciones de sesión
  - Alertas de batería baja
  - Notificaciones de conexión perdida
  - Permisos en tiempo de ejecución

### 4. Integración BleService + Notificaciones
- **Archivo:** `lib/services/ble/ble_service.dart`
- Notificación automática de batería baja (≤20%)
- Notificación de desconexión perdida

### 5. Home Screen - Imports Corregidos
- **Archivo:** `lib/screens/home_screen.dart`
- Activados imports de: companion_screen, roulette_screen, reader_screen, catalog_screen, remote_session_screen

### 6. Consola de Logs Actualizada
- **Archivos:** `lib/screens/home_screen.dart`, `lib/screens/tabs/settings_tab.dart`
- Colores según tipo: Dorado (default), Cyan (cmd), Teal (success), Red (error), Amber (warn), Mint (debug)

---

## 📊 Estado de Análisis

| Métrica | Valor |
|---------|-------|
| Errores | 0 |
| Warnings | 1 (must_call_super en game_screen) |
| Info | 16 |
| Total | 17 issues |

---

## 📁 Archivos Modificados/Creados

### Nuevos
- `lib/widgets/lvs_mode_card.dart`
- `lib/services/backend/notification_service.dart`

### Modificados
- `lib/main.dart` - LinkService init
- `lib/services/ble/ble_service.dart` - Notificaciones
- `lib/screens/home_screen.dart` - Imports + logs
- `lib/screens/tabs/settings_tab.dart` - Logs coloreados
- `lib/screens/dice_screen.dart` - Fix tipo double
- `pubspec.yaml` - flutter_local_notifications
- `android/app/build.gradle.kts` - Core library desugaring

---

## 🔧 Comandos de Build

```powershell
# Debug (funciona)
flutter build apk --flavor dev --debug

# Release
flutter build apk --flavor dev --release
```

**Ubicación APK:** `build/app/outputs/flutter-apk/app-dev-debug.apk`

---

## 📋 Pendientes (PENDIENTES.md)

- [x] Deep Linking
- [x] Notificaciones Push
- [x] Widget LvsModeCard
- [x] Integración Ble + Notificaciones

---

## 🔐 Notas de Seguridad

- `.env` en `.gitignore` ✅
- API Keys no hardcodeadas ✅
- Validación de tokens en Deep Linking ✅
- Permisos de notificaciones solicitados ✅