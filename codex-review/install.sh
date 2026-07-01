#!/usr/bin/env bash
set -euo pipefail
PKG_VERSION="1.5.0"

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$SOURCE_DIR/codex-review"
USER_CLAUDE_DIR="$HOME/.claude"
USER_CLAUDE_MD="$USER_CLAUDE_DIR/CLAUDE.md"
SKILL_TARGET="$USER_CLAUDE_DIR/skills/codex-review"
POLICY_START_MARKER="<!-- codex-review-policy -->"
POLICY_END_MARKER="<!-- /codex-review-policy -->"

c_green()  { printf '\033[32m%s\033[0m' "$1"; }
c_yellow() { printf '\033[33m%s\033[0m' "$1"; }
c_red()    { printf '\033[31m%s\033[0m' "$1"; }
c_dim()    { printf '\033[2m%s\033[0m' "$1"; }
ok()   { echo "  $(c_green '✓') $1"; }
warn() { echo "  $(c_yellow '⚠') $1"; }
fail() { echo "  $(c_red '✗') $1"; }
step() { echo ""; echo "$(c_dim '→') $1"; }

do_install() {
  for f in SKILL.md scripts/run_review.sh scripts/init-spec.sh \
           references/reviewer_prompt.md templates/review-spec.template.md \
           CLAUDE_md_policy.md; do
    [ -f "$PKG_DIR/$f" ] || { echo "ERROR: Missing $PKG_DIR/$f" >&2; exit 1; }
  done

  echo "══════════════════════════════════════════════════════════"
  echo "  codex-review skill installer (v$PKG_VERSION)"
  echo "══════════════════════════════════════════════════════════"

  step "Installing skill files → $SKILL_TARGET"
  mkdir -p "$SKILL_TARGET/scripts" "$SKILL_TARGET/references" "$SKILL_TARGET/templates"
  [ -f "$SKILL_TARGET/SKILL.md" ] && { cp "$SKILL_TARGET/SKILL.md" "$SKILL_TARGET/SKILL.md.bak"; warn "Existing SKILL.md backed up"; }
  cp "$PKG_DIR/SKILL.md" "$SKILL_TARGET/"
  cp "$PKG_DIR/scripts/run_review.sh" "$SKILL_TARGET/scripts/"
  cp "$PKG_DIR/scripts/init-spec.sh" "$SKILL_TARGET/scripts/"
  cp "$PKG_DIR/references/reviewer_prompt.md" "$SKILL_TARGET/references/"
  cp "$PKG_DIR/templates/review-spec.template.md" "$SKILL_TARGET/templates/"
  chmod +x "$SKILL_TARGET/scripts/"*.sh
  ok "Skill files installed"

  step "Updating CLAUDE.md policy"
  mkdir -p "$USER_CLAUDE_DIR"
  touch "$USER_CLAUDE_MD"
  if grep -qF "$POLICY_START_MARKER" "$USER_CLAUDE_MD"; then
    cp "$USER_CLAUDE_MD" "${USER_CLAUDE_MD}.bak"
    sed -i.tmp "/${POLICY_START_MARKER//\//\\/}/,/${POLICY_END_MARKER//\//\\/}/d" "$USER_CLAUDE_MD"
    rm -f "${USER_CLAUDE_MD}.tmp"
    ok "Old policy removed (backup at .bak)"
  fi
  { echo ""; cat "$PKG_DIR/CLAUDE_md_policy.md"; } >> "$USER_CLAUDE_MD"
  ok "v1.5 policy appended"

  step "codex CLI"
  if command -v codex >/dev/null 2>&1; then
    ok "codex found: $(command -v codex)"
    local v; v=$(codex --version 2>&1 | head -1 || true); [ -n "$v" ] && ok "$v"
  else
    fail "codex CLI not found — install: npm install -g @openai/codex"
  fi

  echo ""
  echo "══════════════════════════════════════════════════════════"
  echo "$(c_green '  ✓ Installation complete')"
  echo "══════════════════════════════════════════════════════════"
  echo ""
  echo "What's new in v1.5.0:"
  echo "  • Phase A NOW auto-explores codebase for Related code (no prompting)"
  echo "  • Phase B triggers NARROWED — only explicit review/merge requests fire"
  echo "    Removed: \"I'm done\", \"let's review\", \"wrap up branch\", \"finalize\""
  echo "    Kept:    \"codex review\", \"run codex review\", \"before I commit/MR/PR\","
  echo "             \"before merging\""
  echo "  • For \"I'm done\"-style phrases, Claude now acknowledges without firing"
  echo ""
  echo "Run \`bash install.sh verify\` to check status."
}

do_verify() {
  echo "══════════════════════════════════════════════════════════"
  echo "  codex-review verification (v$PKG_VERSION)"
  echo "══════════════════════════════════════════════════════════"
  local errors=0

  step "Skill files"
  for f in SKILL.md scripts/run_review.sh scripts/init-spec.sh \
           references/reviewer_prompt.md templates/review-spec.template.md; do
    if [ -f "$SKILL_TARGET/$f" ]; then ok "$f present"
    else fail "Missing: $f"; errors=$((errors+1)); fi
  done

  step "v1.5 — narrowed triggers"
  if grep -q 'NARROW' "$SKILL_TARGET/SKILL.md" 2>/dev/null \
     && grep -q "I'm done" "$SKILL_TARGET/CLAUDE_md_policy.md" 2>/dev/null || \
     grep -q "removed in v1.5" "$USER_CLAUDE_MD" 2>/dev/null; then
    ok "Triggers narrowed (v1.5 policy detected)"
  else
    # Check policy in CLAUDE.md instead
    if grep -q "removed in v1.5" "$USER_CLAUDE_MD" 2>/dev/null; then
      ok "Triggers narrowed (v1.5 policy detected in CLAUDE.md)"
    else
      warn "Older policy — re-run install.sh to refresh"
    fi
  fi

  step "v1.5 — Phase A auto-exploration"
  if grep -q "EXPLORE for Related code" "$SKILL_TARGET/SKILL.md" 2>/dev/null; then
    ok "Phase A auto-explores codebase"
  else
    warn "SKILL.md missing auto-exploration — re-run install.sh"
  fi
  if grep -q "EXPLORE for Related code" "$USER_CLAUDE_MD" 2>/dev/null; then
    ok "CLAUDE.md policy includes exploration"
  fi

  step "Related code parsing"
  if grep -q "Related code" "$SKILL_TARGET/scripts/run_review.sh" 2>/dev/null; then
    ok "Script parses Related code section"
  fi

  step "codex CLI"
  if command -v codex >/dev/null 2>&1; then
    ok "codex found"
  else
    fail "codex not in PATH"; errors=$((errors+1))
  fi

  echo ""
  if [ $errors -eq 0 ]; then
    echo "$(c_green '  ✓ All checks passed')"; exit 0
  else
    echo "$(c_red "  ✗ $errors check(s) failed")"; exit 1
  fi
}

do_uninstall() {
  echo "Uninstalling codex-review..."
  [ -d "$SKILL_TARGET" ] && { rm -rf "$SKILL_TARGET"; ok "Removed $SKILL_TARGET"; }
  if grep -qF "$POLICY_START_MARKER" "$USER_CLAUDE_MD" 2>/dev/null; then
    cp "$USER_CLAUDE_MD" "${USER_CLAUDE_MD}.bak"
    sed -i.tmp "/${POLICY_START_MARKER//\//\\/}/,/${POLICY_END_MARKER//\//\\/}/d" "$USER_CLAUDE_MD"
    rm -f "${USER_CLAUDE_MD}.tmp"
    ok "Policy block removed (backup at .bak)"
  fi
  echo "Uninstalled. claude-review NOT affected."
}

case "${1:-install}" in
  install|upgrade)  do_install ;;
  verify|check)     do_verify ;;
  uninstall|remove) do_uninstall ;;
  help|-h|--help)   echo "Subcommands: install / verify / uninstall" ;;
  *) echo "Unknown: $1" >&2; exit 1 ;;
esac
