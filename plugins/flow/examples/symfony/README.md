# An example, not a default

Nothing in the plugin loads this folder. It is one worked stack — Symfony + Doctrine + MySQL +
Docker Compose — so that a fresh install has something concrete to copy instead of an empty
`agents:` map and a `FLOW.md` with every key blank.

Flow ships no agents and no review skill on purpose: they are language- and project-specific, and a
plugin that shipped one stack's reviewers as the default would be wrong for everyone else
([PHILOSOPHY](../../../../docs/PHILOSOPHY.md#stack-agnostic-and-what-that-costs)). The cost of that
decision is day one, and this folder is the mitigation.

## What is here

| File | What it is |
|---|---|
| `FLOW.md` | A complete configuration for this stack — quality commands, the review panel, the `data.*` keys the query duel needs, and ten real conventions |
| `agents/symfony-reviewer.md` | Framework idiom and layering: services and DI, Messenger, domain events, controllers, the Domain/Application/Infrastructure boundary |
| `agents/doctrine-query-reviewer.md` | Data access judged on the plan and the real schema: indexes, N+1, fetch strategy, migrations. The reviewer the query duel wants |
| `agents/symfony-security-reviewer.md` | Authorization per entry point, injection, secrets, data exposure. Severity-tagged, because a high finding is a hard gate |
| `agents/phpunit-tdd-guide.md` | The three test shapes, and the question that catches a test which proves nothing |

## How to use it

```bash
# 1. The configuration — read it, then change what does not apply.
cp plugins/flow/examples/symfony/FLOW.md /path/to/your/repo/FLOW.md

# 2. The agents — per project, or for every project on this machine.
cp plugins/flow/examples/symfony/agents/*.md /path/to/your/repo/.claude/agents/
cp plugins/flow/examples/symfony/agents/*.md ~/.claude/agents/
```

Then run `/flow:doctor`: it reports which of the agents named in `FLOW.md` it can actually find, so
a typo in a name is caught before a review silently falls back to `general-purpose`.

Change first: `tracker.*` (prefix, CLI and the transitions your board uses), `git.default_base`,
every `quality.*` command, and `data.volumes` — the last is the cheapest key in the file and the one
that stops a reviewer arguing against a table size it invented.

## For a neighbouring stack

The agents are prose. For **Laravel**, keep the shape and swap the vocabulary: Eloquent for
Doctrine (the query reviewer's questions about index order and rows examined are unchanged), policies
and gates for voters, queued jobs for Messenger handlers, `app/` layering for
Domain/Application/Infrastructure. For **plain PHP**, drop the framework reviewer and keep the other
three; the security and query questions do not depend on a framework at all.

What must survive any translation is the last section of each file — the report contract. A brief
that says what to look at and nothing about what to send back is how a review round goes quiet:
under 250 words, findings only, one line each as `file:line` + what is wrong + the fix. That cap is
not style, it is what stops a long report being truncated in transit and reaching the flow as
silence (flow-core §6).

## Contributing another stack

A second stack here is the highest-value contribution to this repo. Same layout: `FLOW.md`,
`agents/`, and a README that says what to change for the stack next door.
→ [CONTRIBUTING](../../../../CONTRIBUTING.md)
