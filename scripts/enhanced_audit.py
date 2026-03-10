import os
import re
import logging

# Configuración de logs para la auditoría
logging.basicConfig(
    filename='security_results.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

def log_finding(level, message):
    print(f"[{level}] {message}")
    logging.info(f"[{level}] {message}")

def enhanced_audit(root_dir):
    log_finding("AUDIT", "Iniciando Auditoría de Seguridad Proactiva - Velvet Sync")
    
    # 1. Buscar conexiones inseguras (HTTP en lugar de HTTPS)
    # Ya busqué http:// con grep, pero revisaré patrones de 'allowInsecureHttp'
    
    # 2. Buscar uso de persistencia no cifrada para datos sensibles
    sensitive_storage_patterns = [
        (r'SharedPreferences', "Uso de SharedPreferences detectado. Considerar flutter_secure_storage para datos sensibles."),
        (r'getStorage', "Uso de GetStorage detectado. Verificar cifrado."),
    ]
    
    # 3. Buscar fugas de información en logs (debugPrint sin kDebugMode)
    # Buscaremos debugPrint que NO estén precedidos por una condición de debug
    
    # 4. Buscar Hardcoded IP addresses
    ip_pattern = r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}'
    
    # 5. Análisis de AndroidManifest para exportación de componentes
    manifest_path = os.path.join(root_dir, 'android', 'app', 'src', 'main', 'AndroidManifest.xml')
    
    lib_path = os.path.join(root_dir, 'lib')
    
    for root, _, files in os.walk(lib_path):
        for file in files:
            if file.endswith('.dart'):
                path = os.path.join(root, file)
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    
                    # Chequeo 2: Persistencia
                    for pattern, msg in sensitive_storage_patterns:
                        if re.search(pattern, content):
                            log_finding("WARNING", f"{file}: {msg}")
                    
                    # Chequeo 3: Logging
                    # Buscamos debugPrint y chequeamos si hay kDebugMode cerca (heurística simple)
                    if 'debugPrint' in content and 'kDebugMode' not in content:
                        log_finding("INFO", f"{file}: Contiene debugPrint sin validación global de kDebugMode.")
                        
                    # Chequeo 4: IPs
                    ips = re.findall(ip_pattern, content)
                    for ip in ips:
                        if not ip.startswith('127.') and not ip.startswith('0.'):
                            log_finding("CRITICAL", f"{file}: IP Hardcoded detectada: {ip}")

    # Chequeo 5: Manifest
    if os.path.exists(manifest_path):
        with open(manifest_path, 'r', encoding='utf-8') as f:
            manifest = f.read()
            if 'android:exported="true"' in manifest:
                log_finding("VULNERABILITY", "AndroidManifest.xml: Existen componentes exportados. Verificar permisos de acceso.")
            if 'android:allowBackup="true"' in manifest:
                log_finding("HIGH", "AndroidManifest.xml: allowBackup activo. Los datos de la app podrían ser extraídos vía ADB backup.")

if __name__ == "__main__":
    enhanced_audit(os.getcwd())
