import requests
import csv
import json
import concurrent.futures
import sys

# Supabase config
SUPABASE_URL = "https://wsgytnzigqlviqoktmdo.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndzZ3l0bnppZ3Fsdmlxb2t0bWRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQzMDk4NjQsImV4cCI6MjA3OTg4NTg2NH0.9Bp-bxWIEnsBEtXb1FaaNoxqRozTPnoYRInE8si8DjA"
CSV_URL = "https://raw.githubusercontent.com/reneleyvaolace/velvetsynccatalog/main/devices-categories.csv"

def get_existing_ids(csv_rows):
    if not csv_rows: return set()
    return {row[0] for row in csv_rows[1:]}

def probe_id(id_val):
    url = f"https://image.zlmicro.com/images/product/qrcode/{id_val}.png"
    try:
        # Petición más ligera solo para verificar existencia
        r = requests.head(url, timeout=5)
        if r.status_code == 200:
            return id_val
    except Exception as e:
        pass
    return None

def sync_batch_to_supabase(batch):
    if not batch: return
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=minimal"
    }
    payload = []
    for d in batch:
        payload.append({
            "id": d[0],
            "name": d[2],
            "usage_type": d[3],
            "target_anatomy": d[4],
            "stimulation_type": d[5],
            "motor_logic": d[6],
            "image_url": d[9],
            "qr_code_url": d[11],
            "supported_funcs": d[12],
            "is_precise": d[16] == '0-255',
            "broadcast_prefix": d[17]
        })
    r = requests.post(f"{SUPABASE_URL}/rest/v1/device_catalog", headers=headers, json=payload)
    return r.status_code

def main():
    print("🚀 Búsqueda Estable de Productos (1-1000)...")
    
    try:
        r = requests.get(CSV_URL)
        rows = list(csv.reader(r.text.splitlines()))
        existing_ids = get_existing_ids(rows)
        print(f"Catálogo actual: {len(rows)-1} registros.")
    except Exception as e:
        print(f"Error: {e}")
        return

    found_ids = []
    ids_to_check = [str(i) for i in range(1001, 4001) if str(i) not in existing_ids]
    count = 0
    total_to_check = len(ids_to_check)
    with concurrent.futures.ThreadPoolExecutor(max_workers=20) as executor:
        futures = {executor.submit(probe_id, id_val): id_val for id_val in ids_to_check}
        for future in concurrent.futures.as_completed(futures):
            count += 1
            res = future.result()
            if res:
                found_ids.append(res)
                print(f"✨ Encontrado: {res}")
            if count % 50 == 0:
                print(f"Progreso: {count}/{total_to_check}")

    if not found_ids:
        print("No se hallaron nuevos productos.")
        return

    # Preparar y guardar
    new_rows = []
    for id_str in sorted(found_ids, key=int):
        new_row = [
            id_str, id_str, f"LVS Device {id_str}", "Universal", "Universal", "Vibración", 
            "Single Channel", "0", id_str, "", "0", 
            f"https://image.zlmicro.com/images/product/qrcode/{id_str}.png",
            "classic|finger|game|intera|music|shake|video", "2.4G", "0", "No", "Estándar", "77 62 4d 53 45", ""
        ]
        new_rows.append(new_row)
        rows.append(new_row)

    with open('devices-categories-updated.csv', 'w', newline='', encoding='utf-8') as f:
        csv.writer(f).writerows(rows)

    print(f"Sincronizando {len(new_rows)} hallazgos con Supabase...")
    status = sync_batch_to_supabase(new_rows)
    if status in [201, 204]:
        print("✅ Sincronización exitosa.")
    else:
        print(f"❌ Error Supabase: {status}")

if __name__ == "__main__":
    main()
