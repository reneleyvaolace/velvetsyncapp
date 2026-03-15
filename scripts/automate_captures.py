import os
import time
import subprocess
import re

PROJECT_PATH = r"c:\Projects\velvetsync\velvetsyncapp"
MAIN_DART = os.path.join(PROJECT_PATH, "lib", "main.dart")
SCREENSHOT_SCRIPT = os.path.join(PROJECT_PATH, "scripts", "take_screenshot.ps1")
OUTPUT_DIR = os.path.join(PROJECT_PATH, "screenshots")
BRAIN_DIR = r"C:\Users\renel\.gemini\antigravity\brain\07c21e51-6f3d-4bb7-b0c8-66931449dd5d"
LOG_FILE = os.path.join(PROJECT_PATH, "flutter_run.log")

if not os.path.exists(OUTPUT_DIR):
    os.makedirs(OUTPUT_DIR)

SCREENS = [
    ("SplashScreen()", "01_splash"),
    ("ScreenshotGallery()", "02_gallery"),
    ("MainNavigation(initialIndex: 0)", "03_tab_control"),
    ("MainNavigation(initialIndex: 1)", "04_tab_modos"),
    ("MainNavigation(initialIndex: 2)", "05_tab_remoto"),
    ("MainNavigation(initialIndex: 3)", "06_tab_sistema"),
    ("CatalogScreen()", "07_catalog"),
    ("CompanionScreen()", "08_companion"),
    ("DebugScreen()", "09_debug"),
    ("DiceScreen()", "10_dice"),
    ("RouletteScreen()", "11_roulette"),
    ("ReaderScreen()", "12_reader"),
]

def update_main_dart(screen_widget):
    print(f"Updating main.dart with {screen_widget}...")
    with open(MAIN_DART, "r", encoding="utf-8") as f:
        content = f.read()
    
    # Regex to find home: ... in MaterialApp
    # pattern = r"(MaterialApp\(.*?home:\s+)(.*?),(\s+?.*?\))"
    # Manual replacement for safety if regex fails
    lines = content.splitlines()
    for i, line in enumerate(lines):
        if "home:" in line and "MaterialApp" in "".join(lines[max(0, i-10):i]):
            lines[i] = f"      home: const {screen_widget},"
            break
            
    with open(MAIN_DART, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

def kill_app():
    print("Killing existing app processes...")
    subprocess.run(['powershell', '-Command', 'Get-Process | Where-Object { $_.MainWindowTitle -eq "lvs_control" } | Stop-Process -Force'], capture_output=True, shell=True)
    subprocess.run(['powershell', '-Command', 'Get-Process lvs_control -ErrorAction SilentlyContinue | Stop-Process -Force'], capture_output=True, shell=True)
    time.sleep(2)

def restart_app():
    kill_app()
    if os.path.exists(LOG_FILE): os.remove(LOG_FILE)
    print("Starting app via flutter run...")
    with open(LOG_FILE, "w") as log:
        proc = subprocess.Popen(['flutter', 'run', '-d', 'windows', '--no-hot'], cwd=PROJECT_PATH, stdout=log, stderr=log, shell=True)
    
    print(f"App started. Waiting for window (max 3 mins)...")
    timeout = 180
    start_time = time.time()
    while time.time() - start_time < timeout:
        result = subprocess.run(['powershell', '-Command', 'Get-Process | Where-Object { $_.MainWindowTitle -eq "lvs_control" }'], capture_output=True, text=True, shell=True)
        if "lvs_control" in result.stdout:
            print("Window detected! Waiting for rendering...")
            time.sleep(20) # Wait more for full render
            return True
        time.sleep(10)
    print("Timeout waiting for window. Log file content:")
    if os.path.exists(LOG_FILE):
        with open(LOG_FILE, "r") as f:
            print(f.read()[:500])
    return False

def take_screenshot(name):
    print(f"Taking screenshot for {name}...")
    subprocess.run(['powershell', '-ExecutionPolicy', 'Bypass', '-File', SCREENSHOT_SCRIPT], capture_output=True, shell=True)
    
    # Move file from brain dir to output dir
    files = [f for f in os.listdir(BRAIN_DIR) if f.startswith("desktop_screenshot_") and f.endswith(".png")]
    if files:
        latest_file = max([os.path.join(BRAIN_DIR, f) for f in files], key=os.path.getctime)
        dest = os.path.join(OUTPUT_DIR, f"{name}.png")
        if os.path.exists(dest): os.remove(dest)
        os.rename(latest_file, dest)
        print(f"Saved: {dest}")
    else:
        print("Error: No screenshot found in brain dir!")

if __name__ == "__main__":
    for widget, name in SCREENS:
        print(f"\n--- Processing: {name} ---")
        update_main_dart(widget)
        if restart_app():
            take_screenshot(name)
        else:
            print(f"FAILED to start app for {name}")
    
    print("\nCapture process FINISHED.")
    kill_app()
