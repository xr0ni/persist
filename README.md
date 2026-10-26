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

```powershell
git clone https://github.com/xr0ni/persist.git
cd persist
.\install.ps1
```

The installer will:
1. Ask for your projects directory (where handoff files get saved)
2. Copy hooks to `~/.claude/hooks/`
3. Copy the `/persist` skill to `~/.claude/skills/persist/`
4. Add the hook config to `~/.claude/settings.json` (preserves your existing settings)
5. Add the Persist section to `~/.claude/CLAUDE.md`

Then restart Claude Code.

You can also pass the path directly:

```powershell
.\install.ps1 -ProjectsRoot "C:\Users\YourName\Projects"
```

### Manual installation

<details>
<summary>Click to expand</summary>

If you prefer to install manually:

**1. Copy files:**
```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\hooks"
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\skills\persist"
Copy-Item hooks\pre-compact.ps1 "$env:USERPROFILE\.claude\hooks\"
Copy-Item hooks\compact.ps1 "$env:USERPROFILE\.claude\hooks\"
Copy-Item skill\persist\SKILL.md "$env:USERPROFILE\.claude\skills\persist\"
```

**2. Edit `$root` in both hook scripts** — set it to your projects directory.

**3. Add to `~/.claude/settings.json`** (use forward slashes in paths):
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

**4. Add to `~/.claude/CLAUDE.md`:**

````markdown
## Persist (Auto-Handoff)

**Mandatory. Do not skip.**

```yaml
persist:
  projects_root: C:\Users\YourName\Projects
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

**5. Restart Claude Code.**

</details>

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
[2026-10-26 18:30:16] COMPACT: Hook fired — scanning for handoffs
[2026-10-26 18:30:16] COMPACT: Found 1 handoff(s)
```

## Uninstall

```powershell
Remove-Item "$env:USERPROFILE\.claude\hooks\pre-compact.ps1" -Force
Remove-Item "$env:USERPROFILE\.claude\hooks\compact.ps1" -Force
Remove-Item "$env:USERPROFILE\.claude\skills\persist" -Recurse -Force
Remove-Item "$env:USERPROFILE\.claude\hooks\context-keeper.log" -Force
```

Then remove the `PreCompact` and `SessionStart` compact entries from `~/.claude/settings.json` and the `## Persist` section from `~/.claude/CLAUDE.md`.

## Cross-platform

The hooks are PowerShell (Windows). For macOS/Linux, the logic is identical — bash ports are welcome as PRs.

## License

MIT
