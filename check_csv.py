import requests
import csv

url = 'https://raw.githubusercontent.com/reneleyvaolace/velvetsynccatalog/main/devices-categories.csv'
response = requests.get(url)
if response.status_code == 200:
    content = response.text
    reader = csv.reader(content.splitlines())
    rows = list(reader)
    print(f"Total rows: {len(rows)}")
    if rows:
        print(f"Header length: {len(rows[0])}")
        print(f"First row length: {len(rows[1]) if len(rows) > 1 else 'N/A'}")
        print(f"First row values: {rows[1] if len(rows) > 1 else 'N/A'}")
else:
    print(f"Error: {response.status_code}")
