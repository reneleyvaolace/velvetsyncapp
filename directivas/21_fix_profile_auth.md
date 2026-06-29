## Versión: 1.0.0 | Última actualización: 2026-06-28

# Directiva: Fix Profile Auth Fallback
# Objetivo
Corregir el error "User is not authenticated" al crear el perfil por primera vez si la inicialización en `main.dart` falló o se perdió la sesión.

# Cambios
1. **Fallback de Autenticación**: En `ProfileService.createProfile`, si el `_currentUserId` es null (porque la autenticación en main falló, tal vez por un microcorte de red), se intenta llamar a `_client.auth.signInAnonymously()` de forma sincrónica antes de fallar.

# Historial de Aprendizaje
- Nota: No depender exclusivamente de la autenticación asíncrona de inicialización en `main.dart`, porque puede fallar silenciosamente en redes inestables o por timeouts, dejando al usuario atrapado en la pantalla de Creación de Perfil. En su lugar, añadir un reintento "Just-In-Time" (JIT) justo antes de requerir el ID de usuario en las operaciones de escritura como `createProfile`.
