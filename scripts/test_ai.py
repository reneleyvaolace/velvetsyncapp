import requests
import json

def test_gemini_proxy():
    url = "https://wsgytnzigqlviqoktmdo.supabase.co/functions/v1/gemini-proxy"
    anon_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndzZ3l0bnppZ3Fsdmlxb2t0bWRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQzMDk4NjQsImV4cCI6MjA3OTg4NTg2NH0.9Bp-bxWIEnsBEtXb1FaaNoxqRozTPnoYRInE8si8DjA"
    
    headers = {
        "Content-Type": "application/json",
        "apikey": anon_key,
        "Authorization": f"Bearer {anon_key}"
    }
    payload = {
        "prompt": "Hola, ¿cómo estás? Responde corto."
    }
    
    try:
        response = requests.post(url, headers=headers, data=json.dumps(payload))
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_gemini_proxy()
