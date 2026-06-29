## Versión: 1.0.0 | Última actualización: 2026-06-28

# Directiva: Shortcut a Contactos desde Sesión Remota
# Objetivo
Facilitar el flujo de inicio de sesiones remotas con amigos guardados, agregando un acceso directo a la pantalla de Contactos dentro de la misma pantalla de Sesión Remota, para evitar que el usuario tenga que retroceder a otra pestaña.

# Cambios
1. **Acceso UI**: En `lib/screens/remote_session_screen.dart`, se agregó un tercer bloque ("MIS CONTACTOS") debajo de las opciones de Ser Anfitrión e Invitado.
2. **Navegación**: Al hacer tap en este nuevo bloque, se empuja directamente la pantalla `ContactsScreen` al stack de navegación.
3. **Flujo Natural**: Al estar dentro de `ContactsScreen`, si el usuario selecciona un amigo y elige "INICIAR SESIÓN", el sistema crea el token y envía la invitación invisiblemente a través de la tabla `session_invites`.

# Historial de Aprendizaje
- Nota: Las funciones muy acopladas conceptualmente (como controlar remotamente un juguete y elegir con qué contacto hacerlo) no deben estar escondidas en pestañas separadas. Proveer accesos directos interconectados mejora drásticamente la usabilidad, especialmente cuando se agregan nuevas funciones sobre un diseño anterior.
