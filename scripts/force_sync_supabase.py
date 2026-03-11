import requests
import csv
import json
import os

# Configuración de Supabase
SUPABASE_URL = "https://wsgytnzigqlviqoktmdo.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndzZ3l0bnppZ3Fsdmlxb2t0bWRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQzMDk4NjQsImV4cCI6MjA3OTg4NTg2NH0.9Bp-bxWIEnsBEtXb1FaaNoxqRozTPnoYRInE8si8DjA"
CSV_FILE = 'devices-categories-updated.csv'

def get_already_in_supabase():
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}"
    }
    r = requests.get(f"{SUPABASE_URL}/rest/v1/device_catalog?select=id", headers=headers)
    if r.status_code == 200:
        return {item['id'] for item in r.json()}
    return set()

def upload_missing():
    if not os.path.exists(CSV_FILE):
        print(f"Error: {CSV_FILE} no existe.")
        return

    existing_ids = get_already_in_supabase()
    print(f"IDs ya en Supabase: {len(existing_ids)}")

    to_upload = []
    with open(CSV_FILE, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        header = next(reader)
        for row in reader:
            if row[0] not in existing_ids:
                # Mapeo al esquema de Supabase
                # [0]id, [1]barcode, [2]name, [3]usage, [4]anatomy, [5]stim, [6]motor, [7]dbid, [8]title, [9]pics, [10]cate, [11]qr, [12]funcs, [16]precise, [17]prefix
                device = {
                    "id": row[0],
                    "name": row[2],
                    "usage_type": row[3],
                    "target_anatomy": row[4],
                    "stimulation_type": row[5],
                    "motor_logic": row[6],
                    "image_url": row[9] if row[9] else "",
                    "qr_code_url": row[11],
                    "supported_funcs": row[12],
                    "is_precise": row[16] == '0-255' or row[16] == 'Preciso',
                    "broadcast_prefix": row[17] if len(row) > 17 else "77 62 4d 53 45"
                }
                to_upload.append(device)

    if not to_upload:
        print("Todo está al día.")
        return

    print(f"Subiendo {len(to_upload)} dispositivos faltantes...")
    
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=minimal"
    }

    # Dividir en lotes de 100 para evitar límites de payload
    for i in range(0, len(to_upload), 100):
        batch = to_upload[i:i+100]
        r = requests.post(f"{SUPABASE_URL}/rest/v1/device_catalog", headers=headers, json=batch)
        if r.status_code in [201, 204]:
            print(f"✅ Lote {i//100 + 1} subido.")
        else:
            print(f"❌ Error en lote {i//100 + 1}: {r.status_code} - {r.text}")

if __name__ == "__main__":
    upload_missing()
