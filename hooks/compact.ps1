# Persist — compact hook (SessionStart)
# Fires after compaction. Finds handoff files and tells Claude to read them.

$ErrorActionPreference = "SilentlyContinue"

# ============================================================
# CONFIGURE: Set this to your projects directory (same as pre-compact.ps1)
$root = "CHANGE_ME"  # e.g. "C:\Users\YourName\Projects"
# ============================================================

$logFile = Join-Path $env:USERPROFILE ".claude\hooks\context-keeper.log"

function Log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $dir = Split-Path $logFile
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    Add-Content -Path $logFile -Value "[$ts] COMPACT: $msg" -Encoding utf8
}

# Validate config
if ($root -eq "CHANGE_ME" -or -not (Test-Path $root)) {
    Log "ERROR: projects root not configured or does not exist: $root"
    Write-Output "COMPACTED — Persist not configured. Edit compact.ps1 and set `$root to your projects directory."
    exit 0
}

Log "Hook fired — scanning for handoffs"

$handoffs = @()
$sub = Get-ChildItem "$root\*\handoff.md" -ErrorAction SilentlyContinue
$top = Get-Item "$root\handoff.md" -ErrorAction SilentlyContinue
if ($sub) { $handoffs += $sub }
if ($top) { $handoffs += $top }

if ($handoffs.Count -gt 0) {
    $list = ($handoffs | ForEach-Object { $_.FullName }) -join "`n"
    Log "Found $($handoffs.Count) handoff(s)"
    Write-Output "COMPACTED — read these handoffs NOW:`n$list"
} else {
    Log "No handoffs found"
    Write-Output "COMPACTED — no handoff found, ask user for direction"
}
