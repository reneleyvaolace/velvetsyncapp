# Directiva de Sincronización con GitHub
## Versión: 1.0.0 | Última actualización: 2026-03-10

### Objetivo
Sincronizar el repositorio local con la rama remota de GitHub de manera segura, resolviendo divergencias y actualizando las dependencias del proyecto Flutter.

### Entradas
- Repositorio local en `c:\Proyectos\lvs-flutter`.
- Rama remota `origin/main`.

### Lógica de Ejecución
1. **Verificación de Estado:** Ejecutar `git status` para confirmar que el árbol de trabajo está limpio.
2. **Sincronización:**
   - Si las ramas han divergido, realizar un `git pull --rebase origin main` para mantener un historial lineal.
   - Si hay conflictos durante el rebase, el script debe informar y detenerse.
3. **Actualización de Dependencias:** Ejecutar `flutter pub get` tras la sincronización para asegurar que las dependencias estén al día.
4. **Registro:** Documentar cada paso y resultado en `activity.log`.

### Restricciones/Historial de Aprendizaje
- No realizar `git push` automáticamente.
- En caso de divergencia detectada por `git status` (commits locales no enviados), preferir `rebase` para un historial limpio.

### Skills Usadas
- Git CLI
- Flutter CLI (pub get)
