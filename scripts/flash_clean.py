import os

lib_dir = "c:/Proyectos/lvs-flutter/lib"

def fix_file(path):
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # 1. Corregir dobles prefijos de services/
    new_content = content.replace("services/services/", "services/")
    
    # 2. Corregir rutas de backend faltantes (debe ser services/backend)
    new_content = new_content.replace("package:velvet_sync/backend/", "package:velvet_sync/services/backend/")
    
    # 3. Corregir cualquier rastro de lvs_control remanente
    new_content = new_content.replace("package:lvs_control/", "package:velvet_sync/")

    if new_content != content:
        print(f"Limpiando rutas definitivas: {path}")
        with open(path, "w", encoding="utf-8") as f:
            f.write(new_content)

for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if file.endswith(".dart"):
            fix_file(os.path.join(root, file))
