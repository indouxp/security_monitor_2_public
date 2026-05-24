' run_hidden.vbs
' Launch push_metrics.ps1 via WScript.Shell with window style 0 (completely hidden).
' This prevents the brief PowerShell window flash that occurs when Task Scheduler
' launches powershell.exe directly, even with -WindowStyle Hidden.
Dim WshShell, script
script = CreateObject("Scripting.FileSystemObject").GetParentFolderName( _
    WScript.ScriptFullName) & "\push_metrics.ps1"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -NonInteractive -ExecutionPolicy Bypass -File """ _
    & script & """", 0, True
Set WshShell = Nothing
