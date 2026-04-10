import os
import subprocess
import logging

# Versión: 1.0.0
# Descripción: Script de verificación total según Directiva 19

logging.basicConfig(
    filename='activity.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

def run_cmd(cmd, capture_output=True, output_file=None):
    logging.info(f"Ejecutando: {cmd}")
    try:
        result = subprocess.run(cmd, shell=True, capture_output=capture_output, text=True)
        out = result.stdout if result.stdout else ""
        err = result.stderr if result.stderr else ""
        if output_file and capture_output:
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(out + "\n" + err)
        if result.returncode == 0:
            logging.info(f"Comando exitoso: {cmd}")
            return True, out
        else:
            logging.warning(f"Comando falló: {cmd}")
            return False, out + "\n" + err
    except Exception as e:
        logging.error(f"Error al ejecutar {cmd}: {str(e)}")
        return False, str(e)

def main():
    logging.info("--- INICIO DE VERIFICACION TOTAL ---")
    
    # 1. Pub get
    pub_ok, pub_out = run_cmd("flutter pub get")
    
    # 2. Analyze
    os.makedirs(".tmp", exist_ok=True)
    ana_ok, ana_out = run_cmd("flutter analyze", output_file=".tmp/build_errors_full.txt")
    
    # 3. Security Audit
    sec_ok, sec_out = run_cmd("python scripts/enhanced_audit.py")
    
    # 4. Check pubspec
    pubspec_ok = False
    with open("pubspec.yaml", "r", encoding='utf-8') as f:
        if "name: velvet_sync" in f.read():
            pubspec_ok = True
            
    # 5. Build Apk (dry run) - Requiere usar un flavor explícito (dev/prod)
    build_ok, build_out = run_cmd("flutter build apk --flavor dev --debug")
    
    # Generar reporte
    report_path = "documentacion/tecnica/reporte_verificacion_total.md"
    os.makedirs(os.path.dirname(report_path), exist_ok=True)
    with open(report_path, "w", encoding='utf-8') as f:
        f.write("# Reporte de Verificación Total (Velvet Sync)\n\n")
        f.write("## 1. Dependencias (`flutter pub get`)\n")
        f.write(f"- Estado: {'Exitoso' if pub_ok else 'Fallido'}\n\n")
        
        f.write("## 2. Análisis Estático (`flutter analyze`)\n")
        f.write(f"- Estado: {'Exitoso' if ana_ok else 'Revisar issues'}\n")
        f.write("- Salida capturada en `.tmp/build_errors_full.txt`\n\n")
        
        f.write("## 3. Seguridad (`enhanced_audit.py`)\n")
        f.write(f"- Ejecutado correctamente: {'Sí' if sec_ok else 'No'}\n")
        f.write("- Revisar `security_results.log` para hallazgos.\n\n")
        
        f.write("## 4. Validación Estructura\n")
        f.write(f"- Nombre del paquete es `velvet_sync`: {'Sí' if pubspec_ok else 'No'}\n\n")
        
        f.write("## 5. Prueba de Compilación Android (`flutter build apk --debug`)\n")
        f.write(f"- Estado: {'Exitoso' if build_ok else 'Fallido'}\n")
        if not build_ok:
            f.write("```text\n")
            # truncate output to prevent giant file
            f.write(build_out[-1500:] if len(build_out) > 1500 else build_out)
            f.write("\n```\n")
    
    logging.info(f"Reporte generado en {report_path}")
    logging.info("--- FIN DE VERIFICACION TOTAL ---")
    print(f"Verificación completa. Revisar {report_path}")

if __name__ == "__main__":
    main()
