import os
import re
import json
from fpdf import FPDF
from PIL import Image

# --- CONFIGURACIÓN DE RUTAS ---
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PATH_SQL = os.path.join(BASE_DIR, "sql_batches_completos")
PATH_JSON = os.path.join(BASE_DIR, "json_cache") # Ajusta esta ruta a tu carpeta de JSONs
PATH_ENGINE = os.path.join(BASE_DIR, "engine")
PATH_OUTPUT_TEST = os.path.join(BASE_DIR, "test_50_output")
PATH_TEMP = os.path.join(BASE_DIR, "temp")

if not os.path.exists(PATH_OUTPUT_TEST): os.makedirs(PATH_OUTPUT_TEST)
if not os.path.exists(PATH_TEMP): os.makedirs(PATH_TEMP)

# --- MAPEO DE TRADUCCIÓN DE FUNCIONES ---
TRADUCCIONES = {
    "classic": "Modo Clásico",
    "music": "Ritmo de Música",
    "shake": "Agitar y Vibrar",
    "intera": "Interacción LVS",
    "finger": "Control Táctil",
    "video": "Modo Video",
    "game": "Modo Juego",
    "explore": "Modo Exploración",
    "dual": "Doble Motor Independiente"
}

# --- LÓGICA DE DETECCIÓN DE CATEGORÍA ---
def obtener_info_real(barcode):
    ruta_json = os.path.join(PATH_JSON, f"{barcode}.json")
    info = {
        'category': 'vibrator',
        'gender': 'universal',
        'funcs': ["Control App", "Privacidad LVS"],
        'factory': 'N/A'
    }
    
    if os.path.exists(ruta_json):
        try:
            with open(ruta_json, 'r', encoding='utf-8') as f:
                raw = json.load(f)
                data = raw.get('data', {})
                
                # Detectar Categoría por ClassicId o Name
                classic_name = data.get('ClassicId', [{}])[0].get('Name', '')
                if "双马达" in classic_name: info['category'] = 'dual motor'
                elif "跳蛋" in classic_name: info['category'] = 'egg'
                elif "棒" in classic_name: info['category'] = 'vibrator'
                
                # Extraer Funciones
                product_funcs = data.get('ProductFuncs', [])
                if product_funcs:
                    info['funcs'] = [TRADUCCIONES.get(f.get('Code'), f.get('Name')) for f in product_funcs[:4]]
                
                info['factory'] = data.get('DeviceTitle', 'VS-MODEL')
        except: pass
    return info

# (Aquí va tu clase VelvetPDFMaster que ya tenemos configurada)
# Asegúrate de incluir la lógica de las franjas neón y el logo que validamos.

def procesar_prueba_50():
    print(f">>> Iniciando prueba de refinamiento (50 elementos)...")
    contador = 0
    limite = 50

    for archivo in os.listdir(PATH_SQL):
        if contador >= limite: break
        
        with open(os.path.join(PATH_SQL, archivo), 'r', encoding='utf-8') as f:
            for linea in f:
                if contador >= limite: break
                
                # Extraer barcode y nombre del SQL
                match = re.search(r"VALUES \('(\d+)', '(.*?)', '(.*?)'\)", linea)
                if match:
                    barcode = match.group(1)
                    nombre = match.group(2)
                    
                    # ENRIQUECER con JSON
                    info_extra = obtener_info_real(barcode)
                    
                    # Generar PDF (Llamando a tu clase VelvetPDFMaster)
                    # ... [Lógica de generación de PDF aquí] ...
                    
                    print(f"[{contador+1}/50] Generada: {barcode} - {info_extra['category']}")
                    contador += 1

if __name__ == "__main__":
    procesar_prueba_50()