Set objShell = CreateObject("Wscript.Shell")
objShell.Run "powershell.exe -ExecutionPolicy Bypass -NonInteractive -File ""C:\Users\User\.agents\skills\scheduler\scripts\Restart-ResourceHeavyProcesses.ps1""", 0, True
