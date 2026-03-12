
import os
import shutil

source_dir = r"C:\Users\Sistemas CDMX\.gemini\antigravity\brain\eac52166-6856-4bce-8b04-c2bb1839b669"
dest_dir = r"c:\Proyectos\lvs-flutter\icons"

mapping = {
    "icon_sync_music": "icon_sync_music.png",
    "icon_voice_control": "icon_voice_control.png",
    "icon_motion_control": "icon_motion_control.png",
    "icon_custom_pattern": "icon_custom_pattern.png",
    "icon_remote_partner": "icon_remote_partner.png"
}

found_files = os.listdir(source_dir)
for prefix, final_name in mapping.items():
    matches = [f for f in found_files if f.startswith(prefix) and f.endswith(".png")]
    if matches:
        matches.sort(key=lambda x: os.path.getmtime(os.path.join(source_dir, x)), reverse=True)
        shutil.copy2(os.path.join(source_dir, matches[0]), os.path.join(dest_dir, final_name))
        print(f"Transferido: {final_name}")
