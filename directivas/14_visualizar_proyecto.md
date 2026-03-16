# Directiva de Visualización de Proyecto
## Versión: 1.0.0 | Última actualización: 2026-03-16

### Objetivo
Ejecutar el proyecto en modo web para permitir que el Agente capture una previsualización visual y la presente al usuario.

### Entradas
- SDK de Flutter.
- Archivo `lib/main.dart`.
- Puerto de ejecución (por defecto 8080).

### Lógica de Ejecución
1. **Verificación de Entorno:** Comprobar que Flutter esté instalado y reconozca el dispositivo `chrome`.
2. **Preparación de Archivos:** Asegurarse de que `lib/main.dart` apunte a `SplashScreen` o `ScreenshotGallery` según sea necesario (habitualmente `SplashScreen` para la experiencia completa).
3. **Ejecución de Flutter Web:** Ejecutar `flutter run -d chrome --web-port 8080`.
4. **Captura Visual:** Utilizar el browser subagent para navegar a `localhost:8080` y tomar una captura de pantalla.
5. **Finalización:** Detener el proceso una vez obtenida la imagen.
6. **Registro:** Documentar el éxito o fallo en `activity.log`.

### Restricciones/Historial de Aprendizaje
- **Modo No Interactivo:** Al ejecutar desde scripts, usar flags para evitar bloqueos por prompts del usuario.
- **Tiempos de Carga:** Flutter Web puede tardar unos segundos en inicializar; el browser subagent debe esperar a que el DOM esté listo o usar timeouts.
- **Puerto Ocupado:** Si el puerto 8080 está en uso, se debe intentar con uno alternativo.

### Skills Usadas
- Ejecución de comandos (Flutter)
- Visualización de Navegador (Browser Subagent)
- Gestión de Logs
