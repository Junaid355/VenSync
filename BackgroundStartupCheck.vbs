' VenSync Silent Startup Launcher
' Runs the startup check completely invisible in background and terminates immediately (0 RAM).
Set objShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")
strDir = objFSO.GetParentFolderName(WScript.ScriptFullName)
strPsScript = strDir & "\VencordAutoManager.ps1"
strCommand = "powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File """ & strPsScript & """ -StartupSilent"

' Run invisible (0 = hidden window)
objShell.Run strCommand, 0, True
