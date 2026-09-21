#!/usr/bin/env python3
"""Compare two eval runs and say which differences are real.

`claude plugin eval` scores a case as the **mean** of its runs and prints one number per
case. A mean over three runs of a non-deterministic agent moves on its own, so two runs of
the identical suite produce two different tables and nothing in them says which of the
differences was the plugin and which was the weather.

So this script reads the per-run scores both documents already carry and reports, per case:
the **median** of the runs, the **range** the base's own runs spanned, and whether the new
median leaves that range. A delta inside the base's range is printed as `—`, and saying so
is the whole point: a bench that reports every wobble as a regression is one everybody
learns to ignore.

    python3 script/bench-compare.py <base.json> <candidate.json>
    python3 script/bench-compare.py <base.json> <candidate.json> --fail-on-regression
    python3 script/bench-compare.py --save <result.json> --model <model>   # record a baseline

Both arguments are `aggregate-result.json` documents (or the file `--json <path>` wrote).
"""

import argparse
import json
import os
import statistics
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASELINES = os.path.join(ROOT, "plugins", "flow", "evals", "baselines")
MANIFEST = os.path.join(ROOT, "plugins", "flow", ".claude-plugin", "plugin.json")


def load(path):
    with open(path, encoding="utf-8") as fh:
        doc = json.load(fh)
    if doc.get("partial"):
        print(f"warning: {path} is partial ({doc.get('partialReason')}) — "
              f"a suite that did not finish is not a measurement", file=sys.stderr)
    return doc


def runs_of(case, arm="with"):
    """The per-run scores of one arm, skipping runs whose paid graders were skipped."""
    entries = (case.get("arms") or {}).get(arm) or []
    return [r["score"] for r in entries
            if r.get("score") is not None and not r.get("skippedPaidGraders")]


def summary(doc):
    """Per case: median, range and the tags it carries, keyed by case name."""
    out = {}
    for case in doc.get("cases") or []:
        scores = runs_of(case)
        if not scores:
            continue
        out[case["name"]] = {
            "median": statistics.median(scores),
            "low": min(scores),
            "high": max(scores),
            "runs": len(scores),
            "delta": (case.get("aggregates") or {}).get("delta"),
            "tags": case.get("tags") or [],
        }
    return out


def kind(name, tags):
    """A case is seeded or clean; the name decides when the document carries no tags."""
    if "seeded" in tags:
        return "seeded"
    if "clean" in tags:
        return "clean"
    return "seeded" if name.startswith("seeded-") else "clean"


def mean(values):
    return statistics.mean(values) if values else None


def fmt(value, width=5):
    return "—".rjust(width) if value is None else f"{value:.2f}".rjust(width)


def describe(doc, path):
    aggregates = doc.get("aggregates") or {}
    return (f"{os.path.basename(path)} · claude {doc.get('claudeVersion', '?')} · "
            f"{len(doc.get('cases') or [])} case(s) · "
            f"${doc.get('costUsd', 0):.2f} · {doc.get('durationSeconds', 0):.0f}s · "
            f"mean Δ vs no-plugin {fmt(aggregates.get('meanDelta')).strip()}")


def compare(base_doc, new_doc, fail_on_regression):
    base, new = summary(base_doc), summary(new_doc)
    shared = [n for n in new if n in base]
    missing = sorted(set(base) - set(new))
    added = sorted(set(new) - set(base))

    print(f"base      {describe(base_doc, base_path)}")
    print(f"candidate {describe(new_doc, new_path)}")
    print()
    print(f"{'CASE':<32} {'BASE':>5} {'NEW':>5} {'Δ':>6}  {'BASE RANGE':<12} VERDICT")

    regressions = []
    for name in sorted(shared):
        b, n = base[name], new[name]
        delta = n["median"] - b["median"]
        inside = b["low"] <= n["median"] <= b["high"]
        if inside:
            verdict = "within the base's own range"
        elif delta > 0:
            verdict = "improved"
        else:
            verdict = "REGRESSED"
            regressions.append(name)
        rng = f"{b['low']:.2f}–{b['high']:.2f}"
        shown = "     —" if inside else f"{delta:+.2f}".rjust(6)
        print(f"{name:<32} {fmt(b['median'])} {fmt(n['median'])} {shown}  {rng:<12} {verdict}")

    for name in missing:
        print(f"{name:<32} {fmt(base[name]['median'])}     —      —  "
              f"{'':<12} not in the candidate")
    for name in added:
        print(f"{name:<32}     — {fmt(new[name]['median'])}      —  "
              f"{'':<12} new case, no base to compare")

    print()
    for label, doc_summary in (("base", base), ("candidate", new)):
        seeded = [c["median"] for k, c in doc_summary.items() if kind(k, c["tags"]) == "seeded"]
        clean = [c["median"] for k, c in doc_summary.items() if kind(k, c["tags"]) == "clean"]
        print(f"{label:<10} recall (seeded) {fmt(mean(seeded)).strip():<5} "
              f"· clean diffs kept clean {fmt(mean(clean)).strip():<5} "
              f"· {len(seeded)} seeded, {len(clean)} clean")

    base_cost, new_cost = base_doc.get("costUsd") or 0, new_doc.get("costUsd") or 0
    base_secs, new_secs = base_doc.get("durationSeconds") or 0, new_doc.get("durationSeconds") or 0
    print(f"{'cost':<10} ${base_cost:.2f} → ${new_cost:.2f} ({new_cost - base_cost:+.2f}) "
          f"· wall clock {base_secs:.0f}s → {new_secs:.0f}s ({new_secs - base_secs:+.0f}s)")

    if not shared:
        print("\nnothing to compare: the two documents share no case name", file=sys.stderr)
        return 1
    if regressions and fail_on_regression:
        print(f"\n{len(regressions)} case(s) below the base's own range: "
              f"{', '.join(regressions)}", file=sys.stderr)
        return 1
    return 0


def save(path, model=None):
    """Record a result as the baseline for its version and model.

    The model is given here rather than read from the result: the document records the
    suite, the threshold and the plugin version, and **not** which model the runs used. A
    baseline exists to be compared against after a model changes, so one that cannot name
    its model is the one thing it must never be — hence the warning when nothing pins it.
    """
    doc = load(path)
    if doc.get("partial"):
        print("refusing to record a partial run as a baseline", file=sys.stderr)
        return 1
    with open(MANIFEST, encoding="utf-8") as fh:
        version = json.load(fh).get("version") or "unknown"
    if not model:
        print("warning: no --model given, so this baseline is recorded as `default-model` — "
              "whatever the CLI resolved on the day. Pin `--model` on the run and pass the "
              "same one here, or the comparison after a model ships has nothing to compare to",
              file=sys.stderr)
    model = str(model or "default-model").replace("/", "-")
    os.makedirs(BASELINES, exist_ok=True)
    target = os.path.join(BASELINES, f"{version}-{model}.json")
    with open(target, "w", encoding="utf-8") as fh:
        json.dump(doc, fh, indent=2, sort_keys=True)
        fh.write("\n")
    print(f"baseline written: {os.path.relpath(target, ROOT)}")
    print("commit it with the change it measures — a baseline nobody can read back is a number "
          "nobody can argue with")
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("base", nargs="?", help="the earlier aggregate-result.json")
    parser.add_argument("candidate", nargs="?", help="the run to compare against it")
    parser.add_argument("--save", metavar="RESULT",
                        help="record RESULT under evals/baselines/<version>-<model>.json")
    parser.add_argument("--model", metavar="NAME",
                        help="the model the run used, for the baseline's name. The result "
                             "document does not record it")
    parser.add_argument("--fail-on-regression", action="store_true",
                        help="exit 1 when a case's median falls below the base's own range")
    args = parser.parse_args()

    if args.save:
        sys.exit(save(args.save, args.model))
    if not args.base or not args.candidate:
        parser.error("give two result documents, or --save one")
    base_path, new_path = args.base, args.candidate
    sys.exit(compare(load(base_path), load(new_path), args.fail_on_regression))
