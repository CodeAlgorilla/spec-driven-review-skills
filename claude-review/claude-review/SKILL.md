---
name: claude-review
description: Iterative code review using Claude Code in headless mode (claude -p, opus-4-8, max effort) as a FRESH external reviewer with no conversation history. Phase A scaffolds the spec and AUTO-EXPLORES the codebase for Related code (callers, types, sibling modules) before showing to user. Phase B runs review loop with spec + Related code + Read/Grep/Glob exploration tools. Use only on explicit triggers — "claude review", "claude review this", "fresh review", "fresh eyes", "fresh eyes review", "another review with claude", "review with a fresh claude". Spec setup triggers: "set up claude review spec", "init claude review spec", "scaffold claude review spec". Does NOT auto-trigger on generic completion phrases — those belong to codex-review. Coexists with codex-review (separate spec files). CRITICAL: after review returns CLEAN, STOP — do NOT auto-commit, auto-merge, or chain to `finishing-a-development-branch`.

---

# Claude Cross-Invocation Code Review Loop (with auto-explored Related code)

A fresh `claude -p` invocation (Opus 4.8, max effort, bare mode) reviews the diff with no conversation history and no project context bleed. Main session is the implementer.

Direct mirror of codex-review's architecture, different engine.

## v2.2 — Auto-explored Related code in Phase A

When you scaffold the claude-review spec, Claude now explores the codebase to find callers, type users, sibling modules, and auto-fills the `Related code` section. You review the spec before coding starts.

## Phase A — Set up the claude-review spec (with exploration)

### Triggers (explicit only)

- "set up claude review spec" / "init claude review spec" / "scaffold claude review spec"
- "create a claude-review spec" / "make a claude review spec"

### What to do

1. **Announce briefly**:
   > "Setting up the claude-review spec for this feature. I'll explore the codebase for relevant context. ~60 seconds."

2. **Scaffold**:
   ```bash
   bash "$HOME/.claude/skills/claude-review/scripts/init-spec.sh"
   ```

3. **Fill from plan/conversation** (Purpose, Requirements, Deliberate design choices, Non-goals, Focus areas, Notes). No `<placeholder>` text remaining.

4. **EXPLORE for Related code** (NEW in v2.2 — without asking user):

   **a) Identify search targets** from the plan or conversation:
   - Functions/methods being added or modified
   - Classes/structs being changed
   - Public APIs being changed

   **b) Run targeted searches**:
   - `Grep` for symbol names → finds callers and references
   - `Grep` for inheritance patterns when targets are interfaces
   - `Glob` for sibling files in the same module
   - `Read` enough of each candidate to filter relevance

   **c) Filter to 3–7 most relevant**:
   - **Include**: callers, type definitions, sibling modules with shared conventions, config affecting behavior
   - **Exclude**: test files, files in the diff, unrelated namespaces, vendored/generated code
   - When in doubt, lean towards inclusion

   **d) Auto-populate `## Related code`** with inline comments:

   ```markdown
   ## Related code

   - `src/main_loop.py`            # calls solve_ik() — needs to handle new return shape
   - `include/kinematics_types.h`  # defines the result struct
   ```

   **e) Budget**: ~60s, ~10 calls. If no clear candidates after that: write "None — diff is self-contained based on exploration."

5. **Present the populated spec** and ask once:
   > "Spec drafted. I explored and added these Related code files: [list]. Does it look right? I'll start coding once you confirm — or tell me what to adjust."

6. **Wait for confirmation** before non-spec edits.

If the user has a codex-review spec at `.claude/review-spec.md` already, offer to copy as starting point:
```bash
cp "$REPO_ROOT/.claude/review-spec.md" "$REPO_ROOT/.claude/review-spec-claude.md"
```
Then RE-EXPLORE for Related code (claude-review's spec may want different files than codex's).

For project-wide baselines:
```bash
bash "$HOME/.claude/skills/claude-review/scripts/init-spec.sh" --project
```

### Skip exploration (but keep spec) when

- "skip the exploration" / "I'll list Related code myself"
- Diff is purely additive (no callers exist)
- Plan too brief for concrete searches

## Phase B — Run the review loop

### Triggers (explicit only)

- "claude review" / "claude review this" / "another review with claude"
- "fresh review" / "fresh eyes" / "fresh eyes review"
- "review with a fresh claude"

**Does NOT auto-trigger** on generic completion phrases (those belong to codex-review).

### Pre-flight

1. `command -v claude` succeeds
2. `git rev-parse --is-inside-work-tree` succeeds

### Step 1: Run

```bash
bash "$HOME/.claude/skills/claude-review/scripts/run_review.sh" 1
```

The script reads spec + Related code, calls `claude -p --bare --model claude-opus-4-8 --effort max --allowedTools "Read,Grep,Glob"`.

Stderr summary:
```
[claude-review] opus-4-8 (max effort) — 102 diff lines, iter #1,
  scope: feature branch '...' vs main,
  context: spec:.claude/review-spec-claude.md,related:3files,commits
```

### Step 2: Read verdict

`STATUS: CLEAN` → Step 4. `ISSUES_FOUND` → Step 3.

### Step 3: Fix and loop

- `[CRITICAL]` always fix (spec violations included)
- `[HIGH]` always fix
- `[MEDIUM]` fix if small + clear
- `[LOW]` don't auto-fix

Findings may include "Checked path/to/file.py:42 to verify X" — trust same as bundle.

Re-run with `2`, `3`. Cap at 3.

### Step 4: Final summary and HARD STOP

```
Claude-review loop complete (N iteration(s), fresh `claude -p` per iteration).

Spec used: <path>
Related code loaded: <N or "none">
Context loaded: <stderr summary>

Iteration 1: <one-line>
...

Remaining LOW: <list or "none">
Disagreements: <list or omit>

Status: <CLEAN or "Issues remain at iteration 3 cap">

Your move. Tell me if you want to commit, open an MR, run codex-review for a second opinion, make more changes, or anything else.
```

### Hard stop after CLEAN

Do NOT auto-commit, auto-merge, chain to `finishing-a-development-branch`, open PR/MR, or run codex-review afterward.

## Coexistence with codex-review

- **codex-review**: `.claude/review-spec.md`, `codex exec` (gpt-5.5)
- **claude-review**: `.claude/review-spec-claude.md`, `claude -p` (Opus 4.8)

Both can run sequentially:
```
"I'm done"                       (no auto-trigger — see codex-review v1.5)
"run codex review"               → codex-review CLEAN
"now do a claude review too"     → claude-review CLEAN
"commit it"                      → user-initiated commit
```

## When NOT to use

- Trivial diffs (< 10 lines)
- Pure docs / config changes
- User said "skip claude review" or "no review"

## Tweaking

- Spec template: `~/.claude/skills/claude-review/templates/review-spec-claude.template.md`
- Reviewer behavior: `~/.claude/skills/claude-review/references/reviewer_prompt.md`
- Model / effort / allowed tools: `~/.claude/skills/claude-review/scripts/run_review.sh`
- Triggers / bypass: `~/.claude/CLAUDE.md` (`claude-review-policy` block)
- Exploration depth: edit "Budget" in this file
