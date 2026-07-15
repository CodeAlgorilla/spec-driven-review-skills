---
name: codex-review
description: Drives spec-driven code review using OpenAI Codex (gpt-5.6-sol, max) as external reviewer. Phase A scaffolds and auto-fills review spec (including auto-exploring the codebase for Related code) after writing-plans completes. Phase B runs review loop with spec + Related code + read-only shell exploration. Use PROACTIVELY at TWO points: (1) right after `superpowers:writing-plans`, OR when user starts implementing on a branch with no spec — draft spec including auto-discovered Related code, user confirms before coding; (2) when user explicitly requests review or signals merge prep. Trigger phrases (Phase B) are narrow and explicit — "codex review", "run codex review", "before I commit", "before I MR", "before I PR", "before merging". Does NOT auto-trigger on generic "I'm done" / "let's review" — those are too ambiguous. Also use when user explicitly asks ("scaffold review spec", "init review spec"). CRITICAL: after review returns CLEAN, STOP — do NOT auto-commit, auto-merge, or chain to `finishing-a-development-branch`. The user owns the merge decision.

---

# Spec-Driven Code Review (with auto-explored Related code)

Four-stage workflow with two proactive intervention points:

```
1. PLAN          → Superpowers' brainstorming + writing-plans
2. SPEC          ← AUTO HERE: scaffold + draft spec, EXPLORE for Related code,
                              show user, wait for confirmation
3. IMPLEMENT     → Superpowers' subagent-driven development
4. REVIEW        ← AUTO HERE on EXPLICIT request only — loop with spec + Related code,
                  HARD STOP after CLEAN
```

## v1.5 — Narrowed triggers + auto-explored Related code

Two changes from v1.4:

1. **Phase B triggers narrowed** — only explicit review/merge phrases fire the loop. "I'm done" / "let's review" / "wrap up the branch" are too ambiguous and have been removed. See "Phase B triggers" below.

2. **Phase A auto-explores for Related code** — Claude now scans the codebase during spec drafting to find callers, type users, and interface implementers, and auto-fills the `Related code` section. User reviews the populated spec before coding begins.

## Phase A — Stage 2: Proactive spec scaffolding (with exploration)

### When to do this WITHOUT being asked

- `superpowers:writing-plans` just returned a plan
- User expresses intent to implement a feature, no `.claude/review-spec.md` exists
- User creates a feature branch and is about to code

### What to do

1. **Announce briefly**:
   > "Before we code, let me draft a review spec from the plan and explore the codebase for relevant context. ~60 seconds."

2. **Scaffold**:
   ```bash
   bash "$HOME/.claude/skills/codex-review/scripts/init-spec.sh"
   ```

3. **Fill from the plan** (Purpose, Requirements, Deliberate design choices, Non-goals, Focus areas, Notes). No `<placeholder>` text remaining — write "None for this branch." if a section is empty.

4. **EXPLORE for Related code** (NEW in v1.5 — do this WITHOUT asking the user). Run the following exploration silently, then auto-populate `## Related code`:

   **a) Identify search targets** from the plan:
   - Functions/methods being added or modified
   - Classes/structs being changed
   - Public APIs being changed
   - Modules/files being significantly altered

   **b) For each target, run targeted searches**. Reach for these tools in order:
   - `Grep` for the symbol name → finds callers and references
   - `Grep` for inheritance/implements patterns when targets are interfaces
   - `Glob` for sibling files in the same module/directory
   - `Read` (just enough of each candidate) to filter out irrelevant matches

   **c) Filter candidates** to the most relevant 3–7:
   - **Include**: callers of changed functions, files defining used types, sibling modules with shared conventions, runtime config affecting behavior
   - **Exclude**: test files (covered by unit tests separately), files in the diff (redundant), unrelated namespaces, vendored / generated code
   - When in doubt about a candidate, **lean towards including** — false positives waste a little reviewer budget; false negatives miss bugs

   **d) Auto-populate the spec**. Edit `.claude/review-spec.md` and replace the placeholder bullets under `## Related code` with the discovered files. Add a brief inline comment per file explaining WHY:

   ```markdown
   ## Related code

   - `src/main_loop.py`            # calls solve_ik() — needs to handle new return shape
   - `include/kinematics_types.h`  # defines the result struct
   - `src/safety_layer.py`         # validates inputs before calling solver
   ```

   **e) Exploration budget**: spend at most ~60 seconds and ~10 search/read calls. If after that you have no clear candidates, write:

   ```markdown
   ## Related code

   None — diff is self-contained based on exploration.
   ```

5. **Present and ask once**:
   > "Spec drafted. I explored the codebase and added these Related code files:
   > - `src/main_loop.py` (caller)
   > - `include/kinematics_types.h` (type definitions)
   > - `src/safety_layer.py` (input validation)
   >
   > Spec ready to inspect. Does it look right? I'll start coding once you confirm — or tell me what to adjust."

6. **Wait for confirmation** before making non-spec file edits. User can:
   - Confirm ("looks good", "yes", "go") → proceed to implementation
   - Adjust ("drop safety_layer.py from Related code", "add `config/joints.yaml` to Related code", etc.) → make the change and re-confirm
   - Skip Phase A entirely ("just code") → drop the spec, proceed

### When to skip Phase A entirely

Skip if ANY apply:
- User says "skip the spec" / "no spec" / "just code" / "quick hack"
- Change is < 30 lines
- Doc-only / config-only / rename-only
- `.claude/review-spec.md` exists and matches feature
- Exploratory mode ("let me try something")
- User is on default branch

When skipping, say "Skipping spec for this one." Don't argue.

### When to skip the EXPLORATION (but still draft spec)

Skip just the exploration step (4) and write "None — please add manually if needed" under Related code if:
- User says "skip the exploration" / "no exploration" / "I'll list Related code myself"
- Diff is purely about adding new isolated code (no callers exist yet)
- Plan is so brief there's nothing concrete to search for

## Phase B — Stage 4: The review loop

### Trigger phrases (NARROW — explicit only as of v1.5)

Trigger Phase B ONLY when the user says one of these:

- "codex review" / "run codex review"
- "before I commit" / "before I MR" / "before I PR"
- "before merging"

**Do NOT trigger** on these (removed in v1.5 — too ambiguous):
- ~~"I'm done", "we're done", "feature is done", "the dev is done", "this is done"~~
- ~~"let's review", "review this", "run review", "external review"~~
- ~~"wrap up the branch", "finalize", "finish the work"~~

If the user uses an ambiguous phrase like "I'm done", **do NOT trigger automatically**. Instead, briefly acknowledge ("Got it — let me know when you want to commit, open an MR, or run codex review.") and wait.

### Pre-flight

1. `command -v codex` succeeds
2. `git rev-parse --is-inside-work-tree` succeeds

### Step 1: Run the review

```bash
bash "$HOME/.claude/skills/codex-review/scripts/run_review.sh" 1
```

The script:
1. Verifies codex + non-empty diff
2. Auto-detects scope
3. Loads spec from `.claude/review-spec.md`
4. Parses Related code section, reads each listed file in full
5. Calls `codex exec --sandbox read-only -m gpt-5.6-sol -c model_reasoning_effort=max`
6. Returns verdict

Stderr summary:
```
[codex-review] gpt-5.6-sol (max) — 102 diff lines, iter #1,
  scope: feature branch '...' vs main,
  context: spec:.claude/review-spec.md,related:3files,commits
```

### Step 2: Read the verdict

`STATUS: CLEAN` → Step 4. `ISSUES_FOUND` → Step 3. `ERROR` → report and stop.

### Step 3: Fix and re-loop

- `[CRITICAL]` always fix (includes spec violations)
- `[HIGH]` always fix
- `[MEDIUM]` fix if small + clearly correct
- `[LOW]` don't auto-fix

Findings may include "Checked path/to/file.py:42 to verify X" — reviewer's exploration. Trust same as bundle findings.

Re-run with `2`, `3`. Cap at 3.

### Step 4: Final summary and HARD STOP

```
Codex review loop complete (N iteration(s)).

Spec used: <path>
Related code loaded: <N files or "none">
Context loaded: <stderr summary content>

Iteration 1: <one-line>
...

Remaining LOW-severity items: <list or "none">
Disagreements: <list or omit>

Status: <CLEAN or "Issues remain at iteration 3 cap">

Your move. Tell me if you want to commit, open an MR, make more changes, or anything else.
```

### Hard stop after CLEAN

Do NOT:
- Invoke `superpowers:finishing-a-development-branch`
- Run `git commit`, `git push`, `git merge`
- Open a PR/MR
- Clean up the worktree
- Suggest "next step is to merge" as automatic

Only proceed when explicitly asked.

### Bypass conditions for Phase B

- "skip codex review", "no review", "just commit"
- Diff < 10 lines, doc-only / config-only
- Previous CLEAN in same session, diff unchanged

## When NOT to use this skill

- Trivial diffs (< 10 lines)
- Pure docs / config changes
- Mid-plan (between Superpowers tasks)
- codex unavailable

## Tweaking

- **Spec template**: `~/.claude/skills/codex-review/templates/review-spec.template.md`
- **Reviewer behavior**: `~/.claude/skills/codex-review/references/reviewer_prompt.md`
- **Model / effort**: `~/.claude/skills/codex-review/scripts/run_review.sh`
- **Trigger phrases (narrow → wider, or wider → narrower)**: `~/.claude/CLAUDE.md` (the `codex-review-policy` block)
- **Exploration depth in Phase A**: edit "Exploration budget" in this file
