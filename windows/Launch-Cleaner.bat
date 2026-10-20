@echo off
REM PC Cleaner - Lanzador con auto-elevacion a Administrador
REM Uso: doble clic, o: Launch-Cleaner.bat Avanzado | Completo | Rapido

setlocal
set MODE=%1
if "%MODE%"=="" set MODE=Completo

NET SESSION >nul 2>&1
if %errorlevel% neq 0 (
    echo Solicitando permisos de Administrador...
    powershell -NoProfile -Command "Start-Process '%~f0' -ArgumentList '%MODE%' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"
echo ===========================================
echo  PC CLEANER - Modo %MODE%
echo ===========================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Cleaner.ps1" -Mode %MODE%

echo.
pause
endlocal
