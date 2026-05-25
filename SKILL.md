---
name: context-handoff
version: "1.7.1"
description: Session continuity for Claude — pack your current session state and load it into any new conversation with full context, decisions, behavioral contracts, and work state restored. Auto-updates on commits, decisions, and every 5 turns.
tags: [session-continuity, context, handoff, productivity]
author: googlarz
---

# Context Handoff

Preserve full session context across Claude conversations. Pack the current session — decisions, reasoning, work state, behavioral contracts, what was ruled out and why — and load it into any new chat. The new session resumes as if the conversation never ended.

Works for you, your future self, your teammates, and parallel Claude sessions.

## Commands

All commands that prompt for confirmation accept `--yes` / `-y` to skip. See the [Aliases](#aliases) section for shorthand forms.

| Command | What it does |
|---------|-------------|
| `/context-handoff` | Smart-route: resume active session or offer to create one |
| `/context-handoff pack [--project]` | Create a context pack from the current session |
| `/context-handoff load [--quiet] [--project] [--state-only] [--contracts-only]` | Load a context pack at the start of a new session |
| `/context-handoff update` | Force-write an update to the current session's pack |
| `/context-handoff verify` | Diff Claude's stated session understanding against what's actually in the pack file |
| `/context-handoff status` | Quick health check for the current session |
| `/context-handoff list [query] [--all] [--limit <n>] [--tag <tag>]` | List packs, optionally filtered; defaults to 20 most recent |
| `/context-handoff open <pack> [--full]` | View a pack's summary and first 40 lines without loading it |
| `/context-handoff search [--project] <query>` | Search pack content across all packs (or project-only with --project) |
| `/context-handoff threads [--project]` | All open threads across packs, sorted by priority |
| `/context-handoff add-thread <text> [--priority high\|medium\|low]` | Add an open thread to the active pack |
| `/context-handoff close <thread>` | Mark an open thread as resolved |
| `/context-handoff notes` | List all notes in the active pack |
| `/context-handoff note <text>` | Add a quick observation to the active pack |
| `/context-handoff import <file>` | Extract context from a meeting note, doc, Slack export, or any text file and merge it into the active pack |
| `/context-handoff sync [--source <name>] [--since <duration>]` | Pull recent context from connected MCP integrations (Granola, Slack, Linear, GitHub, etc.) — optional, degrades gracefully if no MCPs connected |
| `/context-handoff contracts` | View and edit active behavioral contracts |
| `/context-handoff amend-decision <partial-what>` | Edit an existing decision's reasoning in the active pack |
| `/context-handoff diff [--vs-current] [pack1] [pack2]` | Compare two packs, or a pack against current git state |
| `/context-handoff merge [--dry-run] <pack1> <pack2> [output-name]` | Merge two packs into a combined pack |
| `/context-handoff rename <pack> <new-name>` | Rename a pack and update its topic field |
| `/context-handoff tag <pack> <tag> [--remove]` | Add or remove a tag on a pack |
| `/context-handoff archive [--project] [--older-than <days>]` | Move old packs to archive/ subdirectory |
| `/context-handoff delete [--dry-run] <pack>` | Delete a saved session by name |
| `/context-handoff fork [--project] <pack> [<new-name>]` | Create a variant of an existing pack for a parallel approach |
| `/context-handoff export <pack> [--format markdown\|json] [--output <file>]` | Export a pack to a clean shareable format |
| `/context-handoff profile [edit]` | View or edit your persistent personal profile — context that loads automatically in every session |
| `/context-handoff setup` | Interactive first-time setup wizard |
| `/context-handoff doctor` | Check hook installation, dirs, active session, and skill version |
| `/context-handoff version` | Show the installed skill version |
| `/context-handoff help` | Show a compact in-session command reference |

---

## No-argument invocation

When `/context-handoff` is invoked with no subcommand, smart-route based on session state:

1. Check `~/.claude/handoffs/.active` and `.claude/handoffs/.active`
2. **Active pack found (updated < 4 hours ago):**
   > "Resume **[topic]** from [X ago]? (y/n)"
   - **Yes:** run `/context-handoff load [pack]`
   - **No:** ask "Create a new session pack instead? (y/n)" — if yes, run `/context-handoff pack`
3. **No active pack (or stale):**
   > "No active session. Save this conversation as a context pack? (y/n)"
   - **Yes:** run `/context-handoff pack`
   - **No:** show `/context-handoff help`

This is the recommended entry point for users who don't remember command names.

---

## First-time onboarding

When any `/context-handoff` command is invoked and `~/.claude/handoffs/` does not exist:

Show this exactly once before executing the command:

> **context-handoff** remembers your sessions. Decisions made, things tried and rejected, where you left off, how you like to work — all of it restored when you come back. Type `/context-handoff help` to see all commands.

Then execute the original command. Never show this message again once the directory exists.

This ensures first-time users understand what they're getting without reading the README first.

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
4. **Same-topic detection:** Before generating the new pack file, compute the topic slug for the new pack. Check whether any file matching `*-<topic-slug>.md` already exists in the target directory. If found, surface it before proceeding:
   > "A pack for this topic already exists: 2026-05-16-vibe-safe-release.md (last updated X ago, N updates). Update it or create a new one?"
   - **Update:** run `/context-handoff update` on that pack (rewrite with current session state, increment `update_count`)
   - **New:** proceed with creating a new dated file
5. **prior_session auto-population:** If `.active` exists and is valid (not stale), set `prior_session` in the new pack's frontmatter to the path of the currently active pack before writing.
6. Generate the pack file at `<dir>/YYYY-MM-DD-<topic-slug>.md`
6a. **Integrity hash:** Compute the SHA-256 of the file content **with the `content_hash` field set to an empty string** (i.e., hash the file as if `content_hash: ""`). Store the resulting hex digest in `content_hash` and write the file once. On verification, the same normalization is applied before checking: temporarily replace `content_hash: "<value>"` with `content_hash: ""` in the string before hashing.
7. **CLAUDE.md seeding:** Before synthesizing behavioral contracts from the session:
   a. Check if `CLAUDE.md` exists in the current directory or `~/.claude/CLAUDE.md`
   b. If found, read it and extract any behavioral instructions (style, process, constraints)
   c. Seed these into `behavioral_contracts` prefixed with `[CLAUDE.md]` so they're distinguishable from session-derived ones
8. Populate both layers (see Pack Format below)
9. Write the session marker: read `~/.claude/handoffs/.active` as JSON (empty object `{}` if absent or unreadable). Set the entry for the current working directory:
   ```json
   { "<cwd>": { "session_id": "<session_id>", "pack": "/full/path/to/pack.md", "last_updated": "<timestamp>" } }
   ```
   Write the updated JSON back to `~/.claude/handoffs/.active`.
10. Confirm: tell the user the file path and that auto-updates are now active
11. Check if the hook is installed (look for "CONTEXT-HANDOFF" in `~/.claude/settings.json`). If not found, emit once: `⚠ Commit hook not installed — run scripts/install-hook.sh for automatic commit-triggered updates.`

**Session ID:** Generate as `ch-YYYYMMDD-<4-char-random>` and store in the pack frontmatter.

---

## `/context-handoff load [--quiet] [--project] [--state-only] [--contracts-only]`

Load a context pack at the start of a new session.

**Scope:**
- Default: load from `~/.claude/handoffs/`
- `--project`: load from `.claude/handoffs/` inside the current git repo. If not in a git repo: error "Not in a git repo — cannot use --project scope"

**Flags:**
- `--quiet` / `-q`: skip all browsing steps (no contract listing, no thread listing, no git log, no contract-check question). Just show one line and proceed:
  > "Loaded: **[topic]** (saved [date], [update_count] updates). Resuming from: [resume_point]."
- `--state-only`: restore only `work_state`, `resume_point`, and `open_threads` — skips behavioral contracts and communication style. Useful when you want to know where you left off without changing how Claude behaves.
- `--contracts-only`: restore only behavioral contracts and communication style, skipping work state and decisions. Useful when starting a fresh task but wanting to preserve working style.
- `--yes` / `-y`: in default (non-quiet) mode, skips the "any contracts no longer apply?" question but still shows contracts and threads. Combined with `--quiet`, has no additional effect (quiet is already fully silent).

**Steps (default mode):**
1. **Stale `.active` check:** Only trigger this when NO specific pack name was given. If `.active` already exists and the `last_updated` timestamp in that pack file is more than 4 hours old, surface it before proceeding:
   > "Previous session detected: [topic] (last updated X hours ago). Load it, discard it, or ignore and continue?"
   - **Load:** run `/context-handoff load` with that pack
   - **Discard:** delete `.active` and proceed
   - **Ignore:** proceed without clearing `.active` (user manages it)
   If a specific pack name was given (`/context-handoff load vibe-safe-release`), skip this check entirely and load the requested pack directly.
2. If a file path is given, load that file. Otherwise list the 5 most recent packs with a one-line summary per pack and ask the user to choose:
   ```
   1. 2026-05-16 · vibe-safe-release · 9 updates · 3 open threads
   2. 2026-05-15 · llmessenger-auth · 4 updates · 1 open thread
   ```
   Pick the most recent if context makes it obvious.
3. If the handoffs directory is empty or doesn't exist: "No packs found. Use `/context-handoff pack` to create one."
4. Read the pack file. If YAML frontmatter fails to parse, fall back to reading the markdown body only and warn: `⚠ Pack YAML could not be parsed — loading human-readable layer only. Behavioral contracts and work state will not be restored.`
4a. **Integrity check:** If `content_hash` is present and non-empty, verify it: normalize the file content by replacing the `content_hash` value with an empty string, compute SHA-256 of the normalized content, and compare. If mismatch: `⚠ Pack integrity check failed — file may have been modified outside context-handoff. Proceeding anyway.`
5. **Staleness check:** If `last_updated` is more than 7 days ago, warn before restoring:
   > `⚠ This pack is X days old (last updated YYYY-MM-DD). Resume point and open threads may be stale.`
   Continue loading regardless.
6. Parse the AI YAML layer
7. **CLAUDE.md check:** After parsing the YAML layer:
   - Check if a `CLAUDE.md` exists in the current directory or `~/.claude/CLAUDE.md`
   - Compare its behavioral instructions against the `[CLAUDE.md]`-prefixed contracts in the pack
   - If the current `CLAUDE.md` differs from what was seeded (new instructions, removed instructions), surface the diff:
     > "CLAUDE.md has changed since this pack was created. New instruction: '[text]'. Add to behavioral contracts? (y/n)"
   - If no `CLAUDE.md` exists but the pack has `[CLAUDE.md]`-prefixed contracts, flag them:
     > "⚠ This pack has contracts sourced from a CLAUDE.md that isn't present in this directory."
8. Unless `--state-only` is set: **explicitly re-establish each behavioral contract** — state them out loud so the user can correct anything wrong. Note any contracts prefixed with `[CLAUDE.md]` as "from project config — may differ if you're in a different project."
9. Unless `--yes` / `-y` is set: ask "Any of these no longer apply?" If the user names one, remove it from `behavioral_contracts` and write the pack.
10. Unless `--contracts-only` is set: restore work state awareness: goal, files touched, plan position. Surface superseded decisions as struck-through context so the receiver understands the evolution.
11. Acknowledge the load:
    > "Loaded: **[topic]** (saved [date], [update_count] updates). Resuming from: [resume_point]."
12. List any open threads (with priority if set)
13. If the current directory is a git repo, run `git log --oneline` since `last_updated` and surface it:
    > `4 commits since this pack was last updated: [list]`
14. Write the session marker: read `~/.claude/handoffs/.active` as JSON (empty object if absent). Update the entry for the current working directory with `session_id`, `pack` path, and `last_updated` timestamp. Write back.
14a. **Profile load:** After writing `.active`, silently read `~/.claude/handoffs/profile.md` if it exists. Merge its `personal`, `professional`, `preferences`, and `never` fields into the current session context. Do NOT list these out loud — they are background context, not contracts to recite. Just apply them silently. If any `never` entries exist, treat them as hard behavioral constraints for this session.
15. Proceed — do not ask "ready to continue?", just continue

**`--quiet` mode** skips steps 8–13 entirely. After step 7, emit the single summary line and jump to step 14.

---

## `/context-handoff update`

Force-write a full update to the current session's pack.

**Steps:**
1. Find the active pack by reading `~/.claude/handoffs/.active` (look up entry by current working directory in the JSON map; or ask user if not found)
2. Before writing, check if `last_updated` in the file is newer than what Claude last read. If so, read the current file first and merge (append new decisions, take latest work_state) rather than overwriting.
3. Rewrite the full pack with current state
3a. **Integrity hash:** Recompute SHA-256 of the updated file content with the `content_hash` field set to an empty string (same normalization as pack step 6a), and update `content_hash` with the resulting hex digest.
4. Increment `update_count`, append trigger `manual` to `update_triggers`
5. Confirm silently: `↻ Pack updated (manual) — [path]`

---

## `/context-handoff verify`

Diff Claude's in-memory understanding of the current session against what is actually written in the active pack file.

**Steps:**
1. Read `~/.claude/handoffs/.active` (look up entry by current working directory in the JSON map). If no active session: error "No active session. Load or create a pack first."
2. Read the pack file from disk.
3. **Systematic scan:** Before comparing, extract decision candidates from recent assistant messages by scanning for these patterns:
   - Phrases: 'decided', 'going with', 'chose', 'ruling out', 'won't', 'instead of', 'over X because', 'rejected', 'the approach is'
   - Any sentence with a clear alternative comparison ('X over Y', 'X instead of Y')
   
   Build a candidate list from the scan. This is the ground truth for step 3b below.

3b. Compare on four dimensions:
   - **resume_point:** Claude's current understanding of where we are vs. the written `resume_point`
   - **decisions:** Candidate list from scan vs. `decisions` in pack — flag any candidates not in the pack
   - **open_threads:** Any threads Claude knows about that are not in `open_threads`
   - **work_state.files_touched:** Files Claude has modified this session vs. `files_touched`
4. Report the diff:
   ```
   verify: context-handoff-build
   ══════════════════════════════

   resume_point
     pack:    "writing README — SKILL.md done"
     session: "README done, pushing to GitHub"   ← DRIFT

   decisions
     in session, not in pack:
       - "use --ff-only for git pull in upgrade.sh" (not yet written)

   open_threads
     ✓ match

   files_touched
     in session, not in pack: ["scripts/upgrade.sh"]
   ```
5. If drift is found, offer: "Update the pack now? (y/n)" — if yes, run `/context-handoff update`.
6. If the active pack was created by auto-pack (identifiable by `update_count: 0` and `update_triggers: []` or `["initial"]`), prefix the drift report with:
   > `ℹ This is an auto-created pack (never manually saved). All drift is expected — the pack was not yet populated.`
   Still offer to update.
7. If no drift: "✓ Pack matches session state."

---

## `/context-handoff status`

Quick health check for the current session. Reads `~/.claude/handoffs/.active` (look up entry by current working directory in the JSON map) and shows:

```
Active pack: 2026-05-16-vibe-safe-release
Last updated: 47 minutes ago (2026-05-16T18:30:00Z) · 9 updates
Open threads: 3 (1 high, 1 medium, 1 low)
Hook: installed
```

If no `.active` file: "No active session. Use `/context-handoff pack` or `/context-handoff load`."

---

## `/context-handoff list [query] [--all] [--limit <n>] [--tag <tag>]`

List packs in `~/.claude/handoffs/` and the project-local `.claude/handoffs/` (if it exists), sorted by most recent. Label each entry `[global]` or `[project]`.

**Output columns:** filename · topic · last_updated · update_count · open thread count · scope

**Defaults:** show the 20 most recent packs. Use `--all` to show all packs. Use `--limit <n>` for a custom count. Exclude `profile.md`, `.active`, and `current.json` from results.

**Optional query:** `/context-handoff list vibe-safe` filters by topic/content match.

**`--tag <tag>`:** filters the output to only packs that include the given tag in their `tags` list. Can be combined with a query string and `--project`.

If no packs exist: "No packs found."

---

## `/context-handoff open <pack> [--full]`

View a pack's human-readable layer without loading it.

Shows:
1. A brief YAML summary: topic, last_updated, update_count, open thread count, resume_point
2. The first 40 lines of the markdown body (below the YAML frontmatter)
3. If the file has more lines: `— [N more lines] — Use /context-handoff open <name> --full to see everything`

`--full`: show the complete markdown body without truncation.

Does NOT write to `.active` or restore any state.

Accept partial name match if unambiguous.

---

## `/context-handoff search [--project] <query>`

Search pack content across all packs (topic, decisions, ruled_out, open_threads, notes, artifacts). Show matching packs with structured results.

**Scope:**
- Default (no flag): searches both `~/.claude/handoffs/` and `.claude/handoffs/` (if it exists)
- `--project`: searches only `.claude/handoffs/` inside the current git repo

Searched fields: topic, decisions, ruled_out, open_threads, notes, artifacts. Exclude `profile.md` from search results. Profile content contains personal data and should not appear in topic/decision searches.

**Output format:**

```
Search: "semgrep" — 3 matches

vibe-safe-release (2026-05-16)
  decisions: "add 3 optional tool integrations (semgrep, bandit, eslint-security)..."
  ruled_out: "making semgrep a hard requirement..."

codebase-onboarding (2026-05-14)
  open_threads: "evaluate semgrep integration for CI..."
```

Pack name + date as header, matched field label + truncated excerpt per match. No file paths. No line numbers.

---

## `/context-handoff delete [--dry-run] <pack>`

Delete a named pack after confirmation. Accept partial name match if unambiguous (error if multiple packs match).

Show the pack's topic, last_updated, and update_count before confirming.

`--dry-run`: show what would be deleted (topic, last_updated, update_count) without deleting — "would delete this pack."

Accepts `--yes` / `-y` to skip the confirmation prompt.

On confirm (without `--dry-run`), delete the file and confirm deletion.

---

## `/context-handoff close <thread>`

Mark an open thread as resolved.

**Steps:**
1. Read `~/.claude/handoffs/.active` (look up entry by current working directory in the JSON map) to get the current pack path. If no active session: error "No active session. Load a pack first." Find the open thread by partial text match. Error if ambiguous (multiple matches).
2. Remove it from `open_threads`
3. Add it to `closed_threads` with a `closed_at` timestamp (current time)
4. Write the pack
5. Confirm: `✓ Thread closed: "[matched text]"`

---

## `/context-handoff add-thread <text> [--priority high|medium|low]`

Add an open thread to the active pack.

**Steps:**
1. Read `~/.claude/handoffs/.active` (look up entry by current working directory in the JSON map) to get the current pack path. If no active session: error "No active session. Load a pack first."
2. **Duplicate detection:** Before appending, check if any existing open thread has text that is >80% similar. Simple heuristic: if the new text shares 3 or more consecutive words with an existing open thread, warn:
   > "Similar thread already exists: '[existing text]'. Add anyway? (y/n)"
   If the user answers `n`, abort. If `y`, proceed.
3. Append the new thread to `open_threads` with `added_at` timestamp. Default priority: `medium`.
4. Write the pack.
5. Confirm: `✓ Thread added: "[text]" [priority]`

---

## `/context-handoff contracts`

Show currently active behavioral contracts from the loaded pack.

**Steps:**
1. Display the current `behavioral_contracts` list (numbered). Note any `[CLAUDE.md]`-prefixed contracts as sourced from project config.
2. Offer:
   > "Add, remove, or edit? (or press enter to skip)"
   - **Add:** Prompt for new contract text, append to list.
   - **Remove:** Prompt for the number of the contract to remove, delete it from the list.
   - **Edit:** Prompt for the number of the contract to edit, show current text, prompt for replacement text, update in place.
   - **(enter):** No changes.
3. If any change was made, write the pack and confirm: `✓ Contracts updated`

---

## `/context-handoff threads [--project]`

Show all open threads across all packs, sorted by priority globally (not grouped by pack).

**Scope:**
- Default (no flag): shows threads from both `~/.claude/handoffs/` and `.claude/handoffs/` (if it exists)
- `--project`: shows only threads from `.claude/handoffs/` inside the current git repo

**Output format:**

```
Open threads — 6 total (2 high, 3 medium, 1 low)
═══════════════════════════════════════════════

[high]   README needs v1.9.0 test evidence          vibe-safe-release · 3d ago
[high]   auth flow blocked on rate limiter decision  llmessenger-auth  · 1d ago
[medium] GitHub profile README shows old numbers     vibe-safe-release · 3d ago
[medium] consider CONTRIBUTING.md                    codebase-onboarding · 8d ago
[medium] rate limiting docs                          llmessenger-auth  · 1d ago
[low]    add diagram to README                       context-handoff   · 2h ago
```

Pack name is right-aligned context, not the primary grouping. High priority items always surface first regardless of which pack they're in. Age shown is time since the thread was added.

---

## `/context-handoff diff [--vs-current] [pack1] [pack2]`

Compare two packs for the same project.

- If only one pack given, diff against the previous pack for the same topic (by filename date prefix)
- If only one pack given and no prior pack exists for the same topic:
  > "No prior pack found for topic '[topic]'. Use --vs-current to diff against git state instead."
  Then offer: "Run diff --vs-current? (y/n)"
- Show: new decisions since pack1, newly closed threads, changes to work_state, newly ruled-out items
- Superseded decisions are highlighted

**`--vs-current` flag:** `/context-handoff diff --vs-current [pack]` compares the named pack (or most recent) against the current git state:
- Runs `git log --oneline` since `last_updated` to show commits since the pack
- Runs `git diff --stat HEAD` to show files changed since pack's `files_touched`
- Flags any `open_threads` that reference files with recent changes

---

## `/context-handoff merge [--dry-run] <pack1> <pack2> [output-name]`

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

Accepts `--yes` / `-y` to skip the confirmation prompt (conflicts are still surfaced — `--yes` only skips the "proceed with merge?" step).

**Output file:** `~/.claude/handoffs/YYYY-MM-DD-<topic1>-<topic2>-merged.md`. If the combined topic slug (from `<topic1>-<topic2>-merged`) exceeds 40 characters, truncate to 40 chars. If an optional `[output-name]` is given, use that as the slug instead (also truncated to 40 chars if needed).

Confirm the output path after writing.

---

## `/context-handoff rename <pack> <new-name>`

Rename a pack file and update its `topic` field in frontmatter to match.

Accept partial name match if unambiguous. Confirm the old and new filename before renaming.

---

## `/context-handoff tag <pack> <tag> [--remove]`

Add or remove a tag on a pack file.

**Steps:**
1. Find the pack by partial name match. Error if ambiguous.
2. Read the `tags` list from frontmatter.
3. Without `--remove`: if the tag already exists, confirm "Tag '[tag]' already on this pack." and exit. Otherwise append the tag and write the pack.
4. With `--remove`: if the tag is not present, confirm "Tag '[tag]' not found on this pack." and exit. Otherwise remove it and write the pack.
5. Confirm: `✓ Tag '[tag]' added/removed: [pack-name]`

**`list` tag filtering:** `/context-handoff list --tag <tag>` filters the output to only packs that include the given tag. The `--tag` flag can be combined with a query string and `--project`.

---

## `/context-handoff archive [--project] [--older-than <days>]`

Move old packs to `~/.claude/handoffs/archive/` (or `.claude/handoffs/archive/` when `--project` is set).

**Scope:**
- Default: archives from `~/.claude/handoffs/`
- `--project`: archives from `.claude/handoffs/` inside the current git repo

**Steps:**
1. Default threshold: 30 days since `last_updated`. `--older-than <days>` overrides this.
2. Show the user what would be archived BEFORE moving (dry-run preview).
3. Ask for confirmation. Accepts `--yes` / `-y` to skip.
4. Move matching files to the `archive/` subdirectory, create it if needed.
5. Confirm: "Archived N packs to ~/.claude/handoffs/archive/"

---

## `/context-handoff fork [--project] <pack> [<new-name>]`

Create a variant of an existing pack for a parallel approach, preserving full lineage.

**Scope:**
- Default: creates the fork in `~/.claude/handoffs/`
- `--project`: creates the fork in `.claude/handoffs/` inside the current git repo

**Steps:**
1. Copy the pack file to `YYYY-MM-DD-<new-name>.md` (or `YYYY-MM-DD-<original-topic>-fork.md` if no name given).
2. Update the copy:
   - New `session_id` (generate fresh `ch-YYYYMMDD-<4-char-random>`)
   - `created` = now
   - `update_count` = 0
   - `update_triggers` = []
   - Add `forked_from: "<original-pack-path>"` field
3. Clear `work_state.plan_position` in the fork (start fresh on plan position).
4. **Open threads:** After copying, before confirming, ask:
   > "Keep N open threads from original? (y/n)"
   Accepts `--yes` / `-y` to skip (threads are kept).
   - **Yes:** threads are kept as-is in the fork
   - **No:** `open_threads` is cleared in the fork (`closed_threads` is untouched)
5. Do NOT overwrite `.active` — the fork is not automatically loaded.
6. Confirm: "Fork created: [path]."
7. Immediately ask: "Switch to the fork now? (y/n)"
   - **Yes:** run `/context-handoff load <fork-name>` — the fork becomes the active session
   - **No:** confirm the fork path and leave the original as active

---

## `/context-handoff export <pack> [--format markdown|json] [--output <file>]`

Export a pack to a clean shareable format without YAML frontmatter.

**Formats:**
- `--format markdown` (default): produces a clean markdown document — topic, date, decisions, ruled out, open threads, next actions. No YAML. Suitable for pasting into Notion, Confluence, or sending to a non-Claude-Code user.
- `--format json`: produces a JSON object with all YAML fields plus the human-layer sections parsed out.

**Output:**
- Default (no `--output`): if `pbcopy` is available (macOS), pipe to `pbcopy` and confirm:
  > "Copied to clipboard: [topic] — [format] format"
- Default (no `pbcopy`, Linux/other): write to stdout with a note:
  > "Output (paste into your destination):"
  [content]
- `--output <file>`: always write to the specified file path, regardless of platform.

Accept partial name match for `<pack>` if unambiguous.

---

## `/context-handoff amend-decision <partial-what>`

Edit an existing decision in the active pack.

**Steps:**
1. Find the decision by partial match on the `what` field. Error if ambiguous (multiple matches) or not found.
2. Show the current entry (what, why, when, superseded_by if set).
3. Offer to edit: `why`, `superseded_by`, or both.
4. Apply the change: move the current `why` value into a `history` sub-field (append, don't replace), then set the new `why`. The `history` field is a list of `{why: "...", amended_at: "ISO timestamp"}` entries. This preserves the full reasoning evolution.

   Example after amendment:
   ```yaml
   - what: "use per-file diff analysis"
     why: "global diff was giving false positives on deleted lines"
     when: "2026-05-16T17:20:00Z"
     history:
       - why: "original reasoning: global diff was simpler"
         amended_at: "2026-05-16T18:00:00Z"
   ```
5. Confirm: `✓ Decision amended: "[what]"`

Does not allow editing `what` (the decision identity) — only its metadata.

---

## `/context-handoff note <text>`

Add a quick unstructured observation to the active pack. Lower overhead than a thread (no priority, no action required).

**Steps:**
1. Read `.active` (look up entry by current working directory in the JSON map) to get the current pack path. If no active session: error "No active session. Load a pack first."
2. Append to the `notes` list in the YAML frontmatter:
   ```yaml
   notes:
     - text: "the observation"
       when: "ISO timestamp"
   ```
3. Write the pack silently — no confirmation needed (lightweight operation).

---

## `/context-handoff notes`

List all notes in the active pack, newest first.

**Steps:**
1. Read `.active` (look up entry by current working directory in the JSON map) to get the current pack path. If no active session: error "No active session. Load a pack first."
2. Read the `notes` list from YAML frontmatter.
3. If empty: "No notes in this session."
4. Otherwise display:

```
Notes — 3 entries
  [2026-05-17T14:30Z] tried the alternative approach — too slow
  [2026-05-17T13:15Z] rate limiter returns 429 with Retry-After header
  [2026-05-17T12:00Z] auth middleware expects Bearer prefix
```

Newest first. No truncation — show full note text.

---

## `/context-handoff import <file|url>`

Extract context from an external file and merge it into the active pack. Useful for pulling in meeting notes, Slack exports, calendar entries, project docs, or any text without manually re-typing decisions and threads.

**Supported inputs:**
- **Files:** Any readable text file — `.md`, `.txt`, `.json`, `.ics`, plain text
- **URLs:** Any fetchable URL — Fathom/Granola transcript links, Notion pages, GitHub issues/PRs, Google Docs (public), raw text URLs. Claude fetches the content and extracts what's relevant.

If a URL is given, fetch its content first, then proceed with the same extraction logic as for files.

**Steps:**
1. Read `.active` to get the current pack path. If no active session: error "No active session. Load or create a pack first."
2. If `<file>` starts with `http://` or `https://`, fetch the URL content. Otherwise read the local file.
3. Extract from the file content:
   - **Decisions / conclusions** → append to `decisions` (what + why inferred from context, `when` = file mtime or now). Before appending any extracted decision, check if an existing decision in `decisions` has a `what` field that is >70% similar (same 3+ consecutive words). If so, skip the duplicate silently.
   - **Action items / open questions** → append to `open_threads` with `priority: medium` by default
   - **Key facts or observations** → append to `notes`
   - **Files or resources referenced** → append to `context_files` if paths are mentioned
4. Before writing, show a preview of what will be imported:
   ```
   Import preview — meeting-notes-2026-05-18.md
   ─────────────────────────────────────────────
   decisions (2):
     + chose Redis over Memcached for session storage
     + defer auth refactor to Q3
   open_threads (1):
     + confirm rate limit behaviour with infra team [medium]
   notes (1):
     + Stan is OOO until June 2

   Import? (y/n)
   ```
5. On confirm (or with `--yes` / `-y`): write the merged pack. Add an artifact entry:
   ```yaml
   artifacts:
     - label: "imported: <filename>"
       content: "imported <N> decisions, <M> threads, <K> notes from <filename>"
   ```
6. Confirm: `✓ Imported from [filename] — [N] decisions, [M] threads, [K] notes added`

Accept `--yes` / `-y` to skip the preview confirmation.
Accept `--dry-run` to show the preview without writing.

---

## `/context-handoff sync [--source <name>] [--since <duration>]`

Pull recent context from connected MCP integrations directly into the active pack. This is the real-time equivalent of `import` — instead of reading a file, it queries connected services live.

**Completely optional.** The skill works identically without any MCPs connected. `sync` simply does nothing useful if no integrations are available — it will tell you what's missing and how to connect it.

### Supported sources

| Source | What it pulls | MCP required |
|--------|--------------|-------------|
| `granola` | Recent meeting notes and action items | Granola MCP |
| `fathom` | Meeting transcripts and highlights | Fathom MCP |
| `slack` | Recent messages in relevant channels/threads | Slack MCP |
| `linear` | Recent issues, comments, status changes | Linear MCP |
| `notion` | Recent page updates and comments | Notion MCP |
| `github` | Recent PRs, issues, review comments | GitHub MCP |
| `calendar` | Upcoming and recent calendar events | Calendar MCP |

### Flags

- `--source <name>`: Pull from one specific source only. Without this flag, all connected sources are checked.
- `--since <duration>`: How far back to look. Default: `24h`. Examples: `--since 7d`, `--since 2h`, `--since 1w`.
- `--dry-run`: Show preview without writing.
- `--yes` / `-y`: Skip confirmation.

### Steps

1. Read `.active` to get the current pack path. If no active session: error "No active session. Load or create a pack first."
2. Determine which sources to check: `--source` if given, otherwise all supported sources.
3. For each source, check if its MCP tools are available in the current session:
   - **Connected:** query for recent data using the MCP tools
   - **Not connected:** skip and note it
4. Extract from each source's response (same logic as `import`):
   - Decisions / conclusions → `decisions`. Before appending any extracted decision, check if an existing decision in `decisions` has a `what` field that is >70% similar (same 3+ consecutive words). If so, skip the duplicate silently.
   - Action items / open questions → `open_threads`
   - Key facts → `notes`
5. Aggregate all results and show a preview:
   ```
   sync — 3 sources checked
   ─────────────────────────
   ✓ granola (2 meetings)
     decisions (1): + chose Postgres over MySQL for new service
     open_threads (2): + confirm deployment window with ops team [medium]
                       + follow up with design on mobile nav [low]

   ✓ slack (last 24h, 4 relevant threads)
     notes (2): + Stan is on PTO until June 2
                + rate limiter PR approved, ready to merge

   ✗ linear: not connected
     → claude mcp add linear https://mcp.linear.app/sse

   Import all? (y/n)
   ```
6. On confirm: merge into active pack. Add one artifact entry per source:
   ```yaml
   artifacts:
     - label: "sync: granola (2026-05-18)"
       content: "1 decision, 2 threads from 2 meetings"
   ```
7. Confirm: `✓ Synced — [N] decisions, [M] threads, [K] notes added from [sources]`

### Graceful degradation

If **no** MCPs are connected:
> "No integrations connected. sync works with: granola, fathom, slack, linear, notion, github, calendar.
> Connect one with: claude mcp add <name> <url>"

If **some** are connected but return no recent data:
> "✓ synced — nothing new in the last 24h"

The skill's core functionality (pack, load, update, import, profile, all other commands) is completely unaffected by whether any MCP is connected.

---

## `/context-handoff profile [edit]`

Your personal profile is a special persistent pack stored at `~/.claude/handoffs/profile.md`. Unlike regular packs, it is **automatically included in every session** — you never need to load it explicitly. It holds context about you that is stable across projects: personal facts, recurring commitments, preferences, working style, and anything else that would otherwise need to be re-established in every new conversation.

**Profile structure** (distinct from regular packs — no `session_id`, no `resume_point`, no `work_state`):

```yaml
---
pack_version: "1.3"
type: profile
last_updated: "YYYY-MM-DDTHH:MM:SSZ"

# Personal context — facts about your life that are useful to an AI assistant
personal:
  - "wife's name: [name]"
  - "kids: [names and ages]"
  - "location: [city/country]"
  - "birthday reminders: [list]"
  - "recurring commitments: [list]"

# Professional context — stable facts about your work
professional:
  - "role: [title]"
  - "company: [name]"
  - "stack: [languages/tools]"
  - "team: [names and roles]"
  - "ongoing projects: [list]"

# Preferences — how you like to work with AI
preferences:
  - "language: [e.g. reply in Polish when I write in Polish]"
  - "code style: [preferences]"
  - "communication: [terse/verbose, etc.]"

# Things AI assistants should never do
never:
  - "never suggest X"
  - "never assume Y"
---

# Profile

[Human-readable summary of the above]
```

**Without argument (`/context-handoff profile`):** Display the current profile in a readable format. If no profile exists: "No profile yet. Run `/context-handoff profile edit` to create one."

**With `edit` argument (`/context-handoff profile edit`):**
1. If profile exists, show current content section by section
2. Ask which section to update (personal / professional / preferences / never)
3. Accept the user's input and update the relevant section
4. Write `~/.claude/handoffs/profile.md`
5. Confirm: `✓ Profile updated`

If no profile exists, walk through each section in sequence to create it from scratch.

---

## `/context-handoff setup`

Interactive first-time setup wizard. Covers everything in sequence.

**Steps:**
1. **Already configured check:** Look for the commit hook in `~/.claude/settings.json` (search for "CONTEXT-HANDOFF") and check if `~/.claude/handoffs/` exists. If both are present: "Already configured. Run `/context-handoff doctor` to verify." and exit.
2. **Hook installation:** Check if the commit hook is installed. If not, ask:
   > "Install the PostToolUse hook for auto-updates on git commit? (y/n)"
   If yes, run `bash ~/.claude/skills/context-handoff/scripts/install-hook.sh` to install the hook. If the script is not found, show the manual JSON from the Hook Setup section below.
3. **Directory creation:** Create `~/.claude/handoffs/` if it doesn't exist.
4. **Scope preference:** Ask:
   > "Where should packs be saved by default? [1] global: ~/.claude/handoffs/ or [2] project: .claude/handoffs/ in each repo?"
   Record the answer and write it to `~/.claude/handoffs/.config` as a JSON file:
   ```json
   { "default_scope": "global" }
   ```
   or `"project"` if the user chose project scope. On any subsequent `pack`, `load`, `archive`, `fork`, `search`, or `threads` call without an explicit `--project` or `--global` flag, read `.config` and apply the default. If `.config` is absent, default to global.
5. **First pack offer:** Ask: "Want to pack this session now? (y/n)". If yes, run `/context-handoff pack`.
6. **Summary:** Show what was done and how to get help:
   > "Setup complete. Type `/context-handoff` to resume or save a session, or `/context-handoff help` to see all commands."

---

## `/context-handoff doctor`

Verify that context-handoff is correctly installed and the current session is healthy.

**Checks:**
1. **Hook installed:** Search `~/.claude/settings.json` for "CONTEXT-HANDOFF". Report ✓ or ✗.
2. **Global handoffs dir:** Check `~/.claude/handoffs/` exists. Report ✓ or ✗ (with mkdir hint).
3. **Project handoffs dir:** If in a git repo, check `.claude/handoffs/` exists. Report ✓ or ✗ (or "not in a git repo").
4. **Active session:** Read `~/.claude/handoffs/.active`. If present, show topic + last_updated. If absent, report "No active session".
5. **Skill version:** Report the version from the SKILL.md frontmatter (search `~/.claude/skills/context-handoff/SKILL.md` for `^version:`). If not found, report "version unknown".
6. **Recent packs:** List the 5 most recent `.md` files in `~/.claude/handoffs/` (excluding `.active`) with their dates.
7. **Update available:** Compare the installed version (from step 5) against the latest GitHub release tag by fetching `https://api.github.com/repos/googlarz/context-handoff/releases/latest`.
   - If fetch succeeds and installed version matches latest: report `✓ Up to date`
   - If fetch fails (network error, timeout): report `⚠ Version check unavailable (offline)`
   - If fetch succeeds and a newer version exists: report `↑ v[latest] available — run scripts/upgrade.sh`

**Output format:**
```
context-handoff doctor
══════════════════════
✓ Hook installed
✓ ~/.claude/handoffs/ exists (12 packs)
✓ .claude/handoffs/ exists (3 packs)
✓ Active session: vibe-safe-release (updated 47m ago)
✓ Skill version: 1.4.0
✓ Up to date  (or: ↑ v1.6.6 available — run scripts/upgrade.sh)

Recent packs:
  2026-05-17 · context-handoff-build
  2026-05-16 · vibe-safe-release
  2026-05-15 · llmessenger-auth
```

If any check fails, show a one-line fix hint below the ✗ line.

---

## `/context-handoff version`

Show the installed skill version.

Search `~/.claude/skills/context-handoff/SKILL.md` for the `^version:` field in frontmatter and print it:

```
context-handoff v1.4.0
```

If the file is not found: "Skill file not found at ~/.claude/skills/context-handoff/SKILL.md"

---

## `/context-handoff help`

Shows a compact in-session command reference. No file access needed — render this inline.

```
context-handoff commands
════════════════════════

Tip: /context-handoff with no args → smart resume or save

Session
  pack [--project]          Save this session  (alias: save)
  load [--quiet] [--project] [--state-only] [--contracts-only]
                            Resume a saved session  (alias: resume)
  update                    Force-save right now
  status                    Is anything saved? What's active?

Browsing
  list [--all] [--limit n]  List saved sessions (default: 20 most recent)
  open <name> [--full]      Preview a session without loading it
  search [--project] <q>    Search across all saved sessions
  threads [--project]       All open questions, sorted by priority

Editing
  add-thread <text> [--priority high|medium|low]
                            Add an open question or to-do  (alias: thread)
  close <thread>            Mark a question as resolved  (alias: resolve)
  note <text>               Quick observation — no action needed  (alias: observe)
  notes                     List all observations in this session
  contracts                 How you like to work  (alias: rules)
  amend-decision <text>     Correct the reasoning behind a decision
  import <file>             Pull context from a meeting note, doc, or export
  sync [--source name]      Pull from connected apps (Granola, Slack, Linear…)

Pack management
  rename <pack> <new>       Rename a saved session
  delete [--dry-run] <pack> Delete a saved session
  archive [--older-than n]  Move old sessions to archive/
  fork [--project] <pack>   Create a parallel variant  
  merge [--dry-run] <a> <b> Combine two sessions
  diff [--vs-current] ...   What changed between two sessions
  tag <pack> <tag>          Add or remove a label
  verify                    Does the saved file match what I remember?

Sharing
  export <pack> [--format markdown|json] [--output file]
                            Share with teammates or other tools

Profile & Setup
  profile [edit]            Persistent context about you — loaded every session
  setup                     First-time setup wizard
  doctor                    Is everything installed correctly?
  version                   Which version is installed?

Flags available on all commands:
  --yes / -y                Skip confirmation prompts
  --project                 Use .claude/handoffs/ (project scope)
```

---

## Aliases

Claude recognises the following aliases as equivalent to their canonical command:

| Canonical | Alias(es) |
|-----------|-----------|
| `pack` | `save`, `snapshot` |
| `profile` | `me`, `about-me` |
| `load` | `resume`, `continue` |
| `contracts` | `rules`, `prefs`, `how-i-work` |
| `add-thread` | `thread`, `open-thread`, `todo` |
| `close` | `close-thread`, `resolve`, `done` |
| `note` | `observe` |
| `notes` | `list-notes` |
| `delete` | `del`, `rm` |
| `export` | `share` |

Example: `/context-handoff resume` is identical to `/context-handoff load`.

---

## Auto-Update System

Once a session has an active pack (created via `pack` or loaded via `load`), maintain it automatically. Do not ask permission — just do it.

### Auto-pack on session start

After the first assistant turn, check whether a fresh active session exists for the current working directory:
1. Read `~/.claude/handoffs/.active` as JSON. Look up the current cwd entry.
2. If entry exists and `last_updated` is within the last 4 hours: do not auto-pack — a session is already active. This prevents re-firing after context compaction, which resets Claude's in-context memory but does not clear `.active`.
3. If no entry, or entry is stale (> 4 hours): silently create a minimal pack and write the `.active` entry.

**Minimal auto-pack contains:**
- `topic`: inferred from the user's first message (3–5 word slug)
- `session_id`: generated fresh
- `created` / `last_updated`: now
- `resume_point`: empty (filled on first real update)
- `work_state.goal`: inferred from first message
- All other fields: empty defaults

Write the pack to `~/.claude/handoffs/YYYY-MM-DD-<topic-slug>.md` and set `.active`.

Confirm once, quietly:
> `✓ Session started — [topic] (auto-pack created)`

This means the user never needs to remember to run `/context-handoff pack`. The pack exists from turn 1.

**Profile on auto-pack:** When an auto-pack is created on session start, also silently load the profile (same as step 14a in `load`).

### Session ID Pinning

The active pack is tracked via `~/.claude/handoffs/.active` — a **JSON file** mapping working directory to active session:

```json
{
  "/Users/dawid/projects/vibe-safe": {
    "session_id": "ch-20260518-x7k2",
    "pack": "/Users/dawid/.claude/handoffs/2026-05-18-vibe-safe.md",
    "last_updated": "2026-05-18T14:30:00Z"
  },
  "/Users/dawid/projects/llmessenger": {
    "session_id": "ch-20260518-y9m3",
    "pack": "/Users/dawid/.claude/handoffs/2026-05-18-llmessenger.md",
    "last_updated": "2026-05-18T09:00:00Z"
  }
}
```

**On every read:** look up the entry for the current working directory (`cwd`). Ignore all other entries.

**On every write:** update only the entry for the current `cwd`. Other projects' entries are never touched.

**Backward compatibility:** if `.active` exists but is not valid JSON (old single-line format), read it as before and migrate it to the new format on next write.

**Result:** multiple Claude sessions in different directories can run simultaneously without colliding. Each project has its own independent active session pointer.

### Trigger 1: Git commit detected

The PostToolUse hook fires on two event types:

**Commit trigger:** When hook output contains `CONTEXT-HANDOFF: commit detected` — full pack update (files_touched, plan_position, append `commit` to update_triggers).

**Write trigger:** When hook output contains `CONTEXT-HANDOFF: file-write detected` — lightweight update: append new files to `files_touched`, update `last_updated`. Do NOT increment `update_count` or append to `update_triggers`. Silent, no confirmation.

**Pre-compact trigger:** When hook output contains `CONTEXT-HANDOFF: pre-compact — save pack now` — full pack update immediately, with trigger `pre-compact` in `update_log`. This fires via the `PreCompact` hook before every context compaction, ensuring the pack is current before the context window shrinks.

Both triggers read `.active` to find the pack path — no reliance on conversation memory.

When the commit trigger fires, immediately:
1. Update `work_state.files_touched` with any new files
2. Update `work_state.plan_position` if a step completed
3. Append `commit` to `update_triggers`
4. Write the pack (with write coordination — see below)
5. Confirm silently: `↻ [topic] saved (commit)`

### Trigger 2: Decision detected

When you have just made a significant decision, ruled something out, or completed a plan step, append the new entry to the relevant section and write the pack. This happens inline — no extra turn, no user prompt.

A "significant decision" is: choosing an approach over alternatives, ruling out an option with reasoning, completing a discrete unit of work, or establishing a new behavioral contract with the user.

Additionally, if a new communication preference or anti-pattern has been observed (pushback recorded, explicit preference stated), update the relevant `communication_style` field at the same time.

Confirm silently: `↻ [topic] saved (decision)`

### Trigger 3: Turn cadence

Count your own responses (assistant turns) since `last_updated`. After every 5 assistant turns, if no other trigger has fired, write a full pack update.

**Important:** Turn cadence uses both turn counting AND time elapsed — whichever fires first. On every auto-update trigger (commit or decision), also check if `last_updated` in the pack is more than 30 minutes old. If so, treat it as a cadence update too (reset the implicit turn counter). This mitigates unreliable turn counting after context compaction.

If a new communication preference or anti-pattern has been observed since the last update, update the relevant `communication_style` field during the cadence update as well.

Confirm silently: `↻ [topic] saved (turn [N])`

**Catchup write:** If the last `update_log` entry (or `last_updated` if `update_log` is empty) is more than 15 minutes old and any trigger fires (commit, file-write, decision, or manual), perform a catchup write first — a full state update with trigger `catchup` — before the normal incremental update. This ensures that pure-conversation sessions (no tool calls for several turns) don't accumulate silent drift.

### Failure detection

If no auto-update has fired in the current session and more than 15 assistant turns have passed, emit once:
> `⚠ No auto-updates recorded this session. Check hook installation with /context-handoff doctor or run /context-handoff update manually.`

This warning fires at most once per session. Do not repeat.

### Update behavior

Updates are **incremental** where possible — append to decisions/ruled_out/open_threads rather than rewriting. Only rewrite `work_state` and `resume_point` in full.

**`update_log` appending:** On every update (auto or manual), append a new entry to `update_log` describing what changed. Never rewrite existing `update_log` entries. This creates a chronological replay log for the full session:
- `trigger`: one of `initial`, `decision`, `commit`, `file-write`, `turn-N`, `manual`, `pre-compact`
- `added`: what was newly added in this update (only include non-empty fields)
- `changed`: what fields changed value (only include fields that actually changed)

Keep `update_log` entries compact — decisions should be short descriptions, not full YAML objects. The full objects live in the main `decisions` list; the log just records that they were added.

**Write coordination and concurrency protection:**

Before writing a pack, read the current file and check two things:

1. **Timestamp check:** If `last_updated` in the file is newer than what Claude last read, merge (append new decisions, take latest work_state) rather than overwrite.

2. **Session ID check:** If the file's `session_id` differs from the current session's `session_id`, this pack is being written by another Claude session. Do NOT overwrite. Instead, append new decisions and threads only — never replace `work_state` or `resume_point`. Log silently: `⚠ Concurrent session detected — appended decisions only, work_state not overwritten.`

This prevents two parallel Claude sessions (e.g., two terminal tabs) from clobbering each other's work state.

**`current.json` mirror:** On every pack write (pack, update, auto-update), also write `~/.claude/handoffs/current.json` containing all YAML frontmatter fields as a JSON object (nested structures like `work_state`, `decisions`, and `open_threads` are preserved as-is). This makes the active session readable by any tool, agent, or LLM that can read files — no YAML parsing required. Other agents can point to this file to get always-current context without needing the context-handoff skill installed.

Example structure:
```json
{
  "topic": "vibe-safe-release",
  "session_id": "ch-20260517-x7k2",
  "last_updated": "2026-05-17T14:30:00Z",
  "resume_point": "README needs updating",
  "work_state": { "goal": "...", "files_touched": [], "plan_position": "..." },
  "decisions": [...],
  "open_threads": [...],
  "behavioral_contracts": [...]
}
```

**update_triggers cap:** When appending to `update_triggers`, if the list already has 20 entries, replace it with a summary format before appending the new trigger:
```yaml
update_triggers: ["[20 prior — truncated]", "decision", "commit"]
```
Keep only the last 2 actual entries plus the summary sentinel. The summary sentinel `[20 prior — truncated]` is the exact string to use. It is distinguishable from valid trigger names by the bracket prefix and is never treated as a trigger value.

### Pack size budget

Keep packs under ~50KB. On every update, check the estimated pack size:

- If `closed_threads` has more than 20 entries, move the oldest 10 to a sidecar file at `<pack-path>-archive.md` (create if not exists, append otherwise).
- If `decisions` has more than 60 entries, move superseded decisions (those with `superseded_by` set) to the sidecar.
- After moving, add a note to the pack:
  ```yaml
  notes:
    - text: "N entries moved to archive (auto-pruned for size)"
      when: "ISO timestamp"
  ```

**`update_log` cap:** When `update_log` exceeds 100 entries, replace the oldest 80 entries with a single summary sentinel:
```yaml
- at: "<timestamp of first pruned entry>"
  trigger: "[80 prior entries — pruned for size]"
  added: {}
  changed: {}
```
Keep the most recent 20 entries intact. The sentinel uses the same bracket format as the `update_triggers` cap.

The sidecar is human-readable only — it is never loaded by `load` or `update`. It is for history, not for restoration.

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
pack_version: "1.3"

created: "YYYY-MM-DDTHH:MM:SSZ"
last_updated: "YYYY-MM-DDTHH:MM:SSZ"
update_count: 0
update_triggers: []

# SHA-256 (hex, lowercase) of pack content normalized as follows:
# 1. Encode file as UTF-8
# 2. Normalize line endings to LF (\n)
# 3. Replace the content_hash value with empty string: content_hash: ""
# 4. Hash the resulting bytes
# SHA-256 of pack content normalized with content_hash set to empty string. Same normalization used for verification.
content_hash: ""

# Chronological log of all updates — append only, never rewrite
# Enables session replay: read update_log entries in order to reconstruct session history
update_log: []
# Each entry shape:
# - at: "ISO timestamp"
#   trigger: "initial|decision|commit|file-write|turn-N|manual|pre-compact|catchup"
#   added:
#     decisions: ["short description of decision added"]
#     open_threads: ["thread text"]
#     files_touched: ["path"]
#     notes: ["note text"]
#   changed:
#     resume_point: "new value"
#     plan_position: "new value"

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
# Updated during auto-updates when new preferences or anti-patterns are observed
communication_style:
  tone: "direct and terse"
  verbosity: low   # low | medium | high
  preferences:
    - "markdown tables for comparisons"
    - "concrete over abstract"
  anti_patterns:
    - "no end-of-turn summaries"
    - "no pleasantries"
# IMPORTANT: communication_style must always be a YAML mapping (object), never a plain string.
# If loading a pack where communication_style is a string, convert it:
# treat the string as the value of the `tone` field and set verbosity: medium,
# preferences: [], anti_patterns: [].

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
    why: "current reasoning"
    when: "ISO timestamp"
    superseded_by: "optional"
    history:           # populated by amend-decision; do not edit manually
      - why: "prior reasoning"
        amended_at: "ISO timestamp"

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

# Quick unstructured observations (added via /context-handoff note)
notes:
  - text: "the observation"
    when: "ISO timestamp"

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
# Auto-populated on pack creation when a valid .active session exists
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
    ]
  }
}
```

```json
{
  "hooks": {
    "PreCompact": [
      {
        "matcher": "",
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

The `PreCompact` hook fires before context is compacted. Claude Code supports this hook type natively — it fires before every compaction event, not before a tool call. When Claude sees `CONTEXT-HANDOFF: pre-compact`, immediately do a full pack update with trigger `pre-compact` before proceeding. This prevents context loss at compaction boundaries.

The `install-hook.sh` script installs all hooks automatically (Bash commit, Write/Edit file-write, and PreCompact). Run:

```bash
bash ~/.claude/skills/context-handoff/scripts/install-hook.sh
```

---

## On Load: Behavioral Contract Restoration

When loading a pack (unless `--state-only` or `--quiet` is set), re-establish contracts explicitly. State them so the user can correct anything stale:

> "Restoring behavioral contracts from last session:
> - [contract 1]
> - [contract 2] *(from CLAUDE.md — may differ in a different project)*
> Let me know if anything has changed."

Then ask: "Any of these no longer apply?" (skipped if `--yes` / `-y` is set). If the user names one, remove it from `behavioral_contracts` and write the pack. Otherwise proceed — don't wait for confirmation.

---

## CLAUDE.md Seeding

On `/context-handoff pack`, behavioral contracts sourced from `CLAUDE.md` are prefixed with `[CLAUDE.md]` in `behavioral_contracts`. This makes them distinguishable from contracts derived from the session.

On `load`, `[CLAUDE.md]`-prefixed contracts are restored but flagged as "from project config — may differ if you're in a different project." The user can remove them via `/context-handoff contracts` or the load confirmation step.

On `load`, if the current `CLAUDE.md` differs from what was seeded (or is absent), the diff is surfaced and the user is asked whether to update the pack's contracts accordingly.

---

## --project Scope

`pack`, `load`, `archive`, `fork`, `search`, and `threads` all accept `--project`:
- Saves/loads/operates from `.claude/handoffs/` inside the current git repo instead of `~/.claude/handoffs/`
- `list` always shows both locations, labelled `[global]` and `[project]`
- If `--project` is used outside a git repo: error "Not in a git repo — cannot use --project scope"

---

## Linked Sessions (Chaining)

Packs can reference prior packs for full lineage via `prior_session`. This field is auto-populated on pack creation when a valid `.active` session exists. On load, Claude may offer to also load the prior session for deeper context, but does not do so automatically. Only offer if the `prior_session` path exists on the current machine.

Forked packs reference their origin via `forked_from` (set automatically by `/context-handoff fork`).

**Cross-machine handoff:** When a pack is used as a team handoff (loaded by someone other than the original author), `prior_session` and `forked_from` paths may not exist on the teammate's machine. On load, if these paths do not resolve: skip the offer to load the prior session and emit: `⚠ prior_session path not found on this machine — lineage unavailable.` Do not error.

---

## Proactive session packing

When no pack exists for the current session (no `.active` file), proactively offer to pack at these natural endpoints:

- **Session length:** The conversation has exceeded 10 assistant turns
- **Natural close:** User says "done", "wrapping up", "that's all", "bye", "thanks", "ending session", "good enough for now", or similar closing phrases
- **Milestone:** A feature ships, a bug is fixed, a significant decision is finalized, a task is fully completed

**Offer exactly once per session:**
> "Want me to save this session so you can pick up exactly where you left off next time? (/context-handoff save)"

If the user says no, do not offer again this session. If the user says yes, run `/context-handoff pack`.

Do NOT offer if a pack is already active (`.active` exists and is fresh).

---

## Edge Cases

**Zero packs on load:** If the handoffs directory is empty or doesn't exist: "No packs found. Use `/context-handoff pack` to create one."

**Corrupted / malformed pack:** If YAML frontmatter fails to parse, fall back to reading the markdown body only and warn: `⚠ Pack YAML could not be parsed — loading human-readable layer only. Behavioral contracts and work state will not be restored.`

**Ambiguous partial match:** For commands that accept partial pack names (delete, close, rename, open, fork, export, amend-decision), error if multiple packs match and list the candidates.

**Superseded decisions on load:** Surface decisions with a `superseded_by` field as struck-through context so the receiver understands the evolution. Don't hide them — the history matters.

**Stale `.active` on startup:** When `pack` or `load` is invoked without a specific pack name and `.active` exists with a `last_updated` more than 4 hours old, surface the previous session and ask the user how to proceed (load / discard / ignore) before continuing.

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

---

## Upgrading

Pack format v1.3 adds `update_log` field. Packs created in v1.2 and earlier load without changes — `update_log` is treated as empty if absent. The `update_log` field is populated going forward from the first v1.7.0 write.
