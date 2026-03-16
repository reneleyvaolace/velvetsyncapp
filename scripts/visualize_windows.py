import subprocess
import time
import os
import logging

# Versión: 1.0.0
# Descripción: Inicia Flutter en Windows y toma una captura de pantalla del escritorio.

# Configuración de Logs
logging.basicConfig(
    filename='activity.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

PROJECT_PATH = r"c:\Projects\velvetsync\velvetsyncapp"
BRAIN_DIR = r"C:\Users\renel\.gemini\antigravity\brain\b7af1595-bbaa-40a3-b534-d82b9447d536"

def kill_app():
    logging.info("Deteniendo procesos previos de lvs_control...")
    subprocess.run(['powershell', '-Command', 'Get-Process | Where-Object { $_.MainWindowTitle -eq "lvs_control" } | Stop-Process -Force'], capture_output=True, shell=True)
    subprocess.run(['powershell', '-Command', 'Get-Process lvs_control -ErrorAction SilentlyContinue | Stop-Process -Force'], capture_output=True, shell=True)

def run_windows_app():
    logging.info("Iniciando Flutter en Windows...")
    kill_app()
    
    # Iniciar la app
    cmd = ["flutter", "run", "-d", "windows", "--no-hot"]
    with open("flutter_windows.log", "w") as log_file:
        proc = subprocess.Popen(cmd, cwd=PROJECT_PATH, stdout=log_file, stderr=log_file, shell=True)
    
    print("App iniciada. Esperando a que aparezca la ventana (máx 3 min)...")
    timeout = 180
    start_time = time.time()
    while time.time() - start_time < timeout:
        result = subprocess.run(['powershell', '-Command', 'Get-Process | Where-Object { $_.MainWindowTitle -eq "lvs_control" }'], capture_output=True, text=True, shell=True)
        if "lvs_control" in result.stdout:
            print("¡Ventana detectada! Esperando renderizado (20s)...")
            time.sleep(20)
            return True
        time.sleep(10)
        print(f"Buscando ventana... ({int(time.time() - start_time)}s)")
    
    logging.error("Timeout esperando la ventana de Windows.")
    return False

def take_screenshot():
    logging.info("Tomando captura de pantalla del escritorio...")
    timestamp = time.strftime("%Y%m%d_%H%M%S")
    output_temp = os.path.join(BRAIN_DIR, f"windows_preview_{timestamp}.png")
    
    # Script de PowerShell embebido para evitar dependencias de archivos externos mal configurados
    ps_code = f"""
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $Screen = [System.Windows.Forms.Screen]::PrimaryScreen
    $Bitmap = New-Object System.Drawing.Bitmap -ArgumentList $Screen.Bounds.Width, $Screen.Bounds.Height
    $Graphics = [System.Drawing.Graphics]::FromImage($Bitmap)
    $Graphics.CopyFromScreen($Screen.Bounds.Left, $Screen.Bounds.Top, 0, 0, $Bitmap.Size)
    $Bitmap.Save('{output_temp}', [System.Drawing.Imaging.ImageFormat]::Png)
    $Graphics.Dispose()
    $Bitmap.Dispose()
    """
    
    subprocess.run(['powershell', '-Command', ps_code], capture_output=True, shell=True)
    if os.path.exists(output_temp):
        print(f"Captura guardada en: {output_temp}")
        return output_temp
    return None

if __name__ == "__main__":
    logging.info("Inicio de ejecución de scripts/visualize_windows.py")
    if run_windows_app():
        img_path = take_screenshot()
        if img_path:
            logging.info(f"Visualización completada exitosamente: {img_path}")
            print(f"--- SUCCESS: {img_path} ---")
        else:
            logging.error("No se pudo guardar la captura.")
    else:
        print("Fallo al iniciar la aplicación en Windows.")
    
    # No matamos la app inmediatamente para que el usuario pueda verla si tiene acceso al escritorio,
    # o para que la captura sea válida. Pero aquí ya terminamos el script.
