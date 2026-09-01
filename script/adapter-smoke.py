#!/usr/bin/env python3
"""Smoke test for the three adapter mirrors (opencode · Codex · Gemini).

`check.py` asks whether a mirror *exists* (parity) and whether it is *older than the
command it mirrors* (freshness). Neither can catch a mirror that exists, is fresh, and
is wrong: condensed into a format its harness does not parse, teaching an invocation
prefix that harness does not use, or pointing at a file that is not there. Those are
the mistakes hand-condensing 14k lines actually produces, and until now the only thing
standing between them and a release was reading every file.

Two halves, both runnable without any of the three harnesses installed:

  static   the mirror is in the shape its harness reads — frontmatter or TOML, the right
           invocation prefix throughout, every path and every command it cites real
  install  `adapters/install.sh <tool>` is run against a throwaway HOME and the files are
           checked to land where that harness looks for them, in the expected number

    script/adapter-smoke.py                 # both halves
    script/adapter-smoke.py --static-only   # what check.py runs (no subprocesses, no HOME)
    script/adapter-smoke.py --quiet         # one `where: what` line per problem, nothing else
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile

try:
    import tomllib
except ModuleNotFoundError:                       # Python < 3.11
    tomllib = None

HERE = os.path.dirname(os.path.realpath(__file__))
ROOT = subprocess.run(["git", "rev-parse", "--show-toplevel"], cwd=HERE,
                      capture_output=True, text=True).stdout.strip() or os.path.dirname(HERE)

PLUGIN_COMMANDS = "plugins/flow/commands/"

# name, directory, extension, flatten, invocation separator the harness uses
ADAPTERS = (
    ("opencode", "adapters/opencode/commands/flow-", ".md", False, "-"),
    ("codex", "adapters/codex/prompts/flow-", ".md", False, "-"),
    ("gemini", "adapters/gemini/commands/flow/", ".toml", True, ":"),
)

problems = []


def fail(where, what):
    problems.append(f"{where}: {what}")


def tracked():
    """Tracked files **plus** untracked-but-not-ignored ones.

    `check.py` inspects only what git tracks, which is right for a release preflight.
    Here it was wrong: a mirror written and not yet `git add`ed is precisely the file
    that needs looking at, and skipping it made this script report a clean run over a
    brand-new command it had never opened. That happened on its first real use.
    """
    listings = (["git", "ls-files", "-z"],
                ["git", "ls-files", "-z", "-o", "--exclude-standard"])
    out = []
    for cmd in listings:
        raw = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True).stdout
        out += [f for f in raw.split("\0")
                if f and os.path.exists(os.path.join(ROOT, f))]
    return sorted(set(out))


def read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as fh:
        return fh.read()


def stems(files, prefix, suffix, flatten):
    out = {}
    for f in files:
        if f.startswith(prefix) and f.endswith(suffix):
            rel = f[len(prefix):-len(suffix)]
            out[rel.replace("/", "-") if flatten else rel] = f
    return out


# ---------------------------------------------------------------- static half

def check_format(name, path, body):
    """Each harness reads one shape, and only one. A mirror in the wrong shape is
    not a degraded mirror: opencode shows a command with no description, Codex
    prints the YAML as prose, Gemini does not load the file at all."""
    if name == "opencode":
        if not body.startswith("---\n"):
            fail(path, "opencode reads a `description:` frontmatter — this file has none")
            return
        fm = body.split("---\n", 2)
        if len(fm) < 3:
            fail(path, "frontmatter opened and never closed")
        elif not re.search(r"^description:\s*\S", fm[1], re.M):
            fail(path, "frontmatter has no non-empty `description:`")
    elif name == "codex":
        if body.startswith("---\n"):
            fail(path, "Codex prompts have no frontmatter — this one starts with a YAML block")
    elif name == "gemini":
        if tomllib is None:
            return
        try:
            data = tomllib.loads(body)
        except Exception as e:                    # noqa: BLE001 - reported, not handled
            fail(path, f"does not parse as TOML ({e})")
            return
        for key in ("description", "prompt"):
            if not isinstance(data.get(key), str) or not data[key].strip():
                fail(path, f"TOML is missing a non-empty `{key}`")


# `(?<![\w/])` keeps repo URLs out of it: `github.com/mashware/flow-workflows` is not
# an invocation, and reading it as one made this check cry wolf on every news mirror.
INVOCATION = re.compile(r"(?<![\w/])/flow(?P<sep>[-:])(?P<rest>[a-zA-Z0-9:*-]+)")


def check_invocations(name, path, body, sep, plugin_stems):
    """The one mistake hand-condensing produces most: a mirror that teaches the
    prefix of the harness it was condensed *from*. The user copies `/flow:feat:build`
    into opencode, gets nothing, and concludes the adapter is broken."""
    wrong = sep_other = ":" if sep == "-" else "-"
    cited = set()
    for m in INVOCATION.finditer(body):
        found, rest = m.group("sep"), m.group("rest")
        if found == wrong and not re.match(r"^[-:]?$", rest):
            fail(path, f"uses `/flow{found}{rest}` — {name} invokes with `{sep}`"
                       f" (`/flow{sep}...`)")
        if found == sep and "*" not in rest:
            cited.add(rest.replace(":", "-").replace("-", "-").strip("-"))
    for token in sorted(cited):
        if token in ("news", "init", "config", "doctor", "save-knowledge"):
            continue
        if token not in plugin_stems:
            fail(path, f"cites `/flow{sep}{token.replace('-', sep)}`, which is not a command")


PATH_REF = re.compile(r"(?:\.\./)*plugins/flow/[\w./{}-]+")


def check_paths(path, body):
    """A mirror that points at a file the plugin no longer has sends the reader
    somewhere empty — and these references are the only way an adapter can reach
    the canonical template and changelog."""
    for ref in set(PATH_REF.findall(body)):
        rel = re.sub(r"^(\.\./)+", "", ref).rstrip(".,)`")
        if "{" in rel or rel.endswith("/"):       # a pattern, not a path
            continue
        if not os.path.exists(os.path.join(ROOT, rel)):
            fail(path, f"references `{ref}`, which does not exist")


def static(files):
    plugin_stems = set(stems(files, PLUGIN_COMMANDS, ".md", True))
    if not plugin_stems:
        fail("adapters", "no plugin commands found — wrong repo root?")
    for name, prefix, suffix, flatten, sep in ADAPTERS:
        mirror = stems(files, prefix, suffix, flatten)
        if not mirror:
            fail(f"adapters/{name}", "no mirrored commands found at all")
        for stem, path in sorted(mirror.items()):
            body = read(path)
            if not body.strip():
                fail(path, "is empty")
                continue
            check_format(name, path, body)
            check_invocations(name, path, body, sep, plugin_stems)
            check_paths(path, body)


# --------------------------------------------------------------- install half

# tool → (path under HOME the harness reads, glob of what should land there)
LANDING = {
    "opencode": (".config/opencode/commands", "flow-*.md"),
    "gemini": (".gemini/commands/flow", "*.toml"),
    "codex": (".codex/prompts", "flow-*.md"),
}


def install(files):
    """The check the README could not make: run the installer and look at where the
    files ended up. It needs no harness — only the paths each one reads, which is
    exactly the thing that silently drifts between harness versions."""
    script = os.path.join(ROOT, "adapters/install.sh")
    if not os.access(script, os.X_OK):
        fail("adapters/install.sh", "is not executable")
        return
    for tool, (subdir, pattern) in LANDING.items():
        expected = len(stems(files, *[a[1:4] for a in ADAPTERS if a[0] == tool][0]))
        home = tempfile.mkdtemp(prefix=f"flow-smoke-{tool}-")
        try:
            env = dict(os.environ, HOME=home)
            run = subprocess.run(["bash", script, tool], cwd=os.path.join(ROOT, "adapters"),
                                 env=env, capture_output=True, text=True)
            if run.returncode != 0:
                fail(f"install.sh {tool}", f"exited {run.returncode}: "
                                           f"{(run.stderr or run.stdout).strip().splitlines()[-1:]}")
                continue
            dest = os.path.join(home, subdir)
            if not os.path.isdir(dest):
                fail(f"install.sh {tool}", f"installed nothing into ~/{subdir}")
                continue
            landed = []
            for dirpath, _dirs, names in os.walk(dest):
                landed += [n for n in names if re.fullmatch(pattern.replace("*", ".*"), n)]
            if len(landed) != expected:
                fail(f"install.sh {tool}",
                     f"{len(landed)} file(s) landed in ~/{subdir}, expected {expected}")
            changelog = os.path.join(home, ".claude/flow/CHANGELOG.md")
            if not os.path.exists(changelog):
                fail(f"install.sh {tool}", "did not place the changelog /flow-news reads")
        finally:
            shutil.rmtree(home, ignore_errors=True)


def main():
    quiet = "--quiet" in sys.argv
    files = tracked()
    static(files)
    if "--static-only" not in sys.argv:
        install(files)
    if problems:
        if quiet:
            print("\n".join(problems))
        else:
            print(f"✗ adapter smoke: {len(problems)} problem(s)\n")
            for p in problems:
                print(f"  {p}")
        return 1
    if not quiet:
        print("✓ adapter smoke: mirrors parse in their harness format, cite real commands "
              "and paths, and install where each harness looks")
    return 0


if __name__ == "__main__":
    sys.exit(main())
