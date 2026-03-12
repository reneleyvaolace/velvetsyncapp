
import os
import shutil

# Rutas
source_dir = r"C:\Users\Sistemas CDMX\.gemini\antigravity\brain\eac52166-6856-4bce-8b04-c2bb1839b669"
dest_dir = r"c:\Proyectos\lvs-flutter\icons"

if not os.path.exists(dest_dir):
    os.makedirs(dest_dir)

# Mapa de archivos generados (prefijo -> nombre final)
mapping = {
    "icon_anal": "icon_anal.png",
    "icon_prostate": "icon_prostate.png",
    "icon_suction": "icon_suction.png",
    "icon_clitoral": "icon_clitoral.png",
    "icon_ring": "icon_ring.png",
    "icon_thrust": "icon_thrust.png",
    "temperature_max": "temperature_max.png",
    "temperature_min": "temperature_min.png",
    "icon_heart": "icon_heart.png",
    "icon_battery": "icon_battery.png",
    "icon_bluetooth": "icon_bluetooth.png",
    "icon_heat": "icon_heat.png"
}

print(f"Buscando archivos en: {source_dir}")
found_files = os.listdir(source_dir)

for prefix, final_name in mapping.items():
    # Buscar el archivo que empiece con el prefijo y sea .png
    matches = [f for f in found_files if f.startswith(prefix) and f.endswith(".png")]
    if matches:
        # Ordenar por fecha (el más reciente) por si acaso hay duplicados
        matches.sort(key=lambda x: os.path.getmtime(os.path.join(source_dir, x)), reverse=True)
        source_path = os.path.join(source_dir, matches[0])
        dest_path = os.path.join(dest_dir, final_name)
        
        shutil.copy2(source_path, dest_path)
        print(f"Copiado: {matches[0]} -> {final_name}")
    else:
        print(f"No se encontró archivo para: {prefix}")

print("Proceso de organización completado.")
