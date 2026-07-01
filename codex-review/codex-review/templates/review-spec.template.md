# Review Spec — <feature name>

## Purpose
<One paragraph: what does this branch do, and why?>

## Requirements (the reviewer MUST verify these are met)
- [ ] <e.g. "All joint angle inputs are in radians">

## Deliberate design choices (the reviewer must NOT flag these)
- <e.g. "Single-precision float — consumer expects f32">

## Non-goals (out of scope for this branch)
- <e.g. "Input validation — handled by safety_layer.py separately">

## Focus areas (please pay extra attention here)
- <e.g. "solver.py:compute_jacobian() — indexing is tricky">

## Related code (the reviewer will read these files in full)

<!--
v1.5+: Claude auto-populates this section during Phase A spec drafting by
exploring the repo for callers, type users, interface implementers, and
sibling modules of code being changed. The user reviews the populated spec
before coding starts.

If you're filling manually, list file paths relative to repo root:
  - `src/caller.py`      # calls function being changed
  - `include/types.h`    # defines the structs the diff uses
-->

- `<path/to/caller.py>`
- `<path/to/types.py>`

## Notes (optional context for the reviewer)
- <e.g. "Algorithm reference: Buss 2009, eq. 11">
