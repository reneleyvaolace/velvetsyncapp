# Documentación Técnica: Flujo de Vinculación BLE (v1.1.0)

## Resumen de Cambios
Se ha rediseñado la lógica de interfaz en `ControlTab` para asegurar una experiencia de usuario coherente y funcional tras la migración a `MainNavigation`.

## 1. Lógica de UI Condicional
Anteriormente, los componentes de "Dispositivo Vinculado" estaban erróneamente agrupados dentro de la condición de "Desconectado", lo que causaba que el botón **Desvincular** apareciera aun cuando no había hardware conectado.

**Nueva Estructura:**
- `if (!ble.isConnected)`: Muestra mensaje de estado "Sin dispositivo" y el botón **INICIAR ESCANEO**.
- `else`: Muestra la tarjeta del dispositivo vinculado (Teal Gradient), info de batería y botón **DESVINCULAR**.

## 2. Inicición de Conexión Manual
Se han habilitado dos métodos para que el usuario inicie la vinculación:

### A. Botón "INICIAR ESCANEO"
Ubicado en la parte superior de `ControlTab` cuando no hay conexión. 
- **Acción:** Ejecuta `ble.connectToDevice()` utilizando el catálogo de modelos preregistrados.
- **Feedback:** El botón cambia a estado "BUSCANDO..." con un indicador de carga mientras el servicio BLE realiza el escaneo.

### B. Panel de Dispositivos Compatibles (`CompatibleDevicesRow`)
Se ha modificado la interacción de los chips de modelos individuales:
- **Acción Anterior:** Abría el catálogo web.
- **Nueva Acción:** Ejecuta `ble.connectToDevice(catalog: [toy])` para intentar vincular específicamente el modelo seleccionado.

## 3. Estado del Servicio
La UI ahora consume `bleStateProvider` para reflejar estados de `scanning` y `connecting` en tiempo real, deshabilitando botones para prevenir ejecuciones concurrentes.

---
**Última Actualización:** 2026-04-16
**Estado:** Implementado en `ControlTab` y `CompatibleDevicesRow`.
