#!/bin/sh
# context-handoff: install hooks for automatic context handoff triggers

set -e

SETTINGS_FILE="$HOME/.claude/settings.json"

echo "context-handoff hook installer"
echo "==============================="

# Create settings file if it doesn't exist
if [ ! -f "$SETTINGS_FILE" ]; then
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  echo '{}' > "$SETTINGS_FILE"
  echo "Created $SETTINGS_FILE"
fi

# Check if hooks already installed
if grep -q "context-handoff-trigger" "$SETTINGS_FILE" 2>/dev/null; then
  echo "✓ Hooks already installed in $SETTINGS_FILE"
  exit 0
fi

# Check if jq is available for safe JSON merging
if command -v jq >/dev/null 2>&1; then
  HOOK_JSON=$(cat <<'EOF'
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'git-commit' | grep -q \"$(git log --format='%H' -1 2>/dev/null)\" || context-handoff-trigger commit"
          }
        ]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "context-handoff-trigger file-write"
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "context-handoff-trigger pre-compact"
          }
        ]
      }
    ]
  }
}
EOF
)
  # Deep merge: existing settings + new hooks
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
        ),
        "PreCompact": (
          ($existing.hooks.PreCompact // []) +
          ($new.hooks.PreCompact // [])
        )
      }
    }
  ' "$SETTINGS_FILE" "$TMPFILE")
  rm -f "$TMPFILE"

  echo "$MERGED" > "$SETTINGS_FILE"
  echo "✓ Hooks installed via jq merge"
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
            "command": "echo 'git-commit' | grep -q \"$(git log --format='%H' -1 2>/dev/null)\" || context-handoff-trigger commit"
          }
        ]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "context-handoff-trigger file-write"
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "context-handoff-trigger pre-compact"
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
