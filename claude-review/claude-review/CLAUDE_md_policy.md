<!-- claude-review-policy -->
## Claude-review skill (fresh `claude -p` reviewer + auto-explored Related code)

Fresh `claude -p` (Opus 4.8, max effort, bare) as reviewer. Coexists with codex-review, separate spec file. v2.2 adds auto-exploration of Related code during Phase A.

### Phase A — Setup spec with auto-exploration

**Triggers (explicit only):**
- "set up claude review spec" / "init claude review spec" / "scaffold claude review spec"
- "create a claude-review spec" / "make a claude review spec"

**What to do:**

1. Announce: "Setting up the claude-review spec for this feature. I'll explore the codebase for relevant context. ~60 seconds."

2. Scaffold via `bash $HOME/.claude/skills/claude-review/scripts/init-spec.sh`

3. Fill from plan/conversation (Purpose, Requirements, Deliberate, Non-goals, Focus areas, Notes). No `<placeholder>` text.

4. **EXPLORE for Related code** (without asking):
   - Identify targets from plan (functions/types being changed)
   - Use Grep / Glob / Read for callers, type defs, sibling modules, runtime config
   - Filter to 3–7 relevant. Exclude tests, files-in-diff, unrelated namespaces
   - Auto-populate `## Related code` with inline `# why this file` comments
   - Budget: ~60s, ~10 calls
   - No clear candidates → "None — diff is self-contained based on exploration."

5. Present populated spec and ask once: "Spec drafted. I explored and added these Related code files: [list]. Does it look right?"

6. Wait for confirmation before non-spec edits.

### Skip exploration (keep spec) when

- "skip the exploration" / "I'll list Related code myself"
- Diff is purely additive
- Plan too brief

### Phase B — Distinct trigger phrases (explicit only)

- "claude review" / "claude review this" / "claude review the branch"
- "fresh review" / "fresh eyes" / "fresh eyes review"
- "another review with claude" / "review with a fresh claude"
- "run claude review"

### Do NOT auto-trigger on generic phrases

"I'm done", "let's review" → don't fire claude-review. The narrowed codex-review v1.5 also doesn't fire on these — for the ambiguous phrases, just acknowledge: "Got it. Tell me when you want to commit, open an MR, or run a review."

If user says generic phrase AND codex-review is unavailable, may suggest: "codex isn't available — want me to run claude-review instead?"

### Spec separation

- `codex-review` reads `.claude/review-spec.md` and `.codex-review/spec.md`
- `claude-review` reads `.claude/review-spec-claude.md` and `.claude-review/spec.md`

### Hard stop after CLEAN

Do NOT auto-commit, auto-push, auto-merge, chain to `finishing-a-development-branch`, open PR/MR, or run codex-review afterward (unless user explicitly asks).

### Bypass

- "skip claude review", "no claude review", "just commit"
- Diff trivial (< 10 lines, doc-only, config-only)
- Previous CLEAN in session, diff unchanged
<!-- /claude-review-policy -->
