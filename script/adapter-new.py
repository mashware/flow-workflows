#!/usr/bin/env python3
"""Generate the adapter mirrors for a plugin command, mechanically.

Three of the four harnesses flow supports read hand-condensed copies of each command,
and every copy has to be created before `check.py` will let a release out. The
condensation itself needs judgement — what to cut for a harness with no subagents, which
paragraph is Claude-Code-specific — so this does not try to write it. It does the part
that is mechanical and that nobody should be doing by hand:

  * the file lands where that harness reads it, named the way it expects
  * the wrapper is right: opencode `description:` frontmatter, Codex none at all,
    Gemini a TOML `description` + `prompt` string
  * every invocation in the body is rewritten to that harness's prefix
    (`/flow:feat:build` → `/flow-feat-build` for opencode and Codex)
  * the region a human still has to condense is marked, so an uncondensed mirror is
    visible in a diff instead of shipping as if it were finished

    script/adapter-new.py feat/start            # all three harnesses
    script/adapter-new.py doctor --only gemini
    script/adapter-new.py doctor --force        # overwrite existing mirrors

Refuses to overwrite an existing mirror without --force: those hold hand-written work
this script cannot reproduce.
"""

import argparse
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.realpath(__file__))
ROOT = subprocess.run(["git", "rev-parse", "--show-toplevel"], cwd=HERE,
                      capture_output=True, text=True).stdout.strip() or os.path.dirname(HERE)

TODO = ("CONDENSE ME — generated from the plugin command verbatim. Cut what this harness "
        "cannot do, keep every gate, then delete this line.")

TARGETS = {
    # name: (path template, invocation separator)
    "opencode": ("adapters/opencode/commands/flow-{flat}.md", "-"),
    "codex": ("adapters/codex/prompts/flow-{flat}.md", "-"),
    "gemini": ("adapters/gemini/commands/flow/{stem}.toml", ":"),
}


def split_frontmatter(body):
    if not body.startswith("---\n"):
        return "", body
    parts = body.split("---\n", 2)
    return (parts[1], parts[2]) if len(parts) == 3 else ("", body)


def description(frontmatter):
    m = re.search(r"^description:\s*(.+)$", frontmatter, re.M)
    return m.group(1).strip().strip('"') if m else ""


def plugin_stems():
    """flat stem → real stem, e.g. `work-clean` → `work/clean`, `save-knowledge` → itself.

    Needed to rewrite invocations *towards* the colon prefix: `/flow-work-clean` is
    `/flow:work:clean`, but `/flow-save-knowledge` is `/flow:save-knowledge`. Only the
    command list can tell those apart, and guessing turns a valid command into one the
    harness does not have.
    """
    base = os.path.join(ROOT, "plugins/flow/commands")
    out = {}
    for dirpath, _dirs, names in os.walk(base):
        for n in names:
            if not n.endswith(".md"):
                continue
            stem = os.path.relpath(os.path.join(dirpath, n), base)[:-3]
            out[stem.replace("/", "-")] = stem
    return out


def retarget(text, sep, stems=None):
    """Rewrite every `/flow…` invocation into the prefix this harness reads.

    Both directions: a body condensed once by hand may spell either, and a mirror that
    teaches the other harness's prefix hands the user a command that does not exist.
    Repo URLs (`mashware/flow-workflows`) are not invocations — the negative lookbehind
    is what keeps them intact.
    """
    stems = stems if stems is not None else plugin_stems()

    def to_dashes(m):
        return "/flow" + m.group("rest").replace(":", "-")

    def to_colons(m):
        flat = m.group("rest").lstrip("-")
        real = stems.get(flat)
        if real is None:                          # not a command (a URL slug, a glob)
            return m.group(0)
        return "/flow:" + real.replace("/", ":")

    if sep == "-":
        return re.sub(r"(?<![\w/])/flow(?P<rest>(?::[a-zA-Z0-9*-]+)+)", to_dashes, text)
    return re.sub(r"(?<![\w/])/flow(?P<rest>-[a-zA-Z0-9-]+)", to_colons, text)


def render(name, sep, stem, desc, body, marked=True, stems=None):
    body = retarget(body, sep, stems).strip("\n")
    title = "flow-" + stem.replace("/", "-") if sep == "-" else f"/flow:{stem.replace('/', ':')}"
    body = re.sub(r"^#\s+.*$", f"# {title}" if sep == "-" else f"# `{title}`", body,
                  count=1, flags=re.M)
    todo = f"<!-- {TODO} -->\n\n" if marked else ""
    if name == "opencode":
        return f"---\ndescription: {desc}\n---\n\n{todo}{body}\n"
    if name == "codex":
        return f"{todo}{body}\n"
    if '"""' in body:
        sys.exit("gemini: the body contains a TOML triple quote — condense it by hand")
    return (f'description = "{desc.replace(chr(34), chr(39))}"\n\n'
            + (f"# {TODO}\n\n" if marked else "")
            + f'prompt = """\n{body}\n"""\n')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("command", help="plugin command, e.g. `doctor` or `feat/start`")
    ap.add_argument("--only", action="append", choices=sorted(TARGETS), default=None)
    ap.add_argument("--force", action="store_true", help="overwrite existing mirrors")
    ap.add_argument("--from", dest="source", default=None, metavar="FILE",
                    help="take the body from FILE instead of the plugin command — condense "
                         "once by hand, wrap it for all three harnesses mechanically")
    args = ap.parse_args()

    stem = args.command.removesuffix(".md")
    src = args.source or os.path.join(ROOT, "plugins/flow/commands", stem + ".md")
    if not os.path.exists(src):
        sys.exit(f"no such plugin command: plugins/flow/commands/{stem}.md")
    with open(src, encoding="utf-8") as fh:
        frontmatter, body = split_frontmatter(fh.read())
    desc = description(frontmatter)
    if not desc:
        sys.exit(f"{src}: no `description:` in the frontmatter — opencode and Gemini need one")

    known = plugin_stems()
    for name in (args.only or sorted(TARGETS)):
        template, sep = TARGETS[name]
        rel = template.format(stem=stem, flat=stem.replace("/", "-"))
        dest = os.path.join(ROOT, rel)
        if os.path.exists(dest) and not args.force:
            print(f"·  {rel} exists, left alone (--force to overwrite)")
            continue
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "w", encoding="utf-8") as fh:
            fh.write(render(name, sep, stem, desc, body, marked=args.source is None,
                            stems=known))
        print(f"✓  {rel}")
    print("\nNow condense the marked bodies by hand, then: script/adapter-smoke.py"
          if args.source is None else
          "\nWrapped a hand-condensed body — verify with: script/adapter-smoke.py")


if __name__ == "__main__":
    sys.exit(main())
