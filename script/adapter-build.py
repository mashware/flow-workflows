#!/usr/bin/env python3
"""Generate the adapter mirrors (opencode · Codex · Gemini) from the plugin commands.

The mirrors used to be condensed by hand — 1.7 MB of near-verbatim copies that drifted
one release at a time. They are now build output: every file under
`adapters/<harness>/commands|prompts/` and every `adapters/<harness>/CORE.md` is
written by this script from `plugins/flow/commands/**/*.md` and
`plugins/flow/skills/flow-core/SKILL.md`. Edit the plugin, rebuild, commit both.

What changes per harness is mechanical, and only this:

  * the wrapper — opencode `description:` frontmatter, Codex a skill folder with a
    `name:`/`description:` `SKILL.md`, Gemini a TOML `description` + `prompt` string
    (backslashes and triple quotes escaped)
  * every `/flow…` invocation rewritten to that harness's sigil and separator
  * `$ARGUMENTS` → `{{args}}` for Gemini
  * the `flow:flow-core` skill pointer → the CORE.md file `install.sh` places under
    `~/.claude/flow/`, and `${CLAUDE_PLUGIN_ROOT}` → that same directory
  * a short legend after the title mapping the Claude Code primitives the prose names
    (`AskUserQuestion`, subagents, `ScheduleWakeup`, `TaskCreate`, `Skill …`) to what
    that harness has — the prose itself is left intact, so the logic is identical

    script/adapter-build.py            # (re)write every mirror
    script/adapter-build.py --check    # exit 1 if any mirror is missing, stale or orphaned
"""

import argparse
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.realpath(__file__))
ROOT = subprocess.run(["git", "rev-parse", "--show-toplevel"], cwd=HERE,
                      capture_output=True, text=True).stdout.strip() or os.path.dirname(HERE)

PLUGIN_COMMANDS = "plugins/flow/commands"
CORE_SKILL = "plugins/flow/skills/flow-core/SKILL.md"
STATE_DIR = "~/.claude/flow"

# Codex takes two shapes, not one, and both are generated here.
#
#   codex         standalone skills, installed by `install.sh` into `~/.codex/skills/`
#                 (or a repo's `.agents/skills/`): global names, so `flow-feat-start`,
#                 invoked `$flow-feat-start`, reading the shared rules from a file
#   codex-plugin  the same skills inside the plugin package, declared by
#                 `.codex-plugin/plugin.json`, so `codex plugin add flow@flow-plugins`
#                 installs them: Codex namespaces a plugin's skills, so the names lose
#                 the `flow-` prefix and are invoked `$flow:feat-start`, and the shared
#                 rules are a sibling skill (`$flow:flow-core`) rather than a file
#
# Both exist because Codex's importer for Claude-format plugins reads `skills/` and not
# `commands/`: it converts the commands itself and silently drops any whose rendered
# skill passes ~4 KB or whose body uses `$ARGUMENTS` — every command here but one.
#
#   path    where the mirror is written (`{flat}` = `feat-start`, `{stem}` = `feat/start`)
#   sep     the separator between an invocation's segments
#   head    what follows `flow` in an invocation, before the first segment
#   sigil   what an invocation starts with
#   args    what `$ARGUMENTS` becomes
#   core    where the shared rules land, and whether the body points at a file or a skill
TARGETS = {
    "opencode": {
        "path": "adapters/opencode/commands/flow-{flat}.md",
        "sep": "-", "head": "-", "sigil": "/", "args": "$ARGUMENTS",
        "core": ("file", "adapters/opencode/CORE.md"),
    },
    "codex": {
        "path": "adapters/codex/skills/flow-{flat}/SKILL.md",
        "sep": "-", "head": "-", "sigil": "$", "args": "$ARGUMENTS",
        "core": ("file", "adapters/codex/CORE.md"),
    },
    "codex-plugin": {
        "path": "plugins/flow/codex-skills/{flat}/SKILL.md",
        "sep": "-", "head": ":", "sigil": "$", "args": "$ARGUMENTS",
        "core": ("skill", "plugins/flow/codex-skills/flow-core/SKILL.md"),
    },
    "gemini": {
        "path": "adapters/gemini/commands/flow/{stem}.toml",
        "sep": ":", "head": ":", "sigil": "/", "args": "{{args}}",
        "core": ("file", "adapters/gemini/CORE.md"),
    },
}

# The Codex manifest that makes the package installable as a Codex plugin. Generated so
# its version can never drift from the Claude one; `skills` is what points Codex at the
# `codex-plugin` mirror instead of the plugin's own `skills/` folder.
CODEX_MANIFEST = "plugins/flow/.codex-plugin/plugin.json"
CLAUDE_MANIFEST = "plugins/flow/.claude-plugin/plugin.json"

# The primitives the plugin prose names, and what each harness has instead. The prose
# is not rewritten — a regex that edits sentences produces sentences nobody wrote — so
# the legend defines the terms once and the body keeps using them.
LEGEND = {
    "opencode": [
        "`AskUserQuestion` → ask in plain text with numbered options and wait for the reply.",
        "`Agent <role>` / `Agent general-purpose` / subagents → `@<name>` declared in `agents/<name>.md` (`mode: subagent`); the name comes from `agents.<role>` in `FLOW.md`, empty → do it in this context.",
        "Parallel fan-out → several `@name` in one prompt, capped at `agents.fanout_max` (empty → 4); `agents.fanout_tool` is Claude Code-only, ignore it.",
        "`ScheduleWakeup` / `Monitor` / `/loop` → not available in-session: run one cycle, persist state in `monitor.md`, let the user schedule `opencode run -p \"<command>\"` with cron.",
        "`TaskCreate` → a markdown checklist in the phase artifact.",
        "`Skill commit-commands:commit-push-pr` → `git add` · `git commit` · `git push -u origin HEAD` · the `git.cli` CLI (`gh pr create` / `glab mr create`).",
        "`/model <value>` → opencode's model picker (`/models`).",
        "`knowledge.*` roles → whatever tools `FLOW.md` names there; an MCP tool keeps its name, its server is declared in `opencode.json` (see this adapter's `opencode.json` for the domain-memory example).",
    ],
    "codex": [
        "`AskUserQuestion` → ask in plain text with numbered options and wait for the reply.",
        "`Agent <role>` / `Agent general-purpose` / subagents → the subagent declared under `[agents.<name>]` in `~/.codex/config.toml`; the name comes from `agents.<role>` in `FLOW.md`, empty → do it in this context.",
        "Parallel fan-out → several subagents in one response, capped at `agents.fanout_max` (empty → 4); `agents.fanout_tool` is Claude Code-only, ignore it.",
        "`ScheduleWakeup` / `Monitor` / `/loop` → not available in-session: run one cycle, persist state in `monitor.md`, let the user schedule `codex exec \"<command>\"` with cron or Codex automations.",
        "`TaskCreate` → a markdown checklist in the phase artifact.",
        "`Skill commit-commands:commit-push-pr` → `git add` · `git commit` · `git push -u origin HEAD` · the `git.cli` CLI (`gh pr create` / `glab mr create`).",
        "`/model <value>` → the `--model` flag at launch (or `/model` if your Codex version has it).",
        "`knowledge.*` roles → whatever tools `FLOW.md` names there; an MCP tool keeps its name, its server is declared under `[mcp_servers.<name>]` in `config.toml` (see `config.snippet.toml`).",
        "`$ARGUMENTS` → whatever the user typed after the skill name, empty if nothing — Codex substitutes nothing, so read it off their message.",
    ],
    "gemini": [
        "`AskUserQuestion` → ask in plain text with numbered options and wait for the reply.",
        "`Agent <role>` / `Agent general-purpose` / subagents → `@<name>` from `.gemini/agents/`; the name comes from `agents.<role>` in `FLOW.md`, empty or absent → do it in this context.",
        "Parallel fan-out → several `@name` in one turn (sequential in this context if none are configured), capped at `agents.fanout_max` (empty → 4); `agents.fanout_tool` is Claude Code-only, ignore it.",
        "`ScheduleWakeup` / `Monitor` / `/loop` → not available in-session: run one cycle, persist state in `monitor.md`, let the user schedule `gemini -p \"<command>\"` with cron.",
        "`TaskCreate` → a markdown checklist in the phase artifact.",
        "`Skill commit-commands:commit-push-pr` → `git add` · `git commit` · `git push -u origin HEAD` · the `git.cli` CLI (`gh pr create` / `glab mr create`).",
        "`/model <value>` → the `--model` flag at launch.",
        "`knowledge.*` roles → whatever tools `FLOW.md` names there; an MCP tool keeps its name, its server is declared under `mcpServers` in `settings.json` (see `settings.snippet.json`).",
    ],
}

# The packaged flavour says the same things as the standalone one, plus what being
# inside a plugin changes: the namespace, and the relative root the prose's paths hang off.
LEGEND["codex-plugin"] = LEGEND["codex"] + [
    "This skill is one of a plugin's, so every workflow here is invoked `$flow:<name>` — the shared rules are the sibling skill `$flow:flow-core`.",
    "`../..` in a path → the plugin root, two folders above the one this `SKILL.md` is in; Codex gives you this file's path.",
]

BANNER = ("GENERATED by script/adapter-build.py from {src} — do not edit; "
          "change the plugin file and run the script.")

SKILL_POINTER = re.compile(r"Load the `flow:flow-core` skill first \((?P<what>[^)]*)\) — skip if it is already in this session's context\.")


def read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as fh:
        return fh.read()


def split_frontmatter(text):
    if not text.startswith("---\n"):
        return "", text
    parts = text.split("---\n", 2)
    return (parts[1], parts[2]) if len(parts) == 3 else ("", text)


def description(frontmatter):
    m = re.search(r"^description:\s*(.+)$", frontmatter, re.M)
    return m.group(1).strip().strip('"') if m else ""


def plugin_stems():
    base = os.path.join(ROOT, PLUGIN_COMMANDS)
    out = {}
    for dirpath, _dirs, names in os.walk(base):
        for n in sorted(names):
            if n.endswith(".md"):
                stem = os.path.relpath(os.path.join(dirpath, n), base)[:-3]
                out[stem] = os.path.join(PLUGIN_COMMANDS, stem + ".md")
    return dict(sorted(out.items()))


def retarget(text, sep, flat_to_stem, sigil="/", head="-"):
    """Rewrite every `/flow…` invocation into this harness's prefix, both directions."""
    def to_dashes(m):
        return sigil + "flow" + head + m.group("rest").lstrip(":").replace(":", "-")

    def to_colons(m):
        real = flat_to_stem.get(m.group("rest").lstrip("-"))
        return m.group(0) if real is None else "/flow:" + real.replace("/", ":")

    if sep == "-":
        return re.sub(r"(?<![\w/])/flow(?P<rest>(?::[a-zA-Z0-9*-]+)+)", to_dashes, text)
    return re.sub(r"(?<![\w/])/flow(?P<rest>-[a-zA-Z0-9-]+)", to_colons, text)


def core_path(name):
    return f"{STATE_DIR}/CORE.{name}.md"


# `news` speaks of the plugin root as a variable — true in Claude Code, where it is one,
# and false everywhere else, where it is a path. The sentence is rewritten, not the term.
UNSET_ROOT = "`${CLAUDE_PLUGIN_ROOT}` unset or `CHANGELOG.md` missing"


def translate(body, name, spec, flat_to_stem):
    kind, _dest = spec["core"]
    body = body.replace(UNSET_ROOT, "`" + ("../.." if kind == "skill" else STATE_DIR)
                        + "/CHANGELOG.md` missing")
    if kind == "skill":
        # Inside the package the pointer already reads true: Codex namespaces a plugin's
        # skills, so the plugin's own `flow:flow-core` is what the sibling skill is called.
        body = body.replace("${CLAUDE_PLUGIN_ROOT}/skills/flow-core/SKILL.md", "../flow-core/SKILL.md")
        body = body.replace("${CLAUDE_PLUGIN_ROOT}", "../..")
    else:
        body = SKILL_POINTER.sub(
            # a function replacement expands no backreference: `\g<what>` here would ship literally
            lambda m: f"Read `{core_path(name)}` first ({m.group('what')}) — skip if you already read it in this session.", body)
        body = body.replace("`flow:flow-core` skill", f"`{core_path(name)}`")
        body = body.replace("${CLAUDE_PLUGIN_ROOT}/skills/flow-core/SKILL.md", core_path(name))
        body = body.replace("${CLAUDE_PLUGIN_ROOT}", STATE_DIR)
    if spec["args"] != "$ARGUMENTS":
        body = body.replace("$ARGUMENTS", spec["args"])
    return retarget(body, spec["sep"], flat_to_stem, spec["sigil"], spec["head"])


DISPLAY = {"codex-plugin": "codex plugin package"}


def legend(name, spec, flat_to_stem):
    lines = "\n".join(f"- {retarget(l, spec['sep'], flat_to_stem, spec['sigil'], spec['head'])}"
                      for l in LEGEND[name])
    return (f"> **{DISPLAY.get(name, name + ' adapter')} — how the Claude Code primitives "
            f"named below map here.**\n"
            + "\n".join("> " + l for l in lines.splitlines()) + "\n")


def render_command(name, stem, frontmatter, body, flat_to_stem):
    spec = TARGETS[name]
    desc = description(frontmatter)
    body = translate(body, name, spec, flat_to_stem).strip("\n")
    # the title already carries this harness's prefix (retarget ran on it); legend goes right after it
    body = re.sub(r"^(#\s+.*\n)", lambda m: m.group(1) + "\n" + legend(name, spec, flat_to_stem),
                  body, count=1, flags=re.M)
    src = f"{PLUGIN_COMMANDS}/{stem}.md"
    return wrap(name, desc, body, src, stem)


def render_core(name, flat_to_stem):
    fm, body = split_frontmatter(read(CORE_SKILL))
    spec = TARGETS[name]
    body = translate(body, name, spec, flat_to_stem).strip("\n")
    body = re.sub(r"^(#\s+.*\n)", lambda m: m.group(1) + "\n" + legend(name, spec, flat_to_stem),
                  body, count=1, flags=re.M)
    head = ""
    if spec["core"][0] == "skill":
        head = f"---\nname: flow-core\ndescription: \"{description(fm).replace(chr(34), chr(39))}\"\n---\n\n"
    return f"{head}<!-- {BANNER.format(src=CORE_SKILL)} -->\n\n{body}\n"


def wrap(name, desc, body, src, stem):
    banner = BANNER.format(src=src)
    if name == "opencode":
        return f"---\ndescription: {desc}\n---\n\n<!-- {banner} -->\n\n{body}\n"
    if name.startswith("codex"):
        # A plugin's skills are namespaced by Codex (`$flow:feat-start`); loose ones in
        # `~/.codex/skills/` share one namespace with everything else, so they keep the prefix.
        flat = stem.replace("/", "-")
        skill = flat if name == "codex-plugin" else "flow-" + flat
        return (f"---\nname: {skill}\ndescription: \"{desc.replace(chr(34), chr(39))}\"\n---\n\n"
                f"<!-- {banner} -->\n\n{body}\n")
    # Gemini: a TOML basic multi-line string. Backslashes are escapes there and a
    # triple quote would end the string, so both are escaped.
    escaped = body.replace("\\", "\\\\").replace('"""', '""\\"')
    return (f"# {banner}\n"
            f'description = "{desc.replace(chr(34), chr(39))}"\n\n'
            f'prompt = """\n{escaped}\n"""\n')


def expected():
    """Every mirror path → the content it should hold."""
    stems = plugin_stems()
    flat_to_stem = {s.replace("/", "-"): s for s in stems}
    out = {}
    for stem, src in stems.items():
        frontmatter, body = split_frontmatter(read(src))
        if not description(frontmatter):
            sys.exit(f"{src}: no `description:` in the frontmatter")
        for name, spec in TARGETS.items():
            rel = spec["path"].format(stem=stem, flat=stem.replace("/", "-"))
            out[rel] = render_command(name, stem, frontmatter, body, flat_to_stem)
    for name, spec in TARGETS.items():
        out[spec["core"][1]] = render_core(name, flat_to_stem)
    out[CODEX_MANIFEST] = codex_manifest()
    return out


def codex_manifest():
    """`.codex-plugin/plugin.json` — what makes `codex plugin add flow@flow-plugins` give
    a Codex user the whole workflow set instead of the one command its importer keeps."""
    claude = json.loads(read(CLAUDE_MANIFEST))
    manifest = {
        "name": claude["name"],
        "version": claude["version"],
        "description": claude["description"],
        "author": claude.get("author"),
        "homepage": claude.get("homepage"),
        "skills": "./codex-skills/",
    }
    return json.dumps({k: v for k, v in manifest.items() if v},
                      indent=2, ensure_ascii=False) + "\n"


# name → (directory walked for orphans, what counts as one of ours in it)
MIRROR_ROOTS = {
    "opencode": ("adapters/opencode/commands",
                 lambda rel: os.path.basename(rel).startswith("flow-") and rel.endswith(".md")),
    "codex": ("adapters/codex/skills",
              lambda rel: os.path.basename(rel) == "SKILL.md"
              and os.path.basename(os.path.dirname(rel)).startswith("flow-")),
    "codex-plugin": ("plugins/flow/codex-skills",
                     lambda rel: os.path.basename(rel) == "SKILL.md"),
    "gemini": ("adapters/gemini/commands/flow", lambda rel: rel.endswith(".toml")),
}


def on_disk():
    """Mirror files currently present (tracked or not), to catch orphans."""
    found = set()
    for name, (base, is_ours) in MIRROR_ROOTS.items():
        for dirpath, _d, names in os.walk(os.path.join(ROOT, base)):
            for n in names:
                rel = os.path.relpath(os.path.join(dirpath, n), ROOT)
                if is_ours(rel):
                    found.add(rel)
        core = TARGETS[name]["core"][1]
        if os.path.exists(os.path.join(ROOT, core)):
            found.add(core)
    if os.path.exists(os.path.join(ROOT, CODEX_MANIFEST)):
        found.add(CODEX_MANIFEST)
    return found


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true",
                    help="report mirrors that are missing, stale or orphaned; write nothing")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    want = expected()
    have = on_disk()
    problems = []
    for rel, content in want.items():
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            problems.append(f"{rel}: missing (run script/adapter-build.py)")
        elif read(rel) != content:
            problems.append(f"{rel}: out of date (run script/adapter-build.py)")
    for rel in sorted(have - set(want)):
        problems.append(f"{rel}: orphan — no plugin command generates it (delete it)")

    if args.check:
        for p in problems:
            print(p if args.quiet else f"  ✗ {p}")
        if not problems and not args.quiet:
            print(f"adapters ok — {len(want)} generated files match")
        return 1 if problems else 0

    for rel, content in want.items():
        path = os.path.join(ROOT, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(content)
    for rel in sorted(have - set(want)):
        os.remove(os.path.join(ROOT, rel))
        parent = os.path.dirname(os.path.join(ROOT, rel))
        if os.path.isdir(parent) and not os.listdir(parent):
            os.rmdir(parent)
        print(f"removed orphan {rel}")
    print(f"wrote {len(want)} files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
