[CmdletBinding()]
param(
    [ValidateSet("status", "bootstrap", "pull", "sync")]
    [string]$Action = "status",
    [switch]$BootstrapIfNeeded,
    [string]$Name
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
Set-Location $RepoRoot

$Upstreams = @(
    @{
        Name = "deploy"
        Prefix = "deploy"
        Remote = "upstream-deploy"
        Url = "https://github.com/SunnySLJ/deploy.git"
        Branch = "main"
    },
    @{
        Name = "xiaolong-upload"
        Prefix = "xiaolong-upload"
        Remote = "upstream-xiaolong-upload"
        Url = "https://github.com/SunnySLJ/xiaolong-upload.git"
        Branch = "main"
    }
)

function Invoke-Git {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Args
    )

    & git @Args
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Args -join ' ') failed with exit code $LASTEXITCODE"
    }
}

function Test-CleanWorktree {
    & git diff --quiet
    if ($LASTEXITCODE -ne 0) { return $false }
    & git diff --cached --quiet
    return ($LASTEXITCODE -eq 0)
}

function Ensure-CleanWorktree {
    if (-not (Test-CleanWorktree)) {
        throw "Working tree is not clean. Commit or stash changes first."
    }
}

function Ensure-Remote {
    param([hashtable]$Upstream)

    $RemoteNames = @(& git remote)
    if ($RemoteNames -contains $Upstream.Remote) {
        Invoke-Git remote set-url $Upstream.Remote $Upstream.Url
    } else {
        Invoke-Git remote add $Upstream.Remote $Upstream.Url
    }
}

function Fetch-Remote {
    param([hashtable]$Upstream)
    Invoke-Git fetch $Upstream.Remote $Upstream.Branch
}

function Test-SubtreeInitialized {
    param([hashtable]$Upstream)

    & git log "--grep=^git-subtree-dir: $($Upstream.Prefix)$" -n 1 --format=%H HEAD *> $null
    return ($LASTEXITCODE -eq 0)
}

function Copy-DirectoryContent {
    param(
        [string]$Source,
        [string]$Destination
    )

    if (-not (Test-Path $Source)) {
        return
    }

    New-Item -ItemType Directory -Force $Destination | Out-Null
    Get-ChildItem -LiteralPath $Source -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $Destination -Recurse -Force
    }
}

function Bootstrap-Upstream {
    param([hashtable]$Upstream)

    Write-Host "[bootstrap] $($Upstream.Name)"
    Ensure-CleanWorktree

    $BackupDir = Join-Path $RepoRoot ".codex_tmp\subtree-bootstrap\$($Upstream.Name)"
    if (Test-Path $BackupDir) {
        Remove-Item -Recurse -Force $BackupDir
    }

    if (Test-Path $Upstream.Prefix) {
        Copy-DirectoryContent -Source $Upstream.Prefix -Destination $BackupDir
        Invoke-Git rm -r -q -- $Upstream.Prefix
        Invoke-Git commit -m "chore(subtree): prepare $($Upstream.Name) bootstrap"
    }

    Invoke-Git subtree add "--prefix=$($Upstream.Prefix)" $Upstream.Remote $Upstream.Branch --squash -m "chore(subtree): add $($Upstream.Name) subtree"

    if (Test-Path $BackupDir) {
        New-Item -ItemType Directory -Force $Upstream.Prefix | Out-Null
        Copy-DirectoryContent -Source $BackupDir -Destination $Upstream.Prefix
        Invoke-Git add $Upstream.Prefix
        & git diff --cached --quiet -- $Upstream.Prefix
        if ($LASTEXITCODE -ne 0) {
            Invoke-Git commit -m "chore(subtree): reapply local $($Upstream.Name) customizations"
        }
    }
}

function Pull-Upstream {
    param([hashtable]$Upstream)

    Ensure-Remote $Upstream
    Fetch-Remote $Upstream

    if (-not (Test-SubtreeInitialized $Upstream)) {
        if ($BootstrapIfNeeded.IsPresent -or $Action -eq "bootstrap") {
            Bootstrap-Upstream $Upstream
        } else {
            Write-Host "[skip] $($Upstream.Name): subtree metadata missing. Run bootstrap first."
            return
        }
    }

    $Before = (& git rev-parse HEAD).Trim()
    Invoke-Git subtree pull "--prefix=$($Upstream.Prefix)" $Upstream.Remote $Upstream.Branch --squash -m "chore(subtree): sync $($Upstream.Name) from $($Upstream.Branch)"
    $After = (& git rev-parse HEAD).Trim()

    if ($Before -eq $After) {
        Write-Host "[ok] $($Upstream.Name): already up to date"
    } else {
        Write-Host "[ok] $($Upstream.Name): synced"
    }
}

function Show-UpstreamStatus {
    param([hashtable]$Upstream)

    Ensure-Remote $Upstream
    Fetch-Remote $Upstream

    $Initialized = if (Test-SubtreeInitialized $Upstream) { "yes" } else { "no" }
    $RemoteHead = (& git rev-parse "$($Upstream.Remote)/$($Upstream.Branch)").Trim()
    Write-Host "$($Upstream.Name): prefix=$($Upstream.Prefix) initialized=$Initialized remote=$RemoteHead"
}

$SelectedUpstreams = if ($Name) {
    $Filtered = $Upstreams | Where-Object { $_.Name -eq $Name }
    if (-not $Filtered) {
        throw "Unknown upstream name: $Name"
    }
    $Filtered
} else {
    $Upstreams
}

switch ($Action) {
    "status" {
        foreach ($Upstream in $SelectedUpstreams) {
            Show-UpstreamStatus $Upstream
        }
    }
    "bootstrap" {
        foreach ($Upstream in $SelectedUpstreams) {
            Pull-Upstream $Upstream
        }
    }
    "pull" {
        foreach ($Upstream in $SelectedUpstreams) {
            Pull-Upstream $Upstream
        }
    }
    "sync" {
        foreach ($Upstream in $SelectedUpstreams) {
            Pull-Upstream $Upstream
        }
    }
}
