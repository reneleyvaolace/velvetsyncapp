# 📸 Velvet Sync - Guía de Capturas de Pantalla

## ✅ Archivos Creados

Se han creado los siguientes archivos para facilitar la generación de capturas:

| Archivo | Propósito |
|---------|-----------|
| `lib/screens/screenshot_gallery.dart` | Galería de todas las pantallas |
| `scripts/capture_all_screens.ps1` | Script PowerShell de automatización |
| `screenshots/README.md` | Documentación completa |
| `test/screenshots.dart` | Test de integración para capturas |

## 🚀 Método Rápido (Recomendado)

### Paso 1: Activar Modo Captura

Edita `lib/main.dart` y cambia:

```dart
const bool kScreenshotMode = true;  // Cambiar a true
```

### Paso 2: Ejecutar la Aplicación

```bash
flutter run -d windows
```

### Paso 3: Usar la Galería

Verás una cuadrícula con **14 pantallas**:

| # | Pantalla | Descripción |
|---|----------|-------------|
| 1 | Splash | Pantalla de carga |
| 2 | Home | Dashboard principal |
| 3 | Control Tab | Control BLE |
| 4 | Modes Tab | Modos de juego |
| 5 | Network Tab | Servicios remotos |
| 6 | Settings | Configuración |
| 7 | Dice | Dados aleatorios |
| 8 | Roulette | Ruleta rusa |
| 9 | Reader | Lector háptico |
| 10 | Companion | IA Companion |
| 11 | Catalog | Catálogo |
| 12 | Remote | Sesión remota |
| 13 | Debug | Depuración |
| 14 | Game | Juego de frutas |

### Paso 4: Capturar

1. Haz clic en cada tarjeta
2. Presiona **`Ctrl + S`** (Windows) o **`Cmd + S`** (Mac)
3. Guarda la captura en `screenshots/`

### Paso 5: Desactivar Modo Captura

Vuelve a cambiar `kScreenshotMode = false` cuando termines.

---

## 📋 Lista de Pantallas para Capturar

### Pantallas Principales
- [ ] `00_splash.png` - Splash screen con logo neon
- [ ] `01_home.png` - Home screen (dashboard completo)

### Tabs de Navegación
- [ ] `02_control_tab.png` - Control de intensidad
- [ ] `03_modes_tab.png` - Modos y patrones
- [ ] `04_network_tab.png` - Servicios de red
- [ ] `05_settings_tab.png` - Configuración del sistema

### Juegos y Entretenimiento
- [ ] `06_dice.png` - Dados
- [ ] `07_roulette.png` - Ruleta
- [ ] `13_game.png` - Juego de frutas

### Utilidades
- [ ] `08_reader.png` - Lector de texto háptico
- [ ] `09_companion.png` - Companion con IA
- [ ] `10_catalog.png` - Catálogo de dispositivos
- [ ] `11_remote_session.png` - Control remoto
- [ ] `12_debug.png` - Consola de depuración

---

## 🛠️ Método Alternativo: PowerShell Script

```powershell
# Ejecutar script de capturas
.\scripts\capture_all_screens.ps1

# Con dispositivo específico
.\scripts\capture_all_screens.ps1 -Device emulator-5554

# Directorio personalizado
.\scripts\capture_all_screens.ps1 -OutputDir mis_capturas
```

---

## 📁 Estructura de Directorios

```
velvetsyncapp/
├── lib/
│   ├── main.dart                     # Cambiar kScreenshotMode
│   └── screens/
│       ├── screenshot_gallery.dart   # Galería de capturas
│       ├── splash_screen.dart
│       ├── home_screen.dart
│       └── ...
├── scripts/
│   └── capture_all_screens.ps1       # Script de automatización
├── screenshots/
│   ├── 00_splash.png
│   ├── 01_home.png
│   ├── ...
│   └── README.md
└── test/
    └── screenshots.dart              # Integration tests
```

---

## ⚠️ Notas Importantes

### Pantallas que requieren conexión BLE:
- **Control Tab**: Muestra estado offline si no hay dispositivo
- **Modes Tab**: Canvas y patrones deshabilitados
- **Game Screen**: Requiere conexión para enviar comandos

### Recomendaciones:
1. Usa un emulador con resolución **1080x1920** o **1440x2560**
2. Desactiva animaciones para capturas más limpias
3. Usa datos de prueba si es necesario

### Para capturas profesionales:
```bash
# Captura desde ADB (Android)
adb shell screencap -p /sdcard/screen.png
adb pull /sdcard/screen.png ./screenshots/nombre.png

# Captura desde Flutter DevTools
flutter pub global run devtools
```

---

## 🎨 Estética de las Capturas

La aplicación usa:
- **Tema oscuro** con colores neón
- **Glassmorphism** en tarjetas
- **Gradientes** rosa/violeta
- **Iconos Material** modernos

Asegúrate de capturar en modo oscuro para la mejor apariencia.

---

## 📞 Soporte

Si tienes problemas:
1. Verifica que Flutter esté instalado: `flutter doctor`
2. Asegúrate de tener un emulador corriendo
3. Revisa `screenshots/README.md` para más detalles
