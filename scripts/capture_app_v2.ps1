# Velvet Sync - Capturar ventana usando Win32 API
param(
    [string]$FileName = "app_screenshot.png"
)

$outputDir = "screenshots"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Drawing;
using System.Drawing.Imaging;

public class Screenshot {
    [DllImport("user32.dll")]
    public static extern IntPtr FindWindow(string className, string windowTitle);
    
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hwnd, out RECT lpRect);
    
    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hWnd, IntPtr hDC, int nFlags);
    
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }
    
    public static bool CaptureWindow(string windowTitle, string outputPath) {
        IntPtr hwnd = FindWindow(null, windowTitle);
        if (hwnd == IntPtr.Zero) {
            Console.WriteLine("Ventana no encontrada: " + windowTitle);
            return false;
        }
        
        RECT rect;
        GetWindowRect(hwnd, out rect);
        int width = rect.Right - rect.Left;
        int height = rect.Bottom - rect.Top;
        
        if (width <= 0 || height <= 0) {
            Console.WriteLine("Ventana minimizada o invalida");
            return false;
        }
        
        Bitmap bmp = new Bitmap(width, height);
        Graphics gfx = Graphics.FromImage(bmp);
        IntPtr hdc = gfx.GetHdc();
        PrintWindow(hwnd, hdc, 0);
        gfx.ReleaseHdc(hdc);
        
        bmp.Save(outputPath, ImageFormat.Png);
        bmp.Dispose();
        gfx.Dispose();
        
        Console.WriteLine("OK: " + outputPath);
        Console.WriteLine("Size: " + width + "x" + height);
        return true;
    }
}
"@

# Buscar ventana de Velvet Sync
$titles = @("Velvet Sync", "lvs_control", "Love Spouse")
$found = $false

foreach ($title in $titles) {
    if ([Screenshot]::CaptureWindow($title, "$outputDir\$FileName")) {
        $found = $true
        break
    }
}

if (-not $found) {
    Write-Host "No se encontro ninguna ventana de Velvet Sync" -ForegroundColor Red
    Write-Host "Titulos buscados: $($titles -join ', ')" -ForegroundColor Yellow
    exit 1
}
