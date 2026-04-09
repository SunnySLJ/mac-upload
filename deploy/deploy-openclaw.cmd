@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PS1=%SCRIPT_DIR%deploy-openclaw.ps1"
set "LOG=%SCRIPT_DIR%deploy-openclaw.log"

echo [INFO] Starting deploy script...
echo [INFO] Log file: "%LOG%"
echo. > "%LOG%"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" >> "%LOG%" 2>&1
set "EXIT_CODE=%ERRORLEVEL%"

echo.
echo [INFO] Exit code: %EXIT_CODE%
echo [INFO] Log saved to: "%LOG%"
echo.

type "%LOG%"

echo.
pause
exit /b %EXIT_CODE%
