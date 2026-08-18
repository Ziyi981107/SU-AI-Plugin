# Restart monitor: kill any existing, start fresh
$ErrorActionPreference = "Continue"

# Kill any existing prompt_monitor processes
$existing = Get-Process powershell -ErrorAction SilentlyContinue
foreach ($p in $existing) {
    try {
        $cmdline = (Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)" -ErrorAction SilentlyContinue).CommandLine
        if ($cmdline -and $cmdline -match "prompt_monitor\.ps1") {
            Stop-Process -Id $p.Id -Force
            Write-Output "killed PID=$($p.Id)"
        }
    } catch {}
}

Start-Sleep -Seconds 1

# Ensure data/_check_tmp exists
$dir = "D:\Projects\SU-AI-Plugin\data\_check_tmp"
if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

# Start monitor detached
Start-Process -FilePath "powershell.exe" `
    -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-WindowStyle","Hidden","-File","D:\Projects\SU-AI-Plugin\scripts\prompt_monitor.ps1" `
    -WorkingDirectory "D:\Projects\SU-AI-Plugin" `
    -RedirectStandardOutput "D:\Projects\SU-AI-Plugin\data\_check_tmp\prompt_monitor.stdout" `
    -RedirectStandardError "D:\Projects\SU-AI-Plugin\data\_check_tmp\prompt_monitor.stderr" `
    | Out-Null

Write-Output "started monitor"
Start-Sleep -Seconds 3

# Show status
Get-Process powershell -ErrorAction SilentlyContinue | ForEach-Object {
    $cmdline = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine
    if ($cmdline -and $cmdline -match "prompt_monitor") {
        Write-Output "monitor PID=$($_.Id) start=$($_.StartTime)"
    }
}

Write-Output "---log---"
if (Test-Path "D:\Projects\SU-AI-Plugin\data\_check_tmp\prompt_monitor.log") {
    Get-Content "D:\Projects\SU-AI-Plugin\data\_check_tmp\prompt_monitor.log"
} else {
    Write-Output "(no log file yet)"
}
Write-Output "---state---"
if (Test-Path "D:\Projects\SU-AI-Plugin\data\_check_tmp\prompt_monitor_state.json") {
    Get-Content "D:\Projects\SU-AI-Plugin\data\_check_tmp\prompt_monitor_state.json"
} else {
    Write-Output "(no state file yet)"
}
