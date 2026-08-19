# Changelog

All notable changes to both skills in this repo.

The two skills evolve in parallel and version independently. This file consolidates both histories.

---

## [Unreleased]

Both skills (`run_review.sh`), mirrored:

- **Fixed**: `## Related code` is now parsed from the full spec file, not the truncated embed. Previously a spec longer than the inline budget silently dropped (or corrupted) the Related-code file list, since that section sits near the end of the template.
- **Changed**: spec inline budget raised 12000 → 60000 chars, overridable via `CODEX_REVIEW_SPEC_BUDGET` / `CLAUDE_REVIEW_SPEC_BUDGET` (values are read as base-10; non-numeric or >9-digit values fall back to the default).
- **Changed**: context budgets raised (ported from a live hot-patch of the installed codex-review script, 2026-08-07): Related code 40000 total / 8000 per-file → 400000 / 60000 chars; commits 4000 → 60000; plan 6000 → 60000; project CLAUDE.md excerpt `head -200`/4000 → `head -600`/20000.
- **Added**: when a spec still exceeds the budget, the bundle carries a `**SPEC TRUNCATED:**` note with the absolute spec path telling the reviewer to read the full file (codex: read-only shell; claude: Read tool).
- **Added**: the stderr status line marks truncation, e.g. `spec:.claude/review-spec.md(TRUNCATED:70000->60000ch)`, so the orchestrator sees it at launch time.

---

## codex-review

### [1.5.0] — 2026-06-05

**Phase A auto-exploration + narrowed Phase B triggers.**

- **Added**: Phase A now auto-explores the codebase (Grep/Glob/Read) during spec scaffolding and auto-fills the `Related code` section. Budget: ~60s, ~10 calls.
- **Changed**: Phase B trigger phrases narrowed to explicit review/merge intent only:
  - **Kept**: `"codex review"`, `"run codex review"`, `"before I commit"`, `"before I MR"`, `"before I PR"`, `"before merging"`
  - **Removed**: `"I'm done"`, `"we're done"`, `"feature is done"`, `"the dev is done"`, `"this is done"`, `"let's review"`, `"review this"`, `"run review"`, `"external review"`, `"wrap up the branch"`, `"finalize"`, `"finish the work"`
- **Changed**: Ambiguous "completion" phrases now get a no-op acknowledgment instead of triggering the review loop.

### [1.4.0] — earlier

- **Added**: `Related code` section in spec; listed files read in full and embedded.
- **Added**: Reviewer may use read-only shell (cat/grep/find) for narrow exploration.

### [1.3.0]

- **Added**: Proactive spec scaffolding after `writing-plans`.
- **Added**: Auto-trigger of review loop on completion signals (now narrowed in v1.5).

### [1.2.0]

- **Added**: Spec-driven contract via `.claude/review-spec.md`.
- **Added**: `init-spec.sh` scaffolder.
- **Added**: "Spec violation" as CRITICAL category.

### [1.1.0]

- **Added**: Reviewer sees commits, plan, project CLAUDE.md, `--context` flag.

### [1.0.0]

- Initial release: gpt-5.6-sol + max, auto-detect scope, hard-stop policy, Superpowers integration.

---

## claude-review

### [2.2.0] — 2026-06-05

- **Added**: Phase A auto-explores codebase for Related code, mirroring codex-review v1.5's behavior.
- Triggers unchanged (claude-review was already explicit-only).

### [2.1.0] — earlier

- **Added**: `Related code` section in spec; reviewer gets Read/Grep/Glob tools for exploration.

### [2.0.0]

- **Changed**: Direct CLI mirror of codex-review architecture. Calls `claude -p` directly (removed Task-tool dispatch).
- **Removed**: v1.0's `prepare_review.sh` (cleaned up by installer on upgrade).

### [1.0.0]

- Initial release: Task-tool subagent reviewer.

---

## Conventions

- Both skills follow semver: MAJOR.MINOR.PATCH.
- Architecture changes (e.g. moving from subagent to `claude -p`) trigger a MAJOR bump.
- New features (e.g. Related code, auto-exploration) trigger a MINOR bump.
- Bug fixes and documentation-only changes trigger a PATCH bump.
- Cross-skill coordination: when both skills get a parallel feature, they're released together with the same date and a note here.
