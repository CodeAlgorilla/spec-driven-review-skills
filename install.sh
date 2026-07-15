#!/usr/bin/env bash
# install.sh — Top-level meta-installer for spec-driven-review-skills.
#
# Two skills are available:
#   • codex-review   (uses OpenAI Codex CLI — gpt-5.6-sol, max)
#   • claude-review  (uses Claude Code CLI — Opus 4.8, max effort)
#
# Usage:
#   bash install.sh              Interactive: picks which to install
#   bash install.sh both         Install both
#   bash install.sh codex        Install only codex-review
#   bash install.sh claude       Install only claude-review
#   bash install.sh verify       Run verify on installed skill(s)
#   bash install.sh uninstall    Uninstall installed skill(s)
#   bash install.sh help         Show this help

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_DIR="$SOURCE_DIR/codex-review"
CLAUDE_DIR="$SOURCE_DIR/claude-review"

# ───────────────────────── Colors / helpers ─────────────────────────

c_green()  { printf '\033[32m%s\033[0m' "$1"; }
c_yellow() { printf '\033[33m%s\033[0m' "$1"; }
c_red()    { printf '\033[31m%s\033[0m' "$1"; }
c_blue()   { printf '\033[34m%s\033[0m' "$1"; }
c_dim()    { printf '\033[2m%s\033[0m' "$1"; }
c_bold()   { printf '\033[1m%s\033[0m' "$1"; }

banner() {
  echo "$(c_bold '╔══════════════════════════════════════════════════════════╗')"
  echo "$(c_bold '║') $(c_bold '  Spec-Driven Code Review Skills installer              ') $(c_bold '║')"
  echo "$(c_bold '╚══════════════════════════════════════════════════════════╝')"
}

ok()   { echo "  $(c_green '✓') $1"; }
warn() { echo "  $(c_yellow '⚠') $1"; }
fail() { echo "  $(c_red '✗') $1"; }
step() { echo ""; echo "$(c_dim '→') $1"; }

# ───────────────────────── Sanity checks ─────────────────────────

require_subpackages() {
  if [ ! -d "$CODEX_DIR" ] || [ ! -f "$CODEX_DIR/install.sh" ]; then
    fail "codex-review/ subpackage missing or incomplete"
    exit 1
  fi
  if [ ! -d "$CLAUDE_DIR" ] || [ ! -f "$CLAUDE_DIR/install.sh" ]; then
    fail "claude-review/ subpackage missing or incomplete"
    exit 1
  fi
}

# ───────────────────────── Subcommands ─────────────────────────

show_help() {
  cat <<EOF
$(c_bold 'Spec-Driven Code Review Skills') — installer

Subcommands:
  install      Interactive picker (default if no argument)
  both         Install both skills
  codex        Install only codex-review
  claude       Install only claude-review
  verify       Run verify on installed skill(s)
  uninstall    Uninstall installed skill(s) (use --yes to skip confirmation)
  help         Show this help

Examples:
  bash install.sh
  bash install.sh both
  bash install.sh verify
  bash install.sh uninstall

Each sub-skill can also be installed directly:
  bash codex-review/install.sh
  bash claude-review/install.sh
EOF
}

install_codex() {
  step "Installing codex-review …"
  ( cd "$CODEX_DIR" && bash install.sh install )
}

install_claude() {
  step "Installing claude-review …"
  ( cd "$CLAUDE_DIR" && bash install.sh install )
}

do_install_both() {
  banner
  step "Installing both skills"
  install_codex
  echo ""
  install_claude
  echo ""
  show_postinstall both
}

do_install_codex_only() {
  banner
  install_codex
  echo ""
  show_postinstall codex
}

do_install_claude_only() {
  banner
  install_claude
  echo ""
  show_postinstall claude
}

show_postinstall() {
  local kind="$1"
  echo "$(c_green '══════════════════════════════════════════════════════════')"
  echo "$(c_green '  ✓ Installation complete')"
  echo "$(c_green '══════════════════════════════════════════════════════════')"
  echo ""
  case "$kind" in
    both)
      echo "Both skills installed. Trigger phrases:"
      echo ""
      echo "  $(c_blue 'codex-review')  →  \"codex review\", \"run codex review\","
      echo "                    \"before I commit/MR/PR\", \"before merging\""
      echo ""
      echo "  $(c_blue 'claude-review') →  \"claude review\", \"fresh review\","
      echo "                    \"fresh eyes\", \"another review with claude\""
      echo ""
      echo "Specs live separately:"
      echo "  codex-review:  .claude/review-spec.md"
      echo "  claude-review: .claude/review-spec-claude.md"
      ;;
    codex)
      echo "codex-review installed. Triggers:"
      echo "  \"codex review\", \"run codex review\""
      echo "  \"before I commit/MR/PR\", \"before merging\""
      echo ""
      echo "Spec: .claude/review-spec.md"
      ;;
    claude)
      echo "claude-review installed. Triggers:"
      echo "  \"claude review\", \"fresh review\", \"fresh eyes\""
      echo ""
      echo "Spec: .claude/review-spec-claude.md"
      ;;
  esac
  echo ""
  echo "Restart your Claude Code session to load the new CLAUDE.md policy."
  echo ""
  echo "Run \`bash install.sh verify\` anytime to check status."
}

read_tty_or_stdin() {
  # Read one line from /dev/tty if available, else stdin. Avoids hang in CI.
  local _var="$1"
  if [ -r /dev/tty ] 2>/dev/null; then
    read -r "$_var" < /dev/tty || return 1
  else
    read -r "$_var" || return 1
  fi
}

do_interactive() {
  banner
  echo ""
  echo "Two skills are available:"
  echo ""
  echo "  $(c_bold '1') $(c_blue 'codex-review')   $(c_dim '— uses OpenAI Codex (gpt-5.6-sol, max)')"
  echo "  $(c_bold '2') $(c_blue 'claude-review')  $(c_dim '— uses Claude Code (Opus 4.8, max effort)')"
  echo "  $(c_bold '3') $(c_green 'Both')           $(c_dim '— recommended (they coexist + complement)')"
  echo "  $(c_bold '0') $(c_dim 'Exit')"
  echo ""
  printf "Choice [1-3, 0]: "
  local choice=""
  if ! read_tty_or_stdin choice; then
    echo ""
    warn "No terminal available for interactive input."
    warn "Use \`bash install.sh both | codex | claude\` for non-interactive install."
    exit 1
  fi
  case "$choice" in
    1) do_install_codex_only ;;
    2) do_install_claude_only ;;
    3) do_install_both ;;
    0|"") echo ""; echo "Exiting without changes."; exit 0 ;;
    *) echo ""; fail "Unrecognized choice: $choice"; exit 1 ;;
  esac
}

do_verify() {
  banner
  local any=0
  local errors=0

  if [ -d "$HOME/.claude/skills/codex-review" ]; then
    any=1
    step "Verifying codex-review"
    ( cd "$CODEX_DIR" && bash install.sh verify ) || errors=$((errors+1))
  fi
  if [ -d "$HOME/.claude/skills/claude-review" ]; then
    any=1
    step "Verifying claude-review"
    ( cd "$CLAUDE_DIR" && bash install.sh verify ) || errors=$((errors+1))
  fi

  if [ "$any" -eq 0 ]; then
    echo ""
    warn "Neither skill appears to be installed. Run \`bash install.sh\` first."
    exit 1
  fi

  echo ""
  if [ $errors -eq 0 ]; then
    echo "$(c_green '  ✓ All installed skills verified')"
  else
    echo "$(c_red "  ✗ $errors skill(s) had issues — see above")"
    exit 1
  fi
}

do_uninstall() {
  banner

  echo ""
  echo "This will uninstall any installed skills from $HOME/.claude/skills/"
  echo "Per-project spec files (.claude/review-spec*.md) will NOT be touched."
  echo ""

  # If --yes/-y given, skip confirmation
  if [ "${1:-}" = "--yes" ] || [ "${1:-}" = "-y" ] || [ "${SKIP_CONFIRM:-}" = "1" ]; then
    :
  else
    printf "Continue? [y/N]: "
    local confirm=""
    if ! read_tty_or_stdin confirm; then
      echo ""
      warn "No terminal for confirmation. Use \`bash install.sh uninstall --yes\` to force."
      exit 1
    fi
    case "$confirm" in
      y|Y|yes|YES) ;;
      *) echo "Cancelled."; exit 0 ;;
    esac
  fi

  if [ -d "$HOME/.claude/skills/codex-review" ]; then
    step "Uninstalling codex-review"
    ( cd "$CODEX_DIR" && bash install.sh uninstall )
  else
    step "codex-review not installed"
  fi

  if [ -d "$HOME/.claude/skills/claude-review" ]; then
    step "Uninstalling claude-review"
    ( cd "$CLAUDE_DIR" && bash install.sh uninstall )
  else
    step "claude-review not installed"
  fi

  echo ""
  echo "$(c_green '  ✓ Uninstall complete')"
}

# ───────────────────────── Entry ─────────────────────────

require_subpackages

CMD="${1:-interactive}"
case "$CMD" in
  ""|interactive)        do_interactive ;;
  install)               do_interactive ;;
  both|all)              do_install_both ;;
  codex|codex-review)    do_install_codex_only ;;
  claude|claude-review)  do_install_claude_only ;;
  verify|check)          do_verify ;;
  uninstall|remove)      shift || true; do_uninstall "$@" ;;
  help|-h|--help)        show_help ;;
  *) fail "Unknown subcommand: $CMD"; show_help; exit 1 ;;
esac
