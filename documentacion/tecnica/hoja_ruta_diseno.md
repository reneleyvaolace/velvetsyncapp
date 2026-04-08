# Hoja de Ruta: Implementación del Nuevo Diseño Velvet Sync
## Fecha: 2026-04-08 | Estatus: En Progreso

Este documento detalla los cambios requeridos para alinear la aplicación actual con los pantallazos de diseño analizados (Tandas 1-5).

---

## 1. Módulos de Interfaz (UI)

### 1.1 Sistema de Pestañas (Bottom Navigation)
- **Implementar:** 4 Secciones principales: Control, Modos, Remoto, Sistema.
- **Estilo:** Iconografía personalizada con efectos de iluminación Rosa/Cian en estado activo.
- **Estado:** ✅ IMPLEMENTADO (5 tabs: Control, Modos, Remoto, Catálogo, Sistema)

### 1.2 Pantalla de Control Maestro
- **Prioridad:** Media.
- **Cambios:** Añadir indicadores de batería y señal en tiempo real. Implementar el anillo de intensidad circular con blur.
- **Estado:** ✅ IMPLEMENTADO (indicadores de batería y señal en control_tab.dart)

### 1.3 Catálogo de Dispositivos (LVS Catalogue)
- **Implementar:** Vista de tarjetas con imágenes de hardware y sliders de acceso rápido.
- **Buscador:** Filtro por ID o Nombre del modelo.
- **Estado:** ✅ IMPLEMENTADO (WebCatalogScreen + catalog_service)

---

## 2. Características Avanzadas (Core)

### 2.1 Sesión Remota (Host/Guest)
- **Implementar:** WebSocket Service para intercambio de códigos de 6 dígitos.
- **Visual:** Modales de invitación con efecto Glassmorphism.
- **Estado:** ✅ IMPLEMENTADO (remote_session_screen.dart)

### 2.2 Gamificación y Sensores
- **Modo Juego:** Widget de colisiones que interactúe con el motor BLE.
- **Modo Agitar:** Implementación de `sensors_plus` para control por acelerómetro.
- **LVS Canvas:** Área de dibujo táctil para control paramétrico de CH1.
- **Estado:** ✅ IMPLEMENTADO (game_screen.dart, shake mode, canvas en modes_tab)

---

## 3. Deuda Técnica y Correcciones
- [x] **Limpieza de Texto:** Localizar y corregir el string "pajera" por "pareja" en los diálogos de invitación. (VERIFICADO: Ya usaba "pareja")
- [x] **Consola de Logs:** Refactorizar el sistema de logs para que se visualice con el nuevo estilo de color (Dorado/Turquesa).
- [x] **rMesh v2 Protocol:** Asegurar compatibilidad de las tramas de bytes con los selectores 11B/18B vistos en los ajustes.

---

## 4. Listado de Archivos a Crear/Modificar
- [x] `lib/screens/main_navigation.dart` (Sistema de tabs - existente)
- [x] `lib/widgets/glass_card.dart` (Base para todas las interfaces - existente)
- [x] `lib/services/remote/remote_session_service.dart` (Lógica de host/guest - existente)
- [x] `lib/screens/tabs/system_settings_tab.dart` (Ajustes avanzados y logs - existente)
