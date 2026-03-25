import os
import re

lib_dir = "c:/Proyectos/lvs-flutter/lib"

replacements = {
    r"import '\.\./ble/": "import '../services/ble/",
    r"import '\.\./\.\./ble/": "import '../../services/ble/",
    r"import 'ble/": "import 'services/ble/"
}

for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if file.endswith(".dart"):
            path = os.path.join(root, file)
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
            
            new_content = content
            for pattern, replacement in replacements.items():
                new_content = re.sub(pattern, replacement, new_content)
            
            if new_content != content:
                print(f"Updating {path}")
                with open(path, "w", encoding="utf-8") as f:
                    f.write(new_content)
