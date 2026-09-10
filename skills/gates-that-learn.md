---
name: gates-that-learn
description: Write checks that cannot quietly pass, and grow the suite from every defect that escapes one.
---

# Gates that learn

`CLAUDE.md` already says a check that passes on known-broken input is
decoration, and that a silent skip reads exactly like a pass. Those rules are
right and easy to violate anyway — they were violated eleven times in one
session by someone who had read them. A rule is advice you must recall at the
moment you are writing a one-line grep. This is the mechanism instead.

The implementation lives in `2-contract/manuals-weftspun`, in Elixir, beside
the RFD DSL it is modelled on.

## The property

A gate is fragile when a defect gets past it and nothing changes. It is
antifragile when the escape makes it stronger. So when something gets past a
check, the suite gains a control, permanently.

`ESCAPES.exs` is that record, written through the `RFD.Escapes` DSL the same
way `SERIALS.exs` uses `RFD.Register`. `test/escapes_test.exs` replays it. A
row naming an unknown guard is rejected, and so is one where `reported` and
`actual` match — a row without a gap records no escape.

## Prefer removing the choice to guarding it

`RFD.Corpora` is the facade over every register-like corpus. It has no
single-corpus entry point, because the escape it exists for was
`grep 2235 SERIALS.exs -> 0 hits`, concluded as "no register names this
serial", while the serial sat in `SERIALS-vsekai-fabric.exs`. A guard would
have caught that; a facade means it cannot be expressed.

`files/1` raises on an empty set rather than answering not-found. An empty
search reporting not-found is the same silent pass in another costume.

## The guards

`RFD.Checks`, each naming the incident that produced it.

| guard | stops |
| --- | --- |
| `run_checked` | an exit code read from the wrong process |
| `require_nonempty` | an empty result reported as a pass |
| `require_file` | concluding from a file never opened |
| `require_corpus` | searching one of several places |
| `require_engaged` | a control whose threshold never fired |
| `expect_fail` | a gate with no negative control |
| `require_precondition` | an unmet precondition reported as a skip |
| `require_literal` | text the shell rewrote |

## Every one of these has the same shape

A check that cannot distinguish its outcomes. Zero hits from a file that does
not exist reads exactly like zero hits from a file that does. An empty token
compares unequal to the previous one just as a fresh one does. `cmd | tail`
exits zero whatever `cmd` did. The guard's whole job is to make those two
states different.

## When a defect escapes

1. Add an `escape` row to `ESCAPES.exs` saying what the check reported and what
   was true.
2. If an existing guard would have caught it, use that guard and move on.
3. If none would have, ask first whether a facade removes the choice. Only
   write a new guard when it does not.

Step 3 is the antifragile part. Skipping it means the next instance is silent too.
