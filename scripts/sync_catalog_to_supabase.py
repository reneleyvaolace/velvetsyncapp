import requests
import csv
import json
import os

# Configuración de Supabase
SUPABASE_URL = "https://wsgytnzigqlviqoktmdo.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndzZ3l0bnppZ3Fsdmlxb2t0bWRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQzMDk4NjQsImV4cCI6MjA3OTg4NTg2NH0.9Bp-bxWIEnsBEtXb1FaaNoxqRozTPnoYRInE8si8DjA"
CSV_FILE = 'devices-categories-updated.csv'

def sync_catalog():
    if not os.path.exists(CSV_FILE):
        print(f"Error: {CSV_FILE} no existe.")
        return

    to_upsert = []
    with open(CSV_FILE, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        header = next(reader)
        for row in reader:
            # Mapeo según el nuevo esquema
            anatomy_raw = row[4].split('|') if row[4] else []
            device = {
                "id": row[0],
                "model_name": row[2],
                "usage_type": row[3],
                "target_anatomy": anatomy_raw, # Se enviará como JSON
                "stimulation_type": row[5],
                "motor_logic": row[6],
                "image_url": row[9] if row[9] else "",
                "qr_code_url": row[11],
                "supported_funcs": row[12],
                "is_precise_new": row[16] in ['0-255', 'Preciso'],
                "broadcast_prefix": row[17] if len(row) > 17 else "77 62 4d 53 45"
            }
            to_upsert.append(device)

    print(f"Sincronizando {len(to_upsert)} dispositivos...")
    
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates" # Esto hace el UPSERT
    }

    # Dividir en lotes de 100
    for i in range(0, len(to_upsert), 100):
        batch = to_upsert[i:i+100]
        r = requests.post(f"{SUPABASE_URL}/rest/v1/device_catalog", headers=headers, json=batch)
        if r.status_code in [200, 201, 204]:
            print(f"✅ Lote {i//100 + 1} sincronizado.")
        else:
            print(f"❌ Error en lote {i//100 + 1}: {r.status_code} - {r.text}")

if __name__ == "__main__":
    sync_catalog()
