# 🚀 VenSync — Automated Discord & Vencord Setup Suite

[![GitHub Stars](https://img.shields.io/github/stars/Junaid355/VenSync?style=for-the-badge&color=5865F2)](https://github.com/Junaid355/VenSync)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%2F%2011-blue?style=for-the-badge)](https://github.com/Junaid355/VenSync)
[![Zero RAM](https://img.shields.io/badge/Residual%20RAM-0%20MB-green?style=for-the-badge)](https://github.com/Junaid355/VenSync)

An ultra-lightweight, automated Windows application and background utility that manages your Discord and Vencord setup.

If Discord is missing, updated, or unpatched, VenSync **automatically downloads official Discord, injects latest Vencord, repairs patches after Discord updates, and launches your patched player**.

---

## ⚡ 1-Click Install (Powershell)

Open PowerShell and paste this single command:

```powershell
iwr -useb https://raw.githubusercontent.com/Junaid355/VenSync/main/install.ps1 | iex
```

> **What this command does:**
> 1. Auto-downloads and configures VenSync in your user profile.
> 2. Automatically downloads & installs official Discord if missing.
> 3. Injects latest Vencord into Discord.
> 4. Enables the silent zero-RAM startup check on boot (auto-repairs on Discord updates).
> 5. Launches patched Discord.
> 6. Creates a `VenSync Dashboard` shortcut on your Desktop.

---

## 🌟 Key Features

- 🤫 **100% Silent Background Startup (0 MB Residual RAM)**:
  - On PC boot, runs silently in the background with **NO UI or terminal popups**.
  - Checks in `<100ms`, verifies/repairs Vencord, starts Discord, and terminates immediately to consume **0 MB of RAM**.
- 🔧 **Auto-Repair on Discord Updates**:
  - Automatically detects when Discord auto-updates and re-hooks Vencord silently (`VencordInstallerCli.exe -repair`).
  - Auto-updates Vencord and VenSync directly from GitHub.
- 📦 **1-Click Missing Components Installer**:
  - Automatically fetches official Discord (`DiscordSetup.exe`).
  - Automatically injects Vencord with one click.
- 🖥️ **Optional Modern Discord Dark Dashboard**:
  - Open `VenSync Dashboard` whenever you want a visual UI with live diagnostic badges, action buttons, and live terminal logs.

---

## 🚀 Usage & Commands

### 1. Manual GUI Dashboard
Double-click `Start-VencordManager.bat` or run:
```powershell
python app.py
```

### 2. Standalone PowerShell Utility
- **Interactive Menu**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\VencordAutoManager.ps1
  ```
- **1-Click Auto Setup**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\VencordAutoManager.ps1 -AutoFix
  ```
- **Silent Background Run (No UI, Auto-close)**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\VencordAutoManager.ps1 -StartupSilent
  ```
- **Repair Vencord**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\VencordAutoManager.ps1 -Repair
  ```

---

## 🛠️ Quick Files & Toggles

| Shortcut | Action |
| :--- | :--- |
| `Run-Silent-Test.bat` | Tests the invisible background check (No UI, auto-closes). |
| `Enable-Startup-AutoCheck.bat` | Enables silent startup auto-check on Windows boot. |
| `Disable-Startup-AutoCheck.bat` | Disables startup auto-check. |
| `Start-VencordManager.bat` | Opens the interactive visual UI dashboard. |

---

## 👤 Author & Credits

- Created by **[Junaid355](https://github.com/Junaid355)**
- Powered by [Vencord](https://github.com/Vendicated/Vencord) & [VencordInstaller](https://github.com/Vendicated/VencordInstaller)
