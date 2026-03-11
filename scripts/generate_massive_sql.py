import csv
import json

CSV_FILE = 'devices-categories-updated.csv'
OUTPUT_SQL = 'insert_catalog_massive.sql'

def escape(val):
    if val is None: return "NULL"
    return str(val).replace("'", "''")

def generate_sql():
    try:
        with open(CSV_FILE, 'r', encoding='utf-8') as f:
            reader = csv.reader(f)
            header = next(reader)
            
            statements = []
            statements.append("-- Script de carga masiva de catálogo LVS (Corrección de nombres de columnas)")
            statements.append("BEGIN;")
            
            count = 0
            for row in reader:
                # Mapeo según el CSV y el esquema real descubierto:
                # [0]id -> id
                # [2]name -> model_name (¡AQUÍ ESTABA EL ERROR!)
                # [3]usage -> usage_type
                # [4]anatomy -> target_anatomy (requiere cast a jsonb si es texto)
                # [5]stim -> stimulation_type
                # [6]motor -> motor_logic
                # [9]pics -> image_url
                # [11]qr -> qr_code_url
                # [12]funcs -> supported_funcs
                # [16]precise -> is_precise_new
                # [17]prefix -> broadcast_prefix
                
                id_val = escape(row[0])
                model_name = escape(row[2])
                usage = escape(row[3])
                # Convertir anatomía a un array JSON válido para jsonb
                anatomy_raw = row[4].split('|') if row[4] else []
                anatomy_json = json.dumps(anatomy_raw)
                
                stim = escape(row[5])
                motor = escape(row[6])
                img = escape(row[9])
                qr = escape(row[11])
                funcs = escape(row[12])
                precise = 'true' if row[16] in ['0-255', 'Preciso'] else 'false'
                prefix = escape(row[17]) if len(row) > 17 else "77 62 4d 53 45"
                
                sql = f"INSERT INTO device_catalog (id, model_name, usage_type, target_anatomy, stimulation_type, motor_logic, image_url, qr_code_url, supported_funcs, is_precise_new, broadcast_prefix) " \
                      f"VALUES ('{id_val}', '{model_name}', '{usage}', '{anatomy_json}'::jsonb, '{stim}', '{motor}', '{img}', '{qr}', '{funcs}', {precise}, '{prefix}') " \
                      f"ON CONFLICT (id) DO UPDATE SET model_name = EXCLUDED.model_name, usage_type = EXCLUDED.usage_type, target_anatomy = EXCLUDED.target_anatomy, stimulation_type = EXCLUDED.stimulation_type, motor_logic = EXCLUDED.motor_logic, image_url = EXCLUDED.image_url, qr_code_url = EXCLUDED.qr_code_url, supported_funcs = EXCLUDED.supported_funcs, is_precise_new = EXCLUDED.is_precise_new, broadcast_prefix = EXCLUDED.broadcast_prefix;"
                
                statements.append(sql)
                count += 1
            
            statements.append("COMMIT;")
            
            with open(OUTPUT_SQL, 'w', encoding='utf-8') as out:
                out.write("\n".join(statements))
            
            print(f"✅ Generadas {count} sentencias SQL corregidas en {OUTPUT_SQL}")
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    generate_sql()
