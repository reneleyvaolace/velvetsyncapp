@echo off
REM Script para arreglar exports en archivos velvet_sync_*.dart
REM Ejecutar desde: lib/

echo ========================================
echo Arreglando exports en velvet_sync_*.dart
echo ========================================
echo.

REM Reemplazar 'src/ con ' en todos los archivos velvet_sync_*.dart
powershell -Command "Get-ChildItem -Filter 'velvet_sync_*.dart' | ForEach-Object { (Get-Content $_.FullName -Raw) -replace \"export 'src/", "export '" | Set-Content $_.FullName -NoNewline }"

echo.
echo ========================================
echo Exports arreglados
echo ========================================
echo.
echo Ahora ejecuta: dart analyze lib/
echo.
pause
