---
name: what-a-macos-desk-cannot-see
description: Seven classes of build defect that an arm64 macOS build is structurally incapable of showing, and the local gate that catches each without waiting for CI
---

# What a macOS desk cannot see

"It builds here" is a weaker claim than it sounds. Seven defects reached
CI in one session from a tree that compiled clean, linked clean, ran its
tests, and passed `warnings=extra werror=yes` on an arm64 macOS build.

None were sloppiness. Each is a property the local toolchain cannot
express.

## The seven, and why each is invisible

**GNU ld resolves archives in one pass; Apple's linker does not.** Godot's
`modules/SCsub` prepends one `libmodule_<name>.a` per module, which put
ggml *ahead* of every consumer calling into it. GNU ld read ggml's
archive before anything needed `gguf_find_tensor`, dropped `gguf.o`, and
failed later. Apple resolves fully, so it never appeared.
*Fix:* the `modules/freetype` pattern — build vendored code into its own
library and insert it before the first system lib, so it lands last among
SCons libraries.

**Which archive members get pulled changes with the target.**
`ggml-backend-reg.o` was never pulled on a macOS editor build, so a
missing `ggml-backend-dl.cpp` stayed invisible; a Linux Mono template
build referenced it and the absent `dl_*` symbols surfaced. A successful
link proves nothing about members you did not happen to need.

**MSVC-isms.** `<cmath>` only declares `M_PI` when `_USE_MATH_DEFINES`
precedes it.

**clang-cl promotes warnings to errors that `/W0` will not downgrade.**
`-Wincompatible-pointer-types` became an error in clang 16;
`disable_warnings()` does not touch it.

**`__declspec` is a no-op off MSVC.** Five C ABIs default to
`dllimport`; static linking needs `dllexport` on *both* the module TU and
the vendored implementation. A mismatch is undiagnosable locally because
the attribute does nothing here.

**Toolchain library gaps.** CI pinned `ubuntu-22.04` — stock GCC 11 and
clang 14, no compiler install step — so `<expected>` does not exist.
Nothing about a modern desk toolchain reveals that.

**32-bit targets.** `__int128` is absent, and a source `#error`s without
it. Note the anti-pattern here: a *compile probe* answers for the wrong
machine on a cross-build, because the NDK's clang has 128-bit ints for
its own default target. Target arch is what decides, and it is resolved
before `can_build` runs.

## The gate that catches the first two locally

Both linker-shaped defects share a signature: a symbol referenced by an
archive member that nothing in the build defines. That is checkable on
any desk, independent of which members this link pulled.

    defined    = union of defined symbols across every archive in the build
    undefined  = union of undefined symbols across OUR archives only
    unresolved = undefined - defined - system

Three details decide whether it works:

- **System symbols come from the SDK's `.tbd` stubs**, every one of them,
  not a hand-written prefix list. Reading only libSystem and libc++ left
  576 false positives; reading every framework stub cut it to 329.
- **Scope it to archives you own.** The remaining 329 were harfbuzz —
  a pre-existing condition in the host project. Auditing everything
  reports a backlog nobody asked for and buries your own defect.
- **Read the last stragglers before filtering them.** The final 83 were
  `objc_msgSend$<selector>` stubs and `__dso_handle`, genuinely
  runtime-provided. Pattern-matching them away without looking is how a
  real symbol hides in the tail.

## Two cheaper checks worth having

**Per-module C++ standard versus features actually used.** Grep the
vendored sources for `std::expected`, `std::span`, `std::print`, then
assert both the MSVC arm and the GCC/Clang arm reach that level. A
module asking MSVC for `/std:c++20` while its header returns
`std::expected` fails only on Windows, forty minutes in.

**Every source on disk versus every source in the build's list.**
A module compiled 1 of 11 library files and shipped as a facade; its
`get_abi_version()` returned the right number because that entry point
lives in the ABI file itself. Diff the two sets and account for every
omission — files defining `main()` are the legitimate ones.

## The habit

Before pushing, ask which of the seven the change could plausibly touch,
and run the gate for that one. When CI fails anyway, add the class to
this list rather than only fixing the instance.
