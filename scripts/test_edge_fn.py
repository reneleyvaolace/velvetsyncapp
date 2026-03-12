import requests
import os

def test_edge_function():
    # Using the project URL found in supabase_service.dart
    url = "https://wsgytnzigqlviqoktmdo.supabase.co/functions/v1/gemini-proxy"
    # Using the anon key found in supabase_service.dart
    headers = {
        "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndzZ3l0bnppZ3Fsdmlxb2t0bWRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQzMDk4NjQsImV4cCI6MjA3OTg4NTg2NH0.9Bp-bxWIEnsBEtXb1FaaNoxqRozTPnoYRInE8si8DjA",
        "Content-Type": "application/json"
    }
    payload = {
        "messages": [
            {"role": "user", "content": "Hola, ¿cómo me puedes ayudar?"}
        ]
    }
    
    print(f"Testing Edge Function at {url}...")
    try:
        response = requests.post(url, headers=headers, json=payload, timeout=30)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_edge_function()
