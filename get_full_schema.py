import requests  
import json  
  
SUPABASE_URL = \"https://baeclricgedhxdtmirid.supabase.co\"  
SUPABASE_KEY = \"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJhZWNscmljZ2VkaHhkdG1pcmlkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMwMTUwMjYsImV4cCI6MjA4ODU5MTAyNn0:lPUuU6RiUGyaf36NJH4HysIkgTe8qFxt4CxA5OnjvjU\"  
  
headers = {\"apikey\": SUPABASE_KEY, \"Authorization\": f\"Bearer {SUPABASE_KEY}\"}  
  
r = requests.get(f\"{SUPABASE_URL}/rest/v1/device_catalog?select=*&limit=1\", headers=headers)  
print(\"Status:\", r.status_code)  
data = r.json()  
print(\"Columns:\", list(data[0].keys()) if data else \"None\")  
print(\"\nFirst record:\")  
import pprint; pprint.pprint(data[0]) if data else print(\"No data\")  
