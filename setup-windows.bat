@echo off
REM ============================================================
REM mac-openclaw Windows Python 环境安装脚本
REM 仅安装 Python 依赖，不安装 OpenClaw
REM ============================================================

setlocal

echo.
echo 🦐 mac-openclaw Python 环境安装
echo.

set SCRIPT_DIR=%~dp0

REM 检测 Python 3.12
echo [检测 Python 3.12]
set PYTHON_CMD=
py -3.12 --version >nul 2>&1
if %errorlevel% equ 0 (
    set PYTHON_CMD=py -3.12
    echo   ✅ Python 3.12: py -3.12
) else (
    python3.12 --version >nul 2>&1
    if %errorlevel% equ 0 (
        set PYTHON_CMD=python3.12
        echo   ✅ Python 3.12: python3.12
    ) else (
        echo   ⚠️  未找到 Python 3.12
        echo   请从 https://www.python.org/downloads/ 下载安装
        pause
        exit /b 1
    )
)

REM 安装 xiaolong-upload
echo.
echo [1/2] xiaolong-upload
cd /d "%SCRIPT_DIR%xiaolong-upload"

if not exist .venv (
    echo   创建虚拟环境...
    python -m venv .venv
)

echo   安装依赖...
.venv\Scripts\pip.exe install -r requirements.txt -q 2>nul || (
    echo   ⚠️  使用国内镜像...
    .venv\Scripts\pip.exe install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple -q
)
echo   ✅ 完成

REM 安装 openclaw_upload
echo.
echo [2/2] openclaw_upload
cd /d "%SCRIPT_DIR%openclaw_upload"

if not exist .venv (
    echo   创建虚拟环境...
    %PYTHON_CMD% -m venv .venv
)

echo   安装依赖...
.venv\Scripts\pip.exe install -r requirements.txt -q 2>nul || (
    echo   ⚠️  使用国内镜像...
    .venv\Scripts\pip.exe install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple -q
)
echo   ✅ 完成

REM 创建 output 目录
if not exist flash_longxia\output mkdir flash_longxia\output

echo.
echo ╔════════════════════════════════════════╗
echo ║  ✅ Python 环境安装完成！              ║
echo ╚════════════════════════════════════════╝
echo.
echo 使用方法:
echo   xiaolong-upload:  .venv\Scripts\python.exe upload.py ...
echo   openclaw_upload:  .venv\Scripts\python.exe flash_longxia\zhenlongxia_workflow.py ...
echo.
pause