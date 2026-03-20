import csv  
  
targets = ['9303', '3778', '8154']  
found = [ ]  
  
with open('devices-categories-updated.csv', 'r', encoding='utf-8') as f:  
    reader = csv.reader(f)  
    header = next(reader)  
    for row in reader:  
        if row:  
            device_id = row[0] if len(row) > 0 else ''  
            for target in targets:  
                if target in device_id:  
                    found.append(row)  
  
print('Found:', len(found))  
print('Results:', found[:10]) 
