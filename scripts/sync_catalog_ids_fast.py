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
        r = requests.head(url, timeout=3)
        if r.status_code == 200:
            return id_val
    except:
        pass
    return None

def sync_to_supabase(new_entries):
    if not new_entries:
        return

    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=minimal"
    }
    
    payload = []
    for d in new_entries:
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

    # Batch insert (might fail if IDs exist, so we use upsert if needed, but here we just post)
    r = requests.post(f"{SUPABASE_URL}/rest/v1/device_catalog", headers=headers, json=payload)
    if r.status_code in [201, 204]:
        print(f"✅ {len(new_entries)} dispositivos sincronizados con Supabase.")
    else:
        print(f"❌ Error Supabase: {r.status_code} - {r.text}")

def main():
    print("🚀 Búsqueda ACELERADA (1-1000)...")
    
    # 1. Obtener catálogo actual
    try:
        r = requests.get(CSV_URL)
        rows = list(csv.reader(r.text.splitlines()))
        existing_ids = get_existing_ids(rows)
    except Exception as e:
        print(f"Error cargando CSV: {e}")
        return

    # 2. Búsqueda en paralelo (100 hilos)
    found_ids = []
    print("Escaneando rangos en paralelo...")
    with concurrent.futures.ThreadPoolExecutor(max_workers=100) as executor:
        futures = {executor.submit(probe_id, str(i)): i for i in range(1, 1001) if str(i) not in existing_ids}
        for future in concurrent.futures.as_completed(futures):
            res = future.result()
            if res:
                found_ids.append(res)
                print(f"✨ Encontrado: {res}")

    # 3. Preparar nuevas entradas
    new_entries = []
    for id_str in found_ids:
        new_row = [
            id_str, id_str, f"LVS Device {id_str}", "Universal", "Universal", "Vibración", 
            "Single Channel", "0", id_str, "", "0", 
            f"https://image.zlmicro.com/images/product/qrcode/{id_str}.png",
            "classic|finger|game|intera|music|shake|video", "2.4G", "0", "No", "Estándar", "77 62 4d 53 45", ""
        ]
        new_entries.append(new_row)
        rows.append(new_row)

    # 4. Guardar CSV local
    with open('devices-categories-updated.csv', 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerows(rows)
    print(f"💾 Guardado CSV local con {len(found_ids)} nuevos IDs.")

    # 5. Sincronizar Supabase
    if new_entries:
        sync_to_supabase(new_entries)
    else:
        print("No se encontraron nuevos productos en este rango.")

if __name__ == "__main__":
    main()
