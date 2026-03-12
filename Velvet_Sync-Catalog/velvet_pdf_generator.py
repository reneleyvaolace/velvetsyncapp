import os
import re
from fpdf import FPDF
from PIL import Image

# --- CONFIGURACIÓN DE RUTAS ---
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PATH_SQL = os.path.join(BASE_DIR, "sql_batches_completos")
PATH_ASSETS = os.path.join(BASE_DIR, "velvet_assets")
PATH_QR = os.path.join(BASE_DIR, "velvet_qrcodes")
PATH_OUTPUT = os.path.join(BASE_DIR, "output_fichas_finales")
PATH_ENGINE = os.path.join(BASE_DIR, "engine")
PATH_TEMP = os.path.join(BASE_DIR, "temp")
PATH_FUENTES = os.path.join(PATH_ENGINE, "Inter", "static")

if not os.path.exists(PATH_OUTPUT):
    os.makedirs(PATH_OUTPUT)
if not os.path.exists(PATH_TEMP):
    os.makedirs(PATH_TEMP)

# --- MAPEO DE ICONOS ---
ICONOS = {
    "USAGE_TYPE": {
        "external": "icon_vibrator.png",
        "internal": "icon_egg.png",
        "hybrid": "icon_dual_motor.png",
    },
    "DESTINO": {
        "hombre": "icon_male.png",
        "mujer": "icon_female.png",
        "universal": "icon_universal.png",
    },
    "STIMULATION": {
        "vibration": "icon_bullet.png",
        "heating": "icon_heating.png",
        "thrusting": "icon_thrust.png",
        "suction": "icon_suction.png",
        "kegel": "icon_kegel.png",
    },
}


# --- LÓGICA DE CONVERSIÓN 16-BIT A 8-BIT ---
def preparar_imagen(ruta_original):
    if not os.path.exists(ruta_original):
        return None
    nombre_archivo = os.path.basename(ruta_original)
    ruta_temp = os.path.join(PATH_TEMP, "8bit_" + nombre_archivo)
    try:
        with Image.open(ruta_original) as img:
            img_rgb = img.convert("RGB")
            img_rgb.save(ruta_temp, "PNG")
            return ruta_temp
    except:
        return None


# --- CLASE DE DISEÑO COREAURA ---
class VelvetPDFMaster(FPDF):
    def __init__(self):
        super().__init__()
        self.fuente_activa = "Arial"
        try:
            self.add_font(
                "Inter",
                "B",
                os.path.join(PATH_FUENTES, "Inter_18pt-Bold.ttf"),
                uni=True,
            )
            self.add_font(
                "Inter",
                "",
                os.path.join(PATH_FUENTES, "Inter_18pt-Regular.ttf"),
                uni=True,
            )
            self.fuente_activa = "Inter"
        except:
            pass

    def header(self):
        self.set_fill_color(5, 5, 10)  # Fondo Negro OLED
        self.rect(0, 0, 210, 297, "F")
        # Líneas Neón superiores
        lines_top = os.path.join(PATH_ENGINE, "asset_lines_top.png")
        if os.path.exists(lines_top):
            self.image(lines_top, x=0, y=0, w=210)
        # Branding
        logo_img = os.path.join(PATH_ENGINE, "logo_velvet.png")
        if os.path.exists(logo_img):
            self.image(logo_img, x=10, y=10, h=14)
            self.set_xy(35, 12)
            self.set_font(self.fuente_activa, "B", 18)
            self.set_text_color(255, 255, 255)
            self.cell(0, 10, "V E L V E T  S Y N C", 0, 1, "L")

    def footer(self):
        lines_bot = os.path.join(PATH_ENGINE, "asset_lines_bottom.png")
        if os.path.exists(lines_bot):
            self.image(lines_bot, x=0, y=282, w=210)

    def draw_glass_card(self, x, y, w, h, title="", icon_name=None):
        self.set_fill_color(26, 26, 46)  # Glass color
        self.set_draw_color(255, 255, 255)
        self.set_line_width(0.1)
        self.rect(x, y, w, h, "F")
        if title:
            self.set_xy(x + 5, y + 4)
            self.set_font(self.fuente_activa, "B", 11)
            self.set_text_color(0, 240, 255)  # Teal
            if icon_name:
                path_icon = os.path.join(PATH_ENGINE, icon_name)
                if os.path.exists(path_icon):
                    self.image(path_icon, x=x + 5, y=y + 3.5, h=7)
                    self.set_x(x + 15)
            self.cell(0, 5, " ".join(list(title.upper())), 0, 1)


def extraer_datos_sql(linea):
    try:
        # SQL con 22 campos
        # INSERT INTO device_catalog (id, model_name, image_url, qr_code_url, supported_funcs, broadcast_prefix, is_precise_new, gender, raw_json_data, factory_model, usage_type, stimulation_type, motor_logic, max_intensity, target_anatomy, certified_by_coreaura, thrust_cmd_hex, vibration_cmd_hex, burst_safety_seconds, cool_down_seconds, verification_command, expected_ack)
        match = re.search(
            r"VALUES \('([^']+)', '([^']+)', '([^']+)', '([^']+)', '([^']+)', '([^']+)', ([^,]+), '([^']+)', '([^']+)', '([^']+)', '([^']+)', '([^']+)', '([^']+)', (\d+), '([^']+)', (true|false), '([^']+)', '([^']+)', (\d+), (\d+), '([^']*)', '([^']*)'\)",
            linea,
        )
        if match:
            return {
                "id": match.group(1),
                "model_name": match.group(2),
                "img_file": match.group(3),
                "qr_file": match.group(4),
                "supported_funcs": match.group(5),
                "broadcast_prefix": match.group(6),
                "is_precise_new": match.group(7).strip(),
                "gender": match.group(8),
                "raw_json_data": match.group(9),
                "factory_model": match.group(10),
                "usage_type": match.group(11),
                "stimulation_type": match.group(12),
                "motor_logic": match.group(13),
                "max_intensity": match.group(14),
                "target_anatomy": match.group(15),
                "certified_by_coreaura": match.group(16),
                "thrust_cmd_hex": match.group(17),
                "vibration_cmd_hex": match.group(18),
                "burst_safety_seconds": match.group(19),
                "cool_down_seconds": match.group(20),
                "verification_command": match.group(21),
                "expected_ack": match.group(22),
            }
    except Exception as e:
        pass
    return None


# --- PROCESO MASIVO ---
print(f">>> Motor de Fichas CoreAura v3.0 | Lote actual: 2059 registros detectados")

for archivo_sql in os.listdir(PATH_SQL):
    if archivo_sql.endswith(".txt"):
        print(f"\nGenerando desde: {archivo_sql}")
        with open(os.path.join(PATH_SQL, archivo_sql), "r", encoding="utf-8") as f:
            for linea in f:
                datos = extraer_datos_sql(linea)
                if not datos:
                    continue

                pdf = VelvetPDFMaster()
                pdf.add_page()

                # PRODUCT SPEC SHEET
                pdf.set_xy(10, 30)
                pdf.set_font(pdf.fuente_activa, "B", 22)
                pdf.set_text_color(255, 42, 133)  # Pink
                pdf.cell(0, 10, "PRODUCT SPEC SHEET", 0, 1)

                # CARDS con Iconos
                icon_cat = ICONOS["USAGE_TYPE"].get(
                    datos["usage_type"].lower(), "icon_vibrator.png"
                )
                pdf.draw_glass_card(10, 55, 90, 90, "Vista de Producto", icon_cat)
                pdf.draw_glass_card(110, 55, 85, 90, "Vinculación QR")

                # IMAGENES (Tratamiento 8-bit)
                img_path = preparar_imagen(os.path.join(PATH_ASSETS, datos["img_file"]))
                qr_path = preparar_imagen(os.path.join(PATH_QR, datos["qr_file"]))

                if img_path:
                    pdf.image(img_path, x=15, y=68, w=80)
                if qr_path:
                    pdf.image(qr_path, x=125, y=68, w=55)

                # ESPECIFICACIONES
                pdf.draw_glass_card(10, 155, 185, 80, "Características Certificadas")
                pdf.set_xy(15, 165)
                pdf.set_font(pdf.fuente_activa, "B", 14)
                pdf.set_text_color(255, 255, 255)
                pdf.cell(100, 10, f"Modelo: {datos['model_name'].upper()}", 0, 1)

                # Info técnica adicional
                pdf.set_font(pdf.fuente_activa, "", 9)
                pdf.set_text_color(200, 200, 200)
                pdf.cell(
                    0,
                    6,
                    f"Uso: {datos['usage_type'].upper()} | Estimulación: {datos['stimulation_type']}",
                    0,
                    1,
                )
                pdf.cell(
                    0,
                    6,
                    f"Motor: {datos['motor_logic'].upper()} | Intensidad máx: {datos['max_intensity']}",
                    0,
                    1,
                )
                pdf.cell(
                    0,
                    6,
                    f"Cmd Vibración: {datos['vibration_cmd_hex']} | Cmd Thrust: {datos['thrust_cmd_hex']}",
                    0,
                    1,
                )

                # Icono de Género
                icon_gen = ICONOS["DESTINO"].get(datos["gender"].lower())
                if icon_gen:
                    path_gen = os.path.join(PATH_ENGINE, icon_gen)
                    if os.path.exists(path_gen):
                        pdf.image(path_gen, x=175, y=166, h=8)

                # LEGAL FOOTER
                pdf.set_y(-45)
                pdf.set_fill_color(26, 26, 46)
                pdf.rect(10, pdf.get_y() - 5, 190, 30, "F")
                logo_legal = os.path.join(PATH_ENGINE, "logo_velvet.png")
                if os.path.exists(logo_legal):
                    pdf.image(logo_legal, x=15, y=pdf.get_y() - 2, h=8)

                pdf.set_xy(25, pdf.get_y())
                pdf.set_font(pdf.fuente_activa, "", 7)
                pdf.set_text_color(120, 120, 140)
                pdf.multi_cell(
                    0,
                    4,
                    f"Certificado por CoreAura S.A.S. de C.V. Velvet Sync es marca registrada.\n"
                    f"ID: {datos['id']} | Fab: {datos['factory_model']} | Género: {datos['gender']} | Cert: {datos['certified_by_coreaura']}",
                    0,
                    "C",
                )

                pdf.output(os.path.join(PATH_OUTPUT, f"FICHA_{datos['id']}.pdf"))
                print(f"Generada: {datos['id']}", end="\r")

print(f"\n>>> ¡PROCESO COMPLETADO! Revisa la carpeta 'output_fichas_finales'.")
