---
name: persist
version: 2.0.0
description: |
  Survives context compaction. Automatically saves full session state to a
  handoff file before every compaction via PreCompact hook, then resumes
  seamlessly after. Manual save point: /persist
license: MIT
compatibility: claude-code
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Bash
  - PowerShell
  - TaskList
---

# Persist

You are about to lose context. Write a handoff that lets the next context window continue **exactly** where you are — same task, same progress, same failures, same rules.

## Where to Write

Your CLAUDE.md defines a `persist.projects_root` directory. List its subdirectories at runtime and match the current chat's topic to one. Write `handoff.md` inside the matching folder. If no folder matches, write it at the projects root.

**Delete any existing `handoff.md` in the target folder before writing.**

## Template

```markdown
---
timestamp: {{ISO 8601}}
target: {{current target or "general"}}
trigger: {{manual | auto}}
---

## RESUME HERE

{{One exact sentence: what you were doing when this fired.}}

## Active Task

{{The user's request in their words. If multi-step, which step.}}

## Findings

{{Numbered. Each: location, what you found, severity, confirmed or not.
Empty: "None yet — still in [phase]."}}

## State

{{Auth tokens, headers, cookies, IDs, UUIDs needed to replay requests.
File paths actively in use. Device/tool state.
Empty: "Clean slate."}}

## Progress

{{What you tried. What worked. What failed and WHY — so the next context doesn't retry it.}}

## Do NOT

{{One bullet per rule. User corrections, failed approaches, feedback that came up.}}

## Next Steps

{{Ordered. Specific actions, not "continue testing."}}

## Open Files

{{Paths to files created, modified, or needed. Include project folder path.}}

## Tasks

{{Active tasks and their status. Empty: "None."}}
```

## Rules

1. **The next context sees ONLY this file and CLAUDE.md.** If it matters, write it down.
2. **Concrete over vague.** Not "testing the profile endpoint" — the full URL, the IDs you swapped, the response code, what's left to verify.
3. **Failures are as important as successes.** The next context will waste tokens re-trying dead approaches without them.
4. **Actual values.** Paste tokens, URLs, IDs — not "the auth token" or "the endpoint."
5. **Read TaskList** before writing. Include active tasks.
6. **Delete then write.** Never merge with an old handoff.

## After Writing

```
Handoff saved → [project folder]. [N] findings, [N] next steps, [N] do-nots.
```

Then continue working — this is a save point, not a stop.
