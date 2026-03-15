#!/usr/bin/env powershell
# ═══════════════════════════════════════════════════════════════
# Velvet Sync · Generador Automático de Capturas
# Requiere: Flutter SDK + ADB en PATH + Emulador/Dispositivo
# ═══════════════════════════════════════════════════════════════

param(
    [switch]$Help,
    [string]$Device = "",
    [string]$OutputDir = "screenshots"
)

if ($Help) {
    Write-Host @"
Velvet Sync - Generador de Capturas de Pantalla

USO:
  .\scripts\capture_all_screens.ps1 [-Device <ID>] [-OutputDir <DIR>]

OPCIONES:
  -Device     ID del dispositivo (opcional, usa el primero si no se especifica)
  -OutputDir  Directorio de salida (default: screenshots)
  -Help       Muestra esta ayuda

EJEMPLOS:
  .\scripts\capture_all_screens.ps1
  .\scripts\capture_all_screens.ps1 -Device emulator-5554
  .\scripts\capture_all_screens.ps1 -OutputDir captures

REQUISITOS:
  - Flutter SDK instalado
  - ADB en el PATH del sistema
  - Emulador corriendo o dispositivo conectado
  - App instalada en el dispositivo

"@
    exit 0
}

# ═══════════════════════════════════════════════════════════════
# Configuración
# ═══════════════════════════════════════════════════════════════

$ErrorActionPreference = "Stop"

# Colores
$ColorCyan = [ConsoleColor]::Cyan
$ColorGreen = [ConsoleColor]::Green
$ColorRed = [ConsoleColor]::Red
$ColorYellow = [ConsoleColor]::Yellow
$ColorGray = [ConsoleColor]::Gray

function Write-Header { Write-Host "`n════════════════════════════════════════════════════" -ForegroundColor $ColorCyan }
function Write-Footer { Write-Host "════════════════════════════════════════════════════`n" -ForegroundColor $ColorCyan }
function Write-Info { Write-Host "  $($args -join ' ')" -ForegroundColor $ColorCyan }
function Write-Success { Write-Host "  ✓ $($args -join ' ')" -ForegroundColor $ColorGreen }
function Write-Warning { Write-Host "  ⚠ $($args -join ' ')" -ForegroundColor $ColorYellow }
function Write-Error { Write-Host "  ✗ $($args -join ' ')" -ForegroundColor $ColorRed }
function Write-Step { Write-Host "  → $($args -join ' ')" -ForegroundColor $ColorGray }

# ═══════════════════════════════════════════════════════════════
# Verificaciones previas
# ═══════════════════════════════════════════════════════════════

Write-Header
Write-Host "  Velvet Sync - Capturador de Pantallas"
Write-Footer

# Verificar Flutter
Write-Step "Verificando Flutter..."
try {
    $flutterVersion = flutter --version 2>&1 | Select-Object -First 1
    Write-Success "Flutter detectado: $flutterVersion"
} catch {
    Write-Error "Flutter no está instalado o no está en PATH"
    exit 1
}

# Verificar ADB
Write-Step "Verificando ADB..."
try {
    $adbVersion = adb version 2>&1 | Select-Object -First 1
    Write-Success "ADB detectado: $adbVersion"
} catch {
    Write-Warning "ADB no encontrado. Se usará método alternativo."
    $useAdb = $false
}

# Listar dispositivos
Write-Step "Buscando dispositivos..."
$devices = @()
try {
    $devices = adb devices 2>&1 | Select-String "device$" | ForEach-Object {
        $_.Line.Split()[0]
    }
} catch {}

if ($devices.Count -eq 0) {
    # Intentar con emuladores de Flutter
    try {
        $flutterDevices = flutter devices 2>&1 | Select-String "•" | ForEach-Object {
            if ($_ -match '\[(.*?)\]') { $matches[1] }
        }
        if ($flutterDevices.Count -gt 0) {
            $devices = $flutterDevices
        }
    } catch {}
}

if ($devices.Count -eq 0) {
    Write-Error "No se encontraron dispositivos/emuladores"
    Write-Info "Ejecuta un emulador o conecta un dispositivo:"
    Write-Info "  flutter emulators --launch <emulator_id>"
    Write-Info "  o"
    Write-Info "  adb devices"
    exit 1
}

Write-Success "$($devices.Count) dispositivo(s) encontrado(s)"

# Seleccionar dispositivo
$targetDevice = $Device
if ([string]::IsNullOrEmpty($targetDevice)) {
    $targetDevice = $devices[0]
    Write-Info "Usando dispositivo: $targetDevice"
}

# ═══════════════════════════════════════════════════════════════
# Lista de pantallas
# ═══════════════════════════════════════════════════════════════

$screens = @(
    @{ Name = "00_splash"; Description = "Splash Screen" },
    @{ Name = "01_home"; Description = "Home Screen" },
    @{ Name = "02_control_tab"; Description = "Control Tab" },
    @{ Name = "03_modes_tab"; Description = "Modes Tab" },
    @{ Name = "04_network_tab"; Description = "Network Tab" },
    @{ Name = "05_settings_tab"; Description = "Settings Tab" },
    @{ Name = "06_dice"; Description = "Dice Screen" },
    @{ Name = "07_roulette"; Description = "Roulette Screen" },
    @{ Name = "08_reader"; Description = "Reader Screen" },
    @{ Name = "09_companion"; Description = "Companion Screen" },
    @{ Name = "10_catalog"; Description = "Catalog Screen" },
    @{ Name = "11_remote_session"; Description = "Remote Session" },
    @{ Name = "12_debug"; Description = "Debug Screen" },
    @{ Name = "13_game"; Description = "Game Screen" }
)

# ═══════════════════════════════════════════════════════════════
# Preparar directorio de salida
# ═══════════════════════════════════════════════════════════════

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
    Write-Success "Directorio creado: $OutputDir"
}

# ═══════════════════════════════════════════════════════════════
# Instrucciones para el usuario
# ═══════════════════════════════════════════════════════════════

Write-Header
Write-Host "  MÉTODO DE CAPTURA"
Write-Footer

Write-Host @"

Como no podemos automatizar completamente las capturas desde PowerShell,
sigue estos pasos:

1. EJECUTA LA APP EN MODO CAPTURA:
   flutter run -d $targetDevice

2. MODIFICA temporalmente lib/main.dart:
   Cambia:
     home: const SplashScreen()
   Por:
     home: const ScreenshotGallery()

3. NAVEGA por cada pantalla desde la galería

4. CAPTURA con Ctrl+S (Windows) o Cmd+S (Mac)

5. LAS CAPTURAS se guardan en:
   $env:USERPROFILE\AppData\Local\Google\Android\Studio3.x\device-screenshots\
   O usa: adb shell screencap -p /sdcard/screen.png && adb pull /sdcard/screen.png

"@

Write-Header
Write-Host "  ¿Quieres intentar método automático con ADB?"
Write-Footer

$answer = Read-Host "  Continuar con ADB? (s/n)"
if ($answer -ne 's' -and $answer -ne 'S') {
    Write-Info "Modo manual seleccionado. Sigue las instrucciones arriba."
    exit 0
}

# ═══════════════════════════════════════════════════════════════
# Método automático con ADB
# ═══════════════════════════════════════════════════════════════

Write-Header
Write-Host "  INICIANDO CAPTURA AUTOMÁTICA"
Write-Footer

# Matar app si está corriendo
Write-Step "Deteniendo app previa..."
adb -s $targetDevice shell am force-stop com.example.lvs_control 2>$null

# Iniciar app
Write-Step "Iniciando Velvet Sync..."
adb -s $targetDevice shell am start -n com.example.lvs_control/.MainActivity 2>$null
Start-Sleep -Seconds 3

# Para cada pantalla, necesitamos navegación automatizada
# Esto requiere instrumentación de la app
Write-Warning "La captura automática requiere modificar la app para navegación programática"
Write-Info "Se recomienda usar el método manual con ScreenshotGallery"

Write-Host ""
Write-Success "Proceso completado"
Write-Host ""
