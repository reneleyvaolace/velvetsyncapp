## Versión: 1.0.0 | Última actualización: 2026-06-28

# Directiva: Panel de Bienvenida y Accesos Rápidos
# Objetivo
Mejorar la retención y la agilidad de uso para los usuarios que acaban de iniciar sesión o abrir la app (y aún no tienen un dispositivo conectado), ofreciéndoles acciones directas en lugar de mostrar modelos fijos que rompen el diseño.

# Cambios
1. **Remoción de UI estática**: Se eliminó el uso del widget `CompatibleDevicesRow` en `lib/screens/tabs/control_tab.dart`.
2. **Tarjeta de Bienvenida**: Se creó una tarjeta `_buildWelcomeAndShortcuts` que saluda al usuario, explica brevemente qué hacer (encender y buscar), y sugiere el modo demo.
3. **Botones de atajo rápido**: Se implementaron 3 tarjetas pequeñas para ir al Catálogo (`CatalogScreen`), entrar a Sesiones Remotas (`RemoteSessionScreen`) o activar el MODO DEMO, centralizando las mejores funciones de la app desde el primer segundo.

# Historial de Aprendizaje
- Nota: La pantalla de inicio nunca debe sentirse como un callejón sin salida (dead end). Si el usuario no tiene un dispositivo físico, el "Modo Demo" debe ser el Call to Action principal, secundado por la posibilidad de ver el catálogo web o unirse a una sesión remota (donde su pareja tenga el dispositivo).
