@echo off
cd /d "%~dp0"
echo Carpeta actual: %cd%
echo Buscando Python...
py --version
echo.
echo Generando PDFs de fichas...
py velvet_pdf_generator.py
echo.
echo El proceso ha terminado.
pause
