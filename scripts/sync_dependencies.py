import subprocess
import logging
import os

# Versión: 1.0.0
# Descripción: Ejecuta flutter pub get y registra la actividad de migración a Fastcon.

logging.basicConfig(
    filename='activity.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

def run_command(command):
    logging.info(f"Ejecutando: {command}")
    try:
        result = subprocess.run(command, capture_output=True, text=True, shell=True)
        if result.returncode == 0:
            logging.info(f"Éxito: {result.stdout.strip()}")
            return True
        else:
            logging.error(f"Fallo: {result.stderr.strip()}")
            return False
    except Exception as e:
        logging.error(f"Error: {str(e)}")
        return False

def main():
    logging.info("Iniciando fase de migración: Instalación de dependencias (Fastcon/Riverpod)")
    
    # 1. Flutter pub get
    if run_command("flutter pub get"):
        print("Dependencias actualizadas correctamente.")
    else:
        print("Error al actualizar dependencias. Revise activity.log.")

    logging.info("Fase de instalación completada.")

if __name__ == "__main__":
    main()
