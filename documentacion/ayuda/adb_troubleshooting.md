# Solución a Error de Instalación ADB (MIUI/HyperOS)

## Problema: `INSTALL_FAILED_USER_RESTRICTED`
Este error ocurre comúnmente en dispositivos Xiaomi, Redmi o POCO que ejecutan MIUI o HyperOS cuando el sistema bloquea instalaciones vía USB por seguridad o falta de permisos en las Opciones de Desarrollador.

## Pasos para Solucionar:

1.  **Habilitar Opciones de Desarrollador:**
    - Ve a **Configuración** > **Acerca del teléfono**.
    - Toca 7 veces seguidas en "Versión de MIUI" (o "Versión del SO" en HyperOS) hasta que diga "¡Ahora eres desarrollador!".

2.  **Activar Permisos de Instalación:**
    - Ve a **Configuración** > **Ajustes Adicionales** > **Opciones de Desarrollador**.
    - Asegúrate de que las siguientes opciones estén **ACTIVADAS**:
        - **Depuración USB**
        - **Instalar vía USB** (Es posible que requiera iniciar sesión con una cuenta Mi).
        - **Depuración USB (ajustes de seguridad)** (Esto permite que ADB conceda permisos y realice instalaciones críticas).

3.  **Aceptar el Diálogo en el Teléfono:**
    - Al ejecutar `flutter run`, estate atento a la pantalla de tu teléfono.
    - Aparecerá un diálogo preguntando si deseas instalar la aplicación. **Debes tocar "Aceptar" o "Instalar" antes de que el tiempo se agote** (normalmente 5-10 segundos).

4.  **Si el error persiste:**
    - Desactiva "Optimización de MIUI" al final de las Opciones de Desarrollador (solo como último recurso, ya que puede afectar la UI del sistema).
    - Reinicia el servidor ADB usando el script `scripts/manage_adb.py` o los comandos:
      ```powershell
      adb kill-server
      adb start-server
      ```
