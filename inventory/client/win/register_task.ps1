# register_task.ps1
# Register push_metrics.ps1 as a Windows Scheduled Task.
# Must be run as Administrator.
# Created: 2026-05-09

#Requires -Version 5.1
#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---- Configuration ----
$TASK_NAME    = 'push_metrics'
$TASK_FOLDER  = '\SecurityMonitor'
$SCRIPT_PATH  = "$PSScriptRoot\push_metrics.ps1"
$INTERVAL_MIN = 1   # Task Scheduler minimum repetition interval is 1 minute (PT30S not supported)

# ---- Create task folder via COM (New-ScheduledTaskFolder not available in PS 5.1) ----
$scheduler = New-Object -ComObject Schedule.Service
$scheduler.Connect()
$rootFolder = $scheduler.GetFolder('\')
try {
    $rootFolder.GetFolder($TASK_FOLDER) | Out-Null
} catch {
    $rootFolder.CreateFolder($TASK_FOLDER) | Out-Null
    Write-Host "Folder created: $TASK_FOLDER"
}

# ---- Remove existing task (for re-registration) ----
try {
    Unregister-ScheduledTask -TaskName $TASK_NAME `
        -TaskPath $TASK_FOLDER -Confirm:$false -ErrorAction Stop
    Write-Host "Existing task removed."
} catch {
    # Ignore if not found
}

# ---- Action ----
# Use wscript.exe + run_hidden.vbs to launch push_metrics.ps1 with window style 0.
# powershell.exe -WindowStyle Hidden still causes a brief window flash via Task Scheduler;
# WScript.Shell.Run(..., 0, True) is completely invisible.
$VBS_PATH = "$PSScriptRoot\run_hidden.vbs"
$action = New-ScheduledTaskAction `
    -Execute 'wscript.exe' `
    -Argument "`"$VBS_PATH`""

# ---- Triggers ----
# Note: Windows Task Scheduler minimum repetition interval is 1 minute (PT30S is invalid).
# Two triggers are used so that the task starts immediately without requiring logoff/logon:
#   1. Once: fires 15 seconds after registration, repeats every INTERVAL_MIN indefinitely.
#   2. AtLogon: fires on next logon, repeats every INTERVAL_MIN indefinitely.
# MultipleInstances=IgnoreNew prevents duplicate execution when both triggers overlap.

$triggerOnce = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date).AddSeconds(15) `
    -RepetitionInterval (New-TimeSpan -Minutes $INTERVAL_MIN)

$repPat = $triggerOnce.Repetition
$triggerLogon = New-ScheduledTaskTrigger -AtLogOn
$triggerLogon.Repetition = $repPat

# ---- Settings ----
$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 2) `
    -StartWhenAvailable `
    -DontStopIfGoingOnBatteries `
    -AllowStartIfOnBatteries `
    -MultipleInstances IgnoreNew

# ---- Principal: run as current interactive user ----
$principal = New-ScheduledTaskPrincipal `
    -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) `
    -LogonType Interactive `
    -RunLevel Highest

# ---- Register ----
Register-ScheduledTask `
    -TaskName  $TASK_NAME `
    -TaskPath  $TASK_FOLDER `
    -Action    $action `
    -Trigger   @($triggerOnce, $triggerLogon) `
    -Settings  $settings `
    -Principal $principal `
    -Force | Out-Null

Write-Host "Task registered: ${TASK_FOLDER}\${TASK_NAME}"
Write-Host "Interval       : ${INTERVAL_MIN} minute(s)"
Write-Host "Script         : $SCRIPT_PATH"
