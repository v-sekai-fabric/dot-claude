# check.sh — primitives for gates that cannot quietly pass.
#
# Every primitive here exists because a check written without it reported
# success while measuring nothing. The incident is named on each one: this file
# is a record, not advice. Source it from a gate:
#
#     . "$(dirname "$0")/../lib/check.sh"
#
# The companion corpus is lib/escapes.tsv, and check_selftest.sh replays it.
# When a defect escapes a gate, add a row there; the suite grows by one control
# and that class of miss cannot recur silently.

# run_checked CMD...
#   Runs a command, capturing stdout+stderr and the exit code SEPARATELY.
#   Sets CHECK_OUT and CHECK_RC. Never put a command behind a pipe to inspect
#   it: in zsh `$PIPESTATUS` is `$pipestatus`, and `cmd | tail` yields tail's
#   status. Incidents: a clean Godot build reported as failure; a conflicted
#   cherry-pick reported as clean; `echo pushed` after a 403.
run_checked() {
    CHECK_OUT=$("$@" 2>&1)
    CHECK_RC=$?
    return 0
}

# require_nonempty LABEL VALUE
#   An empty value is a FAIL, never a pass. Incidents: a watcher read "0 checks
#   returned" as ALL SETTLED when the token had expired; an empty minted token
#   compared unequal to the previous one and reported "behaved".
require_nonempty() {
    if [ -z "${2:-}" ]; then
        printf '  FAIL  %s: empty value, which is not a result\n' "$1"
        return 1
    fi
    printf '  ok    %s: %s\n' "$1" "$(printf %s "$2" | head -c 60)"
}

# require_file LABEL PATH
#   Absence proves nothing about a file you never opened. Assert the search
#   target exists before drawing a conclusion from not finding something in it.
#   Incidents: grepped egit.erl when the module is git.erl and read 0 hits as
#   "merge_base is absent"; grepped SERIALS.exs alone while the serial lived in
#   SERIALS-vsekai-fabric.exs, then used that gap to justify deviating from a rule.
require_file() {
    if [ ! -e "$2" ]; then
        printf '  FAIL  %s: %s does not exist, so nothing can be concluded from its contents\n' "$1" "$2"
        return 1
    fi
    printf '  ok    %s: %s present\n' "$1" "$2"
}

# require_corpus LABEL PATTERN PATHS...
#   Search every member of a corpus, and fail if the corpus is empty. Use when
#   "not found" would otherwise be reported after looking in one of several
#   places. Sets CHECK_HITS.
require_corpus() {
    label=$1; pattern=$2; shift 2
    [ "$#" -gt 0 ] || { printf '  FAIL  %s: empty corpus, nothing was searched\n' "$label"; return 1; }
    missing=0
    for f in "$@"; do [ -e "$f" ] || { printf '  FAIL  %s: corpus member %s missing\n' "$label" "$f"; missing=1; }; done
    [ "$missing" -eq 0 ] || return 1
    CHECK_HITS=$(grep -l -- "$pattern" "$@" 2>/dev/null | wc -l | tr -d ' ')
    printf '  ok    %s: searched %d file(s), %s hit(s)\n' "$label" "$#" "$CHECK_HITS"
}

# require_engaged LABEL EVIDENCE
#   A control that never crossed its threshold tested nothing. Assert the
#   mechanism actually fired. Incident: an ar response-file control at 400
#   objects produced a 30 KB command line against a 32768-byte threshold, so
#   the shim loaded, printed its banner, and never engaged.
require_engaged() {
    if [ -z "${2:-}" ]; then
        printf '  FAIL  %s: no evidence the mechanism engaged; the control proves nothing\n' "$1"
        return 1
    fi
    printf '  ok    %s: engaged (%s)\n' "$1" "$(printf %s "$2" | head -c 50)"
}

# expect_fail LABEL CMD...
#   The negative control CLAUDE.md rule 2 requires: assert that known-broken
#   input is rejected. Passing here means the command failed, as it must.
expect_fail() {
    label=$1; shift
    run_checked "$@"
    if [ "$CHECK_RC" -eq 0 ]; then
        printf '  FAIL  %s: broken input was ACCEPTED; the gate certifies the defect\n' "$label"
        return 1
    fi
    printf '  ok    %s: broken input rejected (exit %d)\n' "$label" "$CHECK_RC"
}

# require_precondition LABEL CMD...
#   An unmet precondition is a FAIL, not a skip (rule 3). Incident: a parser
#   control ran outside a git repository, so the tool exited at "not a git
#   repository" before reading the config, and every arm printed the same
#   nothing.
require_precondition() {
    label=$1; shift
    run_checked "$@"
    if [ "$CHECK_RC" -ne 0 ]; then
        printf '  FAIL  %s: precondition unmet (exit %d) -- results below would be vacuous\n' "$label" "$CHECK_RC"
        return 1
    fi
    printf '  ok    %s: precondition met\n' "$label"
}

# require_literal LABEL NEEDLE HAYSTACK
#   Text that passed through a shell may not be the text you wrote. Assert a
#   distinctive fragment survived. Incident: backticks inside a double-quoted
#   `git commit -m` were evaluated as command substitution, so the message
#   shipped with a sentence silently deleted, and the commit reported success.
require_literal() {
    case "$3" in
        *"$2"*) printf '  ok    %s: text survived\n' "$1" ;;
        *)      printf '  FAIL  %s: %s is not in the result; the shell rewrote it\n' "$1" "$2"; return 1 ;;
    esac
}
