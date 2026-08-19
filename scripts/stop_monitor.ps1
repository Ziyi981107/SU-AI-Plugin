$ErrorActionPreference = "Continue"
$existing = Get-Process powershell -ErrorAction SilentlyContinue
$killed = 0
foreach ($p in $existing) {
    try {
        $cmdline = (Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)" -ErrorAction SilentlyContinue).CommandLine
        if ($cmdline -and $cmdline -match "prompt_monitor\.ps1") {
            Stop-Process -Id $p.Id -Force
            $killed++
            Write-Output "killed PID=$($p.Id)"
        }
    } catch {}
}
Write-Output "killed=$killed monitor processes"
Get-Process powershell -ErrorAction SilentlyContinue | ForEach-Object {
    $cmdline = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine
    if ($cmdline -and $cmdline -match "prompt_monitor") {
        Write-Output "still running: PID=$($_.Id)"
    }
}
