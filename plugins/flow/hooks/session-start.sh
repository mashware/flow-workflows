#!/usr/bin/env sh
# flow plugin — SessionStart hook.
# A session that opens on a branch with a work behind it starts blind: the phase is in
# meta.json, the handoff in 00-summary.md, and what was running when the last session ended
# in panel.json — and nothing reads any of it until the user types a command. This prints
# the two lines that answer "where was I", and nothing else.
#
# Read-only, and silent unless it has something to say: this hook runs in every repo the
# plugin is installed in, so noise in a repo that does not use flow is the failure mode to
# design against. No jq: the common path is grep, sed and awk over the two JSON files, and
# a file it cannot parse degrades to the one line that still helps, never to silence.
set -eu

event=$(cat 2>/dev/null || printf '')

# The repo is the one the session is in, not the one this hook happens to run from — the
# push guard read the wrong directory once (v0.35.1) and blocked every push from a worktree.
cwd=$(printf '%s' "$event" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
[ -n "${cwd:-}" ] && [ -d "$cwd" ] || cwd=$PWD

command -v git >/dev/null 2>&1 || exit 0
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -n "$root" ] || exit 0
branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || printf '')

# In a worktree the branch is here and `.claude/work/` is usually over in the main checkout
# (it is git-ignored in most repos, so it never travelled). Look in both.
main_root=""
common=$(git -C "$cwd" rev-parse --git-common-dir 2>/dev/null || printf '')
if [ -n "$common" ]; then
	case "$common" in
	/*) ;;
	*) common="$root/$common" ;;
	esac
	common=$(cd "$common" 2>/dev/null && pwd || printf '')
	case "$common" in
	*/.git) main_root=${common%/.git} ;;
	esac
fi

work_dirs=""
for r in "$root" "$main_root"; do
	[ -n "$r" ] || continue
	[ -d "$r/.claude/work" ] || continue
	case " $work_dirs " in *" $r/.claude/work "*) continue ;; esac
	work_dirs="$work_dirs $r/.claude/work"
done
# No work folders at all → this repo does not use flow, or has never started a work.
[ -n "$work_dirs" ] || exit 0

# --- the work this branch belongs to -----------------------------------------------------
# A match is the top-level `branch`, any `mrs[].branch` of a train, or a `worktree` pointing
# here. `_archive/` is out: an archived work is not where you are. Same rule as /flow:next §1.
meta=""
for wd in $work_dirs; do
	for candidate in "$wd"/*/meta.json; do
		[ -f "$candidate" ] || continue
		if [ -n "$branch" ] && grep -q "\"branch\"[[:space:]]*:[[:space:]]*\"$branch\"" "$candidate" 2>/dev/null; then
			meta=$candidate
			break
		fi
		if grep -q "\"worktree\"[[:space:]]*:[[:space:]]*\"$root\"" "$candidate" 2>/dev/null; then
			meta=$candidate
			break
		fi
	done
	[ -n "$meta" ] && break
done

field() { # <key> <file> — first "key": "value" in the file, empty when absent
	[ -f "$2" ] || return 0
	sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$2" 2>/dev/null | head -1
}

# --- the pending decision, across open works and the archive -----------------------------
# A follow-up someone accepted and nobody started (flow-core §7). One line, never a list.
followup_line=""
if [ -n "$work_dirs" ]; then
	followup=$(
		for wd in $work_dirs; do
			for candidate in "$wd"/*/meta.json "$wd"/_archive/*/meta.json; do
				[ -f "$candidate" ] || continue
				tick=$(sed -n 's/.*"ticket"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$candidate" 2>/dev/null | head -1)
				[ -n "$tick" ] || tick=$(basename "$(dirname "$candidate")")
				TICKET="$tick" awk '
					/"followups"[[:space:]]*:/ { inf = 1 }
					inf && /"id"[[:space:]]*:/ {
						if (id != "" && acc && open) print ENVIRON["TICKET"] " " id
						id = $0; sub(/.*"id"[[:space:]]*:[[:space:]]*"/, "", id); sub(/".*/, "", id)
						acc = 0; open = 0
					}
					inf && /"status"[[:space:]]*:[[:space:]]*"accepted"/ { acc = 1 }
					inf && /"work"[[:space:]]*:[[:space:]]*null/ { open = 1 }
					inf && /^[[:space:]]*\][,]?[[:space:]]*$/ {
						if (id != "" && acc && open) print ENVIRON["TICKET"] " " id
						inf = 0; id = ""; acc = 0; open = 0
					}
					END { if (inf && id != "" && acc && open) print ENVIRON["TICKET"] " " id }
				' "$candidate" 2>/dev/null
			done
		done
	)
	count=$(printf '%s' "$followup" | grep -c . || true)
	if [ "${count:-0}" -gt 0 ]; then
		first=$(printf '%s\n' "$followup" | head -1)
		more=""
		[ "$count" -gt 1 ] && more=" (+$((count - 1)) more)"
		followup_line="Also: $(printf '%s' "$first" | awk '{print $2 " from " $1}') accepted and never started$more — /flow:work:status"
	fi
fi

if [ -z "$meta" ]; then
	# No work on this branch. The follow-up still deserves its line — it is a standing
	# commitment, and a session that starts with nothing in flight is exactly when it is
	# invisible.
	[ -n "$followup_line" ] && printf '%s\n' "$followup_line"
	exit 0
fi

dir=$(dirname "$meta")
ticket=$(field ticket "$meta")
size=$(field size "$meta")
phase=$(field phase "$meta")

# Nothing readable in meta.json → say the one thing that is still true.
if [ -z "$ticket" ] && [ -z "$phase" ]; then
	printf 'A work exists on this branch — /flow:work:resume\n'
	[ -n "$followup_line" ] && printf '%s\n' "$followup_line"
	exit 0
fi

[ -n "$ticket" ] || ticket=$(basename "$dir")
head_line="$ticket"
[ -n "$size" ] && head_line="$head_line · $size"
[ -n "$phase" ] && head_line="$head_line · phase $phase"

# The MR/PR train: which one is in flight, out of how many. Read in order from `mrs[]`, so
# a number that cannot be read is left out rather than guessed.
train=$(awk '
	/"mrs"[[:space:]]*:/ { inm = 1; next }
	inm && /^[[:space:]]*\][,]?[[:space:]]*$/ { inm = 0 }
	inm && /"n"[[:space:]]*:/ {
		total++
		line = $0; sub(/.*"n"[[:space:]]*:[[:space:]]*/, "", line); sub(/[^0-9].*/, "", line)
		n = line
	}
	inm && /"status"[[:space:]]*:/ {
		st = $0; sub(/.*"status"[[:space:]]*:[[:space:]]*"/, "", st); sub(/".*/, "", st)
		if (cur == "" && st == "in_progress") cur = n
		if (st == "merged") merged++
	}
	END {
		if (total > 0) {
			if (cur == "") cur = (merged < total ? merged + 1 : total)
			print cur " " total
		}
	}
' "$meta" 2>/dev/null)
if [ -n "$train" ]; then
	head_line="$head_line · MR #$(printf '%s' "$train" | awk '{print $1}') of $(printf '%s' "$train" | awk '{print $2}')"
fi

# What the last session was doing, in its own words: the panel's `Now` line first, the
# handoff's first line otherwise.
panel="$dir/panel.json"
now=$(grep '"ref"[[:space:]]*:[[:space:]]*"Now"' "$panel" 2>/dev/null |
	sed -n 's/.*"text"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
if [ -z "$now" ] && [ -f "$dir/00-summary.md" ]; then
	now=$(grep -v '^[[:space:]]*$' "$dir/00-summary.md" 2>/dev/null | grep -v '^#' | head -1 |
		sed 's/^[-*][[:space:]]*//')
fi

last_line="Last stop: ${now:-unknown}"
# panel.json carries the phase that was *running*; meta.json only advances at a close. When
# the two disagree, the last session stopped inside a phase that never closed — the case the
# panel exists to expose.
panel_phase=$(field phase "$panel")
if [ -n "$panel_phase" ] && [ -n "$phase" ] && [ "$panel_phase" != "$phase" ]; then
	last_line="$last_line — $panel_phase was still running"
fi
printf '%s\n%s — /flow:work:resume\n' "$head_line" "$last_line"
[ -n "$followup_line" ] && printf '%s\n' "$followup_line"

exit 0
