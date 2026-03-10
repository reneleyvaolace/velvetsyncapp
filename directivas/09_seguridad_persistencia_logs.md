# Directiva 09: Seguridad en Persistencia y Logs
## Versión: 1.0.0 | Última actualización: 2026-03-09

### Objetivo
Garantizar que ningún dato sensible (dispositivos vinculados, tokens o logs) sea accesible por terceros o mediante ingeniería inversa básica.

### Estándares de Persistencia
1.  **Cifrado Obligatorio:** Queda prohibido el uso de `SharedPreferences` para almacenar cualquier dato que identifique el hardware del usuario o sesiones remotas.
2.  **Tecnología:** Se utilizará `flutter_secure_storage` para el almacenamiento en el Keystore (Android) y Keychain (iOS).
3.  **Fallback Seguro (Opcional):** Si se usa `shared_preferences` para ajustes no sensibles (ej. tema oscuro), nunca debe mezclarse con datos de dispositivos.

### Estándares de Logging
1.  **Silencio en Producción:** Todas las llamadas a `debugPrint` o `print` deben eliminarse o envolverse en un condicional `if (kDebugMode)`.
2.  **Sanitización:** Nunca loguear la URL completa de Supabase ni los payloads de los comandos BLE en modo release.

### Historial de Aprendizaje
- **2026-03-09:** Se detectó que `CatalogService` guardaba IDs de hardware en texto plano. Se inicia migración a Secure Storage.
- **2026-03-09:** Identificadas fugas de información en logs de `SupabaseService`.
