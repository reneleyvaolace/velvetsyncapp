# Directiva 16: Corrección de Fallo en Build de Release

## Versión: 1.0.0 | Última actualización: 2026-03-23

### Objetivo:
Corregir el error de compilación de Flutter (Release APK) causado por espacios en el archivo `key.properties` y asegurar que el keystore sea encontrado.

### Entradas:
- `android/key.properties`
- `android/app/build.gradle.kts`

### Lógica y Pasos:
1. **Limpieza de `key.properties`:** Eliminar los espacios al final de las líneas en `android/key.properties`. Especialmente en la línea de `storeFile`.
2. **Verificación de Keystore:** Confirmar la existencia de `upload-ke.jks` en la ruta esperada (`android/app/`).
3. **Reintento de Build:** Ejecutar `flutter build apk --release` (o --dev) según sea necesario.

### Restricciones/Historial de Aprendizaje:
- **Espacios Invisibles:** Gradle puede incluir espacios en las rutas de los archivos si se carga directamente desde un archivo de propiedades sin trim. 
- **Ruta Relativa:** En `build.gradle.kts`, `file(it)` busca el archivo relativo al directorio del proyecto `app`.
- **Compilación Fallida sin APK:** Si el build parece terminar pero dice que falló al producir el archivo .apk, es porque el proyecto usa `flavorDimensions`. Siempre pasar `--flavor dev` o `--flavor prod` (ej. `flutter build apk --flavor dev --release`).

### Skills Usadas:
- `view_file`
- `replace_file_content`
- `run_command`
