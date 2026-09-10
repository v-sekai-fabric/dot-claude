---
name: gates-that-learn
description: Write checks that cannot quietly pass, and grow the suite from every defect that escapes one.
---

# Gates that learn

`CLAUDE.md` already says a check that passes on known-broken input is
decoration, and that a silent skip reads exactly like a pass. Those rules are
correct and easy to violate anyway — they were violated ten times in one
session by someone who had read them. Rules are advice a person must remember;
this is the mechanism.

## The property

A gate is fragile when a defect gets past it and nothing changes. It is
antifragile when the escape makes it stronger. So: **when something gets past a
check, the check's suite gains a control, permanently.**

`lib/escapes.tsv` is that record — one row per escape, naming what the check
reported and what was actually true. `lib/check_selftest.sh` replays it. The
suite only grows.

## Use the primitives

    . "$(dirname "$0")/../lib/check.sh"

| primitive | stops |
| --- | --- |
| `run_checked` | reading an exit code from the wrong process |
| `require_nonempty` | an empty result reported as a pass |
| `require_file` | concluding from a file that was never opened |
| `require_corpus` | searching one of several places and calling it absent |
| `require_engaged` | a control whose threshold was never crossed |
| `expect_fail` | a gate with no negative control |
| `require_precondition` | an unmet precondition reported as a skip |

Each carries the incident that produced it. Read them; the failures are more
instructive than the API.

## The shape of every one of these

A check that cannot distinguish its outcomes. `0 hits` from a file that does not
exist looks exactly like `0 hits` from a file that does. An empty token compares
unequal to the previous one just as a fresh one does. `cmd | tail` exits 0
whatever `cmd` did. The primitive's whole job is to make those two states
different.

## When a defect escapes

1. Add a row to `lib/escapes.tsv` saying what the check reported and what was true.
2. If an existing primitive would have caught it, use it and move on.
3. If none would have, write one, and add its control to `check_selftest.sh`.

Step 3 is the antifragile part. Skipping it means the next instance is silent too.
