#!/bin/sh
# context-handoff upgrade script
set -e

SKILL_DIR="$HOME/.claude/skills/context-handoff"

if [ ! -d "$SKILL_DIR" ]; then
  echo "context-handoff not found at $SKILL_DIR"
  echo "Install first: git clone https://github.com/googlarz/context-handoff $SKILL_DIR"
  exit 1
fi

cd "$SKILL_DIR"
BEFORE=$(git rev-parse --short HEAD)
git pull --ff-only
AFTER=$(git rev-parse --short HEAD)

if [ "$BEFORE" = "$AFTER" ]; then
  echo "Already up to date ($AFTER)"
else
  echo "Updated $BEFORE → $AFTER"
  git log --oneline "$BEFORE..$AFTER"
fi
