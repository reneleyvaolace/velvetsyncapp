import subprocess
import logging
import os
import sys

# Versión: 1.0.0
# Descripción: Script de sincronización con GitHub y actualización de dependencias Flutter.

# Configuración de Logs
logging.basicConfig(
    filename='activity.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

def run_command(command, shell=True):
    logging.info(f"Ejecutando comando: {' '.join(command) if isinstance(command, list) else command}")
    try:
        result = subprocess.run(command, capture_output=True, text=True, shell=True)
        if result.returncode == 0:
            logging.info(f"Comando exitoso: {result.stdout.strip()[:100]}...")
            return True, result.stdout.strip()
        else:
            logging.error(f"Fallo en comando: {result.stderr.strip()}")
            return False, result.stderr.strip()
    except Exception as e:
        logging.error(f"Error inesperado: {str(e)}")
        return False, str(e)

def sync_github():
    print("Iniciando sincronización con GitHub...")
    logging.info("Inicio de sincronización git_sync.py v1.0.0")

    # 1. Verificar estado de git
    success, output = run_command("git status")
    if not success:
        print(f"Error al verificar estado de git: {output}")
        return False

    # 2. Pull con rebase para mantener historial lineal
    print("Ejecutando git pull --rebase origin main...")
    success, output = run_command("git pull --rebase origin main")
    if not success:
        print(f"Error durante git pull --rebase: {output}")
        logging.error("Conflicto o error detectado en rebase. Deteniendo proceso.")
        return False
    print("Sincronización de git completada.")

    # 3. Actualizar dependencias de Flutter
    print("Ejecutando flutter pub get...")
    success, output = run_command("flutter pub get")
    if not success:
        print(f"Error al ejecutar flutter pub get: {output}")
        return False
    print("Dependencias de Flutter actualizadas.")

    logging.info("Sincronización y actualización finalizada con éxito.")
    return True

if __name__ == "__main__":
    if sync_github():
        print("\nProceso finalizado con éxito.")
    else:
        print("\nHubo un error en el proceso de actualización.")
        sys.exit(1)
