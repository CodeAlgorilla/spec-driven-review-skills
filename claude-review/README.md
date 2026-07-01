# claude-review (v2.2.0)

Spec-driven cross-invocation code review using Claude Code CLI (`claude -p`, Opus 4.8, max effort). Phase A auto-explores codebase for Related code.

## What's new in v2.2.0

Phase A auto-explores the codebase to find Related code and populates the spec before showing it to you. Same mechanism as codex-review v1.5.

When you say "set up claude review spec", Claude:
- Scaffolds the template
- Fills Purpose/Requirements/etc from the plan
- **Explores the codebase** (Grep/Glob/Read) for callers, type definitions, sibling modules
- **Auto-populates the Related code section** with brief inline comments
- Shows the populated spec to you for confirmation

Budget: ~60 seconds, ~10 calls.

## Quick install

```bash
bash install.sh
```

Requires Claude Code CLI (`npm install -g @anthropic-ai/claude-code`, then `claude` interactively once).

Upgrades from v1.0–v2.1 idempotent. v1.0's `prepare_review.sh` is automatically cleaned up.

## Triggers (unchanged from v2.1)

| Phase | Triggers |
|---|---|
| Phase A | "set up claude review spec", "init claude review spec", "scaffold claude review spec" |
| Phase B | "claude review", "claude review this", "fresh review", "fresh eyes", "another review with claude", "review with a fresh claude", "run claude review" |
| Bypass | "skip claude review", "skip the exploration", "just commit" |

claude-review's triggers were already explicit — only codex-review's were narrowed in v1.5.

## How it works

```
You: "set up claude review spec"
                                                 ↓
                  Claude scaffolds + EXPLORES codebase
                                                 ↓
                  shows populated spec
                                                 ↓
                  You: "looks good" or adjustments
                                                 ↓
                  Implementation
                                                 ↓
You: "claude review"
                                                 ↓
                  bash run_review.sh 1
                                                 ↓
                  claude -p --bare --model claude-opus-4-8 --effort max \
                    --allowedTools "Read,Grep,Glob" \
                    --dangerously-skip-permissions
                                                 ↓
                  CLEAN / ISSUES_FOUND
                                                 ↓
                  loop until CLEAN or iter 3
                                                 ↓
                  "Your move."
```

## Coexistence with codex-review

Both can be installed and used:
- **codex-review** (`.claude/review-spec.md`) — fires only on "codex review" / "before I MR/PR" etc. (v1.5)
- **claude-review** (`.claude/review-spec-claude.md`) — fires only on "claude review" / "fresh review" etc.

Both auto-explore for Related code in Phase A. Lists can differ if you want different focus per reviewer.

## Customization

- Spec template: `~/.claude/skills/claude-review/templates/review-spec-claude.template.md`
- Reviewer behavior: `~/.claude/skills/claude-review/references/reviewer_prompt.md`
- Model / effort / allowed tools: `~/.claude/skills/claude-review/scripts/run_review.sh`
- Triggers / bypass: `~/.claude/CLAUDE.md` (`claude-review-policy` block)
- Exploration budget: edit `~/.claude/skills/claude-review/SKILL.md`

## Changelog

### v2.2.0
- Phase A auto-explores codebase for Related code (Grep/Glob/Read)

### v2.1.0
- Related code section + reviewer exploration

### v2.0.0
- Direct CLI mirror of codex-review

### v1.0.0
- Initial (Task-tool subagent)

## Uninstall

```bash
bash install.sh uninstall
```

Per-project specs preserved. codex-review NOT affected.

## License

MIT
