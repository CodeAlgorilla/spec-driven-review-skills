# codex-review (v1.5.0)

Spec-driven code review using OpenAI Codex (gpt-5.6-sol, max reasoning). Phase A auto-explores codebase for Related code; Phase B runs review loop with hard-stop.

## What's new in v1.5.0

### 1. Phase A auto-explores Related code

When you scaffold the spec (after `writing-plans` finishes), Claude:
- Identifies functions/classes/types being changed (from the plan)
- Runs Grep/Glob/Read to find callers, type definitions, sibling modules
- **Auto-fills the `Related code` section** of the spec
- Shows you the populated spec to confirm before coding begins

Budget: ~60 seconds, ~10 search/read calls. If no clear candidates found, writes "None — diff is self-contained based on exploration."

### 2. Phase B triggers narrowed

The review loop now fires ONLY on these explicit phrases:

- `"codex review"` / `"run codex review"`
- `"before I commit"` / `"before I MR"` / `"before I PR"`
- `"before merging"`

**Removed** (too ambiguous, were causing accidental triggers):
- ~~"I'm done", "we're done", "feature is done", "the dev is done", "this is done"~~
- ~~"let's review", "review this", "run review", "external review"~~
- ~~"wrap up the branch", "finalize", "finish the work"~~

When you say one of the removed phrases, Claude now acknowledges without firing — e.g. "Got it. Tell me when you want to commit, open an MR, or run codex review."

## Quick install

```bash
npm install -g @openai/codex   # if needed
codex login

bash install.sh
```

Upgrades from v1.0–v1.4 — idempotent, user content preserved.

## Workflow

```
1. Brainstorm + plan          (Superpowers)
2. Spec scaffold              ← Claude proactively drafts spec + EXPLORES codebase
   You: "looks good"          ← confirm the populated spec
3. Implementation             (Superpowers)
4. "run codex review" / "before I MR"   ← explicit trigger fires Phase B
5. Review CLEAN
6. Your decision              ← HARD STOP — "commit it" / "open MR" / etc.
```

## Quick reference

| Phase | Triggers | Action |
|---|---|---|
| Phase A | After plan; "set up review spec" | Scaffold + explore + populate spec |
| Phase B | "codex review", "before I MR/PR/commit", "before merging" | Run review loop |
| Bypass | "skip codex review", "skip the spec", "just code/commit" | Skip |

See SKILL.md for full details.

## Customization

- Spec template: `~/.claude/skills/codex-review/templates/review-spec.template.md`
- Reviewer behavior: `~/.claude/skills/codex-review/references/reviewer_prompt.md`
- Model / effort: `~/.claude/skills/codex-review/scripts/run_review.sh`
- Triggers / bypass: `~/.claude/CLAUDE.md` (`codex-review-policy` block)
- Exploration budget: edit "Exploration budget" in `~/.claude/skills/codex-review/SKILL.md`
- Spec inline budget: 60000 chars by default; set `CODEX_REVIEW_SPEC_BUDGET` to override. Longer specs are embedded truncated (flagged on stderr) and the reviewer is told to read the full spec file itself.

## Changelog

### v1.5.0
- Phase A auto-explores codebase for Related code (Grep/Glob/Read)
- Phase B triggers narrowed to explicit review/merge intent only
- Ambiguous phrases now get a no-op acknowledgment

### v1.4.0
- Related code section + reviewer exploration

### v1.3.0
- Proactive spec scaffolding after plan

### v1.2.0
- Spec-driven contract

### v1.1.0 / v1.0.0
- Initial + context-aware

## Uninstall

```bash
bash install.sh uninstall
```

Per-project specs preserved. claude-review NOT affected.

## License

MIT
