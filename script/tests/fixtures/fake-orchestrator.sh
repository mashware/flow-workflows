#!/usr/bin/env bash
# A stand-in for the command `autonomy.orchestrator_cmd` names, for headless unattended runs.
#
#     FAKE_ORCH_DIR=<dir> fake-orchestrator.sh <order> [flags]
#
# Reading orders print what <dir> holds: `why` → <dir>/why, `ticket --json` → <dir>/ticket.json,
# `answer` → <dir>/answer, `events --json` → <dir>/events.json. Closing orders (ask, publish,
# blocked, done) are refused after the first one, as a real orchestrator refuses them. Every call
# — refused ones included — is appended to <dir>/calls.jsonl with its flags and, for each `-file`
# flag, the file's content at the moment of the call: the content is the evidence, because the
# run may rewrite or delete the file after it.
set -u
dir="${FAKE_ORCH_DIR:?FAKE_ORCH_DIR is not set}"
order="${1:-}"; [ $# -gt 0 ] && shift

log() {  # log <exit code> <args…>
  python3 - "$dir/calls.jsonl" "$order" "$@" <<'PY'
import json, os, sys
from datetime import datetime, timezone
path, order, code, *args = sys.argv[1:]
flags, files, i = {}, {}, 0
while i < len(args):
    key = args[i]
    value = args[i + 1] if i + 1 < len(args) and not args[i + 1].startswith("--") else True
    flags.setdefault(key, []).append(value)
    if key.endswith("-file") and isinstance(value, str):
        try:
            files[key] = open(value, encoding="utf-8").read()
        except OSError as err:
            files[key] = f"<unreadable: {err}>"
    i += 1 if value is True else 2
entry = {"at": datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds"),
         "order": order, "flags": flags, "files": files, "exit": int(code), "cwd": os.getcwd()}
with open(path, "a", encoding="utf-8") as fh:
    fh.write(json.dumps(entry, ensure_ascii=False) + "\n")
PY
}

serve() {  # serve <file> <args…>
  local file="$1"; shift
  if [ -f "$dir/$file" ]; then cat "$dir/$file"; log 0 "$@"; exit 0; fi
  echo "fake orchestrator: nothing to serve for '$order' ($file missing)" >&2; log 1 "$@"; exit 1
}

case "$order" in
  why)    serve why "$@" ;;
  ticket) serve ticket.json "$@" ;;
  answer) serve answer "$@" ;;
  events) serve events.json "$@" ;;
  reply)  log 0 "$@"; exit 0 ;;
  ask|publish|blocked|done)
    if [ -f "$dir/closed" ]; then
      echo "fake orchestrator: '$(cat "$dir/closed")' already closed this run" >&2
      log 1 "$@"; exit 1
    fi
    echo "$order" > "$dir/closed"; log 0 "$@"; exit 0 ;;
  *) echo "fake orchestrator: unknown order '$order'" >&2; log 2 "$@"; exit 2 ;;
esac
