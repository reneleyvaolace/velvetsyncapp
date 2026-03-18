import os
import google.generativeai as genai

# Get API key from environment variable (never hardcode!)
api_key = os.environ.get('GOOGLE_API_KEY')

if not api_key:
    print("Error: GOOGLE_API_KEY environment variable not set")
    print("Set it with: export GOOGLE_API_KEY='your-key-here' (Linux/Mac)")
    print("Or: set GOOGLE_API_KEY=your-key-here (Windows)")
    exit(1)

genai.configure(api_key=api_key)

print("Listing models...")
try:
    for m in genai.list_models():
        if 'generateContent' in m.supported_generation_methods:
            print(f"- {m.name}")
except Exception as e:
    print(f"Error listing models: {e}")

print("\nTesting gemini-1.5-flash...")
try:
    model = genai.GenerativeModel('gemini-1.5-flash')
    response = model.generate_content("Hello")
    print(f"Response: {response.text}")
except Exception as e:
    print(f"Error testing gemini-1.5-flash: {e}")
