#!/bin/sh
# context-handoff: install PostToolUse hook for automatic pack updates on git commit

set -e

SETTINGS_FILE="$HOME/.claude/settings.json"
HOOK_COMMAND='echo "$CLAUDE_TOOL_INPUT" | grep -qE '"'"'git commit|git push'"'"' && echo '"'"'CONTEXT-HANDOFF: commit detected — update pack'"'"' || true'

echo "context-handoff hook installer"
echo "==============================="

# Create settings file if it doesn't exist
if [ ! -f "$SETTINGS_FILE" ]; then
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  echo '{}' > "$SETTINGS_FILE"
  echo "Created $SETTINGS_FILE"
fi

# Check if hook already installed
if grep -q "CONTEXT-HANDOFF" "$SETTINGS_FILE" 2>/dev/null; then
  echo "✓ Hook already installed in $SETTINGS_FILE"
  exit 0
fi

# Check if jq is available for safe JSON merging
if command -v jq &>/dev/null; then
  HOOK_JSON=$(cat <<'EOF'
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
EOF
)
  # Deep merge: existing settings + new hook
  TMPFILE=$(mktemp)
  echo "$HOOK_JSON" > "$TMPFILE"
  MERGED=$(jq -s '
    .[0] as $existing |
    .[1] as $new |
    $existing * {
      "hooks": {
        "PostToolUse": (
          ($existing.hooks.PostToolUse // []) +
          ($new.hooks.PostToolUse // [])
        )
      }
    }
  ' "$SETTINGS_FILE" "$TMPFILE")
  rm -f "$TMPFILE"

  echo "$MERGED" > "$SETTINGS_FILE"
  echo "✓ Hook installed via jq merge"
else
  # Fallback: print manual instructions
  echo ""
  echo "jq not found — add this manually to $SETTINGS_FILE:"
  echo ""
  cat <<'SNIPPET'
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
SNIPPET
  exit 1
fi

echo ""
echo "Done. Restart Claude Code for the hook to take effect."
echo "Packs will be saved to: ~/.claude/handoffs/"
echo ""
echo "To install for a specific project only (instead of globally), run:"
echo "  SETTINGS_FILE=.claude/settings.json sh scripts/install-hook.sh"
