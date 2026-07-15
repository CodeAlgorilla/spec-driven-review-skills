# Changelog

All notable changes to both skills in this repo.

The two skills evolve in parallel and version independently. This file consolidates both histories.

---

## [Unreleased]

Nothing yet.

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
