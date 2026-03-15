import subprocess
import os
import logging
from datetime import datetime

# Versión: 1.0.0 | Última actualización: 2026-03-11
# Script para sincronización con GitHub y actualización de dependencias

# Configuración de Logging según Directiva 09
logging.basicConfig(
    filename='activity.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

def run_command(command):
    """Ejecuta un comando del sistema y devuelve su salida y código de retorno."""
    try:
        result = subprocess.run(command, capture_output=True, text=True, shell=True)
        return result.stdout, result.stderr, result.returncode
    except Exception as e:
        return "", str(e), 1

def git_sync():
    """Realiza el pull de GitHub y verifica cambios en pubspec.yaml."""
    logging.info("--- Iniciando Sincronización con GitHub ---")
    print("Sincronizando con el repositorio remoto...")

    # 1. Verificar estado actual
    status_stdout, _, _ = run_command("git status")
    if "nothing to commit" not in status_stdout and "working tree clean" not in status_stdout:
        # Si hay modificaciones que impidan un pull (tracked files modified), paramos.
        # Pero permitiremos si solo hay Untracked files.
        if "Changes not staged for commit" in status_stdout or "Changes to be committed" in status_stdout:
            msg = "Error: Existen cambios en el working tree que podrían entrar en conflicto. Realice stash o commit primero."
            logging.error(msg)
            print(msg)
            return
    
    # Continuamos si el estado es aceptable

    # 2. Ejecutar Git Pull
    stdout, stderr, code = run_command("git pull origin main")
    
    if code != 0:
        logging.error(f"Fallo en git pull: {stderr}")
        print(f"Error al actualizar: {stderr}")
        return

    logging.info(f"Git pull exitoso: {stdout.strip()}")
    print("Actualización de código completada.")

    # 3. Verificar si pubspec.yaml fue modificado en el pull
    if "pubspec.yaml" in stdout:
        logging.info("Cambios detectados en pubspec.yaml. Ejecutando flutter pub get...")
        print("Detectados cambios en dependencias. Actualizando paquetes...")
        
        # Intentar ejecutar flutter pub get
        pub_stdout, pub_stderr, pub_code = run_command("flutter pub get")
        
        if pub_code == 0:
            logging.info("Dependencias de Flutter actualizadas con éxito.")
            print("Dependencias sincronizadas correctamente.")
        else:
            logging.error(f"Error al ejecutar flutter pub get: {pub_stderr}")
            print(f"Error en flutter pub get: {pub_stderr}")
    else:
        logging.info("No se detectaron cambios en pubspec.yaml.")
        print("No se requieren actualizaciones de dependencias.")

    logging.info("--- Finalización de Sincronización ---")

if __name__ == "__main__":
    git_sync()
