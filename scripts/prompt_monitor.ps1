# scripts/prompt_monitor.ps1
# Lightweight 5-minute polling monitor for Codex/Prompt directory.
# Per Cicada 2026-08-18 long-term-autonomy protocol:
#   - Polls every 5 minutes
#   - Detects new CODEX_REVIEW_*, CODEX_GUIDANCE_*, OWNER_REPORT_* files
#   - Waits 60s for write stability before reading
#   - Records processed files in state.json (NEVER re-processes)
#   - Writes log events to log file (no console output, no stdout spam)
#   - Quietly exits the loop on no changes (does not consume Agent context)
#
# Launch detached:
#   powershell -WindowStyle Hidden -File D:\Projects\SU-AI-Plugin\scripts\prompt_monitor.ps1
# Stop:
#   Get-Process powershell | Where-Object { $_.MainWindowTitle -eq '' } | ...
#   or simply: taskkill /IM powershell.exe /FI "WINDOWTITLE eq Prompt Monitor*"

$ErrorActionPreference = "Continue"

$ProjectRoot      = "D:\Projects\SU-AI-Plugin"
$PromptDir        = Join-Path $ProjectRoot "Prompt"
$StateFile        = Join-Path $ProjectRoot "data\_check_tmp\prompt_monitor_state.json"
$LogFile          = Join-Path $ProjectRoot "data\_check_tmp\prompt_monitor.log"
$IntervalSeconds  = 300
$StabilitySeconds = 60
$AllowedPrefixes  = @("CODEX_REVIEW_", "CODEX_GUIDANCE_", "OWNER_REPORT_")

# --- helpers ------------------------------------------------------------

function Write-Log {
    param([string]$Message)
    $timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
    $line = "[$timestamp] $Message"
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Load-State {
    if (-not (Test-Path $StateFile)) {
        return @{ processed = @{} }
    }
    try {
        $raw = Get-Content -Path $StateFile -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return @{ processed = @{} }
        }
        $obj = $raw | ConvertFrom-Json
        $processed = @{}
        if ($obj.PSObject.Properties.Name -contains 'processed' -and $obj.processed) {
            foreach ($prop in $obj.processed.PSObject.Properties) {
                $processed[$prop.Name] = [double]$prop.Value
            }
        }
        return @{ processed = $processed }
    } catch {
        Write-Log ("state read failed (assuming empty): " + $_.Exception.Message)
        return @{ processed = @{} }
    }
}

function Save-State {
    param([hashtable]$State)
    $dir = Split-Path -Parent $StateFile
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $json = @{ processed = $State.processed } | ConvertTo-Json -Depth 5
    Set-Content -Path $StateFile -Value $json -Encoding UTF8
}

function Get-RelevantFiles {
    if (-not (Test-Path $PromptDir)) {
        return @{}
    }
    $files = @{}
    Get-ChildItem -Path $PromptDir -File -ErrorAction SilentlyContinue | ForEach-Object {
        foreach ($prefix in $AllowedPrefixes) {
            if ($_.Name.StartsWith($prefix)) {
                $files[$_.Name] = $_.LastWriteTimeUtc.Ticks
                break
            }
        }
    }
    return $files
}

function Test-Stable {
    param([double]$MtimeTicks)
    $mtime = [datetime]::new([long]$MtimeTicks)
    $now = [datetime]::UtcNow
    $ageSec = ($now - $mtime).TotalSeconds
    return ($ageSec -ge $StabilitySeconds)
}

# --- main loop ----------------------------------------------------------

Write-Log "=== monitor started (PID=$PID) ==="

while ($true) {
    try {
        $state = Load-State
        $processed = $state.processed
        $files = Get-RelevantFiles

        $candidates = @()
        foreach ($name in $files.Keys) {
            if ($processed.ContainsKey($name)) { continue }
            if (Test-Stable -MtimeTicks $files[$name]) {
                $candidates += $name
            }
        }

        if ($candidates.Count -gt 0) {
            # belt-and-suspenders: wait additional stability window then re-check
            Start-Sleep -Seconds $StabilitySeconds
            $files2 = Get-RelevantFiles
            $confirmed = @()
            foreach ($name in $candidates) {
                if ($files2.ContainsKey($name)) {
                    if (Test-Stable -MtimeTicks $files2[$name]) {
                        $confirmed += $name
                    }
                }
            }

            if ($confirmed.Count -gt 0) {
                Write-Log ("[NEW] " + ($confirmed -join ", "))
                foreach ($name in $confirmed) {
                    if ($processed.ContainsKey($name)) { continue }
                    $processed[$name] = $files2[$name]
                    Write-Log ("processed: " + $name)
                }
                $state.processed = $processed
                Save-State -State $state
                Write-Log ("state updated; total processed: " + $processed.Count)
            }
        }

        # quiet sleep — no output unless something changed
        Start-Sleep -Seconds $IntervalSeconds
    } catch {
        Write-Log ("error: " + $_.Exception.Message)
        Start-Sleep -Seconds $IntervalSeconds
    }
}
