Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$Screen = [System.Windows.Forms.Screen]::PrimaryScreen
$Width  = $Screen.Bounds.Width
$Height = $Screen.Bounds.Height
$Left   = $Screen.Bounds.Left
$Top    = $Screen.Bounds.Top

$Bitmap = New-Object System.Drawing.Bitmap -ArgumentList $Width, $Height
$Graphics = [System.Drawing.Graphics]::FromImage($Bitmap)

$Graphics.CopyFromScreen($Left, $Top, 0, 0, $Bitmap.Size)

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$OutputFile = "C:\Users\renel\.gemini\antigravity\brain\07c21e51-6f3d-4bb7-b0c8-66931449dd5d\desktop_screenshot_$Timestamp.png"

$Bitmap.Save($OutputFile, [System.Drawing.Imaging.ImageFormat]::Png)

$Graphics.Dispose()
$Bitmap.Dispose()

Write-Host "Screenshot saved to $OutputFile"
