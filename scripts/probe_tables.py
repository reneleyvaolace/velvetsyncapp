import requests

# Test project tlruvlzfiozzskstyrmc (oxen-bala-produccion)
URL1 = "https://tlruvlzfiozzskstyrmc.supabase.co/rest/v1/shared_sessions?select=count"
KEY1 = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRscnV2bHpmaW96enNrc3R5cm1jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIxMjg0MzksImV4cCI6MjA4NzcwNDQzOX0.PkoBOMt3ko4AsT4wt9uuVLpnuyuoT9EdXy57hfOSzjU"

# Test project wsgytnzigqlviqoktmdo (CoreAura)
URL2 = "https://wsgytnzigqlviqoktmdo.supabase.co/rest/v1/shared_sessions?select=count"
KEY2 = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndzZ3l0bnppZ3Fsdmlxb2t0bWRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQzMDk4NjQsImV4cCI6MjA3OTg4NTg2NH0.9Bp-bxWIEnsBEtXb1FaaNoxqRozTPnoYRInE8si8DjA"

def probe(name, url, key):
    headers = {"apikey": key, "Authorization": f"Bearer {key}", "Prefer": "count=exact"}
    try:
        r = requests.get(url, headers=headers)
        print(f"Project: {name}")
        print(f"  Status: {r.status_code}")
        if r.status_code == 200:
            print(f"  Table found! Count: {r.headers.get('Content-Range')}")
        else:
            print(f"  Error: {r.text}")
    except Exception as e:
        print(f"  Failed: {e}")

probe("Oxen Bala", URL1, KEY1)
print("-" * 20)
probe("CoreAura", URL2, KEY2)
