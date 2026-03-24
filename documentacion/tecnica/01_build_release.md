# Manual Técnico: Proceso de Build y Firma (Release)

## Versión: 1.0.0 | Fecha: 2026-03-23

### 1. Resumen de la Arquitectura de Firma
La aplicación utiliza un archivo `android/key.properties` para cargar las credenciales de firma de forma dinámica en el archivo `android/app/build.gradle.kts`.

### 2. Configuración de Archivos
- **Ruta del Keystore:** `android/app/upload-ke.jks` (Ignorado por Git).
- **Control de Propiedades:** `android/key.properties` (Ignorado por Git).

### 3. Solución de Problemas Comunes
- **Error "File not found":** 
    - Verifique que no haya espacios al final de las líneas en `key.properties`.
    - Asegúrese de que el archivo `.jks` esté físicamente en `android/app/`.
- **Falta del Keystore:**
    - Si el archivo se pierde, se puede regenerar usando el script `scripts/generate_keystore.py`.
    - **Nota:** Cambiar el keystore impedirá la actualización de versiones instaladas con el anterior (requerirá desinstalación previa).

### 4. Scripts Útiles
- `scripts/fix_release_build.py`: Diagnostica y limpia `key.properties`.
- `scripts/generate_keystore.py`: Genera un nuevo keystore con las credenciales por defecto (`android`).

---
**Coreaura Lab - Sistemas CDMX**
