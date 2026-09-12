---
name: register-rfd-under-pen-oid
description: Allocate the next RFD serial in SERIALS-vsekai-fabric.exs under Weftspun's PEN arc, write the rfd/<N>-<slug>.exs source whose rendered README carries the AI-drafted attestation canary and the urn:oid spine, and verify the pair with the anti-entropy check. Use when a new RFD needs a number, when subdividing an existing serial (2164.N.M), or when backfilling a previously ad-hoc numbering.
tools: Read, Write, Edit, Grep, Glob, Bash
---

# Register RFD under PEN OID

Weftspun's Private Enterprise Number is `1.3.6.1.4.1.66606`. Site 2
(`v-sekai-fabric`) is category 1 (`documents`), so an RFD's full arc is
`1.3.6.1.4.1.66606.1.2.<serial>[.N.M]`, and it is quoted in prose in the
RFC 3061 URN form `urn:oid:1.3.6.1.4.1.66606.1.2.<serial>`.

## When to invoke

The user asks for a new RFD, asks to subdivide an existing serial into
`.N` or `.N.M` sub-rungs, or points out an RFD that landed under an
ad-hoc number and needs a real serial. Also invoke when a related
document needs to cite an RFD by identifier and the identifier does not
yet exist.

## Where the register lives

`2-contract/manuals-weftspun/SERIALS-vsekai-fabric.exs`. The `arc`,
`pen`, `site`, `category` fields at the top of the file are the source
of truth for the OID shape. Read them before assuming.

New RFDs at this site get `2NNN` serials, per the reactivated-2026-08-31
note in the file's `customLayerData`.

## Pipeline

**1. Read the register.** Open `SERIALS-vsekai-fabric.exs` and find the
`allocated do` block. The highest `serial <N>, "<slug>"` row in it is the
last allocated serial. The next one is `<N>+1`, and it is max-plus-one
rather than the lowest gap. A `deleted do` block below carries rows in
the same `serial <N>, "<slug>"` shape; those are spent, never candidates.

**2. Append the allocation** to `allocated do`, in serial order:

    serial <N+1>, "<kebab-case-slug>"

The slug follows the source's filename so that a retitle renames the
document without renumbering it. Never reuse and never renumber; a serial
is the last arc of an OID and it names one document forever. A document
that landed under a number the register gives to something else is
reissued under a fresh serial, not renumbered into place.

**3. Write the RFD source.** `2-contract/manuals-weftspun/rfd/<N>-<slug>.exs`.
The `.exs` is what is tracked. RFD 2232 makes `README.md` and `DETAILS.md`
build artifacts of `mix rfd.render`, gitignored and never hand-edited:

    # Copyright (c) 2026 K. S. Ernest (iFire) Lee
    # SPDX-License-Identifier: MIT
    #
    # RFD <N>. `mix rfd.render` renders rfd/<N>-<slug>/README.md and
    # DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
    defmodule RFD<N> do
      use RFD.DSL

      rfd <N>, "<title>" do
        state :discussion

        feature "<one sentence>"

        scope "<path or paths>"

        problem ~S"""
        ...
        """

        decision ~S"""
        ...
        """

        related ~S"""
        Spine: urn:oid:1.3.6.1.4.1.66606.1.1.<parent-serial>
        Satellite of: urn:oid:1.3.6.1.4.1.66606.1.2.<other-serial>
        """

        drafted_by :ai
      end
    end

`drafted_by :ai` is what renders the attestation canary into the README,
and `check_rfd_canary.py` reads the rendered file. `drafted_by :human`
renders the human counterpart. Neither sentence is typed by hand.

**4. Cite by URN.** Use the full `urn:oid:` form in prose. Sub-rungs
extend with dot-arcs (`urn:oid:1.3.6.1.4.1.66606.1.2.2164.3.2` is
"RFD 2164 sub-rung 3.2"). Never abbreviate to bare `.2164` or invent
sitewise shortcuts.

**5. Run the anti-entropy check.**

    pixi run python scripts/check_anti_entropy.py

It enumerates the serial register against the RFD sources under `rfd/`,
across every checkout in the manifest rather than this one. An allocated
serial with no document, a document with no row, and two documents on one
serial all fail. Read what it says, not the last line.

**6. Commit both files in the same commit.** The register row and the
`.exs` source land together, so a `git bisect` never lands on a state with
one and not the other.

## Rules that catch failure modes

- **The `arc`, `pen`, `site`, `category` fields in the `layer` of `SERIALS-vsekai-fabric.exs` are the source of truth.** Do not hardcode `1.3.6.1.4.1.66606.1.2` into scripts; read it from the register.
- **Sub-rungs are dot-arcs on the serial**, not slashes and not colons: `urn:oid:1.3.6.1.4.1.66606.1.2.2164.3.2`, not `.../2164/3/2`.
- **PEN category comes before site**, not after: `<pen>.<category>.<site>.<serial>`. An earlier version of this pipeline had `<pen>.<site>.<category>.<serial>` and the user corrected it.
- **The canary comes from `drafted_by`**, not from a typed sentence. A misspelling is rejected by `check_rfd_canary.py`'s self-test control, and a sentence typed into a rendered README is lost on the next `mix rfd.render`.
- **Slug and filename match.** The register's slug must equal the `<slug>` in `rfd/<N>-<slug>.exs`. The anti-entropy check enumerates both.
- **A rendered README over 40 lines fails the structural gate.** Trim the `.exs` body to fit — move the argument into a `section`, which renders into DETAILS.md.
- **A commit with only the serial or only the source** leaves the register in a drift state that neither half of the pair notices on its own; the anti-entropy check does, but only when it is run.
