import subprocess
import logging
import os
import sys

# Versión: 1.1.0
# Descripción: Script corregido para instalar Flutter vía git clone y actualizar el PATH

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
            logging.info(f"Comando exitoso")
            return True, result.stdout.strip()
        else:
            logging.error(f"Fallo en comando: {result.stderr.strip()}")
            return False, result.stderr.strip()
    except Exception as e:
        logging.error(f"Error inesperado: {str(e)}")
        return False, str(e)

def setup_path(flutter_path):
    print(f"Configurando PATH para incluir {flutter_path}...")
    ps_command = f'[Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User) + ";{flutter_path}", [EnvironmentVariableTarget]::User)'
    success, output = run_command(f'powershell -Command "{ps_command}"')
    if success:
        print("PATH actualizado permanentemente (Nivel Usuario).")
        return True
    else:
        print(f"Error al actualizar PATH: {output}")
        return False

def install_flutter_git():
    src_dir = "C:\\src"
    if not os.path.exists(src_dir):
        print(f"Creando directorio {src_dir}...")
        os.makedirs(src_dir)
    
    flutter_dir = os.path.join(src_dir, "flutter")
    if os.path.exists(flutter_dir):
        print("El directorio de Flutter ya existe. Intentando actualizar...")
        os.chdir(flutter_dir)
        run_command("git pull")
        os.chdir("..")
    else:
        print("Descargando Flutter SDK (Clone)... Esto puede tardar unos minutos.")
        success, output = run_command(f"git clone https://github.com/flutter/flutter.git -b stable {flutter_dir}")
        if not success:
            print(f"Error al clonar Flutter: {output}")
            return False

    bin_path = os.path.join(flutter_dir, "bin")
    setup_path(bin_path)
    return True

if __name__ == "__main__":
    logging.info("Inicio de ejecución de scripts/manage_flutter.py v1.1.0")
    
    # Verificar Git
    success, output = run_command("git --version")
    if not success:
        print("Error: Git no está instalado o no se encuentra en el PATH.")
        sys.exit(1)
        
    # Verificar si ya existe en el PATH actual
    success, output = run_command("flutter --version")
    if success:
        print(f"Flutter ya está disponible: {output}")
    else:
        if install_flutter_git():
            print("\nInstalación finalizada con éxito.")
            print("IMPORTANTE: Cierre esta terminal y abra una nueva para que el comando 'flutter' sea reconocido.")
            print("Luego ejecute 'flutter doctor' para completar la configuración.")
        else:
            print("Hubo un error en el proceso de instalación.")
            sys.exit(1)

    logging.info("Fin de ejecución v1.1.0")
