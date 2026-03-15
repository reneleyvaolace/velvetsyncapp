# Velvet Sync - Capturar solo ventana de la app
param(
    [string]$FileName = "app_screenshot.png",
    [string]$ProcessName = "lvs_control"
)

$outputDir = "screenshots"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Runtime.InteropServices

# Obtener procesos
$processes = [System.Diagnostics.Process]::GetProcessesByName($ProcessName)

if ($processes.Count -eq 0) {
    Write-Host "No se encontro la app '$ProcessName'" -ForegroundColor Red
    Write-Host "Asegurate de que la app este corriendo" -ForegroundColor Yellow
    exit 1
}

$proc = $processes[0]
$bounds = $proc.MainWindowRectangle

if ($bounds.Width -eq 0 -or $bounds.Height -eq 0) {
    Write-Host "La ventana esta minimizada o no es visible" -ForegroundColor Red
    Write-Host "Maximiza la ventana de la app" -ForegroundColor Yellow
    exit 1
}

Write-Host "Ventana encontrada: $($bounds.X), $($bounds.Y) - $($bounds.Width)x$($bounds.Height)" -ForegroundColor Green

# Crear bitmap del tamano exacto de la ventana
$bmp = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
$gfx = [System.Drawing.Graphics]::FromImage($bmp)

# Capturar solo la ventana
$gfx.CopyFromScreen(
    (New-Object System.Drawing.Point($bounds.X, $bounds.Y)),
    [System.Drawing.Point]::Empty,
    $bmp.Size
)

# Guardar
$outputPath = Join-Path $outputDir $FileName
$bmp.Save($outputPath)

# Limpiar
$bmp.Dispose()
$gfx.Dispose()

Write-Host "OK: $outputPath" -ForegroundColor Green
Write-Host "Tamano: $($bounds.Width)x$($bounds.Height) px" -ForegroundColor Gray
