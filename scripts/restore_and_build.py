import os
import re

lib_dir = "c:/Proyectos/lvs-flutter/lib"

def restore_and_fix(path):
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # 1. Limpieza de las rutas corrompidas del script anterior
    new_content = content.replace("package:velvet_sync/core/hal/protocol_adapter.dart/../../", "package:velvet_sync/")
    
    # 2. Corregir mapeos de paquetes de primer nivel que faltaban bajo services/ o devices/
    map_fixes = {
        "package:velvet_sync/ai/": "package:velvet_sync/services/ai/",
        "package:velvet_sync/ble/": "package:velvet_sync/services/ble/",
        "package:velvet_sync/backend/": "package:velvet_sync/services/backend/",
        "package:velvet_sync/models/": "package:velvet_sync/devices/models/",
        "package:velvet_sync/parsers/": "package:velvet_sync/devices/parsers/",
        "package:velvet_sync/catalog/": "package:velvet_sync/services/catalog/",
        "package:velvet_sync/services/services/": "package:velvet_sync/services/"
    }
    
    for old, new in map_fixes.items():
        new_content = new_content.replace(old, new)
        
    # 3. Colores remanentes
    new_content = new_content.replace("LvsColors.background", "LvsColors.bg")
    new_content = new_content.replace("LvsColors.green", "LvsColors.teal")
    
    # 4. FIX SINTAXIS: home_screen.dart
    if "home_screen.dart" in path:
        # Re-evaluar el cierre del Stack. Quitar el paréntesis extra
        # Se busca el bloque final del build que suele tener muchos cierres
        lines = new_content.splitlines()
        if len(lines) > 223 and ")," in lines[222]:
             # Eliminar la línea 223 si es un duplicado del cierre
             pass # Lo haremos vía regex mejor para ser precisos
        
        # Eliminar el child: sobrante si aún existe
        new_content = new_content.replace("child: CustomScrollView(", "CustomScrollView(")
        
    if new_content != content:
        print(f"Restaurando: {path}")
        with open(path, "w", encoding="utf-8") as f:
            f.write(new_content)

for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if file.endswith(".dart"):
            restore_and_fix(os.path.join(root, file))

# 5. Fix manual de syntax en home_screen via script directo (más robusto)
home_path = os.path.join(lib_dir, "screens", "home_screen.dart")
if os.path.exists(home_path):
    with open(home_path, "r", encoding="utf-8") as f:
        lines = f.readlines()
    
    # El error es en el cierre del Stack. Vamos a buscar la estructura children: [ ... ],
    # y asegurarnos de que no hay un wrap extra de child:
    final_lines = []
    for i, line in enumerate(lines):
        # Si detectamos el paréntesis extra en la zona muerta del Stack
        if i == 222 and line.strip() == "),":
             print("Eliminando paréntesis huérfano en home_screen.dart:223")
             continue 
        final_lines.append(line)
        
    with open(home_path, "w", encoding="utf-8") as f:
        f.writelines(final_lines)
