import subprocess
import time
import os
import logging
import signal

# Versión: 1.0.0
# Descripción: Inicia Flutter Web en el puerto 8080 para visualización.

# Configuración de Logs
logging.basicConfig(
    filename='activity.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

PROJECT_PATH = r"c:\Projects\velvetsync\velvetsyncapp"

def run_flutter_web():
    logging.info("Iniciando Flutter Web para visualización...")
    try:
        # Usamos --web-port para fijar el puerto y --no-hot para evitar logs excesivos
        cmd = ["flutter", "run", "-d", "web-server", "--web-port", "8080", "--web-hostname", "localhost", "--no-hot"]
        
        # Iniciar proceso en segundo plano
        with open("flutter_web.log", "w") as log_file:
            process = subprocess.Popen(
                cmd,
                cwd=PROJECT_PATH,
                stdout=log_file,
                stderr=log_file,
                shell=True,
                creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if os.name == 'nt' else 0
            )
        
        logging.info(f"Proceso Flutter iniciado con PID: {process.pid}")
        print(f"Iniciando servidor web en http://localhost:8080...")
        
        # Dar tiempo a que el servidor inicialice
        max_wait = 60
        waited = 0
        while waited < max_wait:
            time.sleep(5)
            waited += 5
            print(f"Esperando a que el servidor esté listo ({waited}s)...")
            
            # Verificar si el log indica que está corriendo
            if os.path.exists("flutter_web.log"):
                with open("flutter_web.log", "r") as f:
                    content = f.read()
                    if "is being served" in content or "localhost:8080" in content:
                        logging.info("Servidor web listo.")
                        print("¡Servidor listo!")
                        return process
        
        logging.warning("Tiempo de espera agotado, el servidor podría tardar más.")
        return process

    except Exception as e:
        logging.error(f"Error al iniciar Flutter Web: {str(e)}")
        return None

if __name__ == "__main__":
    logging.info("Inicio de ejecución de scripts/visualize_web.py")
    proc = run_flutter_web()
    if proc:
        logging.info("Script finalizado. El servidor sigue en segundo plano.")
    else:
        logging.error("No se pudo iniciar el servidor.")
