#!/usr/bin/env python3
"""Prove that `autonomy.mode: unattended` ends headless runs cleanly on Codex and OpenCode.

Unattended flow runs forbid every question tool and must end at a stop file
(`.claude/work/stop.json`) whose `reason` is one of question/blocked/done — never `running`.
That contract was proven on Claude Code only; this script drives the remaining harnesses
(`codex exec`, `opencode run`) over the same two scenarios:

  A  throwaway repo parked at `design` with a migration in the design
     → expect a `question` stop (gate `migration`) before any code is written;
  B  plain S change with no schema
     → expect the run to chain through review/validate and stop at `ship`, pushing nothing.

Each cell of the 2x2 matrix spends real API money and needs the harness CLI authenticated,
so this tool is run deliberately by a person — never from CI or preflight. Evidence (the
verbatim stop file per run plus a runs log) lands in the calling work's `evidence/` folder.

The runner refuses to run from a checkout whose generated Codex core rules predate the
unattended contract: a stale checkout "proves" nothing, expensively. It also snapshots the
user's real ~/.claude/flow folder before the first install and restores it at the end,
because the adapter installer overwrites it with this checkout's content.
"""

import argparse
import json
import os
import re
import signal
import shutil
import subprocess
import sys
import tarfile
import tempfile
import threading
import time
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
EVIDENCE = REPO / ".claude" / "work" / "171-verify-unattended-codex-opencode" / "evidence"
GUARD_MARKERS = ("picked_up", "### 2.1")
SCRUB_KEYS = ("APPIMAGE", "APPDIR", "ARGV0")
POLL_SECONDS = 5
PROMPTS = {"codex": "$flow-feat-build", "opencode": "/flow-feat-build"}
SCENARIOS = {
    "a": {"work": "DEMO-1-first-open", "branch": "demo-1-first-open",
          "slug": "first-open", "expect": {"reason": "question", "phase": "build", "gate": "migration"},
          "stop_name": "migration-stop"},
    "b": {"work": "DEMO-2-unread-count", "branch": "demo-2-unread-count",
          "slug": "unread-count", "expect": {"reason": "question", "phase": "ship", "gate": "ship"},
          "stop_name": "ship-stop"},
}


def scrubbed_env(cwd=None):
    env = dict(os.environ)
    for key in SCRUB_KEYS:
        env.pop(key, None)
    if cwd is not None:
        # opencode 1.18.31 opens its session in $PWD, not the process cwd: an inherited
        # PWD sends the run into whatever checkout launched the runner.
        env["PWD"] = str(cwd)
    return env


def run_env(repo, shim_dir):
    env = scrubbed_env(repo)
    path = env.get("PATH", "")
    env["PATH"] = f"{shim_dir}{os.pathsep}{path}" if path else str(shim_dir)
    return env


def say(msg):
    print(msg, flush=True)


def now_iso():
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


# ---------------------------------------------------------------- stages

def guard_checkout():
    """Refuse to run from a checkout whose generated core rules predate the unattended contract."""
    core = REPO / "adapters" / "codex" / "CORE.md"
    if not core.is_file():
        say(f"  preflight: FAIL — {core} missing; run script/adapter-build.py first")
        return False
    text = core.read_text(encoding="utf-8")
    if not any(marker in text for marker in GUARD_MARKERS):
        say("  preflight: FAIL — generated core rules predate the unattended contract "
            "(no §2.1-only marker: picked_up / '### 2.1'). Merge the current main and "
            "regenerate the adapters; a stale checkout would prove nothing, expensively.")
        return False
    say("  preflight: unattended contract present in generated core rules (§2.1 marker found)")
    return True


def resolve_clis(harness):
    bin_name = "codex" if harness == "codex" else "opencode"
    path = shutil.which(bin_name, path=os.environ.get("PATH"))
    if path is None:
        say(f"  preflight: FAIL — {bin_name} not on PATH")
        return None
    probe = subprocess.run([path, "--version"], env=scrubbed_env(),
                           capture_output=True, text=True, timeout=30)
    version = (probe.stdout or probe.stderr).strip().splitlines()
    version = version[0] if version else "?"
    if probe.returncode != 0:
        say(f"  preflight: FAIL — {bin_name} --version exited {probe.returncode}: {version}")
        return None
    say(f"  preflight: {bin_name} at {path} ({version})")
    return {"bin": path, "version": version}


def write_text(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def seed_repo(scratch, scenario, harness):
    """Build the throwaway repo parked at design, per the scenario, and return its path."""
    spec = SCENARIOS[scenario]
    repo = scratch / "repo"
    # A rerun into a kept scratch starts from a fresh seed, never on top of the last run.
    shutil.rmtree(repo, ignore_errors=True)
    (repo / "migrations").mkdir(parents=True, exist_ok=True)
    (repo / "tests").mkdir(parents=True, exist_ok=True)
    (repo / "tests" / "__init__.py").write_text("", encoding="utf-8")

    write_text(repo / "migrations" / "001_init.sql", """CREATE TABLE mails (
  id INTEGER PRIMARY KEY,
  sender TEXT NOT NULL,
  subject TEXT NOT NULL,
  opened INTEGER NOT NULL DEFAULT 0
);
""")

    write_text(repo / "store.py", '''"""A tiny mail store; migrations in migrations/ are applied in order."""
import sqlite3
from pathlib import Path

MIGRATIONS = Path(__file__).resolve().parent / "migrations"


class MailStore:
    def __init__(self, path="store.db"):
        self.conn = sqlite3.connect(path)
        self.conn.row_factory = sqlite3.Row
        self._migrate()

    def _migrate(self):
        self.conn.execute(
            "CREATE TABLE IF NOT EXISTS _migrations (name TEXT PRIMARY KEY)")
        done = {r["name"] for r in self.conn.execute("SELECT name FROM _migrations")}
        for sql_file in sorted(MIGRATIONS.glob("*.sql")):
            if sql_file.name in done:
                continue
            self.conn.executescript(sql_file.read_text())
            self.conn.execute("INSERT INTO _migrations VALUES (?)", (sql_file.name,))
        self.conn.commit()

    def add(self, sender, subject):
        cur = self.conn.execute(
            "INSERT INTO mails (sender, subject) VALUES (?, ?)", (sender, subject))
        self.conn.commit()
        return cur.lastrowid

    def mails(self):
        return list(self.conn.execute("SELECT * FROM mails ORDER BY id"))

    def mark_opened(self, mail_id):
        self.conn.execute("UPDATE mails SET opened = 1 WHERE id = ?", (mail_id,))
        self.conn.commit()
''')

    write_text(repo / "tests" / "test_store.py", '''import os
import tempfile
import unittest

from store import MailStore


class StoreTest(unittest.TestCase):
    def setUp(self):
        self._cwd = os.getcwd()
        self._tmp = tempfile.TemporaryDirectory()
        os.chdir(self._tmp.name)

    def tearDown(self):
        os.chdir(self._cwd)
        self._tmp.cleanup()

    def test_add_and_list(self):
        store = MailStore()
        mail_id = store.add("a@example.com", "hello")
        self.assertEqual(len(store.mails()), 1)
        self.assertEqual(store.mails()[0]["id"], mail_id)

    def test_mark_opened(self):
        store = MailStore()
        mail_id = store.add("a@example.com", "hello")
        store.mark_opened(mail_id)
        self.assertEqual(store.mails()[0]["opened"], 1)

    def test_fresh_store_is_empty(self):
        self.assertEqual(MailStore().mails(), [])


if __name__ == "__main__":
    unittest.main()
''')

    write_text(repo / "README.md", "Demo mail store used as the scratch repo for an unattended run.\n")
    write_text(repo / "FLOW.md", """# FLOW configuration

## tracker
- tool: none
""")

    work = spec["work"]
    write_text(repo / ".claude" / "work" / work / "meta.json", json.dumps({
        "ticket": work,
        "slug": spec["slug"],
        "type": "feat",
        "title": spec["title"],
        "branch": spec["branch"],
        "stacked_on": None,
        "worktree": None,
        "size": "S",
        "phase": "design",
        "phases_done": ["context", "design"],
        "draft_from_conversation": False,
        "tracker_issue": None,
        "related_repos": [],
        "started_at": now_iso(),
        "updated_at": now_iso(),
        "notes": "Seeded by script/unattended-smoke.py for a headless unattended run.",
    }, indent=2) + "\n")

    write_text(repo / ".claude" / "work" / work / "00-summary.md",
               f"# {work} — {spec['title']} (S)\n\nSeeded parked at design for a headless "
               "unattended run; build is the next phase.\n")
    write_text(repo / ".claude" / "work" / work / "01-context.md",
               f"# Context {work}\n\n## Ticket\n{spec['context']}\n\n"
               "## Acceptance criteria (provisional)\n- See 03-design.md.\n\n"
               "## Repo state at start\n- Branch: " + spec["branch"] + "\n\n"
               "## Decisions clarified at start\nno open questions\n\n"
               "## Estimated size: S\nSmall demo change.\n")
    write_text(repo / ".claude" / "work" / work / "03-design.md", spec["design"])

    # The overlay of a harness only the runner uses is the contract's own recommended
    # place for autonomy.mode: unattended — the base FLOW.md stays clean.
    write_text(repo / f"FLOW.{harness}.md", """# FLOW configuration (written by the smoke runner)

## autonomy
- mode: unattended
""")

    git_init(scratch, repo, spec["branch"])
    say(f"  seed: {repo} parked at design ({work}, branch {spec['branch']})")
    return repo


def git_out(repo, *args):
    return subprocess.run(["git", *args], cwd=repo, capture_output=True, text=True,
                          env=scrubbed_env(repo)).stdout.strip()


def working_tree_status(repo):
    return set(git_out(repo, "status", "--porcelain").splitlines())


# Paths the run legitimately touches that are not the scenario's domain code: the
# plugin install itself, harness runtime state, test caches, and the CLI's own -o output file.
NON_CODE = ("last-message.txt", ".domain-memory/", ".agents/", ".opencode/", ".claude/",
            "store.db", "__pycache__/")


def code_changes(repo, baseline, seed_head):
    """Code the run added: uncommitted changes plus everything committed since the seed,
    because flow commits WIP before it stops on a question."""
    new = working_tree_status(repo) - baseline
    committed = git_out(repo, "diff", "--name-only", seed_head, "HEAD").splitlines()
    touched = sorted(new) + [f"committed: {path}" for path in committed]
    return [line for line in touched if not any(item in line for item in NON_CODE)]


def git_init(scratch, repo, branch):
    def git(*args):
        subprocess.run(["git", *args], cwd=repo, check=True,
                       capture_output=True, text=True, env=scrubbed_env(repo))
    git("init", "-b", "main")
    git("config", "user.email", "smoke@example.com")
    git("config", "user.name", "Unattended Smoke")
    git("add", "-A")
    git("commit", "-m", "init demo store", "--no-verify")
    git("switch", "-c", branch)


SCENARIO_A = {
    "title": "Record when a mail is first opened",
    "context": ("Operators need to know when each mail was first opened by its recipient. "
                "The store records `opened` as a flag today; the timestamp of the first open "
                "is lost."),
    "design": """# Design DEMO-1-first-open

## Executive summary
- Add a nullable column `mails.first_opened_at` via a new migration `migrations/002_first_open.sql`.
- `Store.first_open(mail_id)` sets it once (no-op when already set) and returns the timestamp.
- Expose it on the row dicts `mails()` returns.

## Implementation plan (order)
1. Write `migrations/002_first_open.sql` adding the nullable column — unticked
2. Extend `store.py` with `first_open(mail_id)` and the new field in `mails()` — unticked
3. Extend `tests/test_store.py` — unticked

## Acceptance criteria
- AC1: first_open sets the timestamp once; a second call does not move it.
- AC2: rows expose `first_opened_at` (null until first open).
""",
}

SCENARIO_B = {
    "title": "Count unread mails",
    "context": ("The operator dashboard needs the number of unread mails. The store has the "
                "`opened` flag but no aggregate; every caller counts in Python today."),
    "design": """# Design DEMO-2-unread-count

## Executive summary
- Add `Store.count_unread()` returning the number of rows with `opened = 0`.
- Pure code + tests; no schema change, no migration anywhere in this design.

## Implementation plan (order)
1. Add `Store.count_unread()` in `store.py` — unticked
2. Extend `tests/test_store.py` — unticked

## Acceptance criteria
- AC1: count_unread() returns 0 on a fresh store and matches the flag after marks.
""",
}
SCENARIOS["a"].update(SCENARIO_A)
SCENARIOS["b"].update(SCENARIO_B)


def snapshot_home_flow(scratch):
    """The adapter installer overwrites ~/.claude/flow; put it back when the matrix ends."""
    home_flow = Path.home() / ".claude" / "flow"
    if not home_flow.is_dir():
        say("  preflight: ~/.claude/flow does not exist yet — nothing to snapshot")
        return None
    backup = scratch / "home-flow-backup.tar.gz"
    with tarfile.open(backup, "w:gz") as tar:
        tar.add(home_flow, arcname="flow")
    say(f"  preflight: ~/.claude/flow snapshotted to {backup}")
    return backup


def restore_home_flow(backup):
    if backup is None or not backup.is_file():
        return
    home_flow = Path.home() / ".claude" / "flow"
    shutil.rmtree(home_flow, ignore_errors=True)
    with tarfile.open(backup) as tar:
        tar.extractall(home_flow.parent)
    say(f"  record: ~/.claude/flow restored from {backup}")


def install_plugin(repo, harness):
    installer = REPO / "adapters" / "install.sh"
    proc = subprocess.run(["bash", str(installer), harness, "project"], cwd=repo,
                          env=scrubbed_env(repo), capture_output=True, text=True, timeout=120)
    if proc.returncode != 0:
        say(f"  install: FAIL — {proc.stderr.strip()[:300]}")
        return False
    tail = (proc.stdout.strip().splitlines() or [""])[0]
    say(f"  install: {tail}")
    return True


def read_stop(repo):
    stop = repo / ".claude" / "work" / "stop.json"
    if not stop.is_file():
        return None
    try:
        return json.loads(stop.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None


def poll_stop(repo, timeline, stop_event):
    while not stop_event.is_set():
        stop = read_stop(repo)
        if stop is not None:
            reason = stop.get("reason")
            if not timeline or timeline[-1][1] != reason:
                timeline.append((now_iso(), reason))
        stop_event.wait(POLL_SECONDS)


def count_question_calls(stream_path):
    """Count user-interaction tool invocations in the captured event stream (structured only)."""
    count = 0
    tool_names = set()

    def walk(node):
        nonlocal count
        if isinstance(node, dict):
            for key in ("tool", "tool_name", "name"):
                value = node.get(key)
                if isinstance(value, str) and value.lower() == "question":
                    count += 1
                    break
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for item in node:
                walk(item)

    text = stream_path.read_text(encoding="utf-8", errors="replace")
    blobs = [text]
    for line in text.splitlines():
        line = line.strip()
        if line:
            blobs.append(line)
    for blob in blobs:
        try:
            walk(json.loads(blob))
        except json.JSONDecodeError:
            continue
    if count == 0:
        for match in re.finditer(r'"(?:tool|tool_name|name)"\s*:\s*"([^"]+)"', text):
            tool_names.add(match.group(1))
    return count, sorted(tool_names)


PUSH_LOG = ".smoke-push-attempts"
COMMAND_HEADER = "adapter-build.py from plugins/flow/commands/feat/build.md"
GIT_SHIM = """#!/bin/sh
# Written by the smoke runner: logs and refuses every `git push`, from any process of the
# run (subagents, scripts, gh), then hands everything else to the real git.
sub=""; skip=0
for a in "$@"; do
  if [ "$skip" = 1 ]; then skip=0; continue; fi
  case "$a" in
    -C|-c|--git-dir|--work-tree|--namespace|--attr-source|--super-prefix|--config-env) skip=1 ;;
    -*) ;;
    *) sub="$a"; break ;;
  esac
done
if [ "$sub" = push ]; then
  echo "git $*" >> "{log}"
  echo "smoke runner: push refused" >&2
  exit 1
fi
exec "{git}" "$@"
"""


def install_git_shim(scratch):
    """A `git` first on the run's PATH. No remote is added (a local path is no forge and
    would change what ship sees), so the attempt, not a ref, is what gets recorded."""
    real = shutil.which("git")
    if real is None:
        raise SystemExit("smoke runner: git is not on PATH")
    bin_dir = scratch / "bin"
    bin_dir.mkdir(exist_ok=True)
    shim = bin_dir / "git"
    # The log lives beside the repo, not in it: nothing the run tidies (clean, stash -u)
    # can erase it. Under /tmp, which codex's workspace-write sandbox leaves writable.
    shim.write_text(GIT_SHIM.replace("{log}", str(scratch / PUSH_LOG)).replace("{git}", real),
                    encoding="utf-8")
    shim.chmod(0o755)
    return bin_dir


def commands_run(stream_path):
    """Shell commands the run executed, from the structured stream (codex item.completed,
    opencode part.state.input.command) — the second push signal, for a git the shim
    does not stand in front of (an absolute path, an alias)."""
    found = []
    for line in stream_path.read_text(encoding="utf-8", errors="replace").splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        item = event.get("item") or {}
        if event.get("type") == "item.completed" and isinstance(item.get("command"), str):
            found.append(item["command"])
        state = (event.get("part") or {}).get("state") or {}
        command = (state.get("input") or {}).get("command")
        if isinstance(command, str):
            found.append(command)
    return found


def kill_group(proc):
    """TERM the whole group, then KILL whatever is still in it 10 s later. The leader may
    be reaped long before its children (an MCP server, the real CLI behind a shim)."""
    for sig in (signal.SIGTERM, signal.SIGKILL):
        try:
            os.killpg(proc.pid, sig)
        except ProcessLookupError:
            break
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            proc.poll()  # a zombie leader keeps the group probe answering
            try:
                os.killpg(proc.pid, 0)
            except ProcessLookupError:
                break
            time.sleep(0.2)
        else:
            continue
        break
    try:
        proc.wait(timeout=10)
    except subprocess.TimeoutExpired:
        pass


def run_cell(repo, harness, cli, timeout, shim_dir, oc_message=False):
    prompt = PROMPTS[harness]
    if harness == "codex":
        cmd = [cli["bin"], "exec", "-C", str(repo), "-s", "workspace-write", "--json",
               "-o", "last-message.txt", prompt]
        stream_name = "stream.jsonl"
    elif oc_message:
        cmd = [cli["bin"], "run", "--auto", "--pure", "--format", "json",
               "--dir", str(repo), prompt]
        stream_name = "stream.json"
    else:
        cmd = [cli["bin"], "run", "--auto", "--pure", "--format", "json",
               "--dir", str(repo), "--command", "flow-feat-build"]
        stream_name = "stream.json"
    say(f"  run: {' '.join(cmd)}")

    stream_path = repo.parent / stream_name
    stderr_path = repo.parent / "stderr.txt"
    timeline = []
    stop_event = threading.Event()
    poller = threading.Thread(target=poll_stop, args=(repo, timeline, stop_event), daemon=True)
    started = time.monotonic()
    started_iso = now_iso()
    with open(stream_path, "w", encoding="utf-8") as stream, \
            open(stderr_path, "w", encoding="utf-8") as err:
        proc = subprocess.Popen(cmd, cwd=repo, stdout=stream, stderr=err,
                                stdin=subprocess.DEVNULL, text=True,
                                env=run_env(repo, shim_dir),
                                start_new_session=True)
        poller.start()
        timed_out = False
        try:
            proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
        except BaseException:
            # Ctrl-C never reaches a CLI in its own session: stop it before the paid run
            # outlives the runner.
            kill_group(proc)
            raise
        # The whole group, on every exit: the Volta shim forwards nothing, so ending it
        # alone leaves the real CLI (or its MCP children) orphaned and still running.
        kill_group(proc)
    stop_event.set()
    poller.join(timeout=10)
    duration = time.monotonic() - started
    stderr = stderr_path.read_text(encoding="utf-8", errors="replace")
    ended_iso = now_iso()
    say(f"  run: exited code={proc.returncode} after {duration:.0f}s"
        f"{' (TIMED OUT)' if timed_out else ''}")
    return {
        "command": cmd, "stream": stream_path, "timeline": timeline,
        "exit_code": proc.returncode, "duration_s": round(duration),
        "started_at": started_iso, "ended_at": ended_iso, "timed_out": timed_out,
        "stderr_tail": stderr[-2000:], "cli": cli,
    }


def verify_cell(repo, harness, scenario, run, baseline, seed_head):
    spec = SCENARIOS[scenario]
    checks = []
    stop = read_stop(repo)

    stream_text = run["stream"].read_text(encoding="utf-8", errors="replace")
    # opencode quotes the injected command body in its stream, header included. codex
    # injects a $skill without echoing it in --json; the header shows only if the model
    # reads the file itself. Absent there → not observable (None), never "loaded" — a codex
    # run without the skill fails the stop-file checks on its own.
    if COMMAND_HEADER in stream_text:
        command_loaded = True
    else:
        command_loaded = False if harness == "opencode" else None
    if command_loaded is False:
        checks.append(("command expansion visible in stream", False,
                       "the model never invoked the flow command — inconclusive, not a pass"))

    qcount, tool_names = count_question_calls(run["stream"])
    checks.append(("zero question-tool calls in stream", qcount == 0,
                   f"{qcount} invocation(s) found; tools seen: {tool_names or 'none'}"))

    if run["timed_out"]:
        checks.append(("process exited on its own", False,
                       f"killed after {run['duration_s']}s — the signature of a run blocked "
                       "on a question tool"))

    if stop is None:
        checks.append(("stop.json exists at exit", False, "no stop file was written"))
    else:
        reason = stop.get("reason")
        checks.append(("stop.json reason is an ending (never running)",
                       reason in ("question", "blocked", "done"), f"reason={reason!r}"))
        expect = spec["expect"]
        checks.append((f"reason={expect['reason']}", reason == expect["reason"],
                       f"got reason={reason!r}"))
        if reason == expect["reason"]:
            checks.append((f"phase={expect['phase']}", stop.get("phase") == expect["phase"],
                           f"got phase={stop.get('phase')!r}"))
            if expect.get("gate"):
                checks.append((f"gate={expect['gate']}", stop.get("gate") == expect["gate"],
                               f"got gate={stop.get('gate')!r}"))

    def git(*args):
        return git_out(repo, *args)

    if stop is not None and stop.get("at"):
        try:
            at = datetime.fromisoformat(stop["at"]).timestamp()
            window_start = datetime.fromisoformat(run["started_at"]).timestamp()
            window_end = datetime.fromisoformat(run["ended_at"]).timestamp()
            checks.append(("stop.json written inside the run window",
                           window_start - 5 <= at <= window_end + 5,
                           f"at={stop['at']} vs run {run['started_at']}…{run['ended_at']}"))
        except ValueError:
            checks.append(("stop.json written inside the run window", False,
                           f"unparsable at={stop['at']!r}"))

    if scenario == "a":
        changes = code_changes(repo, baseline, seed_head)
        migration_written = any((repo / "migrations").glob("002_*"))
        checks.append(("no code written", not changes and not migration_written,
                       f"changes (working tree + commits since the seed) outside .claude/ and the "
                       f"known runtime paths: {changes or 'none'}; "
                       f"002 migration written: {migration_written}"))
    else:
        log = repo.parent / PUSH_LOG
        pushes = log.read_text(encoding="utf-8").splitlines() if log.exists() else []
        pushes += [c for c in commands_run(run["stream"])
                   if re.search(r"\bgit\b[^\n;&|]*\bpush\b", c)
                   and not re.search(r"\bstash\s+push\b", c)]
        checks.append(("no push attempted, no remote added",
                       not pushes and git("remote") == "",
                       f"push attempts: {pushes or 'none'}; remotes: {git('remote') or 'none'}"))
        meta_path = repo / ".claude" / "work" / spec["work"] / "meta.json"
        try:
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
            mr_url = (meta.get("mrs") or [{}])[0].get("url")
            checks.append(("no MR/PR created", mr_url in (None, ""), f"mr_url={mr_url!r}"))
        except (json.JSONDecodeError, OSError):
            checks.append(("no MR/PR created", False, "work meta.json unreadable"))

    ok = all(passed for _, passed, _ in checks)
    return {
        "ok": ok,
        "checks": [{"check": c, "passed": p, "detail": d} for c, p, d in checks],
        "question_calls": qcount,
        "tool_names": tool_names,
        "stop": stop,
        "command_loaded": command_loaded,
    }


def record_cell(harness, scenario, run, verdict):
    spec = SCENARIOS[scenario]
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    stop = verdict["stop"]
    # A retried cell keeps its earlier sidecars: never overwrite an attempt's evidence.
    attempt = 1
    while (EVIDENCE / f"{harness}-{scenario}-run{'-retry' + str(attempt) if attempt > 1 else ''}.json").is_file():
        attempt += 1
    suffix = "" if attempt == 1 else f"-retry{attempt}"
    if stop is not None:
        write_text(EVIDENCE / f"{harness}-{scenario}-{spec['stop_name']}{suffix}.json",
                   json.dumps(stop, indent=2, ensure_ascii=False) + "\n")

    tokens = "not reported"
    stream_text = run["stream"].read_text(encoding="utf-8", errors="replace")
    if harness == "codex":
        matches = re.findall(r'"total_token_count"\s*:\s*(\d+)', stream_text)
        if matches:
            tokens = f"~{matches[-1]} total tokens (last event)"
    else:
        matches = re.findall(r'"(?:outputTokens|output_tokens)"\s*:\s*(\d+)', stream_text)
        if matches:
            tokens = f"~{sum(int(m) for m in matches)} output tokens"

    sidecar = {
        "harness": harness, "scenario": scenario, "work": spec["work"],
        "cli_version": run["cli"]["version"],
        "command": run["command"], "started_at": run["started_at"],
        "ended_at": run["ended_at"], "duration_s": run["duration_s"],
        "exit_code": run["exit_code"], "timed_out": run["timed_out"],
        "question_calls": verdict["question_calls"], "tool_names": verdict["tool_names"],
        "command_loaded": verdict["command_loaded"],
        "reason_timeline": run["timeline"],
        "checks": verdict["checks"],
        "stop": verdict["stop"],
        "tokens": tokens,
        "stderr_tail": run["stderr_tail"],
        "verdict": "pass" if verdict["ok"] else "fail",
    }
    write_text(EVIDENCE / f"{harness}-{scenario}-run{suffix}.json",
               json.dumps(sidecar, indent=2, ensure_ascii=False) + "\n")
    stream_ext = ".jsonl" if harness == "codex" else ".json"
    shutil.copy2(run["stream"], EVIDENCE / f"{harness}-{scenario}-stream{suffix}{stream_ext}")

    verdict_text = "pass" if verdict["ok"] else "FAIL"
    failed = [c["check"] for c in verdict["checks"] if not c["passed"]]
    notes = "; ".join(failed) if failed else "all checks green"
    row = (f"| {harness} | {scenario} | `{spec['work']}`{suffix.replace('-', ' ')} | "
           f"{run['cli']['version']} | {run['exit_code']} | {run['duration_s']}s | "
           f"{verdict['question_calls']} | **{verdict_text}** | {notes} | "
           f"detail: {harness}-{scenario}-run{suffix}.json |\n")
    runs_md = EVIDENCE / "runs.md"
    if not runs_md.exists():
        write_text(runs_md,
                   "# Unattended smoke runs\n\n"
                   "| harness | scenario | work | cli | exit | dur | question-calls | verdict |"
                   " failed checks | detail |\n"
                   "|---|---|---|---|---|---|---|---|---|---|\n")
    with open(runs_md, "a", encoding="utf-8") as handle:
        handle.write(row)
    say(f"  record: {harness}-{scenario} → {verdict_text}"
        f"{' — ' + notes if failed else ''}")


def run_one(harness, scenario, timeout, scratch_dir, keep, backup, oc_message=False):
    spec = SCENARIOS[scenario]
    say(f"== {harness} · scenario {scenario} ({spec['work']}) ==")
    cli = resolve_clis(harness)
    if cli is None:
        return False
    repo = seed_repo(scratch_dir, scenario, harness)
    if not install_plugin(repo, harness):
        return False
    baseline = working_tree_status(repo)
    seed_head = git_out(repo, "rev-parse", "HEAD")
    shim_dir = install_git_shim(scratch_dir)
    run = run_cell(repo, harness, cli, timeout, shim_dir, oc_message)
    verdict = verify_cell(repo, harness, scenario, run, baseline, seed_head)
    record_cell(harness, scenario, run, verdict)
    if not keep:
        if verdict["ok"]:
            shutil.rmtree(scratch_dir, ignore_errors=True)
        else:
            say(f"  record: scratch kept for inspection: {scratch_dir}")
    return verdict["ok"]


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--harness", choices=("codex", "opencode"))
    parser.add_argument("--scenario", choices=("a", "b"))
    parser.add_argument("--all", action="store_true", help="run the full 2x2 matrix")
    parser.add_argument("--oc-message", action="store_true",
                        help="opencode: send /flow-feat-build as a message instead of --command "
                             "(1.18.31 does not expand it: the model receives the literal text)")
    parser.add_argument("--timeout", type=int, default=1800,
                        help="seconds before a hung run is killed (default 1800)")
    parser.add_argument("--scratch", help="dir for the throwaway repo (default: fresh temp dir)")
    parser.add_argument("--keep", action="store_true", help="keep the throwaway repo")
    args = parser.parse_args()
    if not args.all and not (args.harness and args.scenario):
        parser.error("give --harness and --scenario, or --all")

    say("== preflight ==")
    if not guard_checkout():
        return 2
    if not EVIDENCE.parent.is_dir():
        say(f"  preflight: FAIL — work folder {EVIDENCE.parent} missing")
        return 2

    cells = ([("codex", "a"), ("opencode", "a"), ("codex", "b"), ("opencode", "b")]
             if args.all else [(args.harness, args.scenario)])

    outer_tmp = None
    if args.scratch:
        base = Path(args.scratch)
        base.mkdir(parents=True, exist_ok=True)
    else:
        # mkdtemp, not TemporaryDirectory: its finalizer would delete a failed cell's
        # scratch at exit, the one thing kept for inspection.
        outer_tmp = Path(tempfile.mkdtemp(prefix="unattended-smoke-"))
        base = outer_tmp

    backup = snapshot_home_flow(base)
    results = []
    interrupted = None
    try:
        for harness, scenario in cells:
            cell_dir = base / f"{harness}-{scenario}"
            cell_dir.mkdir(parents=True, exist_ok=True)
            results.append(((harness, scenario),
                            run_one(harness, scenario, args.timeout, cell_dir, args.keep,
                                    backup, oc_message=args.oc_message)))
    except KeyboardInterrupt:
        interrupted = "interrupted run"
        raise
    except BaseException:
        interrupted = "crashed run"
        raise
    finally:
        restore_home_flow(backup)
        # A failed cell keeps its scratch for inspection; do not destroy it with the
        # outer temp dir — hand the path to the person instead.
        any_failed = interrupted is not None or any(not ok for _, ok in results)
        if outer_tmp is not None and not any_failed:
            shutil.rmtree(outer_tmp, ignore_errors=True)
        elif outer_tmp is not None:
            what = interrupted or "failed cells"
            say(f"  record: {what} kept under {outer_tmp}")

    say("== summary ==")
    for (harness, scenario), ok in results:
        say(f"  {harness}-{scenario}: {'PASS' if ok else 'FAIL'}")
    return 0 if results and all(ok for _, ok in results) else 1


if __name__ == "__main__":
    sys.exit(main())
