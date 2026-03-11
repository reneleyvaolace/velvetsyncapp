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
- **Limitación de PATH:** Es posible que el comando `adb` no esté en el PATH del sistema, aunque el proceso esté corriendo.
- **Terminación Forzada:** Si `adb kill-server` falla, se debe intentar terminar el proceso `adb` por nombre de sistema (ej. `taskkill /F /IM adb.exe` o `Stop-Process`).
- **Registro:** Siempre verificar si el proceso sigue vivo tras el intento de cierre.

### Skills Usadas
- ADB CLI
