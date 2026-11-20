@echo off
rem Instala o MineServer no Windows. A logica fica em instalar.ps1 e acompanha o instalar.sh.
rem Na segunda execucao, instalar.ps1 consulta o GitHub e traz a versao nova antes de instalar.
chcp 65001 >nul
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar.ps1"
echo.
pause
