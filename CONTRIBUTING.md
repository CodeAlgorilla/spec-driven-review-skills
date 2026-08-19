# Contributing

Thanks for considering a contribution.

## Ground rules

1. **Don't break the hard-stop.** The "stop after CLEAN, hand decision to user" semantics is core. PRs that auto-commit, auto-merge, auto-chain to `finishing-a-development-branch`, or otherwise erode this gate will be rejected.

2. **Keep the two skills mirrored.** Both should have the same external behavior unless there's a specific reason for divergence (e.g. `--allowedTools` is claude-only because codex uses `--sandbox read-only` instead). When you add a feature to one, the other usually needs the parallel update.

3. **Test before PR'ing.** Run `bash tests/test_run_review.sh` — it exercises both `run_review.sh` scripts against throwaway repos with shim reviewer binaries (no codex/claude CLI needed) and must report 0 failed. Then run `bash install.sh verify` on a clean machine. Test that:
   - Both `install.sh` and the sub-installers work
   - Idempotent re-install preserves user content
   - Uninstall is clean
   - Both skills can coexist

4. **Update docs.** If you change visible behavior, update:
   - The skill's `SKILL.md`
   - The skill's `CLAUDE_md_policy.md`
   - The skill's `README.md`
   - The top-level `README.md` comparison table (if affected)
   - `CHANGELOG.md`

## Local development

```bash
git clone <your-fork-url>
cd spec-driven-review-skills

# Smoke test
TMP_HOME=$(mktemp -d)
HOME=$TMP_HOME bash install.sh both
HOME=$TMP_HOME bash install.sh verify
HOME=$TMP_HOME bash install.sh uninstall
rm -rf "$TMP_HOME"
```

## Filing issues

Useful info to include:

- Which skill (codex-review or claude-review or both)
- Versions: `bash install.sh verify` shows them
- OS and shell
- Reviewer CLI version: `codex --version` or `claude --version`
- Steps to reproduce
- What you expected vs what happened
- Relevant snippet from `~/.claude/CLAUDE.md` (just the policy block)

## What's most welcome

- Bug fixes
- More precise reviewer prompts that reduce false positives
- Cross-platform testing (especially Windows / WSL)
- New trigger phrases that don't overlap with existing ones
- Better exploration heuristics for Phase A (e.g. language-aware AST instead of grep)
- Real-world stories: "Spec X with Related code Y caught a bug Z" — these inform future tuning

## What's less welcome

- Aggressive automation that removes human checkpoints
- Adding tool permissions to the reviewer beyond Read/Grep/Glob (or codex's read-only sandbox)
- Changes that make the two skills diverge in API or workflow
- Re-enabling security review as a default (project-specific opt-in is fine)
