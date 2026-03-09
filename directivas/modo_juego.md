## Versión: 1.0.0 | Última actualización: 2026-03-06

# Directiva: Modo Juego Local (Flame) para LVS-8154

## Objetivo
Integrar un mini-juego interactivo de físicas (estilo frutas rectangulares o circulares fusionables) usando el motor `flame`.
Las interacciones en el juego deben traducirse a comandos hápticos precisos enviados al dispositivo LVS-8154 utilizando el protocolo rMesh/BLE actual.

## Lógica y Haptic Feedback (LVS-8154)
- **Choque Ligero (Pequeños rebotes):**
  - Acción: Ráfaga de 200ms.
  - Canal: Canal 2 (Vibración, prefijo 0xA).
  - Comando Base Estático (Intensidad Media): `[0xA7, 0x03, 0x1C]`.
  
- **Fusión/Level Up (Grandes choques):**
  - Acción: Ráfaga de 500ms.
  - Canal: Canal 1 (Empuje/Motor Principal, prefijo 0xD).
  - Comando Base Estático (Intensidad Máxima): `[0xD6, 0x0D, 0x7E]`.

- **Progresión de Dificultad:**
  - A medida que el score aumenta, se puede sustituir el comando estático por una variación dinámica usando `[0xD6, 0x0D, INTENSIDAD]`, considerando que la propiedad `IsPrecise: 1` permite valores de 0 a 255.
  
- **Throttling Crítico (Prevención de Flood):**
  - Restricción: No se deben enviar comandos BLE a una frecuencia mayor a 4Hz (Wait mínimo de 250ms entre ráfagas).
  - Trampa Conocida: Saturar el bus Bluetooth con comandos por colisión provocará un cuelgue del dispositivo físico (buffer overflow) provocando desincronización o desconexión.
  - Solución: Implementar un `_lastCommandTime` en el control del juego para rechazar o encolar hápticos que ocurran muy cerca en el tiempo.

## Interfaz de Usuario
- El widget del juego ocupa toda pantalla (`Scaffold.body`).
- Un botón "Salir y Detener" debe estar claramente visible en la pantalla (usualmente como un overlay sobre el juego).
- Acción del botón salir: 
  1. Enviar comando de parada general: `[0xE5, 0x15, 0x7D]`.
  2. Cerrar la pantalla usando `Navigator.pop(context)`.

## Consideraciones de Implementación Flame
- Usar `Forge2DGame` o lógica circular base en componentes Flame para físicas (gravedad, colisiones y merge).
- Crear un `CircleComponent` base y manejar `onCollisionStart` o delegar a un `CollisionCallbacks`.
- Se requiere arrastrar y soltar: usar `DragCallbacks`.
