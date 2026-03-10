# Directiva de Verificación de Seguridad

## Versión: 1.0.0 | Última actualización: 2026-03-09

Esta directiva define el proceso para auditar y verificar la seguridad de la aplicación Velvet Sync.

### Objetivos
1. Identificar fugas de tokens y llaves API.
2. Verificar la protección de datos sensibles en el almacenamiento local.
3. Asegurar que las comunicaciones con el backend (Supabase) sigan las mejores prácticas de RLS.
4. Detectar exposición de información sensible en los logs.

### Skills Requeridas
- Análisis de código estático (Python).
- Auditoría de backend (Supabase CLI/MCP).
- Revisión de configuración de entorno (.env/pubspec).

### Procedimiento de Auditoría
1. **Configuración de Entorno:**
   - Validar que `.env` esté en `.gitignore`.
   - Verificar que no se incluyan archivos de secretos en los assets de Flutter (`pubspec.yaml`).
2. **Almacenamiento Local:**
   - Buscar el uso de `shared_preferences`. Asegurar que no se guarden contraseñas o tokens de acceso sin cifrar.
3. **Logs y Depuración:**
   - Buscar sentencias `print()` o `debugPrint()` que puedan estar exponiendo PII (Información Personal Identificable) o secretos.
4. **Backend (Supabase):**
   - Verificar que todas las tablas tengan Row Level Security (RLS) habilitado.
   - Revisar que el `anon_key` no tenga permisos excesivos.

### Historial de Aprendizaje y Seguimiento
- **2026-03-09 (H1 - Crítico):** Se confirmó que `.env` estaba siendo rastreado por Git.
  - *Acción:* Se eliminó del historial (`git rm --cached .env`) y se añadió a `.gitignore`.
- **2026-03-09 (H2 - Crítico):** Se detectó que `.env` (conteniendo `GEMINI_API_KEY`) se incluye en los assets de `pubspec.yaml`.
  - *Estado:* Persiste para evitar rotura de la app, pero se requiere migración a Edge Functions o Secret Vault.
- **2026-03-09 (H3 - Informativo):** Se identificaron 24 sentencias `debugPrint`.
  - *Prevención:* Implementar un logger que se desactive en producción o usar `kDebugMode`.

### Recomendaciones de Remediación
1. **Rotación de Llaves:** Al haber estado en Git, la `GEMINI_API_KEY` debe ser rotada inmediatamente.
2. **Migración a Backend:** Mover la llamada a `GenerativeModel` a una Supabase Edge Function (`gemini-proxy`) para manejar la API Key de forma segura en el servidor.
3. **Ofuscación:** Utilizar el comando de construcción con `--obfuscate` y `--split-debug-info` para dificultar la ingeniería inversa de los assets.

### Plan de Implementación: Gemini Edge Function
- **Servicio:** Supabase Edge Functions.
- **Nombre:** `gemini-proxy`.
- **Lógica:** Recibir el mensaje del usuario, llamar a la API de Google AI con el API Key almacenado en los Secretos de Supabase, y devolver la respuesta JSON al cliente Flutter.
- **Seguridad:** Requiere JWT de Supabase (Anon Key) para la invocación.
