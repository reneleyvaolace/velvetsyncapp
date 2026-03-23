import requests
import json

SUPABASE_URL = "https://baeclricgedhxdtmirid.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJhZWNscmljZ2VkaHhkdG1pcmlkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMwMTUwMjYsImV4cCI6MjA4ODU5MTAyNn0.lPUuU6RiUGyaf36NJH4HysIkgTe8qFxt4CxA5OnjvjU"

headers = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json",
    "Accept": "application/json"
}

try:
    response = requests.get(
        f"{SUPABASE_URL}/rest/v1/device_catalog?select=id,model_name,usage_type&limit=500",
        headers=headers,
        timeout=10
    )
    
    print(f"Status Code: {response.status_code}")
    print(f"Response Headers: {response.headers}")
    
    if response.status_code == 200:
        devices = response.json()
        print(f"\n{'='*80}")
        print(f"TOTAL DE DISPOSITIVOS EN CATALOGO: {len(devices)}")
        print(f"{'='*80}\n")
        
        target_models = ['9303', '3778', '8154']
        found_models = []
        
        print(f"{'ID':<10} {'MODEL NAME':<40} {'USAGE'}")
        print(f"{'-'*80}")
        
        for device in devices:
            id_val = str(device.get('id', 'N/A'))
            model_name = str(device.get('model_name', 'N/A'))[:38]
            usage = str(device.get('usage_type', 'N/A'))
            
            print(f"{id_val:<10} {model_name:<40} {usage}")
            
            if id_val in target_models:
                found_models.append(id_val)
        
        print(f"\n{'='*80}")
        print(f"MODELOS OBJETIVO ENCONTRADOS: {found_models}")
        print(f"{'='*80}\n")
        
        with open('catalog_dump.txt', 'w', encoding='utf-8') as f:
            json.dump(devices, f, indent=2, ensure_ascii=False)
        print("Catalogo guardado en: catalog_dump.txt\n")
    else:
        print(f"Error Response: {response.text}")
except Exception as e:
    print(f"Exception: {e}")
