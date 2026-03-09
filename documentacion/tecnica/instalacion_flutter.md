# Manual Técnico: Instalación de Flutter SDK
## Versión: 1.0.0 | 2026-03-05

### Resumen
Este documento describe el procedimiento automatizado para la instalación de Flutter en entornos Windows de la organización, utilizando `git clone` y persistencia de PATH.

### Requisitos Previos
- Windows 10/11.
- Git (versión 2.0 o superior).
- Conexión a internet estable.

### Procedimiento de Instalación
La instalación se realiza mediante el script `scripts/manage_flutter.py`, el cual realiza las siguientes acciones:
1. Crea el directorio base `C:\src`.
2. Clona la rama `stable` de Flutter desde el repositorio oficial de GitHub: `https://github.com/flutter/flutter.git`.
3. Registra el directorio `bin` en la variable de entorno PATH del usuario mediante PowerShell.

### Verificación
Para confirmar que la instalación fue exitosa:
1. Cerrar todas las terminales abiertas.
2. Abrir una nueva terminal.
3. Ejecutar `flutter --version`.
4. Ejecutar `flutter doctor` para verificar dependencias adicionales de Android/iOS.

### Resolución de Problemas
- **Comando no reconocido:** Verifique que el PATH del usuario incluya `C:\src\flutter\bin`.
- **Error en clonación:** Asegúrese de tener permisos de escritura en el disco `C:\`.
