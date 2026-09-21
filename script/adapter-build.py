#!/usr/bin/env python3
"""Generate the adapter mirrors (opencode · Codex · Gemini · Hermes · zcode) from the plugin commands.

The mirrors used to be condensed by hand — 1.7 MB of near-verbatim copies that drifted
one release at a time. They are now build output: every file under
`adapters/<harness>/commands|prompts/` and every `adapters/<harness>/CORE.md` is
written by this script from `plugins/flow/commands/**/*.md` and
`plugins/flow/skills/flow-core/SKILL.md`. Edit the plugin, rebuild, commit both.

What changes per harness is mechanical, and only this:

  * the wrapper — opencode `description:` frontmatter, Codex and Hermes a skill folder
    with a `name:`/`description:` `SKILL.md`, Gemini a TOML `description` + `prompt`
    string (backslashes and triple quotes escaped)
  * every `/flow…` invocation rewritten to that harness's sigil and separator
  * `$ARGUMENTS` → `{{args}}` for Gemini
  * `--harness claude` on a `flow-workflows` call → that harness's own overlay name,
    because the flag names the `FLOW.<harness>.md` the CLI merges and a mirror that
    kept `claude` would read another harness's overrides, or none
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
#
# Hermes reads the same skill shape as Codex — a folder with a `SKILL.md` keyed by
# `name:`, the agentskills.io layout — from `~/.hermes/skills/`, and invokes it with a
# slash like opencode: `/flow-feat-start`. So it is Codex's wrapper on opencode's sigil.
#
# zcode reads this package's Claude format directly — `.zcode-plugin/plugin.json` first,
# then `.claude-plugin/plugin.json` — and exposes the same primitives under the same
# names, so its mirror is the Claude page with two changes and no translation at all:
#
#   * `--harness zcode`, because the overlay is `FLOW.zcode.md`
#   * a `flow/` folder above the command tree: zcode names a command after its path
#     under the root it was found in and adds no plugin prefix, so `feat/start.md`
#     alone would be `/feat:start` — a name that collides with the user's own and with
#     zcode's built-ins (`/init`, `/doctor`). Nested one level down it is
#     `/flow:feat:start`, which is what every page here already says to type.
#
# The shared rules are not mirrored: zcode qualifies a plugin's skills by plugin name,
# so the plugin's own `flow:flow-core` is what the pointer already names.
TARGETS = {
    "opencode": {
        "path": "adapters/opencode/commands/flow-{flat}.md",
        "sep": "-", "head": "-", "sigil": "/", "args": "$ARGUMENTS", "overlay": "opencode",
        "core": ("file", "adapters/opencode/CORE.md"),
    },
    "codex": {
        "path": "adapters/codex/skills/flow-{flat}/SKILL.md",
        "sep": "-", "head": "-", "sigil": "$", "args": "$ARGUMENTS", "overlay": "codex",
        "core": ("file", "adapters/codex/CORE.md"),
    },
    "codex-plugin": {
        "path": "plugins/flow/codex-skills/{flat}/SKILL.md",
        "sep": "-", "head": ":", "sigil": "$", "args": "$ARGUMENTS", "overlay": "codex",
        "core": ("skill", "plugins/flow/codex-skills/flow-core/SKILL.md"),
    },
    "zcode": {
        "path": "plugins/flow/zcode-commands/flow/{stem}.md",
        "sep": ":", "head": ":", "sigil": "/", "args": "$ARGUMENTS", "overlay": "zcode",
        "core": ("plugin", None),
    },
    "gemini": {
        "path": "adapters/gemini/commands/flow/{stem}.toml",
        "sep": ":", "head": ":", "sigil": "/", "args": "{{args}}", "overlay": "gemini",
        "core": ("file", "adapters/gemini/CORE.md"),
    },
    "hermes": {
        "path": "adapters/hermes/skills/flow-{flat}/SKILL.md",
        "sep": "-", "head": "-", "sigil": "/", "args": "$ARGUMENTS", "overlay": "hermes",
        "core": ("file", "adapters/hermes/CORE.md"),
    },
}

# The harnesses whose wrapper is a skill folder keyed by `name:`. Codex reads them from
# `~/.codex/skills`, Hermes from `~/.hermes/skills`; the file is the same shape in both.
SKILL_SHAPED = ("codex", "codex-plugin", "hermes")

# The Codex manifest that makes the package installable as a Codex plugin. Generated so
# its version can never drift from the Claude one; `skills` is what points Codex at the
# `codex-plugin` mirror instead of the plugin's own `skills/` folder.
CODEX_MANIFEST = "plugins/flow/.codex-plugin/plugin.json"
ZCODE_MANIFEST = "plugins/flow/.zcode-plugin/plugin.json"
CLAUDE_MANIFEST = "plugins/flow/.claude-plugin/plugin.json"
NPM_MANIFEST = "package.json"

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
    "hermes": [
        "`AskUserQuestion` → ask in plain text with numbered options and wait for the reply.",
        "`Agent <role>` / `Agent general-purpose` / subagents → `delegate_task`, which creates the child on the spot from the `goal` and `context` you give it: the name in `agents.<role>` in `FLOW.md` is a role to state in that prompt, not an agent to declare anywhere; empty → do it in this context.",
        "Parallel fan-out → several `delegate_task` calls in one response, capped at `agents.fanout_max` (empty → 4) and, above that, by `delegation.max_concurrent_children` in `config.yaml` (default 10); `agents.fanout_tool` is Claude Code-only, ignore it.",
        "`ScheduleWakeup` / `Monitor` / `/loop` → Hermes schedules itself: the `cronjob` tool, or `/cron add \"every 30m\" \"<this command>\"`. Each firing is a fresh session with no history, so the state still lives in `monitor.md` and the scheduled text must stand alone; retiring the job from inside a firing needs `cron.allow_agent_scheduling: true`.",
        "`TaskCreate` → a markdown checklist in the phase artifact.",
        "`Skill commit-commands:commit-push-pr` → `git add` · `git commit` · `git push -u origin HEAD` · the `git.cli` CLI (`gh pr create` / `glab mr create`).",
        "`/model <value>` → Hermes's own `/model`; a subagent's model is `delegation.model` in `config.yaml`, one value for every child of a round.",
        "`knowledge.*` roles → whatever tools `FLOW.md` names there; an MCP tool keeps its name, its server is declared under `mcp_servers` in `~/.hermes/config.yaml` (see `config.snippet.yaml`).",
        "`$ARGUMENTS` → what the user typed after the skill name: Hermes takes everything from the first non-skill token on as the instruction.",
    ],
    "zcode": [
        "Every primitive named below exists here under the same name — `AskUserQuestion`, `Agent <role>` and its subagents, `ScheduleWakeup`, `TaskCreate`, `Skill flow:<name>`, `$ARGUMENTS`, `${CLAUDE_PLUGIN_ROOT}` (`${ZCODE_PLUGIN_ROOT}` is an alias). Nothing in this page is a translation of anything.",
        "The overlay read here is `FLOW.zcode.md`, and every `flow-workflows` call below already names it. The same plugin also exposes its unprefixed Claude pages — `/feat:start`, `/bug:fix`, … — which name Claude's overlay instead, so type the `/flow:` names.",
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
    # `plugin`: the mirror ships inside the package the prose was written for, so every
    # pointer in it already reads true — the plugin root is a variable in zcode too, and
    # `flow:flow-core` is what zcode calls the plugin's own skill. Rewriting either would
    # be the only thing able to break them.
    if kind != "plugin":
        body = body.replace(UNSET_ROOT, "`" + ("../.." if kind == "skill" else STATE_DIR)
                            + "/CHANGELOG.md` missing")
    if kind == "skill":
        # Inside the package the pointer already reads true: Codex namespaces a plugin's
        # skills, so the plugin's own `flow:flow-core` is what the sibling skill is called.
        body = body.replace("${CLAUDE_PLUGIN_ROOT}/skills/flow-core/SKILL.md", "../flow-core/SKILL.md")
        body = body.replace("${CLAUDE_PLUGIN_ROOT}", "../..")
    elif kind == "file":
        body = SKILL_POINTER.sub(
            # a function replacement expands no backreference: `\g<what>` here would ship literally
            lambda m: f"Read `{core_path(name)}` first ({m.group('what')}) — skip if you already read it in this session.", body)
        body = body.replace("`flow:flow-core` skill", f"`{core_path(name)}`")
        body = body.replace("${CLAUDE_PLUGIN_ROOT}/skills/flow-core/SKILL.md", core_path(name))
        body = body.replace("${CLAUDE_PLUGIN_ROOT}", STATE_DIR)
    if spec["args"] != "$ARGUMENTS":
        body = body.replace("$ARGUMENTS", spec["args"])
    # `--harness` names which `FLOW.<name>.md` the CLI merges on top of the base. The plugin
    # page is Claude Code's, so it carries `claude`; a mirror that shipped that value would
    # hand every other harness either someone else's overrides or, where no such file exists,
    # the base alone while the pack's header reports an overlay was read.
    body = body.replace("--harness claude", "--harness " + spec["overlay"])
    return retarget(body, spec["sep"], flat_to_stem, spec["sigil"], spec["head"])


DISPLAY = {"codex-plugin": "codex plugin package", "zcode": "zcode plugin package"}


def legend(name, spec, flat_to_stem):
    lines = "\n".join(f"- {retarget(l, spec['sep'], flat_to_stem, spec['sigil'], spec['head'])}"
                      for l in LEGEND[name])
    headline = ("the Claude Code primitives named below are the ones this harness has"
                if spec["core"][0] == "plugin"
                else "how the Claude Code primitives named below map here")
    return (f"> **{DISPLAY.get(name, name + ' adapter')} — {headline}.**\n"
            + "\n".join("> " + l for l in lines.splitlines()) + "\n")


def render_command(name, stem, frontmatter, body, flat_to_stem):
    spec = TARGETS[name]
    desc = description(frontmatter)
    body = translate(body, name, spec, flat_to_stem).strip("\n")
    # the title already carries this harness's prefix (retarget ran on it); legend goes right after it
    body = re.sub(r"^(#\s+.*\n)", lambda m: m.group(1) + "\n" + legend(name, spec, flat_to_stem),
                  body, count=1, flags=re.M)
    src = f"{PLUGIN_COMMANDS}/{stem}.md"
    return wrap(name, desc, body, src, stem, frontmatter)


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


def wrap(name, desc, body, src, stem, frontmatter=""):
    banner = BANNER.format(src=src)
    if name == "zcode":
        # zcode reads this exact frontmatter, `argument-hint` included, so it is carried
        # over rather than rebuilt from `description` alone.
        return f"---\n{frontmatter.strip()}\n---\n\n<!-- {banner} -->\n\n{body}\n"
    if name == "opencode":
        return f"---\ndescription: {desc}\n---\n\n<!-- {banner} -->\n\n{body}\n"
    if name in SKILL_SHAPED:
        # A plugin's skills are namespaced by Codex (`$flow:feat-start`); loose ones in
        # `~/.codex/skills/` — and every Hermes skill — share one namespace with
        # everything else installed, so they keep the prefix.
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
        if spec["core"][0] == "plugin":
            continue                          # zcode reads the plugin's own flow-core skill
        out[spec["core"][1]] = render_core(name, flat_to_stem)
    out[CODEX_MANIFEST] = codex_manifest()
    out[ZCODE_MANIFEST] = zcode_manifest()
    out[NPM_MANIFEST] = npm_manifest()
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


def zcode_manifest():
    """`.zcode-plugin/plugin.json` — zcode looks for this file before
    `.claude-plugin/plugin.json`, and declaring `commands` here is what adds the
    `zcode-commands/` mirror to the roots it scans. The plugin's own `commands/` and
    `skills/` are picked up anyway, by being where zcode looks by default: the mirror is
    an addition, so `/flow:feat:start` is the zcode name and the unprefixed Claude pages
    stay reachable under their own."""
    claude = json.loads(read(CLAUDE_MANIFEST))
    manifest = {
        "name": claude["name"],
        "version": claude["version"],
        "description": claude["description"],
        "author": claude.get("author"),
        "homepage": claude.get("homepage"),
        "commands": "./zcode-commands/",
    }
    return json.dumps({k: v for k, v in manifest.items() if v},
                      indent=2, ensure_ascii=False) + "\n"


def npm_manifest():
    """`package.json` — `npx flow-workflows install <harness>` for the harnesses with no
    marketplace of their own. `files` carries the adapters plus the three plugin files
    `bin/cli.mjs` reads at install time; the version is the plugin's, never its own."""
    claude = json.loads(read(CLAUDE_MANIFEST))
    manifest = {
        "name": "flow-workflows",
        "version": claude["version"],
        "description": claude["description"],
        "type": "module",
        "bin": {"flow-workflows": "bin/cli.mjs"},
        "files": [
            "bin/",
            "adapters/",
            "plugins/flow/CHANGELOG.md",
            "plugins/flow/.claude-plugin/plugin.json",
            "plugins/flow/examples/FLOW.template.md",
        ],
        "engines": {"node": ">=18"},
        "keywords": ["workflow", "code-review", "opencode", "gemini-cli", "codex",
                     "hermes", "zcode", "coding-agent", "feature-flow", "bug-flow"],
        "author": claude.get("author"),
        "license": "MIT",
        "homepage": claude.get("homepage"),
        "repository": {"type": "git", "url": "git+https://github.com/mashware/flow-workflows.git"},
        "bugs": {"url": "https://github.com/mashware/flow-workflows/issues"},
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
    "zcode": ("plugins/flow/zcode-commands", lambda rel: rel.endswith(".md")),
    "gemini": ("adapters/gemini/commands/flow", lambda rel: rel.endswith(".toml")),
    "hermes": ("adapters/hermes/skills",
               lambda rel: os.path.basename(rel) == "SKILL.md"
               and os.path.basename(os.path.dirname(rel)).startswith("flow-")),
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
        if core and os.path.exists(os.path.join(ROOT, core)):
            found.add(core)
    for manifest in (CODEX_MANIFEST, ZCODE_MANIFEST):
        if os.path.exists(os.path.join(ROOT, manifest)):
            found.add(manifest)
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
