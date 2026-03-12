@echo off
cd /d "%~dp0"
echo Carpeta actual: %cd%
echo Buscando Python...
py --version
echo.
echo Intentando arrancar el motor...
py engine/main_velvet.py
echo.
echo El script ha terminado o fallado.
pause