# Velvet Sync - Guía de Capturas de Pantalla

## Pantallas Identificadas

La aplicación Velvet Sync tiene las siguientes pantallas:

### Pantallas Principales
| # | Pantalla | Archivo | Descripción |
|---|----------|---------|-------------|
| 1 | Splash Screen | `lib/screens/splash_screen.dart` | Pantalla de carga con logo neon |
| 2 | Home Screen | `lib/screens/home_screen.dart` | Dashboard principal con todas las funciones |
| 3 | Main Navigation | `lib/screens/main_navigation.dart` | Navegación con bottom navigation bar |

### Tabs (Navegación Principal)
| # | Tab | Archivo | Descripción |
|---|-----|---------|-------------|
| 4 | Control Tab | `lib/screens/tabs/control_tab.dart` | Control de intensidad, conexión BLE |
| 5 | Modes Tab | `lib/screens/tabs/modes_tab.dart` | Modos de juego y patrones |
| 6 | Network Tab | `lib/screens/tabs/network_tab.dart` | Sesión remota y catálogo |
| 7 | Settings Tab | `lib/screens/tabs/settings_tab.dart` | Configuración del sistema |

### Pantallas de Juegos
| # | Pantalla | Archivo | Descripción |
|---|----------|---------|-------------|
| 8 | Game Screen | `lib/screens/game_screen.dart` | Juego de frutas (Flame engine) |
| 9 | Dice Screen | `lib/screens/dice_screen.dart` | Dados aleatorios |
| 10 | Roulette Screen | `lib/screens/roulette_screen.dart` | Ruleta rusa |
| 11 | Reader Screen | `lib/screens/reader_screen.dart` | Lector háptico de texto |
| 12 | Companion Screen | `lib/screens/companion_screen.dart` | Companion con IA |

### Otras Pantallas
| # | Pantalla | Archivo | Descripción |
|---|----------|---------|-------------|
| 13 | Catalog Screen | `lib/screens/catalog_screen.dart` | Catálogo de dispositivos |
| 14 | Remote Session Screen | `lib/screens/remote_session_screen.dart` | Control remoto |
| 15 | Debug Screen | `lib/screens/debug_screen.dart` | Consola de depuración |

---

## Método 1: Capturas Manuales (Recomendado)

1. **Inicia la aplicación en un emulador o dispositivo:**
   ```bash
   flutter run
   ```

2. **Navega a cada pantalla** usando la interfaz de la aplicación

3. **Captura la pantalla** con uno de estos métodos:

   **Opción A - Desde el emulador:**
   - Presiona `Ctrl + S` (Windows/Linux) o `Cmd + S` (Mac)
   
   **Opción B - Usando ADB:**
   ```bash
   adb shell screencap -p /sdcard/screenshot.png
   adb pull /sdcard/screenshot.png ./screenshots/nombre_pantalla.png
   ```

   **Opción C - Desde Flutter DevTools:**
   - Abre DevTools (`flutter pub global run devtools`)
   - Ve a la pestaña "Inspector"
   - Haz clic en "Screenshot"

---

## Método 2: Capturas Automatizadas

### Requisitos
- Emulador o dispositivo conectado
- Flutter SDK instalado

### Pasos

1. **Ejecuta los tests de screenshot:**
   ```bash
   flutter test integration_test/screenshots_test.dart
   ```

2. **Las capturas se guardarán en:** `screenshots/`

---

## Método 3: Script PowerShell (Windows)

```powershell
# Ejecuta el script de capturas
.\screenshots\capture_screenshots.ps1
```

---

## Estructura de Directorios de Capturas

```
screenshots/
├── 00_splash.png
├── 01_home.png
├── 02_control_tab.png
├── 03_modes_tab.png
├── 04_network_tab.png
├── 05_settings_tab.png
├── 06_dice_screen.png
├── 07_roulette_screen.png
├── 08_reader_screen.png
├── 09_companion_screen.png
├── 10_catalog_screen.png
├── 11_remote_session_screen.png
├── 12_debug_screen.png
└── README.md
```

---

## Notas Importantes

⚠️ **Algunas pantallas requieren:**
- **Control/Modes Tabs**: Dispositivo BLE conectado
- **Game Screen**: Conexión activa para enviar comandos
- **Remote Session**: Token de sesión válido
- **Catalog**: Datos cargados desde Supabase

💡 **Recomendación**: Para capturas limpias, considera:
1. Usar datos de prueba/mock
2. Desactivar animaciones durante capturas
3. Usar un emulador con resolución fija (ej. 1080x1920)
