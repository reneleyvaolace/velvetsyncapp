import requests
import csv
import json
import time

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
        r = requests.head(url, timeout=2)
        return r.status_code == 200
    except:
        return False

def sync_to_supabase(new_devices):
    if not new_devices:
        print("No hay nuevos dispositivos para subir a Supabase.")
        return

    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=minimal"
    }
    
    # Mapear al esquema de Supabase: id, name, usage_type, target_anatomy, stimulation_type, motor_logic, image_url, qr_code_url, supported_funcs, is_precise, broadcast_prefix
    payload = []
    for d in new_devices:
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
    if r.status_code in [201, 204]:
        print(f"✅ {len(new_devices)} dispositivos subidos exitosamente a Supabase.")
    else:
        print(f"❌ Error al subir a Supabase: {r.status_code} - {r.text}")

def main():
    print("🚀 Iniciando búsqueda de productos (1-1000)...")
    
    # 1. Obtener catálogo actual
    try:
        r = requests.get(CSV_URL)
        csv_text = r.text
        rows = list(csv.reader(csv_text.splitlines()))
        existing_ids = get_existing_ids(rows)
        print(f"Catálogo actual cargado: {len(rows)-1} registros.")
    except Exception as e:
        print(f"Error cargando CSV: {e}")
        return

    # 2. Búsqueda de nuevos IDs
    new_entries = []
    found_count = 0
    for i in range(1, 1001):
        id_str = str(i)
        if id_str in existing_ids:
            continue
        
        if probe_id(id_str):
            print(f"✨ Encontrado nuevo producto: ID {id_str}")
            # Crear entrada genérica basada en patrones comunes
            # 0:ID, 1:Barcode, 2:Nombre, 3:UsageType, 4:TargetAnatomy, 5:StimulationType, 6:MotorLogic, 7:DB_Id, 8:RealTitle, 9:Pics, 10:CateId, 11:Qrcode, 12:SupportedFuncs, 13:Wireless, 14:FactoryId, 15:IsEncrypt, 16:IsPrecise, 17:BroadcastPrefix, 18:BleName
            new_row = [
                id_str, id_str, f"LVS Device {id_str}", "Universal", "Universal", "Vibración", 
                "Single Channel", "0", id_str, "", "0", 
                f"https://image.zlmicro.com/images/product/qrcode/{id_str}.png",
                "classic|finger|game|intera|music|shake|video", "2.4G", "0", "No", "Estándar", "77 62 4d 53 45", ""
            ]
            new_entries.append(new_row)
            rows.append(new_row)
            found_count += 1
            
        if i % 100 == 0:
            print(f"Progreso: {i}/1000...")

    # 3. Guardar CSV localmente
    with open('devices-categories-updated.csv', 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerows(rows)
    print(f"💾 CSV actualizado guardado en 'devices-categories-updated.csv'. Total encontrados: {found_count}")

    # 4. Sincronizar con Supabase
    if new_entries:
        sync_to_supabase(new_entries)
    else:
        print("No se encontraron nuevos productos en el rango 1-1000.")

if __name__ == "__main__":
    main()
