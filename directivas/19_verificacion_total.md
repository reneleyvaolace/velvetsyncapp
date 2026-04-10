# Directiva: Verificación Total del Proyecto (Velvet Sync)
## Versión: 1.0.0 | Última actualización: 2026-03-27

### Objetivo
Realizar una auditoría exhaustiva del proyecto para asegurar su integridad técnica, funcional y de seguridad tras múltiples fases de refactorización y saneamiento.

### Entradas
- Código fuente en `lib/`.
- Archivos de configuración (`pubspec.yaml`, `analysis_options.yaml`).
- Logs previos en `activity.log` y `security_results.log`.
- Herramientas de CLI: `flutter`, `dart`.

### Lógica de Ejecución
1. **Auditoría de Dependencias**: 
   - Ejecutar `flutter pub get` para verificar que todas las dependencias sean alcanzables.
   - Revisar `pubspec.yaml` en busca de versiones obsoletas o conflictos.
2. **Análisis Estático**:
   - Ejecutar `flutter analyze` y capturar el resultado en `build_errors_full.txt`.
   - Categorizar errores remanentes (especialmente imports rotos tras la migración a `velvet_sync`).
3. **Verificación de Estructura**:
   - Validar que todos los archivos referenciados en `home_screen.dart` existan o estén correctamente comentados según la directiva 15.
   - Comprobar que el paquete `velvet_sync` es el nombre oficial en todos los archivos.
4. **Pruebas de Compilación**:
   - Intentar una compilación de prueba (dry-run) para Android para detectar errores de Manifest o Gradle.
5. **Auditoría de Seguridad**:
   - Ejecutar `scripts/enhanced_audit.py` para detectar IPs hardcoded o fugas de logs.
6. **Consolidación de Resultados**:
   - Generar un reporte final en `documentacion/tecnica/reporte_verificacion_total.md`.

### Restricciones/Historial de Aprendizaje
- **Nota**: El proyecto fue renombrado de `lvs_control` a `velvet_sync`. Algunos scripts antiguos podrían seguir usando el nombre viejo.
- **Nota**: Se han detectado múltiples archivos faltantes en `lib/screens/` que fueron comentados para permitir la compilación. No revertir estos cambios sin antes confirmar la existencia de los archivos.
- **Nota**: Al usar los productFlavors definidos en Gradle (`dev`, `prod`), NUNCA usar `flutter build apk` a secas. Hacer `flutter build apk --flavor dev` para evitar el error "failed to produce an .apk file".

### Skills Usadas
- Análisis Estático (Flutter/Dart)
- Auditoría de Seguridad
- Gestión de Dependencias
- Automatización con Python
