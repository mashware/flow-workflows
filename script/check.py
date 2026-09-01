#!/usr/bin/env python3
"""Release preflight for this repo.

Every check here exists because something shipped broken. The plugin has no CI
and no test suite — a release is a tag on whatever is in the tree — so the tree
has to be able to say "this would not load" before a tag makes it permanent.

Run it by hand, or wire it as a pre-commit hook:

    ln -s ../../script/check.py .git/hooks/pre-commit
"""

import json
import os
import re
import subprocess
import sys

try:
    import tomllib
except ModuleNotFoundError:                       # Python < 3.11
    tomllib = None

def repo_root():
    """The checkout this script belongs to, however it was invoked.

    Wired as `.git/hooks/pre-commit` the script is reached through a symlink, so
    `abspath(__file__)` lands in `.git/hooks` and every git command below would
    run against a directory git does not track — reporting nothing to check and
    exiting green, which is worse than having no hook at all. Resolve the link
    first, then ask git where the top of the tree is.
    """
    here = os.path.dirname(os.path.realpath(__file__))
    top = subprocess.run(["git", "rev-parse", "--show-toplevel"], cwd=here,
                         capture_output=True, text=True)
    return top.stdout.strip() if top.returncode == 0 else os.path.dirname(here)


ROOT = repo_root()
MANIFEST = "plugins/flow/.claude-plugin/plugin.json"
MARKETPLACE = ".claude-plugin/marketplace.json"
CHANGELOG = "plugins/flow/CHANGELOG.md"

problems = []


def fail(where, what):
    problems.append(f"{where}: {what}")


def tracked_files():
    """Tracked paths that are actually on disk.

    A file can be tracked and absent — deleted but not yet committed — and every
    check below reads what it inspects. Dropping those here keeps the run from
    dying on the deletion, and the parity check still notices the gap.
    """
    out = subprocess.run(["git", "ls-files", "-z"], cwd=ROOT,
                         capture_output=True, text=True).stdout
    return [f for f in out.split("\0")
            if f and os.path.isfile(os.path.join(ROOT, f))]


def read(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as fh:
        return fh.read()


def check_no_empty_tracked_files(files):
    """A zero-byte manifest shipped in two releases and broke the whole plugin.

    It went unnoticed because nothing reads it except the loader — no example,
    no command, no parser in this repo touches it — so every other check passed
    while the plugin could not start.
    """
    for f in files:
        p = os.path.join(ROOT, f)
        if os.path.isfile(p) and os.path.getsize(p) == 0:
            fail(f, "tracked file is empty (0 bytes)")


def check_manifests():
    for path, required in ((MANIFEST, ("name", "version")),
                           (MARKETPLACE, ("plugins",))):
        try:
            data = json.loads(read(path))
        except FileNotFoundError:
            fail(path, "missing")
            continue
        except json.JSONDecodeError as e:
            fail(path, f"invalid JSON ({e})")
            continue
        for key in required:
            if not data.get(key):
                fail(path, f"missing or empty `{key}`")

    # Every plugin the marketplace advertises has to be on disk. A source that points
    # nowhere installs an empty plugin, and nothing else here would notice.
    try:
        entries = json.loads(read(MARKETPLACE)).get("plugins") or []
    except (FileNotFoundError, json.JSONDecodeError):
        return
    for entry in entries:
        source = entry.get("source") if isinstance(entry, dict) else None
        if isinstance(source, str) and not source.startswith(("http", "git@")):
            target = os.path.join(ROOT, source.lstrip("./"))
            if not os.path.exists(target):
                fail(MARKETPLACE, f"plugin source `{source}` does not exist")


def check_all_json(files):
    """Every tracked .json must parse — not only the two manifests.

    `hooks/hooks.json` is the one that matters most and was never checked: it is read
    by the loader alone, so a stray comma there ships a plugin whose hooks are simply
    absent, with every other check green.
    """
    for f in files:
        if not f.endswith(".json"):
            continue
        try:
            json.loads(read(f))
        except json.JSONDecodeError as e:
            fail(f, f"invalid JSON ({e})")


def check_hooks_executable(files):
    """A hook without its executable bit is a hook that does not run.

    Nothing reports it: the harness fires it, the shell refuses, and the guard that
    exists to stop a push to the main branch stops nothing.
    """
    for f in files:
        if f.startswith("plugins/flow/hooks/") and f.endswith(".sh"):
            if not os.access(os.path.join(ROOT, f), os.X_OK):
                fail(f, "hook is not executable (chmod +x)")


def check_version_matches_changelog():
    """The manifest version and the newest changelog heading must agree.

    `/flow:news` shows the user what changed since the version they had, and it
    reads the changelog while the loader reads the manifest. When the two drift,
    the release notes describe a version nobody is running.
    """
    try:
        version = json.loads(read(MANIFEST)).get("version")
    except (FileNotFoundError, json.JSONDecodeError):
        return                                     # already reported above
    try:
        changelog = read(CHANGELOG)
    except FileNotFoundError:
        fail(CHANGELOG, "missing")
        return
    m = re.search(r"^## v(\S+)", changelog, re.M)
    if not m:
        fail(CHANGELOG, "no `## vX.Y.Z` heading found")
    elif m.group(1) != version:
        fail(CHANGELOG, f"newest entry is v{m.group(1)} "
                        f"but {MANIFEST} says {version}")


def check_command_frontmatter(files):
    for f in files:
        if not (f.startswith("plugins/flow/commands/") and f.endswith(".md")):
            continue
        src = read(f)
        if not src.startswith("---\n"):
            fail(f, "command has no YAML frontmatter")
        elif "\n---\n" not in src[3:]:
            fail(f, "frontmatter is never closed")
        elif "description:" not in src[: src.index("\n---\n", 3)]:
            fail(f, "frontmatter has no `description:`")


def check_toml(files):
    if tomllib is None:
        # Every Gemini adapter command is a .toml. Skipping them silently on an older
        # Python reads exactly like having validated them.
        count = sum(1 for f in files if f.endswith(".toml"))
        print(f"  ! python < 3.11: {count} .toml file(s) NOT validated (no tomllib)")
        return
    for f in files:
        if f.endswith(".toml"):
            try:
                with open(os.path.join(ROOT, f), "rb") as fh:
                    tomllib.load(fh)
            except tomllib.TOMLDecodeError as e:
                fail(f, f"invalid TOML ({e})")


def check_embedded_json(files):
    """The ```json blocks inside commands are contracts the agent copies.

    Most of them are schematic — `<ticket>` placeholders, `"XS" | "S"` unions —
    and never meant to parse. But skipping every block that looks schematic
    skips the real ones too: the panel examples all carry an ellipsis in a URL,
    so an "ignore anything with …" rule would wave through a stray comma in the
    one block agents copy verbatim. So: normalise the ellipsis, try to parse,
    and only forgive a failure when the block genuinely holds placeholder
    syntax that no amount of care could make valid JSON.
    """
    schematic = re.compile(r"<[^>\n]*>|\"\s*\|\s*\"|\.\.\.,|^\s*\.\.\.\s*$", re.M)
    for f in files:
        if not f.endswith((".md", ".toml")):
            continue
        for block in re.findall(r"```json\n(.*?)\n```", read(f), re.S):
            text = block.replace("…", "...").strip()
            # some blocks quote one field of a larger object ("mrs": [ … ])
            candidates = [text] if text[:1] in "{[" else ["{" + text + "}"]
            for candidate in candidates:
                try:
                    data = json.loads(candidate)
                except json.JSONDecodeError as e:
                    if not schematic.search(block):
                        fail(f, f"embedded json block does not parse ({e})")
                    continue
                check_panel_vocabulary(f, data)


# The reader's vocabulary. A mark it does not know is not an error there — the
# line simply loses its symbol and its column and renders as plain text — which
# makes a typo in an example something no parse check would ever surface.
MARKS = {"done", "current", "pending", "wait", "block", "info"}
STYLES = {"normal", "dim", "title", "accent", "ok", "warn", "error"}


def check_panel_vocabulary(f, data):
    if not isinstance(data, dict) or not isinstance(data.get("lines"), list):
        return
    for line in data["lines"]:
        if not isinstance(line, dict):
            continue
        mark, style = line.get("mark"), line.get("style")
        if mark is not None and mark not in MARKS:
            fail(f, f"panel example uses unknown mark `{mark}`")
        if style is not None and style not in STYLES:
            fail(f, f"panel example uses unknown style `{style}`")
        if isinstance(line.get("text"), str) and "http" in line["text"]:
            fail(f, "panel example pastes a URL into `text` (use `link`)")


ADAPTERS = (
    ("opencode", "adapters/opencode/commands/flow-", ".md", False),
    ("codex", "adapters/codex/prompts/flow-", ".md", False),
    ("gemini", "adapters/gemini/commands/flow/", ".toml", True),
)
PLUGIN_COMMANDS = "plugins/flow/commands/"


def _stems(files, prefix, suffix, flatten):
    out = {}
    for f in files:
        if f.startswith(prefix) and f.endswith(suffix):
            rel = f[len(prefix):-len(suffix)]
            out[rel.replace("/", "-") if flatten else rel] = f
    return out


def check_adapter_parity(files):
    """Every plugin command must exist in all three adapters, and vice versa.

    Parity is maintained by hand, one file at a time, so the failure mode is a
    command that silently stops being mirrored rather than one that breaks. The
    reverse direction matters too: a command deleted from the plugin leaves three
    orphans behind that keep being installed.
    """
    plugin = _stems(files, PLUGIN_COMMANDS, ".md", True)
    for name, prefix, suffix, flatten in ADAPTERS:
        mirror = _stems(files, prefix, suffix, flatten)
        missing = set(plugin) - set(mirror)
        if missing:
            fail(f"adapters/{name}", "not mirrored: " + ", ".join(sorted(missing)))
        orphans = set(mirror) - set(plugin)
        if orphans:
            fail(f"adapters/{name}",
                 "mirrors a command the plugin no longer has: "
                 + ", ".join(sorted(orphans)))


EXCEPTIONS = "script/adapter-parity.exceptions"


def _last_commit(path, fmt):
    out = subprocess.run(["git", "log", "-1", f"--format={fmt}", "--", path],
                         cwd=ROOT, capture_output=True, text=True)
    return out.stdout.strip()


def _last_commit_time(path):
    return int(_last_commit(path, "%ct") or 0)


def _parity_exceptions():
    """Stems whose newest plugin commit was deliberately not mirrored.

    Keyed by stem → sha, so the entry only holds for that one commit: the next edit to
    the command moves the sha and the exception expires on its own.
    """
    out = {}
    try:
        src = read(EXCEPTIONS)
    except FileNotFoundError:
        return out
    for line in src.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) >= 2:
            out[parts[0]] = parts[1]
    return out


def _dirty_paths():
    out = subprocess.run(["git", "status", "--porcelain", "-z"], cwd=ROOT,
                         capture_output=True, text=True).stdout
    paths = set()
    for entry in out.split("\0"):
        if len(entry) > 3:
            paths.add(entry[3:])
    return paths


def check_adapter_freshness(files):
    """A mirror that exists is not a mirror that is current.

    Presence was the only thing checked here, so an adapter could sit five versions
    behind and the preflight stayed green — which is the failure this repo is most
    exposed to: 14k mirrored lines maintained by hand, and no generator. Rather than
    stamping every file with a version to be bumped by hand (another thing to forget),
    ask git: a plugin command edited more recently than its mirror is drift, and one
    edited in the working tree while the mirror is untouched is drift about to be
    committed. Same-commit edits — how this repo has always done it — are equal and
    pass.
    """
    dirty = _dirty_paths()
    excepted = _parity_exceptions()
    plugin = _stems(files, PLUGIN_COMMANDS, ".md", True)
    for name, prefix, suffix, flatten in ADAPTERS:
        mirror = _stems(files, prefix, suffix, flatten)
        stale = []
        for stem, src in sorted(plugin.items()):
            dst = mirror.get(stem)
            if dst is None:
                continue                            # already reported as not mirrored
            if src in dirty:
                if dst not in dirty:
                    stale.append(f"{stem} (edited here, mirror untouched)")
            elif dst not in dirty and _last_commit_time(src) > _last_commit_time(dst):
                granted = excepted.get(stem)
                if granted and _last_commit(src, "%h").startswith(granted[:7]):
                    continue                        # see script/adapter-parity.exceptions
                stale.append(f"{stem} (plugin newer)")
        if stale:
            fail(f"adapters/{name}", "mirror out of date: " + ", ".join(stale))


# Paragraphs of the phase preamble that must read identically everywhere. Excluded on
# purpose: the `Models` and `Autonomy` blocks, whose wording legitimately varies (each
# command names its own `models` key, and respond/green/query carry their own gates).
SHARED_BLOCKS = (
    "**Never a question in `guided`/`auto`",
    "**Reporting — how every stop reads.**",
    "**Product altitude — the effect, not the implementation.**",
    "**Short lines, not prose.**",
    "**Out of the chat, into the artifact**",
    "**Zero-context rule.**",
    "**If it is a question, it is `AskUserQuestion`.**",
    "**Live panel — the same stop, written to disk.**",
    "**`mark` says what a line *is*",
    "**`ref` need not be a number.**",
    "**`link` is a field, never text inside `text`.**",
    "**What goes in, in this order.**",
    "**When to write it.**",
    "**Rules.** `phase` is",
)


def check_shared_preamble(files):
    """The 18 phase commands carry the same preamble, copied by hand into each.

    Copying is deliberate — a command prompt has to be self-contained — but it means a
    change to the panel spec has to land in 18 files, and the one that gets missed is
    invisible: every file still reads plausibly on its own. So compare the copies and
    name the odd one out.
    """
    for marker in SHARED_BLOCKS:
        variants = {}
        for f in sorted(files):
            if not (f.startswith(PLUGIN_COMMANDS) and f.endswith(".md")):
                continue
            for line in read(f).splitlines():
                if line.startswith(marker):
                    variants.setdefault(line, []).append(f)
                    break
        if len(variants) < 2:
            continue
        majority = max(variants.values(), key=len)
        for holders in variants.values():
            if holders is majority:
                continue
            for f in holders:
                fail(f, f"shared preamble block `{marker[:40]}…` differs from the "
                        f"other {len(majority)} command(s)")


# Panel vocabulary that a previous generation of these commands used. The reader knows
# `mark`/`ref`; these labels render as plain prose, so a command still teaching them
# writes a panel that silently loses its column — and this is exactly where the spec
# already drifted once.
RETIRED_PANEL_LABELS = ("Right now:", "Waiting on you:", "under `Left`")


def check_panel_vocabulary_prose(files):
    for f in files:
        if not (f.startswith((PLUGIN_COMMANDS, "adapters/"))
                and f.endswith((".md", ".toml"))):
            continue
        src = read(f)
        for label in RETIRED_PANEL_LABELS:
            if label in src:
                fail(f, f"uses retired panel label `{label}` "
                        f"(the reader knows `mark`/`ref`: Now · Next · Decision)")


SMOKE = "script/adapter-smoke.py"


def check_adapter_smoke():
    """Delegate the "is this mirror actually usable" half to adapter-smoke.py.

    Parity and freshness answer whether a mirror exists and whether it is current.
    Neither can catch one that is fresh and wrong — the wrong wrapper for its harness,
    the other harness's invocation prefix, a path that is not there. That check lives in
    its own script because it also has an install half (running install.sh against a
    throwaway HOME) too slow for a pre-commit hook; only the static half runs here.
    """
    script = os.path.join(ROOT, SMOKE)
    if not os.path.exists(script):
        fail(SMOKE, "missing — the adapter smoke test is part of the preflight")
        return
    run = subprocess.run([sys.executable, script, "--static-only", "--quiet"],
                         cwd=ROOT, capture_output=True, text=True)
    if run.returncode == 0:
        return
    for line in (run.stdout or run.stderr).strip().splitlines():
        problems.append(line.strip())


def main():
    files = tracked_files()
    if not files:
        print("not a git checkout — nothing to check")
        return 0

    check_no_empty_tracked_files(files)
    check_manifests()
    check_all_json(files)
    check_hooks_executable(files)
    check_version_matches_changelog()
    check_command_frontmatter(files)
    check_toml(files)
    check_embedded_json(files)
    check_adapter_parity(files)
    check_adapter_freshness(files)
    check_adapter_smoke()
    check_shared_preamble(files)
    check_panel_vocabulary_prose(files)

    if problems:
        print("preflight failed:\n")
        for p in problems:
            print(f"  ✗ {p}")
        print(f"\n{len(problems)} problem(s).")
        return 1
    print(f"preflight ok — {len(files)} tracked files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
