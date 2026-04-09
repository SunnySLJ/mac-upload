#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
ALT_CODEX_HOME="/Users/mima0000/Library/Caches/JetBrains/IntelliJIdea2025.3/aia/codex"
SKILL_DIR="$CODEX_HOME/skills/baoyu-post-to-wechat"

if [ ! -d "$SKILL_DIR" ] && [ -d "$ALT_CODEX_HOME/skills/baoyu-post-to-wechat" ]; then
  SKILL_DIR="$ALT_CODEX_HOME/skills/baoyu-post-to-wechat"
fi

if [ ! -d "$SKILL_DIR" ]; then
  echo "Error: baoyu-post-to-wechat skill not found." >&2
  exit 1
fi

if command -v bun >/dev/null 2>&1; then
  BUN_CMD=("$(command -v bun)")
elif command -v npx >/dev/null 2>&1; then
  BUN_CMD=("npx" "-y" "bun")
else
  echo "Error: bun or npx is required." >&2
  exit 1
fi

if [ $# -lt 1 ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  cat >&2 <<'EOF'
Usage:
  ./publish-wechat.sh <article.md|article.html> [extra args]

Examples:
  ./publish-wechat.sh article.md
  ./publish-wechat.sh article.md --cover ./imgs/cover.png
  ./publish-wechat.sh article.md --title "自定义标题" --summary "自定义摘要"
  ./publish-wechat.sh article.md --type newspic
EOF
  exit 1
fi

ARTICLE_PATH="$1"
shift

cd "$ROOT_DIR"

if [[ ! -f "$ARTICLE_PATH" ]]; then
  echo "Error: file not found: $ARTICLE_PATH" >&2
  exit 1
fi

"${BUN_CMD[@]}" "$SKILL_DIR/scripts/wechat-api.ts" "$ARTICLE_PATH" --theme default "$@"
