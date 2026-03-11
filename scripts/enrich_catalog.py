import csv
import requests
import json
import time
import concurrent.futures

CSV_FILE = 'devices-categories-updated.csv'
ENRICHED_CSV = 'devices-categories-enriched.csv'
OUTPUT_SQL = 'insert_catalog_massive_enriched.sql'

def fetch_product_detail(barcode):
    url = f"https://lovespouse.zlmicro.com/index.php?g=App&m=Diyapp&a=getproductdetail&barcode={barcode}&userid=-1"
    try:
        r = requests.get(url, timeout=10)
        if r.status_code == 200:
            data = r.json()
            if data.get('response', {}).get('result'):
                return data['data']
    except Exception as e:
        pass
    return None

def enrich():
    print("🧪 Iniciando enriquecimiento del catálogo con datos reales de Zlmicro...")
    
    try:
        with open(CSV_FILE, 'r', encoding='utf-8') as f:
            reader = csv.reader(f)
            rows = list(reader)
            header = rows[0]
            data_rows = rows[1:]

        enriched_rows = [header]
        sql_statements = ["BEGIN;"]
        
        ids = [row[0] for row in data_rows]
        
        # Usar hilos para acelerar
        with concurrent.futures.ThreadPoolExecutor(max_workers=20) as executor:
            future_to_id = {executor.submit(fetch_product_detail, bid): bid for bid in ids}
            
            count = 0
            for future in concurrent.futures.as_completed(future_to_id):
                bid = future_to_id[future]
                detail = future.result()
                
                # Buscar la fila original
                orig_row = next(r for r in data_rows if r[0] == bid)
                
                if detail:
                    model_name = detail.get('DeviceTitle') or detail.get('Name') or f"LVS {bid}"
                    img_url = detail.get('Pics', '')
                    qr_url = detail.get('Qrcode', '')
                    prefix = detail.get('BroadcastPrefix', '77 62 4d 53 45')
                    is_precise = 'true' if detail.get('IsPrecise') == 1 else 'false'
                    
                    product_funcs = detail.get('ProductFuncs', [])
                    funcs_list = [f.get('Code') for f in product_funcs if f.get('Code')]
                    funcs_str = "|".join(funcs_list) if funcs_list else orig_row[12]

                    new_row = list(orig_row)
                    new_row[2] = model_name
                    new_row[9] = img_url
                    new_row[11] = qr_url
                    new_row[12] = funcs_str
                    new_row[16] = '0-255' if is_precise == 'true' else 'Estándar'
                    new_row[17] = prefix
                    
                    anatomy_raw = new_row[4].split('|') if new_row[4] else ["Universal"]
                    anatomy_json = json.dumps(anatomy_raw)
                    
                    clean_name = model_name.replace("'", "''")
                    
                    sql = (f"INSERT INTO device_catalog (id, model_name, usage_type, target_anatomy, stimulation_type, motor_logic, image_url, qr_code_url, supported_funcs, is_precise_new, broadcast_prefix) "
                           f"VALUES ('{bid}', '{clean_name}', '{new_row[3]}', '{anatomy_json}'::jsonb, '{new_row[5]}', '{new_row[6]}', '{img_url}', '{qr_url}', '{funcs_str}', {is_precise}, '{prefix}') "
                           f"ON CONFLICT (id) DO UPDATE SET model_name = EXCLUDED.model_name, image_url = EXCLUDED.image_url, qr_code_url = EXCLUDED.qr_code_url, supported_funcs = EXCLUDED.supported_funcs, is_precise_new = EXCLUDED.is_precise_new, broadcast_prefix = EXCLUDED.broadcast_prefix;")
                    
                    sql_statements.append(sql)
                    enriched_rows.append(new_row)
                    print(f"✅ Enriquecido ID {bid}: {model_name}")
                else:
                    enriched_rows.append(orig_row)
                    print(f"⚠️ Sin datos para ID {bid}")
                
                count += 1
                if count % 20 == 0:
                    print(f"Progreso: {count}/{len(ids)}")

        sql_statements.append("COMMIT;")

        with open(ENRICHED_CSV, 'w', newline='', encoding='utf-8') as f:
            csv.writer(f).writerows(enriched_rows)
            
        with open(OUTPUT_SQL, 'w', encoding='utf-8') as f:
            f.write("\n".join(sql_statements))
            
        print(f"\n🚀 ¡Enriquecimiento finalizado!")
        print(f"CSV enriquecido: {ENRICHED_CSV}")
        print(f"SQL para Supabase: {OUTPUT_SQL}")

    except Exception as e:
        print(f"Error general: {e}")

if __name__ == "__main__":
    enrich()
