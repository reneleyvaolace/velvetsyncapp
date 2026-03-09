# Directiva: Instalación y Verificación de Flutter
## Versión: 1.1.0 | Última actualización: 2026-03-05

### Objetivo
Asegurar que el entorno de desarrollo cuente con Flutter SDK instalado y configurado correctamente en el PATH.

### Entradas
- Comando de verificación: `flutter --version`
- Gestor de paquetes: `winget`

### Lógica de Ejecución
1. **Verificación:** Ejecutar `flutter --version`.
2. **Decisión:**
   - Si se reconoce el comando, verificar salud con `flutter doctor`.
   - Si no se reconoce, proceder a la instalación vía `git clone`.
3. **Instalación Flutter:**
   - Crear directorio `C:\src` si no existe.
   - Ejecutar `git clone https://github.com/flutter/flutter.git -b stable` en `C:\src`.
   - Agregar `C:\src\flutter\bin` al PATH del usuario permanentemente.
4. **Configuración Android SDK:**
   - Instalar Android Studio (incluye el SDK).
   - En Android Studio: `File → Settings → Languages & Frameworks → Android SDK → SDK Tools`.
   - Activar: `Android SDK Command-line Tools (latest)` y `Android SDK Build-Tools`.
   - Si el SDK queda en ruta con espacios (ej. `C:\Users\Sistemas CDMX\...`), ejecutar:
     ```
     flutter config --android-sdk "<ruta al sdk>"
     ```
   - Aceptar licencias: `flutter doctor --android-licenses` (responder `y` a todo).
5. **Visual Studio (para Windows desktop):**
   - Instalar con workload **"Desarrollo de escritorio con C++"**.
   - Si aparece como incompleto, usar el Installer para reparar.
6. **Validación Final:** Ejecutar `flutter doctor` — debe mostrar `No issues found!`.

### Trampas Conocidas
- **PATH:** La modificación del PATH por script requiere una nueva sesión de terminal.
- **Permisos:** Se requiere acceso de escritura en `C:\src`.
- **SDK con espacios en ruta:** Android NDK falla si el path contiene espacios. Solución: usar `flutter config --android-sdk` con la ruta (Flutter la acepta aunque tenga espacios; el problema es solo con NDK tools nativos).
- **cmdline-tools faltante:** No basta con Android Studio. Se debe instalar explícitamente desde SDK Tools en Android Studio.

### Historial de Aprendizaje
- **2026-03-05:** Creación de la directiva inicial.
- **2026-03-05:** Cambio de `winget` a `git clone` — `winget` no localizó el paquete correctamente en el entorno.
- **2026-03-05:** Lección — `cmdline-tools` NO se instala automáticamente con Android Studio; debe activarse manualmente en SDK Tools.
- **2026-03-05:** Lección — SDK en ruta con espacios genera error de NDK. Resolver con `flutter config --android-sdk <ruta>` (Flutter maneja rutas con espacios vía su configuración interna).
- **2026-03-05:** Configuración final verificada: Flutter 3.41.4 stable + Android SDK 36.1.0 + Visual Studio 2026 → `No issues found!`
