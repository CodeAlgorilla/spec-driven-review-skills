#!/usr/bin/env bash
# run_review.sh — Send a git diff + context to Claude Code (fable-5, max effort)
# headless for review.
#
# v2.1.0+: supports a "Related code" section in the spec. Files listed there
# are read in full and included in the bundle. The reviewer may also use
# Read/Grep/Glob tools to explore beyond the bundle when needed.
#
# Spec inline budget: 60000 chars by default (CLAUDE_REVIEW_SPEC_BUDGET
# overrides). Longer specs are embedded truncated, flagged on stderr, and the
# reviewer is told to read the full spec file itself.

set -euo pipefail

ITERATION="${1:-1}"
shift || true

BASE_REF=""
EXTRA_CONTEXT="${CLAUDE_REVIEW_CONTEXT:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --context)    EXTRA_CONTEXT="${2:-}"; shift 2 ;;
    --context=*)  EXTRA_CONTEXT="${1#--context=}"; shift ;;
    *)            if [ -z "$BASE_REF" ]; then BASE_REF="$1"; fi; shift ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
PROMPT_FILE="$SKILL_DIR/references/reviewer_prompt.md"

if ! command -v claude >/dev/null 2>&1; then
  cat <<EOF
STATUS: ERROR
SUMMARY: claude CLI not found in PATH.
Install: npm install -g @anthropic-ai/claude-code
Then: claude  (interactive first run to authenticate)
EOF
  exit 127
fi
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "STATUS: ERROR"; echo "SUMMARY: Not inside a git repository."; exit 1
fi
if [ ! -f "$PROMPT_FILE" ]; then
  echo "STATUS: ERROR"; echo "SUMMARY: Reviewer prompt missing at: $PROMPT_FILE"; exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"

detect_default_branch() {
  local b
  b=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@' || true)
  if [ -n "${b:-}" ]; then echo "$b"; return; fi
  if git show-ref --verify --quiet refs/heads/main;   then echo "main";   return; fi
  if git show-ref --verify --quiet refs/heads/master; then echo "master"; return; fi
  echo ""
}

if [ -n "$BASE_REF" ]; then
  if DIFF=$(git diff "${BASE_REF}...HEAD" 2>/dev/null); then
    SCOPE="changes vs ${BASE_REF}"
  elif DIFF=$(git diff "${BASE_REF}" 2>/dev/null); then
    SCOPE="changes vs ${BASE_REF} (two-dot diff; no merge base)"
  else
    echo "STATUS: ERROR"
    echo "SUMMARY: Cannot diff against '${BASE_REF}' — ref does not resolve."
    exit 1
  fi
  COMMIT_RANGE="${BASE_REF}..HEAD"
else
  DEFAULT_BRANCH=$(detect_default_branch)
  CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ] && [ -n "$DEFAULT_BRANCH" ] && [ "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" ]; then
    if git show-ref --verify --quiet "refs/remotes/origin/$DEFAULT_BRANCH"; then BASE="origin/$DEFAULT_BRANCH"; else BASE="$DEFAULT_BRANCH"; fi
    if DIFF=$(git diff "${BASE}...HEAD" 2>/dev/null); then
      SCOPE="feature branch '$CURRENT_BRANCH' vs $BASE (three-dot diff)"
    elif DIFF=$(git diff "${BASE}" 2>/dev/null); then
      SCOPE="feature branch '$CURRENT_BRANCH' vs $BASE (two-dot diff; no merge base)"
    else
      echo "STATUS: ERROR"
      echo "SUMMARY: Cannot diff '$CURRENT_BRANCH' against $BASE."
      exit 1
    fi
    COMMIT_RANGE="${BASE}..HEAD"
    UNCOMMITTED=$(git diff HEAD)
    if [ -n "$UNCOMMITTED" ]; then
      DIFF="${DIFF}

# === Uncommitted changes (not yet on the branch) ===
${UNCOMMITTED}"
      SCOPE="${SCOPE} + uncommitted changes"
    fi
  else
    if ! git rev-parse --verify --quiet HEAD >/dev/null; then
      echo "STATUS: ERROR"
      echo "SUMMARY: Repository has no commits yet (unborn HEAD) — nothing to diff against."
      exit 1
    fi
    DIFF=$(git diff HEAD)
    SCOPE="uncommitted changes (staged + unstaged) vs HEAD"
    COMMIT_RANGE=""
  fi
fi

if [ -z "$DIFF" ]; then
  echo "STATUS: CLEAN"
  echo "SUMMARY: No changes detected to review (scope: $SCOPE)."
  exit 0
fi

truncate_str() {
  local s="$1" max="$2"
  if [ ${#s} -gt "$max" ]; then echo "${s:0:$max}"; echo ""; echo "[... truncated, ${#s} chars total ...]"
  else echo "$s"; fi
}

# Print a backtick fence longer than the longest backtick run in $1 (min 3),
# so embedded content can never close the wrapper fence early.
backtick_fence() {
  local run
  run=$(printf '%s\n' "$1" | awk '{
    s = $0; n = 0
    while (match(s, /`+/)) { if (RLENGTH > n) n = RLENGTH; s = substr(s, RSTART + RLENGTH) }
    if (n > max) max = n
  } END { print max + 0 }')
  if [ "$run" -lt 2 ]; then run=2; fi
  printf '%*s' "$((run + 1))" '' | tr ' ' '`'
}

# Spec. Inline budget is in chars; override with CLAUDE_REVIEW_SPEC_BUDGET.
SPEC_BUDGET="${CLAUDE_REVIEW_SPEC_BUDGET:-60000}"
case "$SPEC_BUDGET" in
  ''|*[!0-9]*) SPEC_BUDGET=60000 ;;
esac
if [ ${#SPEC_BUDGET} -gt 9 ]; then SPEC_BUDGET=60000; fi
# Force base-10: a leading zero would octal-parse in ${s:0:$max} arithmetic.
SPEC_BUDGET=$((10#$SPEC_BUDGET))
SPEC_TEXT=""; SPEC_FULL=""; SPEC_PATH=""; SPEC_ABS=""; SPEC_SCOPE=""; SPEC_TRUNCATED=0
for spec_candidate in "$REPO_ROOT/.claude/review-spec-claude.md" "$REPO_ROOT/.claude-review/spec.md"; do
  if [ -f "$spec_candidate" ]; then
    SPEC_PATH="${spec_candidate#"$REPO_ROOT"/}"
    SPEC_ABS="$spec_candidate"
    [[ "$spec_candidate" == *"/.claude/"* ]] && SPEC_SCOPE="branch-level" || SPEC_SCOPE="project-level"
    SPEC_FULL=$(cat "$spec_candidate" 2>/dev/null || true)
    SPEC_TEXT=$(truncate_str "$SPEC_FULL" "$SPEC_BUDGET")
    if [ ${#SPEC_FULL} -gt "$SPEC_BUDGET" ]; then SPEC_TRUNCATED=1; fi
    break
  fi
done

RELATED_CODE_TEXT=""; RELATED_LOADED=(); RELATED_SKIPPED=()
if [ -n "$SPEC_TEXT" ]; then
  # Parse from the FULL spec, not the truncated embed: the template puts
  # "## Related code" near the end, where truncation would silently drop it.
  RELATED_SECTION=$(echo "$SPEC_FULL" | awk '/^## Related code/ { in_section=1; next } /^## / { in_section=0 } in_section==1 { print }')
  RELATED_FILES=()
  while IFS= read -r line; do
    stripped="${line#-}"
    stripped="${stripped# }"; stripped="${stripped# }"
    stripped="${stripped#\`}"; stripped="${stripped%% #*}"
    stripped="${stripped%"${stripped##*[![:space:]]}"}"
    stripped="${stripped%\`}"
    if [ -z "$stripped" ] || [[ "$stripped" == "<"* ]] || [[ "$stripped" == "#"* ]]; then continue; fi
    RELATED_FILES+=("$stripped")
  done <<< "$RELATED_SECTION"

  # Sized to honour this script's documented contract ("read in full"). The old
  # 40000/8000 pair silently truncated ordinary sources and dropped whole files
  # once the running total was exhausted — the stderr `related:Nfiles` count was
  # the only signal. These remain a backstop against generated/vendored blobs.
  TOTAL_BUDGET=400000; PER_FILE_BUDGET=60000; bytes_loaded=0
  # bash 3.2-safe: expands to nothing (not an "unbound variable" error) when the array is empty
  for relpath in ${RELATED_FILES[@]+"${RELATED_FILES[@]}"}; do
    case "/$relpath/" in
      */../*) RELATED_SKIPPED+=("$relpath (outside repo)"); continue ;;
    esac
    fullpath="$REPO_ROOT/$relpath"
    if [ ! -f "$fullpath" ]; then RELATED_SKIPPED+=("$relpath (not found)"); continue; fi
    if [ "$bytes_loaded" -ge "$TOTAL_BUDGET" ]; then RELATED_SKIPPED+=("$relpath (total budget exhausted)"); continue; fi
    content="$(cat "$fullpath" 2>/dev/null || true)"
    if [ -z "$content" ]; then RELATED_SKIPPED+=("$relpath (empty or unreadable)"); continue; fi
    orig_len=${#content}
    if [ ${#content} -gt "$PER_FILE_BUDGET" ]; then
      content="${content:0:$PER_FILE_BUDGET}

[... truncated; full file is $orig_len chars]"
    fi
    fence=$(backtick_fence "$content")
    RELATED_CODE_TEXT="${RELATED_CODE_TEXT}#### \`$relpath\`

${fence}
${content}
${fence}

"
    bytes_loaded=$((bytes_loaded + ${#content}))
    RELATED_LOADED+=("$relpath")
  done
fi

COMMITS_TEXT=""
if [ -n "$COMMIT_RANGE" ]; then
  RAW_COMMITS=$(git log --no-merges --format='─── %h %s%n%b%n' "$COMMIT_RANGE" 2>/dev/null || true)
  # 4000 covered only a handful of commits with bodies; a long branch lost most
  # of its history — exactly where per-task rationale lives.
  [ -n "$RAW_COMMITS" ] && COMMITS_TEXT=$(truncate_str "$RAW_COMMITS" 60000)
fi

PLAN_TEXT=""; PLAN_PATH=""
for plan_dir in "$REPO_ROOT/.claude/plans" "$REPO_ROOT/.superpowers/plans" "$REPO_ROOT/plans"; do
  if [ -d "$plan_dir" ]; then
    LATEST_PLAN=$(ls -t "$plan_dir"/*.md 2>/dev/null | head -1 || true)
    if [ -n "$LATEST_PLAN" ] && [ -f "$LATEST_PLAN" ]; then
      PLAN_PATH="${LATEST_PLAN#"$REPO_ROOT"/}"
      PLAN_TEXT=$(truncate_str "$(cat "$LATEST_PLAN")" 60000)
      break
    fi
  fi
done

PROJECT_CLAUDE_TEXT=""
if [ -z "$SPEC_TEXT" ] && [ -f "$REPO_ROOT/CLAUDE.md" ]; then
  PROJECT_CLAUDE_TEXT=$(truncate_str "$(head -600 "$REPO_ROOT/CLAUDE.md")" 20000)
fi

SPEC_CTX="spec:$SPEC_PATH"
[ "$SPEC_TRUNCATED" -eq 1 ]        && SPEC_CTX="spec:$SPEC_PATH(TRUNCATED:${#SPEC_FULL}->${SPEC_BUDGET}ch)"

CTX_PARTS=()
[ -n "$SPEC_TEXT" ]                && CTX_PARTS+=("$SPEC_CTX")
[ ${#RELATED_LOADED[@]} -gt 0 ]    && CTX_PARTS+=("related:${#RELATED_LOADED[@]}files")
[ -n "$EXTRA_CONTEXT" ]            && CTX_PARTS+=("user")
[ -n "$COMMITS_TEXT" ]             && CTX_PARTS+=("commits")
[ -n "$PLAN_TEXT" ]                && CTX_PARTS+=("plan:$PLAN_PATH")
[ -n "$PROJECT_CLAUDE_TEXT" ]      && CTX_PARTS+=("CLAUDE.md")
CTX_SUMMARY=$(IFS=,; echo "${CTX_PARTS[*]:-none}")

DIFF_LINES=$(echo "$DIFF" | wc -l)
echo "[claude-review] fable-5 (max effort) — $DIFF_LINES diff lines, iter #$ITERATION, scope: $SCOPE, context: $CTX_SUMMARY" >&2

render_context() {
  local has_spec=0
  if [ -n "$SPEC_TEXT" ]; then
    has_spec=1
    echo "### Review spec ($SPEC_SCOPE) — AUTHORITATIVE"
    echo ""
    echo "**This is the contract for this review.** Treat it as authoritative."
    echo ""
    echo "Source file: \`$SPEC_PATH\`"
    echo ""; echo "---"; echo ""; echo "$SPEC_TEXT"; echo ""; echo "---"; echo ""
    if [ "$SPEC_TRUNCATED" -eq 1 ]; then
      echo "**SPEC TRUNCATED:** only the first $SPEC_BUDGET of ${#SPEC_FULL} chars are shown above. The FULL spec is at \`$SPEC_ABS\` — Read it in full before reviewing."
      echo ""
    fi
  fi
  if [ -n "$RELATED_CODE_TEXT" ]; then
    echo "### Related code (context only — NOT under review)"
    echo ""
    echo "Files loaded: ${RELATED_LOADED[*]}"
    if [ ${#RELATED_SKIPPED[@]} -gt 0 ]; then
      echo ""; echo "Files skipped: ${RELATED_SKIPPED[*]}"
    fi
    echo ""; echo "$RELATED_CODE_TEXT"; echo "---"; echo ""
  fi
  if [ -n "$EXTRA_CONTEXT" ]; then
    if [ $has_spec -eq 1 ]; then echo "### Additional user-provided context"
    else echo "### User-provided context"; fi
    echo ""; echo "$EXTRA_CONTEXT"; echo ""
  fi
  if [ $has_spec -eq 0 ]; then
    [ -n "$COMMITS_TEXT" ] && { echo "### Commits on this branch"; echo ""; echo "$COMMITS_TEXT"; echo ""; }
    [ -n "$PLAN_TEXT" ]     && { echo "### Implementation plan ($PLAN_PATH)"; echo ""; echo "$PLAN_TEXT"; echo ""; }
    [ -n "$PROJECT_CLAUDE_TEXT" ] && { echo "### Project CLAUDE.md (top section)"; echo ""; echo "$PROJECT_CLAUDE_TEXT"; echo ""; }
  else
    [ -n "$COMMITS_TEXT" ] && { echo "### Commits on this branch (for cross-reference)"; echo ""; echo "$COMMITS_TEXT" | head -40; echo ""; }
  fi

  # Trailing if also guarantees render_context returns 0 even when the
  # bare [ -n ] && { } lines above evaluated false under set -e.
  if [ $has_spec -eq 0 ] && [ -z "$EXTRA_CONTEXT" ] && [ -z "$COMMITS_TEXT" ] && [ -z "$PLAN_TEXT" ] && [ -z "$PROJECT_CLAUDE_TEXT" ]; then
    echo "### Context"
    echo ""
    echo "(no review spec, plan files, or commit context available; review purely on the diff's own merits.)"
    echo ""
  fi
}

CONTEXT_BLOCK=$(render_context)

if [ -n "$SPEC_TEXT" ]; then
  INTRO_TEXT="A review spec exists for this branch. **The spec is the contract.** Verify against Requirements, respect Deliberate design choices and Non-goals, attend to Focus areas, and read Related code as authoritative extended context. Spec violations take priority."
else
  INTRO_TEXT="No formal review spec. Use the context below to understand intent. Distinguish deliberate design choices from accidental bugs."
fi

DIFF_FENCE=$(backtick_fence "$DIFF")

FULL_INPUT=$(
  cat "$PROMPT_FILE"
  echo ""; echo "---"; echo ""
  echo "## Context for this review"
  echo ""; echo "$INTRO_TEXT"; echo ""
  echo "$CONTEXT_BLOCK"
  echo "---"; echo ""
  echo "**Review iteration:** #$ITERATION"
  echo "**Scope:** $SCOPE"
  echo ""; echo "**Diff to review:**"; echo ""
  echo "${DIFF_FENCE}diff"; echo "$DIFF"; echo "$DIFF_FENCE"
)

# The bundle is piped via stdin: passing it as a single argv hits the kernel's
# 128 KiB per-argument limit (MAX_ARG_STRLEN) and fails exactly on large diffs.
CLAUDE_ERR=$(mktemp)
if ! REVIEW_OUTPUT=$(echo "$FULL_INPUT" | claude -p \
      --bare \
      --model claude-fable-5 \
      --effort max \
      --allowedTools "Read,Grep,Glob" \
      --dangerously-skip-permissions \
      --output-format text \
      2>"$CLAUDE_ERR"); then
  echo "STATUS: ERROR"
  echo "SUMMARY: claude headless call failed."
  if [ -s "$CLAUDE_ERR" ]; then
    echo ""
    echo "Reviewer stderr (tail):"
    tail -20 "$CLAUDE_ERR"
  fi
  rm -f "$CLAUDE_ERR"
  exit 1
fi
rm -f "$CLAUDE_ERR"

echo "$REVIEW_OUTPUT"
