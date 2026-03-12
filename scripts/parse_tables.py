import json
import os

filepath = r"C:\Users\Sistemas CDMX\.gemini\antigravity\brain\a84dddb7-eb7d-4649-869f-6e6a7eba9d84\.system_generated\steps\222\output.txt"
with open(filepath, 'r', encoding='utf-8') as f:
    data = json.load(f)

for table in data['tables']:
    if table['name'] in ['public.device_catalog', 'public.products']:
        print(f"Table: {table['name']}")
        for col in table['columns']:
            print(f"  - {col['name']} ({col['data_type']})")
