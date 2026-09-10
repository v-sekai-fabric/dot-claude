---
name: pushcheck-local-gates-before-ci
description: Run every gate the project already declares — prek plus a real (non-dry-run) compile of what changed — before `git push`, so CI is never the first runner of a formatter or a build. Load whenever you're about to push a branch, whenever a CI round-trip felt slow, whenever a prek / clang-format / copyright-headers / scons failure landed on a PR when the change had never left the desk, or whenever the workspace hits the RFD 2229 pattern "a part with no caller is not yet a part." Answers "how do I stop wasting operator cycles on push-and-wait" and installs the reflex.
---

# pushcheck — local gates before CI

CI is the wrong place to catch a formatter, a missing include, or a
copyright-header violation. Every one of those is a mechanism that
already exists on the desk — the `.pre-commit-config.yaml` prek picks
up, the SCons that compiles the module, the CMake that links the
library. RFD 2229's retro named the pattern: **a part with no caller
is not yet a part.** `pushcheck` is that caller.

## Reflex

Before `git push`, always:

    pushcheck && git push -u <remote> <branch>

The `&&` matters. A failed check has to be a hard stop.

## What it runs

The shell function in `~/.zshrc` sniffs the project type and runs the
gates that apply to what actually changed:

1. **prek** on the diff, whenever a `.pre-commit-config.yaml` exists in
   the checkout root. That covers clang-format, ruff-check + ruff-format,
   mypy, codespell, validate-codeowners, validate-includes,
   copyright-headers, header-guards, file-format — the whole
   static-checks bank.
2. **scons real compile** for a Godot fork (`SConstruct` at root and
   any changed file under `modules/<name>/`). Compiles just the affected
   module's static library, so the check finishes in seconds on a warm
   sccache. Not `--dry-run` — `--dry-run` only parses SConscript, and the
   class of failure that ate three CI cycles this session (missing
   `#include "core/object/class_db.h"`) only shows up when the C++
   actually goes through the compiler.
3. **cmake real build** for a CMake project (`CMakeLists.txt` at root
   and any changed C/C++/CMake file). Configures into
   `.build/pushcheck/` once, then rebuilds.
4. **mix compile + test** for an Elixir project (`mix.exs` at root and
   any changed `.ex`/`.exs`/`.eex` file). Uses `--warnings-as-errors`
   because a warning survives to CI as a failure.

Exits non-zero on the first violation; prints `pushcheck: green` on
success and returns 0 so it composes with `&& git push`.

## Why this is a skill and not a habit

Because the pattern lives in muscle memory and muscle memory doesn't
survive a coordinator handoff. The last three pushes without it cost:

- PR #79 in `V-Sekai-fire/entities-godot` — three CI cycles for
  clang-format (`Type& var` should be `Type &var`), then
  copyright-headers (Godot's canonical MIT block, not SPDX-only),
  then CODEOWNERS (six new `modules/<name>/` lines), then a real
  build failure (missing `#include "core/object/class_db.h"`),
  every one of which prek + a real scons compile would have caught
  locally in under 15 seconds. Wall-clock cost: ~45 minutes of
  operator wait plus a stuck PR closed and reopened at narrower scope.
- `V-Sekai-fire/weftspun-character-taxonomy#3` — a prek check ran
  green on second attempt because the first push was rushed. One
  CI round-trip avoidable.
- Every prior push through `V-Sekai-fire/*` this session where
  formatting drift landed on the desk before the reviewer.

None of these were compute-bound. Every one was operator round-trip
bound. `pushcheck` is not new mechanism — it's the caller that turns
the mechanism the workspace already ships into the fast feedback the
operator already needed.

## When it doesn't apply

- **First-touch of a repo you don't own.** No `.pre-commit-config.yaml`,
  no `SConstruct`, no local build. `pushcheck` reports "no changed
  files" or skips the compile step; that's honest, not a bypass.
- **Docs-only diffs.** `pushcheck` still runs prek on the touched
  Markdown / YAML / .exs files — that catches the copyright-headers
  and file-format issues just as often as it catches clang-format —
  and skips the compile step because no source changed. Fast.
- **A CI check the desk cannot reproduce.** Multi-platform builds
  (Android, iOS, Windows-MSVC on a Mac desk), signed release
  workflows, secret-dependent integration tests. `pushcheck` covers
  the local subset honestly and CI covers the rest; that's the
  boundary, not a failure of the pattern.

## Related

- RFD 2229's retro passage names the exact pattern: "a part with no
  caller is not yet a part." `pushcheck` is that caller.
- `~/.local/bin/gh-app` mints the token the push uses; `pushcheck`
  runs before that step, no auth required until the push itself.
- The `.pre-commit-config.yaml` files (46 of them across the
  workspace) are the mechanism side; `pushcheck` is the caller side.
- CLAUDE.md's "How Work Is Verified" rule 3: "A silent skip reads
  exactly like a pass" — `pushcheck`'s "no changed files" print and
  "green" print are named and distinct on purpose.
