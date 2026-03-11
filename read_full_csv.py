import requests
import csv

url = 'https://raw.githubusercontent.com/reneleyvaolace/velvetsynccatalog/main/devices-categories.csv'
response = requests.get(url)
if response.status_code == 200:
    content = response.text
    reader = csv.reader(content.splitlines())
    rows = list(reader)
    for i, row in enumerate(rows):
        print(f"Row {i}: {row}")
else:
    print(f"Error: {response.status_code}")
