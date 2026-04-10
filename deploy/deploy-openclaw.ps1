#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$NoElevate,
    [switch]$NonInteractive
)

$ErrorActionPreference = "Stop"

$script:DeployVersion = "3.0.1"
$script:OpenClawPackage = "openclaw@latest"
$script:OpenClawRoot = Join-Path $env:USERPROFILE ".openclaw"
$script:WorkspaceRoot = Join-Path $script:OpenClawRoot "workspace"
$script:SkillsRoot = Join-Path $script:OpenClawRoot "skills"
$script:DeployRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:PythonExe = $null
$script:PythonArgs = @()
$script:InstallMemoryPlugin = $false
$script:InstallContextPlugin = $false
$script:InstalledOpenClawVersion = "unknown"
$script:Profile = [ordered]@{
    UserName = "user"
    Industry = "general"
    VideoStyle = "general"
    AssistantName = "xiawang"
    AssistantTone = "direct and reliable"
    ConfirmBeforePublish = "true"
    SoulStyle = "steady"
    WechatTarget = ""
    FeishuEnabled = $false
    FeishuAppId = ""
    FeishuAppSecret = ""
    ApiKey = "{{YOUR_API_KEY}}"
}

function Write-Title([string]$Text) {
    Write-Host ""
    Write-Host $Text -ForegroundColor Cyan
}

function Write-Info([string]$Text) {
    Write-Host ("[INFO] {0}" -f $Text) -ForegroundColor Cyan
}

function Write-Ok([string]$Text) {
    Write-Host ("[OK] {0}" -f $Text) -ForegroundColor Green
}

function Write-Warn([string]$Text) {
    Write-Host ("[WARN] {0}" -f $Text) -ForegroundColor Yellow
}

function Fail([string]$Text) {
    throw $Text
}

function Ask-YesNo([string]$Prompt, [bool]$DefaultYes = $true) {
    if ($NonInteractive) {
        Write-Info ("auto answer for '{0}': {1}" -f $Prompt, $(if ($DefaultYes) { "yes" } else { "no" }))
        return $DefaultYes
    }
    $suffix = if ($DefaultYes) { "[Y/n]" } else { "[y/N]" }
    $answer = Read-Host ("{0} {1}" -f $Prompt, $suffix)
    if ([string]::IsNullOrWhiteSpace($answer)) {
        return $DefaultYes
    }
    return $answer -match "^[Yy]"
}

function Ask-Value([string]$Prompt, [string]$DefaultValue = "") {
    if ($NonInteractive) {
        Write-Info ("auto value for '{0}': {1}" -f $Prompt, $DefaultValue)
        return $DefaultValue
    }
    $value = Read-Host $Prompt
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $DefaultValue
    }
    return $value.Trim()
}

function Test-CommandExists([string]$Name) {
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Ensure-Dir([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Write-Ascii([string]$Path, [string]$Content) {
    $ascii = [System.Text.Encoding]::ASCII
    [System.IO.File]::WriteAllText($Path, $Content, $ascii)
}

function Copy-DirContent([string]$Source, [string]$Destination) {
    Ensure-Dir $Destination
    Get-ChildItem -LiteralPath $Source -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $Destination -Recurse -Force
    }
}

function Invoke-Checked([string]$Command, [string[]]$Arguments, [string]$ErrorText) {
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        Fail $ErrorText
    }
}

function Ensure-Admin {
    $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($currentIdentity)
    $isAdmin = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

    if ($isAdmin) {
        Write-Ok "already running as administrator"
        return
    }

    if ($NoElevate) {
        Write-Warn "administrator permission not available, continuing in user mode"
        return
    }

    try {
        Write-Info "relaunching with administrator permission"
        $args = @(
            "-NoProfile"
            "-NoExit"
            "-ExecutionPolicy", "Bypass"
            "-File", ('"{0}"' -f $MyInvocation.MyCommand.Path)
            "-NoElevate"
        )
        $process = Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $args -PassThru -ErrorAction Stop
        if ($process) {
            exit 0
        }
    } catch {
        Write-Warn "administrator relaunch was blocked, continuing in user mode"
    }
}

function Ensure-ExecutionPolicy {
    try {
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction Stop
    } catch {
        Write-Warn "failed to set process execution policy, continuing"
    }

    try {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
    } catch {
        Write-Warn "failed to set current user execution policy, continuing"
    }

    try {
        Unblock-File -LiteralPath $MyInvocation.MyCommand.Path -ErrorAction Stop
    } catch {
        Write-Warn "failed to unblock script file, continuing"
    }

    Write-Ok "execution policy step finished"
}

function Grant-FullControl([string]$Path) {
    Ensure-Dir $Path
    $acl = Get-Acl -LiteralPath $Path
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
        "FullControl",
        "ContainerInherit,ObjectInherit",
        "None",
        "Allow"
    )
    $acl.SetAccessRule($rule)
    Set-Acl -LiteralPath $Path -AclObject $acl
}

function Ensure-LocalPermissions {
    Grant-FullControl $script:OpenClawRoot
    Grant-FullControl $script:WorkspaceRoot
    Grant-FullControl $script:SkillsRoot
    Write-Ok "full control granted to current user for .openclaw"
}

function Get-OpenClawCmdPath {
    $command = Get-Command "openclaw.cmd" -ErrorAction SilentlyContinue
    if (-not $command) {
        $command = Get-Command "openclaw" -ErrorAction SilentlyContinue
    }
    if ($command -and $command.Source) {
        return $command.Source
    }
    return (Join-Path $env:APPDATA "npm\openclaw.cmd")
}

function Repair-GatewayLauncher {
    $gatewayPath = Join-Path $script:OpenClawRoot "gateway.cmd"
    $openclawCmd = Get-OpenClawCmdPath
    $content = @"
@echo off
call "$openclawCmd" gateway --port 18789
"@
    Write-Ascii $gatewayPath ($content.Trim() + "`r`n")
    Write-Ok "gateway launcher repaired for Windows path safety"
}

function Ensure-GatewayService {
    $taskName = "OpenClaw Gateway"
    & schtasks /Query /TN $taskName *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Info "installing OpenClaw gateway service"
        $previousErrorActionPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = "Continue"
            & openclaw gateway install *> $null
            if ($LASTEXITCODE -ne 0) {
                Write-Warn "gateway install returned non-zero, skip automatic start"
                return
            }
        } finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
    }

    Repair-GatewayLauncher

    Write-Info "starting OpenClaw gateway service"
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & openclaw gateway start *> $null
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "gateway start returned non-zero, run 'openclaw gateway status --deep' later"
            return
        }
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    Write-Ok "gateway start command sent"
}

function Select-Python312 {
    $candidates = @(
        @{ Name = "py"; Args = @("-3.12"); Check = @("-3.12", "--version") },
        @{ Name = "python3.12"; Args = @(); Check = @("--version") },
        @{ Name = "python"; Args = @(); Check = @("--version") }
    )

    foreach ($candidate in $candidates) {
        if (-not (Test-CommandExists $candidate.Name)) {
            continue
        }

        try {
            $version = & $candidate.Name @($candidate.Check) 2>$null
            if ($version -match "3\.12") {
                $script:PythonExe = $candidate.Name
                $script:PythonArgs = $candidate.Args
                Write-Ok ("python detected: {0}" -f $version)
                return
            }
        } catch {
        }
    }

    Fail "python 3.12 not found"
}

function Invoke-Python {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

    $allArgs = @()
    $allArgs += $script:PythonArgs
    $allArgs += $Arguments
    & $script:PythonExe @allArgs
    if ($LASTEXITCODE -ne 0) {
        Fail "python command failed"
    }
}

function Install-PythonRequirements([string]$Target, [string]$RequirementsFile = "requirements.txt") {
    Push-Location $Target
    try {
        Invoke-Python -m venv .venv
        $venvPython = Join-Path $Target ".venv\Scripts\python.exe"
        if (Test-Path -LiteralPath $venvPython) {
            Invoke-Checked $venvPython @("-m", "pip", "install", "--isolated", "-r", $RequirementsFile) ("pip install failed: {0}" -f $Target)
        } else {
            Invoke-Python -m pip install --isolated -r $RequirementsFile
        }
    } finally {
        Pop-Location
    }
}

function Install-NodeDeps([string]$Target) {
    Push-Location $Target
    try {
        Invoke-Checked "npm" @("install") ("npm install failed: {0}" -f $Target)
    } finally {
        Pop-Location
    }
}

function Clone-OrUpdateRepo([string]$RepoUrl, [string]$TargetPath) {
    if (Test-Path -LiteralPath (Join-Path $TargetPath ".git")) {
        Push-Location $TargetPath
        try {
            $previousErrorActionPreference = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            & cmd.exe /c "git pull origin main" > $null 2>&1
            if ($LASTEXITCODE -ne 0) {
                & cmd.exe /c "git pull origin master" > $null 2>&1
            }
            $ErrorActionPreference = $previousErrorActionPreference
            if ($LASTEXITCODE -ne 0) {
                Fail ("git pull failed: {0}" -f $TargetPath)
            }
        } finally {
            $ErrorActionPreference = $previousErrorActionPreference
            Pop-Location
        }
        return
    }

    if (Test-Path -LiteralPath $TargetPath) {
        $hasContent = (Get-ChildItem -LiteralPath $TargetPath -Force -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($hasContent) {
            $backupPath = "{0}.bak-{1}" -f $TargetPath, (Get-Date -Format "yyyyMMddHHmmss")
            Move-Item -LiteralPath $TargetPath -Destination $backupPath -Force
            Write-Warn ("existing non-git directory moved to backup: {0}" -f $backupPath)
        } else {
            Remove-Item -LiteralPath $TargetPath -Force
        }
    }

    Invoke-Checked "git" @("clone", $RepoUrl, $TargetPath) ("git clone failed: {0}" -f $RepoUrl)
}

function New-RandomHex([int]$Length = 48) {
    $bytes = New-Object byte[] ($Length / 2)
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    return ($bytes | ForEach-Object { $_.ToString("x2") }) -join ""
}

function Sync-PluginConfig {
    $configPath = Join-Path $script:OpenClawRoot "openclaw.json"
    if (-not (Test-Path -LiteralPath $configPath)) {
        return
    }

    $json = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $plugins = $json.plugins
    $plugins.allow = @($plugins.allow | Where-Object { $_ -notin @("memory-lancedb-pro", "lossless-claw") })
    $plugins.entries.PSObject.Properties.Remove("memory-lancedb-pro")
    $plugins.entries.PSObject.Properties.Remove("lossless-claw")
    $plugins.slots.PSObject.Properties.Remove("memory")
    $plugins.slots.PSObject.Properties.Remove("contextEngine")
    $plugins.installs.PSObject.Properties.Remove("lossless-claw")

    $memoryPath = (Join-Path $script:WorkspaceRoot "plugins\memory-lancedb-pro").Replace("\", "/")
    $plugins.load.paths = @($plugins.load.paths | Where-Object { $_ -ne $memoryPath })

    if (-not $json.commands) {
        $json | Add-Member -NotePropertyName "commands" -NotePropertyValue @{} -Force
    }
    $json.commands.native = $true
    $json.commands.nativeSkills = $true
    $json.commands.restart = $true
    $json.commands.ownerDisplay = "raw"

    Write-Utf8NoBom $configPath (($json | ConvertTo-Json -Depth 100) + "`n")
}

function Reset-PluginConfigToBase {
    $configPath = Join-Path $script:OpenClawRoot "openclaw.json"
    if (-not (Test-Path -LiteralPath $configPath)) {
        return
    }

    $json = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $json.plugins) {
        return
    }

    $plugins = $json.plugins
    $plugins.allow = @($plugins.allow | Where-Object { $_ -notin @("memory-lancedb-pro", "lossless-claw") })
    $plugins.entries.PSObject.Properties.Remove("memory-lancedb-pro")
    $plugins.entries.PSObject.Properties.Remove("lossless-claw")
    $plugins.slots.PSObject.Properties.Remove("memory")
    $plugins.slots.PSObject.Properties.Remove("contextEngine")
    $plugins.installs.PSObject.Properties.Remove("lossless-claw")
    if ($plugins.load -and $plugins.load.paths) {
        $plugins.load.paths = @($plugins.load.paths | Where-Object {
            $_ -notmatch 'memory-lancedb-pro|lossless-claw-enhanced'
        })
    }

    Write-Utf8NoBom $configPath (($json | ConvertTo-Json -Depth 100) + "`n")
}

function Collect-Profile {
    Write-Title "Profile setup"
    $script:Profile.UserName = Ask-Value "User display name" $script:Profile.UserName
    $script:Profile.Industry = Ask-Value "Industry" $script:Profile.Industry
    $script:Profile.VideoStyle = Ask-Value "Video style" $script:Profile.VideoStyle
    $script:Profile.AssistantName = Ask-Value "Assistant name" $script:Profile.AssistantName
    $script:Profile.AssistantTone = Ask-Value "Assistant tone" $script:Profile.AssistantTone
    $script:Profile.SoulStyle = Ask-Value "Soul style: steady / strict / lively" $script:Profile.SoulStyle
    $script:Profile.ConfirmBeforePublish = if (Ask-YesNo "Require manual confirm before publish?" $true) { "true" } else { "false" }

    if (Ask-YesNo "Enable Feishu notification?" $false) {
        $script:Profile.FeishuAppId = Ask-Value "Feishu App ID"
        if (-not [string]::IsNullOrWhiteSpace($script:Profile.FeishuAppId)) {
            $script:Profile.FeishuEnabled = $true
            $script:Profile.FeishuAppSecret = Ask-Value "Feishu App Secret"
        }
    }
}

function Configure-LLM {
    Write-Title "LLM config"
    Write-Host "1. Bailian"
    Write-Host "2. n1n.ai"
    $choice = Ask-Value "Select provider" "2"
    $templatePath = if ($choice -eq "1") {
        Join-Path $script:DeployRoot "config\openclaw-bailian.json.template"
    } else {
        Join-Path $script:DeployRoot "config\openclaw-n1n.json.template"
    }

    if (-not (Test-Path -LiteralPath $templatePath)) {
        Fail ("template not found: {0}" -f $templatePath)
    }

    $script:Profile.ApiKey = Ask-Value "API Key" "{{YOUR_API_KEY}}"
    $content = Get-Content -LiteralPath $templatePath -Raw -Encoding UTF8
    $content = $content.Replace("{{API_KEY}}", $script:Profile.ApiKey)
    $content = $content.Replace("{{HOME}}", $env:USERPROFILE.Replace("\", "/"))
    $content = $content.Replace("{{GATEWAY_TOKEN}}", (New-RandomHex 48))
    Write-Utf8NoBom (Join-Path $script:OpenClawRoot "openclaw.json") $content
    Reset-PluginConfigToBase
}

function Setup-WorkspaceFiles {
    $pythonDisplay = ($script:PythonExe + " " + ($script:PythonArgs -join " ")).Trim()
    foreach ($name in @("AGENTS.md", "HEARTBEAT.md", "MEMORY.md", "TOOLS.md")) {
        $src = Join-Path $script:DeployRoot ("workspace\{0}" -f $name)
        if (-not (Test-Path -LiteralPath $src)) {
            continue
        }

        $content = Get-Content -LiteralPath $src -Raw -Encoding UTF8
        $content = $content.Replace("{{HOME}}", $env:USERPROFILE)
        $content = $content.Replace("{{PYTHON_CMD}}", $pythonDisplay)
        $content = $content.Replace("{{WECHAT_TARGET}}", $script:Profile.WechatTarget)
        $content = $content.Replace("{{USER_NAME}}", $script:Profile.UserName)
        $content = $content.Replace("{{FEISHU_APP_ID}}", $script:Profile.FeishuAppId)
        $content = $content.Replace("{{FEISHU_APP_SECRET}}", $script:Profile.FeishuAppSecret)
        Write-Utf8NoBom (Join-Path $script:WorkspaceRoot $name) $content
    }

    $identity = @"
# IDENTITY

- name: $($script:Profile.AssistantName)
- role: main workspace assistant
- tone: $($script:Profile.AssistantTone)
- soul: $($script:Profile.SoulStyle)
"@
    Write-Utf8NoBom (Join-Path $script:WorkspaceRoot "IDENTITY.md") ($identity.Trim() + "`n")

    $soul = @"
# SOUL

- work first, explain second
- no empty reassurance
- verify before claiming success
- be careful with external publishing actions
"@
    Write-Utf8NoBom (Join-Path $script:WorkspaceRoot "SOUL.md") ($soul.Trim() + "`n")

    $user = @"
# USER

- name: $($script:Profile.UserName)
- industry: $($script:Profile.Industry)
- video_style: $($script:Profile.VideoStyle)
- confirm_before_publish: $($script:Profile.ConfirmBeforePublish)
"@
    Write-Utf8NoBom (Join-Path $script:WorkspaceRoot "USER.md") ($user.Trim() + "`n")
}

function Setup-UploadConfig {
    $uploadRoot = Join-Path $script:WorkspaceRoot "openclaw_upload"
    $configPath = Join-Path $uploadRoot "flash_longxia\config.yaml"
    Ensure-Dir (Split-Path -Parent $configPath)

    $yaml = @"
base_url: "http://123.56.58.223:8081"
upload_url: "http://123.56.58.223:8081/api/v1/file/upload"
model_config_url: "http://123.56.58.223:8081/api/v1/globalConfig/getModel"

device_verify:
  enabled: false
  api_path: "/api/v1/device/verify"

video:
  poll_interval: 30
  max_wait_minutes: 30
  download_retries: 3
  download_retry_interval: 5
  output_dir: "./output"
  confirm_before_generate: $($script:Profile.ConfirmBeforePublish)
  model: "auto"
  duration: 10
  aspectRatio: "16:9"
  variants: 1

content:
  industry: "$($script:Profile.Industry)"
  video_style: "$($script:Profile.VideoStyle)"
  auto_generate_title: true
  auto_generate_description: true

notify:
  wechat_target: "$($script:Profile.WechatTarget)"
  channel: "openclaw-weixin"
  feishu:
    enabled: $($script:Profile.FeishuEnabled.ToString().ToLower())
    app_id: "$($script:Profile.FeishuAppId)"
    app_secret: "$($script:Profile.FeishuAppSecret)"
    notify_on_complete: true
    notify_on_publish: true
"@
    Write-Utf8NoBom $configPath ($yaml.Trim() + "`n")
}

function Setup-Cron {
    $loginTime = Ask-Value "Daily login check time HH:MM" "10:10"
    $cleanupDay = Ask-Value "Cleanup weekday 0-6" "2"
    $cleanupTime = Ask-Value "Cleanup time HH:MM" "01:00"
    $loginParts = $loginTime.Split(":")
    $cleanupParts = $cleanupTime.Split(":")
    if ($loginParts.Count -ne 2 -or $cleanupParts.Count -ne 2) {
        Fail "invalid time format"
    }

    $pythonDisplay = ($script:PythonExe + " " + ($script:PythonArgs -join " ")).Trim()
    $xiaolongDir = (Join-Path $script:WorkspaceRoot "xiaolong-upload").Replace("\", "/")
    $uploadDir = (Join-Path $script:WorkspaceRoot "openclaw_upload").Replace("\", "/")
    $workspaceDir = $script:WorkspaceRoot.Replace("\", "/")
    $nowMs = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()

    $cron = @"
{
  "version": 1,
  "jobs": [
    {
      "id": "$(New-Guid)",
      "agentId": "main",
      "sessionKey": "agent:main:main",
      "name": "login-status-daily-check",
      "enabled": true,
      "createdAtMs": $nowMs,
      "updatedAtMs": $nowMs,
      "schedule": { "kind": "cron", "expr": "$($loginParts[1]) $($loginParts[0]) * * *", "tz": "Asia/Shanghai" },
      "sessionTarget": "main",
      "wakeMode": "now",
      "payload": { "kind": "systemEvent", "text": "cd $xiaolongDir && $pythonDisplay skills/auth/scripts/scheduled_login_check.py" },
      "state": { "consecutiveErrors": 0 }
    },
    {
      "id": "$(New-Guid)",
      "agentId": "main",
      "sessionKey": "agent:main:main",
      "name": "video-cleanup-weekly",
      "enabled": true,
      "createdAtMs": $nowMs,
      "updatedAtMs": $nowMs,
      "schedule": { "kind": "cron", "expr": "$($cleanupParts[1]) $($cleanupParts[0]) * * $cleanupDay", "tz": "Asia/Shanghai" },
      "sessionTarget": "main",
      "wakeMode": "now",
      "payload": { "kind": "systemEvent", "text": "cd $uploadDir && $pythonDisplay scripts/cleanup_uploaded_videos.py --workspace-root $workspaceDir --project-root $uploadDir" },
      "state": { "consecutiveErrors": 0 }
    }
  ]
}
"@
    Write-Utf8NoBom (Join-Path $script:OpenClawRoot "cron\jobs.json") ($cron.Trim() + "`n")
}

function Setup-UpdaterScript {
    $content = @'
param()
$ErrorActionPreference = "Stop"

function Copy-DirContent([string]$Source, [string]$Destination) {
    if (-not (Test-Path -LiteralPath $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }
    Get-ChildItem -LiteralPath $Source -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $Destination -Recurse -Force
    }
}

function Update-Repo([string]$Path) {
    if (-not (Test-Path -LiteralPath (Join-Path $Path ".git"))) { return }
    Push-Location $Path
    try {
        & git pull origin main 2>$null
        if ($LASTEXITCODE -ne 0) {
            & git pull origin master 2>$null
        }
    } finally {
        Pop-Location
    }
}

$workspace = Join-Path $env:USERPROFILE ".openclaw\workspace"
$skills = Join-Path $env:USERPROFILE ".openclaw\skills"
$x = Join-Path $workspace "xiaolong-upload"
$u = Join-Path $workspace "openclaw_upload"

Update-Repo $x
Update-Repo $u

foreach ($name in @("auth", "longxia-bootstrap", "longxia-upload")) {
    $src = Join-Path $x ("skills\{0}" -f $name)
    if (Test-Path -LiteralPath $src) {
        Copy-DirContent $src (Join-Path $skills $name)
    }
}

$flash = Join-Path $u "skills\flash-longxia"
if (Test-Path -LiteralPath $flash) {
    Copy-DirContent $flash (Join-Path $skills "flash-longxia")
}
'@
    Write-Utf8NoBom (Join-Path $script:WorkspaceRoot "update-skills.ps1") ($content.Trim() + "`n")
}

function Install-Skills {
    foreach ($name in @("flash-longxia", "auth", "longxia-upload", "longxia-bootstrap", "video-cleanup")) {
        $src = Join-Path $script:DeployRoot ("skills\{0}" -f $name)
        if (Test-Path -LiteralPath $src) {
            Copy-DirContent $src (Join-Path $script:SkillsRoot $name)
        }
    }

    $xiaolong = Join-Path $script:WorkspaceRoot "xiaolong-upload"
    foreach ($name in @("auth", "longxia-bootstrap", "longxia-upload")) {
        $src = Join-Path $xiaolong ("skills\{0}" -f $name)
        if (Test-Path -LiteralPath $src) {
            Copy-DirContent $src (Join-Path $script:SkillsRoot $name)
        }
    }

    $flash = Join-Path $script:WorkspaceRoot "openclaw_upload\skills\flash-longxia"
    if (Test-Path -LiteralPath $flash) {
        Copy-DirContent $flash (Join-Path $script:SkillsRoot "flash-longxia")
    }
}

function Install-Plugins {
    $plugins = Join-Path $script:WorkspaceRoot "plugins"
    Ensure-Dir $plugins

    Write-Info "skip memory-lancedb-pro during deployment"
    $script:InstallMemoryPlugin = $false
    Write-Info "skip lossless-claw-enhanced during deployment"
    $script:InstallContextPlugin = $false

    Sync-PluginConfig
}

function Write-Status {
    Write-Title "Summary"
    Write-Host ("OpenClaw version: {0}" -f $script:InstalledOpenClawVersion)
    Write-Host ("Python: {0} {1}" -f $script:PythonExe, ($script:PythonArgs -join " "))
    Write-Host ("Workspace: {0}" -f $script:WorkspaceRoot)
    Write-Host "Next:"
    Write-Host "1. openclaw"
    Write-Host "2. openclaw channels login --channel openclaw-weixin"
    Write-Host "3. run $HOME\.openclaw\workspace\update-skills.ps1 when you need updates"
}

function Main {
    Write-Title ("OpenClaw Windows one-click deploy v{0}" -f $script:DeployVersion)
    Ensure-Admin
    Ensure-ExecutionPolicy

    Write-Title "System check"
    foreach ($cmd in @("node", "npm", "npx", "git")) {
        if (-not (Test-CommandExists $cmd)) {
            Fail ("required command not found: {0}" -f $cmd)
        }
    }
    Select-Python312

    Write-Title "Install OpenClaw"
    if (Test-CommandExists "openclaw") {
        $script:InstalledOpenClawVersion = (& openclaw --version 2>$null)
        Write-Ok ("existing OpenClaw detected: {0}" -f $script:InstalledOpenClawVersion)
    } else {
        Invoke-Checked "npm" @("install", "-g", $script:OpenClawPackage) "failed to install OpenClaw"
        if (Test-CommandExists "openclaw") {
            $script:InstalledOpenClawVersion = (& openclaw --version 2>$null)
        }
    }

    foreach ($dir in @(
        $script:OpenClawRoot,
        $script:WorkspaceRoot,
        $script:SkillsRoot,
        (Join-Path $script:WorkspaceRoot "inbound_images"),
        (Join-Path $script:WorkspaceRoot "inbound_videos"),
        (Join-Path $script:WorkspaceRoot "memory"),
        (Join-Path $script:WorkspaceRoot "plugins"),
        (Join-Path $script:WorkspaceRoot "logs\auth_qr"),
        (Join-Path $script:OpenClawRoot "memory"),
        (Join-Path $script:OpenClawRoot "memory-md"),
        (Join-Path $script:OpenClawRoot "cron")
    )) {
        Ensure-Dir $dir
    }

    Ensure-LocalPermissions

    Collect-Profile
    Configure-LLM

    if ($script:Profile.FeishuEnabled) {
        $credDir = Join-Path $script:OpenClawRoot "credentials"
        Ensure-Dir $credDir
        $credJson = @{
            appId = $script:Profile.FeishuAppId
            appSecret = $script:Profile.FeishuAppSecret
        } | ConvertTo-Json -Depth 10
        Write-Utf8NoBom (Join-Path $credDir "feishu-main-allowFrom.json") ($credJson + "`n")
    }

    Write-Title "Sync repositories"
    $xiaolong = Join-Path $script:WorkspaceRoot "xiaolong-upload"
    $upload = Join-Path $script:WorkspaceRoot "openclaw_upload"
    Clone-OrUpdateRepo "https://github.com/SunnySLJ/xiaolong-upload.git" $xiaolong
    Clone-OrUpdateRepo "https://github.com/SunnySLJ/openclaw_upload.git" $upload

    if (Test-Path -LiteralPath (Join-Path $xiaolong "requirements.txt")) {
        Install-PythonRequirements $xiaolong "requirements.txt"
    }
    if (Test-Path -LiteralPath (Join-Path $upload "requirements.txt")) {
        Install-PythonRequirements $upload "requirements.txt"
    }

    foreach ($dir in @(
        (Join-Path $upload "cookies"),
        (Join-Path $upload "logs"),
        (Join-Path $upload "published"),
        (Join-Path $upload "flash_longxia\output"),
        (Join-Path $upload "scripts")
    )) {
        Ensure-Dir $dir
    }

    $cleanupSrc = Join-Path $script:DeployRoot "scripts\cleanup_uploaded_videos.py"
    $cleanupDst = Join-Path $upload "scripts\cleanup_uploaded_videos.py"
    if (Test-Path -LiteralPath $cleanupSrc) {
        Copy-Item -LiteralPath $cleanupSrc -Destination $cleanupDst -Force
    }

    Setup-WorkspaceFiles
    Setup-UploadConfig
    Install-Skills
    Install-Plugins

    Write-Title "Install channel plugin"
    if ($NonInteractive) {
        Write-Warn "skipping automatic weixin login in non-interactive mode"
        $previousErrorActionPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = "Continue"
            & npx -y "@tencent-weixin/openclaw-weixin-cli@latest" install *> $null
            if ($LASTEXITCODE -ne 0) {
                Write-Warn "weixin plugin install returned non-zero, continue and login manually later"
            }
        } catch {
            Write-Warn "weixin plugin install hit a non-fatal error, continue and login manually later"
        } finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
    } else {
        Invoke-Checked "npx" @("-y", "@tencent-weixin/openclaw-weixin-cli@latest", "install") "failed to install weixin plugin"
    }

    Setup-Cron
    Ensure-GatewayService

    $token = Ask-Value "Video token (optional)"
    if (-not [string]::IsNullOrWhiteSpace($token)) {
        $tokenDir = Join-Path $upload "flash_longxia"
        Ensure-Dir $tokenDir
        Write-Utf8NoBom (Join-Path $tokenDir "token.txt") $token
    }

    $script:Profile.WechatTarget = Ask-Value "Wechat target id (optional)" $script:Profile.WechatTarget
    if (-not [string]::IsNullOrWhiteSpace($script:Profile.WechatTarget)) {
        Setup-UploadConfig
    }

    Setup-UpdaterScript
    Write-Status
}

try {
    Main
} catch {
    Write-Host ("[ERROR] {0}" -f $_.Exception.Message) -ForegroundColor Red
    if ($_.Exception.GetType()) {
        Write-Host ("[ERROR_TYPE] {0}" -f $_.Exception.GetType().FullName) -ForegroundColor Red
    }
    if ($_.InvocationInfo -and $_.InvocationInfo.PositionMessage) {
        Write-Host $_.InvocationInfo.PositionMessage -ForegroundColor DarkRed
    }
    if ($_.ScriptStackTrace) {
        Write-Host $($_.ScriptStackTrace) -ForegroundColor DarkRed
    }
    exit 1
}
