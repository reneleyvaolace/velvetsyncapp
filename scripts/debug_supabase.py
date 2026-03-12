import requests

URL = "https://baeclricgedhxdtmirid.supabase.co/rest/v1/device_catalog?select=count"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6ImJhZWNscmljZ2VkaHhkdG1pcmlkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMwMTUwMjYsImV4cCI6MjA4ODU5MTAyNn0.lPUuU6RiUGyaf36NJH4HysIkgTe8qFxt4CxA5OnjvjU"

headers = {
    "apikey": KEY,
    "Authorization": f"Bearer {KEY}",
    "Range-Unit": "items",
    "Range": "0-0",
    "Prefer": "count=exact"
}

try:
    r = requests.get(URL, headers=headers)
    print(f"Status: {r.status_code}")
    print(f"Count: {r.headers.get('Content-Range', 'Unknown')}")
    
    # Try insert into shared_sessions
    print("\nProbing shared_sessions insert...")
    insert_url = "https://baeclricgedhxdtmirid.supabase.co/rest/v1/shared_sessions"
    insert_payload = {"device_id": "8154", "is_active": True}
    r2 = requests.post(insert_url, headers=headers, json=insert_payload)
    print(f"Insert Status: {r2.status_code}")
    print(f"Insert Response: {r2.text}")
except Exception as e:
    print(f"Error: {e}")
