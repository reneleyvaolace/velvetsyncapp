import os
import re

# Versión: 1.0.0
# Descripción: Arregla los problemas de análisis restantes en el proyecto Velvet Sync.

PROJECT_PATH = r"c:\Proyectos\lvs-flutter"
LIB_PATH = os.path.join(PROJECT_PATH, "lib")

def fix_avoid_print():
    """Reemplaza print() por lvsLog() o ignore: avoid_print"""
    print("Fixing avoid_print issues...")
    for root, dirs, files in os.walk(PROJECT_PATH):
        for file in files:
            if file.endswith(".dart") and "build" not in root:
                file_path = os.path.join(root, file)
                with open(file_path, "r", encoding="utf-8") as f:
                    content = f.read()
                
                # Para archivos de test, ignorar. Para otros, reemplazar o comentar.
                if "test" in root or file.startswith("test_"):
                    new_content = re.sub(r'(\s+)print\(', r'\1// ignore: avoid_print\n\1print(', content)
                else:
                    new_content = content.replace("print(", "lvsLog(")
                
                if new_content != content:
                    with open(file_path, "w", encoding="utf-8") as f:
                        f.write(new_content)
                    print(f"  Fixed: {file_path}")

def fix_deprecated_opacity():
    """Reemplaza withOpacity con withValues"""
    print("Fixing deprecated withOpacity...")
    for root, dirs, files in os.walk(LIB_PATH):
        for file in files:
            if file.endswith(".dart"):
                file_path = os.path.join(root, file)
                with open(file_path, "r", encoding="utf-8") as f:
                    content = f.read()
                
                # withOpacity(0.5) -> withValues(alpha: 0.5)
                new_content = re.sub(r'\.withOpacity\((.*?)\)', r'.withValues(alpha: \1)', content)
                
                if new_content != content:
                    with open(file_path, "w", encoding="utf-8") as f:
                        f.write(new_content)
                    print(f"  Fixed: {file_path}")

if __name__ == "__main__":
    fix_avoid_print()
    fix_deprecated_opacity()
    print("Análisis y corrección completada.")
