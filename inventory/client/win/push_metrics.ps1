# push_metrics.ps1
# Collect client metrics (CPU, temperature, Disk I/O, memory) and HTTP POST
# to rpi4-1. Also saves a local history file.
# Designed to be called every 30 seconds from Task Scheduler.
# Created: 2026-05-09

#Requires -Version 5.1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---- Configuration ----
$ENDPOINT     = if ($env:PUSH_ENDPOINT)     { $env:PUSH_ENDPOINT }     else { 'http://rpi4-1.tsystem.gr.jp/api/push' }
$HISTORY_DIR  = if ($env:PUSH_HISTORY_DIR)  { $env:PUSH_HISTORY_DIR }  else { "$env:APPDATA\push_metrics" }
# Join-Path keeps paths correct on both Windows ('\') and the Linux test host ('/').
$HISTORY_FILE = Join-Path $HISTORY_DIR 'history.ndjson'   # local history (NDJSON)
$LOG_FILE     = Join-Path $HISTORY_DIR 'push_metrics.log' # error log
# MAX_HISTORY / MAX_LOG are env-overridable so unit tests can exercise trimming.
$MAX_HISTORY  = if ($env:PUSH_MAX_HISTORY) { [int]$env:PUSH_MAX_HISTORY } else { 2880 }  # max lines kept (30s * 2880 = 24h)
$MAX_LOG      = if ($env:PUSH_MAX_LOG)     { [int]$env:PUSH_MAX_LOG }     else { 5000 }  # max log lines

# ---- Helper functions ----

# Append a timestamped message to the log file.
function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format 'yyyyMMdd.HHmmss'
    "$ts`: $Message" | Add-Content -Path $LOG_FILE -Encoding UTF8 -ErrorAction SilentlyContinue
}

# Trim the log file to MAX_LOG lines if it exceeds the limit.
function Trim-Log {
    if (-not (Test-Path $LOG_FILE)) { return }
    $lines = @(Get-Content $LOG_FILE -Encoding UTF8 -ErrorAction SilentlyContinue)
    if ($lines.Count -gt $MAX_LOG) {
        $lines[-$MAX_LOG..-1] | Set-Content $LOG_FILE -Encoding UTF8
    }
}

# Return CPU usage (%) using a 1-second Get-Counter sample.
function Get-CpuPercent {
    $sample = (Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1).CounterSamples
    [math]::Round($sample.CookedValue, 1)
}

# Return CPU temperature (Celsius) via WMI MSAcpi_ThermalZoneTemperature.
# Returns 0.0 if the BIOS does not expose thermal zones.
function Get-CpuTempC {
    try {
        $zones = Get-WmiObject MSAcpi_ThermalZoneTemperature `
            -Namespace 'root/wmi' -ErrorAction Stop
        if ($null -eq $zones) { return 0.0 }
        # CurrentTemperature is in units of 1/10 Kelvin
        $maxK10 = ($zones | Measure-Object CurrentTemperature -Maximum).Maximum
        [math]::Round(($maxK10 - 2732) / 10.0, 1)
    } catch {
        Write-Log "WARN CPU temp unavailable: $_"
        0.0
    }
}

# Return total Disk I/O (bytes/s, read + write) using a 1-second Get-Counter sample.
function Get-DiskRwBps {
    $samples = (Get-Counter @(
        '\PhysicalDisk(_Total)\Disk Read Bytes/sec',
        '\PhysicalDisk(_Total)\Disk Write Bytes/sec'
    ) -SampleInterval 1).CounterSamples
    $read  = ($samples | Where-Object { $_.Path -like '*Read*'  }).CookedValue
    $write = ($samples | Where-Object { $_.Path -like '*Write*' }).CookedValue
    [long]($read + $write)
}

# Return memory info hashtable: pct (usage %) and total_kb (total RAM in KB).
# Single WMI call for TotalPhysicalMemory covers both values.
function Get-MemInfo {
    $totalBytes = (Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory
    $totalMB    = [math]::Round($totalBytes / 1MB, 0)
    $availMB    = (Get-Counter '\Memory\Available MBytes' -SampleInterval 1).CounterSamples.CookedValue
    if ($totalMB -le 0) { return @{ pct = 0.0; total_kb = 0 } }
    @{
        pct      = [math]::Round(($totalMB - $availMB) / $totalMB * 100, 1)
        total_kb = [long]($totalBytes / 1024)
    }
}

# Main: collect metrics, save local history, POST to rpi4-1.
function Main {
    if (-not (Test-Path $HISTORY_DIR)) {
        New-Item -ItemType Directory -Path $HISTORY_DIR -Force | Out-Null
    }

    $cpuPct  = Get-CpuPercent  # blocks ~1s (Get-Counter sampling)
    $tempC   = Get-CpuTempC
    $diskRw  = Get-DiskRwBps   # blocks ~1s
    $memInfo = Get-MemInfo     # blocks ~1s

    $hostname = $env:COMPUTERNAME.ToLower()
    $ts       = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')

    $payload = [ordered]@{
        hostname  = $hostname
        ts        = $ts
        cpu       = $cpuPct
        temp      = $tempC
        disk_rw   = $diskRw
        mem       = $memInfo.pct
        mem_total = $memInfo.total_kb
    }
    $json = $payload | ConvertTo-Json -Compress

    # Append to local history; trim to MAX_HISTORY lines.
    Add-Content -Path $HISTORY_FILE -Value $json -Encoding UTF8
    $lines = @(Get-Content $HISTORY_FILE -Encoding UTF8 -ErrorAction SilentlyContinue)
    if ($lines.Count -gt $MAX_HISTORY) {
        $lines[-$MAX_HISTORY..-1] | Set-Content $HISTORY_FILE -Encoding UTF8
    }

    # POST to rpi4-1; log warning on failure but continue.
    try {
        Invoke-RestMethod -Method Post -Uri $ENDPOINT `
            -ContentType 'application/json' `
            -Body $json `
            -TimeoutSec 10 | Out-Null
    } catch {
        Write-Log "WARN POST failed: $_"
    }

    Trim-Log
}

# Run Main only when executed directly. When the script is dot-sourced for unit
# testing ($MyInvocation.InvocationName is '.'), only the functions are loaded.
if ($MyInvocation.InvocationName -ne '.') {
    Main
}
