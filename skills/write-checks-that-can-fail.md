---
name: write-checks-that-can-fail
description: Before trusting a check, prove it can report the other outcome — the failure mode is a check that prints something reassuring while measuring nothing
---

# Write checks that can fail

A check that cannot distinguish its outcomes is not a weak check, it is
no check. It costs the same to run, prints something reassuring, and
certifies whatever was already broken. `CLAUDE.md` states it as rule 2 —
a check that passes on known-broken input is decoration — and rule 3 —
a silent skip reads exactly like a pass.

The trap is not writing a bad assertion. It is writing a *good*
assertion the check never reaches.

## Reflex

Before believing a green check, ask: **what would make this print the
other thing?** If there is no answer, the check has not run yet.

Then make it print the other thing, once, deliberately.

## The five ways a check measures nothing

Each of these produced a false green in one session.

**It never reached the assertion.** A parser control ran outside a git
repository, so the tool exited at `fatal: not a git repository` before
reading its config. Three configs "passed" identically — including the
one with the defect planted in it.

**It matched on guessed wording.** The same control grepped for
`parse error|invalid assembly`. The real message was `unknown command: #`.
The tool was rejecting the input correctly and the check called it
accepted. Grep for the *outcome* — exit code, artifact present — not for
a string you predicted.

**The threshold was never crossed.** An `ar` response-file fix was
"verified" with 400 objects producing a 30 KB command line, against a
32,768-byte threshold. The shim loaded, the banner printed, and the
response file never engaged. Rerunning at 1200 objects (82,820 bytes)
is what made it actually fire.

**The exit code came from the wrong process.** `if git cherry-pick X | tail -3`
tests `tail`, which always succeeds. A conflicted cherry-pick reported
as clean while `CHERRY_PICK_HEAD` sat on disk. Same family: `$PIPESTATUS`
is bash; **zsh spells it `$pipestatus`**, so the bash form silently
expands to nothing and a clean compile reads as a failure. Capture
output and status separately and never put a compiler behind a pipe.

**Absence was read as success.** A CI watcher counted "0 checks
returned" as ALL SETTLED and reported green. The token had expired and
every call was 401ing. An empty or unauthorised result is an *error*
state, never a settled one — and long-running watchers must re-mint
credentials, because an hourly expiry otherwise masquerades as success.

A sixth, in the same family: `echo "pushed"` inside a loop, printing
regardless of what the push returned. One of three had 403'd.

## Both directions, always

A control that only shows the good case proves the check *can* say yes.
Pair it:

    control -- real input        : behaved (accepted)
    control -- planted defect    : behaved (caught)
    control -- defect then fixed : behaved (clears)

The third matters more than it looks. It proves the check responds to
the *thing* rather than to some unrelated property of the broken file.

The strongest control is not planted at all: run the check against a
defect that already happened. An archive-symbol gate was validated
against two real facades found earlier the same day — better evidence
than any synthetic input, because nobody chose those inputs to be found.

## Do not assume the convention, read the value

Two PRs were opened against `main`. One repository used `main`; the
other used `main-fabric`, and that PR named a branch that does not
exist. `default_branch` is one API call. The same shape put a ref in a
committed config file that no longer resolved after a rename.

Anything a tool will resolve later — a branch, a remote, a path, a
flag name — gets read now, not guessed. Check the flag too: a control
passed `--config` to a tool whose option is `-f`.

## When the result is implausible, suspect the check first

A tree-hash comparison reported CONTENT DRIFTED on all six branches of
a rebase. The rebase was correct; the check was impossible to satisfy,
because the whole point of the operation was adding two files to every
tree. The right question was not "are these identical" but "do these
differ by *exactly* the expected files".

An implausible result is usually the measurement, not the world.
