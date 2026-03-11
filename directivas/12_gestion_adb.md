# Directiva de Gestión de ADB
## Versión: 1.0.0 | Última actualización: 2026-03-10

### Objetivo
Gestionar el ciclo de vida del servidor ADB (Android Debug Bridge) para liberar puertos o solucionar problemas de conectividad con dispositivos físicos/emuladores.

### Entradas
- ADB instalado en el PATH o en la ruta predeterminada del SDK de Android.

### Lógica de Ejecución
1. **Verificación de dispositivos:** Listar dispositivos conectados antes de cualquier acción.
2. **Cierre de Interfaz:** Ejecutar `adb kill-server` para detener el proceso del servidor.
3. **Reinicio (opcional):** Ejecutar `adb start-server` si se requiere restablecer la conexión.
4. **Registro:** Documentar acciones en `activity.log`.

### Restricciones/Historial de Aprendizaje
- Asegurarse de cerrar procesos que dependan de ADB antes de matar el servidor si es posible.

### Skills Usadas
- ADB CLI
