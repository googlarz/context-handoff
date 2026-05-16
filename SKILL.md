---
name: context-handoff
version: "1.1.0"
description: Session continuity for Claude — pack your current session state and load it into any new conversation with full context, decisions, behavioral contracts, and work state restored. Auto-updates on commits, decisions, and every 5 turns.
tags: [session-continuity, context, handoff, productivity]
author: googlarz
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
| `/context-handoff list [query]` | List all packs, optionally filtered by query |
| `/context-handoff search <query>` | Search pack content across all packs |
| `/context-handoff delete <pack>` | Delete a named pack after confirmation |
| `/context-handoff close <thread>` | Mark an open thread as resolved |
| `/context-handoff contracts` | View and edit active behavioral contracts |
| `/context-handoff threads` | Show all open threads across all packs |
| `/context-handoff diff [pack1] [pack2]` | Compare two packs for the same project |
| `/context-handoff merge <pack1> <pack2>` | Merge two packs into a combined pack |
| `/context-handoff rename <pack> <new-name>` | Rename a pack and update its topic field |

---

## `/context-handoff pack`

Synthesize the current conversation into a context pack file.

**Steps:**
1. Infer the topic from the conversation (or ask the user if ambiguous)
2. Create `~/.claude/handoffs/` if it doesn't exist
3. Generate the pack file at `~/.claude/handoffs/YYYY-MM-DD-<topic-slug>.md`
4. Populate both layers (see Pack Format below)
5. Write the session marker: `~/.claude/handoffs/.active` → `session_id|/full/path/to/pack.md|last_updated_timestamp`
6. Confirm: tell the user the file path and that auto-updates are now active
7. Check if the hook is installed (look for "CONTEXT-HANDOFF" in `~/.claude/settings.json`). If not found, emit once: `⚠ Commit hook not installed — run scripts/install-hook.sh for automatic commit-triggered updates.`

**Session ID:** Generate as `ch-YYYYMMDD-<4-char-random>` and store in the pack frontmatter.

---

## `/context-handoff load`

Load a context pack at the start of a new session.

**Steps:**
1. If a file path is given, load that file. Otherwise list the 5 most recent packs from `~/.claude/handoffs/` with a one-line summary per pack and ask the user to choose:
   ```
   1. 2026-05-16 · vibe-safe-release · 9 updates · 3 open threads
   2. 2026-05-15 · llmessenger-auth · 4 updates · 1 open thread
   ```
   Pick the most recent if context makes it obvious.
2. If `~/.claude/handoffs/` is empty or doesn't exist: "No packs found. Use `/context-handoff pack` to create one."
3. Read the pack file. If YAML frontmatter fails to parse, fall back to reading the markdown body only and warn: `⚠ Pack YAML could not be parsed — loading human-readable layer only. Behavioral contracts and work state will not be restored.`
4. **Staleness check:** If `last_updated` is more than 7 days ago, warn before restoring:
   > `⚠ This pack is X days old (last updated YYYY-MM-DD). Resume point and open threads may be stale.`
   Continue loading regardless.
5. Parse the AI YAML layer
6. **Explicitly re-establish each behavioral contract** — state them out loud so the user can correct anything wrong
7. Ask: "Any of these no longer apply?" If the user names one, remove it from `behavioral_contracts` and write the pack.
8. Restore work state awareness: goal, files touched, plan position. Surface superseded decisions as struck-through context so the receiver understands the evolution.
9. Acknowledge the load:
   > "Loaded: **[topic]** (saved [date], [update_count] updates). Resuming from: [resume_point]."
10. List any open threads (with priority if set)
11. If the current directory is a git repo, run `git log --oneline` since `last_updated` and surface it:
    > `4 commits since this pack was last updated: [list]`
12. Write the session marker: `~/.claude/handoffs/.active` → `session_id|/full/path/to/pack.md|last_updated_timestamp`
13. Proceed — do not ask "ready to continue?", just continue

**Partial load:** `/context-handoff load --contracts-only` restores only behavioral contracts and communication style, skipping work state and decisions. Useful when starting a fresh task but wanting to preserve working style.

---

## `/context-handoff update`

Force-write a full update to the current session's pack.

**Steps:**
1. Find the active pack by reading `~/.claude/handoffs/.active` (or ask user if not found)
2. Before writing, check if `last_updated` in the file is newer than what Claude last read. If so, read the current file first and merge (append new decisions, take latest work_state) rather than overwriting.
3. Rewrite the full pack with current state
4. Increment `update_count`, append trigger `manual` to `update_triggers`
5. Confirm silently: `↻ Pack updated (manual) — [path]`

---

## `/context-handoff list [query]`

List all packs in `~/.claude/handoffs/` and the project-local `.claude/handoffs/` (if it exists), sorted by most recent.

**Output columns:** filename · topic · last_updated · update_count · open thread count

**Optional query:** `/context-handoff list vibe-safe` filters by topic/content match.

If no packs exist: "No packs found."

---

## `/context-handoff search <query>`

Search pack content across all packs (topic, decisions, ruled_out, open_threads). Show matching packs with the matching excerpt.

Implementation: `grep -r -l "<query>" ~/.claude/handoffs/*.md` then show the matching lines with context.

---

## `/context-handoff delete <pack>`

Delete a named pack after confirmation. Accept partial name match if unambiguous (error if multiple packs match).

Show the pack's topic and last_updated before confirming. On confirm, delete the file and confirm deletion.

---

## `/context-handoff close <thread>`

Mark an open thread as resolved.

**Steps:**
1. Find the open thread by partial text match. Error if ambiguous (multiple matches).
2. Remove it from `open_threads`
3. Add it to `closed_threads` with a `closed_at` timestamp (current time)
4. Write the pack
5. Confirm: `✓ Thread closed: "[matched text]"`

---

## `/context-handoff contracts`

Show currently active behavioral contracts from the loaded pack.

**Steps:**
1. Display the current `behavioral_contracts` list (numbered)
2. Offer: "Add, remove, or edit? (or press enter to skip)"
3. If user responds, apply the change and write the pack
4. Confirm any changes silently

---

## `/context-handoff threads`

Show all open threads across all packs, grouped by pack, with age (time since `last_updated`).

```
vibe-safe-release (3 days old)
  [high] README needs v1.9.0 test evidence
  [medium] GitHub profile README shows old numbers

llmessenger-auth (12 days old)
  [low] consider rate limiting docs
```

Useful for finding stale unresolved work.

---

## `/context-handoff diff [pack1] [pack2]`

Compare two packs for the same project.

- If only one pack given, diff against the previous pack for the same topic (by filename date prefix)
- Show: new decisions since pack1, newly closed threads, changes to work_state, newly ruled-out items
- Superseded decisions are highlighted

---

## `/context-handoff merge <pack1> <pack2>`

Merge context from two packs into a new combined pack.

**Merge rules:**
- `decisions`: union, deduplicated by `what` field
- `open_threads`: union of all open threads
- `work_state`: latest `last_updated` wins
- `behavioral_contracts`: merged with exact duplicates removed
- `ruled_out`: union, deduplicated by `what` field
- `closed_threads`: union

**Output file:** `~/.claude/handoffs/YYYY-MM-DD-<topic1>-<topic2>-merged.md`

Confirm the output path after writing.

---

## `/context-handoff rename <pack> <new-name>`

Rename a pack file and update its `topic` field in frontmatter to match.

Accept partial name match if unambiguous. Confirm the old and new filename before renaming.

---

## Auto-Update System

Once a session has an active pack (created via `pack` or loaded via `load`), maintain it automatically. Do not ask permission — just do it.

### Session ID Pinning

The active pack is tracked via `~/.claude/handoffs/.active`:
```
session_id|/full/path/to/pack.md|last_updated_timestamp
```

On every auto-update trigger, read `.active` to find the current pack path — no reliance on conversation memory. On session end or new `pack`/`load`, `.active` is overwritten.

### Trigger 1: Git commit detected

When you see `CONTEXT-HANDOFF: commit detected` in hook output (from the PostToolUse hook), immediately:
1. Update `work_state.files_touched` with any new files
2. Update `work_state.plan_position` if a step completed
3. Append `commit` to `update_triggers`
4. Write the pack (with write coordination — see below)
5. Confirm silently: `↻ Pack updated (commit)`

### Trigger 2: Decision detected

When you have just made a significant decision, ruled something out, or completed a plan step, append the new entry to the relevant section and write the pack. This happens inline — no extra turn, no user prompt.

A "significant decision" is: choosing an approach over alternatives, ruling out an option with reasoning, completing a discrete unit of work, or establishing a new behavioral contract with the user.

Confirm silently: `↻ Pack updated (decision)`

### Trigger 3: Turn cadence

Count your own responses (assistant turns) since `last_updated`. After every 5 assistant turns, if no other trigger has fired, write a full pack update.

Confirm silently: `↻ Pack updated (turn 5)`

### Update behavior

Updates are **incremental** where possible — append to decisions/ruled_out/open_threads rather than rewriting. Only rewrite `work_state` and `resume_point` in full.

**Write coordination:** Before writing a pack, check if `last_updated` in the file is newer than what Claude last read. If so, read the current file first and merge (append new decisions, take latest work_state) rather than overwriting.

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
# Pack schema version
pack_version: "1.1"

version: "1.0"
created: "YYYY-MM-DDTHH:MM:SSZ"
last_updated: "YYYY-MM-DDTHH:MM:SSZ"
update_count: 0
update_triggers: []
topic: "short topic description"
session_id: "ch-YYYYMMDD-xxxx"

# Who created this pack (optional)
author: "session owner's name or handle"

# Intended receiver — self | teammate | any
receiver: "self"

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
  files_touched: []   # paths relative to git root; absolute if not in a git repo
  plan_position: "description of where we are in any active plan"

# Decisions made — append only, never remove
# superseded_by is optional — use when a later decision overrides this one
decisions:
  - what: "what was decided"
    why: "the reasoning — alternatives considered and why this was chosen"
    when: "ISO timestamp"
    superseded_by: "optional: description of the later decision that overrides this"

# Options considered and rejected — the most expensive context to lose
# revisit_after is optional — use when the ruling-out is conditional
ruled_out:
  - what: "what was ruled out"
    why: "why — be specific"
    when: "ISO timestamp"
    revisit_after: "optional: condition under which this should be reconsidered"

# Unresolved threads
open_threads:
  - text: "description of open question or unresolved item"
    priority: high   # high | medium | low
    added_at: "ISO timestamp"

# Resolved threads (moved here via /context-handoff close)
closed_threads:
  - text: "description of the resolved item"
    closed_at: "ISO timestamp"

# Key snippets, outputs, or error messages referenced in this session
# Truncate each entry to ~500 chars. If larger, store first 300 chars + "... [truncated, see <file_path>]"
# Keep total pack size under ~50KB
artifacts:
  - label: "short label"
    content: "the content"

# Files the receiver should read before continuing
context_files:
  - "src/auth/middleware.ts"
  - "docs/architecture.md"

# Prerequisites — things the receiver needs set up
prerequisites:
  - "Node.js 20+"
  - "ANTHROPIC_API_KEY set"

# Environment state at time of last update
environment_state:
  branch: "feat/context-handoff"
  services_running: ["dev server on :3000"]
  notes: "migration pending — don't run db:reset"

# Reference to a prior session pack for full lineage (optional)
prior_session: "~/.claude/handoffs/YYYY-MM-DD-prior-topic.md"
---

# Context Handoff — [topic]

**Session:** [date] · **Goal:** [goal] · **Resume at:** [resume_point]

## What we were working on

[2-3 sentences describing the session's purpose and current state]

## Decisions made

[Each decision with its reasoning, in plain English. Note superseded decisions inline.]

## Ruled out

[Each rejected option with its reasoning — critical section. Note revisit conditions where relevant.]

## Open threads

[Bulleted list of unresolved items, with priority]

## Next actions

[Ordered list of what to do next]
```

### files_touched path format

Store `files_touched` as paths relative to the git root (output of `git rev-parse --show-toplevel`). If not in a git repo, store absolute paths.

### Artifact size management

Each `artifacts` entry should be truncated to ~500 chars. If an artifact is larger, store only the first 300 chars + `"... [truncated, see <file_path>]"`. The pack should stay under ~50KB total.

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

Then ask: "Any of these no longer apply?" If the user names one, remove it from `behavioral_contracts` and write the pack. Otherwise proceed — don't wait for confirmation.

---

## Linked Sessions (Chaining)

Packs can reference prior packs for full lineage via `prior_session`. On load, Claude may offer to also load the prior session for deeper context, but does not do so automatically.

---

## Edge Cases

**Zero packs on load:** If `~/.claude/handoffs/` is empty or doesn't exist: "No packs found. Use `/context-handoff pack` to create one."

**Corrupted / malformed pack:** If YAML frontmatter fails to parse, fall back to reading the markdown body only and warn: `⚠ Pack YAML could not be parsed — loading human-readable layer only. Behavioral contracts and work state will not be restored.`

**Ambiguous partial match:** For commands that accept partial pack names (delete, close, rename), error if multiple packs match and list the candidates.

**Superseded decisions on load:** Surface decisions with a `superseded_by` field as struck-through context so the receiver understands the evolution. Don't hide them — the history matters.

---

## Finding Packs

List available packs:
```bash
# /context-handoff list
# or directly:
ls -lt ~/.claude/handoffs/
```

Load the most recent:
```bash
# /context-handoff load
# Claude shows a summary list and you pick, or it picks the most recent
```

Load a specific pack:
```bash
# /context-handoff load 2026-05-16-vibe-safe-release
```

Search across all packs:
```bash
# /context-handoff search "semgrep"
```
