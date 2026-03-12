import csv
import json

CSV_FILE = 'devices-categories-updated.csv'
OUTPUT_SQL = 'insert_catalog_massive_v2.sql'

def escape(val):
    if val is None: return "NULL"
    return str(val).replace("'", "''")

def generate_sql():
    try:
        with open(CSV_FILE, 'r', encoding='utf-8') as f:
            reader = csv.reader(f)
            header = next(reader)
            
            rows_data = []
            for row in reader:
                if not row or len(row) < 3: continue
                
                id_val = escape(row[0])
                name = escape(row[2])
                model_name = escape(row[2]) # Often same as name
                usage = escape(row[3])
                anatomy_raw = row[4].split('|') if row[4] else []
                anatomy_json = json.dumps(anatomy_raw)
                stim = escape(row[5])
                motor = escape(row[6])
                icon = escape(row[8]) if len(row) > 8 and row[8] else "vibrator"
                img = escape(row[9]) if len(row) > 9 and row[9] else ""
                qr = escape(row[11]) if len(row) > 11 and row[11] else ""
                funcs = escape(row[12]) if len(row) > 12 and row[12] else "speed,vibration"
                desc = escape(row[14]) if len(row) > 14 and row[14] else ""
                
                # Precision logic
                is_precise_val = 'false'
                if len(row) > 16:
                    p_val = str(row[16]).lower()
                    if p_val in ['0-255', 'preciso', 'true', '1']:
                        is_precise_val = 'true'
                
                prefix = escape(row[17]) if len(row) > 17 and row[17] else "77 62 4d 53 45"
                
                rows_data.append(f"('{id_val}', '{name}', '{model_name}', '{usage}', '{anatomy_json}'::jsonb, '{stim}', '{motor}', '{icon}', '{img}', '{qr}', '{funcs}', '{desc}', {is_precise_val}, {is_precise_val}, '{prefix}')")

            # Batch in 100s
            batch_size = 100
            final_sql = ["BEGIN;"]
            for i in range(0, len(rows_data), batch_size):
                batch = rows_data[i:i+batch_size]
                values_str = ",\n".join(batch)
                sql = f"""INSERT INTO device_catalog (
    id, name, model_name, usage_type, target_anatomy, 
    stimulation_type, motor_logic, icon_type, image_url, 
    qr_code_url, supported_funcs, description, is_precise, is_precise_new, broadcast_prefix
) 
VALUES {values_str}
ON CONFLICT (id) DO UPDATE SET 
    name = EXCLUDED.name,
    model_name = EXCLUDED.model_name, 
    usage_type = EXCLUDED.usage_type, 
    target_anatomy = EXCLUDED.target_anatomy, 
    stimulation_type = EXCLUDED.stimulation_type, 
    motor_logic = EXCLUDED.motor_logic, 
    icon_type = EXCLUDED.icon_type,
    image_url = EXCLUDED.image_url, 
    qr_code_url = EXCLUDED.qr_code_url, 
    supported_funcs = EXCLUDED.supported_funcs, 
    description = EXCLUDED.description,
    is_precise = EXCLUDED.is_precise,
    is_precise_new = EXCLUDED.is_precise_new, 
    broadcast_prefix = EXCLUDED.broadcast_prefix;"""
                final_sql.append(sql)
            
            final_sql.append("COMMIT;")
            
            with open(OUTPUT_SQL, 'w', encoding='utf-8') as out:
                out.write("\n".join(final_sql))
            
            print(f"✅ Generada SQL v3 corregida en {OUTPUT_SQL} con {len(rows_data)} registros.")
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    generate_sql()
