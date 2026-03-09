# Directiva: Implementación de Protocolo Fastcon y Optimización BLE (2026)

## Versión: 1.2.0 | Última actualización: 2026-03-06

Este documento define la estrategia técnica para la migración del protocolo de comunicación de LVS Control de BLE GATT estándar a Broadlink Fastcon (brMesh) y la optimización de la estabilidad del sistema.

### 1. Auditoría de Situación Actual
- **Estado:** La aplicación utiliza `flutter_blue_plus` con conexión GATT (`device.connect()`).
- **Problema:** Los modelos 8154 y 7043 son dispositivos Fastcon que prefieren comunicación por anuncios (Advertising). La conexión GATT es inestable o no soportada nativamente por el hardware.
- **Riesgos:** Timeouts de conexión, desconexiones frecuentes en Android 12+.

### 2. Objetivos de Implementación
1.  **Migración a Advertising:** Implementar el envío de comandos mediante paquetes de anuncio (Manufacturer Data).
2.  **Permisos 2026:** Configurar flags de privacidad y descripciones obligatorias en iOS/Android.
3.  **Arquitectura Riverpod:** Migrar de `Provider` a `Riverpod` para una gestión de estado más robusta y asíncrona.
4.  **Precisión (IsPrecise: 1):** Ajustar el slider para control (0-100).
5.  **Estabilidad:** Reforzar el servicio en primer plano y asegurar el flujo de ráfagas.

### 3. Especificaciones Técnicas

#### A. Protocolo Fastcon (brMesh)
- **Modo:** Bluetooth Peripheral (Advertiser).
- **Campo:** Manufacturer Data.
- **Service UUID:** Obligatorio formato largo de 128-bits `0000fff0-0000-1000-8000-00805f9b34fb` (El formato corto causa crash en Java en algunos teléfonos).
- **Company ID:** `0xFFF0`.
- **Intervalo:** ~100ms - 250ms máximo.
- **Paquete (11B):** `[Prefix 8B] + [Cmd 3B]`.
- **Intensidad Proporcional:** 0-100 máximo (0x64), no superar esto.

#### B. Permisos (Privacidad Progresiva)
- **Android:** `BLUETOOTH_SCAN`, `BLUETOOTH_ADVERTISE` con `neverForLocation`.
- **iOS:** `NSBluetoothAlwaysUsageDescription`.

#### C. Lógica de Negocio
- **Throttling:** Los comandos deben filtrarse (no reiniciar publicidad si el comando no cambió).
- **Legacy Mode:** Vital configurar `AdvertiseSetParameters` con `legacyMode: true`, `scannable: true` y `connectable: true`.

### 4. Historial de Aprendizaje
- **[2026-03-05]:** Se detectó que la implementación actual usa GATT, lo cual causa inestabilidad reportada en logs. La documentación técnica de hardware Knight No. 3 confirma el uso de rMesh.
- **Trampa conocida (Advertising):** `flutter_blue_plus` no soporta modo Peripheral. Se requiere integrar `flutter_ble_peripheral` v2.1.0 o superior.
- **Restricciones/Historial de Aprendizaje (Errores Críticos):**
  - **Nota:** No usar la escala de 0-255 en intensidad para chips antiguos, ya que los dispositivos la superan y no responden. En su lugar, escalar a 0-100.
  - **Nota:** No configurar `AdvertiseData` con un Service UUID corto ("FFF0"). Causa una `IllegalArgumentException` en Java en Android. En su lugar, usar siempre el UUID de 128 bits completo.
  - **Nota:** No iniciar el periférico sin parámetros configurados. Los chips del LVS-8154 requieren explícitamente `legacyMode: true`, `scannable: true` y `connectable: true` en `AdvertiseSetParameters`, o de lo contrario no interceptan la señal.
- **[2026-03-06] Confirmación de Motores (LVS-8154):**
  - **Canal General (Ambos):** Ignorado para control seguro. Sirve como Master Stop enviando `E6 8E 00`.
  - **Canal 1 (Empuje):** Confirmado en prefijo `D6 0D`.
  - **Canal 2 (Vibración):** Confirmado en prefijo `E6 8E`. El prefijo secundario `A6 8A` es ignorado por este chip.
  - **Nota de Comportamiento del Juguete:** Este modelo no tiene un botón LED parpadeante, tiene un botón que se queda en color **blanco fijo** cuando está encendido esperando comandos de App. Si se oprime estando en ese estado, entra en los modos de fábrica incrustados y deja de escuchar al smartphone hasta que se vuelva a reiniciar.
  - **Nota:** No enviar intensidad `00` en comandos proporcionales (`0xE6 0x8E 0x00`), ya que la placa base lo ignora. Para apagar un canal individual se debe usar el comando macro de Stop (Ej: `0xD5 0x96 0x4C`).
  - **Nota Crítica de Desempeño Bluetooth:** NO implementar envíos a ráfagas menores a 100ms ni Secuenciadores Matemáticos/Sintetizadores osciladores usando Multiplexación en el teléfono. Superar la cuota de escritura llena el buffer HCI del celular y causa el error permanente de Android `ADVERTISE_FAILED_TOO_MANY_ADVERTISERS (status 2)`. Si esto ocurre el usuario está obligado a reiniciar el Bluetooth del teléfono. Siempre usar `Mutex Locks` lógicos.

### 5. Pasos de Ejecución
1.  Actualizar `AndroidManifest.xml` e `Info.plist`.
2.  Migrar dependencias (Agregar `flutter_ble_peripheral`, `flutter_riverpod`).
3.  Implementar `ToyProfile` y refactorizar `BleService` para usar modo Advertising con Legacy Mode.
4.  Actualizar UI a Riverpod y ajustar Slider de precisión a 0-100.
