import os
import json
from fpdf import FPDF

# --- CONFIGURACIÓN DE RUTAS ---
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PATH_FUENTES = os.path.join(BASE_DIR, "engine", "Inter", "static")
PATH_ENGINE = os.path.join(BASE_DIR, "engine")
PATH_LOGO = os.path.join(PATH_ENGINE, "logo_velvet.png")

# --- NUEVOS ACTIVOS DE LÍNEAS NEÓN (Estilo Imagen 5) ---
PATH_LINES_TOP = os.path.join(PATH_ENGINE, "asset_lines_top.png")
PATH_LINES_BOTTOM = os.path.join(PATH_ENGINE, "asset_lines_bottom.png")

# --- PALETA LVS COLORS (Respaldo) ---
COLOR_FONDO = (5, 5, 10)       
COLOR_CARD = (26, 26, 46)      
COLOR_PINK = (255, 42, 133)    
COLOR_VIOLET = (138, 43, 226)  
COLOR_TEAL = (0, 240, 255)     
COLOR_GREEN = (0, 255, 102)    
COLOR_TEXTO = (255, 255, 255) 

# --- MAPEO DE ICONOS ---
ICONOS = {
    'CATEGORIA': {
        'bullet': 'icon_bullet.png',
        'dual motor': 'icon_dual_motor.png',
        'egg': 'icon_egg.png',
        'vibrator': 'icon_vibrator.png'
    },
    'DESTINO': {
        'hombre': 'icon_male.png',
        'mujer': 'icon_female.png',
        'universal': 'icon_universal.png'
    }
}

class VelvetPDFPremium(FPDF):
    def __init__(self):
        super().__init__()
        self.fuente_activa = 'Arial' 
        
        # Archivos Inter_18pt
        bold_font = os.path.join(PATH_FUENTES, 'Inter_18pt-Bold.ttf')
        reg_font = os.path.join(PATH_FUENTES, 'Inter_18pt-Regular.ttf')
        
        try:
            if os.path.exists(bold_font) and os.path.exists(reg_font):
                # Registro estándar compatible
                self.add_font('Inter', 'B', bold_font, uni=True)
                self.add_font('Inter', '', reg_font, uni=True)
                self.fuente_activa = 'Inter'
                print(">>> Fuentes Inter Estáticas cargadas exitosamente.")
            else:
                print(">>> Aviso: No se encontraron fuentes en engine/Inter/static. Usando Arial.")
        except Exception as e:
            print(f">>> Error al cargar fuentes: {e}")

    def header(self):
        # 1. Fondo Principal (Negro Profundo)
        self.set_fill_color(*COLOR_FONDO)
        self.rect(0, 0, 210, 297, 'F')
        
        # 2. FRANJAS SUPERIORES DE LÍNEAS (Estilo Imagen 5 - Corrección)
        # Cargamos el patrón de líneas neón desde una imagen
        if os.path.exists(PATH_LINES_TOP):
            # Posicionamos la imagen de líneas neón en el borde superior
            self.image(PATH_LINES_TOP, x=0, y=0, w=210)
        else:
            # Fallback de seguridad (bloque de color) si no existe el activo
            self.set_fill_color(*COLOR_PINK)
            self.rect(0, 0, 210, 2, 'F')
            self.set_fill_color(*COLOR_VIOLET)
            self.rect(0, 2, 210, 2, 'F')
        
        # 3. BRANDING: LOGO + TEXTO "VELVET SYNC"
        if os.path.exists(PATH_LOGO):
            self.image(PATH_LOGO, x=10, y=10, h=14)
            self.set_xy(35, 12)
            self.set_font(self.fuente_activa, 'B', 18)
            self.set_text_color(255, 255, 255)
            self.cell(0, 10, "V E L V E T  S Y N C", 0, 1, 'L')

    def footer(self):
        # FRANJAS INFERIORES DE LÍNEAS (Estilo Imagen 5 - Corrección)
        # Posicionamos al final de la página
        self.set_y(-20)
        
        # Cargamos el patrón de líneas neón desde una imagen para el footer
        if os.path.exists(PATH_LINES_BOTTOM):
            # Posicionamos la imagen de líneas neón en el borde inferior
            # Ajustamos la 'y' para que esté justo en el borde de la página
            self.image(PATH_LINES_BOTTOM, x=0, y=282, w=210) 
        else:
            # Fallback de seguridad si no existe el activo
            self.set_fill_color(*COLOR_VIOLET)
            self.rect(0, 290, 210, 2, 'F')
            self.set_fill_color(*COLOR_PINK)
            self.rect(0, 292, 210, 2, 'F')

    def draw_glass_card(self, x, y, w, h, title="", icon_name=None):
        # Efecto CardGlass
        self.set_fill_color(*COLOR_CARD)
        self.set_draw_color(255, 255, 255)
        self.set_line_width(0.1)
        self.rect(x, y, w, h, 'F')
        
        if title:
            self.set_xy(x + 5, y + 4)
            self.set_font(self.fuente_activa, 'B', 11)
            self.set_text_color(*COLOR_TEAL)
            
            # ICONO AL LADO DEL TÍTULO
            if icon_name:
                path_icon = os.path.join(PATH_ENGINE, icon_name)
                if os.path.exists(path_icon):
                    self.image(path_icon, x=x+5, y=y+3.5, h=7) 
                    self.set_x(x + 15) 

            texto_seccion = " ".join(list(title.upper()))
            self.cell(0, 5, texto_seccion, 0, 1)

def generar_ficha_final_iconos(datos):
    pdf = VelvetPDFPremium()
    pdf.add_page()
    
    # PRODUCT SPEC SHEET
    pdf.set_xy(10, 30)
    pdf.set_font(pdf.fuente_activa, 'B', 22)
    pdf.set_text_color(*COLOR_PINK)
    pdf.cell(0, 10, "PRODUCT SPEC SHEET", 0, 1)

    cat_key = datos.get('category', '').lower()
    gen_key = datos.get('gender', '').lower()
    
    # CARDS PRINCIPALES con Icono en título
    icon_cat = ICONOS['CATEGORIA'].get(cat_key)
    pdf.draw_glass_card(10, 55, 90, 90, "Vista de Producto", icon_cat)
    pdf.draw_glass_card(110, 55, 85, 90, "Vinculación QR")

    # ESPECIFICACIONES
    pdf.draw_glass_card(10, 155, 185, 80, "Características Certificadas")
    
    pdf.set_xy(15, 165)
    pdf.set_font(pdf.fuente_activa, 'B', 14)
    pdf.set_text_color(255, 255, 255)
    pdf.cell(100, 10, f"Modelo: {datos['model_name'].upper()}", 0, 0)
    
    # Icono de Género
    icon_gen = ICONOS['DESTINO'].get(gen_key)
    if icon_gen:
        path_gen = os.path.join(PATH_ENGINE, icon_gen)
        if os.path.exists(path_gen):
            pdf.image(path_gen, x=175, y=166, h=8)
    pdf.ln(10)

    # Lista de funciones
    pdf.set_font(pdf.fuente_activa, '', 11)
    y_pos = 180
    for f in ["Motor Adaptativo Neon", "Privacidad LVS Sync", "Protocolo CoreAura"]:
        pdf.set_xy(20, y_pos)
        pdf.set_text_color(*COLOR_GREEN)
        pdf.cell(10, 7, "OK", 0, 0)
        pdf.set_text_color(*COLOR_TEXTO)
        pdf.cell(0, 7, f" {f}", 0, 1)
        y_pos += 8

    # BLOQUE LEGAL (FOOTER)
    pdf.set_y(-45)
    pdf.set_fill_color(*COLOR_CARD)
    pdf.rect(10, pdf.get_y() - 5, 190, 30, 'F')
    if os.path.exists(PATH_LOGO):
        pdf.image(PATH_LOGO, x=15, y=pdf.get_y() - 2, h=8)
    
    pdf.set_xy(25, pdf.get_y())
    pdf.set_font(pdf.fuente_activa, '', 7)
    pdf.set_text_color(120, 120, 140)
    pdf.multi_cell(0, 4, (
        f"Certificado por CoreAura S.A.S. de C.V. Velvet Sync es una marca registrada.\n"
        f"ID: {datos['id']} | Fab: {datos['factory_model']}"
    ), 0, 'C')

    # SALIDA
    pdf.output("FICHA_COREAURA_FINAL_ICONOS.pdf")
    print(f"\n>>> Éxito: Archivo generado con estilo de líneas neón.")

datos_test = {
    'id': '9950',
    'model_name': 'VelSyn Neo Dual Bullet',
    'category': 'dual motor',
    'gender': 'mujer',
    'factory_model': 'LVS-B-99-DM'
}

if __name__ == "__main__":
    generar_ficha_final_iconos(datos_test)