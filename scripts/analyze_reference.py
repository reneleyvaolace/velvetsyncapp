
import os
import json

path = r'c:\Proyectos\lvs-flutter\imagenes-referencia'
output_log = r'c:\Proyectos\lvs-flutter\scripts\reference_analysis.json'

def analyze_reference():
    files = os.listdir(path)
    analysis = {
        'total_files': len(files),
        'by_extension': {},
        'nine_patch_count': 0,
        'standard_png_count': 0,
        'potential_ui_icons': [], # Archivos pequeños < 5kb que suelen ser iconos
        'potential_full_images': [], # Archivos > 50kb
        'named_files': [] # Archivos que no tienen nombres aleatorios/codificados
    }
    
    for f in files:
        ext = os.path.splitext(f)[1]
        analysis['by_extension'][ext] = analysis['by_extension'].get(ext, 0) + 1
        
        full_path = os.path.join(path, f)
        size = os.path.getsize(full_path)
        
        if '.9.png' in f:
            analysis['nine_patch_count'] += 1
        elif ext == '.png':
            analysis['standard_png_count'] += 1
            
        # Clasificación por tamaño
        if size < 5120: # 5KB
            if len(f) > 8: # Nombres largos suelen ser descriptivos
                 analysis['potential_ui_icons'].append({'name': f, 'size': size})
        elif size > 51200: # 50KB
            analysis['potential_full_images'].append({'name': f, 'size': size})
            
        if not any(c.isdigit() for c in f[:3]) and len(f) > 5:
            analysis['named_files'].append(f)

    with open(output_log, 'w', encoding='utf-8') as j:
        json.dump(analysis, j, indent=2)

if __name__ == '__main__':
    analyze_reference()
