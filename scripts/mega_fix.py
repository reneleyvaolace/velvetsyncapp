import os
import re

lib_dir = "c:/Proyectos/lvs-flutter/lib"

replacements = {
    # 1. Rebranding de paquete
    r"import 'package:lvs_control/": "import 'package:velvet_sync/",
    
    # 2. Corrección de rutas BLE (Package)
    r"package:velvet_sync/ble/": "package:velvet_sync/services/ble/",
    
    # 3. Corrección de rutas relativas duplicadas (causadas por el fix anterior)
    r"import '../services/ble/": "import '../ble/",
    r"import '../../services/ble/": "import '../../ble/",
    
    # 4. Asegurar que 'services/ble' sea la ruta base para imports desde la raíz de lib
    r"import 'ble/": "import 'services/ble/"
}

def fix_file(path):
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    
    new_content = content
    for pattern, replacement in replacements.items():
        new_content = re.sub(pattern, replacement, new_content)
    
    if new_content != content:
        print(f"Reparando: {path}")
        with open(path, "w", encoding="utf-8") as f:
            f.write(new_content)

for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if file.endswith(".dart"):
            fix_file(os.path.join(root, file))
