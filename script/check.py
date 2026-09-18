#!/usr/bin/env python3
"""Release preflight for this repo.

Every check here exists because something shipped broken. The plugin has no CI
and no test suite — a release is a tag on whatever is in the tree — so the tree
has to be able to say "this would not load" before a tag makes it permanent.

Run it by hand, or wire it as a pre-commit hook:

    ln -s ../../script/check.py .git/hooks/pre-commit
"""

import glob
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
PACKAGE = "package.json"
CORE_SKILL = "plugins/flow/skills/flow-core/SKILL.md"

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


def check_example_config():
    """The worked example under `examples/<stack>/` must use keys that exist.

    `examples/symfony/FLOW.md` is a complete configuration a reader copies. A key
    renamed or retired in the template leaves it advertising a key nothing reads —
    the same drift `config-keys.py` prevents in the reference table, one directory
    over. `conventions` and `notes` are free text (any command id is a valid note
    key), so only their section headings are checked.
    """
    template = read("plugins/flow/examples/FLOW.template.md")
    known, section = {}, None
    for line in template.splitlines():
        if line.startswith("## "):
            section = line[3:].strip()
            known.setdefault(section, set())
        elif section:
            m = re.match(r"^- `([a-z_]+):`", line)
            if m:
                known[section].add(m.group(1))

    for rel in sorted(glob.glob(os.path.join(ROOT, "plugins/flow/examples/*/FLOW.md"))):
        rel = os.path.relpath(rel, ROOT)
        section = None
        for n, line in enumerate(read(rel).splitlines(), 1):
            if line.startswith("## "):
                section = line[3:].strip()
                if section not in known:
                    fail(rel, f"line {n}: section `{section}` is not in the template")
                continue
            if section in (None, "conventions", "notes"):
                continue
            m = re.match(r"^- ([a-z_]+):", line)
            if m and section in known and m.group(1) not in known[section]:
                fail(rel, f"line {n}: `{section}.{m.group(1)}` is not a key in the template")


def check_template_keys_are_read(files):
    """A key in the template that no command and no skill names is a key nothing reads.

    `models.study` and `models.test` were documented, printed by `/flow:doctor` and
    resolved by nobody for eight releases: the commands that were supposed to name
    them never did. A key costs a paragraph in the template, a row in CONFIGURATION,
    a branch in `init`, a row in `config` and a check in `doctor` — all of it wasted
    when the key is dead. Section-qualified (`git.host`) or bare (`host`) both count
    as naming it; the free-text sections have no fixed keys and are skipped.
    """
    free_text = {"conventions", "notes"}
    readers = "\n".join(
        read(f) for f in files
        if (f.startswith("plugins/flow/commands/") or f.startswith("plugins/flow/skills/"))
        and f.endswith(".md")
    )
    template = read("plugins/flow/examples/FLOW.template.md")
    section = None
    for line in template.splitlines():
        if line.startswith("## "):
            section = line[3:].strip()
            continue
        m = re.match(r"^- `([a-z_]+):`", line)
        if not m or section in free_text or section is None:
            continue
        key = m.group(1)
        if f"{section}.{key}" in readers or f"`{key}`" in readers or f"{{{key}}}" in readers:
            continue
        fail("plugins/flow/examples/FLOW.template.md",
             f"`{section}.{key}` is documented but no command or skill names it")


MODELS_CLAUSE_FORMS = (
    "**Models: this command runs with the model it was launched with (no `models` key).**",
    "**Models: the subagents it launches take `models.agents`.**",
    "**Models: the subagents it launches take `models.agents`; its parallel rounds take "
    "`models.workers`.**",
)


def check_models_clause(files):
    """A command's `Models:` clause may only name the two keys that exist.

    Fourteen commands announced *"Models key for this command: `review`"* for six
    releases after `models.study`/`code`/`test`/`review` were retired — pointing the
    reader at a key nothing reads. `check_template_keys_are_read` cannot see it: it
    walks template → commands, and the stale clause named the key bare (`` `review` ``),
    not qualified. So the clause itself is pinned to its three legal forms.
    """
    for f in files:
        if not f.startswith("plugins/flow/commands/") or not f.endswith(".md"):
            continue
        for n, line in enumerate(read(f).splitlines(), 1):
            if not line.startswith("Load the `flow:flow-core` skill first"):
                continue
            start = line.find("**Models")
            if start == -1:
                break
            clause = line[start:]
            if clause not in MODELS_CLAUSE_FORMS:
                fail(f, f"line {n}: `Models:` clause is not one of the three legal "
                        f"forms (only `models.agents` and `models.workers` exist)")
            break


def check_no_orphan_commands(files):
    """A command nothing links to is a command nobody runs.

    `/flow:save-knowledge` was invoked as a skill by `ship` and `postmortem` and
    linked from nowhere as a command: its standalone entry existed for a mid-work
    save that no other file mentioned. A command earns its file by being reachable
    — from another command, from `flow-core`, from `next`, or from the README's
    tables.
    """
    commands = [f for f in files
                if f.startswith("plugins/flow/commands/") and f.endswith(".md")
                and not f.endswith("/README.md")]
    corpus = "\n".join(
        read(f) for f in files
        if (f.startswith("plugins/flow/commands/") or f.startswith("plugins/flow/skills/")
            or f in ("README.md", "plugins/flow/README.md"))
        and f.endswith(".md")
    )
    for f in commands:
        rel = f[len("plugins/flow/commands/"):-len(".md")]
        invocation = "/flow:" + rel.replace("/", ":")
        # a command may not cite itself
        own = read(f)
        elsewhere = corpus.replace(own, "")
        if invocation not in elsewhere:
            fail(f, f"nothing links to `{invocation}` — no command, skill or README names it")


def check_hooks_executable(files):
    """A hook without its executable bit is a hook that does not run.

    Nothing reports it: the harness fires it, the shell refuses, and the guard that
    exists to stop a push to the main branch stops nothing.
    """
    for f in files:
        if f.startswith("plugins/flow/hooks/") and f.endswith(".sh"):
            if not os.access(os.path.join(ROOT, f), os.X_OK):
                fail(f, "hook is not executable (chmod +x)")


def check_hooks_have_tests(files):
    """A hook ships with its test, or it ships untested.

    The three hooks here are shell against a JSON event and a git checkout — the
    kind of code that works on the maintainer's machine and fails on a worktree,
    an empty repo or a missing `jq`. Each already has a case file under
    `script/tests/`; this is what stops the fourth one from arriving without.
    """
    tests = "\n".join(
        read(f) for f in files if f.startswith("script/tests/") and f.endswith(".sh")
    )
    for f in files:
        if f.startswith("plugins/flow/hooks/") and f.endswith(".sh"):
            if os.path.basename(f) not in tests:
                fail(f, "no file under script/tests/ exercises this hook")


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
    # A release candidate is the same tree as the release it precedes, tagged early so it
    # can be installed and run before it is `latest` (CONTRIBUTING §Testing a change before
    # it ships). Its changelog entry is already written under the final number, so the
    # manifest may carry a `-rc.N` suffix the changelog does not — and only that suffix.
    release, _, pre = version.partition("-") if version else ("", "", "")
    if pre and not re.fullmatch(r"rc\.[1-9][0-9]*", pre):
        fail(MANIFEST, f"version `{version}`: the only prerelease suffix this repo "
                       f"publishes is `-rc.N`")

    m = re.search(r"^## v(\S+)", changelog, re.M)
    if not m:
        fail(CHANGELOG, "no `## vX.Y.Z` heading found")
    elif m.group(1) != release:
        fail(CHANGELOG, f"newest entry is v{m.group(1)} "
                        f"but {MANIFEST} says {version}")


def check_version_is_one_number():
    """The manifest version, the npm package version and flow-core's own must agree.

    Three places state the version and each one is load-bearing. The commands pin the
    CLI to the manifest's number (`npx flow-workflows@<version>`), so a `package.json`
    that lags publishes a version those commands will ask for and not find — every
    `flow-workflows` call fails for the whole session. And `flow-core` states its own so
    a session can notice it is running commands from one copy of the plugin and shared
    rules from another; a stale number there makes that check fire on every clean run,
    which is how a warning stops being read.
    """
    try:
        version = json.loads(read(MANIFEST)).get("version")
    except (FileNotFoundError, json.JSONDecodeError):
        return                                     # already reported above
    if not version:
        return

    try:
        pkg = json.loads(read(PACKAGE)).get("version")
    except (FileNotFoundError, json.JSONDecodeError):
        fail(PACKAGE, "missing or unreadable")
    else:
        if pkg != version:
            fail(PACKAGE, f"version `{pkg}` but {MANIFEST} says `{version}` — the commands "
                          f"pin the CLI to the manifest's number, so npm must publish it")

    try:
        core = read(CORE_SKILL)
    except FileNotFoundError:
        return                                     # already reported above
    m = re.search(r"^\*\*This file belongs to flow `(\S+)`\.\*\*", core, re.M)
    if not m:
        fail(CORE_SKILL, "no `**This file belongs to flow `X.Y.Z`.**` line — a session "
                         "cannot tell a mixed install from a clean one without it")
    elif m.group(1) != version:
        fail(CORE_SKILL, f"states version `{m.group(1)}` but {MANIFEST} says `{version}`")


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


PLUGIN_COMMANDS = "plugins/flow/commands/"
BUILD = "script/adapter-build.py"


def check_adapters_generated():
    """The adapter mirrors are build output, not source.

    They used to be condensed by hand, and the checks here asked whether a mirror
    existed and whether it was older than its command — neither could catch one that
    was present, current and wrong. Now `script/adapter-build.py` writes every mirror
    from the plugin command, and the only question left is whether someone edited the
    plugin and forgot to rebuild (or edited a mirror by hand, which the rebuild will
    undo). `--check` renders everything in memory and compares.
    """
    script = os.path.join(ROOT, BUILD)
    if not os.path.exists(script):
        fail(BUILD, "missing — the adapters are generated by it")
        return
    run = subprocess.run([sys.executable, script, "--check", "--quiet"],
                         cwd=ROOT, capture_output=True, text=True)
    if run.returncode == 0:
        return
    for line in (run.stdout or run.stderr).strip().splitlines():
        problems.append(line.strip())


# Blocks that live in the flow-core skill and nowhere else. A command that carries a
# copy again is the drift this repo used to have 18 times over: the copy reads fine on
# its own and silently disagrees with the skill.
CORE_SKILL = "plugins/flow/skills/flow-core/SKILL.md"
CORE_ONLY_BLOCKS = (
    "**Never a question in `guided`/`auto`",
    "**Reporting — how every stop reads.**",
    "**Product altitude — the effect, not the implementation.**",
    "**Zero-context rule.**",
    "**Live panel — the same stop, written to disk.**",
    "**`mark` says what a line *is*",
    "**`link` is a field, never text inside `text`.**",
    "**When to write it.**",
)


def check_core_skill(files):
    if CORE_SKILL not in files:
        fail(CORE_SKILL, "missing — every command points at it")
        return
    src = read(CORE_SKILL)
    if not src.startswith("---\n") or "\nname: flow-core" not in src[:400]:
        fail(CORE_SKILL, "skill frontmatter must declare `name: flow-core`")
    for f in files:
        if not (f.startswith(PLUGIN_COMMANDS) and f.endswith(".md")):
            continue
        body = read(f)
        for marker in CORE_ONLY_BLOCKS:
            if marker in body:
                fail(f, f"carries a copy of a flow-core block (`{marker[:40]}…`) — "
                        f"point at the skill instead")


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


CONFIG_KEYS = "script/config-keys.py"


def check_config_keys():
    """`FLOW.md` keys are documented twice — the template and docs/CONFIGURATION.md —
    and the two drifted. The table in the reference is now generated from the template
    by `script/config-keys.py`; `--check` says whether it was regenerated."""
    script = os.path.join(ROOT, CONFIG_KEYS)
    if not os.path.exists(script):
        fail(CONFIG_KEYS, "missing")
        return
    run = subprocess.run([sys.executable, script, "--check"], cwd=ROOT,
                         capture_output=True, text=True)
    if run.returncode != 0:
        for line in (run.stdout or run.stderr).strip().splitlines():
            problems.append(line.strip())


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


# --- stack-agnosticism ---------------------------------------------------------------
# "Stack-agnostic" is the README's first claim and nothing in the tree enforced it.
#
# The invariant is not "never name a tool": `/flow:init` has to recognise eleven
# ecosystems to propose anything, and `doctor`, `green`, `fix` and `review` all say
# "auto-discover from Makefile / npm / composer / Gradle / dotnet / …". Naming many is
# how the plugin stays neutral. The invariant is "never depend on ONE" — so a line that
# names tools from a single ecosystem, with no second ecosystem beside it, is the shape
# a dependency arrives in, and that is what this check rejects.
#
# Three places may name one stack on purpose: `examples/`, which exists to be one
# stack's answer; the delimited detection table in `init.md`; and any line pointing a
# reader at `examples/<stack>/`.
STACK_FAMILIES = {
    "php": r"phpstan|php-cs-fixer|phpunit|composer|symfony|laravel|doctrine",
    "node": r"\bnpm\b|\bnpx\b|package-lock|pnpm|\byarn\b|eslint|vitest|\bjest\b",
    "python": r"pytest|pyproject|\bruff\b|\bmypy\b|tox\.ini|alembic",
    "ruby": r"bundle exec|Gemfile|rubocop|\brails\b",
    "rust": r"Cargo\.toml|cargo test|cargo clippy|clippy",
    "jvm": r"gradlew|gradle|\bmvn\b|pom\.xml|detekt|ktlint",
    "dotnet": r"dotnet|csproj|\.sln\b|nuget",
    "apple": r"xcode|Package\.swift|swiftlint|swift test",
    "dart": r"pubspec|flutter|dart format",
    "go": r"go\.mod|go test|golangci",
}

# npm is this project's own stack: `bin/cli.mjs` is an npm package and the plugin README
# documents `npx flow-workflows`. So node counts towards a line's plurality but never
# trips the check on its own — the alternative is either a false positive on every line
# describing our own install, or losing "npm / composer" as a valid detection pair.
OWN_STACK = "node"

STACK_SCOPES = ("plugins/", "bin/")
STACK_EXEMPT_DIRS = ("plugins/flow/examples/",)
STACK_EXEMPT_FILES = ("plugins/flow/CHANGELOG.md",)
DETECTION_START = "stack-detection:start"
DETECTION_END = "stack-detection:end"


def _stack_families(line, families):
    return {name for name, pattern in families.items()
            if re.search(pattern, line, re.IGNORECASE)}


def check_no_stack_leak(files):
    """A plugin that assumes one ecosystem stops being the thing it advertises.

    Held by discipline alone until now, and the CLI work ahead — a context bundle, a
    review runner — is exactly where a hardcoded `composer.lock` or a linter-specific
    `--error-format` slips in without anyone noticing.
    """
    for f in files:
        if not f.startswith(STACK_SCOPES):
            continue
        if f.startswith(STACK_EXEMPT_DIRS) or f in STACK_EXEMPT_FILES:
            continue
        if not f.endswith((".md", ".mjs", ".js", ".json", ".sh", ".toml")):
            continue

        # In `bin/` there is no prose to make plural: a default hardcoded there is the
        # leak itself, so one family is one too many — the list belongs in `FLOW.md`.
        code = f.startswith("bin/")
        families = ({k: v for k, v in STACK_FAMILIES.items() if k != OWN_STACK}
                    if code else STACK_FAMILIES)

        inside_detection = False
        for n, line in enumerate(read(f).splitlines(), 1):
            if DETECTION_START in line:
                inside_detection = True
                continue
            if DETECTION_END in line:
                inside_detection = False
                continue
            if inside_detection or "examples/" in line:
                continue
            found = _stack_families(line, families)
            if not found:
                continue
            if not code and found == {OWN_STACK}:
                continue
            named = ', '.join(sorted(found))
            if code:
                fail(f"{f}:{n}",
                     f"the CLI names an ecosystem ({named}) — it reads `FLOW.md` keys "
                     f"and runs what they say; it never knows which stack it is in")
            elif len(found) == 1:
                fail(f"{f}:{n}",
                     f"names one ecosystem ({named}) on its own — a tool name belongs "
                     f"in a `FLOW.md` key, or beside the other stacks of a detection list")


def main():
    files = tracked_files()
    if not files:
        print("not a git checkout — nothing to check")
        return 0

    check_no_empty_tracked_files(files)
    check_manifests()
    check_all_json(files)
    check_example_config()
    check_template_keys_are_read(files)
    check_models_clause(files)
    check_no_orphan_commands(files)
    check_hooks_executable(files)
    check_hooks_have_tests(files)
    check_version_matches_changelog()
    check_version_is_one_number()
    check_command_frontmatter(files)
    check_toml(files)
    check_embedded_json(files)
    check_adapters_generated()
    check_adapter_smoke()
    check_core_skill(files)
    check_config_keys()
    check_panel_vocabulary_prose(files)
    check_no_stack_leak(files)

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
