import subprocess
import logging
import sys

# Versión: 1.0.0
# Descripción: Script para gestionar la interfaz ADB (matar el servidor).

# Configuración de Logs
logging.basicConfig(
    filename='activity.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

def run_command(command):
    logging.info(f"Ejecutando comando: {command}")
    try:
        result = subprocess.run(command, capture_output=True, text=True, shell=True)
        if result.returncode == 0:
            logging.info(f"Comando exitoso: {result.stdout.strip()}")
            return True, result.stdout.strip()
        else:
            logging.error(f"Fallo en comando: {result.stderr.strip()}")
            return False, result.stderr.strip()
    except Exception as e:
        logging.error(f"Error inesperado: {str(e)}")
        return False, str(e)

def stop_adb():
    print("Intentando cerrar el servidor ADB...")
    success, output = run_command("adb kill-server")
    if success:
        print("Servidor ADB cerrado correctamente.")
        logging.info("Servidor ADB detenido por el usuario.")
        return True
    else:
        print(f"Error al cerrar ADB: {output}")
        return False

if __name__ == "__main__":
    if stop_adb():
        sys.exit(0)
    else:
        sys.exit(1)
