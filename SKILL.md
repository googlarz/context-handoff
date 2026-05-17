---
name: context-handoff
version: "1.5.0"
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
| `/context-handoff status` | Quick health check for the current session |
| `/context-handoff list [query] [--all] [--limit <n>] [--tag <tag>]` | List packs, optionally filtered; defaults to 20 most recent |
| `/context-handoff open <pack> [--full]` | View a pack's summary and first 40 lines without loading it |
| `/context-handoff search [--project] <query>` | Search pack content across all packs (or project-only with --project) |
| `/context-handoff threads [--project]` | All open threads across packs, sorted by priority |
| `/context-handoff add-thread <text> [--priority high\|medium\|low]` | Add an open thread to the active pack |
| `/context-handoff close <thread>` | Mark an open thread as resolved |
| `/context-handoff notes` | List all notes in the active pack |
| `/context-handoff note <text>` | Add a quick observation to the active pack |
| `/context-handoff contracts` | View and edit active behavioral contracts |
| `/context-handoff amend-decision <partial-what>` | Edit an existing decision's reasoning in the active pack |
| `/context-handoff diff [--vs-current] [pack1] [pack2]` | Compare two packs, or a pack against current git state |
| `/context-handoff merge [--dry-run] <pack1> <pack2> [output-name]` | Merge two packs into a combined pack |
| `/context-handoff rename <pack> <new-name>` | Rename a pack and update its topic field |
| `/context-handoff tag <pack> <tag> [--remove]` | Add or remove a tag on a pack |
| `/context-handoff archive [--project] [--older-than <days>]` | Move old packs to archive/ subdirectory |
| `/context-handoff fork [--project] <pack> [<new-name>]` | Create a variant of an existing pack for a parallel approach |
| `/context-handoff export <pack> [--format markdown\|json] [--output <file>]` | Export a pack to a clean shareable format |
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

> **context-handoff** — saves your session (decisions, work state, what was ruled out, how you like to work) and restores it in any new conversation. Run `/context-handoff help` to see all commands.

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
7. **CLAUDE.md seeding:** Before synthesizing behavioral contracts from the session:
   a. Check if `CLAUDE.md` exists in the current directory or `~/.claude/CLAUDE.md`
   b. If found, read it and extract any behavioral instructions (style, process, constraints)
   c. Seed these into `behavioral_contracts` prefixed with `[CLAUDE.md]` so they're distinguishable from session-derived ones
8. Populate both layers (see Pack Format below)
9. Write the session marker: `<dir>/.active` → `session_id|/full/path/to/pack.md|last_updated_timestamp`
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
14. Write the session marker: `<dir>/.active` → `session_id|/full/path/to/pack.md|last_updated_timestamp`
15. Proceed — do not ask "ready to continue?", just continue

**`--quiet` mode** skips steps 8–13 entirely. After step 7, emit the single summary line and jump to step 14.

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

## `/context-handoff list [query] [--all] [--limit <n>] [--tag <tag>]`

List packs in `~/.claude/handoffs/` and the project-local `.claude/handoffs/` (if it exists), sorted by most recent. Label each entry `[global]` or `[project]`.

**Output columns:** filename · topic · last_updated · update_count · open thread count · scope

**Defaults:** show the 20 most recent packs. Use `--all` to show all packs. Use `--limit <n>` for a custom count.

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

Searched fields: topic, decisions, ruled_out, open_threads, notes, artifacts.

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
4. Apply the change and write the pack.
5. Confirm: `✓ Decision amended: "[what]"`

Does not allow editing `what` (the decision identity) — only its metadata.

---

## `/context-handoff note <text>`

Add a quick unstructured observation to the active pack. Lower overhead than a thread (no priority, no action required).

**Steps:**
1. Read `.active` to get the current pack path. If no active session: error "No active session. Load a pack first."
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
1. Read `.active` to get the current pack path. If no active session: error "No active session. Load a pack first."
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
   Record the answer as a note — Claude cannot persist settings, so this is informational guidance the user can apply when running `pack` and `load`.
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

**Output format:**
```
context-handoff doctor
══════════════════════
✓ Hook installed
✓ ~/.claude/handoffs/ exists (12 packs)
✓ .claude/handoffs/ exists (3 packs)
✓ Active session: vibe-safe-release (updated 47m ago)
✓ Skill version: 1.4.0

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
  pack [--project]          Create a context pack from this session
  load [--quiet] [--project] [--state-only] [--contracts-only]
                            Restore a pack into a new session
  update                    Force-write a pack update
  status                    Quick health check for active session

Browsing
  list [--all] [--limit n]  List packs (default: 20 most recent)
  open <name> [--full]      View a pack without loading it
  search [--project] <q>    Search pack content
  threads [--project]       All open threads, sorted by priority
  notes                     List notes in the active session

Editing
  add-thread <text> [--priority high|medium|low]
  close <thread>            Resolve an open thread
  note <text>               Add a quick observation
  contracts                 View/edit behavioral contracts
  amend-decision <text>     Edit a decision's reasoning

Pack management
  rename <pack> <new>       Rename a pack
  tag <pack> <tag> [--remove]  Add or remove a tag
  delete [--dry-run] <pack> Delete a pack
  archive [--older-than n]  Move old packs to archive/
  fork [--project] <pack>   Create a parallel variant
  merge [--dry-run] <a> <b> Combine two packs
  diff [--vs-current] ...   Compare packs

Sharing
  export <pack> [--format markdown|json] [--output file]

Setup
  setup                     Interactive first-time setup wizard
  doctor                    Verify hook, dirs, active session
  version                   Show installed skill version

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
| `load` | `resume` |
| `contracts` | `rules`, `prefs` |
| `add-thread` | `open-thread`, `thread` |
| `close` | `close-thread`, `resolve` |
| `note` | `observe` |
| `notes` | `list-notes` |

Example: `/context-handoff resume` is identical to `/context-handoff load`.

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

### Failure detection

If no auto-update has fired in the current session and more than 15 assistant turns have passed, emit once:
> `⚠ No auto-updates recorded this session. Check hook installation with /context-handoff doctor or run /context-handoff update manually.`

This warning fires at most once per session. Do not repeat.

### Update behavior

Updates are **incremental** where possible — append to decisions/ruled_out/open_threads rather than rewriting. Only rewrite `work_state` and `resume_point` in full.

**Write coordination:** Before writing a pack, check if `last_updated` in the file is newer than what Claude last read. If so, read the current file first and merge (append new decisions, take latest work_state) rather than overwriting.

**update_triggers cap:** When appending to `update_triggers`, if the list already has 20 entries, replace it with a summary format before appending the new trigger:
```yaml
update_triggers: ["...20 prior triggers", "decision", "commit"]
```
Keep only the last 2 actual entries plus the summary prefix.

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

Packs can reference prior packs for full lineage via `prior_session`. This field is auto-populated on pack creation when a valid `.active` session exists. On load, Claude may offer to also load the prior session for deeper context, but does not do so automatically.

Forked packs reference their origin via `forked_from` (set automatically by `/context-handoff fork`).

---

## Proactive session packing

When no pack exists for the current session (no `.active` file), proactively offer to pack at these natural endpoints:

- **Session length:** The conversation has exceeded 20 assistant turns
- **Natural close:** User says "done", "wrapping up", "that's all", "bye", "thanks", "ending session", "good enough for now", or similar closing phrases
- **Milestone:** A feature ships, a bug is fixed, a significant decision is finalized, a task is fully completed

**Offer exactly once per session:**
> "Want me to save this session? I can pack the decisions, work state, and context so you can resume exactly here later. (y/n)"

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
