#!/bin/bash
# context-handoff: remove PostToolUse hook from ~/.claude/settings.json

set -e

SETTINGS_FILE="$HOME/.claude/settings.json"
ACTIVE_MARKER="$HOME/.claude/handoffs/.active"

echo "context-handoff uninstaller"
echo "==========================="

# Remove .active marker if present
if [ -f "$ACTIVE_MARKER" ]; then
  rm "$ACTIVE_MARKER"
  echo "✓ Removed active session marker ($ACTIVE_MARKER)"
else
  echo "  No active session marker found"
fi

# Remove hook from settings.json
if [ ! -f "$SETTINGS_FILE" ]; then
  echo "  $SETTINGS_FILE not found — nothing to remove"
  echo ""
  echo "Done. Pack files in ~/.claude/handoffs/ were left untouched."
  exit 0
fi

if ! grep -q "CONTEXT-HANDOFF" "$SETTINGS_FILE" 2>/dev/null; then
  echo "  Hook not found in $SETTINGS_FILE — nothing to remove"
  echo ""
  echo "Done. Pack files in ~/.claude/handoffs/ were left untouched."
  exit 0
fi

if command -v jq &>/dev/null; then
  # Remove the hook entry whose command contains CONTEXT-HANDOFF
  CLEANED=$(jq '
    if .hooks.PostToolUse then
      .hooks.PostToolUse |= map(
        .hooks |= map(select(.command | test("CONTEXT-HANDOFF") | not))
        | select(.hooks | length > 0)
      )
      | if (.hooks.PostToolUse | length) == 0 then del(.hooks.PostToolUse) else . end
      | if (.hooks | length) == 0 then del(.hooks) else . end
    else .
    end
  ' "$SETTINGS_FILE")

  echo "$CLEANED" > "$SETTINGS_FILE"
  echo "✓ Hook removed from $SETTINGS_FILE"
else
  echo ""
  echo "✗ jq not found — cannot automatically edit $SETTINGS_FILE"
  echo ""
  echo "Remove the CONTEXT-HANDOFF hook manually from $SETTINGS_FILE."
  echo "Look for a PostToolUse hook entry whose command contains 'CONTEXT-HANDOFF'."
  exit 1
fi

echo ""
echo "Pack files in ~/.claude/handoffs/ were left untouched."
echo "Restart Claude Code for the change to take effect."
