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
    # Intento 1: comando adb kill-server
    success, output = run_command("adb kill-server")
    if success:
        print("Servidor ADB cerrado correctamente mediante comando.")
        logging.info("Servidor ADB detenido mediante comando adb.")
        return True
    
    # Intento 2: taskkill (Windows)
    print("Comando adb no disponible. Intentando terminación forzada del proceso...")
    success, output = run_command("taskkill /F /IM adb.exe")
    if success:
        print("Proceso adb.exe terminado forzosamente.")
        logging.info("Proceso adb.exe terminado mediante taskkill.")
        return True
    
    # Intento 3: Stop-Process (PowerShell via shell)
    success, output = run_command('powershell -Command "Stop-Process -Name adb -ErrorAction SilentlyContinue"')
    # Nota: Stop-Process no devuelve mucho si funciona, verificamos si el proceso sigue ahí
    
    print("Verificando si el proceso persiste...")
    # Verificación final
    check_success, check_output = run_command('powershell -Command "Get-Process adb -ErrorAction SilentlyContinue"')
    if not check_output:
        print("El proceso ADB ya no se encuentra en ejecución.")
        logging.info("Gestión de ADB exitosa (proceso no detectado).")
        return True
    else:
        print(f"No se pudo cerrar el proceso ADB: {output}")
        return False

if __name__ == "__main__":
    if stop_adb():
        sys.exit(0)
    else:
        sys.exit(1)
