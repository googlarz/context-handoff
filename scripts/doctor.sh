#!/bin/bash
# context-handoff: diagnose installation and session state

SETTINGS_FILE="$HOME/.claude/settings.json"
HANDOFFS_DIR="$HOME/.claude/handoffs"
ACTIVE_MARKER="$HANDOFFS_DIR/.active"
SKILL_FILE="$HOME/.claude/skills/context-handoff/SKILL.md"

echo "context-handoff doctor"
echo "======================"

# 1. Hook installed?
if [ -f "$SETTINGS_FILE" ] && grep -q "CONTEXT-HANDOFF" "$SETTINGS_FILE" 2>/dev/null; then
  echo "✓ Commit hook installed"
else
  echo "✗ Commit hook not found in $SETTINGS_FILE"
  echo "  Fix: bash ~/.claude/skills/context-handoff/scripts/install-hook.sh"
fi

# 2. Handoffs directory exists and is writable?
if [ -d "$HANDOFFS_DIR" ] && [ -w "$HANDOFFS_DIR" ]; then
  PACK_COUNT=$(find "$HANDOFFS_DIR" -maxdepth 1 -name "*.md" ! -name ".active" 2>/dev/null | wc -l | tr -d ' ')
  echo "✓ Handoffs directory: $HANDOFFS_DIR ($PACK_COUNT packs)"
else
  echo "✗ Handoffs directory missing or not writable: $HANDOFFS_DIR"
  echo "  Fix: mkdir -p $HANDOFFS_DIR"
  PACK_COUNT=0
fi

# 3. SKILL.md installed?
if [ -f "$SKILL_FILE" ]; then
  echo "✓ SKILL.md installed at ~/.claude/skills/context-handoff/"
else
  echo "✗ SKILL.md not found at $SKILL_FILE"
  echo "  Fix: git clone https://github.com/googlarz/context-handoff ~/.claude/skills/context-handoff"
fi

# 4. Active session?
if [ -f "$ACTIVE_MARKER" ]; then
  SESSION_ID=$(grep "^session_id:" "$ACTIVE_MARKER" 2>/dev/null | awk '{print $2}')
  PACK_PATH=$(grep "^pack:" "$ACTIVE_MARKER" 2>/dev/null | awk '{print $2}')
  LAST_UPDATED=$(grep "^last_updated:" "$ACTIVE_MARKER" 2>/dev/null | awk '{print $2}')
  echo "✓ Active session: ${SESSION_ID:-unknown}"
  [ -n "$PACK_PATH" ]    && echo "    pack: $PACK_PATH"
  [ -n "$LAST_UPDATED" ] && echo "    last updated: $LAST_UPDATED"
else
  echo "✗ No active session (.active not found)"
fi

# 5. Recent packs (last 5, parsed with grep/awk — no jq dependency)
if [ "$PACK_COUNT" -gt 0 ] 2>/dev/null; then
  echo ""
  echo "Recent packs:"
  # Sort by modification time, newest first, skip .active
  find "$HANDOFFS_DIR" -maxdepth 1 -name "*.md" ! -name ".active" -exec ls -t {} + 2>/dev/null | head -5 | while read -r pack; do
    BASENAME=$(basename "$pack" .md)

    # last_updated from YAML frontmatter (date portion only)
    LAST=$(grep "^last_updated:" "$pack" 2>/dev/null | awk '{print $2}' | cut -c1-10)
    [ -z "$LAST" ] && LAST=$(date -r "$pack" "+%Y-%m-%d" 2>/dev/null || echo "unknown")

    # Count updates: lines matching "^## Update" or "update_count:" field
    UPDATE_COUNT=$(grep "^update_count:" "$pack" 2>/dev/null | awk '{print $2}')
    if [ -z "$UPDATE_COUNT" ]; then
      UPDATE_COUNT=$(grep -c "^## Update" "$pack" 2>/dev/null || echo "0")
    fi

    # Count open threads
    OPEN_THREADS=$(awk '/^open_threads:/,/^[a-z]/' "$pack" 2>/dev/null | grep -c "^ *- " || echo "0")

    THREAD_WORD="threads"
    [ "$OPEN_THREADS" -eq 1 ] 2>/dev/null && THREAD_WORD="thread"

    printf "  %s · %-30s · %s updates · %s open %s\n" \
      "$LAST" "$BASENAME" "$UPDATE_COUNT" "$OPEN_THREADS" "$THREAD_WORD"
  done
fi
