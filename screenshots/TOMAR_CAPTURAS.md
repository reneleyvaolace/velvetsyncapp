# 📸 Guía para Tomar Capturas de Pantalla - Velvet Sync

## Estado Actual

Capturas tomadas:
- ✅ `00_splash_gallery.png` - Galería de capturas
- ✅ `01_gallery_view.png` - Vista de galería
- ✅ `01_home_screen.png` - Home screen

## 🎯 Instrucciones Paso a Paso

### Paso 1: Navegar a cada pantalla

Con la app corriendo en modo galería (`kScreenshotMode = true`):

1. **Haz clic en cada tarjeta** de la galería para abrir esa pantalla
2. **Espera 2 segundos** a que cargue completamente
3. **Ejecuta el comando** para tomar la captura

### Paso 2: Tomar captura de cada pantalla

Usa uno de estos métodos:

#### Método A: Script PowerShell (Recomendado)
```powershell
# Ejecuta este comando después de abrir cada pantalla:
.\scripts\take_screenshot.ps1 -FileName "02_control_tab.png"
```

#### Método B: Atajo de Teclado Windows
```
Presiona: Win + Shift + S
Selecciona: Rectangular Snip
Guarda en: screenshots\02_control_tab.png
```

### Paso 3: Lista de Capturas a Tomar

Navega en orden y toma capturas de:

| # | Pantalla | Comando |
|---|----------|---------|
| 1 | Splash/Galería | ✅ Ya tomada |
| 2 | Home Screen | ✅ Ya tomada |
| 3 | Control Tab | `.\scripts\take_screenshot.ps1 -FileName "02_control_tab.png"` |
| 4 | Modes Tab | `.\scripts\take_screenshot.ps1 -FileName "03_modes_tab.png"` |
| 5 | Network Tab | `.\scripts\take_screenshot.ps1 -FileName "04_network_tab.png"` |
| 6 | Settings Tab | `.\scripts\take_screenshot.ps1 -FileName "05_settings_tab.png"` |
| 7 | Dice Screen | `.\scripts\take_screenshot.ps1 -FileName "06_dice.png"` |
| 8 | Roulette Screen | `.\scripts\take_screenshot.ps1 -FileName "07_roulette.png"` |
| 9 | Reader Screen | `.\scripts\take_screenshot.ps1 -FileName "08_reader.png"` |
| 10 | Companion Screen | `.\scripts\take_screenshot.ps1 -FileName "09_companion.png"` |
| 11 | Catalog Screen | `.\scripts\take_screenshot.ps1 -FileName "10_catalog.png"` |
| 12 | Remote Session | `.\scripts\take_screenshot.ps1 -FileName "11_remote_session.png"` |
| 13 | Debug Screen | `.\scripts\take_screenshot.ps1 -FileName "12_debug.png"` |
| 14 | Game Screen | `.\scripts\take_screenshot.ps1 -FileName "13_game.png"` |

### Paso 4: Verificar capturas

```powershell
# Ver todas las capturas tomadas
dir screenshots\*.png

# O usa el script para ver la lista completa
.\scripts\take_screenshot.ps1 -FullList
```

---

## 🔄 Para cambiar entre pantallas

### Desde la Galería:
1. Abre la app (verás la galería con todas las pantallas)
2. Haz clic en la tarjeta de la pantalla deseada
3. Toma la captura
4. Presiona "Atrás" para volver a la galería
5. Repite con la siguiente

### Desde la App Normal:
1. Cambia `kScreenshotMode = false` en `lib/main.dart`
2. Navega normalmente por la app
3. Usa Win+Shift+S para capturar

---

## 💡 Tips para Mejores Capturas

1. **Pantalla completa**: Maximiza la ventana de la app (Win + Flecha arriba)
2. **Sin distracciones**: Cierra otras ventanas
3. **Espera la carga**: Algunos screens necesitan 1-2 segundos para cargar datos
4. **Modo oscuro**: Asegúrate de que Windows esté en modo oscuro para mejor apariencia

---

## 📁 Estructura Final Esperada

```
screenshots/
├── 00_splash_gallery.png    ✅
├── 01_home_screen.png       ✅
├── 01_gallery_view.png      ✅
├── 02_control_tab.png       ⬜
├── 03_modes_tab.png         ⬜
├── 04_network_tab.png       ⬜
├── 05_settings_tab.png      ⬜
├── 06_dice.png              ⬜
├── 07_roulette.png          ⬜
├── 08_reader.png            ⬜
├── 09_companion.png         ⬜
├── 10_catalog.png           ⬜
├── 11_remote_session.png    ⬜
├── 12_debug.png             ⬜
└── 13_game.png              ⬜
```

---

## 🚀 Comandos Útiles

```powershell
# Tomar captura con delay de 3 segundos (útil para abrir menús)
.\scripts\take_screenshot.ps1 -FileName "nombre.png" -Delay 3

# Ver lista completa de capturas sugeridas
.\scripts\take_screenshot.ps1 -FullList

# Contar capturas tomadas
(dir screenshots\*.png).Count
```

---

## ⚠️ Importante

Cuando termines de tomar todas las capturas:

1. **Cambia `kScreenshotMode = false`** en `lib/main.dart`
2. **Reinicia la app** para volver al modo normal
3. **Organiza las capturas** en la carpeta `screenshots/`

---

## 📞 Si hay problemas

- **La app no muestra la galería**: Verifica que `kScreenshotMode = true`
- **Error al tomar captura**: Ejecuta PowerShell como administrador
- **Pantalla en blanco**: Espera más tiempo para que cargue la pantalla
- **Datos faltantes**: Conecta un dispositivo BLE o usa modo virtual
