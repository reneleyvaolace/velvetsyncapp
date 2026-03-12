import re
import os
import json

# --- CONFIGURACIÓN DE LA MATRIZ COREAURA ---
def determinar_tecnico(model_name):
    m = model_name.upper()
    # Lógica de familias basada en los batches
    if m.endswith(("TD", "BTD")):
        return {"usage": "hybrid", "stim": "thrusting, vibration", "motor": "dual", "anatomy": '{"clitoral":true,"vaginal":true}', "cmd": "aa020a0005"}
    elif m.endswith("HT"):
        return {"usage": "external", "stim": "suction, heating", "motor": "single", "anatomy": '{"clitoral":true}', "cmd": "aa020a0000"}
    elif m.endswith("ZD"):
        return {"usage": "external", "stim": "vibration", "motor": "single", "anatomy": '{"clitoral":true}', "cmd": "77010a"}
    elif m.endswith("SJ"):
        return {"usage": "external", "stim": "suction", "motor": "single", "anatomy": '{"clitoral":true}', "cmd": "aa020a0000"}
    elif m.endswith(("YJ", "FJ")):
        return {"usage": "internal", "stim": "vibration", "motor": "single", "anatomy": '{"vaginal":true}', "cmd": "77010a"}
    else:
        return {"usage": "external", "stim": "vibration", "motor": "single", "anatomy": '{"clitoral":true}', "cmd": "77010a"}

# --- PROCESO DE CATALOGACIÓN ---
files = ['batch_full_1000.txt', 'batch_full_2500.txt', 'batch_full_3000.txt', 'batch_full_3500.txt', 'batch_full_4000.txt', 'batch_full_4500.txt']
sql_output = "-- CoreAura Master Catalog Enrichement\n\n"

for file_name in files:
    if os.path.exists(file_name):
        with open(file_name, 'r', encoding='utf-8') as f:
            content = f.read()
            # Extraer (ID, MODELO) de los INSERTs actuales
            matches = re.findall(r"VALUES\s*\(\s*'([^']+)'\s*,\s*'([^']+)'", content)
            for barcode, model in matches:
                tech = determinar_tecnico(model)
                query = (
                    f"UPDATE device_catalog SET "
                    f"usage_type = '{tech['usage']}', "
                    f"stimulation_type = '{tech['stim']}', "
                    f"motor_logic = '{tech['motor']}', "
                    f"target_anatomy = '{tech['anatomy']}', "
                    f"vibration_cmd_hex = '{tech['cmd']}', "
                    f"certified_by_coreaura = true "
                    f"WHERE barcode = '{barcode}';\n"
                )
                sql_output += query

# Guardar el resultado
with open("update_prefijos_final.sql", "w", encoding="utf-8") as f:
    f.write(sql_output)

print(">>> Catalogación completada. Se generó 'update_prefijos_final.sql' para Supabase.")