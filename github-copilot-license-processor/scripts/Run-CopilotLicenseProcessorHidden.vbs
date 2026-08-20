Option Explicit

If WScript.Arguments.Count <> 3 Then
    WScript.Quit 2
End If

Dim shell
Dim powerShellPath
Dim processorScript
Dim configPath
Dim command

Set shell = CreateObject("WScript.Shell")
powerShellPath = WScript.Arguments(0)
processorScript = WScript.Arguments(1)
configPath = WScript.Arguments(2)

command = Quote(powerShellPath) & _
    " -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File " & _
    Quote(processorScript) & " -ConfigPath " & Quote(configPath)

WScript.Quit shell.Run(command, 0, True)

Function Quote(value)
    Quote = Chr(34) & value & Chr(34)
End Function
