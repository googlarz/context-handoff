# context-handoff

![version](https://img.shields.io/badge/version-1.7.1-blue)
![license](https://img.shields.io/badge/license-MIT-green)
![skill](https://img.shields.io/badge/Claude%20Code-skill-orange)

**Your Claude sessions have amnesia. This fixes it.**

A Claude Code skill that saves what happened in a session — decisions made, things tried and rejected, where you left off, how you like to work — and brings it all back in any new conversation. Pick up exactly where you stopped.

Works for you, your future self, your teammates, and parallel Claude sessions.

---

## The problem

Every time you start a new Claude session, you re-explain everything. The context, the constraints, what was tried, what was ruled out, how you like to work. An hour of hard-won decision context, gone.

The worst part isn't the summary — it's the **ruled-out list**. The things that were considered, debated, and rejected for good reasons. Without it, every new session risks re-litigating the same decisions.

## What it does

Saving a session (`/context-handoff save`) captures it into a living document:

| What's saved | Why it matters |
|-------------|---------------|
| **Decisions + reasoning** | Not just "we chose X" but "we chose X over Y because Z" — stops the same debate from happening twice. |
| **Dead ends + why** | The most expensive context to lose. Every wrong turn that was considered and rejected, with the reason. |
| **Where you left off** | Current goal, files touched, position in any active plan. |
| **How you like to work** | Preferences established, how Claude was behaving, what you pushed back on. |
| **Communication style** | Tone, verbosity, implicit agreements built up over the session. |
| **Open questions** | Unresolved threads with full context — nothing falls through the cracks. |

`/context-handoff resume` restores all of it into a new session. Claude reads everything back, re-establishes how you like to work, and picks up from the exact resume point — before doing anything else.

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

**The easiest way — just tell Claude:**

> "Install this skill: https://github.com/googlarz/context-handoff"

Claude clones the repo, updates your settings, and installs the commit hook. Done.

**Manual install:**

```bash
git clone https://github.com/googlarz/context-handoff ~/.claude/skills/context-handoff
bash ~/.claude/skills/context-handoff/scripts/install-hook.sh
```

Then add to your Claude Code settings:

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
| `/context-handoff profile [edit]` | Persistent personal context loaded automatically in every session |
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
| `/context-handoff import <file>` | Extract context from a meeting note, doc, or text file into the active pack |
| `/context-handoff sync [--source <name>] [--since <duration>]` | Pull context from connected MCPs (Granola, Slack, Linear, GitHub…) — optional |
| `/context-handoff notes` | List all notes in the active session |
| `/context-handoff verify` | Diff Claude's stated session understanding against the written pack |

Commands that accept `--project`: `pack`, `load`, `archive`, `fork`, `search`, `threads` — saves/reads from `.claude/handoffs/` inside the git repo instead of `~/.claude/handoffs/`.

> Common aliases: `save`/`snapshot` = `pack`, `resume`/`continue` = `load`, `rules`/`how-i-work` = `contracts`, `thread`/`todo` = `add-thread`, `resolve`/`done` = `close`, `share` = `export`, `del`/`rm` = `delete`.

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
      },
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'CONTEXT-HANDOFF: file-write detected — update files_touched'"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "compact",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'CONTEXT-HANDOFF: pre-compact — save pack now'"
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

## Using your context in other tools

Every time context-handoff saves, it also writes `~/.claude/handoffs/current.json` — a flat JSON snapshot of the active session. Any tool that can read a file can consume it. No special integration, no API key.

### Cursor / Windsurf / other AI editors

Add one line to your rules file (`.cursorrules`, `.windsurfrules`, etc.):

```
At session start, read ~/.claude/handoffs/current.json for current work context, open decisions, and resume point.
```

### Claude.ai (web or mobile)

Run `/context-handoff export` in Claude Code — it copies a clean markdown summary to your clipboard. Paste it into your first message on the web.

### Any MCP-compatible agent

Point directly at the file:

```json
{
  "mcpServers": {
    "context": {
      "command": "cat",
      "args": ["~/.claude/handoffs/current.json"]
    }
  }
}
```

Or just tell the agent: *"Read ~/.claude/handoffs/current.json for my current session context."*

### What's in current.json

```json
{
  "topic": "vibe-safe-release",
  "resume_point": "README needs updating — all code done",
  "work_state": {
    "goal": "ship v1.9.0",
    "files_touched": ["vibe-safe.sh", "README.md"],
    "plan_position": "step 3 of 4"
  },
  "decisions": [...],
  "open_threads": [...],
  "behavioral_contracts": [...]
}
```

Updated automatically on every save — no manual export needed.

---

## Using with your team

### Share a session with a teammate

Pack your session, commit the file, done. Your teammate loads it and picks up with your full decision context — not just a summary, but every decision and every dead end with its reasoning.

```bash
# Save your session to the project (instead of ~/.claude/handoffs/)
/context-handoff save --project

# Commit it
git add .claude/handoffs/
git commit -m "handoff: auth refactor context for @teammate"
git push
```

Your teammate:
```
/context-handoff resume --project
```

### Parallel work with fork

Two people working on the same problem from different angles:

```
/context-handoff fork auth-refactor auth-approach-a
/context-handoff fork auth-refactor auth-approach-b
```

Each fork preserves the full decision history. When one approach wins, merge the insights back:

```
/context-handoff merge auth-approach-a auth-approach-b
```

### Project-scoped vs global packs

| | Global (`~/.claude/handoffs/`) | Project (`.claude/handoffs/`) |
|---|---|---|
| Visible to | You only | Everyone who clones the repo |
| Good for | Personal work, solo projects | Team handoffs, shared context |
| Committed to git | No | Yes (add `.claude/handoffs/` to repo) |

Use `--project` flag on `save`, `resume`, `archive`, `fork`, `search`, and `threads` to switch scope.

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

### Optional MCP integrations

`sync` pulls from connected MCP services — Granola, Fathom, Slack, Linear, Notion, GitHub, Calendar. Connect any, use none, the skill works either way.

```bash
# Pull from all connected sources (last 24h)
/context-handoff sync

# Pull from one source, last 7 days
/context-handoff sync --source granola --since 7d
```

---

## What's next (v2.0)

**v1.7.0 shipped:** Architecture overhaul targeting the four solvable reliability gaps — per-CWD active session tracking (multiple terminal tabs no longer collide), `update_log` append field in pack format v1.3 (chronological replay of every update within a session), PreCompact hook (full pack write before every context compaction so nothing is lost at the boundary), catchup write strategy (session drift from pure-conversation turns is caught on the next trigger), systematic `verify` (scans actual assistant messages for decision candidates instead of relying on Claude's memory alone).

**v1.6.5 shipped:** Plain-language README intro, team usage guide (project-scoped packs, fork for parallel work, sharing via git), `import` now accepts URLs (Fathom links, Notion pages, GitHub issues), `doctor` checks for available updates, proactive save offer at 10 turns (down from 20), new aliases: `del`/`rm`=delete, `share`=export.

**v1.6.4 shipped:** Plain-language help — all commands now show what they actually do alongside their technical names. `current.json` cross-tool guide — Cursor, Windsurf, Claude.ai web, and any MCP agent can now consume the active session with zero extra setup.

**v1.6.3 shipped:** Optional MCP sync — `sync` command pulls from Granola, Fathom, Slack, Linear, Notion, GitHub, Calendar if connected. Graceful degradation: shows what's missing and how to connect it. Core skill unchanged — zero dependencies.

**v1.6.2 shipped:** Personal profile (`~/.claude/handoffs/profile.md`) — persistent cross-session context for personal facts, professional context, preferences, and hard "never do this" rules. Loaded silently in every session automatically. Edit with `/context-handoff profile edit`.

**v1.6.1 shipped:** Auto-pack on session start (pack created silently from turn 1, no manual command needed), `import` command (pull decisions/threads/notes from meeting notes, Slack exports, docs), `current.json` mirror (active pack always available as JSON at `~/.claude/handoffs/current.json` for any agent or tool to read — not just Claude).

**v1.6.0 shipped:** Expert reliability overhaul — `verify` command (diffs session memory vs. written pack), pack integrity hash (SHA-256 verified on load), concurrency protection (two parallel sessions no longer clobber each other), Write/Edit hook (files_touched updated on every file change, not just git commits), decision history (amend-decision preserves prior reasoning in `history` sub-field), pack size budget (auto-archives closed threads and superseded decisions above threshold).

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
