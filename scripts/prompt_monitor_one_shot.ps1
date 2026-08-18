# scripts/prompt_monitor_one_shot.ps1
# One-shot variant: checks Prompt/ once, updates state, exits.
# Use this in agent turns to learn the current state quickly.
#
# Usage: powershell -ExecutionPolicy Bypass -File scripts\prompt_monitor_one_shot.ps1

$ErrorActionPreference = "Continue"

$ProjectRoot      = "D:\Projects\SU-AI-Plugin"
$PromptDir        = Join-Path $ProjectRoot "Prompt"
$StateFile        = Join-Path $ProjectRoot "data\_check_tmp\prompt_monitor_state.json"
$LogFile          = Join-Path $ProjectRoot "data\_check_tmp\prompt_monitor.log"
$StabilitySeconds = 60
$AllowedPrefixes  = @("CODEX_REVIEW_", "CODEX_GUIDANCE_", "OWNER_REPORT_")

function Write-Log {
    param([string]$Message)
    $timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
    Add-Content -Path $LogFile -Value "[$timestamp] [one-shot] $Message" -Encoding UTF8
}

function Load-State {
    if (-not (Test-Path $StateFile)) { return @{ processed = @{} } }
    try {
        $raw = Get-Content -Path $StateFile -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) { return @{ processed = @{} } }
        $obj = $raw | ConvertFrom-Json
        $processed = @{}
        if ($obj.PSObject.Properties.Name -contains 'processed' -and $obj.processed) {
            foreach ($prop in $obj.processed.PSObject.Properties) {
                $processed[$prop.Name] = [double]$prop.Value
            }
        }
        return @{ processed = $processed }
    } catch {
        return @{ processed = @{} }
    }
}

function Save-State {
    param([hashtable]$State)
    $dir = Split-Path -Parent $StateFile
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $json = @{ processed = $State.processed } | ConvertTo-Json -Depth 5
    Set-Content -Path $StateFile -Value $json -Encoding UTF8
}

function Get-RelevantFiles {
    if (-not (Test-Path $PromptDir)) { return @{} }
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
    $age = ([datetime]::UtcNow - $mtime).TotalSeconds
    return ($age -ge $StabilitySeconds)
}

$state = Load-State
$processed = $state.processed
$files = Get-RelevantFiles

$newObjs = @()
foreach ($name in $files.Keys) {
    if ($processed.ContainsKey($name)) { continue }
    if (Test-Stable -MtimeTicks $files[$name]) {
        $newObjs += [PSCustomObject]@{
            name  = $name
            mtime = $files[$name]
        }
    }
}

if ($newObjs.Count -eq 0) {
    Write-Output "no new files"
    exit 0
}

Write-Log ("[NEW] " + (($newObjs | ForEach-Object { $_.name }) -join ", "))
foreach ($obj in $newObjs) {
    if ($processed.ContainsKey($obj.name)) { continue }
    $processed[$obj.name] = $obj.mtime
}
$state.processed = $processed
Save-State -State $state
Write-Output ("new files: " + (($newObjs | ForEach-Object { $_.name }) -join ", "))
