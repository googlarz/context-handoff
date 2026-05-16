# context-handoff

**Your Claude sessions have amnesia. This fixes it.**

A Claude Code skill that packs your session state — decisions, reasoning, work state, behavioral contracts — and restores it in any new conversation. The new session resumes exactly where you left off.

Works for you, your future self, your teammates, and parallel Claude sessions.

---

## The problem

Every time you start a new Claude session, you re-explain everything. The context, the constraints, what was tried, what was ruled out, how you like to work. An hour of hard-won decision context, gone.

The worst part isn't the summary — it's the **ruled-out list**. The things that were considered, debated, and rejected for good reasons. Without it, every new session risks re-litigating the same decisions.

## What it does

`/context-handoff pack` captures your session into a living document:

| What's captured | Why it matters |
|----------------|---------------|
| **Decisions + reasoning** | Prevents re-litigating. Not just "we chose X" but "we chose X over Y because Z". |
| **Ruled out + why** | The most expensive context to lose. Stops the same wrong turns from being taken twice. |
| **Work state** | Current goal, files touched, position in any active plan. |
| **Behavioral contracts** | Active skills, preferences established, how Claude was behaving in this session. |
| **Communication style** | How you communicate, what you pushed back on, implicit agreements. |
| **Open threads** | Unresolved questions with full context. |

`/context-handoff load` restores all of it into a new session. Claude reads the pack, re-establishes every contract, and picks up from the exact resume point — before doing anything else.

## Auto-update

Once a session has an active pack, context-handoff maintains it automatically. Three triggers:

- **Git commit** — immediate update via PostToolUse hook. Clean checkpoint every time you ship.
- **Decision detected** — Claude appends inline when it recognizes a significant decision or ruled-out entry. No extra turn.
- **Turn cadence** — fallback update every ~5 turns. Exploratory work still gets captured.

The pack is a **living document**, not a one-time snapshot.

---

## Install

```bash
# Clone or copy the skill
git clone https://github.com/googlarz/context-handoff ~/.claude/skills/context-handoff

# Install the commit hook (adds PostToolUse hook to ~/.claude/settings.json)
bash ~/.claude/skills/context-handoff/scripts/install-hook.sh
```

Then add the skill to your Claude Code project or global settings:

```json
{
  "skills": ["~/.claude/skills/context-handoff"]
}
```

---

## Usage

### Start a session, pack it at the end

```
/context-handoff pack
```

Claude synthesizes the conversation and saves a pack to `~/.claude/handoffs/YYYY-MM-DD-<topic>.md`.

### Continue in a new session

```
/context-handoff load
```

Claude finds the most recent pack, restores all contracts and state, and resumes from the exact resume point.

```
/context-handoff load 2026-05-16-vibe-safe-release
```

Load a specific session by name.

### Force a manual update mid-session

```
/context-handoff update
```

---

## Pack format

Each pack has two layers:

**AI layer** — YAML frontmatter. Claude reads this on load to restore exact operating state: behavioral contracts, work state, decisions, ruled-out options, open threads.

**Human layer** — Markdown body. Readable by anyone. Useful for review, sharing with teammates, or understanding what happened in a session you didn't run yourself.

```
~/.claude/handoffs/
├── 2026-05-16-context-handoff-build.md
├── 2026-05-15-vibe-safe-release.md
└── 2026-05-14-llmessenger-auth.md
```

Example pack:

```yaml
---
version: "1.0"
topic: "building context-handoff skill"
session_id: "ch-20260516-x7k2"
resume_point: "writing README.md — SKILL.md already done"

behavioral_contracts:
  - "no filler, pleasantries, or hedging"
  - "surgical changes only — don't touch adjacent code"
  - "ask before committing"

work_state:
  goal: "build and ship context-handoff v1.0 to GitHub"
  files_touched: ["SKILL.md"]
  plan_position: "step 2 of 4 — SKILL.md done, writing README"

decisions:
  - what: "skill only, no MCP"
    why: "simpler distribution, no infrastructure needed; MCP adds server requirement for no gain at v1"
    when: "2026-05-16T17:35:00Z"

ruled_out:
  - what: "SQLite + MCP server approach"
    why: "adds infrastructure requirement; pure skill handles single-session case cleanly"
---

# Context Handoff — building context-handoff skill

**Goal:** Build and ship context-handoff v1.0  
**Resume at:** Writing README.md — SKILL.md already done

...
```

---

## Hook setup

The commit auto-update requires a PostToolUse hook in your Claude Code settings. The install script handles this:

```bash
bash ~/.claude/skills/context-handoff/scripts/install-hook.sh
```

Or add it manually to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "echo \"$CLAUDE_TOOL_INPUT\" | grep -qE 'git commit|git push' && echo 'CONTEXT-HANDOFF: commit detected — update pack' || true"
          }
        ]
      }
    ]
  }
}
```

---

## Handoff to a teammate

Pack your session, share the file. Your teammate loads it in their Claude session and picks up with full context — not just a summary of what happened, but the reasoning behind every decision.

```bash
# Share via git (if handoffs folder is tracked)
git add ~/.claude/handoffs/2026-05-16-feature-x.md
git commit -m "handoff: feature-x context for @teammate"

# Or just send the file
```

---

## What's next (v2.0)

v1.0 is single-session continuity. v2.0 will be multi-agent and team-native:

- **Append-only decisions log** — multiple Claude sessions write to the same pack without collisions
- **Git-native sync** — session branches merge into a shared pack; teams pull context like they pull code
- **No new infrastructure** — still pure skill, same zero-dependency install

---

## License

MIT
