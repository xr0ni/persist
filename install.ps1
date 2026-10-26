# Persist — Installer
# Run: .\install.ps1
# Or:  .\install.ps1 -ProjectsRoot "C:\Users\YourName\Projects"

param(
    [string]$ProjectsRoot
)

$ErrorActionPreference = "Stop"
$claudeDir = Join-Path $env:USERPROFILE ".claude"
$hooksDir = Join-Path $claudeDir "hooks"
$skillDir = Join-Path $claudeDir "skills\persist"
$settingsFile = Join-Path $claudeDir "settings.json"
$claudeMd = Join-Path $claudeDir "CLAUDE.md"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "`n  Persist — Installer" -ForegroundColor Cyan
Write-Host "  Survive context compaction in Claude Code`n" -ForegroundColor DarkGray

# Step 1: Get projects root
if (-not $ProjectsRoot) {
    Write-Host "  Enter your projects directory (where Persist writes handoff files):"
    Write-Host "  Example: C:\Users\$env:USERNAME\Projects" -ForegroundColor DarkGray
    $ProjectsRoot = Read-Host "  Path"
}

$ProjectsRoot = $ProjectsRoot.Trim().TrimEnd('\', '/')

if (-not (Test-Path $ProjectsRoot)) {
    Write-Host "  Directory doesn't exist. Create it? (y/n)" -ForegroundColor Yellow
    $create = Read-Host "  "
    if ($create -eq 'y') {
        New-Item -ItemType Directory -Force $ProjectsRoot | Out-Null
    } else {
        Write-Host "  Aborted." -ForegroundColor Red
        exit 1
    }
}

# Step 2: Create directories
Write-Host "`n  [1/5] Creating directories..." -ForegroundColor White
New-Item -ItemType Directory -Force $hooksDir | Out-Null
New-Item -ItemType Directory -Force $skillDir | Out-Null

# Step 3: Copy hooks with configured path
Write-Host "  [2/5] Installing hooks..." -ForegroundColor White

$preCompact = Get-Content "$scriptDir\hooks\pre-compact.ps1" -Raw
$preCompact = $preCompact -replace '\$root = "CHANGE_ME"', "`$root = `"$ProjectsRoot`""
$preCompact | Out-File -Encoding utf8 "$hooksDir\pre-compact.ps1" -Force

$compact = Get-Content "$scriptDir\hooks\compact.ps1" -Raw
$compact = $compact -replace '\$root = "CHANGE_ME"', "`$root = `"$ProjectsRoot`""
$compact | Out-File -Encoding utf8 "$hooksDir\compact.ps1" -Force

# Step 4: Copy skill
Write-Host "  [3/5] Installing skill..." -ForegroundColor White
Copy-Item "$scriptDir\skill\persist\SKILL.md" "$skillDir\SKILL.md" -Force

# Step 5: Update settings.json
Write-Host "  [4/5] Updating settings.json..." -ForegroundColor White

$hooksPath = ($hooksDir -replace '\\', '/')

$preCompactHook = @{
    hooks = @(
        @{
            type = "command"
            command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File $hooksPath/pre-compact.ps1"
            timeout = 60
        }
    )
}

$compactHook = @{
    matcher = "compact"
    hooks = @(
        @{
            type = "command"
            command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File $hooksPath/compact.ps1"
        }
    )
}

if (Test-Path $settingsFile) {
    $settings = Get-Content $settingsFile -Raw | ConvertFrom-Json
} else {
    $settings = [PSCustomObject]@{}
}

# Build hooks object
$hooksObj = @{}
if ($settings.PSObject.Properties['hooks']) {
    # Preserve existing hooks
    $settings.hooks.PSObject.Properties | ForEach-Object {
        $hooksObj[$_.Name] = $_.Value
    }
}

$hooksObj['PreCompact'] = @($preCompactHook)

# Merge compact into SessionStart (preserve other matchers)
$sessionStart = @()
if ($hooksObj.ContainsKey('SessionStart')) {
    $sessionStart = @($hooksObj['SessionStart'] | Where-Object {
        -not ($_.PSObject.Properties['matcher'] -and $_.matcher -eq 'compact')
    })
}
$sessionStart += $compactHook
$hooksObj['SessionStart'] = $sessionStart

# Can't assign hashtable directly to PSCustomObject, so rebuild
$settings | Add-Member -NotePropertyName 'hooks' -NotePropertyValue ([PSCustomObject]$hooksObj) -Force

$settings | ConvertTo-Json -Depth 10 | Out-File -Encoding utf8 $settingsFile -Force

# Step 6: Update CLAUDE.md
Write-Host "  [5/5] Updating CLAUDE.md..." -ForegroundColor White

$persistSection = @"

## Persist (Auto-Handoff)

**Mandatory. Do not skip.**

``````yaml
persist:
  projects_root: $ProjectsRoot
``````

### Cycle

1. **Session starts** — do nothing.
2. **PreCompact hook fires** — automatically generates a handoff via Haiku fork before compaction. Falls back to filesystem dump if the fork fails.
3. **Compaction** — ``compact`` hook prints handoff paths. Read them all. Resume from "Next Steps." Obey "Do NOT." Tell user: "Resumed from handoff — [summary]." Don't ask what to do.
4. Repeat.

### Where

List subdirectories of your projects root at runtime. Match the chat's topic to a folder name. Write ``handoff.md`` there. No match → write at the root.

### Manual

``/persist`` anytime.
"@

if (Test-Path $claudeMd) {
    $mdContent = Get-Content $claudeMd -Raw
    if ($mdContent -notmatch "## Persist") {
        Add-Content -Path $claudeMd -Value $persistSection -Encoding utf8
        Write-Host "    Added Persist section to CLAUDE.md" -ForegroundColor DarkGray
    } else {
        Write-Host "    Persist section already in CLAUDE.md — skipped" -ForegroundColor DarkGray
    }
} else {
    $persistSection | Out-File -Encoding utf8 $claudeMd -Force
    Write-Host "    Created CLAUDE.md with Persist section" -ForegroundColor DarkGray
}

# Done
Write-Host "`n  Installed." -ForegroundColor Green
Write-Host "  Projects root: $ProjectsRoot" -ForegroundColor DarkGray
Write-Host "  Logs: $hooksDir\context-keeper.log" -ForegroundColor DarkGray
Write-Host "  Manual save: /persist" -ForegroundColor DarkGray
Write-Host "`n  Restart Claude Code to activate.`n" -ForegroundColor Yellow
