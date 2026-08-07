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
    m = re.search(r"^## v(\S+)", read(CHANGELOG), re.M)
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


def check_adapter_parity(files):
    """Every plugin command must exist in all three adapters.

    Parity is maintained by hand, one file at a time, so the failure mode is a
    command that silently stops being mirrored rather than one that breaks.
    """
    def stems(prefix, suffix, flatten):
        out = set()
        for f in files:
            if f.startswith(prefix) and f.endswith(suffix):
                rel = f[len(prefix):-len(suffix)]
                out.add(rel.replace("/", "-") if flatten else rel)
        return out

    plugin = stems("plugins/flow/commands/", ".md", True)
    for name, prefix, suffix, flatten in (
        ("opencode", "adapters/opencode/commands/flow-", ".md", False),
        ("codex", "adapters/codex/prompts/flow-", ".md", False),
        ("gemini", "adapters/gemini/commands/flow/", ".toml", True),
    ):
        missing = plugin - stems(prefix, suffix, flatten)
        if missing:
            fail(f"adapters/{name}", "not mirrored: " + ", ".join(sorted(missing)))


def main():
    files = tracked_files()
    if not files:
        print("not a git checkout — nothing to check")
        return 0

    check_no_empty_tracked_files(files)
    check_manifests()
    check_version_matches_changelog()
    check_command_frontmatter(files)
    check_toml(files)
    check_embedded_json(files)
    check_adapter_parity(files)

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
