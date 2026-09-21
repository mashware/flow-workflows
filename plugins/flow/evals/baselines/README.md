# Baselines

One file per plugin version and model: `<version>-<model>.json`, the `aggregate-result.json` of a
full suite run, written by `python3 script/bench-compare.py --save <result.json> --model <model>`.

**The model is passed in, because the result document does not record it.** It carries the suite,
the threshold and the plugin version and nothing about which model ran. A baseline exists to be
compared against after a model changes, so pin `--model` on the run and give the same name here.

A baseline is a **reference, never a verdict**. The first run of a new suite establishes it and
judges nothing: no pass is retired and no threshold is moved on the strength of one run. What a
baseline is for is the next run — `bench-compare.py` reads the range this one's own runs spanned,
and prints `—` for any later difference that lands inside it.

`0.67.0-rc.1-claude-opus-5.json` is the first, and it is the one exception to that rule: the run
did not pin a model and took the CLI's default, which its transcripts name as `claude-opus-5`. Every
later one pins it.

Record one when the model changes, when the suite changes, and at a release. A partial run — the
cost ceiling hit, the credential rejected, the suite interrupted — is refused by `--save` and does
not belong in a trend.
