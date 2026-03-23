# Directiva: Limpieza y Análisis de Código
## Versión: 1.0.0 | Última actualización: 2026-03-22

### Objetivo
Resolver los 180 problemas detectados por `flutter analyze` para asegurar la estabilidad del proyecto y cumplir con los estándares de calidad del sistema.

### Entradas
- Resultado de `flutter analyze`.
- Archivos del proyecto en `lib/`.
- Reglas de linting configuradas en `analysis_options.yaml`.

### Lógica de Ejecución
1. **Categorización de Errores**: Identificar los patrones más comunes (omit_local_variable_types, prefer_const_constructors, etc.).
2. **Automatización de Arreglos**:
   - Ejecutar `dart fix --apply` para resolver problemas automáticos.
   - Desarrollar un script en Python (`scripts/fix_analysis_issues.py`) para patrones complejos no cubiertos por `dart fix`.
3. **Verificación Manual**: Revisar cambios críticos en servicios de hardware y backend.
4. **Validación Final**: Ejecutar `flutter analyze` nuevamente hasta alcanzar 0 errores/advertencias.
5. **Registro de Logs**: Documentar cada fase de limpieza en `activity.log`.

### Restricciones/Historial de Aprendizaje
- **Nota**: No automatizar cambios en lógica de protocolos BLE sin revisión, ya que pequeños cambios en tipos pueden afectar la serialización de bytes.
- **Nota**: `dart fix` es potente pero a veces sugiere `const` en lugares donde la inyección de dependencias (Riverpod) requiere mutabilidad.

### Skills Usadas
- Análisis Estático (Flutter/Dart)
- Automatización con Python
- Gestión de Logs
