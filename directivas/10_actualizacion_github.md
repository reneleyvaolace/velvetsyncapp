# Directiva 10: Actualización desde GitHub
## Versión: 1.0.0 | Última actualización: 2026-03-11

### Objetivo
Sincronizar el entorno local con los últimos cambios en el repositorio remoto de GitHub de forma segura, garantizando la integridad del sistema.

### Procedimiento
1.  **Auditoría de Estado:**
    -   Ejecutar `git status` para verificar limpieza del working directory.
    -   Confirmar la rama actual (normalmente `main`).
2.  **Sincronización:**
    -   Ejecutar `git pull origin <branch_name>`.
    -   Resolver conflictos si se presentan (notificar al usuario si son críticos).
3.  **Post-Actualización:**
    -   Si `pubspec.yaml` cambió, ejecutar `flutter pub get`.
    -   Si archivos de configuración (.env, etc) requieren cambios, actualizarlos.
4.  **Logging:**
    -   Registrar el éxito o fallo de la operación en `activity.log`.

### Historial de Aprendizaje
- **2026-03-11:** Creación de la directiva para automatizar actualizaciones y registro de logs.
- **2026-03-11:** Confirmado que el working tree está limpio antes de proceder.
