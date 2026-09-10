---
name: land-work-through-gitassembly
description: How work reaches entities-godot — declared in gitassembly and applied in order, never merged into the default branch; PRs are review surfaces and stay drafts
---

# Land work through gitassembly

`V-Sekai-fire/entities-godot` is not integrated by merging pull requests.
`entities-assembly` holds a `gitassembly` file of `stage` / `merge` lines
that `thirdparty/git-assembler` applies **in order** to build the
`multiplayer-fabric` branch, driven by `update_godot_v_sekai.exs`.

Getting this wrong is not a style error. Spending a session optimising
"which PR to merge first" is optimising a step that does not exist here.

## The rules

- **Never modify entities-godot's default branch.** This is that
  repository only; others merge normally.
- **Every PR on entities-godot is a draft.** They are review surfaces.
  Draft is what makes "do not merge" mechanical instead of conventional.
- **`feat/*` naming**: `feat/module-ggml`, `feat/ci-ar-response-file`.
- **Import code with `git subtree`**, not by copying files. Copying
  flattens history that the subtree split preserves.
- **The repo manifest places code side by side.** Use it for code that
  stays independent; do not use it for code that has to become part of
  the tree.

## Order is how a branch declares its dependencies

The assembler applies merges top to bottom, so position expresses
prework. When the default branch is broken, the fix goes first and
everything that needs it goes after:

    merge multiplayer-fabric remotes/v-sekai-fire/feat/ci-ar-response-file
    merge multiplayer-fabric remotes/v-sekai-fire/feat/module-ggml
    merge multiplayer-fabric remotes/v-sekai-fire/feat/module-kimodo

Nothing links without the first line; the five consumers include the
second one's headers. A branch chain that carries its own prework is
fine — re-merging is idempotent.

## The file is a set of promises to check

Every ref in `gitassembly` is resolved later by a tool, so verify it now.
Three defects found by actually checking, all of which read as fine:

- A line naming a branch that had been **renamed**, so the ref no longer
  resolved. Added and then invalidated in the same session.
- Twelve lines on a remote the script **never runs `add_remote` for**,
  which worked only if the operator's checkout happened to have it.
- Every line and the clone URL pointing through an **archived org** via
  redirect. The script's own comment had already named the principle:
  *a redirect is somebody else's promise.*

Also check the sibling-checkout search in `update_godot_v_sekai.exs`
against the path the manifest actually uses. It looked for
`fabric-godot-core` and `godot`, found neither, and re-cloned a
multi-gigabyte tree beside a checkout that was already there.

## `#` is not a comment

Comment support was deliberately removed from the vendored
`git-assembler`. A `#` line now exits 2 with `unknown command: #`, and a
trailing `#` exits 1. Removing it made comments **loud** rather than
silently dropped, which is the point — do not add explanatory `#` lines
to `gitassembly`.

## Read the branch, not the working tree

A checkout can sit far behind the branch that matters. One turboquant
checkout was on `main`, **2359 llama.cpp files** behind the `mtp-subtree`
tip that carried the real work. Anything reading the working tree —
including subagents — analyses whatever is checked out. Name the branch
and read it with `git show <branch>:<path>`.

## Two traps around PR state

GitHub's index goes stale: a PR reported `CLOSED` by one query showed
`OPEN` minutes later, and `--base master` returned nothing while a PR
plainly had that base. Re-read before acting on a listing.

And force-pushing a branch whose remote head has gone **closes its PR**,
irrecoverably — `gh pr reopen` refuses. Check the remote ref exists
before a force push, and read `[new branch]` in push output as the
warning it is.
