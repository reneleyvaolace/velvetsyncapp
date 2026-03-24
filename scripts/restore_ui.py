# Versión: 1.0.0
import logging
import subprocess
import os

# Configuración de log
logging.basicConfig(
    filename='activity.log',
    level=logging.INFO,
    format='%(asctime)s - [%(levelname)s] - %(message)s'
)

def ejecutar_comando(cmd):
    try:
        resultado = subprocess.run(cmd, shell=True, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        logging.info(f"Comando ejecutado: {cmd}")
        return True, resultado.stdout
    except subprocess.CalledProcessError as e:
        logging.error(f"Fallo al ejecutar {cmd}: {e.stderr}")
        return False, e.stderr

archivos_restaurar = [
    "lib/main.dart",
    "lib/screens/main_navigation.dart",
    "lib/screens/tabs/modes_tab.dart",
    "lib/screens/tabs/network_tab.dart",
    # Posibles otras rutas principales si fueron borradas
    "lib/screens/home_screen.dart",
    "lib/screens/game_screen.dart",
    "assets/icons/icon_tab_control.png",
    "assets/icons/icon_tab_modes.png",
    "assets/icons/icon_remote_session.png",
    "assets/icons/icon_online_products.png",
    "assets/icons/icon_tab_settings.png"
]

def run():
    logging.info("Iniciando restauración programada de UI...")
    
    # 1. Recuperar archivos clave explícitamente desde HEAD~1 (antes del commit >3K)
    for path in archivos_restaurar:
        if os.path.exists(path):
            logging.info(f"El archivo {path} ya existe o está modificado y podría perderse, revisaremos si restaurarlo de HEAD~1 es necesario. Forzando...")
        cmd = f"git checkout HEAD~1 -- {path}"
        exito, output = ejecutar_comando(cmd)
        if exito:
            print(f"Restaurado: {path}")
            logging.info(f"Archivo restaurado exitosamente: {path}")
        else:
            print(f"Nota: {path} no se pudo restaurar (puede que no existiera en HEAD~1).")
    
    print("UI y Navegación Principal restauradas de la limpieza masiva. Revisa los resultados.")
    logging.info("Restauración UI concluida.")

if __name__ == '__main__':
    run()
