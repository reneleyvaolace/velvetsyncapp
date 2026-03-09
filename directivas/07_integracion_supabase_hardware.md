# Directiva: Integración Supabase + Hardware (Handshake & Sigilo)
## Versión: 1.0.0 | Última actualización: 2026-03-09

Este documento define la lógica de integración entre la base de datos Supabase (Proyecto: baeclricgedhxdtmirid) y los servicios BLE de la aplicación LVS Control.

### 1. Mapeo Dinámico de Dispositivos (Tabla device_catalog)
- **Origen:** Tabla `device_catalog`.
- **Lógica:**
  - Identificar dispositivos por ID de 4 dígitos (ej: 8154).
  - Canales Prioritarios: `0xD` para empuje (Thrust) y `0xA` para vibración.
  - Escalado: Si `is_precise` es verdadero, los comandos deben enviarse en el rango `0-255`. En caso contrario, usar niveles discretos (Bajo/Medio/Alto).
- **Acción:** El `CatalogNotifier` debe migrar de leer el CSV de GitHub a consultar esta tabla vía Supabase SDK.

### 2. Protocolo de Handshake Activo
- **Objetivo:** Evitar conexiones "fantasma" sin respuesta física.
- **Flujo:**
  1. La app localiza el dispositivo wbMSE/8154.
  2. **Envío:** Escribir comando `verification_command` (`0x01`).
  3. **Espera:** Aguardar por el `expected_ack` (`0x06`) del hardware.
  4. **Validación:** Si no se recibe el ACK en 2 segundos, abortar la conexión y marcar como "Hardware Not Responding".

### 3. Gestión de Errores y Seguridad (Bytemaster Lab)
- **Tablas:** `hardware_error_codes` y `hardware_troubleshooting_steps`.
- **Lógica de Protección:**
  - Monitorear errores del sistema.
  - Si se detecta el código `THERM_MAX_80` (Sobrecalentamiento), invocar la función `cooldown()` inmediatamente:
    - Detener todos los motores (`0xE5` o `0x00` en ambos canales).
    - Bloquear la interfaz por 60 segundos con cuenta regresiva.
    - Mostrar mensaje según `hardware_troubleshooting_steps`.

### 4. Políticas de Privacidad y Sigilo
- **Tabla:** `stealth_policies`.
- **Lógica:**
  - Al iniciar una sesión (local o remota), consultar la hora actual del servidor.
  - Si la hora está dentro del rango definido en `stealth_policies`, aplicar `max_intensity_cap` (ej: 40%).
  - Esta restricción es mandatoria y no puede ser ignorada por el usuario.

### 5. Ajustes de UI (Safe Area)
- **Problema:** Desbordamiento en el notch/StatusBar de Android detectado en Alpha.
- **Solución:** Envolver `Scaffold` de todas las pantallas de interacción (`DiceScreen`, `RouletteScreen`, `GameScreen`, `ReaderScreen`) con un `SafeArea` explícito que respete los top insets.

### Historial de Aprendizaje
- *2026-03-09:* Inicialización de la directiva de integración con Supabase. Definición del protocolo de Handshake y políticas de sigilo.
