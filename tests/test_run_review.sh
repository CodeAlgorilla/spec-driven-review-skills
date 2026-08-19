#!/usr/bin/env bash
# test_run_review.sh — Behavioral test suite for both skills' run_review.sh.
#
# Runs each script against throwaway git repos, with shim `codex`/`claude`
# binaries that capture stdin, so assertions run on the exact bundle each
# script would send to its reviewer. No real codex/claude CLI is needed and
# nothing outside a mktemp workdir is touched.
#
# Covers: spec inline budget (default, env override, sanitization, truncation
# note + stderr marker), Related-code parsing from the full spec, Related-code
# per-file/total budgets, commits/plan/CLAUDE.md context budgets, and graceful
# degradation (unreadable spec, invalid/overflow budget values).
#
# Usage: bash tests/test_run_review.sh
set -u

REPO_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
BIN="$WORK/bin"
trap 'rm -rf "$WORK"' EXIT

# Don't let the caller's environment skew default-budget assertions.
unset CODEX_REVIEW_SPEC_BUDGET CLAUDE_REVIEW_SPEC_BUDGET \
      CODEX_REVIEW_CONTEXT CLAUDE_REVIEW_CONTEXT 2>/dev/null || true

PASS=0; FAIL=0
assert_contains()     { if grep -qF -- "$2" "$1"; then echo "PASS: $3"; PASS=$((PASS+1)); else echo "FAIL: $3 (missing: $2)"; FAIL=$((FAIL+1)); fi; }
assert_not_contains() { if grep -qF -- "$2" "$1"; then echo "FAIL: $3 (unexpected: $2)"; FAIL=$((FAIL+1)); else echo "PASS: $3"; PASS=$((PASS+1)); fi; }
assert_rc0()          { if [ "$1" -eq 0 ]; then echo "PASS: $2"; PASS=$((PASS+1)); else echo "FAIL: $2 (rc=$1)"; FAIL=$((FAIL+1)); fi; }

# --- shim reviewer binaries -------------------------------------------------
mkdir -p "$BIN"
for tool in codex claude; do
  cat > "$BIN/$tool" <<'EOF'
#!/usr/bin/env bash
cat > "${CAPTURE_FILE:?}"
echo "STATUS: CLEAN"
echo "SUMMARY: shim reviewer"
EOF
  chmod +x "$BIN/$tool"
done

# --- test repo --------------------------------------------------------------
make_spec() { # $1=outfile $2=filler_chars
  {
    echo "# Review Spec — harness"
    echo
    echo "## Purpose"
    echo "Harness spec."
    echo
    echo "## Requirements (the reviewer MUST verify these are met)"
    echo "- [ ] behaves"
    echo
    echo "## Filler"
    head -c "$2" /dev/zero | tr '\0' 'x'
    echo
    echo
    echo "## Related code"
    echo
    echo '- `src/helper.py`  # marker file'
    echo
    echo "## Notes"
    echo "NOTES_TAIL_MARKER"
  } > "$1"
}

setup_repo() { # $1=repo_dir
  rm -rf "$1"; mkdir -p "$1/src" "$1/.claude"
  ( cd "$1"
    git init -q -b main 2>/dev/null || { git init -q; git checkout -q -b main; }
    git config user.email t@t; git config user.name t
    git config commit.gpgsign false
    echo "def app(): return 1" > src/app.py
    git add -A; git commit -qm init
    echo "def app(): return 2  # changed" > src/app.py   # uncommitted diff
    echo "HELPER_MARKER_XYZZY = True" > src/helper.py    # related file, untracked
  )
}

run_case() { # $1=script $2=repo $3=capture $4=errfile $5=env_name $6=env_value  (stdout -> $3.out)
  : > "$3"; : > "$4"; : > "$3.out"
  ( cd "$2"
    export CAPTURE_FILE="$3" PATH="$BIN:$PATH"
    if [ -n "$5" ]; then export "$5=$6"; fi
    bash "$1" 1 >"$3.out" 2>"$4"
  )
}

# --- cases, run for both skills --------------------------------------------
for skill in codex claude; do
  if [ "$skill" = codex ]; then
    SCRIPT="$REPO_SRC/codex-review/codex-review/scripts/run_review.sh"
    SPEC_REL=".claude/review-spec.md"
    ENV_NAME="CODEX_REVIEW_SPEC_BUDGET"
  else
    SCRIPT="$REPO_SRC/claude-review/claude-review/scripts/run_review.sh"
    SPEC_REL=".claude/review-spec-claude.md"
    ENV_NAME="CLAUDE_REVIEW_SPEC_BUDGET"
  fi
  T="$WORK/$skill"; CAP="$WORK/$skill.cap"; ERR="$WORK/$skill.err"
  echo "=== $skill ==="

  # T1: 15k spec, default budget — fits the 60k default, Related past the old 12k cap
  setup_repo "$T"; make_spec "$T/$SPEC_REL" 15000
  run_case "$SCRIPT" "$T" "$CAP" "$ERR" "" ""; rc=$?
  assert_rc0 "$rc" "$skill/T1 exit 0"
  assert_contains     "$CAP" "HELPER_MARKER_XYZZY" "$skill/T1a related file loaded (15k spec)"
  assert_not_contains "$CAP" "[... truncated"      "$skill/T1b 15k spec not truncated (default budget)"
  assert_not_contains "$ERR" "TRUNCATED"           "$skill/T1c no truncation warning on stderr"

  # T2: 70k spec, default budget — truncated at 60k, note + warning + related still loaded
  setup_repo "$T"; make_spec "$T/$SPEC_REL" 70000
  run_case "$SCRIPT" "$T" "$CAP" "$ERR" "" ""; rc=$?
  assert_rc0 "$rc" "$skill/T2 exit 0"
  assert_contains "$CAP" "[... truncated"        "$skill/T2a 70k spec truncated at default budget"
  assert_contains "$CAP" "FULL spec"             "$skill/T2b read-the-full-spec note present"
  assert_contains "$CAP" "$T/$SPEC_REL"          "$skill/T2c note carries absolute spec path"
  assert_contains "$ERR" "TRUNCATED"             "$skill/T2d stderr truncation warning"
  assert_contains "$CAP" "HELPER_MARKER_XYZZY"   "$skill/T2e related file loaded despite truncation"

  # T3: 70k spec, env override 100000 — no truncation
  setup_repo "$T"; make_spec "$T/$SPEC_REL" 70000
  run_case "$SCRIPT" "$T" "$CAP" "$ERR" "$ENV_NAME" 100000; rc=$?
  assert_rc0 "$rc" "$skill/T3 exit 0"
  assert_not_contains "$CAP" "[... truncated" "$skill/T3a env override lifts truncation"
  assert_not_contains "$ERR" "TRUNCATED"      "$skill/T3b no stderr warning with raised budget"

  # T4: invalid env value — falls back to default, no crash
  setup_repo "$T"; make_spec "$T/$SPEC_REL" 15000
  run_case "$SCRIPT" "$T" "$CAP" "$ERR" "$ENV_NAME" "abc"; rc=$?
  assert_rc0 "$rc" "$skill/T4 exit 0 with invalid env value"
  assert_not_contains "$CAP" "[... truncated" "$skill/T4a invalid env falls back to default"

  # T6: leading-zero budget (invalid octal digits) — normalized to decimal, no crash
  setup_repo "$T"; make_spec "$T/$SPEC_REL" 15000
  run_case "$SCRIPT" "$T" "$CAP" "$ERR" "$ENV_NAME" "09000"; rc=$?
  assert_rc0 "$rc" "$skill/T6 exit 0 with leading-zero budget 09000"
  assert_contains "$CAP" "first 9000 of" "$skill/T6a budget 09000 treated as decimal 9000"

  # T7: leading-zero budget that IS valid octal — must still be decimal
  setup_repo "$T"; make_spec "$T/$SPEC_REL" 45000
  run_case "$SCRIPT" "$T" "$CAP" "$ERR" "$ENV_NAME" "0100000"; rc=$?
  assert_rc0 "$rc" "$skill/T7 exit 0 with budget 0100000"
  assert_not_contains "$CAP" "[... truncated" "$skill/T7a 0100000 read as decimal 100000 (45k spec fits)"

  # T8: absurdly huge budget — falls back cleanly, no bash integer errors
  setup_repo "$T"; make_spec "$T/$SPEC_REL" 15000
  run_case "$SCRIPT" "$T" "$CAP" "$ERR" "$ENV_NAME" "99999999999999999999"; rc=$?
  assert_rc0 "$rc" "$skill/T8 exit 0 with overflow budget"
  assert_not_contains "$CAP" "[... truncated"           "$skill/T8a overflow budget falls back to default"
  assert_not_contains "$ERR" "integer expression"       "$skill/T8b no bash integer errors on stderr"

  # T9: spec file exists but unreadable — degrade to spec-less review, keep STATUS protocol
  # (meaningless as root, where chmod 000 files stay readable)
  if [ "$(id -u)" -ne 0 ]; then
    setup_repo "$T"; make_spec "$T/$SPEC_REL" 1000; chmod 000 "$T/$SPEC_REL"
    run_case "$SCRIPT" "$T" "$CAP" "$ERR" "" ""; rc=$?
    chmod 644 "$T/$SPEC_REL"
    assert_rc0 "$rc" "$skill/T9 exit 0 with unreadable spec"
    assert_contains "$CAP.out" "STATUS:" "$skill/T9a STATUS line still emitted (unreadable spec)"
  else
    echo "SKIP: $skill/T9 unreadable-spec case (running as root)"
  fi

  # T5: small spec — regression guard, nothing new fires
  setup_repo "$T"; make_spec "$T/$SPEC_REL" 100
  run_case "$SCRIPT" "$T" "$CAP" "$ERR" "" ""; rc=$?
  assert_rc0 "$rc" "$skill/T5 exit 0"
  assert_contains     "$CAP" "HELPER_MARKER_XYZZY" "$skill/T5a related file loaded (small spec)"
  assert_contains     "$CAP" "NOTES_TAIL_MARKER"   "$skill/T5b spec tail present (small spec)"
  assert_not_contains "$CAP" "SPEC TRUNCATED"      "$skill/T5c no truncation note (small spec)"
  assert_not_contains "$ERR" "TRUNCATED"           "$skill/T5d no stderr warning (small spec)"

  # T10: Related-code budgets — 6 files x 20k chars each. The pre-overhaul
  # 8000 per-file cut every tail; the old 40000 total skipped file 6 entirely.
  setup_repo "$T"
  {
    echo "# Review Spec — harness"
    echo; echo "## Purpose"; echo "Harness spec."
    echo; echo "## Related code"; echo
    for i in 1 2 3 4 5 6; do echo "- \`src/rel$i.py\`"; done
    echo; echo "## Notes"; echo "NOTES_TAIL_MARKER"
  } > "$T/$SPEC_REL"
  for i in 1 2 3 4 5 6; do
    { head -c 20000 /dev/zero | tr '\0' 'y'; echo; echo "RTAIL_MARKER_$i = True"; } > "$T/src/rel$i.py"
  done
  run_case "$SCRIPT" "$T" "$CAP" "$ERR" "" ""; rc=$?
  assert_rc0 "$rc" "$skill/T10 exit 0"
  assert_contains     "$CAP" "RTAIL_MARKER_1"          "$skill/T10a per-file budget keeps 20k file tail"
  assert_contains     "$CAP" "RTAIL_MARKER_6"          "$skill/T10b total budget fits 6x20k files"
  assert_not_contains "$CAP" "total budget exhausted"  "$skill/T10c no file skipped for total budget"

  # T11: no-spec context budgets (commits / plan / CLAUDE.md) on a feature branch
  setup_repo "$T"; rm -f "$T/$SPEC_REL"
  ( cd "$T"
    git checkout -q -b feature
    git add -A; git commit -qm "seed feature"
    for i in 1 2 3 4 5 6 7 8 9 10; do
      echo "change $i" >> src/app.py
      body="COMMIT_BODY_${i}_MARKER $(head -c 700 /dev/zero | tr '\0' 'b')"
      git add -A; git commit -qm "commit $i" -m "$body"
    done
    mkdir -p .claude/plans
    { head -c 10000 /dev/zero | tr '\0' 'p'; echo; echo "PLAN_TAIL_MARKER"; } > .claude/plans/plan.md
    { for n in $(seq 1 300); do
        if [ "$n" -eq 250 ]; then echo "line $n CLAUDEMD_DEEP_MARKER xxxxxxxxxxxxxxxxxx"
        else echo "line $n xxxxxxxxxxxxxxxxxxxxxxxxxxxx"; fi
      done; } > CLAUDE.md
  )
  run_case "$SCRIPT" "$T" "$CAP" "$ERR" "" ""; rc=$?
  assert_rc0 "$rc" "$skill/T11 exit 0"
  assert_contains "$CAP" "COMMIT_BODY_1_MARKER"  "$skill/T11a commits budget keeps oldest commit body"
  assert_contains "$CAP" "PLAN_TAIL_MARKER"      "$skill/T11b plan budget keeps 10k plan tail"
  assert_contains "$CAP" "CLAUDEMD_DEEP_MARKER"  "$skill/T11c CLAUDE.md excerpt reaches line 250"
done

echo
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
