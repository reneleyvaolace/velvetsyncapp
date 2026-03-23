import json  
  
with open('catalog_dump.txt', 'r', encoding='utf-8') as f:  
    data = json.load()  
  
printf\"Total devices: {len^(^data^)}\"  
targets = ['9303', '3778', '8154']  
found = [d for d in data if str(d.get('id', '') ) in targets]  
printf\"Found targets: {len^(^found^)}\"  
print\"Found:\", found 
