import requests
import csv

url = 'https://raw.githubusercontent.com/reneleyvaolace/velvetsynccatalog/main/devices-categories.csv'
response = requests.get(url)
if response.status_code == 200:
    content = response.text
    reader = csv.reader(content.splitlines())
    rows = list(reader)
    # Escribir a un archivo local para que el agente pueda leerlo cómodamente
    with open('catalog_dump.txt', 'w', encoding='utf-8') as f:
        for i, row in enumerate(rows):
            f.write(f"Row {i}: {row}\n")
    print("Catálogo guardado en catalog_dump.txt")
else:
    print(f"Error: {response.status_code}")
