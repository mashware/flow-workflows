#!/usr/bin/env bash
# Exercise `check_panel_reminder` in script/check.py — the guard over the panel vocabulary.
#     bash script/tests/panel-reminder.sh
# The reader knows a closed set of words and drops anything else without a sound: the panel
# still paints, and the line loses its symbol and its column with nobody told. That is why the
# sentence naming those words sits in all 24 command files — a session reads the shared skill
# once, a compaction drops it, and the copy is all the agent has left. Twenty-four copies only
# stay honest while one constant pins them, so the guard is load-bearing. Its own failure mode
# is the quiet one: the trigger that decides which files owe the sentence is ordinary prose,
# and reworded once it matches nothing, reports nothing and exits green having read nobody —
# a retired guard and a passing preflight look identical from outside. Case 4 is that case.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$HERE/../.."
CHECK="$REPO/script/check.py"
BASE="${TMPDIR:-/tmp}/flow-panel-reminder-test"
rm -rf "$BASE"; mkdir -p "$BASE"
fails=0

check() {  # <label> <file> <expected: hit|miss> <pattern>
  local out; out=$(cat "$2")
  if printf '%s' "$out" | grep -q -- "$4"; then found=hit; else found=miss; fi
  if [ "$found" = "$3" ]; then printf '  ok   %s\n' "$1"
  else printf '  FAIL %s — wanted %s for %q\n' "$1" "$3" "$4"; fails=$((fails+1)); fi
}

# Every case is a throwaway tree of fake command files plus an import of check.py with `ROOT`
# pointed at it, so the tracked tree is only ever read. The fixtures are written *from* the
# module's own constants, never from a copy pasted here, so a reworded sentence cannot leave
# this test asserting last year's text. One process per case, and `problems` — module level, and
# the only place `fail()` writes — cleared before each call, so no case can inherit another's.
drive() {  # <case> → writes $BASE/<case>.txt with one line per problem, or "clean"
  python3 - "$1" "$BASE" "$CHECK" > "$BASE/$1.txt" 2>&1 <<'PY'
import importlib.util, os, re, sys

case, base, path = sys.argv[1], sys.argv[2], sys.argv[3]

def load(src=None):
    """check.py as a module. With `src`, a rebuilt one — the point of case 5."""
    if src is None:
        spec = importlib.util.spec_from_file_location("flow_check", path)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        return mod
    ns = {"__name__": "flow_check_patched", "__file__": path}
    exec(compile(src, path, "exec"), ns)          # not __main__, so main() does not run
    return ns

mod = load()
MOD = vars(mod)
tree = os.path.join(base, case)
cmds = os.path.join(tree, "plugins", "flow", "commands")
os.makedirs(cmds, exist_ok=True)

def write(name, body):
    with open(os.path.join(cmds, name), "w", encoding="utf-8") as fh:
        fh.write(body)

def command(preflight=True, reminder=None):
    out = ["# /flow:fake:command\n"]
    if preflight:
        out.append(MOD["PREFLIGHT_LINE"] + " and then do the thing.\n")
    out.append("Some body prose that has nothing to do with the panel.\n")
    if reminder is not None:
        out.append(reminder + "\n")
    return "\n".join(out)

def run(ns, files):
    ns["problems"].clear()                        # no case inherits another's problems
    ns["check_panel_reminder"](files)
    return list(ns["problems"])

def report(problems):
    print("\n".join(problems) if problems else "clean — the check found no problem")

good = command(reminder=MOD["PANEL_REMINDER"])
rel = lambda *names: ["plugins/flow/commands/" + n for n in names]

if case == "in-order":
    write("alpha.md", good); write("beta.md", good)
    MOD["ROOT"] = tree
    report(run(MOD, rel("alpha.md", "beta.md")))

elif case == "one-character":
    # Still opens with the sentinel, so it is collected as a copy and judged — a file whose
    # sentence merely went missing is case 3, and the two must not report as each other.
    edited = MOD["PANEL_REMINDER"].replace("nobody is told.", "nobody is told!")
    assert edited != MOD["PANEL_REMINDER"], "fixture edited nothing"
    write("alpha.md", good); write("beta.md", command(reminder=edited))
    MOD["ROOT"] = tree
    report(run(MOD, rel("alpha.md", "beta.md")))

elif case == "no-sentence":
    write("alpha.md", good); write("gamma.md", command(reminder=None))
    MOD["ROOT"] = tree
    report(run(MOD, rel("alpha.md", "gamma.md")))

elif case == "reworded-trigger":
    # A tree in perfect order, read by a check whose trigger has been reworded: the loop
    # matches nothing at all, which is how a guard retires without anybody noticing.
    write("alpha.md", good); write("beta.md", good)
    MOD["ROOT"] = tree
    MOD["PREFLIGHT_LINE"] = "Read the `flow:flow-core` skill before anything else"
    report(run(MOD, rel("alpha.md", "beta.md")))

elif case == "built-from-the-lists":
    # (a) The sentence carries exactly the two lists — no word invented, none left behind.
    #     `mark` and `style` are the field names the sentence introduces them with.
    quoted = set(re.findall(r"`([^`]+)`", MOD["PANEL_REMINDER"])) - {"mark", "style"}
    want = set(MOD["MARKS"]) | set(MOD["STYLES"])
    if quoted == want:
        print("vocabulary: exact")
    else:
        print("vocabulary: extra=%s missing=%s"
              % (sorted(quoted - want), sorted(want - quoted)))

    # (b) The constant is *built* from the lists, so editing a list has to move it. Proven by
    #     rebuilding check.py from a patched source rather than by reading the f-string: a
    #     sentence typed out by hand beside the lists would pass (a) and fail here.
    src = open(path, encoding="utf-8").read()
    patched = src.replace('MARKS = ("done",', 'MARKS = ("doing", "done",', 1)
    patched = patched.replace('STYLES = ("normal", ', 'STYLES = (', 1)
    assert patched != src, "the lists are not where this test thinks they are"
    rebuilt = load(patched)
    print("rebuilt-marks: a word added to MARKS is %s the sentence"
          % ("in" if "`doing`" in rebuilt["PANEL_REMINDER"] else "NOT in"))
    print("rebuilt-styles: a word dropped from STYLES is %s the sentence"
          % ("out of" if "`normal`" not in rebuilt["PANEL_REMINDER"] else "STILL in"))

    # ...and that one edit turns every copy red at once, which is the whole reason 24 files
    # may repeat the sentence: they cannot be edited one at a time.
    write("alpha.md", good); write("beta.md", good)
    rebuilt["ROOT"] = tree
    report(run(rebuilt, rel("alpha.md", "beta.md")))
PY
}

# The fixtures are the whole point: a test that edited the real command files and put them back
# would pass every case here and lose somebody's work the one time it died in the middle. The
# tree is already dirty while this feature is in flight, so what is pinned is the delta — the
# working-tree bytes of everything the check reads, before and after.
snapshot() {
  git -C "$REPO" status --porcelain -uno
  git -C "$REPO" hash-object "$REPO/script/check.py" "$REPO"/plugins/flow/commands/*.md
}
snapshot > "$BASE/before.txt" 2>&1

drive in-order
check "a tree in order reports nothing"        "$BASE/in-order.txt" hit  'clean — the check found no problem'

drive one-character
check "one character off fails, naming the file" "$BASE/one-character.txt" hit  'plugins/flow/commands/beta.md: its panel-vocabulary line differs from PANEL_REMINDER'
check "and says the sentence is frozen"          "$BASE/one-character.txt" hit  'the sentence is frozen, edit the constant and rebuild'
check "the untouched copy is not accused"        "$BASE/one-character.txt" miss 'alpha.md'

drive no-sentence
check "a file that loads the skill owes one"   "$BASE/no-sentence.txt" hit  'plugins/flow/commands/gamma.md: loads flow-core but carries no panel-vocabulary line'
check "and is told why it matters"             "$BASE/no-sentence.txt" hit  'keeps after a compaction'
check "the compliant file is not accused"      "$BASE/no-sentence.txt" miss 'alpha.md'

drive reworded-trigger
check "a trigger matching nothing is a failure" "$BASE/reworded-trigger.txt" hit 'script/check.py: no command file contains PREFLIGHT_LINE'
check "and says the guard now guards nothing"   "$BASE/reworded-trigger.txt" hit 'this check is now guarding nothing'

drive built-from-the-lists
check "the sentence carries exactly both lists" "$BASE/built-from-the-lists.txt" hit 'vocabulary: exact'
check "a word added to MARKS moves the sentence" "$BASE/built-from-the-lists.txt" hit 'rebuilt-marks: a word added to MARKS is in the sentence'
check "a word dropped from STYLES leaves it"     "$BASE/built-from-the-lists.txt" hit 'rebuilt-styles: a word dropped from STYLES is out of the sentence'
check "and one list edit reddens every copy"     "$BASE/built-from-the-lists.txt" hit 'alpha.md: its panel-vocabulary line differs'
check "every copy, not just the first"           "$BASE/built-from-the-lists.txt" hit 'beta.md: its panel-vocabulary line differs'

snapshot > "$BASE/after.txt" 2>&1
if diff -q "$BASE/before.txt" "$BASE/after.txt" >/dev/null 2>&1
then echo "the real tree is byte-identical" > "$BASE/untouched.txt"
else diff "$BASE/before.txt" "$BASE/after.txt" > "$BASE/untouched.txt" 2>&1; fi
check "the real tree is read, never written"   "$BASE/untouched.txt" hit 'the real tree is byte-identical'

rm -rf "$BASE"
if [ "$fails" = 0 ]; then echo "panel-reminder: all cases pass"
else echo "panel-reminder: $fails failure(s)"; exit 1; fi
