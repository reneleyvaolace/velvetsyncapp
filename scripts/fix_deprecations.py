import os
import re

def migrate_deprecations(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # .withOpacity(x) -> .withValues(alpha: x)
    # Match something like .withOpacity( 0.5 ) or .withOpacity(opacityVar)
    content = re.sub(r'\.withOpacity\(([^)]+)\)', r'.withValues(alpha: \1)', content)

    # activeColor: color -> activeThumbColor: color (for Switch/Slider usually)
    # We should only do this where it's deprecated. In analyze it's at lines 436 and 544 of home_screen.dart.
    if 'home_screen.dart' in file_path:
        content = content.replace('activeColor: ', 'activeThumbColor: ')

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

files_to_fix = [
    r'c:\Proyectos\lvs-flutter\lib\screens\home_screen.dart',
    r'c:\Proyectos\lvs-flutter\lib\screens\debug_screen.dart'
]

for fp in files_to_fix:
    if os.path.exists(fp):
        print(f"Migrating {fp}...")
        migrate_deprecations(fp)
    else:
        print(f"File not found: {fp}")
