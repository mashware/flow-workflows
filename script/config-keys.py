#!/usr/bin/env python3
"""Keep docs/CONFIGURATION.md's key table in step with the FLOW.md template.

Every `FLOW.md` key was documented twice — inline in
`plugins/flow/examples/FLOW.template.md` and again in `docs/CONFIGURATION.md` — and the
two drifted. The template is the single source now: this script reads every
`- key:` under every `## section` there, with the first line of its comment, and
writes the table between the two markers in the reference.

    script/config-keys.py            # rewrite the table
    script/config-keys.py --check    # exit 1 if the table is stale or a marker is missing
"""

import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.realpath(__file__))
ROOT = subprocess.run(["git", "rev-parse", "--show-toplevel"], cwd=HERE,
                      capture_output=True, text=True).stdout.strip() or os.path.dirname(HERE)
TEMPLATE = "plugins/flow/examples/FLOW.template.md"
REFERENCE = "docs/CONFIGURATION.md"
BEGIN, END = "<!-- config-keys:begin -->", "<!-- config-keys:end -->"

KEY = re.compile(r"^- `(?P<key>[a-z_]+):`\s*#\s*(?P<doc>.*)$")


def read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as fh:
        return fh.read()


def keys():
    section, out = None, []
    for line in read(TEMPLATE).splitlines():
        if line.startswith("## "):
            section = line[3:].strip()
            continue
        m = KEY.match(line)
        if m and section:
            doc = m.group("doc").strip().rstrip(".")
            doc = re.sub(r"\s+", " ", doc).replace("|", "\\|")
            out.append((section, m.group("key"), doc))
    return out


def table():
    rows = ["| Section | Key | What it does (first line of the template comment) |",
            "|---|---|---|"]
    for section, key, doc in keys():
        rows.append(f"| `{section}` | `{key}` | {doc} |")
    return (f"{BEGIN}\n_Generated from [`{TEMPLATE}`]({os.path.relpath(TEMPLATE, 'docs')}) by "
            f"`script/config-keys.py` — edit the template, not this table._\n\n"
            + "\n".join(rows) + f"\n{END}")


def main():
    check = "--check" in sys.argv
    ref = read(REFERENCE)
    if BEGIN not in ref or END not in ref:
        print(f"{REFERENCE}: missing the `{BEGIN}` / `{END}` markers")
        return 1
    new = re.sub(re.escape(BEGIN) + r".*?" + re.escape(END), lambda _m: table(), ref, flags=re.S)
    if check:
        if new != ref:
            print(f"{REFERENCE}: key table out of date with {TEMPLATE} (run script/config-keys.py)")
            return 1
        print(f"config keys ok — {len(keys())} keys documented")
        return 0
    with open(os.path.join(ROOT, REFERENCE), "w", encoding="utf-8") as fh:
        fh.write(new)
    print(f"wrote {len(keys())} keys into {REFERENCE}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
