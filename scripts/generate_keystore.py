import subprocess
import os
import logging

# Versión: 1.0.0
# Descripción: Script para generar un nuevo keystore si no existe.

# Configuración de Logs
logging.basicConfig(
    filename='activity.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

def run_command(command, shell=True):
    logging.info(f"Ejecutando: {command}")
    try:
        result = subprocess.run(command, capture_output=True, text=True, shell=shell)
        if result.returncode == 0:
            return True, result.stdout.strip()
        else:
            return False, result.stderr.strip()
    except Exception as e:
        return False, str(e)

def generate_keystore():
    keytool_path = 'C:\\Program Files\\Android\\Android Studio\\jbr\\bin\\keytool.exe'
    keystore_path = "android/app/upload-ke.jks"
    
    if os.path.exists(keystore_path):
        logging.info("El keystore ya existe. No se generará uno nuevo.")
        return True, "El keystore ya existe."

    # Comando de generación
    # CN=Coreaura Lab, OU=Dev, O=Coreaura, L=CDMX, S=Mexico, C=MX
    cmd = f'"{keytool_path}" -genkey -v -keystore {keystore_path} -alias upload -keyalg RSA -keysize 2048 -validity 10000 -storepass android -keypass android -dname "CN=Coreaura Lab, OU=Dev, O=Coreaura, L=CDMX, S=Mexico, C=MX" -noprompt'
    
    # Crear directorio si no existe
    # app dir is root + android/app
    
    success, output = run_command(cmd)
    if success:
        logging.info(f"Keystore generado con éxito en {keystore_path}")
        return True, output
    else:
        logging.error(f"Fallo al generar keystore: {output}")
        return False, output

if __name__ == "__main__":
    logging.info("Iniciando scripts/generate_keystore.py v1.0.0")
    success, output = generate_keystore()
    if success:
        print(f"Éxito: {output}")
    else:
        print(f"Error al generar keystore: {output}")
    logging.info("Finalizado scripts/generate_keystore.py")
