import requests
import time
import random
import json
import os
import re
from datetime import datetime

# --- CONFIGURACIÓN INTEGRAL COREAURA ---
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
START_ID = 1000
LOG_FILE = os.path.join(BASE_DIR, "reconstruccion_progreso.log")
DICT_FILE = os.path.join(BASE_DIR, "traducciones.json")
SQL_FOLDER = os.path.join(BASE_DIR, "sql_batches_completos")
IMG_FOLDER = os.path.join(BASE_DIR, "velvet_assets")
QR_FOLDER = os.path.join(BASE_DIR, "velvet_qrcodes")
GENERIC_IMG = "logo_velvet.png"
RECORDS_PER_FILE = 500

for folder in [SQL_FOLDER, IMG_FOLDER, QR_FOLDER]:
    if not os.path.exists(folder):
        os.makedirs(folder)


def cargar_diccionario():
    if os.path.exists(DICT_FILE):
        with open(DICT_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}


TRADUCCIONES = cargar_diccionario()


def verificar_y_descargar(url, barcode, folder, prefix):
    if not url:
        return GENERIC_IMG if prefix == "VS" else "default_qr.png"
    filename = f"{prefix}_{barcode}.png"
    path = os.path.join(folder, filename)

    if not os.path.exists(path) or os.path.getsize(path) == 0:
        try:
            res = requests.get(url, headers={"User-Agent": "Mozilla/5.0"}, timeout=15)
            if res.status_code == 200 and len(res.content) > 0:
                with open(path, "wb") as f:
                    f.write(res.content)
                return filename
        except:
            pass
    return (
        filename
        if os.path.exists(path)
        else (GENERIC_IMG if prefix == "VS" else "default_qr.png")
    )


def inferir_genero(nombre):
    n = nombre.lower()
    if any(w in n for w in ["cup", "masturbator", "male", "stroker"]):
        return "Hombre"
    if any(
        w in n
        for w in ["kegel", "butterfly", "egg", "clit", "vibrator", "woman", "lady"]
    ):
        return "Mujer"
    return "Universal"


def limpiar_titulo(texto, barcode):
    if not texto:
        return f"VelSyn {barcode}"
    for c, i in TRADUCCIONES.items():
        texto = texto.replace(c, i)
    limpio = re.sub(r"[\u4e00-\u9fff]", "", texto).strip()
    return limpio if len(limpio) >= 3 else f"VelSyn {barcode}"


# --- LÓGICA DE INFERENCIA PARA CAMPOS TÉCNICOS ---


def inferir_usage_type(cate_id, classic_id, device_title, nombre_original):
    """Infiere el tipo de uso basado en CateId, ClassicId y nombre del dispositivo"""
    title_lower = device_title.lower()
    nombre_lower = nombre_original.lower() if nombre_original else ""

    # External: CateId 3 (Dual), vibrator, wand
    if (
        cate_id == 3
        or "vibrator" in title_lower
        or "vibrator" in nombre_lower
        or "wand" in title_lower
    ):
        return "external"

    # Hybrid: ClassicId menciona egg o anal
    if classic_id:
        for item in classic_id:
            name = item.get("Name", "").lower()
            if "egg" in name or "anal" in name or "蛋" in name or "肛门" in name:
                return "hybrid"

    # Internal: Masturbator, sucking
    if (
        "masturbator" in title_lower
        or "sucking" in title_lower
        or "飞机杯" in nombre_original
        or "名器" in nombre_original
    ):
        return "internal"

    return "external"  # Default


def inferir_stimulation_type(product_funcs, func_obj):
    """Infiere el tipo de estimulación basado en ProductFuncs y FuncObj"""
    stimulation_types = []

    # Verificar desde ProductFuncs
    if product_funcs:
        for func in product_funcs:
            code = func.get("Code", "").lower()
            name = func.get("Name", "").lower()

            if "classic" in code or "vibrat" in name or "震动" in func.get("Name", ""):
                if "vibration" not in stimulation_types:
                    stimulation_types.append("vibration")
            if "heat" in code or "加热" in func.get("Name", ""):
                if "heating" not in stimulation_types:
                    stimulation_types.append("heating")
            if (
                "thrust" in code
                or "伸缩" in func.get("Name", "")
                or "冲" in func.get("Name", "")
            ):
                if "thrusting" not in stimulation_types:
                    stimulation_types.append("thrusting")
            if (
                "suction" in code
                or "吸吮" in func.get("Name", "")
                or "吸" in func.get("Name", "")
            ):
                if "suction" not in stimulation_types:
                    stimulation_types.append("suction")
            if "kegel" in code or "凯格尔" in func.get("Name", ""):
                if "kegel" not in stimulation_types:
                    stimulation_types.append("kegel")

    # Verificar desde FuncObj
    if func_obj:
        if func_obj.get("heating") and "heating" not in stimulation_types:
            stimulation_types.append("heating")
        if func_obj.get("thrust") and "thrusting" not in stimulation_types:
            stimulation_types.append("thrusting")
        if func_obj.get("suction") and "suction" not in stimulation_types:
            stimulation_types.append("suction")

    if not stimulation_types:
        return "vibration"  # Default

    return ", ".join(stimulation_types)


def inferir_max_intensity(device_title):
    """Infiere la intensidad máxima basada en el nombre del modelo"""
    title_lower = device_title.lower()
    if "pro" in title_lower or "elite" in title_lower or "premium" in title_lower:
        return 12
    return 10


def inferir_motor_logic(cate_id):
    """Infiere la lógica del motor"""
    if cate_id == 3:
        return "dual"
    return "single"


def inferir_target_anatomy(genero):
    """Infiere la anatomía objetivo basada en el género"""
    if genero == "Mujer":
        return json.dumps({"clitoral": True, "vaginal": False, "anal": False})
    elif genero == "Hombre":
        return json.dumps({"prostate": True, "penile": True, "anal": False})
    else:  # Universal
        return json.dumps(
            {"clitoral": True, "vaginal": True, "prostate": True, "anal": False}
        )


def generar_cmd_hex_from_prefix(broadcast_prefix):
    """Genera thrust_cmd_hex y vibration_cmd_hex desde BroadcastPrefix"""
    if not broadcast_prefix:
        return "", ""

    prefix_clean = broadcast_prefix.replace(" ", "").lower()
    if len(prefix_clean) >= 8:
        # Generar comando de vibración (base + 01)
        vibration = prefix_clean[:8] + "01"
        # Generar comando de thrust (base + 02)
        thrust = prefix_clean[:8] + "02"
        return thrust, vibration
    return "", ""


# --- MOTOR DE RECONSTRUCCIÓN ---
if os.path.exists(LOG_FILE):
    with open(LOG_FILE, "r") as f_log:
        content = f_log.read().strip()
        current_id = int(content) if content else START_ID
else:
    current_id = START_ID

print(f">>> RECONSTRUYENDO CATÁLOGO COREAURA DESDE ID: {current_id}")

try:
    while True:
        batch_id = (current_id // RECORDS_PER_FILE) * RECORDS_PER_FILE
        file_path = os.path.join(SQL_FOLDER, f"batch_full_{batch_id}.txt")
        url_api = f"https://lovespouse.zlmicro.com/index.php?g=App&m=Diyapp&a=getproductdetail&barcode={current_id}&userid=-1"

        try:
            res = requests.get(
                url_api, headers={"User-Agent": "Mozilla/5.0"}, timeout=10
            )
            if res.status_code == 200:
                data = res.json().get("data")
                if isinstance(data, dict) and data.get("BarCode"):
                    barcode = data.get("BarCode")

                    # Datos básicos
                    nombre_final = limpiar_titulo(
                        data.get("DeviceTitle") or data.get("Name"), barcode
                    )
                    nombre_sql = nombre_final.replace("'", "''")

                    factory_raw = data.get("Name") or "N/A"
                    factory_sql = factory_raw.replace("'", "''")

                    # Género
                    genero = inferir_genero(nombre_final)

                    # Funciones
                    func_obj = data.get("FuncObj", {})
                    supported_funcs = json.dumps(func_obj)
                    product_funcs = data.get("ProductFuncs", [])

                    # Broadcast y comandos
                    broadcast_prefix = data.get("BroadcastPrefix") or ""
                    thrust_cmd, vibration_cmd = generar_cmd_hex_from_prefix(
                        broadcast_prefix
                    )

                    # Campos inferidos
                    cate_id = data.get("CateId", 0)
                    classic_id = data.get("ClassicId", [])

                    usage_type = inferir_usage_type(
                        cate_id, classic_id, nombre_final, factory_raw
                    )
                    stimulation_type = inferir_stimulation_type(product_funcs, func_obj)
                    max_intensity = inferir_max_intensity(nombre_final)
                    motor_logic = inferir_motor_logic(cate_id)
                    target_anatomy = inferir_target_anatomy(genero)

                    is_precise = data.get("IsPrecise") == 1

                    # Descargar imágenes
                    img_local = verificar_y_descargar(
                        data.get("Pics"), barcode, IMG_FOLDER, "VS"
                    )
                    qr_local = verificar_y_descargar(
                        data.get("Qrcode"), barcode, QR_FOLDER, "QR"
                    )

                    # Raw JSON
                    raw_json_esc = json.dumps(data).replace("'", "''")

                    # SQL con TODOS los campos
                    sql = (
                        f"INSERT INTO device_catalog ("
                        f"id, model_name, image_url, qr_code_url, supported_funcs, "
                        f"broadcast_prefix, is_precise_new, gender, raw_json_data, factory_model, "
                        f"usage_type, stimulation_type, motor_logic, max_intensity, target_anatomy, "
                        f"certified_by_coreaura, thrust_cmd_hex, vibration_cmd_hex, "
                        f"burst_safety_seconds, cool_down_seconds, verification_command, expected_ack"
                        f") VALUES ("
                        f"'{barcode}', '{nombre_sql}', '{img_local}', '{qr_local}', '{supported_funcs}', "
                        f"'{broadcast_prefix}', {str(is_precise).lower()}, '{genero}', '{raw_json_esc}', '{factory_sql}', "
                        f"'{usage_type}', '{stimulation_type}', '{motor_logic}', {max_intensity}, '{target_anatomy}', "
                        f"true, '{thrust_cmd}', '{vibration_cmd}', "
                        f"30, 60, '', ''"
                        f") ON CONFLICT (id) DO UPDATE SET "
                        f"model_name=EXCLUDED.model_name, image_url=EXCLUDED.image_url, qr_code_url=EXCLUDED.qr_code_url, "
                        f"supported_funcs=EXCLUDED.supported_funcs, gender=EXCLUDED.gender, "
                        f"raw_json_data=EXCLUDED.raw_json_data, factory_model=EXCLUDED.factory_model, "
                        f"usage_type=EXCLUDED.usage_type, stimulation_type=EXCLUDED.stimulation_type, "
                        f"motor_logic=EXCLUDED.motor_logic, max_intensity=EXCLUDED.max_intensity, "
                        f"target_anatomy=EXCLUDED.target_anatomy, certified_by_coreaura=EXCLUDED.certified_by_coreaura, "
                        f"thrust_cmd_hex=EXCLUDED.thrust_cmd_hex, vibration_cmd_hex=EXCLUDED.vibration_cmd_hex;\n"
                    )

                    with open(file_path, "a", encoding="utf-8") as f:
                        f.write(sql)

                    print(
                        f"[OK] {barcode} | {nombre_final[:20]:<20} | {usage_type:<10} | {stimulation_type}"
                    )
                else:
                    print(f"[-] {current_id} vacío en servidor.")
        except Exception as e:
            print(f"[!] Error en ID {current_id}: {e}")

        current_id += 1
        with open(LOG_FILE, "w") as f_log:
            f_log.write(str(current_id))

        time.sleep(random.uniform(1.5, 3.0))

except KeyboardInterrupt:
    print("\n>>> Motor detenido manualmente. Progreso guardado.")
