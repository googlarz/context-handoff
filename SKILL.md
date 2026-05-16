---
name: context-handoff
description: Session continuity for Claude — pack your current session state and load it into any new conversation with full context, decisions, behavioral contracts, and work state restored. Auto-updates on commits, decisions, and every 5 turns.
---

# Context Handoff

Preserve full session context across Claude conversations. Pack the current session — decisions, reasoning, work state, behavioral contracts, what was ruled out and why — and load it into any new chat. The new session resumes as if the conversation never ended.

Works for you, your future self, your teammates, and parallel Claude sessions.

## Commands

| Command | What it does |
|---------|-------------|
| `/context-handoff pack` | Create a context pack from the current session |
| `/context-handoff load` | Load a context pack at the start of a new session |
| `/context-handoff update` | Force-write an update to the current session's pack |

---

## `/context-handoff pack`

Synthesize the current conversation into a context pack file.

**Steps:**
1. Infer the topic from the conversation (or ask the user if ambiguous)
2. Create `~/.claude/handoffs/` if it doesn't exist
3. Generate the pack file at `~/.claude/handoffs/YYYY-MM-DD-<topic-slug>.md`
4. Populate both layers (see Pack Format below)
5. Confirm: tell the user the file path and that auto-updates are now active
6. If the commit hook isn't installed, show the setup snippet (see Hook Setup below)

**Session ID:** Generate as `ch-YYYYMMDD-<4-char-random>` and store in the pack frontmatter. Use this to identify the active pack for auto-updates during the session.

---

## `/context-handoff load`

Load a context pack at the start of a new session.

**Steps:**
1. If a file path is given, load that file. Otherwise list the 5 most recent packs from `~/.claude/handoffs/` and ask the user to choose, or pick the most recent if context makes it obvious.
2. Read the pack file
3. Parse the AI YAML layer
4. **Explicitly re-establish each behavioral contract** — state them out loud so the user can correct anything wrong
5. Restore work state awareness: goal, files touched, plan position
6. Acknowledge the load:
   > "Loaded: **[topic]** (saved [date], [update_count] updates). Resuming from: [resume_point]."
7. List any open threads
8. Proceed — do not ask "ready to continue?", just continue

---

## `/context-handoff update`

Force-write a full update to the current session's pack.

**Steps:**
1. Find the active pack (by session_id stored in conversation, or ask user)
2. Rewrite the full pack with current state
3. Increment `update_count`, append trigger `manual` to `update_triggers`
4. Confirm silently (one line: `↻ Pack updated — [path]`)

---

## Auto-Update System

Once a session has an active pack (created via `pack` or loaded via `load`), maintain it automatically. Do not ask permission — just do it.

### Trigger 1: Git commit detected

When you see `CONTEXT-HANDOFF: commit detected` in hook output (from the PostToolUse hook), immediately:
1. Update `work_state.files_touched` with any new files
2. Update `work_state.plan_position` if a step completed
3. Append `commit` to `update_triggers`
4. Write the pack
5. Confirm silently: `↻ Pack updated on commit`

### Trigger 2: Decision detected

When you have just made a significant decision, ruled something out, or completed a plan step, append the new entry to the relevant section and write the pack. This happens inline — no extra turn, no user prompt.

A "significant decision" is: choosing an approach over alternatives, ruling out an option with reasoning, completing a discrete unit of work, or establishing a new behavioral contract with the user.

### Trigger 3: Turn cadence

Every 5 turns, if no other trigger has fired, write a full pack update. Track turns by counting since `last_updated`.

### Update behavior

Updates are **incremental** where possible — append to decisions/ruled_out/open_threads rather than rewriting. Only rewrite `work_state` and `resume_point` in full. This keeps writes fast and the file history readable.

---

## Pack Format

Each pack is a markdown file with two layers:

**AI layer** — YAML frontmatter, machine-readable. Claude reads this on `load` to restore exact operating state.

**Human layer** — Markdown body, readable by people. Useful for review, sharing, and understanding what happened.

```
~/.claude/handoffs/YYYY-MM-DD-<topic-slug>.md
```

### Full format

```markdown
---
version: "1.0"
created: "YYYY-MM-DDTHH:MM:SSZ"
last_updated: "YYYY-MM-DDTHH:MM:SSZ"
update_count: 0
update_triggers: []
topic: "short topic description"
session_id: "ch-YYYYMMDD-xxxx"

# Where to pick up
resume_point: "one sentence: exactly what was about to happen next"

# Active skills loaded in this session
active_skills: []

# How Claude was behaving — restore these exactly on load
behavioral_contracts:
  - "example: no filler or pleasantries"
  - "example: surgical changes only"

# How this person communicates
communication_style: "description of tone, preferences, patterns observed"

# Things the user pushed back on or corrected
pushbacks_recorded:
  - what: "what was suggested or done"
    why: "why the user pushed back"
    when: "ISO timestamp"

# Current work state
work_state:
  goal: "the overarching goal of this session"
  files_touched: []
  plan_position: "description of where we are in any active plan"

# Decisions made — append only, never remove
decisions:
  - what: "what was decided"
    why: "the reasoning — alternatives considered and why this was chosen"
    when: "ISO timestamp"

# Options considered and rejected — the most expensive context to lose
ruled_out:
  - what: "what was ruled out"
    why: "why — be specific"
    when: "ISO timestamp"

# Unresolved threads
open_threads:
  - "description of open question or unresolved item"

# Key snippets, outputs, or error messages referenced in this session
artifacts:
  - label: "short label"
    content: "the content"
---

# Context Handoff — [topic]

**Session:** [date] · **Goal:** [goal] · **Resume at:** [resume_point]

## What we were working on

[2-3 sentences describing the session's purpose and current state]

## Decisions made

[Each decision with its reasoning, in plain English]

## Ruled out

[Each rejected option with its reasoning — critical section]

## Open threads

[Bulleted list of unresolved items]

## Next actions

[Ordered list of what to do next]
```

---

## Hook Setup

To enable automatic pack updates on git commits, add this to `~/.claude/settings.json` (or the project's `.claude/settings.json`):

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

The skill's `install-hook.sh` script does this automatically. Run:

```bash
bash ~/.claude/skills/context-handoff/scripts/install-hook.sh
```

---

## On Load: Behavioral Contract Restoration

When loading a pack, re-establish contracts explicitly. State them so the user can correct anything stale:

> "Restoring behavioral contracts from last session:
> - [contract 1]
> - [contract 2]
> Let me know if anything has changed."

Then proceed. Don't wait for confirmation unless the user responds.

---

## Linked Sessions (Chaining)

Packs can reference prior packs for full lineage:

```yaml
prior_session: "~/.claude/handoffs/2026-05-15-planning.md"
```

On load, Claude may offer to also load the prior session for deeper context, but does not do so automatically.

---

## Finding Packs

List available packs:
```bash
ls -lt ~/.claude/handoffs/
```

Load the most recent:
```bash
# In Claude: /context-handoff load
# Claude will find the most recent pack automatically
```

Load a specific pack:
```bash
# /context-handoff load 2026-05-16-vibe-safe-release
```
