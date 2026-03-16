Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$Screen = [System.Windows.Forms.Screen]::PrimaryScreen
$Bitmap = New-Object System.Drawing.Bitmap -ArgumentList $Screen.Bounds.Width, $Screen.Bounds.Height
$Graphics = [System.Drawing.Graphics]::FromImage($Bitmap)
$Graphics.CopyFromScreen($Screen.Bounds.Left, $Screen.Bounds.Top, 0, 0, $Bitmap.Size)
$Bitmap.Save('C:\Users\renel\.gemini\antigravity\brain\b7af1595-bbaa-40a3-b534-d82b9447d536\direct_windows_capture.png', [System.Drawing.Imaging.ImageFormat]::Png)
$Graphics.Dispose()
$Bitmap.Dispose()
Write-Host "Screenshot success"
