import os
import logging
from datetime import datetime

# Versión: 1.0.0
# Descripción: Script para verificar y corregir la configuración del build de release.

# Configuración de Logs
logging.basicConfig(
    filename='activity.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

def fix_key_properties():
    file_path = "android/key.properties"
    if not os.path.exists(file_path):
        logging.error(f"Archivo {file_path} no encontrado.")
        return False
    
    with open(file_path, "r") as f:
        lines = f.readlines()
    
    new_lines = []
    for line in lines:
        cleaned_line = line.strip()
        if cleaned_line:
            new_lines.append(cleaned_line + "\n")
    
    with open(file_path, "w") as f:
        f.writelines(new_lines)
    
    logging.info(f"Espacios eliminados en {file_path}")
    return True

def verify_keystore():
    # El build.gradle.kts busca en android/app/
    keystore_name = "upload-ke.jks"
    app_dir = "android/app"
    full_path = os.path.join(app_dir, keystore_name)
    
    if os.path.exists(full_path):
        logging.info(f"Keystore {full_path} encontrado.")
        return True
    else:
        logging.error(f"Keystore {full_path} NO ENCONTRADO.")
        # Buscar en todo el proyecto android/ por si acaso
        for root, dirs, files in os.walk("android"):
            if keystore_name in files:
                found_path = os.path.join(root, keystore_name)
                logging.info(f"Keystore encontrado en ubicación alternativa: {found_path}")
                return found_path
        return False

if __name__ == "__main__":
    logging.info("Iniciando fix_release_build.py v1.0.0")
    
    if fix_key_properties():
        print("Configuración de key.properties corregida (espacios eliminados).")
    
    keystore_status = verify_keystore()
    if keystore_status is True:
        print("Estado: El keystore se encuentra en android/app/upload-ke.jks.")
    elif isinstance(keystore_status, str):
        print(f"Estado: El keystore se encuentra en {keystore_status}. Debe estar en android/app/.")
        print("Sugerencia: Cambiar la propiedad 'storeFile' en key.properties o mover el archivo.")
    else:
        print("Error: El archivo 'upload-ke.jks' no se encuentra en el proyecto.")
        print("Por favor, asegúrese de que el archivo keystore esté presente.")
    
    logging.info("Finalizado fix_release_build.py")
