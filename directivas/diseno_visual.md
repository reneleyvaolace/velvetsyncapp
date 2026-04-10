# Directiva: Sistema de Diseño Visual e Iconografía
## Versión: 1.0.0 | Última actualización: 2026-04-10

### Objetivo
Mantener una estética premium, coherente y determinista en todos los componentes de control de Velvet Sync, utilizando activos visuales de alta calidad mapeados a los comandos BLE.

### Jerarquía de Iconos
Para evitar el uso de iconos genéricos de Material Design, se deben utilizar los siguientes activos alojados en `assets/icons/`:

| Elemento / Modo | Activo Recomendado | Color Sugerido |
| :--- | :--- | :--- |
| **Manual / Control** | `assets/icons/icon_motion_control.png` | `LvsColors.teal` |
| **Suave / Cool Down** | `assets/icons/icon_cool_down.png` | `LvsColors.blue` |
| **Medio / Heart** | `assets/icons/icon_heart.png` | `LvsColors.pink` |
| **Fuerte / Thrust** | `assets/icons/icon_thrust.png` | `LvsColors.red` |
| **Ola / Waves** | `assets/icons/icon_pulse_waves.png` | `LvsColors.violet` |
| **Pulso / Music** | `assets/icons/icon_sync_music.png` | `LvsColors.pink` |
| **Rampa / Vibrator** | `assets/icons/icon_vibrator.png` | `LvsColors.teal` |
| **Flip / Dual Motor** | `assets/icons/icon_dual_motor.png` | `LvsColors.amber` |
| **Storm / Tornado** | `assets/icons/icon_cool_down.png` | `LvsColors.teal` |
| **Caos / Custom** | `assets/icons/icon_custom_pattern.png` | `LvsColors.red` |

### Reglas de Implementación
1. **Consistencia:** Los nombres y activos usados en `home_screen.dart` deben coincidir con los de `lvs_modes.dart`.
2. **Blend Mode:** Utilizar siempre `colorBlendMode: BlendMode.srcIn` al renderizar iconos PNG para permitir cambios dinámicos de color manteniendo la transparencia.
3. **Fallback:** Siempre incluir un `errorBuilder` con un icono de Material equivalente para evitar espacios vacíos si el activo falla.
4. **Haptics:** Cada interacción con un selector de modo debe disparar `HapticFeedback.selectionClick()`.

### Lógica de Interacción (Toggle)
Para mejorar la usabilidad y reducir la dependencia del botón de parada de emergencia:
1. **Comportamiento Toggle:** Si un usuario presiona un modo que ya está activo, el sistema debe interpretar esto como una orden de "Apagar" y detener todos los motores.
2. **Visualización:** El estado activo debe ser claramente distinguible mediante un cambio de color de fondo (opacidad 0.15) y sombras neón.
3. **Respuesta Inmediata:** La detención debe ocurrir mediante el método `stopAllMotors()` del servicio BLE, que envía comandos de parada a ambos canales de forma secuencial.

### Historial de Aprendizaje
- **2026-04-10:** Se detectó que la pantalla principal usaba iconos genéricos `noise_control_off`. Se migró a un sistema basado en `Image.asset` con mapeo determinista por cada patrón rítmico.
- **2026-04-10:** Implementada lógica de "Toggle-to-Stop" en `BleService`. Ahora, al presionar un modo activo, el dispositivo se detiene automáticamente, eliminando la fricción de tener que buscar el botón de emergencia para paradas rutinarias.
