# scripts/build_rbz.ps1 — PowerShell port of scripts/build_rbz.rb
# because the system Ruby runtime is broken on this host
# (per AGENTS.md §16 / PROJECT_HANDOFF.md §15, env failure
# is not product-code failure; we do not reinstall Ruby
# or rewrite PATH). This script produces an identical
# .rbz layout per the locked shipping policy.
#
# Output: D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz

param(
    [string]$ProjectRoot = 'D:\Projects\SU-AI-Plugin',
    [string]$OutputName = 'SU-AI-Plugin.rbz'
)

$ErrorActionPreference = 'Stop'

$DistDir   = Join-Path $ProjectRoot 'dist'
$OutputPath = Join-Path $DistDir $OutputName
$PkgName   = 'su_ai_plugin'

# Excluded patterns (dev-only, never shipped).
$ExcludePatterns = @(
    'tests/',
    'scripts/',
    'Review/',
    'Prompt/',
    'AGENT.md',
    'README.md',
    'CURRENT_STATE.md',
    'PROJECT_HANDOFF.md',
    'PROJECT_MASTER_PLAN_V1X.md',
    'PI_START_HERE.md',
    '.git/',
    '.gitignore',
    '.pi/',
    '.codex/',
    'data/',
    'dist/',
    '*.log',
    '*.zip',
    '*.rbz',
    'node_modules/'
)

function Test-Excluded {
    param([string]$RelativePath)
    foreach ($pat in $ExcludePatterns) {
        if ($pat.EndsWith('/')) {
            if ($RelativePath.StartsWith($pat, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
        } else {
            if ($RelativePath -like $pat) { return $true }
        }
    }
    return $false
}

# V1.9A FINAL BLOCK FIX (this packet):
# - Test files added under tests/ are excluded by the
#   'tests/' prefix above.
# - The dispatch and durable blueprints under Prompt/ are
#   excluded.
# - The Review/ directory is excluded.

# Build the list of files to ship.
$ShipFiles = @()

# 1. Root registration loader: extension/su_ai_plugin.rb -> <PKG>/su_ai_plugin.rb
$RootLoader = Join-Path $ProjectRoot (Join-Path 'extension' 'su_ai_plugin.rb')
if (-not (Test-Path $RootLoader)) {
    # Some layouts don't have extension/su_ai_plugin.rb — fall back to extension/su_ai_plugin/main.rb etc.
    Write-Host "Note: $RootLoader not present; skipping root registration loader."
} else {
    $ShipFiles += [pscustomobject]@{
        Source = $RootLoader
        Arcname = "$PkgName.rb"
    }
}

# 2. Support folder: extension/su_ai_plugin/**/* -> <PKG>/su_ai_plugin/**/*
$SupportDir = Join-Path $ProjectRoot (Join-Path 'extension' 'su_ai_plugin')
if (Test-Path $SupportDir) {
    $SupportFiles = Get-ChildItem -Path $SupportDir -Recurse -File
    foreach ($f in $SupportFiles) {
        $rel = $f.FullName.Substring($SupportDir.Length).TrimStart('\', '/')
        $arc = "$PkgName/$rel" -replace '\\', '/'
        $ShipFiles += [pscustomobject]@{
            Source = $f.FullName
            Arcname = $arc
        }
    }
}

# Filter excluded files (defense-in-depth).
$ShipFiles = $ShipFiles | Where-Object {
    $src = $_.Source
    # Convert source path to relative-from-project for pattern matching.
    $rel = $src.Substring($ProjectRoot.Length).TrimStart('\', '/') -replace '\\', '/'
    -not (Test-Excluded $rel)
}

Write-Host "Shipping $($ShipFiles.Count) files into $OutputPath..."

# Create the .rbz (ZIP) archive.
if (Test-Path $OutputPath) { Remove-Item $OutputPath -Force }
if (-not (Test-Path $DistDir)) { New-Item -ItemType Directory -Path $DistDir -Force | Out-Null }

Add-Type -AssemblyName System.IO.Compression.FileSystem

$Zip = [System.IO.Compression.ZipFile]::Open($OutputPath, 'Create')
try {
    foreach ($entry in $ShipFiles) {
        # Use NoCompression (STORE method = 0) to match the
        # pure-Ruby build_rbz.rb output. SketchUp's
        # Extension Manager accepts STORE or DEFLATE; we
        # use STORE for byte-identical determinism with
        # the historical rbz layout.
        $archiveEntry = $Zip.CreateEntry($entry.Arcname, 'NoCompression')
        $writer = New-Object System.IO.BinaryWriter($archiveEntry.Open())
        try {
            $bytes = [System.IO.File]::ReadAllBytes($entry.Source)
            $writer.Write($bytes)
        } finally {
            $writer.Close()
        }
    }
} finally {
    $Zip.Dispose()
}

# Compute SHA-256 of the output.
$Hash = (Get-FileHash -Path $OutputPath -Algorithm SHA256).Hash.ToLower()
$Size = (Get-Item $OutputPath).Length

Write-Host ""
Write-Host "Built: $OutputPath"
Write-Host "  Size (bytes): $Size"
Write-Host "  SHA-256:      $Hash"
Write-Host "  Entries:      $($ShipFiles.Count)"
