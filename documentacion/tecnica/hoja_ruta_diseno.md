# Hoja de Ruta: Implementación del Nuevo Diseño Velvet Sync
## Fecha: 2026-04-07 | Estatus: En Análisis

Este documento detalla los cambios requeridos para alinear la aplicación actual con los pantallazos de diseño analizados (Tandas 1-5).

---

## 1. Módulos de Interfaz (UI)

### 1.1 Sistema de Pestañas (Bottom Navigation)
- **Implementar:** 4 Secciones principales: Control, Modos, Remoto, Sistema.
- **Estilo:** Iconografía personalizada con efectos de iluminación Rosa/Cian en estado activo.

### 1.2 Pantalla de Control Maestro
- **Prioridad:** Media.
- **Cambios:** Añadir indicadores de batería y señal en tiempo real. Implementar el anillo de intensidad circular con blur.

### 1.3 Catálogo de Dispositivos (LVS Catalogue)
- **Implementar:** Vista de tarjetas con imágenes de hardware y sliders de acceso rápido.
- **Buscador:** Filtro por ID o Nombre del modelo.

---

## 2. Características Avanzadas (Core)

### 2.1 Sesión Remota (Host/Guest)
- **Implementar:** WebSocket Service para intercambio de códigos de 6 dígitos.
- **Visual:** Modales de invitación con efecto Glassmorphism.

### 2.2 Gamificación y Sensores
- **Modo Juego:** Widget de colisiones que interactúe con el motor BLE.
- **Modo Agitar:** Implementación de `sensors_plus` para control por acelerómetro.
- **LVS Canvas:** Área de dibujo táctil para control paramétrico de CH1.

---

## 3. Deuda Técnica y Correcciones
- **Limpieza de Texto:** Localizar y corregir el string "pajera" por "pareja" en los diálogos de invitación.
- **Consola de Logs:** Refactorizar el sistema de logs para que se visualice con el nuevo estilo de color (Dorado/Turquesa).
- **Rmesh v2 Protocol:** Asegurar compatibilidad de las tramas de bytes con los selectores 11B/18B vistos en los ajustes.

---

## 4. Listado de Archivos a Crear/Modificar
- [ ] `lib/screens/main_navigator.dart` (Nuevo sistema de tabs)
- [ ] `lib/widgets/glass_card.dart` (Base para todas las interfaces)
- [ ] `lib/services/remote/remote_session_service.dart` (Logica de host/guest)
- [ ] `lib/screens/tabs/system_settings_tab.dart` (Ajustes avanzados y logs)
