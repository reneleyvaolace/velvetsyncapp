# Velvet Sync - Capturar ventana de la app
param([string]$FileName = "app_screenshot.png")

$outputDir = "screenshots"
if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Path $outputDir | Out-Null }

# Obtener proceso
$proc = Get-Process lvs_control -ErrorAction SilentlyContinue
if (-not $proc) {
    Write-Host "App no encontrada" -Red
    exit 1
}

$hwnd = $proc.MainWindowHandle
if ($hwnd -eq [IntPtr]::Zero) {
    Write-Host "Ventana no encontrada" -Red
    exit 1
}

# Usar User32 para obtener rectangulo
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@

$rect = New-Object Win32+RECT
[Win32]::GetWindowRect($hwnd, [ref]$rect) | Out-Null

$width = $rect.Right - $rect.Left
$height = $rect.Bottom - $rect.Top

if ($width -le 0 -or $height -le 0) {
    Write-Host "Ventana minimizada ($width x $height)" -Red
    Write-Host "Maximizala por favor" -Yellow
    exit 1
}

Write-Host "Ventana: $($rect.Left),$($rect.Top) - ${width}x${height}" -Green

# Capturar
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$bmp = New-Object System.Drawing.Bitmap($width, $height)
$gfx = [System.Drawing.Graphics]::FromImage($bmp)
$gfx.CopyFromScreen((New-Object System.Drawing.Point($rect.Left, $rect.Top)), 
                    [System.Drawing.Point]::Empty, 
                    $bmp.Size)

$bmp.Save("$outputDir\$FileName")
$bmp.Dispose()
$gfx.Dispose()

Write-Host "OK: $outputDir\$FileName" -Green
