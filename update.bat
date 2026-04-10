@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0"

echo.
echo mac-upload update
echo.

git rev-parse --show-toplevel >nul 2>&1
if errorlevel 1 (
    echo Current directory is not a git repository.
    exit /b 2
)

echo [1/4] Update mac-upload
git fetch origin
for /f %%i in ('git branch --show-current') do set CURRENT_BRANCH=%%i
if defined CURRENT_BRANCH (
    git pull --ff-only origin !CURRENT_BRANCH!
) else (
    echo Detached HEAD detected. Skip origin pull.
)
echo   OK

echo.
echo [2/4] Sync subtree upstreams
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\sync-upstreams.ps1" -Action sync -BootstrapIfNeeded
if errorlevel 1 exit /b %errorlevel%
echo   OK

echo.
echo [3/4] Refresh local Python deps
if exist "xiaolong-upload\.venv\Scripts\python.exe" (
    if exist "xiaolong-upload\requirements.txt" (
        xiaolong-upload\.venv\Scripts\python.exe -m pip install --isolated -r xiaolong-upload\requirements.txt
        if errorlevel 1 (
            echo   Warning: xiaolong-upload deps refresh failed
        ) else (
            echo   xiaolong-upload deps refreshed
        )
    ) else (
        echo   Skip xiaolong-upload deps
    )
) else (
    echo   Skip xiaolong-upload deps
)

if exist "openclaw_upload\.venv\Scripts\python.exe" (
    if exist "openclaw_upload\requirements.txt" (
        openclaw_upload\.venv\Scripts\python.exe -m pip install --isolated -r openclaw_upload\requirements.txt
        if errorlevel 1 (
            echo   Warning: openclaw_upload deps refresh failed
        ) else (
            echo   openclaw_upload deps refreshed
        )
    ) else (
        echo   Skip openclaw_upload deps
    )
) else (
    echo   Skip openclaw_upload deps
)

echo.
echo [4/4] Done
git status --short
echo.
echo Update complete.
endlocal
