# Persist — PreCompact hook
# Fires before every compaction. Generates a handoff via Haiku fork.
# Falls back to filesystem dump if the fork fails.

$ErrorActionPreference = "SilentlyContinue"

# ============================================================
# CONFIGURE: Set this to your projects directory
$root = "CHANGE_ME"  # e.g. "C:\Users\YourName\Projects"
# ============================================================

$logFile = Join-Path $env:USERPROFILE ".claude\hooks\context-keeper.log"

function Log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $dir = Split-Path $logFile
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    Add-Content -Path $logFile -Value "[$ts] PRE-COMPACT: $msg" -Encoding utf8
}

function Exit-Ok($msg) {
    if ($msg) { Log $msg }
    Write-Output '{"continue": true}'
    exit 0
}

function Exit-Fail($msg) {
    Log "ERROR: $msg"
    Write-Output '{"continue": true}'
    exit 0
}

# Validate config
if ($root -eq "CHANGE_ME" -or -not (Test-Path $root)) {
    Exit-Fail "projects root not configured or does not exist: $root — edit pre-compact.ps1 and set `$root"
}

Log "Hook fired"

# Read hook input from stdin
try {
    $input_json = [Console]::In.ReadToEnd()
    Log "Got input ($($input_json.Length) chars)"
} catch {
    Exit-Fail "Failed to read stdin: $_"
}

# Delete any old handoffs
$old = @()
$old += Get-ChildItem "$root\*\handoff.md" -ErrorAction SilentlyContinue
$old += Get-Item "$root\handoff.md" -ErrorAction SilentlyContinue
foreach ($f in $old) {
    if ($f) {
        Remove-Item $f.FullName -Force
        Log "Deleted old handoff: $($f.FullName)"
    }
}

# Try to generate handoff via forked Claude session
try {
    $parsed = $input_json | ConvertFrom-Json
    $session_id = $parsed.session_id
    Log "Session ID: $session_id"

    if ($session_id) {
        $prompt = @"
Write a handoff file for the current session. This will be read after context compaction to resume exactly where we left off.

Determine which project folder under "$root" matches the current work. List the subdirectories to find the right one. Write handoff.md there. If no folder matches, write to "$root\handoff.md".

The handoff MUST include these sections:
- RESUME HERE: one exact sentence of what was happening
- Active Task: the user's request in their words, which step we're on
- Findings: numbered, with endpoints/locations, what was found, severity, confirmed or not
- State: auth tokens, headers, cookies, IDs, file paths, device/tool state
- Progress: what was tried, what worked, what failed and WHY
- Do NOT: user corrections, failed approaches, rules that came up
- Next Steps: ordered specific actions
- Open Files: paths to files created/modified/needed

Be concrete — actual values, URLs, IDs. Not "the auth token" — the token itself.
"@
        Log "Spawning Haiku fork..."
        $result = claude --resume $session_id --fork-session --model haiku --print $prompt 2>$null
        if ($result -and $LASTEXITCODE -eq 0) {
            Log "Haiku fork succeeded ($($result.Length) chars)"
            Exit-Ok "Handoff generated via Haiku fork"
        } else {
            Log "Haiku fork failed (exit code: $LASTEXITCODE)"
        }
    } else {
        Log "No session_id in input"
    }
} catch {
    Log "Fork exception: $_"
}

# Fork failed — filesystem fallback
Log "Using filesystem fallback"
$recent_files = Get-ChildItem "$root\*" -Recurse -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 20 |
    ForEach-Object { $_.FullName }

$state = @"
---
timestamp: $(Get-Date -Format "o")
target: unknown
trigger: pre-compact-fallback
---

## RESUME HERE

Compaction fired. Haiku fork failed — this is a filesystem-only fallback.

## Recently Modified Files

$($recent_files -join "`n")

## State

No session state captured. Ask user for direction.
"@

$state | Out-File -Encoding utf8 "$root\handoff.md" -Force
Log "Fallback handoff saved to $root\handoff.md"
Exit-Ok "Fallback handoff written"
