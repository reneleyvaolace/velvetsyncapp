## Versión: 1.0.0 | Última actualización: 2026-06-28

# Directiva: Add "My Profile" Access
# Objetivo
Dar al usuario un punto de acceso constante para ver su propio nombre de usuario, el cual necesita para compartirlo con otras personas y ser agregado como contacto.

# Cambios
1. **Acceso a la interfaz**: Se modificó `lib/screens/tabs/settings_tab.dart` para incluir un nuevo botón (`_buildMyProfileCard`) en la sección superior, justo debajo del "Catálogo Web". Este botón dirige nuevamente a `MyProfileScreen`, la cual ya está preparada para funcionar tanto en modo de Creación como de Edición/Visualización.

# Historial de Aprendizaje
- Nota: Las pantallas que se utilizan como Onboarding obligatorio (como MyProfileScreen) deben tener forzosamente un punto de entrada en la navegación principal (Settings), de lo contrario el usuario queda "encerrado" sin poder volver a consultar los datos que creó originalmente.
