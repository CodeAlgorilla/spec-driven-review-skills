# spec-driven-review-skills

> Two Claude Code skills for **spec-driven, cross-engine code review** with auto-explored Related code and a hard-stop after CLEAN.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![codex-review](https://img.shields.io/badge/codex--review-v1.5.0-blueviolet)](codex-review/)
[![claude-review](https://img.shields.io/badge/claude--review-v2.2.0-blueviolet)](claude-review/)
[![Shell](https://img.shields.io/badge/shell-bash-89e051)](#)
[![Status](https://img.shields.io/badge/status-active-success.svg)](#)

A pair of Claude Code skills that turn "finished feature → reviewed feature → committed feature" into an explicit, spec-driven loop. Two engines are supported and coexist:

- **codex-review** routes review through OpenAI Codex (gpt-5.6-sol, max reasoning)
- **claude-review** routes review through a fresh `claude -p` invocation (Fable 5, max effort)

Each skill writes its own spec, has its own trigger phrases, and ends with a hard stop so the merge decision stays human.

---

## Table of contents

- [Why this exists](#why-this-exists)
- [Architecture](#architecture)
- [Quick install](#quick-install)
- [Workflow walkthrough](#workflow-walkthrough)
- [Skill comparison](#skill-comparison)
- [Spec anatomy](#spec-anatomy)
- [Trigger phrases](#trigger-phrases)
- [Auto-explored Related code](#auto-explored-related-code)
- [Customization](#customization)
- [Uninstall](#uninstall)
- [Project layout](#project-layout)
- [Contributing](#contributing)
- [License](#license)

---

## Why this exists

Three observations drive the design:

1. **Self-review has blind spots.** Same-model review misses bugs the same model just made. Cross-engine review (`gpt-5.6-sol` reviewing Claude's code, or fresh `claude -p` reviewing a main session's code) catches a meaningfully different class of issues.

2. **Reviewers without context produce false positives.** "You changed `solve_ik()`'s return shape" is only a bug if the caller cares. Without seeing the caller, the reviewer either misses the bug or flags every change as suspicious.

3. **Auto-merge is the wrong default.** Code review is a decision point. The pipeline drives the work but stops at the merge — the human owns that gate.

These skills encode all three: spec as authoritative contract, auto-explored Related code, and a hard stop after CLEAN.

---

## Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                 Phase A — Spec setup (proactive)                │
│                                                                  │
│   Plan ─→ Scaffold ─→ EXPLORE codebase ─→ Auto-fill spec        │
│           template     (Grep / Glob /      with Related code     │
│                         Read, ~60 sec)     section populated     │
│                                                                  │
│                                ↓                                 │
│                       Show spec to user                          │
│                                ↓                                 │
│                       User confirms or edits                     │
└────────────────────────────────────────────────────────────────┘
                                ↓
                    Implementation (Superpowers)
                                ↓
┌────────────────────────────────────────────────────────────────┐
│              Phase B — Review loop (explicit trigger)            │
│                                                                  │
│      Spec + Related code + diff + commits  ─→ Bundle             │
│                                ↓                                 │
│      ┌──────────────────┐   OR   ┌──────────────────┐           │
│      │   codex-review   │        │  claude-review   │           │
│      │                  │        │                  │           │
│      │   codex exec     │        │   claude -p      │           │
│      │   gpt-5.6-sol    │        │   Fable 5        │           │
│      │   max effort     │        │   max effort     │           │
│      │   --sandbox ro   │        │   --bare         │           │
│      │                  │        │   --allowedTools │           │
│      │                  │        │     Read/Grep/   │           │
│      │                  │        │     Glob         │           │
│      └────────┬─────────┘        └────────┬─────────┘           │
│               │                            │                     │
│               └────── STATUS: CLEAN ───────┘                     │
│                      or ISSUES_FOUND → fix → re-loop             │
│                      (max 3 iterations)                          │
└────────────────────────────────────────────────────────────────┘
                                ↓
┌────────────────────────────────────────────────────────────────┐
│                  HARD STOP — User decides                        │
│         commit / open MR / continue / abandon — your call        │
└────────────────────────────────────────────────────────────────┘
```

---

## Quick install

```bash
git clone https://github.com/CodeAlgorilla/spec-driven-review-skills.git
cd spec-driven-review-skills
bash install.sh
```

You'll be asked which skill(s) to install:

```
Two skills are available:

  1 codex-review   — uses OpenAI Codex (gpt-5.6-sol, max)
  2 claude-review  — uses Claude Code (Fable 5, max effort)
  3 Both           — recommended (they coexist + complement)
  0 Exit
```

Non-interactive:

```bash
bash install.sh both       # install both
bash install.sh codex      # install only codex-review
bash install.sh claude     # install only claude-review
bash install.sh verify     # verify whichever is installed
bash install.sh uninstall  # remove whichever is installed
```

Or install a single skill directly from its subdirectory:

```bash
bash codex-review/install.sh
bash claude-review/install.sh
```

### Prerequisites

- **bash** (macOS/Linux)
- **git**
- **codex-review**: [OpenAI Codex CLI](https://github.com/openai/codex) → `npm install -g @openai/codex` + `codex login`
- **claude-review**: [Claude Code CLI](https://docs.claude.com/claude-code) → `npm install -g @anthropic-ai/claude-code` + run `claude` once to authenticate

Restart your Claude Code session after installing so the new CLAUDE.md policy is picked up.

---

## Workflow walkthrough

```text
You:   "let's build feature X"

Claude:  brainstorming + writing-plans  (Superpowers)
         ↓
         "Drafting review spec + exploring codebase. ~60 sec."
         ↓
         scaffolds .claude/review-spec.md
         fills Purpose, Requirements, Deliberate, Non-goals, Focus
         ↓
         GREPS for symbols, GLOBS sibling files, READS to filter
         auto-populates Related code:
            - src/main_loop.py      # calls solve_ik() — needs new shape
            - include/types.h       # defines result struct
         ↓
         "Spec drafted with 2 Related code files. Look right?"

You:     "looks good"  (or "drop X, add Y")

Claude:  Implementation via Superpowers' subagent-driven flow
         per-task reviews handled by Superpowers' internal reviewer
         ...
         done coding

You:     "I'm done with the feature"  ← AMBIGUOUS

Claude:  "Got it. Tell me when you want to commit, open an MR,
          or run codex review."   ← acknowledged, no fire

You:     "run codex review"  ← EXPLICIT trigger

Claude:  bash run_review.sh 1
         loads spec + Related code + diff + commits
         ↓
         codex exec gpt-5.6-sol max — full bundle review
         ↓
         STATUS: ISSUES_FOUND  →  Claude fixes CRITICAL+HIGH
         re-run: STATUS: CLEAN
         ↓
         "Review clean (2 iterations). Your move."  ← HARD STOP

You:     "now do a claude review too"  ← optional second pass

Claude:  same loop, claude -p engine
         STATUS: CLEAN

You:     "commit it, then I'll open the MR"  ← explicit

Claude:  git commit ...
```

---

## Skill comparison

|                          | codex-review                                       | claude-review                                  |
|--------------------------|----------------------------------------------------|------------------------------------------------|
| **Engine**               | `codex exec`                                       | `claude -p`                                    |
| **Model**                | `gpt-5.6-sol`                                      | `claude-fable-5`                               |
| **Reasoning**            | `model_reasoning_effort=max`                       | `--effort max`                                 |
| **Context isolation**    | `--sandbox read-only --ephemeral`                  | `--bare --allowedTools "Read,Grep,Glob"`       |
| **Exploration tools**    | shell: `cat`, `grep`, `find`                       | Read, Grep, Glob                               |
| **Bias mitigation**      | Different model family                             | Different invocation (no history, bare)        |
| **Branch spec path**     | `.claude/review-spec.md`                           | `.claude/review-spec-claude.md`                |
| **Project spec path**    | `.codex-review/spec.md`                            | `.claude-review/spec.md`                       |
| **Auto-trigger**         | "before I commit/MR/PR", "before merging"          | None — explicit only                           |
| **Manual trigger**       | "codex review", "run codex review"                 | "claude review", "fresh review", "fresh eyes"  |
| **External CLI needed**  | OpenAI Codex                                       | Claude Code (which you already have)           |
| **Phase A spec scaffold**| auto after `writing-plans`                         | manual: "set up claude review spec"            |
| **Phase A exploration**  | auto                                               | auto                                           |
| **Hard stop after CLEAN**| yes                                                | yes                                            |

Both are designed to coexist. Most users install both and use them sequentially — codex for first pass, claude for an optional second opinion.

---

## Spec anatomy

A review spec lives at `.claude/review-spec.md` (codex) and `.claude/review-spec-claude.md` (claude). It has six sections:

```markdown
# Review Spec — <feature name>

## Purpose
<One paragraph: what does this branch do, and why?>

## Requirements (the reviewer MUST verify these are met)
- [ ] <verifiable behavior>

## Deliberate design choices (the reviewer must NOT flag these)
- <intentional thing that looks like a bug>

## Non-goals (out of scope for this branch)
- <deferred or owned by another layer>

## Focus areas (extra reviewer attention here)
- <tricky spots>

## Related code (the reviewer will read these in full)
- `src/caller.py`       # auto-populated by Phase A exploration
- `include/types.h`

## Notes (optional)
- <algorithm references, conventions>
```

The reviewer's contract:

- Requirements → MUST verify met; spec violation if not.
- Deliberate design choices → NEVER flag.
- Non-goals → don't flag their absence.
- Related code → read for context; don't review.
- Focus areas → extra reasoning budget.

---

## Trigger phrases

### codex-review (Phase B) — narrow on purpose

```
✅ "codex review"
✅ "run codex review"
✅ "before I commit"
✅ "before I MR"
✅ "before I PR"
✅ "before merging"

❌ "I'm done"          ← acknowledged, no fire
❌ "let's review"      ← too ambiguous, removed in v1.5
❌ "wrap up the branch"
❌ "finalize"
```

### claude-review (Phase B)

```
✅ "claude review"
✅ "claude review this"
✅ "run claude review"
✅ "fresh review"
✅ "fresh eyes" / "fresh eyes review"
✅ "another review with claude"
✅ "review with a fresh claude"
```

### Spec scaffold triggers

```
codex-review:
  "set up review spec" / "init review spec" / "scaffold review spec"
  Also auto-triggers after Superpowers' writing-plans finishes.

claude-review:
  "set up claude review spec" / "init claude review spec" /
  "scaffold claude review spec"
```

### Bypass

```
"skip codex review"          ← Phase B
"skip claude review"         ← Phase B
"skip the spec"              ← Phase A
"skip the exploration"       ← Phase A exploration only
"just code" / "just commit"  ← bypasses Phase A or B
```

---

## Auto-explored Related code

When you ask for a spec to be scaffolded, Claude doesn't just create an empty template. It:

1. **Identifies search targets** from the plan — functions, classes, types being changed
2. **Runs targeted searches** — Grep for symbol references, Glob for sibling files
3. **Reads candidates briefly** to confirm relevance
4. **Filters to 3–7 most relevant files** — callers, type definitions, sibling modules, runtime config
5. **Auto-populates the `Related code` section** with inline comments explaining each file

Budget: ~60 seconds, ~10 search/read calls. If no clear candidates are found, the section is filled with `None — diff is self-contained based on exploration.`

You see the populated spec and can adjust before coding starts.

---

## Customization

| What                          | Where                                                                       |
|-------------------------------|-----------------------------------------------------------------------------|
| Spec template                 | `<skill>/templates/*.template.md`                                           |
| Reviewer behavior / prompt    | `<skill>/references/reviewer_prompt.md`                                     |
| Model / effort                | `<skill>/scripts/run_review.sh`                                             |
| Related code budgets          | `run_review.sh`: `TOTAL_BUDGET=40000`, `PER_FILE_BUDGET=8000`               |
| Iteration cap                 | `<skill>/SKILL.md`, Step 3                                                  |
| Trigger phrases / bypass      | `~/.claude/CLAUDE.md` (`codex-review-policy` / `claude-review-policy`)      |
| Exploration depth (Phase A)   | `<skill>/SKILL.md`, Phase A step 4                                          |
| Per-project override          | drop `.claude/skills/<skill>/` in a specific repo                           |

### Security

Both skills' default reviewer prompts **skip security review** because they were built for non-security-sensitive (motion control) work. For internet-facing / auth-related projects, edit `references/reviewer_prompt.md` in each skill:

1. Remove "Security issues" from "What NOT to flag"
2. Add it back to "Focus areas"

---

## Uninstall

```bash
bash install.sh uninstall
```

Removes only the installed skill(s) and their CLAUDE.md policy blocks. Does NOT touch:

- Per-project spec files (`.claude/review-spec.md`, `.claude/review-spec-claude.md`)
- The Codex or Claude Code CLI itself
- Other skills you've installed

---

## Project layout

```
spec-driven-review-skills/
├── README.md                              ← this file
├── LICENSE                                ← MIT
├── CHANGELOG.md
├── .gitignore
├── install.sh                             ← top-level meta-installer
│
├── codex-review/                          ← codex-review package
│   ├── install.sh                         ← sub-installer
│   ├── README.md                          ← skill-specific docs
│   └── codex-review/                      ← the actual skill
│       ├── SKILL.md
│       ├── CLAUDE_md_policy.md
│       ├── scripts/
│       │   ├── run_review.sh
│       │   └── init-spec.sh
│       ├── references/
│       │   └── reviewer_prompt.md
│       └── templates/
│           └── review-spec.template.md
│
└── claude-review/                         ← claude-review package
    ├── install.sh                         ← sub-installer
    ├── README.md                          ← skill-specific docs
    └── claude-review/                     ← the actual skill
        ├── SKILL.md
        ├── CLAUDE_md_policy.md
        ├── scripts/
        │   ├── run_review.sh
        │   └── init-spec.sh
        ├── references/
        │   └── reviewer_prompt.md
        └── templates/
            └── review-spec-claude.template.md
```

---

## Contributing

Issues and PRs welcome. A few ground rules:

- **Don't break the hard-stop.** Any change that lets the skill auto-commit, auto-merge, or chain into `finishing-a-development-branch` will be rejected. That gate exists on purpose.
- **Keep the two skills mirrored.** Architectural changes should land in both unless there's a specific reason for divergence (e.g. `--allowedTools` is claude-specific).
- **Test before PR'ing.** Both skills' installers have a `verify` subcommand — run it.
- **Update the README's comparison table** if you change anything visible to the user.

---

## License

MIT — see [LICENSE](LICENSE).
