#!/usr/bin/env sh
# flow plugin — PostToolUse hook: keep the live panel in step with the work's files.
# The panel used to be republished only when the agent remembered to, and the record says it
# mostly did not: 8 of 64 build sessions with a written plan ever showed a step. The ticks,
# the MR/PR train and the agent's own Now/Next live in files, so when one of them is newer
# than panel.json, this renders the panel again (`flow-workflows panel`) — the agent no longer
# has to remember anything but writing those files.
#
# Runs after every tool call of every session in every repo the plugin is installed in, so
# the common path must cost nothing: no work for this branch, or nothing newer than the
# panel → exit at once, without starting node. The render itself is detached, so a slow
# npx never holds a tool call. It never blocks and every failure exits 0. It prints only
# after an answered question, and only under Claude Code: a terminal that holds the panel
# over MCP ignores every file this hook renders, so the one party that can drop the claim is
# the agent, and the hook's output is what reaches it before its next call.
set -u

event=$(cat 2>/dev/null || printf '')
# The event's own `cwd`, the first one: a tool's input or output may carry another later on.
cwd=$(printf '%s' "$event" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"\(.*\)"$/\1/')
[ -n "${cwd:-}" ] && [ -d "$cwd" ] || cwd=$PWD

# The user answered a question (Claude Code's AskUserQuestion, Codex's request_user_input): the
# decision it asked leaves the panel now, not when the agent remembers to rewrite its input.
# Only the tool's own response is read, and only a real answer counts: Claude Code's `answers`
# holding one question → answer pair (it comes back empty when nobody answered in time), or a
# Codex answer list with an entry in it (its response is a JSON string, so its quotes are
# escaped). A rejected question is a failed tool use and never reaches PostToolUse.
answered=""
case $event in
	*'"AskUserQuestion"'*|*'"request_user_input"'*)
		response=${event#*\"tool_response\"}
		[ "$response" != "$event" ] && printf '%s' "$event" | grep -Eq '"tool_name"[[:space:]]*:[[:space:]]*"(AskUserQuestion|request_user_input)"' \
			&& printf '%s' "$response" | grep -Eq '"answers"[[:space:]]*:[[:space:]]*\{[[:space:]]*"([^"\\]|\\.)*"[[:space:]]*:[[:space:]]*"|\\"answers\\"[[:space:]]*:[[:space:]]*\[[[:space:]]*\\"' \
			&& answered=1 ;;
esac

command -v git >/dev/null 2>&1 || exit 0
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0
common=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || printf '')
main_root=${common%/.git}

# The work whose `branch` — top-level or a train MR/PR's — is this branch: the key, not the
# name anywhere (a `"base": "main"` is not the `main` session's work). The CLI is then told
# which folder it is, so the worktree and the main checkout can never disagree about it.
[ "$main_root" = "$root" ] && main_root=""
[ -d "$root/.claude/work" ] || { [ -n "$main_root" ] && [ -d "$main_root/.claude/work" ]; } || exit 0
stamp=".panel-refresh-$(printf '%s' "$branch" | cksum | cut -d' ' -f1)"
pattern="\"branch\"[[:space:]]*:[[:space:]]*\"$(printf '%s' "$branch" | sed 's/[][\.*^$+?(){}|/]/\\&/g')\""
needs=""
named=""
matched=""
for r in "$root" "$main_root"; do
	[ -n "$r" ] && [ -d "$r/.claude/work" ] || continue
	for meta in "$r"/.claude/work/*/meta.json; do
		[ -f "$meta" ] || continue
		grep -qE "$pattern" "$meta" 2>/dev/null || continue
		work=${meta%/meta.json}
		matched=1
		# A decision on the panel (the labels may name one too, so they are left out of the look):
		# copy the input aside as answered and render. The input itself is the agent's, untouched.
		# The reminder below goes out even when the copy cannot be written.
		if [ -n "$answered" ] && [ -f "$work/panel-input.json" ] \
			&& sed 's/"labels"[[:space:]]*:[[:space:]]*{[^}]*}//' "$work/panel-input.json" 2>/dev/null | grep -q '"decision"'; then
			named="$work"
			cp "$work/panel-input.json" "$work/.panel-answered.tmp" 2>/dev/null \
				&& mv -f "$work/.panel-answered.tmp" "$work/panel-answered.json" 2>/dev/null \
				&& needs="$work" || rm -f "$work/.panel-answered.tmp" 2>/dev/null
			break 2
		fi
		# Newer than the panel and than this branch's last attempt → render. The stamp is
		# touched before each launch, so a render that writes nothing (a broken input, npx
		# unreachable) is not retried after every tool call: only once a file changes again.
		for f in meta.json 05-implementation.md 04-fix.md panel-input.json forge-state.json; do
			[ -f "$work/$f" ] || continue
			if [ ! -f "$work/panel.json" ] || [ "$work/$f" -nt "$work/panel.json" ]; then
				if [ ! -f "$work/$stamp" ] || [ "$work/$f" -nt "$work/$stamp" ]; then
					needs="$work"
				fi
			fi
		done
		[ -n "$needs" ] && break 2
	done
done

# The answer's reminder. A branch that names a work → that work, by its folder. A branch that
# names none (a session in the main checkout driving a sibling worktree) → a line that names
# no work: every session there reports the same cwd and branch, so the hook cannot tell whose
# work is whose, and naming another session's work would invite clearing that session's claim.
if [ -n "$answered" ] && [ "${CLAUDECODE:-}" = 1 ]; then
	reminder=""
	# The text is already JSON: its \" stays escaped, and the folder name is escaped to match.
	if [ -n "$named" ]; then
		folder=$(printf '%s' "${named##*/}" | tr -d '\000-\037' | sed 's/[\\"]/\\&/g')
		if [ -z "$needs" ]; then
			reminder="flow: the question was answered, but the panel files of $folder could not be cleared. Before anything else: rewrite panel-input.json without \\\"decision\\\", render, and republish where the panel goes (panel_set over the terminal's MCP; ArtifactData set of card.json when panel.artifact is on)."
		else
			reminder="flow: the question was answered and the panel files of $folder no longer claim the user, but a panel published over the terminal's MCP, and the control-room card, still carry the decision. If either is in use, before anything else: rewrite panel-input.json without \\\"decision\\\", render, and republish there (panel_set; ArtifactData set of card.json)."
		fi
	elif [ -z "$matched" ]; then
		for r in "$root" "$main_root"; do
			[ -n "$r" ] && [ -d "$r/.claude/work" ] || continue
			for input in "$r"/.claude/work/*/panel-input.json; do
				[ -f "$input" ] || continue
				# An input already copied aside as answered claims nobody (the CLI's own rule).
				cmp -s "$input" "${input%/*}/panel-answered.json" && continue
				if sed 's/"labels"[[:space:]]*:[[:space:]]*{[^}]*}//' "$input" 2>/dev/null | grep -q '"decision"'; then
					reminder="flow: a question was answered, and this session's branch names no work, so no panel file was cleared. If your work's panel carries that decision, before anything else: rewrite its panel-input.json without \\\"decision\\\", render, and republish (panel_set over the terminal's MCP; ArtifactData set of card.json when panel.artifact is on)."
					break 2
				fi
			done
		done
	fi
	if [ -n "$reminder" ]; then
		printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$reminder"
	fi
fi

[ -n "$needs" ] || exit 0
touch "$needs/$stamp" 2>/dev/null || exit 0

here=$(cd "$(dirname "$0")" 2>/dev/null && pwd) || exit 0
version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$here/../.claude-plugin/plugin.json" 2>/dev/null | head -1)
[ -n "$version" ] || exit 0

# The overlay this harness reads: Claude Code marks its children with CLAUDECODE=1; the
# other harness that loads plugin hooks is Codex.
if [ "${CLAUDECODE:-}" = 1 ]; then harness=claude; else harness=codex; fi

# From outside the checkout: npx run inside it would honour a committed `.npmrc` or
# `node_modules`, and the repo would choose what runs. FLOW_PANEL_CLI replaces the npx call
# (the tests point it at the repo's bin/cli.mjs).
cd "${HOME:-/}" 2>/dev/null || cd / || exit 0
if [ -n "${FLOW_PANEL_CLI:-}" ]; then
	nohup sh -c "$FLOW_PANEL_CLI panel --harness $harness --repo \"\$1\" --work \"\$2\"" _ "$root" "$needs" >/dev/null 2>&1 &
else
	nohup npx -y "flow-workflows@$version" panel --harness "$harness" --repo "$root" --work "$needs" >/dev/null 2>&1 &
fi
exit 0
