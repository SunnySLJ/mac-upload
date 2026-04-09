@echo off
REM ============================================================
REM mac-openclaw Windows 快速更新脚本
REM 用于已安装环境，一键更新所有代码和 Skills
REM ============================================================

setlocal enabledelayedexpansion

echo.
echo 🔄 mac-openclaw 快速更新
echo.

set WORKSPACE=%USERPROFILE%\.openclaw\workspace
set SKILLS_DIR=%USERPROFILE%\.openclaw\skills

REM 更新 xiaolong-upload
echo [1/3] xiaolong-upload
if exist "%WORKSPACE%\xiaolong-upload" (
    cd /d "%WORKSPACE%\xiaolong-upload"
    if exist .git (
        git fetch origin 2>nul
        for /f %%i in ('git rev-parse HEAD') do set LOCAL=%%i
        for /f %%i in ('git rev-parse origin/main 2^>nul') do set REMOTE=%%i
        if "!LOCAL!" neq "!REMOTE!" (
            git pull origin main 2>nul || git pull origin master 2>nul
            echo   ✅ 代码已更新
        ) else (
            echo   ℹ️  已是最新版本
        )
    ) else (
        echo   ⚠️  非 git 仓库，无法更新
    )
    if exist .venv\Scripts\pip.exe (
        .venv\Scripts\pip.exe install -r requirements.txt -q 2>nul
        echo   ✅ 依赖已更新
    )
) else (
    echo   ❌ 未安装
)

REM 更新 openclaw_upload
echo.
echo [2/3] openclaw_upload
if exist "%WORKSPACE%\openclaw_upload" (
    cd /d "%WORKSPACE%\openclaw_upload"
    if exist .git (
        git fetch origin 2>nul
        for /f %%i in ('git rev-parse HEAD') do set LOCAL=%%i
        for /f %%i in ('git rev-parse origin/main 2^>nul') do set REMOTE=%%i
        if "!LOCAL!" neq "!REMOTE!" (
            git pull origin main 2>nul || git pull origin master 2>nul
            echo   ✅ 代码已更新
        ) else (
            echo   ℹ️  已是最新版本
        )
    ) else (
        echo   ⚠️  非 git 仓库，无法更新
    )
    if exist .venv\Scripts\pip.exe (
        .venv\Scripts\pip.exe install -r requirements.txt -q 2>nul
        echo   ✅ 依赖已更新
    )
) else (
    echo   ❌ 未安装
)

REM 同步 Skills
echo.
echo [3/3] Skills 同步
if not exist "%SKILLS_DIR%" mkdir "%SKILLS_DIR%"

set COUNT=0
for %%s in (auth longxia-upload video-cleanup login-monitor) do (
    if exist "%WORKSPACE%\xiaolong-upload\skills\%%s" (
        xcopy /E /I /Y /Q "%WORKSPACE%\xiaolong-upload\skills\%%s" "%SKILLS_DIR%\%%s" >nul 2>&1
        echo   ✅ %%s
        set /a COUNT+=1
    )
)
for %%s in (flash-longxia) do (
    if exist "%WORKSPACE%\openclaw_upload\skills\%%s" (
        xcopy /E /I /Y /Q "%WORKSPACE%\openclaw_upload\skills\%%s" "%SKILLS_DIR%\%%s" >nul 2>&1
        echo   ✅ %%s
        set /a COUNT+=1
    )
)

echo.
echo ╔════════════════════════════════════════╗
echo ║  ✅ 更新完成！%COUNT% 个 Skills 已同步        ║
echo ╚════════════════════════════════════════╝
pause