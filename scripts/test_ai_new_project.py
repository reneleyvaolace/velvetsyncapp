import requests
import json

def test_gemini_proxy():
    # Nueva URL del proyecto indicado por el usuario
    url = "https://baeclricgedhxdtmirid.supabase.co/functions/v1/gemini-proxy"
    # Nueva ANON KEY indicada por el usuario
    anon_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJhZWNscmljZ2VkaHhkdG1pcmlkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMwMTUwMjYsImV4cCI6MjA4ODU5MTAyNn0.lPUuU6RiUGyaf36NJH4HysIkgTe8qFxt4CxA5OnjvjU"
    
    headers = {
        "Content-Type": "application/json",
        "apikey": anon_key,
        "Authorization": f"Bearer {anon_key}"
    }
    payload = {
        "prompt": "Hola, ¿puedes leerme? Responde corto."
    }
    
    print(f"Probando conexion a: {url}")
    try:
        response = requests.post(url, headers=headers, data=json.dumps(payload), timeout=15)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
    except Exception as e:
        print(f"Error de conexión: {e}")

if __name__ == "__main__":
    test_gemini_proxy()
