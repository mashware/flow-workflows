#!/usr/bin/env bash
# Exercise `script/bench-compare.py` — the reader that decides which difference between two
# eval runs is real.
#     bash script/tests/bench-compare.sh
# It parses a document written by another tool and turns three numbers into a verdict a
# release reads. Nobody checks that by eye: a median taken over the wrong arm, or a delta
# printed for a wobble the base's own runs already spanned, looks exactly like a result.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CMP="$HERE/../bench-compare.py"
BASE="${TMPDIR:-/tmp}/flow-bench-compare-test"
rm -rf "$BASE"; mkdir -p "$BASE"
fails=0

check() {  # <label> <file> <expected: hit|miss> <pattern>
  local out; out=$(cat "$2")
  if printf '%s' "$out" | grep -q -- "$4"; then found=hit; else found=miss; fi
  if [ "$found" = "$3" ]; then printf '  ok   %s\n' "$1"
  else printf '  FAIL %s — wanted %s for %q\n' "$1" "$3" "$4"; fails=$((fails+1)); fi
}

# <file> <seeded run scores, comma separated> <clean run scores> [partial]
doc() {
  python3 - "$@" <<'PY'
import json, sys
path, seeded, clean = sys.argv[1], sys.argv[2], sys.argv[3]
partial = len(sys.argv) > 4
def arm(scores):
    return [{"score": float(s), "error": None} for s in scores.split(",")]
doc = {
    "schemaVersion": 1,
    "claudeVersion": "9.9.9",
    "costUsd": 4.0,
    "durationSeconds": 100,
    "partial": partial,
    "partialReason": "cost_ceiling" if partial else None,
    "aggregates": {"meanDelta": 0.5},
    "cases": [
        {"name": "seeded-one", "tags": ["review", "seeded"],
         "aggregates": {"delta": 0.6}, "arms": {"with": arm(seeded)}},
        {"name": "clean-one", "tags": ["review", "clean"],
         "aggregates": {"delta": 0.2}, "arms": {"with": arm(clean)}},
    ],
}
json.dump(doc, open(path, "w"))
PY
}

# The base spans 0.33–0.66 on the seeded case: three runs of the same suite, which is what a
# non-deterministic agent looks like. A candidate landing anywhere inside that is not news, and a
# median equal to the base's best run is still something the base itself did.
doc "$BASE/base.json"   "0.33,0.33,0.66" "1,1,1"
doc "$BASE/inside.json" "0.66,0.33,0.33" "1,1,1"
doc "$BASE/below.json"  "0,0,0"       "1,1,1"
doc "$BASE/above.json"  "1,1,1"       "1,1,1"
doc "$BASE/partial.json" "1,1,1"      "1,1,1" partial

python3 "$CMP" "$BASE/base.json" "$BASE/inside.json" > "$BASE/inside.txt" 2>&1
check "a median inside the base's range is not a delta" "$BASE/inside.txt" hit "within the base's own range"
check "and its delta column stays empty"                "$BASE/inside.txt" miss "seeded-one.*+"

python3 "$CMP" "$BASE/base.json" "$BASE/below.json" > "$BASE/below.txt" 2>&1
check "a median under the range is a regression" "$BASE/below.txt" hit "REGRESSED"
python3 "$CMP" "$BASE/base.json" "$BASE/below.json" --fail-on-regression > /dev/null 2>&1
[ $? -eq 1 ] && printf '  ok   %s\n' "--fail-on-regression exits 1" \
             || { printf '  FAIL %s\n' "--fail-on-regression exits 1"; fails=$((fails+1)); }

python3 "$CMP" "$BASE/base.json" "$BASE/above.json" > "$BASE/above.txt" 2>&1
check "a median over the range is an improvement" "$BASE/above.txt" hit "improved"
check "seeded and clean are reported apart"       "$BASE/above.txt" hit "recall (seeded)"
check "cost and wall clock travel with the score" "$BASE/above.txt" hit "wall clock"

python3 "$CMP" "$BASE/partial.json" "$BASE/above.json" > "$BASE/partial.txt" 2>&1
check "a partial run is called out, not silently compared" "$BASE/partial.txt" hit "is partial"

python3 "$CMP" --save "$BASE/partial.json" > "$BASE/save.txt" 2>&1
check "and never recorded as a baseline" "$BASE/save.txt" hit "refusing to record a partial run"

# The result document records the suite and the plugin version and never the model, so a
# baseline saved without one is named for a model nobody can identify later.
python3 "$CMP" --save "$BASE/above.json" > "$BASE/nomodel.txt" 2>&1
check "a baseline with no model says so" "$BASE/nomodel.txt" hit "no --model given"
rm -f "$HERE/../../plugins/flow/evals/baselines/"*-default-model.json

rm -rf "$BASE"
if [ "$fails" = 0 ]; then echo "bench-compare: all cases pass"
else echo "bench-compare: $fails failure(s)"; exit 1; fi
