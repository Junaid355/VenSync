"""
VenSync - Discord & Vencord Auto-Detector & Setup Suite - Core Engine
Handles Discord detection, Vencord CLI automation, background repair, downloads, and startup registry.
"""

import os
import sys
import json
import time
import glob
import shutil
import urllib.request
import subprocess
import winreg
from typing import Dict, Any, Callable, Optional

# Standard Paths
APPDATA = os.environ.get("APPDATA", "")
LOCALAPPDATA = os.environ.get("LOCALAPPDATA", "")
USERPROFILE = os.environ.get("USERPROFILE", "")

DISCORD_UPDATE_PATHS = [
    os.path.join(LOCALAPPDATA, "Discord", "Update.exe"),
    os.path.join(LOCALAPPDATA, "DiscordCanary", "Update.exe"),
    os.path.join(LOCALAPPDATA, "DiscordPTB", "Update.exe"),
]

DISCORD_DOWNLOAD_URL = "https://discord.com/api/download?platform=win"
VENCORD_CLI_URL = "https://github.com/Vendicated/VencordInstaller/releases/latest/download/VencordInstallerCli.exe"

REG_RUN_KEY = r"Software\Microsoft\Windows\CurrentVersion\Run"
REG_APP_NAME = "VenSyncAutoSetupManager"


class DiscordDetector:
    """Performs real-time diagnostics on Discord and Vencord installations."""

    @staticmethod
    def get_discord_launcher_path() -> Optional[str]:
        for path in DISCORD_UPDATE_PATHS:
            if os.path.exists(path):
                return path
        return None

    @staticmethod
    def is_discord_installed() -> bool:
        return DiscordDetector.get_discord_launcher_path() is not None

    @staticmethod
    def is_discord_running() -> bool:
        try:
            cmd = ['powershell', '-NoProfile', '-Command', '(Get-Process -Name Discord,DiscordCanary,DiscordPTB -ErrorAction SilentlyContinue).Count']
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
            count_str = result.stdout.strip()
            return int(count_str) > 0 if count_str.isdigit() else False
        except Exception:
            return False

    @staticmethod
    def is_vencord_files_present() -> bool:
        vencord_dir = os.path.join(APPDATA, "Vencord", "dist")
        if os.path.exists(vencord_dir) and (
            os.path.exists(os.path.join(vencord_dir, "vencord.asar")) or
            os.path.exists(os.path.join(vencord_dir, "index.js"))
        ):
            return True
        return False

    @staticmethod
    def is_vencord_patched() -> bool:
        """Checks if Vencord is currently injected into Discord's desktop_core."""
        # Find desktop_core index.js
        pattern = os.path.join(LOCALAPPDATA, "Discord*", "app-*", "modules", "discord_desktop_core-*", "discord_desktop_core", "index.js")
        matches = glob.glob(pattern)
        for path in matches:
            try:
                with open(path, "r", encoding="utf-8", errors="ignore") as f:
                    content = f.read(500)
                    if "vencord" in content.lower() or "patcher" in content.lower():
                        return True
            except Exception:
                pass
        return False

    @staticmethod
    def is_startup_enabled() -> bool:
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, REG_RUN_KEY, 0, winreg.KEY_READ) as key:
                val, _ = winreg.QueryValueEx(key, REG_APP_NAME)
                return bool(val)
        except Exception:
            return False

    @classmethod
    def get_full_status(cls) -> Dict[str, Any]:
        discord_launcher = cls.get_discord_launcher_path()
        return {
            "discord": {
                "installed": discord_launcher is not None,
                "path": discord_launcher,
                "running": cls.is_discord_running(),
            },
            "vencord": {
                "installed": cls.is_vencord_files_present(),
                "patched": cls.is_vencord_patched(),
            },
            "system": {
                "startup_enabled": cls.is_startup_enabled(),
                "timestamp": time.time(),
            }
        }


class VencordManager:
    """Executes installation, patching, updates, and process management for Discord & Vencord."""

    def __init__(self, log_callback: Optional[Callable[[str, str], None]] = None):
        self.log_callback = log_callback or self._default_log

    def _log(self, msg: str, level: str = "info"):
        self.log_callback(msg, level)

    def _default_log(self, msg: str, level: str):
        prefix = {
            "info": "[INFO]",
            "success": "[SUCCESS]",
            "warning": "[WARN]",
            "error": "[ERROR]"
        }.get(level, "[LOG]")
        print(f"{prefix} {msg}")

    def kill_discord(self) -> bool:
        """Terminates running Discord processes before modifying files."""
        self._log("Stopping running Discord instances...", "info")
        try:
            cmd = "Stop-Process -Name Discord,DiscordCanary,DiscordPTB -Force -ErrorAction SilentlyContinue"
            subprocess.run(["powershell", "-NoProfile", "-Command", cmd], capture_output=True, timeout=10)
            time.sleep(1)
            self._log("Discord processes stopped.", "success")
            return True
        except Exception as e:
            self._log(f"Failed to stop Discord: {e}", "warning")
            return False

    def download_and_install_discord(self) -> bool:
        """Downloads official Discord installer and executes it."""
        self._log("Initiating official Discord setup...", "info")
        temp_dir = os.path.join(LOCALAPPDATA, "Temp")
        installer_path = os.path.join(temp_dir, "DiscordSetup.exe")

        try:
            self._log(f"Downloading Discord from {DISCORD_DOWNLOAD_URL} ...", "info")
            urllib.request.urlretrieve(DISCORD_DOWNLOAD_URL, installer_path)
            self._log(f"Installer downloaded to {installer_path}", "success")

            self._log("Running Discord installer (please wait a moment)...", "info")
            subprocess.Popen([installer_path], creationflags=0)

            # Wait for Discord to be installed
            max_wait = 90
            start_t = time.time()
            installed = False

            while time.time() - start_t < max_wait:
                if DiscordDetector.is_discord_installed():
                    installed = True
                    break
                time.sleep(2)

            if installed:
                self._log("Discord successfully installed!", "success")
                return True
            else:
                self._log("Discord installer started, installation pending.", "warning")
                return True
        except Exception as e:
            self._log(f"Error downloading/installing Discord: {e}", "error")
            return False

    def get_or_download_vencord_cli(self) -> Optional[str]:
        """Ensures VencordInstallerCli.exe is available in Temp directory."""
        temp_dir = os.path.join(LOCALAPPDATA, "Temp")
        cli_path = os.path.join(temp_dir, "VencordInstallerCli.exe")

        if not os.path.exists(cli_path) or (time.time() - os.path.getmtime(cli_path) > 86400 * 7):
            try:
                self._log("Downloading latest VencordInstallerCli.exe...", "info")
                urllib.request.urlretrieve(VENCORD_CLI_URL, cli_path)
                self._log("VencordInstallerCli downloaded.", "success")
            except Exception as e:
                self._log(f"Failed to download Vencord CLI: {e}", "error")
                return None
        return cli_path

    def install_or_patch_vencord(self) -> bool:
        """Installs/patches Vencord into Discord."""
        cli_path = self.get_or_download_vencord_cli()
        if not cli_path:
            return False

        self.kill_discord()
        self._log("Injecting Vencord into Discord...", "info")
        try:
            proc = subprocess.run([cli_path, "-install", "-branch", "auto"], capture_output=True, text=True, timeout=30)
            if proc.returncode == 0 or DiscordDetector.is_vencord_patched():
                self._log("Vencord successfully installed and patched into Discord!", "success")
                return True
            else:
                self._log(f"Installer output: {proc.stdout} {proc.stderr}", "warning")
                # Fallback to repair
                return self.repair_vencord()
        except Exception as e:
            self._log(f"Error patching Vencord: {e}", "error")
            return False

    def repair_vencord(self) -> bool:
        """Re-hooks Vencord when Discord auto-updates."""
        cli_path = self.get_or_download_vencord_cli()
        if not cli_path:
            return False

        self.kill_discord()
        self._log("Re-patching Vencord into Discord (Repair mode)...", "info")
        try:
            proc = subprocess.run([cli_path, "-repair", "-branch", "auto"], capture_output=True, text=True, timeout=30)
            if proc.returncode == 0 or DiscordDetector.is_vencord_patched():
                self._log("Vencord re-hooked successfully!", "success")
                return True
            else:
                self._log(f"Repair output: {proc.stdout} {proc.stderr}", "warning")
                return False
        except Exception as e:
            self._log(f"Repair failed: {e}", "error")
            return False

    def launch_discord(self) -> bool:
        """Launches Discord application."""
        launcher = DiscordDetector.get_discord_launcher_path()
        if not launcher:
            self._log("Discord executable not found! Cannot launch.", "error")
            return False

        self._log(f"Launching Discord from {launcher}...", "info")
        try:
            subprocess.Popen([launcher, "--processStart", "Discord.exe"], close_fds=True)
            self._log("Discord launched!", "success")
            return True
        except Exception as e:
            self._log(f"Failed to launch Discord: {e}", "error")
            return False

    def set_startup_enabled(self, enabled: bool) -> bool:
        """Configures Windows Startup Registry entry to run silently on boot (0 RAM)."""
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, REG_RUN_KEY, 0, winreg.KEY_SET_VALUE) as key:
                if enabled:
                    script_dir = os.path.dirname(os.path.abspath(__file__))
                    vbs_path = os.path.join(script_dir, "BackgroundStartupCheck.vbs")
                    val_str = f'wscript.exe "{vbs_path}"'
                    winreg.SetValueEx(key, REG_APP_NAME, 0, winreg.REG_SZ, val_str)
                    self._log("Silent background check on Windows Startup enabled (auto-closes, 0 RAM).", "success")
                else:
                    try:
                        winreg.DeleteValue(key, REG_APP_NAME)
                        self._log("Silent auto-check on Windows Startup disabled.", "info")
                    except FileNotFoundError:
                        pass
            return True
        except Exception as e:
            self._log(f"Failed to update startup registry: {e}", "error")
            return False

    def auto_setup_all(self) -> Dict[str, Any]:
        """
        Complete 1-Click Pipeline:
        1. Checks Discord -> Downloads & Installs if missing
        2. Checks Vencord -> Downloads & Patches if missing or unpatched
        3. Launches patched Discord
        """
        self._log("=== Starting Automated Discord & Vencord Full Setup ===", "info")

        # Step 1: Discord
        if not DiscordDetector.is_discord_installed():
            self._log("[Step 1/3] Discord is not installed. Initiating download...", "info")
            if not self.download_and_install_discord():
                self._log("Discord installation failed. Aborting pipeline.", "error")
                return {"success": False, "step": "discord"}
        else:
            self._log("[Step 1/3] Discord is already installed.", "success")

        # Step 2: Vencord
        if not DiscordDetector.is_vencord_patched():
            self._log("[Step 2/3] Vencord is not patched into Discord. Installing & Patching...", "info")
            if not self.install_or_patch_vencord():
                self._log("Vencord patching failed.", "error")
                return {"success": False, "step": "vencord"}
        else:
            self._log("[Step 2/3] Vencord is already patched and ready.", "success")

        # Step 3: Launch
        self._log("[Step 3/3] Launching patched Discord...", "info")
        self.launch_discord()

        self._log("=== Automated Setup Completed Successfully! ===", "success")
        return {"success": True, "step": "completed"}


if __name__ == "__main__":
    print(json.dumps(DiscordDetector.get_full_status(), indent=2))
