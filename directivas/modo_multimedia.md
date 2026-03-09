## Versión: 1.5.0 | Última actualización: 2026-03-06

# Modo Multimedia Local (Knight No. 3 - 8154)

## Objetivo
Sincronizar la intensidad de los motores del modelo LVS-8154 con el ritmo y amplitud de archivos de audio locales (MP3/MP4).

## Requisitos Técnicos
### Dependencias
- `just_audio`: Reproducción de audio y gestión de estados.
- `file_picker`: Selección de archivos desde el almacenamiento.
- `audio_waveforms` (o similar): Procesamiento de la forma de onda para extracción de RMS.
- `flutter_riverpod`: Gestión del estado del reproductor y sincronización.

### Lógica de Mapeo (Protocolo Preciso)
- **Canal 2 (Vibración):** Prefijo `0xA`. Rango `0-255`. IsPrecise: True.
- **Canal 1 (Empuje):** Prefijo `0xD`. Activación por picos (Beat Detection).
- **Throttling:** Intervalo de 250ms (4Hz) para evitar saturación del buffer BLE.

## Flujo de Trabajo
1. **Selección:** El usuario selecciona un archivo local.
2. **Pre-procesamiento:** Se genera un mapa de energía (amplitudes) del archivo para evitar cálculos pesados en tiempo real.
3. **Playback:** Al iniciar la reproducción, un Timer de 250ms consulta la posición actual del audio.
4. **Sincronización:**
   - Se obtiene la amplitud RMS de la posición actual.
   - Se envía comando de intensidad proporcional al Canal 2.
   - Si la amplitud supera el umbral del 80%, se envía ráfaga al Canal 1.
5. **UI:** Visualizador de progreso, visualizador de picos y controles básicos.

## Historial de Aprendizaje
- Nota: El uso de GATT persistente para batería causaba errores de licencia en FBP 2.x; el modo Multimedia operará sobre el flujo Fastcon existente para máxima estabilidad.
- Restricción: No exceder 4 paquetes por segundo para mantener la respuesta "en tiempo real" sin lag.
- Observación Técnica (2026-03-06): La implementación lógica de extracción de audio (RMS) y normalización funciona en app, pero el dispositivo físico no responde como se espera. Posibles causas para investigar a futuro: umbrales (0-255 vs 0-100), desfases del Bluetooth buffer para envíos 4Hz, o requerimiento de curvas de aceleración específicas para los actuadores LVS-8154. Se pausó el desarrollo de la calibración fina para el hardware.
