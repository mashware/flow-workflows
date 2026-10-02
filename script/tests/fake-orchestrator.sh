#!/usr/bin/env bash
# The fake orchestrator answers as a real one does on the orders a study run depends on.
#     bash script/tests/fake-orchestrator.sh
# A fixture that is laxer than the real orchestrator lets a headless run pass on a closing order
# production refuses.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAKE="$HERE/fixtures/fake-orchestrator.sh"
fails=0
ok()   { printf '  ok   %s\n' "$1"; }
fail() { printf '  FAIL %s\n' "$1"; fails=$((fails+1)); }
expect() {  # <description> <expected exit> <why> <order…>
  local desc="$1" want="$2" why="$3"; shift 3
  local dir; dir=$(mktemp -d); printf '%s\n' "$why" > "$dir/why"
  [ -n "${ANSWER:-}" ] && printf '%s' "$ANSWER" > "$dir/answer"
  [ -n "${SUMMARY:-}" ] && printf '%s' "$SUMMARY" > "$dir/summary"
  (cd "$dir" && FAKE_ORCH_DIR="$dir" bash "$FAKE" "$@" >/dev/null 2>&1); local got=$?
  [ "$got" -eq "$want" ] && ok "$desc" || fail "$desc (exit $got, wanted $want)"
  rm -rf "$dir"
}
expect "answer with no reply exits 2" 2 study answer
ANSWER="make it one MR" expect "answer with a reply exits 0" 0 study answer
expect "publish is refused in a study run" 2 study publish --title-file t --body-file b
expect "done in a study run needs a summary file" 2 study done
SUMMARY="x" expect "done in a study run with a summary closes" 0 study done --summary-file summary
expect "done in a start run needs no summary file" 0 start done
[ "$fails" -eq 0 ] && echo "fake orchestrator: ok" || { echo "fake orchestrator: $fails failure(s)"; exit 1; }
