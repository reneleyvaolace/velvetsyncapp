import requests  
import os  
  
SUPABASE_URL = \"https://baeclricgedhxdtmirid.supabase.co\"  
SUPABASE_KEY = \"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJhZWNscmljZ2VkaHhkdG1pcmlkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMwMTUwMjYsImV4cCI6MjA4ODU5MTAyNn0:lPUuU6RiUGyaf36NJH4HysIkgTe8qFxt4CxA5OnjvjU\"  
r = requests.get(SUPABASE_URL + \"/rest/v1/device_catalog?select=id,model_name\", headers={\"apikey\": SUPABASE_KEY, \"Authorization\": \"Bearer \" + SUPABASE_KEY})  
db = set([p[\"id\"] for p in r.json()]) if r.status_code == 200 else set()  
print(\"Supabase:\", len(db), \"productos\")  
imgs = set([f[3:-4] for f in os.listdir(r\"c:\Proyectos\velvetsynccatalog\documentacion\docs\img\") if f.startswith(\"VS_\") and f.endswith(\".jpg\")])  
print(\"Imagenes:\", len(imgs))  
qrs = set([f[3:-4] for f in os.listdir(r\"c:\Proyectos\velvetsynccatalog\documentacion\docs\qr\") if f.startswith(\"QR_\") and f.endswith(\".png\")])  
print(\"QRs:\", len(qrs))  
print()  
print(\"CRITICOS:\")  
for p in [\"8154\",\"3778\",\"9303\"]: print(f\"  {p}: DB={p in db}, IMG={p in imgs}, QR={p in qrs}\")  
print()  
