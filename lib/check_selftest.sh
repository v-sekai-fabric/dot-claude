#!/bin/sh
# Replays lib/escapes.tsv: every defect that once escaped a check must now be
# caught by its primitive. This suite only grows.
set -u
DIR=$(cd "$(dirname "$0")" && pwd)
. "$DIR/check.sh"
pass=0; fail=0
ck() { if "$@" >/dev/null 2>&1; then pass=$((pass+1)); else fail=$((fail+1)); printf '  MISS  %s\n' "$1"; fi; }
ckfail() { if "$@" >/dev/null 2>&1; then fail=$((fail+1)); printf '  MISS  %s (accepted bad input)\n' "$1"; else pass=$((pass+1)); fi; }

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
printf 'hello\n' > "$tmp/present.txt"

# run_checked: the exit code must come from the command, not a pipe stage
run_checked sh -c 'exit 7'
[ "$CHECK_RC" = 7 ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "  MISS  run_checked lost the exit code"; }
run_checked sh -c 'echo out; exit 0'
[ "$CHECK_OUT" = "out" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "  MISS  run_checked lost stdout"; }

# require_nonempty: empty is a failure, never a result
ckfail require_nonempty "empty value" ""
ck     require_nonempty "real value" "ghs_abc"

# require_file: absence proves nothing about a file never opened
ckfail require_file "missing file" "$tmp/nope.txt"
ck     require_file "present file" "$tmp/present.txt"

# require_corpus: searching one of several places is not searching
ckfail require_corpus "corpus with a missing member" hello "$tmp/present.txt" "$tmp/nope.txt"
ck     require_corpus "complete corpus" hello "$tmp/present.txt"
ckfail require_corpus "empty corpus" hello

# require_engaged: a control that never fired proves nothing
ckfail require_engaged "mechanism never fired" ""
ck     require_engaged "mechanism fired" "ar @/tmp/x.lnk"

# expect_fail: broken input must be rejected
ck     expect_fail "rejects broken input" sh -c 'exit 1'
ckfail expect_fail "accepts broken input" sh -c 'exit 0'

# require_precondition: an unmet precondition is a FAIL, not a skip
ckfail require_precondition "unmet precondition" sh -c 'exit 2'
ck     require_precondition "met precondition" sh -c 'exit 0'

# require_literal: text that passed through a shell must still be the text written
ckfail require_literal "text eaten by the shell" "cmd | tail" "an empty token would.  exits zero"
ck     require_literal "text survived" "cmd | tail" "a check like cmd | tail exits zero"

rows=$(grep -vc '^#' "$DIR/escapes.tsv" 2>/dev/null || echo 0)
printf '\n  %d passed, %d missed, over %d recorded escapes\n' "$pass" "$fail" "$rows"
[ "$fail" -eq 0 ] || exit 1
