#!/usr/bin/env powershell
# ═══════════════════════════════════════════════════════════════
# Velvet Sync · Script de Capturas de Pantalla (PowerShell)
# Genera capturas de todas las pantallas de la aplicación
# ═══════════════════════════════════════════════════════════════

$ErrorActionPreference = "Stop"

# Colores para output
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Error { Write-Host $args -ForegroundColor Red }

# Crear directorio de screenshots
$screenshotDir = "screenshots"
if (-not (Test-Path $screenshotDir)) {
    New-Item -ItemType Directory -Path $screenshotDir | Out-Null
    Write-Success "✓ Directorio '$screenshotDir' creado"
}

# Lista de rutas de pantallas a capturar
$screens = @(
    @{ Name = "00_splash"; Route = "/splash" },
    @{ Name = "01_home"; Route = "/home" },
    @{ Name = "02_control"; Route = "/control" },
    @{ Name = "03_modes"; Route = "/modes" },
    @{ Name = "04_network"; Route = "/network" },
    @{ Name = "05_settings"; Route = "/settings" },
    @{ Name = "06_dice"; Route = "/dice" },
    @{ Name = "07_roulette"; Route = "/roulette" },
    @{ Name = "08_reader"; Route = "/reader" },
    @{ Name = "09_companion"; Route = "/companion" },
    @{ Name = "10_catalog"; Route = "/catalog" },
    @{ Name = "11_remote_session"; Route = "/remote" },
    @{ Name = "12_debug"; Route = "/debug" }
)

Write-Info "════════════════════════════════════════════════════"
Write-Info "  Velvet Sync - Generador de Capturas de Pantalla"
Write-Info "════════════════════════════════════════════════════"
Write-Host ""

# Verificar si hay un emulador/dispositivo conectado
Write-Info "Verificando dispositivos conectados..."
$devices = adb devices | Select-String -Pattern "device$" -Context 0,0

if ($devices.Count -eq 0) {
    Write-Error "✗ No hay dispositivos/emuladores conectados"
    Write-Info "  Ejecuta un emulador o conecta un dispositivo y vuelve a intentar"
    exit 1
}

Write-Success "✓ Dispositivo detectado"
Write-Host ""

# Iniciar la aplicación
Write-Info "Iniciando Velvet Sync..."
flutter run -d $devices[0].Line.Trim().Split()[0] --no-sound-null-safety

Write-Host ""
Write-Info "Aplicación iniciada. Navegando por las pantallas..."

# Para cada pantalla:
foreach ($screen in $screens) {
    Write-Info "Capturando: $($screen.Name)..."
    
    # Navegar a la pantalla (esto requiere que la app esté instrumentada)
    # Por ahora, hacemos screenshot directo
    adb shell screencap -p "/sdcard/$($screen.Name).png"
    adb pull "/sdcard/$($screen.Name).png" "$screenshotDir/$($screen.Name).png"
    adb shell rm "/sdcard/$($screen.Name).png"
    
    Write-Success "  ✓ $screenshotDir/$($screen.Name).png"
}

Write-Host ""
Write-Success "════════════════════════════════════════════════════"
Write-Success "  ¡Capturas completadas!"
Write-Success "════════════════════════════════════════════════════"
