import os
import logging

# Versión: 1.0.0
# Descripción: Script para corregir la recursión en logger.dart y registrar la acción.

logging.basicConfig(
    filename='activity.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

def fix_logger():
    file_path = 'lib/utils/logger.dart'
    if not os.path.exists(file_path):
        logging.error(f"No se encontró {file_path}")
        return False
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        fixed_lines = []
        modified = False
        for line in lines:
            if 'lvsLog(entry.toString());' in line:
                fixed_lines.append(line.replace('lvsLog(entry.toString());', 'debugPrint(entry.toString());'))
                modified = True
            else:
                fixed_lines.append(line)
        
        if modified:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.writelines(fixed_lines)
            logging.info("Recursión corregida en lib/utils/logger.dart: lvsLog -> debugPrint")
            print("Corrección aplicada exitosamente.")
            return True
        else:
            logging.info("No se encontró la cadena de recursión en lib/utils/logger.dart (posiblemente ya corregido)")
            print("No se requirieron cambios.")
            return True
            
    except Exception as e:
        logging.error(f"Error al corregir logger.dart: {str(e)}")
        print(f"Error: {e}")
        return False

if __name__ == "__main__":
    logging.info("Iniciando script de corrección de logger...")
    fix_logger()
    logging.info("Script de corrección finalizado.")
