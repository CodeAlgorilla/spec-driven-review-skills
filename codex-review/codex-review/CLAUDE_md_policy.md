<!-- codex-review-policy -->
## Spec-driven code review workflow (MANDATORY)

Four-stage workflow:

```
1. PLAN          → Superpowers' brainstorming + writing-plans
2. SPEC          → review spec drafted from the plan + auto-explored Related code
3. IMPLEMENT     → Superpowers' subagent-driven development
4. REVIEW        → codex-review loop with spec + Related code (EXPLICIT trigger)
```

Stage 2 is proactive. Stage 4 is on explicit user request only (v1.5 narrowed triggers).

### Stage 2 — Proactive spec scaffolding WITH auto-exploration

**Trigger:** After `superpowers:writing-plans` returns a plan, OR when user expresses intent to start implementing and no `.claude/review-spec.md` exists.

**Default behavior (do this without being asked):**

1. Announce: "Before we code, let me draft a review spec and explore for relevant context. ~60 seconds."

2. Scaffold:
   ```bash
   bash "$HOME/.claude/skills/codex-review/scripts/init-spec.sh"
   ```

3. **Fill from plan** — Purpose, Requirements, Deliberate design choices, Non-goals, Focus areas, Notes. No `<placeholder>` text left.

4. **EXPLORE for Related code** (new in v1.5 — do WITHOUT asking the user):
   - Identify search targets from plan (functions/types being changed)
   - Use Grep for symbol references, Glob for sibling files, Read to filter candidates
   - Filter to 3–7 relevant: callers, type defs, sibling modules, runtime config. Exclude tests and files in the diff.
   - Auto-populate `## Related code` section with brief inline comments per file ("# calls solve_ik — needs new return shape")
   - Budget: ~60 seconds, ~10 search/read calls
   - If no clear candidates after budget exhausted: write "None — diff is self-contained based on exploration."

5. Present the populated spec to the user and ask once:
   "Spec drafted with N Related code files auto-discovered. Does this look right? I'll start coding once you confirm — or tell me what to adjust."

6. **Wait for confirmation** before non-spec edits.

### Skip conditions for Stage 2

- "skip the spec" / "no spec" / "just code" / "quick hack"
- Change < 30 lines
- Doc-only / config-only / rename-only
- Spec already exists and matches feature
- Exploratory mode
- On default branch

### Skip ONLY the exploration (keep spec) when

- "skip the exploration" / "I'll list Related code myself"
- Diff is purely additive (no callers exist)
- Plan too brief for concrete searches

### Stage 4 — NARROW trigger phrases (v1.5)

Trigger Phase B ONLY on these (explicit review/merge intent):

- "codex review" / "run codex review"
- "before I commit" / "before I MR" / "before I PR"
- "before merging"

**Do NOT trigger** on these (too ambiguous, removed in v1.5):
- "I'm done", "we're done", "feature is done", "the dev is done", "this is done"
- "let's review", "review this", "run review", "external review"
- "wrap up the branch", "finalize", "finish the work"

When user says one of the removed phrases, acknowledge briefly without triggering: "Got it — let me know when you want to commit, open an MR, or run codex review."

### Stage 4 spec-related triggers (unchanged)

- "set up review spec", "init review spec", "scaffold review spec"
- "create a review-spec", "make a review spec"

### Hard stop after CLEAN

Do NOT auto-commit, auto-merge, chain to `finishing-a-development-branch`, open PR/MR, clean worktree, or suggest merge as automatic.

Handoff: "Review is clean (N iterations). Your call — commit, open an MR, make more changes, or anything else."

Only proceed when explicitly asked.

### Bypass review (Stage 4)

- "skip codex review", "no review", "just commit"
- Diff < 10 lines, doc/config-only
- Previous CLEAN in session, diff unchanged

### Per-task work

Do NOT invoke codex-review between Superpowers plan tasks. Internal `code-reviewer` handles per-task QA.

### Proactive but not pushy

User push-back → honor immediately. Don't suggest same path again in session.
<!-- /codex-review-policy -->
