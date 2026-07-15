#!/usr/bin/env bash
set -euo pipefail
PKG_VERSION="2.2.0"

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$SOURCE_DIR/claude-review"
USER_CLAUDE_DIR="$HOME/.claude"
USER_CLAUDE_MD="$USER_CLAUDE_DIR/CLAUDE.md"
SKILL_TARGET="$USER_CLAUDE_DIR/skills/claude-review"
POLICY_START_MARKER="<!-- claude-review-policy -->"
POLICY_END_MARKER="<!-- /claude-review-policy -->"

LEGACY_SKILL_FILES=("$SKILL_TARGET/scripts/prepare_review.sh")

c_green()  { printf '\033[32m%s\033[0m' "$1"; }
c_yellow() { printf '\033[33m%s\033[0m' "$1"; }
c_red()    { printf '\033[31m%s\033[0m' "$1"; }
c_dim()    { printf '\033[2m%s\033[0m' "$1"; }
ok()   { echo "  $(c_green '✓') $1"; }
warn() { echo "  $(c_yellow '⚠') $1"; }
fail() { echo "  $(c_red '✗') $1"; }
step() { echo ""; echo "$(c_dim '→') $1"; }

# Safely remove the policy block from USER_CLAUDE_MD.
# Only deletes when exactly one START marker pairs with exactly one END after it,
# and writes through the file (never rename) so a symlinked CLAUDE.md keeps its link.
# Returns 1 (touching nothing) when the markers are malformed.
remove_policy_block() {
  local starts ends start_line end_line tmp
  [ -f "$USER_CLAUDE_MD" ] || return 0
  starts=$(grep -cF "$POLICY_START_MARKER" "$USER_CLAUDE_MD" || true)
  ends=$(grep -cF "$POLICY_END_MARKER" "$USER_CLAUDE_MD" || true)
  if [ "$starts" -eq 0 ] && [ "$ends" -eq 0 ]; then return 0; fi
  if [ "$starts" -ne 1 ] || [ "$ends" -ne 1 ]; then return 1; fi
  start_line=$(grep -nF "$POLICY_START_MARKER" "$USER_CLAUDE_MD" | head -1 | cut -d: -f1)
  end_line=$(grep -nF "$POLICY_END_MARKER" "$USER_CLAUDE_MD" | head -1 | cut -d: -f1)
  if [ "$end_line" -lt "$start_line" ]; then return 1; fi
  cp "$USER_CLAUDE_MD" "${USER_CLAUDE_MD}.bak"
  tmp=$(mktemp)
  awk -v s="$start_line" -v e="$end_line" 'NR < s || NR > e' "$USER_CLAUDE_MD" > "$tmp"
  cat "$tmp" > "$USER_CLAUDE_MD"
  rm -f "$tmp"
  ok "Existing policy block removed (backup at .bak)"
  return 0
}

do_install() {
  for f in SKILL.md scripts/run_review.sh scripts/init-spec.sh \
           references/reviewer_prompt.md templates/review-spec-claude.template.md \
           CLAUDE_md_policy.md; do
    [ -f "$PKG_DIR/$f" ] || { echo "ERROR: Missing $PKG_DIR/$f" >&2; exit 1; }
  done

  echo "══════════════════════════════════════════════════════════"
  echo "  claude-review skill installer (v$PKG_VERSION)"
  echo "══════════════════════════════════════════════════════════"

  step "Cleaning v1.0 leftovers (if any)"
  local cleaned=0
  for f in "${LEGACY_SKILL_FILES[@]}"; do
    [ -f "$f" ] && { rm "$f"; ok "Removed legacy: $f"; cleaned=1; }
  done
  [ $cleaned -eq 0 ] && ok "No leftovers"

  step "Installing skill files → $SKILL_TARGET"
  rm -rf "$SKILL_TARGET/scripts" "$SKILL_TARGET/references" "$SKILL_TARGET/templates"
  mkdir -p "$SKILL_TARGET/scripts" "$SKILL_TARGET/references" "$SKILL_TARGET/templates"
  [ -f "$SKILL_TARGET/SKILL.md" ] && { cp "$SKILL_TARGET/SKILL.md" "$SKILL_TARGET/SKILL.md.bak"; warn "Existing SKILL.md backed up"; }
  cp "$PKG_DIR/SKILL.md" "$SKILL_TARGET/"
  cp "$PKG_DIR/scripts/run_review.sh" "$SKILL_TARGET/scripts/"
  cp "$PKG_DIR/scripts/init-spec.sh" "$SKILL_TARGET/scripts/"
  cp "$PKG_DIR/references/reviewer_prompt.md" "$SKILL_TARGET/references/"
  cp "$PKG_DIR/templates/review-spec-claude.template.md" "$SKILL_TARGET/templates/"
  chmod +x "$SKILL_TARGET/scripts/"*.sh
  ok "Skill files installed"

  step "Updating CLAUDE.md policy"
  mkdir -p "$USER_CLAUDE_DIR"; touch "$USER_CLAUDE_MD"
  if remove_policy_block; then
    { echo ""; cat "$PKG_DIR/CLAUDE_md_policy.md"; } >> "$USER_CLAUDE_MD"
    ok "v2.2 policy appended"
  else
    warn "claude-review policy markers in $USER_CLAUDE_MD are malformed (orphaned or duplicated)."
    warn "NOT touching the policy. Clean up the markers manually, then re-run install."
  fi

  step "Coexistence check"
  if [ -d "$USER_CLAUDE_DIR/skills/codex-review" ]; then
    ok "codex-review present — coexisting"
  else
    ok "codex-review not installed — claude-review standalone"
  fi

  step "Claude Code CLI"
  if command -v claude >/dev/null 2>&1; then
    ok "claude found: $(command -v claude)"
    local v; v=$(claude --version 2>&1 | head -1 || true); [ -n "$v" ] && ok "$v"
  else
    fail "claude CLI not found — install: npm install -g @anthropic-ai/claude-code"
  fi

  echo ""
  echo "══════════════════════════════════════════════════════════"
  echo "$(c_green '  ✓ Installation complete')"
  echo "══════════════════════════════════════════════════════════"
  echo ""
  echo "What's new in v2.2.0:"
  echo "  • Phase A NOW auto-explores codebase for Related code"
  echo "    Claude scans for callers, type users, sibling modules and"
  echo "    auto-fills the Related code section before showing the spec"
  echo "  • You still review the populated spec — hard stop preserved"
  echo ""
  echo "Run \`bash install.sh verify\` to check status."
}

do_verify() {
  echo "══════════════════════════════════════════════════════════"
  echo "  claude-review verification (v$PKG_VERSION)"
  echo "══════════════════════════════════════════════════════════"
  local errors=0

  step "Skill files"
  for f in SKILL.md scripts/run_review.sh scripts/init-spec.sh \
           references/reviewer_prompt.md templates/review-spec-claude.template.md; do
    if [ -f "$SKILL_TARGET/$f" ]; then ok "$f present"
    else fail "Missing: $f"; errors=$((errors+1)); fi
  done

  step "v2.2 — Phase A auto-exploration"
  if grep -q "EXPLORE for Related code" "$SKILL_TARGET/SKILL.md" 2>/dev/null; then
    ok "Phase A auto-explores codebase"
  fi
  if grep -q "auto-explored Related code" "$USER_CLAUDE_MD" 2>/dev/null; then
    ok "CLAUDE.md policy mentions auto-exploration"
  fi

  step "Related code parsing in script"
  grep -q "Related code" "$SKILL_TARGET/scripts/run_review.sh" 2>/dev/null && ok "Wired up"

  step "Read-only tools restriction"
  grep -q -- '--allowedTools "Read,Grep,Glob"' "$SKILL_TARGET/scripts/run_review.sh" 2>/dev/null && ok "Read-only tools enforced"

  step "Fable 5 max effort"
  if grep -q -- "--model claude-fable-5" "$SKILL_TARGET/scripts/run_review.sh" 2>/dev/null \
     && grep -q -- "--effort max" "$SKILL_TARGET/scripts/run_review.sh" 2>/dev/null; then
    ok "Fable 5 with max effort"
  fi

  step "Coexistence"
  if [ -d "$USER_CLAUDE_DIR/skills/codex-review" ]; then
    ok "codex-review present — coexisting"
  else
    ok "Standalone"
  fi

  step "Claude Code CLI"
  if command -v claude >/dev/null 2>&1; then ok "claude found"
  else fail "claude not in PATH"; errors=$((errors+1)); fi

  echo ""
  if [ $errors -eq 0 ]; then
    echo "$(c_green '  ✓ All checks passed')"; exit 0
  else
    echo "$(c_red "  ✗ $errors check(s) failed")"; exit 1
  fi
}

do_uninstall() {
  echo "Uninstalling claude-review..."
  [ -d "$SKILL_TARGET" ] && { rm -rf "$SKILL_TARGET"; ok "Removed $SKILL_TARGET"; }
  if ! remove_policy_block; then
    warn "claude-review policy markers in $USER_CLAUDE_MD are malformed (orphaned or duplicated)."
    warn "NOT touching the policy. Remove the block manually."
  fi
  echo "Uninstalled. codex-review NOT affected."
}

case "${1:-install}" in
  install|upgrade)  do_install ;;
  verify|check)     do_verify ;;
  uninstall|remove) do_uninstall ;;
  help|-h|--help)   echo "Subcommands: install / verify / uninstall" ;;
  *) echo "Unknown: $1" >&2; exit 1 ;;
esac
