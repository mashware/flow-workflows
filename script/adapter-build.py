#!/usr/bin/env python3
"""Generate the adapter mirrors (opencode · Codex · Gemini) from the plugin commands.

The mirrors used to be condensed by hand — 1.7 MB of near-verbatim copies that drifted
one release at a time. They are now build output: every file under
`adapters/<harness>/commands|prompts/` and every `adapters/<harness>/CORE.md` is
written by this script from `plugins/flow/commands/**/*.md` and
`plugins/flow/skills/flow-core/SKILL.md`. Edit the plugin, rebuild, commit both.

What changes per harness is mechanical, and only this:

  * the wrapper — opencode `description:` frontmatter, Codex none, Gemini a TOML
    `description` + `prompt` string (backslashes and triple quotes escaped)
  * every `/flow…` invocation rewritten to that harness's prefix
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

# name → (mirror path template, invocation separator, args token)
TARGETS = {
    "opencode": ("adapters/opencode/commands/flow-{flat}.md", "-", "$ARGUMENTS"),
    "codex": ("adapters/codex/prompts/flow-{flat}.md", "-", "$ARGUMENTS"),
    "gemini": ("adapters/gemini/commands/flow/{stem}.toml", ":", "{{args}}"),
}

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
        "`Skill commit-commands:commit-push-pr` → `git add` · `git commit` · `git push -u origin HEAD` · the `git.cli` CLI (`gh pr create` / `glab mr create`). `Skill save-knowledge` → `/flow:save-knowledge`.",
        "`/model <value>` → opencode's model picker (`/models`).",
        "`mcp__domain-memory__*` → same tool names; server declared in `opencode.json` (see `opencode.json` in this adapter).",
    ],
    "codex": [
        "`AskUserQuestion` → ask in plain text with numbered options and wait for the reply.",
        "`Agent <role>` / `Agent general-purpose` / subagents → the subagent declared under `[agents.<name>]` in `~/.codex/config.toml`; the name comes from `agents.<role>` in `FLOW.md`, empty → do it in this context.",
        "Parallel fan-out → several subagents in one response, capped at `agents.fanout_max` (empty → 4); `agents.fanout_tool` is Claude Code-only, ignore it.",
        "`ScheduleWakeup` / `Monitor` / `/loop` → not available in-session: run one cycle, persist state in `monitor.md`, let the user schedule `codex exec \"<command>\"` with cron or Codex automations.",
        "`TaskCreate` → a markdown checklist in the phase artifact.",
        "`Skill commit-commands:commit-push-pr` → `git add` · `git commit` · `git push -u origin HEAD` · the `git.cli` CLI (`gh pr create` / `glab mr create`). `Skill save-knowledge` → `/flow:save-knowledge`.",
        "`/model <value>` → the `--model` flag at launch (or `/model` if your Codex version has it).",
        "`mcp__domain-memory__*` → same tool names; server declared under `[mcp_servers.domain-memory]` in `config.toml` (see `config.snippet.toml`).",
    ],
    "gemini": [
        "`AskUserQuestion` → ask in plain text with numbered options and wait for the reply.",
        "`Agent <role>` / `Agent general-purpose` / subagents → `@<name>` from `.gemini/agents/`; the name comes from `agents.<role>` in `FLOW.md`, empty or absent → do it in this context.",
        "Parallel fan-out → several `@name` in one turn (sequential in this context if none are configured), capped at `agents.fanout_max` (empty → 4); `agents.fanout_tool` is Claude Code-only, ignore it.",
        "`ScheduleWakeup` / `Monitor` / `/loop` → not available in-session: run one cycle, persist state in `monitor.md`, let the user schedule `gemini -p \"<command>\"` with cron.",
        "`TaskCreate` → a markdown checklist in the phase artifact.",
        "`Skill commit-commands:commit-push-pr` → `git add` · `git commit` · `git push -u origin HEAD` · the `git.cli` CLI (`gh pr create` / `glab mr create`). `Skill save-knowledge` → `/flow:save-knowledge`.",
        "`/model <value>` → the `--model` flag at launch.",
        "`mcp__domain-memory__*` → same tool names; server declared under `mcpServers` in `settings.json` (see `settings.snippet.json`).",
    ],
}

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


def retarget(text, sep, flat_to_stem):
    """Rewrite every `/flow…` invocation into this harness's prefix, both directions."""
    def to_dashes(m):
        return "/flow" + m.group("rest").replace(":", "-")

    def to_colons(m):
        real = flat_to_stem.get(m.group("rest").lstrip("-"))
        return m.group(0) if real is None else "/flow:" + real.replace("/", ":")

    if sep == "-":
        return re.sub(r"(?<![\w/])/flow(?P<rest>(?::[a-zA-Z0-9*-]+)+)", to_dashes, text)
    return re.sub(r"(?<![\w/])/flow(?P<rest>-[a-zA-Z0-9-]+)", to_colons, text)


def core_path(name):
    return f"{STATE_DIR}/CORE.{name}.md"


def translate(body, name, sep, args_token, flat_to_stem):
    body = SKILL_POINTER.sub(
        lambda m: f"Read `{core_path(name)}` first (\\g<what>) — skip if you already read it in this session.", body)
    body = body.replace("`flow:flow-core` skill", f"`{core_path(name)}`")
    body = body.replace("${CLAUDE_PLUGIN_ROOT}/skills/flow-core/SKILL.md", core_path(name))
    body = body.replace("${CLAUDE_PLUGIN_ROOT}", STATE_DIR)
    if args_token != "$ARGUMENTS":
        body = body.replace("$ARGUMENTS", args_token)
    return retarget(body, sep, flat_to_stem)


def legend(name, sep, flat_to_stem):
    lines = "\n".join(f"- {retarget(l, sep, flat_to_stem)}" for l in LEGEND[name])
    return (f"> **{name} adapter — how the Claude Code primitives named below map here.**\n"
            + "\n".join("> " + l for l in lines.splitlines()) + "\n")


def render_command(name, stem, frontmatter, body, flat_to_stem):
    _template, sep, args_token = TARGETS[name]
    desc = description(frontmatter)
    body = translate(body, name, sep, args_token, flat_to_stem).strip("\n")
    # the title already carries this harness's prefix (retarget ran on it); legend goes right after it
    body = re.sub(r"^(#\s+.*\n)", lambda m: m.group(1) + "\n" + legend(name, sep, flat_to_stem), body, count=1, flags=re.M)
    src = f"{PLUGIN_COMMANDS}/{stem}.md"
    return wrap(name, desc, body, src)


def render_core(name, flat_to_stem):
    _fm, body = split_frontmatter(read(CORE_SKILL))
    _template, sep, args_token = TARGETS[name]
    body = translate(body, name, sep, args_token, flat_to_stem).strip("\n")
    body = re.sub(r"^(#\s+.*\n)", lambda m: m.group(1) + "\n" + legend(name, sep, flat_to_stem), body, count=1, flags=re.M)
    return f"<!-- {BANNER.format(src=CORE_SKILL)} -->\n\n{body}\n"


def wrap(name, desc, body, src):
    banner = BANNER.format(src=src)
    if name == "opencode":
        return f"---\ndescription: {desc}\n---\n\n<!-- {banner} -->\n\n{body}\n"
    if name == "codex":
        return f"<!-- {banner} -->\n\n{body}\n"
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
        for name, (template, _sep, _args) in TARGETS.items():
            rel = template.format(stem=stem, flat=stem.replace("/", "-"))
            out[rel] = render_command(name, stem, frontmatter, body, flat_to_stem)
    for name in TARGETS:
        out[f"adapters/{name}/CORE.md"] = render_core(name, flat_to_stem)
    return out


def on_disk():
    """Mirror files currently present (tracked or not), to catch orphans."""
    found = set()
    for name, (template, _sep, _args) in TARGETS.items():
        base = os.path.join(ROOT, os.path.dirname(template.format(stem="x/y", flat="x")))
        base = base if name != "gemini" else os.path.join(ROOT, "adapters/gemini/commands/flow")
        suffix = ".toml" if name == "gemini" else ".md"
        for dirpath, _d, names in os.walk(base):
            for n in names:
                if n.endswith(suffix):
                    rel = os.path.relpath(os.path.join(dirpath, n), ROOT)
                    if name == "gemini" or os.path.basename(rel).startswith("flow-"):
                        found.add(rel)
        core = f"adapters/{name}/CORE.md"
        if os.path.exists(os.path.join(ROOT, core)):
            found.add(core)
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
        print(f"removed orphan {rel}")
    print(f"wrote {len(want)} files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
