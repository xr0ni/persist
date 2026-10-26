# Persist

Survive context compaction in Claude Code. Automatically saves your full session state before every compaction and resumes seamlessly after — no manual commands, no lost context.

## The Problem

Claude Code compacts your conversation when context fills up. When it does, you lose details — findings, progress, what you tried, what failed, critical state. You end up re-explaining everything or watching Claude retry approaches that already failed.

## The Fix

Persist hooks into Claude Code's compaction lifecycle:

1. **Before compaction** → `PreCompact` hook fires automatically, spawns a Haiku fork that writes a structured handoff file with your full session state
2. **After compaction** → `SessionStart` hook fires, injects handoff paths into the new context
3. **Claude reads the handoff and picks up exactly where it left off**

No tokens to monitor. No commands to remember. Fully automatic.

### Fallback layers

If the Haiku fork fails (network issue, CLI error), Persist falls back to a filesystem dump of your recently modified files — so something always survives.

You can also run `/persist` manually at any time to force a save point.

## Requirements

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) with `claude` on PATH
- Windows with PowerShell 5.1+

## Installation

### 1. Create directories

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\hooks"
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\skills\persist"
```

### 2. Copy files

```powershell
# From the repo root:
Copy-Item hooks\pre-compact.ps1 "$env:USERPROFILE\.claude\hooks\pre-compact.ps1"
Copy-Item hooks\compact.ps1 "$env:USERPROFILE\.claude\hooks\compact.ps1"
Copy-Item skill\persist\SKILL.md "$env:USERPROFILE\.claude\skills\persist\SKILL.md"
```

### 3. Set your projects directory

Open both hook scripts and change the `$root` variable at the top:

**`~/.claude/hooks/pre-compact.ps1`** and **`~/.claude/hooks/compact.ps1`**:
```powershell
$root = "C:\Users\YourName\Projects"  # ← your projects directory
```

Persist matches your current chat's topic to a subfolder name and writes `handoff.md` there. If no subfolder matches, it writes to the root.

### 4. Add hooks to settings.json

Open `~/.claude/settings.json` and merge in the `hooks` block below. Replace the paths with your actual home directory.

```json
{
  "hooks": {
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:/Users/YourName/.claude/hooks/pre-compact.ps1",
            "timeout": 60
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "compact",
        "hooks": [
          {
            "type": "command",
            "command": "powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:/Users/YourName/.claude/hooks/compact.ps1"
          }
        ]
      }
    ]
  }
}
```

> **Use forward slashes** (`/`) in the JSON paths. Backslashes get eaten by JSON + PowerShell double-escaping.

### 5. Add the CLAUDE.md section

Add this to your `~/.claude/CLAUDE.md` (or project-level `CLAUDE.md`):

````markdown
## Persist (Auto-Handoff)

**Mandatory. Do not skip.**

```yaml
persist:
  projects_root: C:\Users\YourName\Projects  # ← same as your hook scripts
```

### Cycle

1. **Session starts** — do nothing.
2. **PreCompact hook fires** — automatically generates a handoff via Haiku fork before compaction. Falls back to filesystem dump if the fork fails.
3. **Compaction** — `compact` hook prints handoff paths. Read them all. Resume from "Next Steps." Obey "Do NOT." Tell user: "Resumed from handoff — [summary]." Don't ask what to do.
4. Repeat.

### Where

List subdirectories of your projects root at runtime. Match the chat's topic to a folder name. Write `handoff.md` there. No match → write at the root.

### Manual

`/persist` anytime.
````

### 6. Restart Claude Code

Hooks load on startup. Restart to pick them up.

## What a handoff looks like

```markdown
---
timestamp: 2026-10-26T18:30:00Z
target: MyProject
trigger: auto
---

## RESUME HERE

Refactoring the auth middleware to use JWT validation instead of session cookies.

## Active Task

"Swap out session auth for JWT across all API routes"

## Findings

1. /api/users/:id — no auth check, returns any user's data (confirmed)
2. /api/settings — validates session but not JWT yet (in progress)

## State

Working branch: feat/jwt-auth
Modified files: src/middleware/auth.ts, src/routes/users.ts

## Progress

- Replaced session middleware with JWT verify — working for /api/users
- Tried jsonwebtoken first, switched to jose (doesn't support ES256)

## Do NOT

- Don't use jsonwebtoken — failed on ES256, use jose
- Don't touch /api/admin routes — next sprint

## Next Steps

1. Add JWT validation to /api/settings route
2. Update tests in tests/auth.test.ts
3. Run full test suite

## Open Files

- src/middleware/auth.ts
- src/routes/users.ts
```

## Debugging

Logs go to `~/.claude/hooks/context-keeper.log`:

```
[2026-10-26 18:30:01] PRE-COMPACT: Hook fired
[2026-10-26 18:30:01] PRE-COMPACT: Session ID: abc123
[2026-10-26 18:30:01] PRE-COMPACT: Spawning Haiku fork...
[2026-10-26 18:30:15] PRE-COMPACT: Haiku fork succeeded (1842 chars)
[2026-10-26 18:30:15] PRE-COMPACT: Handoff generated via Haiku fork
[2026-10-26 18:30:16] COMPACT: Hook fired — scanning for handoffs
[2026-10-26 18:30:16] COMPACT: Found 1 handoff(s)
```

If the fork fails:

```
[2026-10-26 18:30:05] PRE-COMPACT: Haiku fork failed (exit code: 1)
[2026-10-26 18:30:05] PRE-COMPACT: Using filesystem fallback
[2026-10-26 18:30:05] PRE-COMPACT: Fallback handoff saved
```

## Cross-platform

The hooks are PowerShell (Windows). For macOS/Linux, swap the hook commands in `settings.json` to point at bash equivalents. The logic is identical — bash ports are welcome as PRs.

## License

MIT
