#!/usr/bin/env bash
# init-spec.sh — Scaffold a review spec for the claude-review skill.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE="$SKILL_DIR/templates/review-spec-claude.template.md"

MODE="branch"
PRINT_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --project)  MODE="project"; shift ;;
    --branch)   MODE="branch"; shift ;;
    --print)    PRINT_ONLY=1; shift ;;
    -h|--help)  echo "Usage: bash init-spec.sh [--project|--print]"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

[ ! -f "$TEMPLATE" ] && { echo "ERROR: Template missing at $TEMPLATE" >&2; exit 1; }
[ $PRINT_ONLY -eq 1 ] && { cat "$TEMPLATE"; exit 0; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "ERROR: Not in a git repo." >&2; exit 1; }
REPO_ROOT="$(git rev-parse --show-toplevel)"

if [ "$MODE" = "project" ]; then
  TARGET_DIR="$REPO_ROOT/.claude-review"; TARGET="$TARGET_DIR/spec.md"
else
  TARGET_DIR="$REPO_ROOT/.claude"; TARGET="$TARGET_DIR/review-spec-claude.md"
fi

mkdir -p "$TARGET_DIR"
if [ -f "$TARGET" ]; then
  echo "Spec already exists at: $TARGET"
  exit 0
fi
cp "$TEMPLATE" "$TARGET"
echo "✓ Created claude-review spec at: $TARGET"
