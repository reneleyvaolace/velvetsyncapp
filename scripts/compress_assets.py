"""
compress_assets.py -- Velvet Sync v1.1.0
Comprime todos los PNG en assets/ usando Pillow

Estrategia por carpeta:
  assets/icons/  -> 256x256 max (iconos UI, se renderizan a 32-64px en pantalla)
  assets/images/ -> 1024x1024 max (imagenes de contenido/fondo)

Reduccion esperada vs originales: >90%
"""

import os
import sys
import io

# Forzar salida UTF-8 en Windows
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
from pathlib import Path

# Instalar pillow si no esta
try:
    from PIL import Image
except ImportError:
    print("Instalando Pillow...")
    os.system(f"{sys.executable} -m pip install pillow -q")
    from PIL import Image

ASSETS_DIR = Path(__file__).parent.parent / "assets"

# Configuracion por tipo de asset
CONFIGS = {
    "icons":  {"max_dim": 256, "quantize": True},   # Iconos UI: 256px, paleta reducida
    "images": {"max_dim": 1024, "quantize": False},  # Imagenes de contenido: 1024px
    "default":{"max_dim": 512,  "quantize": False},  # Resto: 512px
}

def get_config(path: Path) -> dict:
    for folder, cfg in CONFIGS.items():
        if folder in str(path):
            return cfg
    return CONFIGS["default"]


def compress_png(path: Path) -> tuple:
    """Comprime un PNG y retorna (tamano_original, tamano_nuevo) en bytes."""
    original_size = path.stat().st_size
    cfg = get_config(path)
    max_dim = cfg["max_dim"]

    with Image.open(path) as img:
        # Mantener transparencia si existe
        has_alpha = img.mode == "RGBA" or (
            img.mode == "P" and "transparency" in img.info
        )
        target_mode = "RGBA" if has_alpha else "RGB"
        if img.mode != target_mode:
            img = img.convert(target_mode)

        # Redimensionar si supera el maximo
        w, h = img.size
        if w > max_dim or h > max_dim:
            ratio = min(max_dim / w, max_dim / h)
            new_w, new_h = int(w * ratio), int(h * ratio)
            img = img.resize((new_w, new_h), Image.LANCZOS)
            print(f"  Redimensionado: {w}x{h} -> {new_w}x{new_h}")

        # Cuantizacion de color para iconos (reduce peso ~60-70%)
        # FASTOCTREE es el unico metodo que soporta RGBA en Pillow
        if cfg["quantize"] and img.mode == "RGBA":
            img = img.quantize(
                colors=128,
                method=Image.Quantize.FASTOCTREE,
                dither=1
            ).convert("RGBA")

        img.save(path, format="PNG", optimize=True, compress_level=9)

    new_size = path.stat().st_size
    return original_size, new_size


def main():
    print(f"\n{'='*60}")
    print("  Velvet Sync -- Compresor de Assets v1.1.0")
    print(f"{'='*60}")
    print(f"Directorio: {ASSETS_DIR}\n")
    print("  icons/  -> max 256px + cuantizacion (iconos UI)")
    print("  images/ -> max 1024px (imagenes de contenido)")
    print("  otros   -> max 512px\n")

    png_files = list(ASSETS_DIR.rglob("*.png"))
    if not png_files:
        print("No se encontraron archivos PNG.")
        return

    total_original = 0
    total_new = 0

    for png in sorted(png_files):
        rel = png.relative_to(ASSETS_DIR.parent)
        try:
            orig, new = compress_png(png)
            total_original += orig
            total_new += new
            pct = (1 - new / orig) * 100 if orig > 0 else 0
            status = "[OK]" if pct > 5 else "[--]"
            print(f"{status} {rel.name:<40} {orig//1024}KB -> {new//1024}KB  (-{pct:.0f}%)")
        except Exception as e:
            print(f"[ERR] {rel.name}: {e}")

    print(f"\n{'='*60}")
    print(f"  TOTAL ORIGINAL : {total_original/1024/1024:.1f} MB")
    print(f"  TOTAL NUEVO    : {total_new/1024/1024:.1f} MB")
    savings = (total_original - total_new) / 1024 / 1024
    pct_saved = (1 - total_new / total_original) * 100
    print(f"  AHORRO         : {savings:.1f} MB  (-{pct_saved:.0f}%)")
    print(f"{'='*60}\n")
    print("[OK] Listo. Reconstruye con:")
    print("     flutter build apk --release --flavor prod --split-per-abi")


if __name__ == "__main__":
    main()
