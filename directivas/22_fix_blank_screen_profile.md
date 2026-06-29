## Versión: 1.0.0 | Última actualización: 2026-06-28

# Directiva: Fix Blank Screen After Profile Creation
# Objetivo
Corregir la pantalla en blanco que ocurría al guardar el perfil recién creado por primera vez.

# Cambios
1. **Lógica de Navegación Segura**: En `MyProfileScreen`, la pantalla asumía que siempre debía cerrarse con un `Navigator.pop()`. Sin embargo, cuando se lanza desde el SplashScreen por primera vez, reemplaza la pila de navegación (`pushReplacement`). Al hacer `.pop()`, cerraba la única pantalla activa, dejando la aplicación en un lienzo en blanco. Se implementó un condicional `if (Navigator.canPop(context))` para redirigir correctamente a `MainNavigation()` en el primer inicio.

# Historial de Aprendizaje
- Nota: Al utilizar flujos de onboarding o pantallas obligatorias al arranque que reemplazan el historial (`pushReplacement`), las llamadas para salir de esas pantallas no deben ser `Navigator.pop()`, sino una redirección explícita a la pantalla principal, para evitar borrar la raíz de la app y causar pantallas negras/blancas.
