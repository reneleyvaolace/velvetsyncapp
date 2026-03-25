import os
import re

lib_dir = "c:/Proyectos/lvs-flutter/lib"

def fix_errors(path):
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # 1. Corregir rutas de paquetes según la estructura real de lib/
    replacements = {
        "package:velvet_sync/ai/": "package:velvet_sync/services/ai/",
        "package:velvet_sync/models/": "package:velvet_sync/devices/models/",
        "package:velvet_sync/parsers/": "package:velvet_sync/devices/parsers/",
        "package:velvet_sync/utils/": "package:velvet_sync/core/hal/protocol_adapter.dart/../../utils/", # Fallback if utils moved
        "package:velvet_sync/services/services/": "package:velvet_sync/services/"
    }
    
    new_content = content
    for old, new in replacements.items():
        new_content = new_content.replace(old, new)
        
    # 2. Corregir colores (tema actual en lib/theme.dart)
    new_content = new_content.replace("LvsColors.background", "LvsColors.bg")
    new_content = new_content.replace("LvsColors.green", "LvsColors.teal")
    
    # 3. FIX ESPECÍFICO: home_screen.dart
    if "home_screen.dart" in path:
        # Arreglar el child: CustomScrollView que rompe el Stack
        # De:
        #  ),
        # ),
        # child: CustomScrollView(
        # A:
        #  ),
        # ),
        # CustomScrollView(
        new_content = new_content.replace("child: CustomScrollView(", "CustomScrollView(")
        
    if new_content != content:
        print(f"Cirugía aplicada: {path}")
        with open(path, "w", encoding="utf-8") as f:
            f.write(new_content)

for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if file.endswith(".dart"):
            fix_errors(os.path.join(root, file))
