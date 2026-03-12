import requests

# Test project tlruvlzfiozzskstyrmc (oxen-bala-produccion)
URL = "https://tlruvlzfiozzskstyrmc.supabase.co/rest/v1/shared_sessions?select=*"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRscnV2bHpmb296enNrc3R5cm1jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDA1OTI0MzksImV4cCI6MjA1NjE2ODQzOX0.6n7vA-3Y3O-z9n6_xS6Y4A6n7vA-3Y3O-z9n6_xS6Y4A" 

# Getting keys via MCP first to be sure
headers = {
    "apikey": "REPLACEME",
    "Authorization": "Bearer REPLACEME"
}

print("This script is just a template, I will fetch real keys first.")
