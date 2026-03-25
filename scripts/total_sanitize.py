import os
import re

lib_dir = "c:/Proyectos/lvs-flutter/lib"

# 1. Definiciones de mapeo
package_name = "velvet_sync"
old_package = "lvs_control"

# Rutas que han cambiado de ubicación
moved_modules = {
    "ble": "services/ble",
    "services/catalog_service.dart": "services/catalog/catalog_service.dart"
}

def fix_file(path):
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()
    
    new_lines = []
    modified = False
    
    for line in lines:
        new_line = line
        
        # A. Reemplazar nombre de paquete viejo por nuevo
        if old_package in new_line:
            new_line = new_line.replace(f"package:{old_package}/", f"package:{package_name}/")
            modified = True
            
        # B. Convertir imports relativos a package imports para evitar errores de profundidad
        # Ejemplo: import '../ble/ble_service.dart' -> import 'package:velvet_sync/services/ble/ble_service.dart'
        rel_match = re.search(r"import ['\"](\.\.?/)+([^'\"]+)['\"]", new_line)
        if rel_match:
            rel_path = rel_match.group(2)
            # Detectar si es un módulo que movimos
            for old, new in moved_modules.items():
                if rel_path.startswith(old):
                    rel_path = rel_path.replace(old, new)
            
            # Rebuilding as package import (si no es un dart: o package:)
            # Esto es más agresivo pero resuelve el problema de raíz
            # Solo si no es ya un package:
            if "package:" not in new_line:
                # Determinar la ruta real basada en la posición del archivo actual
                # Pero usaremos una lógica más simple: si el archivo existe bajo lib/path, lo usamos.
                # Para simplificar, asumimos que todos los archivos referenciados están bajo lib/
                new_line = f"import 'package:velvet_sync/{rel_path}';\n"
                modified = True

        # C. Específicamente para la estructura de servicios BLE que se movió a lib/services/ble
        if f"package:{package_name}/ble/" in new_line:
            new_line = new_line.replace(f"package:{package_name}/ble/", f"package:{package_name}/services/ble/")
            modified = True
            
        new_lines.append(new_line)
    
    if modified:
        print(f"Saneando: {path}")
        with open(path, "w", encoding="utf-8") as f:
            f.writelines(new_lines)

for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if file.endswith(".dart"):
            fix_file(os.path.join(root, file))

# 2. Cleanup específico para home_screen.dart (comentar archivos perdidos)
home_path = os.path.join(lib_dir, "screens", "home_screen.dart")
if os.path.exists(home_path):
    with open(home_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    missing_files = [
        "preregister_widget.dart",
        "companion_screen.dart",
        "roulette_screen.dart",
        "reader_screen.dart",
        "catalog_screen.dart",
        "remote_session_screen.dart"
    ]
    
    new_content = content
    for m_file in missing_files:
        # Comentar la línea de import
        new_content = re.sub(f"import '.*{m_file}';", f"// import '{m_file}'; // FALTANTE EN DISCO", new_content)
        # Comentar la instanciación de la clase (aproximación simple)
        class_name = "".join([x.capitalize() for x in m_file.replace(".dart", "").split("_")])
        new_content = new_content.replace(f"const {class_name}()", f"/* const {class_name}() FALTANTE */ Container()")
        new_content = new_content.replace(f"MaterialPageRoute(builder: (_) => const {class_name}())", 
                                        f"MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text('{class_name} No Encontrada'))))")
    
    if new_content != content:
        print("Limpiando referencias a archivos faltantes en home_screen.dart")
        with open(home_path, "w", encoding="utf-8") as f:
            f.write(new_content)
