# Manual Técnico: Comunicación Fastcon rMesh (2026)

## 1. Arquitectura de Comunicación
La aplicación ha sido migrada de **GATT (Central)** a **Advertising (Peripheral)** para soportar dispositivos **Broadlink Fastcon (brMesh)**.

### Flujo de Datos
- **Escaneo:** Se sigue utilizando `flutter_blue_plus` para detectar la presencia de juguetes (filtro por prefijo `wbMSE`).
- **Control:** Ya **no se establece una conexión persistente** (`device.connect()`). En su lugar, cada comando se envía mediante una ráfaga de anuncio Bluetooth (Manufacturer Data).
- **Protocolo:**
  - Company ID: `0xFFF0`
  - Payload: `[Prefijo 8B] + [Comando 3B]`

## 2. Precisión (IsPrecise: 1)
Se ha implementado el control milimétrico del hardware:
- El Slider de la pantalla principal ahora tiene un rango de **0 a 255**.
- Cada valor se mapea directamente al byte de intensidad del protocolo, permitiendo un control más fino.

## 3. Estabilidad y Permisos
- **Android 12+:** Se añadió el flag `neverForLocation` para evitar rastreo innecesario y mejorar la tasa de conexión.
- **iOS:** Se añadieron las llaves de descripción obligatorias para evitar cierres del sistema.
- **Segundo Plano:** El `Foreground Service` se mantiene activo para asegurar que las ráfagas de control no se interrumpan al bloquear el teléfono.

## 4. Gestión de Estado (Riverpod)
El sistema utiliza ahora **Riverpod** (`bleProvider`) para una gestión de estado reactiva y desacoplada del UI, cumpliendo con los estándares de 2026.

## 5. Perfiles de Juguete
Se introdujo la clase `ToyProfile` para gestionar las diferencias entre modelos:
- **LVS-8154:** 1 Canal.
- **LVS-7043:** 2 Canales (ZBTD015).
