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

function Test-VencordPatched {
    $pattern = "$env:LOCALAPPDATA\Discord*\app-*\modules\discord_desktop_core-*\discord_desktop_core\index.js"
    $files = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        $content = Get-Content -Path $f.FullName -Raw -ErrorAction SilentlyContinue
        if ($content -match "vencord|patcher") { return $true }
    }
    return $false
}

function Show-Diagnostics {
    Write-Host " [System Diagnostics]" -ForegroundColor Yellow
    Write-Host " --------------------------------------------------------" -ForegroundColor DarkGray
    
    # 1. Discord
    $discPath = Get-DiscordPath
    if ($discPath) {
        Write-Host "  Discord Desktop  : " -NoNewline
        Write-Host "INSTALLED" -ForegroundColor Green -NoNewline
        Write-Host " ($discPath)" -ForegroundColor DarkGray
    } else {
        Write-Host "  Discord Desktop  : " -NoNewline
        Write-Host "MISSING" -ForegroundColor Red
    }

    # Process
    $proc = Get-Process -Name Discord,DiscordCanary,DiscordPTB -ErrorAction SilentlyContinue
    Write-Host "  Discord Status   : " -NoNewline
    if ($proc) {
        Write-Host "RUNNING ($($proc.Count) processes)" -ForegroundColor Green
    } else {
        Write-Host "STOPPED" -ForegroundColor DarkYellow
    }

    # 2. Vencord Patch
    $patched = Test-VencordPatched
    Write-Host "  Vencord Patch    : " -NoNewline
    if ($patched) {
        Write-Host "PATCHED & ACTIVE" -ForegroundColor Green
    } else {
        Write-Host "NOT PATCHED / NEEDS INJECTION" -ForegroundColor Red
    }

    # 3. Startup Check
    $regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $startupEntry = (Get-ItemProperty -Path $regKey -Name "VenSyncAutoSetupManager" -ErrorAction SilentlyContinue)
    Write-Host "  Auto-Check Boot  : " -NoNewline
    if ($startupEntry) {
        Write-Host "ENABLED (100% Silent Background & Auto-Close)" -ForegroundColor Green
    } else {
        Write-Host "DISABLED" -ForegroundColor DarkGray
    }

    Write-Host " --------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
}

function Update-VenSyncFiles {
    $repoRaw = "https://raw.githubusercontent.com/Junaid355/VenSync/main"
    $scriptDir = $PSScriptRoot
    if (-not $scriptDir) { $scriptDir = "$env:USERPROFILE\.vensync" }
    
    $files = @("VencordAutoManager.ps1", "core.py", "app.py", "BackgroundStartupCheck.vbs")
    foreach ($f in $files) {
        try {
            $dest = "$scriptDir\$f"
            Invoke-WebRequest -Uri "$repoRaw/$f" -OutFile "$dest.new" -UseBasicParsing -TimeoutSec 5 2>$null
            if (Test-Path "$dest.new") {
                Move-Item -Path "$dest.new" -Destination $dest -Force 2>$null
            }
        } catch {}
    }
}

function Install-DiscordClient {
    $url = "https://discord.com/api/download?platform=win"
    $dest = "$env:TEMP\DiscordSetup.exe"
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
        $proc = Start-Process -FilePath $dest -PassThru
        $maxWait = 60
        $elapsed = 0
        while ($elapsed -lt $maxWait) {
            Start-Sleep -Seconds 2
            $elapsed += 2
            if (Get-DiscordPath) { return $true }
        }
    } catch {}
    return (Get-DiscordPath) -ne $null
}

function Get-VencordCli {
    $cliPath = "$env:TEMP\VencordInstallerCli.exe"
    if (-not (Test-Path $cliPath)) {
        try {
            $url = "https://github.com/Vendicated/VencordInstaller/releases/latest/download/VencordInstallerCli.exe"
            Invoke-WebRequest -Uri $url -OutFile $cliPath -UseBasicParsing
        } catch {}
    }
    return $cliPath
}

function Install-VencordPatch {
    $cli = Get-VencordCli
    if (-not (Test-Path $cli)) { return $false }

    # Stop Discord
    Stop-Process -Name Discord,DiscordCanary,DiscordPTB -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1

    & $cli -install -branch auto 2>$null
    return (Test-VencordPatched)
}

function Repair-VencordPatch {
    $cli = Get-VencordCli
    if (-not (Test-Path $cli)) { return $false }

    Stop-Process -Name Discord,DiscordCanary,DiscordPTB -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1

    & $cli -repair -branch auto 2>$null
    return (Test-VencordPatched)
}

function Start-DiscordPatched {
    $discPath = Get-DiscordPath
    if ($discPath) {
        Start-Process -FilePath $discPath -ArgumentList "--processStart Discord.exe"
    }
}

function Start-AutoFixPipeline {
    # 1. Discord
    if (-not (Get-DiscordPath)) {
        Install-DiscordClient
    }

    # 2. Vencord
    if (-not (Test-VencordPatched)) {
        Install-VencordPatch
    }

    # 3. Launch
    Start-DiscordPatched
}

function Run-SilentStartupCheck {
    <#
    100% HEADLESS BACKGROUND EXECUTION (NO UI SHOWN):
    1. Checks GitHub for self-update silently.
    2. If Discord is NOT downloaded: silently downloads and installs Discord, then patches Vencord.
    3. If Discord updated and unpatched Vencord: silently re-hooks with -repair.
    4. Ensures Discord is running.
    5. Auto-closes immediately (0 MB residual RAM).
    #>
    Update-VenSyncFiles

    $discPath = Get-DiscordPath
    $isPatched = Test-VencordPatched

    if (-not $discPath) {
        Install-DiscordClient
        Install-VencordPatch
        Start-DiscordPatched
    } elseif (-not $isPatched) {
        # Discord auto-updated and wiped patch -> silently re-hook!
        Repair-VencordPatch
        Start-DiscordPatched
    } else {
        $proc = Get-Process -Name Discord,DiscordCanary,DiscordPTB -ErrorAction SilentlyContinue
        if (-not $proc) {
            Start-DiscordPatched
        }
    }

    [System.GC]::Collect()
    exit 0
}

function Toggle-Startup {
    $regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $scriptDir = $PSScriptRoot
    if (-not $scriptDir) { $scriptDir = "$env:USERPROFILE\.vensync" }
    $vbsPath = "$scriptDir\BackgroundStartupCheck.vbs"
    $val = "wscript.exe `"$vbsPath`""

    $exists = (Get-ItemProperty -Path $regKey -Name "VenSyncAutoSetupManager" -ErrorAction SilentlyContinue)
    if ($exists) {
        Remove-ItemProperty -Path $regKey -Name "VenSyncAutoSetupManager" -ErrorAction SilentlyContinue
        Write-Host "Silent Auto-check on Windows Startup disabled." -ForegroundColor Yellow
    } else {
        Set-ItemProperty -Path $regKey -Name "VenSyncAutoSetupManager" -Value $val
        Write-Host "Silent Auto-check on Windows Startup ENABLED." -ForegroundColor Green
        Write-Host "It will run 100% invisible with NO UI on boot, auto-repair Vencord, and auto-close (0 RAM)." -ForegroundColor Cyan
    }
}

# CLI Parameter handling
if ($StartupSilent) {
    Run-SilentStartupCheck
    exit 0
}

if ($Update) {
    Write-Host "Checking for VenSync updates from GitHub..." -ForegroundColor Cyan
    Update-VenSyncFiles
    Write-Host "Updated!" -ForegroundColor Green
    exit 0
}

if ($AutoFix) {
    Write-Host "Running 1-Click Auto Setup..." -ForegroundColor Cyan
    Start-AutoFixPipeline
    Write-Host "Done!" -ForegroundColor Green
    exit 0
}

if ($CheckOnly) {
    Write-BrandHeader
    Show-Diagnostics
    exit 0
}

if ($Launch) {
    Start-DiscordPatched
    exit 0
}

if ($Repair) {
    Repair-VencordPatch
    exit 0
}

if ($InstallVencord) {
    Install-VencordPatch
    exit 0
}

if ($Startup) {
    Toggle-Startup
    exit 0
}

# Interactive Menu (Only shown if opened manually)
do {
    Write-BrandHeader
    Show-Diagnostics

    Write-Host "  [1] Complete 1-Click Auto Setup (Download Discord + Vencord + Patch + Launch)" -ForegroundColor Green
    Write-Host "  [2] Launch Discord (Patched)" -ForegroundColor Cyan
    Write-Host "  [3] Install / Re-hook Vencord Patch" -ForegroundColor White
    Write-Host "  [4] Repair Vencord (Fix after Discord update)" -ForegroundColor White
    Write-Host "  [5] Stop Discord Processes" -ForegroundColor Yellow
    Write-Host "  [6] Toggle Silent Auto-Check on Startup (No UI, Auto-closes, 0 RAM)" -ForegroundColor Magenta
    Write-Host "  [7] Refresh Diagnostics" -ForegroundColor White
    Write-Host "  [8] Update VenSync from GitHub" -ForegroundColor Cyan
    Write-Host "  [0] Exit" -ForegroundColor DarkGray
    Write-Host ""
    $choice = Read-Host " Select an option [0-8]"

    switch ($choice) {
        "1" { Start-AutoFixPipeline; Read-Host "`nPress Enter to return..." }
        "2" { Start-DiscordPatched; Start-Sleep -Seconds 2 }
        "3" { Install-VencordPatch; Read-Host "`nPress Enter to return..." }
        "4" { Repair-VencordPatch; Read-Host "`nPress Enter to return..." }
        "5" { Stop-Process -Name Discord,DiscordCanary,DiscordPTB -Force -ErrorAction SilentlyContinue; Write-Host "Discord stopped." -ForegroundColor Green; Start-Sleep -Seconds 1 }
        "6" { Toggle-Startup; Start-Sleep -Seconds 2 }
        "7" { }
        "8" { Update-VenSyncFiles; Write-Host "Updated from GitHub." -ForegroundColor Green; Start-Sleep -Seconds 2 }
        "0" { exit }
        default { Write-Host "Invalid option" -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
} while ($choice -ne "0")
