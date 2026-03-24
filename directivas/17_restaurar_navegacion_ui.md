## Versión: 1.0.0 | Última actualización: 2026-03-23

# Directiva 17: Restauración de UI y Navegación Principal

## Objetivo
Restaurar los archivos de interfaz de usuario, especialmente la navegación inferior (pantallas de control, modos, navegación, etc.) y reestablecer `lib/main.dart` a su estado previo al commit de limpieza masiva que los eliminó inadvertidamente al apuntar hacia un componente de depuración (`DebugDashboard`).

## Entradas
- Repositorio git en `c:\Proyectos\lvs-flutter`.

## Salidas
- Archivos restaurados de la versión `HEAD~1`.
- `lib/main.dart` revertido a `HEAD~1` para cargar `MainNavigation`.
- Log persistente en `activity.log`.

## Lógica / Pasos a seguir
1. Generar la lista de archivos que fueron eliminados en `lib/` en el último commit.
2. Ejecutar `git checkout HEAD~1 <archivo>` para cada archivo UI que debe ser restaurado.
3. Ejecutar `git checkout HEAD~1 lib/main.dart`.
4. Registrar el resultado de la operación en `activity.log` utilizando el módulo `logging`.

## Trampas Conocidas / Restricciones
- Solo se deben restaurar archivos `.dart` relevantes de `lib/screens` o dependencias perdidas y `lib/main.dart`.
- Evitar hacer un checkout completo (`git checkout HEAD~1 .`) ya que desharía la depuración útil.
- Los iconos referenciados en `MainNavigation` (`assets/icons/`) deben ser revisados para confirmar que existan y restaurarse si fueron borrados.
