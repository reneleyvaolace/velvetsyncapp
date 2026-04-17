# Directiva: Corrección de Lógica de UI en ControlTab
## Versión: 1.0.0 | Última actualización: 2026-04-16

### Objetivo
Corregir la lógica de visualización en `lib/screens/tabs/control_tab.dart` donde los componentes de "Dispositivo Vinculado" se muestran erróneamente cuando no hay conexión, bloqueando o confundiendo el flujo de vinculación.

### Contexto del Error
En el método `_buildConnectCard`, el bloque condicional `if (!ble.isConnected) ...[` engloba tanto el mensaje de "Sin dispositivo" como la tarjeta de dispositivo vinculado y el botón de "Desvincular". Esto causa que:
1. Cuando NO hay conexión, se muestre el botón de "Desvincular".
2. Cuando SÍ hay conexión, no se muestre nada (porque `!ble.isConnected` es falso).

### Pasos de Ejecución
1. Modificar `c:\Proyectos\lvs-flutter\lib\screens\tabs\control_tab.dart`:
   - Separar el bloque `if (!ble.isConnected)` para que solo contenga el mensaje de "Sin dispositivo".
   - **Añadir un botón de "INICIAR ESCANEO"** dentro del bloque `if (!ble.isConnected)` que llame a `ble.connectToDevice()`.
   - Crear un bloque `else` (o un `if (ble.isConnected)`) para los componentes de dispositivo vinculado.
2. Modificar `c:\Proyectos\lvs-flutter\lib\widgets\compatible_devices_row.dart`:
   - Cambiar la acción `onTap` de `_DeviceChip` para que intente conectar al modelo seleccionado (`ble.connectToDevice(catalog: [toy])`) en lugar de abrir el catálogo web.
3. Asegurar que las llamadas a `withOpacity` sigan migradas a `withValues`.

### Historial de Aprendizaje
- 2026-04-16: Se detectó que el botón "Desvincular" aparecía por defecto debido a una agrupación incorrecta de widgets en una colección condicional de Flutter.
