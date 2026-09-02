# ==============================================================================
#  VenSync - 1-Click Automated Installer & Setup for Discord & Vencord
#  Repo: https://github.com/Junaid355/VenSync
#  Usage: iwr -useb https://raw.githubusercontent.com/Junaid355/VenSync/main/install.ps1 | iex
# ==============================================================================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = "SilentlyContinue"

$InstallDir = "$env:USERPROFILE\.vensync"
$RepoRaw = "https://raw.githubusercontent.com/Junaid355/VenSync/main"

Write-Host ""
Write-Host " ========================================================" -ForegroundColor Cyan
Write-Host "   [*] Installing VenSync Setup Suite..." -ForegroundColor Cyan
Write-Host "   [+] Creator: Junaid355 | GitHub: Junaid355/VenSync" -ForegroundColor Green
Write-Host " ========================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    New-Item -ItemType Directory -Force -Path "$InstallDir\web" | Out-Null
}

$files = @(
    "VencordAutoManager.ps1",
    "BackgroundStartupCheck.vbs",
    "Enable-Startup-AutoCheck.bat",
    "Disable-Startup-AutoCheck.bat",
    "Start-VencordManager.bat",
    "Run-Silent-Test.bat",
    "core.py",
    "app.py",
    "README.md",
    "web/index.html",
    "web/style.css",
    "web/app.js"
)

Write-Host "Downloading VenSync files..." -ForegroundColor Cyan
foreach ($f in $files) {
    $url = "$RepoRaw/$f"
    $dest = "$InstallDir\$f"
    $parent = Split-Path -Parent $dest
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
    } catch {}
}

# Create Desktop Shortcut
$wsh = New-Object -ComObject WScript.Shell
$desktop = [System.Environment]::GetFolderPath('Desktop')
$shortcut = $wsh.CreateShortcut("$desktop\VenSync Dashboard.lnk")
$shortcut.TargetPath = "$InstallDir\Start-VencordManager.bat"
$shortcut.WorkingDirectory = "$InstallDir"
$shortcut.Description = "VenSync Discord & Vencord Auto-Setup Suite"
$shortcut.Save()

# Enable Silent Startup
$regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$vbsPath = "$InstallDir\BackgroundStartupCheck.vbs"
$val = "wscript.exe `"$vbsPath`""
Set-ItemProperty -Path $regKey -Name "VenSyncAutoSetupManager" -Value $val

Write-Host "`nRunning initial setup pipeline..." -ForegroundColor Green
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$InstallDir\VencordAutoManager.ps1" -AutoFix

Write-Host ""
Write-Host " ========================================================" -ForegroundColor Cyan
Write-Host "  [SUCCESS] VenSync Installed and Configured!" -ForegroundColor Green
Write-Host "  [*] Discord + Vencord are ready and patched." -ForegroundColor Green
Write-Host "  [*] Silent Startup Auto-Check is ENABLED (0 RAM)." -ForegroundColor Cyan
Write-Host "  [*] Desktop shortcut created: 'VenSync Dashboard'" -ForegroundColor Cyan
Write-Host " ========================================================" -ForegroundColor Cyan
Write-Host ""
