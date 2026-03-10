import os
import re
import logging

# Configuración de logs
logging.basicConfig(
    filename='activity.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

def log_action(message):
    print(message)
    logging.info(message)

def audit_configs(root_dir):
    log_action("--- Auditing configuration files ---")
    
    # 1. Check .gitignore for .env
    gitignore_path = os.path.join(root_dir, '.gitignore')
    if os.path.exists(gitignore_path):
        with open(gitignore_path, 'r') as f:
            content = f.read()
            if '.env' not in content:
                log_action("[VULNERABILITY] .env is not in .gitignore")
            else:
                log_action("[OK] .env is in .gitignore")
    else:
        log_action("[WARNING] .gitignore not found")

    # 2. Check pubspec.yaml for .env in assets
    pubspec_path = os.path.join(root_dir, 'pubspec.yaml')
    if os.path.exists(pubspec_path):
        with open(pubspec_path, 'r') as f:
            content = f.read()
            if re.search(r'assets:.*?- .env', content, re.DOTALL):
                log_action("[CRITICAL] .env is being bundled as an asset in pubspec.yaml")
            else:
                log_action("[OK] .env is not listed in pubspec.yaml assets")

def audit_code(lib_dir):
    log_action("--- Auditing source code (lib/) ---")
    
    sensitive_keywords = ['print', 'debugPrint', 'shared_preferences', 'password', 'token', 'secret']
    results = {k: [] for k in sensitive_keywords}

    for root, _, files in os.walk(lib_dir):
        for file in files:
            if file.endswith('.dart'):
                file_path = os.path.join(root, file)
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        lines = f.readlines()
                        for i, line in enumerate(lines):
                            for key in sensitive_keywords:
                                if key in line:
                                    results[key].append(f"{file}:{i+1}")
                except Exception as e:
                    log_action(f"Error reading {file_path}: {e}")

    # Summary of findings
    for key, findings in results.items():
        if findings:
            log_action(f"[INFO] Found {len(findings)} occurrences of '{key}'.")
            # Log first 5 as examples
            for f in findings[:5]:
                logging.info(f"Occurrence of {key} in {f}")

if __name__ == "__main__":
    root_path = os.getcwd()
    lib_path = os.path.join(root_path, 'lib')
    
    audit_configs(root_path)
    if os.path.exists(lib_path):
        audit_code(lib_path)
    else:
        log_action("[ERROR] lib/ directory not found")
