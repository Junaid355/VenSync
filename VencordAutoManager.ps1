param(
    [switch]$AutoFix,
    [switch]$CheckOnly,
    [switch]$Launch,
    [switch]$Repair,
    [switch]$InstallVencord,
    [switch]$Startup,
    [switch]$StartupSilent,
    [switch]$Update
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Host.UI.RawUI.WindowTitle = "VenSync - Discord & Vencord Auto-Detector"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ScriptDir) { $ScriptDir = "$env:USERPROFILE\.vensync" }
$CliPath = Join-Path $ScriptDir "VencordInstallerCli.exe"

function Write-BrandHeader {
    Clear-Host
    Write-Host ""
    Write-Host " ========================================================" -ForegroundColor Cyan
    Write-Host "   [*] VenSync - Discord & Vencord Auto Setup Suite" -ForegroundColor Cyan
    Write-Host "   [+] Auto-Detection | 1-Click Installer | Auto-Repair" -ForegroundColor Green
    Write-Host "   [+] GitHub: https://github.com/Junaid355/VenSync" -ForegroundColor DarkGray
    Write-Host " ========================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Get-DiscordPath {
    $paths = @(
        "$env:LOCALAPPDATA\Discord\Update.exe",
        "$env:LOCALAPPDATA\DiscordCanary\Update.exe",
        "$env:LOCALAPPDATA\DiscordPTB\Update.exe"
    )
    foreach ($p in $paths) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Get-ActiveDiscordInstallations {
    $installations = @()
    $branches = @("Discord", "DiscordCanary", "DiscordPTB")
    foreach ($branch in $branches) {
        $dir = Join-Path $env:LOCALAPPDATA $branch
        if (Test-Path $dir) {
            $appDirs = Get-ChildItem -Path $dir -Directory -Filter "app-*" -ErrorAction SilentlyContinue | Sort-Object Name -Descending
            $validApp = $null
            foreach ($ad in $appDirs) {
                $asarCheck = Join-Path $ad.FullName "resources\app.asar"
                $backupCheck = Join-Path $ad.FullName "resources\_app.asar"
                if ((Test-Path $asarCheck) -or (Test-Path $backupCheck)) {
                    $validApp = $ad
                    break
                }
            }
            if ($validApp) {
                $exePath = Join-Path $validApp.FullName "$branch.exe"
                $resourcesPath = Join-Path $validApp.FullName "resources"
                $asarPath = Join-Path $resourcesPath "app.asar"
                $installations += [PSCustomObject]@{
                    Branch       = $branch
                    Directory    = $dir
                    LatestAppDir = $validApp.FullName
                    ExePath      = $exePath
                    ResourcesDir = $resourcesPath
                    AsarPath     = $asarPath
                }
            }
        }
    }
    return $installations
}

function Test-VencordPatched {
    $installs = Get-ActiveDiscordInstallations
    if (-not $installs) { return $false }
    
    foreach ($inst in $installs) {
        if (-not (Test-Path $inst.AsarPath)) { return $false }
        $content = Get-Content -Path $inst.AsarPath -Raw -ErrorAction SilentlyContinue
        if ($content -notmatch "vencord|patcher\.js") {
            # Also check app directory fallback
            $appIndex = Join-Path $inst.ResourcesDir "app\index.js"
            if (-not (Test-Path $appIndex)) {
                return $false
            }
            $appContent = Get-Content -Path $appIndex -Raw -ErrorAction SilentlyContinue
            if ($appContent -notmatch "vencord|patcher\.js") {
                return $false
            }
        }
    }
    return $true
}

function Ensure-VencordCli {
    if (Test-Path $CliPath) { return $true }
    $url = "https://github.com/Vendicated/VencordInstaller/releases/latest/download/VencordInstallerCli.exe"
    try {
        curl.exe --retry 3 --retry-delay 2 -L -o "$CliPath" "$url" 2>$null
        return (Test-Path $CliPath)
    } catch {
        return $false
    }
}

function Apply-VencordPatch {
    param([switch]$RestartDiscord)

    Ensure-VencordCli | Out-Null
    if (-not (Test-Path $CliPath)) { return $false }

    $wasRunning = $false
    $running = Get-Process -Name "Discord*", "DiscordCanary*", "DiscordPTB*" -ErrorAction SilentlyContinue
    if ($running) {
        $wasRunning = $true
        Stop-Process -Name "Discord*", "DiscordCanary*", "DiscordPTB*" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }

    & "$CliPath" -install -branch auto 2>$null
    Start-Sleep -Seconds 1

    if ($wasRunning -or $RestartDiscord) {
        $installs = Get-ActiveDiscordInstallations
        if ($installs) {
            Start-Process -FilePath $installs[0].ExePath
        }
    }
    return (Test-VencordPatched)
}

function Run-SilentStartupCheck {
    if (-not (Test-VencordPatched)) {
        Apply-VencordPatch -RestartDiscord
    }
    [System.GC]::Collect()
    exit 0
}

if ($StartupSilent) {
    Run-SilentStartupCheck
}

if ($CheckOnly) {
    Write-BrandHeader
    Write-Host " [System Diagnostics]" -ForegroundColor Yellow
    Write-Host " --------------------------------------------------------" -ForegroundColor DarkGray
    $discPath = Get-DiscordPath
    Write-Host "  Discord Desktop  : " -NoNewline
    if ($discPath) { Write-Host "INSTALLED ($discPath)" -ForegroundColor Green } else { Write-Host "MISSING" -ForegroundColor Red }

    $proc = Get-Process -Name Discord,DiscordCanary,DiscordPTB -ErrorAction SilentlyContinue
    Write-Host "  Discord Status   : " -NoNewline
    if ($proc) { Write-Host "RUNNING ($($proc.Count) processes)" -ForegroundColor Green } else { Write-Host "STOPPED" -ForegroundColor DarkYellow }

    $isPatched = Test-VencordPatched
    Write-Host "  Vencord Patch    : " -NoNewline
    if ($isPatched) { Write-Host "PATCHED & ACTIVE" -ForegroundColor Green } else { Write-Host "OUTDATED / UNPATCHED" -ForegroundColor Red }

    $regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $startupEntry = (Get-ItemProperty -Path $regKey -Name "VenSyncAutoSetupManager" -ErrorAction SilentlyContinue)
    Write-Host "  Auto-Check Boot  : " -NoNewline
    if ($startupEntry) { Write-Host "ENABLED (100% Silent Background & Auto-Close)" -ForegroundColor Green } else { Write-Host "DISABLED" -ForegroundColor DarkGray }
    Write-Host " --------------------------------------------------------" -ForegroundColor DarkGray
    exit 0
}

if ($AutoFix -or $InstallVencord -or $Repair) {
    Write-BrandHeader
    Write-Host " [*] Applying Vencord patch..." -ForegroundColor Cyan
    Apply-VencordPatch -RestartDiscord
    Write-Host " [OK] Complete!" -ForegroundColor Green
    Start-Sleep -Seconds 2
    exit 0
}

# Interactive Menu
Write-BrandHeader
$isPatched = Test-VencordPatched
Write-Host " Discord Status: " -NoNewline
if ($isPatched) { Write-Host "Active & Patched [OK]" -ForegroundColor Green } else { Write-Host "Needs Patch [!]" -ForegroundColor Red }
Write-Host ""
Write-Host " [1] Re-Patch / AutoFix Vencord" -ForegroundColor Cyan
Write-Host " [2] Toggle Windows Startup Check" -ForegroundColor Yellow
Write-Host " [3] Launch Discord" -ForegroundColor Green
Write-Host " [4] Exit" -ForegroundColor DarkGray
Write-Host ""
$choice = Read-Host " Enter choice (1-4)"
switch ($choice) {
    "1" { Apply-VencordPatch -RestartDiscord }
    "2" {
        $regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        $vbsPath = Join-Path $ScriptDir "BackgroundStartupCheck.vbs"
        $val = "wscript.exe `"$vbsPath`""
        $exists = (Get-ItemProperty -Path $regKey -Name "VenSyncAutoSetupManager" -ErrorAction SilentlyContinue)
        if ($exists) {
            Remove-ItemProperty -Path $regKey -Name "VenSyncAutoSetupManager" -ErrorAction SilentlyContinue
            Write-Host "Startup check disabled." -ForegroundColor Yellow
        } else {
            Set-ItemProperty -Path $regKey -Name "VenSyncAutoSetupManager" -Value $val
            Write-Host "Startup check enabled!" -ForegroundColor Green
        }
        Start-Sleep -Seconds 2
    }
    "3" {
        $installs = Get-ActiveDiscordInstallations
        if ($installs) { Start-Process $installs[0].ExePath }
    }
    default { exit 0 }
}
