---
name: context-handoff
version: "1.2.0"
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
| `/context-handoff pack [--project]` | Create a context pack from the current session |
| `/context-handoff load [--project] [--state-only] [--contracts-only]` | Load a context pack at the start of a new session |
| `/context-handoff update` | Force-write an update to the current session's pack |
| `/context-handoff status` | Quick health check for the current session |
| `/context-handoff list [query]` | List all packs (global + project), optionally filtered |
| `/context-handoff open <pack>` | View a pack's human-readable layer without loading it |
| `/context-handoff search <query>` | Search pack content across all packs |
| `/context-handoff delete [--dry-run] <pack>` | Delete a named pack after confirmation |
| `/context-handoff close <thread>` | Mark an open thread as resolved |
| `/context-handoff add-thread <text> [--priority high\|medium\|low]` | Add an open thread to the active pack |
| `/context-handoff contracts` | View and edit active behavioral contracts |
| `/context-handoff threads` | Show all open threads across all packs |
| `/context-handoff diff [--vs-current] [pack1] [pack2]` | Compare two packs, or a pack against current git state |
| `/context-handoff merge [--dry-run] <pack1> <pack2>` | Merge two packs into a combined pack |
| `/context-handoff rename <pack> <new-name>` | Rename a pack and update its topic field |
| `/context-handoff archive [--older-than <days>]` | Move old packs to archive/ subdirectory |
| `/context-handoff fork <pack> [<new-name>]` | Create a variant of an existing pack for a parallel approach |

---

## `/context-handoff pack [--project]`

Synthesize the current conversation into a context pack file.

**Scope:**
- Default: save to `~/.claude/handoffs/`
- `--project`: save to `.claude/handoffs/` inside the current git repo. If not in a git repo: error "Not in a git repo — cannot use --project scope"

**Steps:**
1. Infer the topic from the conversation (or ask the user if ambiguous)
2. Create the target directory if it doesn't exist
3. **Stale session check:** If `~/.claude/handoffs/.active` (or `.claude/handoffs/.active` for `--project`) already exists and the `last_updated` timestamp in that pack file is more than 4 hours old, surface it before proceeding:
   > "Previous session detected: [topic] (last updated X hours ago). Load it, discard it, or ignore and continue?"
   - **Load:** run `/context-handoff load` with that pack
   - **Discard:** delete `.active` and proceed
   - **Ignore:** proceed without clearing `.active` (user manages it)
4. Generate the pack file at `<dir>/YYYY-MM-DD-<topic-slug>.md`
5. **CLAUDE.md seeding:** Before synthesizing behavioral contracts from the session:
   a. Check if `CLAUDE.md` exists in the current directory or `~/.claude/CLAUDE.md`
   b. If found, read it and extract any behavioral instructions (style, process, constraints)
   c. Seed these into `behavioral_contracts` prefixed with `[CLAUDE.md]` so they're distinguishable from session-derived ones
6. Populate both layers (see Pack Format below)
7. Write the session marker: `<dir>/.active` → `session_id|/full/path/to/pack.md|last_updated_timestamp`
8. Confirm: tell the user the file path and that auto-updates are now active
9. Check if the hook is installed (look for "CONTEXT-HANDOFF" in `~/.claude/settings.json`). If not found, emit once: `⚠ Commit hook not installed — run scripts/install-hook.sh for automatic commit-triggered updates.`

**Session ID:** Generate as `ch-YYYYMMDD-<4-char-random>` and store in the pack frontmatter.

---

## `/context-handoff load [--project] [--state-only] [--contracts-only]`

Load a context pack at the start of a new session.

**Scope:**
- Default: load from `~/.claude/handoffs/`
- `--project`: load from `.claude/handoffs/` inside the current git repo. If not in a git repo: error "Not in a git repo — cannot use --project scope"

**Flags:**
- `--state-only`: restore only `work_state`, `resume_point`, and `open_threads` — skips behavioral contracts and communication style. Useful when you want to know where you left off without changing how Claude behaves.
- `--contracts-only`: restore only behavioral contracts and communication style, skipping work state and decisions. Useful when starting a fresh task but wanting to preserve working style.

**Steps:**
1. **Stale session check:** If `.active` already exists and the `last_updated` timestamp in that pack file is more than 4 hours old, surface it before proceeding:
   > "Previous session detected: [topic] (last updated X hours ago). Load it, discard it, or ignore and continue?"
   - **Load:** run `/context-handoff load` with that pack
   - **Discard:** delete `.active` and proceed
   - **Ignore:** proceed without clearing `.active` (user manages it)
2. If a file path is given, load that file. Otherwise list the 5 most recent packs with a one-line summary per pack and ask the user to choose:
   ```
   1. 2026-05-16 · vibe-safe-release · 9 updates · 3 open threads
   2. 2026-05-15 · llmessenger-auth · 4 updates · 1 open thread
   ```
   Pick the most recent if context makes it obvious.
3. If the handoffs directory is empty or doesn't exist: "No packs found. Use `/context-handoff pack` to create one."
4. Read the pack file. If YAML frontmatter fails to parse, fall back to reading the markdown body only and warn: `⚠ Pack YAML could not be parsed — loading human-readable layer only. Behavioral contracts and work state will not be restored.`
5. **Staleness check:** If `last_updated` is more than 7 days ago, warn before restoring:
   > `⚠ This pack is X days old (last updated YYYY-MM-DD). Resume point and open threads may be stale.`
   Continue loading regardless.
6. Parse the AI YAML layer
7. Unless `--state-only` is set: **explicitly re-establish each behavioral contract** — state them out loud so the user can correct anything wrong. Note any contracts prefixed with `[CLAUDE.md]` as "from project config — may differ if you're in a different project."
8. Ask: "Any of these no longer apply?" If the user names one, remove it from `behavioral_contracts` and write the pack.
9. Unless `--contracts-only` is set: restore work state awareness: goal, files touched, plan position. Surface superseded decisions as struck-through context so the receiver understands the evolution.
10. Acknowledge the load:
    > "Loaded: **[topic]** (saved [date], [update_count] updates). Resuming from: [resume_point]."
11. List any open threads (with priority if set)
12. If the current directory is a git repo, run `git log --oneline` since `last_updated` and surface it:
    > `4 commits since this pack was last updated: [list]`
13. Write the session marker: `<dir>/.active` → `session_id|/full/path/to/pack.md|last_updated_timestamp`
14. Proceed — do not ask "ready to continue?", just continue

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

## `/context-handoff status`

Quick health check for the current session. Reads `~/.claude/handoffs/.active` and shows:

```
Active pack: 2026-05-16-vibe-safe-release
Last updated: 47 minutes ago (2026-05-16T18:30:00Z) · 9 updates
Open threads: 3 (1 high, 1 medium, 1 low)
Hook: installed
```

If no `.active` file: "No active session. Use `/context-handoff pack` or `/context-handoff load`."

---

## `/context-handoff list [query]`

List all packs in `~/.claude/handoffs/` and the project-local `.claude/handoffs/` (if it exists), sorted by most recent. Label each entry `[global]` or `[project]`.

**Output columns:** filename · topic · last_updated · update_count · open thread count · scope

**Optional query:** `/context-handoff list vibe-safe` filters by topic/content match.

If no packs exist: "No packs found."

---

## `/context-handoff open <pack>`

View a pack's human-readable layer without loading it.

Shows:
- A brief YAML summary: topic, last_updated, update_count, open thread count, resume_point
- The full markdown body (below the YAML frontmatter)

Does NOT write to `.active` or restore any state.

Accept partial name match if unambiguous.

---

## `/context-handoff search <query>`

Search pack content across all packs (topic, decisions, ruled_out, open_threads). Show matching packs with the matching excerpt.

Implementation: `grep -r -n -B1 -A2 "<query>" ~/.claude/handoffs/*.md` — returns matching lines with context, not just filenames. Show: filename, line number, matched line, 2 lines after.

---

## `/context-handoff delete [--dry-run] <pack>`

Delete a named pack after confirmation. Accept partial name match if unambiguous (error if multiple packs match).

Show the pack's topic, last_updated, and update_count before confirming.

`--dry-run`: show what would be deleted (topic, last_updated, update_count) without deleting — "would delete this pack."

On confirm (without `--dry-run`), delete the file and confirm deletion.

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

## `/context-handoff add-thread <text> [--priority high|medium|low]`

Add an open thread to the active pack.

**Steps:**
1. Read `~/.claude/handoffs/.active` to get the current pack path. If no active session: error "No active session. Load a pack first."
2. Append the new thread to `open_threads` with `added_at` timestamp. Default priority: `medium`.
3. Write the pack.
4. Confirm: `✓ Thread added: "[text]" [priority]`

---

## `/context-handoff contracts`

Show currently active behavioral contracts from the loaded pack.

**Steps:**
1. Display the current `behavioral_contracts` list (numbered). Note any `[CLAUDE.md]`-prefixed contracts as sourced from project config.
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

## `/context-handoff diff [--vs-current] [pack1] [pack2]`

Compare two packs for the same project.

- If only one pack given, diff against the previous pack for the same topic (by filename date prefix)
- Show: new decisions since pack1, newly closed threads, changes to work_state, newly ruled-out items
- Superseded decisions are highlighted

**`--vs-current` flag:** `/context-handoff diff --vs-current [pack]` compares the named pack (or most recent) against the current git state:
- Runs `git log --oneline` since `last_updated` to show commits since the pack
- Runs `git diff --stat HEAD` to show files changed since pack's `files_touched`
- Flags any `open_threads` that reference files with recent changes

---

## `/context-handoff merge [--dry-run] <pack1> <pack2>`

Merge context from two packs into a new combined pack.

**Merge rules:**
- `decisions`: union, deduplicated by `what` field
- `open_threads`: union of all open threads
- `work_state`: latest `last_updated` wins
- `behavioral_contracts`: merged with exact duplicates removed
- `ruled_out`: union, deduplicated by `what` field
- `closed_threads`: union

**Conflict detection:** After computing the union of decisions, check for conflicts: two decisions whose `what` fields are semantically opposite or contradictory. Simple heuristic: flag any two decisions where one's `what` contains negation words relative to the other ("don't use X" vs "use X", "avoid Y" vs "use Y"). Surface flagged conflicts and ask the user to resolve each before writing the merged pack.

`--dry-run`: show the merged result in the terminal without writing a file.

**Output file:** `~/.claude/handoffs/YYYY-MM-DD-<topic1>-<topic2>-merged.md`

Confirm the output path after writing.

---

## `/context-handoff rename <pack> <new-name>`

Rename a pack file and update its `topic` field in frontmatter to match.

Accept partial name match if unambiguous. Confirm the old and new filename before renaming.

---

## `/context-handoff archive [--older-than <days>]`

Move old packs to `~/.claude/handoffs/archive/` (and `.claude/handoffs/archive/` for project-scoped packs).

**Steps:**
1. Default threshold: 30 days since `last_updated`. `--older-than <days>` overrides this.
2. Show the user what would be archived BEFORE moving (dry-run preview).
3. Ask for confirmation.
4. Move matching files to the `archive/` subdirectory, create it if needed.
5. Confirm: "Archived N packs to ~/.claude/handoffs/archive/"

---

## `/context-handoff fork <pack> [<new-name>]`

Create a variant of an existing pack for a parallel approach, preserving full lineage.

**Steps:**
1. Copy the pack file to `YYYY-MM-DD-<new-name>.md` (or `YYYY-MM-DD-<original-topic>-fork.md` if no name given).
2. Update the copy:
   - New `session_id` (generate fresh `ch-YYYYMMDD-<4-char-random>`)
   - `created` = now
   - `update_count` = 0
   - `update_triggers` = []
   - Add `forked_from: "<original-pack-path>"` field
3. Clear `work_state.plan_position` in the fork (start fresh on plan position).
4. Do NOT overwrite `.active` — the fork is not automatically loaded.
5. Confirm: "Fork created: [path]. Use `/context-handoff load <name>` to switch to it."

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

**Important:** Turn cadence uses both turn counting AND time elapsed — whichever fires first. On every auto-update trigger (commit or decision), also check if `last_updated` in the pack is more than 30 minutes old. If so, treat it as a cadence update too (reset the implicit turn counter). This mitigates unreliable turn counting after context compaction.

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
pack_version: "1.2"

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

# Optional labels for filtering, e.g. ["auth", "backend", "release"]
tags: []

# How Claude was behaving — restore these exactly on load
# Entries prefixed with [CLAUDE.md] were seeded from project config
behavioral_contracts:
  - "example: no filler or pleasantries"
  - "example: surgical changes only"
  - "[CLAUDE.md] example: contract seeded from project CLAUDE.md"

# How this person communicates — populated from observed session behavior on pack
communication_style:
  tone: "direct and terse"
  verbosity: low   # low | medium | high
  preferences:
    - "markdown tables for comparisons"
    - "concrete over abstract"
  anti_patterns:
    - "no end-of-turn summaries"
    - "no pleasantries"

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

# Set when this pack was forked from another (optional)
forked_from: "~/.claude/handoffs/YYYY-MM-DD-original-topic.md"
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

When loading a pack (unless `--state-only` is set), re-establish contracts explicitly. State them so the user can correct anything stale:

> "Restoring behavioral contracts from last session:
> - [contract 1]
> - [contract 2] *(from CLAUDE.md — may differ in a different project)*
> Let me know if anything has changed."

Then ask: "Any of these no longer apply?" If the user names one, remove it from `behavioral_contracts` and write the pack. Otherwise proceed — don't wait for confirmation.

---

## CLAUDE.md Seeding

On `/context-handoff pack`, behavioral contracts sourced from `CLAUDE.md` are prefixed with `[CLAUDE.md]` in `behavioral_contracts`. This makes them distinguishable from contracts derived from the session.

On `load`, `[CLAUDE.md]`-prefixed contracts are restored but flagged as "from project config — may differ if you're in a different project." The user can remove them via `/context-handoff contracts` or the load confirmation step.

---

## --project Scope

Both `pack` and `load` accept `--project`:
- Saves/loads from `.claude/handoffs/` inside the current git repo instead of `~/.claude/handoffs/`
- `list` always shows both locations, labelled `[global]` and `[project]`
- If `--project` is used outside a git repo: error "Not in a git repo — cannot use --project scope"

---

## Linked Sessions (Chaining)

Packs can reference prior packs for full lineage via `prior_session`. On load, Claude may offer to also load the prior session for deeper context, but does not do so automatically.

Forked packs reference their origin via `forked_from` (set automatically by `/context-handoff fork`).

---

## Edge Cases

**Zero packs on load:** If the handoffs directory is empty or doesn't exist: "No packs found. Use `/context-handoff pack` to create one."

**Corrupted / malformed pack:** If YAML frontmatter fails to parse, fall back to reading the markdown body only and warn: `⚠ Pack YAML could not be parsed — loading human-readable layer only. Behavioral contracts and work state will not be restored.`

**Ambiguous partial match:** For commands that accept partial pack names (delete, close, rename, open, fork), error if multiple packs match and list the candidates.

**Superseded decisions on load:** Surface decisions with a `superseded_by` field as struck-through context so the receiver understands the evolution. Don't hide them — the history matters.

**Stale `.active` on startup:** When `pack` or `load` is invoked and `.active` exists with a `last_updated` more than 4 hours old, surface the previous session and ask the user how to proceed (load / discard / ignore) before continuing.

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
