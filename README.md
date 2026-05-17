# context-handoff

![version](https://img.shields.io/badge/version-1.5.0-blue)
![license](https://img.shields.io/badge/license-MIT-green)
![skill](https://img.shields.io/badge/Claude%20Code-skill-orange)

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

## How it works

```
Session starts   →  /context-handoff (or /context-handoff load)
                    smart-routes to resume or save
                    restores contracts, decisions, work state, open threads
                         │
                         ▼
Work happens     →  auto-updates fire:
                    • git commit  → immediate update (PostToolUse hook)
                    • decision detected → Claude appends inline
                    • ~5 turns   → fallback cadence update
                         │
                         ▼
Session ends     →  pack is a complete living record
                         │
                         ▼
New session      →  /context-handoff load
                    resumes exactly — contracts re-established, work state intact
```

---

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

### First-time setup

```
/context-handoff setup
```

Walks you through hook installation, directory creation, and creates your first pack. Run once after installing.

```
/context-handoff help
```

Shows all commands grouped by category. Run any time you forget a command.

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

### Other commands (v1.1.0+)

| Command | Description |
|---------|-------------|
| `/context-handoff` | Smart-route: resume active session, or offer to create one |
| `/context-handoff help` | Show all commands grouped by category — in-session reference |
| `/context-handoff setup` | Interactive first-time setup wizard |
| `/context-handoff doctor` | Verify hook, directories, active session, and skill version |
| `/context-handoff version` | Show the installed skill version |
| `/context-handoff list [query] [--all] [--limit <n>] [--tag <tag>]` | List packs, optionally filtered; defaults to 20 most recent |
| `/context-handoff search <query>` | Full-text search across all pack content |
| `/context-handoff delete <name>` | Delete a pack by name. Accepts `--dry-run` |
| `/context-handoff close <thread>` | Mark an open thread as resolved |
| `/context-handoff contracts` | Show active behavioral contracts for the current session |
| `/context-handoff threads` | List all open threads across all packs |
| `/context-handoff diff <name>` | Show what changed between two updates of a pack. Accepts `--vs-current` to diff against live session |
| `/context-handoff merge <a> <b>` | Merge two packs into one (combines decisions, threads, contracts). Accepts `--dry-run` |
| `/context-handoff rename <old> <new>` | Rename a pack file |
| `/context-handoff tag <pack> <tag> [--remove]` | Add or remove a tag on a pack |
| `/context-handoff status` | Quick health check — active pack, last updated, open thread count |
| `/context-handoff open <name>` | View a pack's content without loading it |
| `/context-handoff add-thread <text>` | Add an open thread to the active pack. Accepts `--priority high\|medium\|low` |
| `/context-handoff archive` | Move packs not updated in 30+ days to `archive/`. Accepts `--older-than <days>` |
| `/context-handoff fork <name>` | Create a variant of a pack for a parallel approach, preserving lineage |
| `/context-handoff export <name>` | Export pack to clean markdown or JSON — no YAML, shareable with anyone |
| `/context-handoff amend-decision <text>` | Edit an existing decision's reasoning or mark it superseded |
| `/context-handoff note <text>` | Add a quick observation to the active pack (lighter-weight than a thread) |
| `/context-handoff notes` | List all notes in the active session |

Commands that accept `--project`: `pack`, `load`, `archive`, `fork`, `search`, `threads` — saves/reads from `.claude/handoffs/` inside the git repo instead of `~/.claude/handoffs/`.

> Common aliases: `save` = `pack`, `resume` = `load`, `rules` = `contracts`, `thread` = `add-thread`, `resolve` = `close`.

`load` also accepts `--state-only` to restore work state without re-establishing behavioral contracts.

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

## Project-scoped packs

By default packs go to `~/.claude/handoffs/` (personal, not committed). For team sharing, use `--project` to save inside the repo:

```bash
/context-handoff pack --project
# saves to .claude/handoffs/YYYY-MM-DD-topic.md inside the git repo
```

Add `.claude/handoffs/` to your repo and commit packs you want to share. `list` always shows both locations.

---

## vs Claude's built-in memory

Users often ask: "how is this different from Claude's memory files?"

| | context-handoff | Claude memory files |
|---|---|---|
| Scope | One session / project | Across all sessions |
| What's captured | Decisions, reasoning, work state, contracts | Facts, preferences, project notes |
| Load mechanism | Explicit — you choose when and what | Always-on background context |
| Team sharing | Yes — commit the pack file | No — per-user |
| Session replay | Yes — diff between sessions | No |
| Best for | Continuing a specific thread of work | Persistent cross-project knowledge |

They're complementary, not competing. Use both.

---

## What's next (v2.0)

**v1.5.0 shipped:** No-arg smart routing (`/context-handoff` alone resumes or offers to save), proactive packing offer at natural session endpoints (20 turns, closing phrases, milestone completion), first-time onboarding message on first command, visible save confirmations show pack topic.

**v1.4.0 shipped:** `doctor` command (verifies full install health), `notes` list command, `version` command, tag management (`tag`, `--tag` filter on `list`), `search` now covers notes and artifacts, `contracts` edit flow fully specced, `setup` wizard references install script correctly.

**v1.3.2 shipped:** `setup` wizard, `help` command, `--quiet` load, `--yes` flag, command aliases, formatted search output, global thread priority sort.

**v1.2.1 shipped:** same-topic pack detection, scope consistency across all commands, `export`/`amend-decision`/`note`, `prior_session` auto-link, `CLAUDE.md` check on load.

**v1.2.0 shipped:** `status`, `open`, `add-thread`, `archive`, `fork` commands; `diff --vs-current`, `load --state-only`, `delete/merge --dry-run` flags; merge conflict detection; CLAUDE.md contract seeding; stale session detection; structured `communication_style` field in pack format.

**v1.1.0 shipped:** new commands (`list`, `search`, `delete`, `close`, `contracts`, `threads`, `diff`, `merge`, `rename`), pack format improvements, staleness detection, and session ID pinning.

v1.1.0 is still single-session continuity. v2.0 will be multi-agent and team-native:

- **Append-only decisions log** — multiple Claude sessions write to the same pack without collisions
- **Git-native sync** — session branches merge into a shared pack; teams pull context like they pull code
- **No new infrastructure** — still pure skill, same zero-dependency install

---

## FAQ

**Can I have multiple active packs at once?**
Yes — each `/context-handoff pack` creates a new file. `/context-handoff load` lets you pick which one to restore.

**Does this work without the commit hook?**
Yes. The hook adds commit-triggered auto-updates. Without it, decision detection and turn cadence still fire.

**How is this different from just summarizing the conversation?**
A summary tells you what happened. A pack tells you what to do next — with the reasoning behind every decision and every option that was considered and rejected.

**Can teammates use each other's packs?**
Yes. Commit the `.claude/handoffs/` folder to your repo. Anyone who loads your pack gets your full decision context.

**What happens to old packs?**
They accumulate in `~/.claude/handoffs/`. Use `/context-handoff list` to browse and `/context-handoff delete` to clean up.

---

## Upgrading

```bash
cd ~/.claude/skills/context-handoff && git pull
```

Pack format is backwards-compatible. Packs created in v1.0 and v1.1 load without changes.

---

## License

MIT
