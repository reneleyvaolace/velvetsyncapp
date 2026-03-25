import os

lib_dir = "c:/Proyectos/lvs-flutter/lib"

def finalize_imports(path):
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # 1. Eliminar duplicidades de services/ble/services
    new_content = content.replace("services/ble/services/", "services/ble/")
    
    # 2. Corregir cualquier instancia de package:velvet_sync/services/services/
    new_content = new_content.replace("services/services/", "services/")
    
    # 3. Asegurar que lvs_commands y ble_service estén en services/ble/
    # (Caso de que falte el prefijo services/)
    new_content = new_content.replace("package:velvet_sync/ble/lvs_commands.dart", "package:velvet_sync/services/ble/lvs_commands.dart")
    new_content = new_content.replace("package:velvet_sync/ble/ble_service.dart", "package:velvet_sync/services/ble/ble_service.dart")

    if new_content != content:
        print(f"Finalizando: {path}")
        with open(path, "w", encoding="utf-8") as f:
            f.write(new_content)

for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if file.endswith(".dart"):
            finalize_imports(os.path.join(root, file))
