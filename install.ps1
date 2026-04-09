# ============================================================
# mac-openclaw Windows 一键部署脚本 (PowerShell)
# 支持: 全新安装 + 智能更新
# ============================================================

param(
    [switch]$Update,
    [switch]$PythonOnly
)

$ErrorActionPreference = "Stop"

# 颜色函数
function Write-Ok { param($msg) Write-Host "  ✅ $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "  ⚠️  $msg" -ForegroundColor Yellow }
function Write-Fail { param($msg) Write-Host "  ❌ $msg" -ForegroundColor Red }
function Write-Info { param($msg) Write-Host "  ℹ️  $msg" -ForegroundColor Cyan }

# 全局变量
$OPENCLAW_DIR = "$env:USERPROFILE\.openclaw"
$WORKSPACE_DIR = "$OPENCLAW_DIR\workspace"
$SKILLS_DIR = "$OPENCLAW_DIR\skills"
$PROJECT_ROOT = $PSScriptRoot
$OPENCLAW_VERSION = "2026.3.28"
$PYTHON_CMD = ""

# 检测安装状态
function Test-Installation {
    Write-Host ""
    Write-Host "🔍 检测安装状态..." -ForegroundColor Cyan

    $openclawInstalled = Get-Command openclaw -ErrorAction SilentlyContinue
    $xiaolongInstalled = Test-Path "$WORKSPACE_DIR\xiaolong-upload"
    $openclawUploadInstalled = Test-Path "$WORKSPACE_DIR\openclaw_upload"

    if ($openclawInstalled) {
        Write-Info "OpenClaw: 已安装"
    } else {
        Write-Info "OpenClaw: 未安装"
    }

    if ($xiaolongInstalled) {
        Write-Info "xiaolong-upload: 已安装"
    } else {
        Write-Info "xiaolong-upload: 未安装"
    }

    if ($openclawUploadInstalled) {
        Write-Info "openclaw_upload: 已安装"
    } else {
        Write-Info "openclaw_upload: 未安装"
    }

    return @{
        OpenClaw = $openclawInstalled
        Xiaolong = $xiaolongInstalled
        OpenclawUpload = $openclawUploadInstalled
    }
}

# 步骤 1: 系统环境检查
function Step-SystemCheck {
    Write-Host ""
    Write-Host "[1/6] 系统环境检查" -ForegroundColor Yellow

    # Node.js
    $node = Get-Command node -ErrorAction SilentlyContinue
    if ($node) {
        Write-Ok "Node.js: $(node -v)"
    } else {
        Write-Fail "未安装 Node.js"
        Write-Info "下载: https://nodejs.org/"
        exit 1
    }

    # Git
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        Write-Ok "Git: $(git --version)"
    } else {
        Write-Fail "未安装 Git"
        Write-Info "下载: https://git-scm.com/"
        exit 1
    }

    Write-Ok "Windows 环境"
}

# 步骤 2: Python 环境
function Step-Python {
    Write-Host ""
    Write-Host "[2/6] Python 环境" -ForegroundColor Yellow

    # 查找 Python 3.12
    $pythonCmds = @("py -3.12", "python3.12", "python")

    foreach ($cmd in $pythonCmds) {
        try {
            $result = Invoke-Expression "$cmd --version" 2>$null
            if ($result -match "3\.12") {
                $PYTHON_CMD = $cmd
                Write-Ok "Python 3.12: $cmd"
                return $cmd
            }
        } catch {}
    }

    # 尝试安装 Python 3.12
    Write-Warn "未找到 Python 3.12"
    $install = Read-Host "  是否安装 Python 3.12？(Y/n)"
    if ($install -ne "n") {
        Write-Info "请从 https://www.python.org/downloads/ 下载 Python 3.12"
        exit 1
    } else {
        Write-Fail "Python 3.12 是必需的"
        exit 1
    }
}

# 步骤 3: 安装/更新 OpenClaw
function Step-OpenClaw {
    Write-Host ""
    Write-Host "[3/6] OpenClaw" -ForegroundColor Yellow

    $openclaw = Get-Command openclaw -ErrorAction SilentlyContinue

    if ($openclaw) {
        $version = openclaw --version 2>$null
        Write-Ok "当前版本: $version"

        $update = Read-Host "  是否更新到 $OPENCLAW_VERSION？(Y/n)"
        if ($update -ne "n") {
            npm install -g "openclaw@$OPENCLAW_VERSION"
            Write-Ok "已更新到 $OPENCLAW_VERSION"
        }
    } else {
        Write-Info "安装 OpenClaw $OPENCLAW_VERSION..."
        npm install -g "openclaw@$OPENCLAW_VERSION"
        Write-Ok "OpenClaw $OPENCLAW_VERSION 已安装"
    }

    # 创建目录
    New-Item -ItemType Directory -Force -Path $OPENCLAW_DIR | Out-Null
    New-Item -ItemType Directory -Force -Path $WORKSPACE_DIR | Out-Null
    New-Item -ItemType Directory -Force -Path $SKILLS_DIR | Out-Null
    New-Item -ItemType Directory -Force -Path "$WORKSPACE_DIR\inbound_images" | Out-Null
    New-Item -ItemType Directory -Force -Path "$WORKSPACE_DIR\logs\auth_qr" | Out-Null
}

# 步骤 4: 安装/更新 xiaolong-upload
function Step-XiaolongUpload {
    param($PythonCmd)

    Write-Host ""
    Write-Host "[4/6] xiaolong-upload (四平台视频上传)" -ForegroundColor Yellow

    $target = "$WORKSPACE_DIR\xiaolong-upload"

    if (Test-Path $target) {
        Write-Ok "已存在于 $target"

        if (Test-Path "$target\.git") {
            $pull = Read-Host "  是否拉取最新代码？(Y/n)"
            if ($pull -ne "n") {
                Push-Location $target
                git pull origin main 2>$null
                if ($LASTEXITCODE -ne 0) { git pull origin master 2>$null }
                Pop-Location
                Write-Ok "代码已更新"
            }
        }
    } else {
        Write-Info "从本地项目复制..."
        if (Test-Path "$PROJECT_ROOT\xiaolong-upload") {
            Copy-Item -Recurse "$PROJECT_ROOT\xiaolong-upload" $target
            Write-Ok "已复制到 $target"
        } else {
            Write-Fail "找不到 xiaolong-upload 目录"
            exit 1
        }
    }

    # 安装 Python 依赖
    if (Test-Path "$target\requirements.txt") {
        Write-Info "安装 Python 依赖..."
        Push-Location $target

        if (-not (Test-Path ".venv")) {
            python -m venv .venv
        }

        .\.venv\Scripts\pip.exe install -r requirements.txt -q
        Write-Ok "Python 依赖已安装"
        Pop-Location
    }
}

# 步骤 5: 安装/更新 openclaw_upload
function Step-OpenclawUpload {
    param($PythonCmd)

    Write-Host ""
    Write-Host "[5/6] openclaw_upload (帧龙虾图生视频)" -ForegroundColor Yellow

    $target = "$WORKSPACE_DIR\openclaw_upload"

    if (Test-Path $target) {
        Write-Ok "已存在于 $target"

        if (Test-Path "$target\.git") {
            $pull = Read-Host "  是否拉取最新代码？(Y/n)"
            if ($pull -ne "n") {
                Push-Location $target
                git pull origin main 2>$null
                if ($LASTEXITCODE -ne 0) { git pull origin master 2>$null }
                Pop-Location
                Write-Ok "代码已更新"
            }
        }
    } else {
        Write-Info "从本地项目复制..."
        if (Test-Path "$PROJECT_ROOT\openclaw_upload") {
            Copy-Item -Recurse "$PROJECT_ROOT\openclaw_upload" $target
            Write-Ok "已复制到 $target"
        } else {
            Write-Fail "找不到 openclaw_upload 目录"
            exit 1
        }
    }

    # 安装 Python 依赖
    if (Test-Path "$target\requirements.txt") {
        Write-Info "安装 Python 依赖..."
        Push-Location $target

        if (-not (Test-Path ".venv")) {
            & $PythonCmd -m venv .venv
        }

        .\.venv\Scripts\pip.exe install -r requirements.txt -q
        Write-Ok "Python 依赖已安装"
        Pop-Location
    }

    # 创建 output 目录
    New-Item -ItemType Directory -Force -Path "$target\flash_longxia\output" | Out-Null
}

# 步骤 6: 同步 Skills
function Step-Skills {
    Write-Host ""
    Write-Host "[6/6] Skills 同步" -ForegroundColor Yellow

    # 从 xiaolong-upload 同步
    $xiaolongSkills = "$WORKSPACE_DIR\xiaolong-upload\skills"
    if (Test-Path $xiaolongSkills) {
        @("auth", "longxia-upload", "video-cleanup", "login-monitor") | ForEach-Object {
            $skill = $_
            if (Test-Path "$xiaolongSkills\$skill") {
                Copy-Item -Recurse -Force "$xiaolongSkills\$skill" "$SKILLS_DIR\$skill"
                Write-Ok "Skill [$skill]"
            }
        }
    }

    # 从 openclaw_upload 同步
    $openclawSkills = "$WORKSPACE_DIR\openclaw_upload\skills"
    if (Test-Path $openclawSkills) {
        @("flash-longxia") | ForEach-Object {
            $skill = $_
            if (Test-Path "$openclawSkills\$skill") {
                Copy-Item -Recurse -Force "$openclawSkills\$skill" "$SKILLS_DIR\$skill"
                Write-Ok "Skill [$skill]"
            }
        }
    }

    # 从 deploy/skills 同步
    if (Test-Path "$PROJECT_ROOT\deploy\skills") {
        @("longxia-bootstrap", "repo-sync") | ForEach-Object {
            $skill = $_
            if (Test-Path "$PROJECT_ROOT\deploy\skills\$skill") {
                Copy-Item -Recurse -Force "$PROJECT_ROOT\deploy\skills\$skill" "$SKILLS_DIR\$skill"
                Write-Ok "Skill [$skill]"
            }
        }
    }
}

# 同步 Workspace 配置
function Sync-WorkspaceConfig {
    Write-Host ""
    Write-Host "📋 Workspace 配置" -ForegroundColor Yellow

    $wsSrc = "$PROJECT_ROOT\deploy\workspace"

    if (Test-Path $wsSrc) {
        @("AGENTS.md", "IDENTITY.md", "SOUL.md", "USER.md", "MEMORY.md", "HEARTBEAT.md", "TOOLS.md") | ForEach-Object {
            $f = $_
            if ((Test-Path "$wsSrc\$f") -and (-not (Test-Path "$WORKSPACE_DIR\$f"))) {
                Copy-Item "$wsSrc\$f" "$WORKSPACE_DIR\$f"
                Write-Ok "$f 已复制"
            } elseif (Test-Path "$wsSrc\$f") {
                Write-Warn "$f 已存在，跳过"
            }
        }
    }
}

# 创建更新脚本
function New-UpdateScript {
    $updateScript = @'
@echo off
REM mac-openclaw 快速更新脚本 (Windows)

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
        git pull origin main 2>nul || git pull origin master 2>nul
        echo   ✅ 代码已更新
    )
    if exist .venv\Scripts\pip.exe (
        .venv\Scripts\pip.exe install -r requirements.txt -q
        echo   ✅ 依赖已更新
    )
)

REM 更新 openclaw_upload
echo.
echo [2/3] openclaw_upload
if exist "%WORKSPACE%\openclaw_upload" (
    cd /d "%WORKSPACE%\openclaw_upload"
    if exist .git (
        git pull origin main 2>nul || git pull origin master 2>nul
        echo   ✅ 代码已更新
    )
    if exist .venv\Scripts\pip.exe (
        .venv\Scripts\pip.exe install -r requirements.txt -q
        echo   ✅ 依赖已更新
    )
)

REM 同步 Skills
echo.
echo [3/3] Skills 同步
xcopy /E /I /Y /Q "%WORKSPACE%\xiaolong-upload\skills\*" "%SKILLS_DIR%\" >nul 2>&1
xcopy /E /I /Y /Q "%WORKSPACE%\openclaw_upload\skills\*" "%SKILLS_DIR%\" >nul 2>&1
echo   ✅ Skills 已同步

echo.
echo ✅ 更新完成！
pause
'@

    $updateScript | Out-File -FilePath "$WORKSPACE_DIR\update-all.bat" -Encoding ASCII
    Write-Ok "update-all.bat 已创建"
}

# 最终验证
function Test-Deployment {
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host "验证安装结果" -ForegroundColor Yellow
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue

    $allOk = $true

    # 检查 OpenClaw
    if (Get-Command openclaw -ErrorAction SilentlyContinue) {
        Write-Ok "OpenClaw: 已安装"
    } else {
        Write-Fail "OpenClaw: 未安装"
        $allOk = $false
    }

    # 检查项目目录
    if (Test-Path "$WORKSPACE_DIR\xiaolong-upload") {
        Write-Ok "xiaolong-upload: ✓"
    } else {
        Write-Fail "xiaolong-upload: 缺失"
        $allOk = $false
    }

    if (Test-Path "$WORKSPACE_DIR\openclaw_upload") {
        Write-Ok "openclaw_upload: ✓"
    } else {
        Write-Fail "openclaw_upload: 缺失"
        $allOk = $false
    }

    # 检查 Skills
    $skillCount = (Get-ChildItem $SKILLS_DIR -Directory -ErrorAction SilentlyContinue).Count
    Write-Ok "Skills: $skillCount 个已安装"

    Write-Host ""
    if ($allOk) {
        Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║  🎉 安装/更新完成！                              ║" -ForegroundColor Green
        Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Green
    } else {
        Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Yellow
        Write-Host "║  ⚠️  有部分问题，请检查                          ║" -ForegroundColor Yellow
        Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "📋 后续操作：" -ForegroundColor Yellow
    Write-Host "  1. 启动 OpenClaw:    openclaw"
    Write-Host "  2. 绑定微信:         openclaw channel connect openclaw-weixin"
    Write-Host "  3. 更新代码:         $WORKSPACE_DIR\update-all.bat"
    Write-Host ""
    Write-Host "  工作区: $WORKSPACE_DIR" -ForegroundColor Cyan
}

# 主函数
function Main {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  🦐 mac-openclaw 一键部署脚本 (Windows)          ║" -ForegroundColor Cyan
    Write-Host "║  OpenClaw + 四平台上传 + 图生视频                 ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan

    if ($PythonOnly) {
        Step-SystemCheck
        $pythonCmd = Step-Python
        Step-XiaolongUpload $pythonCmd
        Step-OpenclawUpload $pythonCmd
        return
    }

    if ($Update) {
        $pythonCmd = Step-Python
        Step-XiaolongUpload $pythonCmd
        Step-OpenclawUpload $pythonCmd
        Step-Skills
        Test-Deployment
        return
    }

    # 检测安装状态
    $status = Test-Installation

    # 执行安装步骤
    Step-SystemCheck
    $pythonCmd = Step-Python
    Step-OpenClaw
    Step-XiaolongUpload $pythonCmd
    Step-OpenclawUpload $pythonCmd
    Step-Skills
    Sync-WorkspaceConfig
    New-UpdateScript
    Test-Deployment
}

Main