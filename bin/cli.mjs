#!/usr/bin/env node
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, renameSync, rmSync, statSync, writeFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { execFileSync, spawn } from 'node:child_process'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')
const ADAPTERS = join(ROOT, 'adapters')
const PLUGIN = join(ROOT, 'plugins', 'flow')
const STATE = join(homedir(), '.claude', 'flow')

const HARNESSES = {
  opencode: {
    global: join(homedir(), '.config', 'opencode', 'commands'),
    project: '.opencode/commands',
    src: join(ADAPTERS, 'opencode', 'commands'),
    unit: 'commands',
    count: (src) => readdirSync(src).filter((f) => f.endsWith('.md')).length,
    invoke: '/flow-feat-start, /flow-work-watch, …',
    snippet: ['opencode/opencode.json', 'opencode.json'],
    notes: [
      'MCP: merge the "mcp" block from ~/.claude/flow/opencode.json into your opencode.json',
      'Subagents: declare the ones named in FLOW.md (agents/review map) in agents/*.md — see opencode/PRIMITIVES.md',
    ],
  },
  gemini: {
    global: join(homedir(), '.gemini', 'commands'),
    project: '.gemini/commands',
    src: join(ADAPTERS, 'gemini', 'commands'),
    unit: 'commands',
    nested: 'flow',
    count: (src) => countByExt(src, '.toml'),
    invoke: '/flow:feat:start, /flow:work:watch, …',
    snippet: ['gemini/settings.snippet.json', 'settings.snippet.json'],
    notes: [
      'MCP: merge "mcpServers" from ~/.claude/flow/settings.snippet.json into your settings.json',
      'Subagents: declare the ones from FLOW.md in .gemini/agents/*.md — see gemini/PRIMITIVES.md',
    ],
  },
  codex: {
    global: join(homedir(), '.codex', 'skills'),
    project: '.agents/skills',
    src: join(ADAPTERS, 'codex', 'skills'),
    unit: 'skills',
    skillDirs: true,
    count: (src) => countByName(src, 'SKILL.md'),
    invoke: '$flow-feat-start, $flow-work-watch, …',
    snippet: ['codex/config.snippet.toml', 'config.snippet.toml'],
    notes: [
      'Codex discovers skills, not Claude commands: they are invoked with $, and a new session picks them up.',
      'MCP/subagents: merge ~/.claude/flow/config.snippet.toml into ~/.codex/config.toml',
      'Conventions: adapters/codex/AGENTS.md in the repo is one you can copy to your repo root (Codex reads it as a guide).',
    ],
  },
  hermes: {
    global: join(homedir(), '.hermes', 'skills'),
    project: '.hermes/skills',
    src: join(ADAPTERS, 'hermes', 'skills'),
    unit: 'skills',
    skillDirs: true,
    count: (src) => countByName(src, 'SKILL.md'),
    invoke: '/flow-feat-start, /flow-work-watch, …',
    snippet: ['hermes/config.snippet.yaml', 'config.snippet.yaml'],
    notes: [
      'Hermes reads ~/.hermes/skills as one flat namespace; a project install (.hermes/skills) needs `hermes skills trust` the first time.',
      'MCP, delegation and cron: merge ~/.claude/flow/config.snippet.yaml into ~/.hermes/config.yaml',
      'Conventions: Hermes reads AGENTS.md as project context — adapters/codex/AGENTS.md in the repo is one you can copy to your repo root.',
    ],
  },
}

function countByExt(dir, ext) {
  let n = 0
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    if (e.isDirectory()) n += countByExt(join(dir, e.name), ext)
    else if (e.name.endsWith(ext)) n++
  }
  return n
}

function countByName(dir, name) {
  let n = 0
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    if (e.isDirectory()) n += countByName(join(dir, e.name), name)
    else if (e.name === name) n++
  }
  return n
}

function note(msg) {
  console.log(`  ${msg}`)
}

// A reinstall copies over what is there but never removes what upstream deleted, so a command
// dropped from the plugin would stay installed and invocable for ever. Clear ours first, by
// prefix, never the whole directory — the user's own files live there too.
function sweep(dest, { skillDirs }) {
  if (!existsSync(dest)) return
  let removed = 0
  for (const e of readdirSync(dest, { withFileTypes: true })) {
    if (!e.name.startsWith('flow-')) continue
    if (e.isDirectory() !== Boolean(skillDirs)) continue
    if (!skillDirs && !e.name.endsWith('.md')) continue
    rmSync(join(dest, e.name), { recursive: true, force: true })
    removed++
  }
  if (removed) note(`removed ${removed} previously installed ${skillDirs ? 'skill(s)' : 'file(s)'} from ${dest}`)
}

function version() {
  return JSON.parse(readFileSync(join(ROOT, 'package.json'), 'utf8')).version
}

function install(tool, scope) {
  const h = HARNESSES[tool]
  const dest = scope === 'project' ? h.project : h.global

  mkdirSync(dest, { recursive: true })
  if (h.nested) rmSync(join(dest, h.nested), { recursive: true, force: true })
  else sweep(dest, h)
  cpSync(h.src, dest, { recursive: true })

  console.log(`✓ ${tool}: ${h.count(h.src)} ${h.unit} in ${dest}  (invoke as ${h.invoke})`)
  h.notes.forEach(note)

  // The adapters have no ${CLAUDE_PLUGIN_ROOT}, so what the plugin reads from there lands in
  // ~/.claude/flow instead.
  mkdirSync(STATE, { recursive: true })
  cpSync(join(ADAPTERS, tool, 'CORE.md'), join(STATE, `CORE.${tool}.md`))
  note(`core: shared rules copied to ~/.claude/flow/CORE.${tool}.md (every command reads it once per session)`)
  copyIfPresent(join(PLUGIN, 'CHANGELOG.md'), join(STATE, 'CHANGELOG.md'))
  note('news: changelog copied to ~/.claude/flow/CHANGELOG.md (feeds /flow-news · /flow:news)')
  copyIfPresent(join(PLUGIN, '.claude-plugin', 'plugin.json'), join(STATE, 'plugin.json'))
  // Installed via npx, this package lives in a directory that is deleted right after, so
  // anything the user still has to open has to be copied somewhere that outlives the run.
  copyIfPresent(join(ADAPTERS, h.snippet[0]), join(STATE, h.snippet[1]))
  copyIfPresent(join(PLUGIN, 'examples', 'FLOW.template.md'), join(STATE, 'FLOW.template.md'))

  console.log()
  console.log('→ One key step remaining: place a shared FLOW.md at the root of your repo.')
  console.log(`  Optional for this harness: FLOW.${tool}.md (sparse overrides only).`)
  console.log('  Template: ~/.claude/flow/FLOW.template.md')
  console.log('  (without either file everything still works, just with more prompting)')
}

function copyIfPresent(from, to) {
  if (existsSync(from)) cpSync(from, to)
}

function claude() {
  console.log('Claude Code installs flow from its own marketplace, not from npm:')
  console.log()
  console.log('  /plugin marketplace add mashware/flow-workflows')
  console.log('  /plugin install flow@flow-plugins')
  console.log()
  console.log('Then /flow:init in your repo. Updates arrive through /plugin.')
  console.log('Codex has its own too: codex plugin marketplace add https://github.com/mashware/flow-workflows.git')
}

function check() {
  const pkg = version()
  console.log(`this package:  v${pkg}`)

  const manifest = join(STATE, 'plugin.json')
  const installed = existsSync(manifest) ? JSON.parse(readFileSync(manifest, 'utf8')).version : null
  console.log(`installed:     ${installed ? `v${installed}` : 'nothing installed yet'}`)

  let latest = null
  try {
    latest = execFileSync('npm', ['view', 'flow-workflows', 'version'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim()
    console.log(`latest on npm: v${latest}`)
  } catch {
    console.log('latest on npm: could not reach the registry')
  }

  console.log()
  if (latest && latest !== pkg) {
    console.log(`→ v${latest} is out. Run: npx flow-workflows@latest install <harness>`)
  } else if (installed && installed !== pkg) {
    console.log(`→ your harnesses still run v${installed}. Reinstall to move them to v${pkg}.`)
  } else if (installed) {
    console.log('→ up to date.')
  } else {
    console.log('→ nothing installed yet. Run: npx flow-workflows install <harness>')
  }
}

// --- bundle ------------------------------------------------------------------------------
// A phase costs `turns × context`: every tool call resends the whole conversation, so ten
// calls spent discovering what changed cost ten times the context they discover. This
// gathers the same material in one call — and gathers it ONCE for a whole review panel,
// instead of each reviewer running its own diff and opening the same files.
//
// It knows nothing about any ecosystem. `FLOW.md` says which paths to leave out and which
// command reports problems; this runs what it is told and copies the output out verbatim.
// Parsing that output is what would couple it to one toolchain, so it never does.

const MAX_FILE_BYTES = 64 * 1024
const MAX_TOTAL_BYTES = 512 * 1024

function git(args, cwd = process.cwd()) {
  try {
    return execFileSync('git', args, {
      cwd, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, stdio: ['ignore', 'pipe', 'ignore'],
    })
  } catch {
    return ''
  }
}

// `FLOW.md` is `## section` then `- key: value`, with an indented `- item` list where a key
// has no inline value. `conventions` carries bare prose lines and is skipped by the same
// rule that skips anything else without a `key:`.
function parseFlow(text) {
  const out = {}
  let section = null
  let listKey = null
  for (const line of text.split('\n')) {
    const heading = /^##\s+(\S+)/.exec(line)
    if (heading) {
      section = heading[1]
      out[section] ??= {}
      listKey = null
      continue
    }
    if (!section) continue
    const item = /^\s+-\s+(.*)$/.exec(line)
    if (item && listKey) {
      out[section][listKey].push(item[1].trim())
      continue
    }
    const kv = /^-\s+`?([a-z_]+)`?:\s*(.*)$/.exec(line)
    if (!kv) { listKey = null; continue }
    const [, key, value] = kv
    if (value.trim()) { out[section][key] = value.trim(); listKey = null }
    else { out[section][key] = []; listKey = key }
  }
  // A key with no inline value opens a list. One that never got an item is simply unset —
  // and an empty array reads as *set* at every call site, which turns the template's own
  // `- exec_cmd:` into a command to run. Unset is unset, whichever way it was written.
  for (const keys of Object.values(out)) {
    for (const [key, value] of Object.entries(keys)) if (Array.isArray(value) && !value.length) keys[key] = ''
  }
  return out
}

// Base file plus the overlay of the harness running this, exactly as flow-core §0 resolves
// it: a key present in the overlay replaces the base value.
function flowConfig(repo, harness) {
  const read = (name) => {
    const p = join(repo, name)
    return existsSync(p) ? parseFlow(readFileSync(p, 'utf8')) : {}
  }
  const base = read('FLOW.md')
  const overlay = harness ? read(`FLOW.${harness}.md`) : {}
  for (const [section, keys] of Object.entries(overlay)) {
    base[section] = { ...(base[section] ?? {}), ...keys }
  }
  return base
}

function workFolder(repo, branch) {
  const root = join(repo, '.claude', 'work')
  if (!existsSync(root)) return null
  for (const entry of readdirSync(root, { withFileTypes: true })) {
    if (!entry.isDirectory() || entry.name === '_archive') continue
    const meta = join(root, entry.name, 'meta.json')
    if (!existsSync(meta)) continue
    let data
    try { data = JSON.parse(readFileSync(meta, 'utf8')) } catch { continue }
    const branches = [data.branch, ...(Array.isArray(data.mrs) ? data.mrs.map((m) => m?.branch) : [])]
    if (branches.includes(branch)) return join(root, entry.name)
  }
  return null
}

function fence(body, lang = '') {
  // A diff can legitimately contain a fence; open a longer one than anything inside it.
  const longest = Math.max(2, ...[...String(body).matchAll(/^`{3,}/gm)].map((m) => m[0].length))
  const bar = '`'.repeat(longest + 1)
  return `${bar}${lang}\n${body.replace(/\n*$/, '\n')}${bar}`
}

function buildBundle(argv) {
  const flag = (name, fallback = null) => {
    const i = argv.indexOf(name)
    return i === -1 ? fallback : argv[i + 1]
  }
  const repo = git(['rev-parse', '--show-toplevel']).trim()
  if (!repo) {
    console.error('flow bundle: not a git checkout')
    process.exit(1)
  }
  const cfg = flowConfig(repo, flag('--harness'))
  const branch = git(['rev-parse', '--abbrev-ref', 'HEAD'], repo).trim()
  const maxFile = Number(flag('--max-file-bytes', MAX_FILE_BYTES)) || MAX_FILE_BYTES

  const resolves = (ref) => Boolean(git(['rev-parse', '--verify', '--quiet', ref], repo).trim())
  let base = flag('--base') || cfg.git?.default_base || ''
  if (!base) {
    // What the remote says it defaults to, then the usual names — remote first, but a repo
    // with no remote at all still has a base branch, and a clone is not a requirement here.
    const head = git(['symbolic-ref', 'refs/remotes/origin/HEAD'], repo).trim()
    const candidates = [head && head.replace('refs/remotes/', ''),
                        'origin/main', 'origin/master', 'main', 'master'].filter(Boolean)
    base = candidates.find(resolves) || candidates[0]
  }
  // One point of comparison for everything below: the merge base, so the diff carries
  // committed and uncommitted work together — which is the diff a review is looking at.
  if (!resolves(base)) {
    console.error(`flow bundle: base \`${base}\` does not resolve in this checkout.`)
    console.error('Set `git.default_base` in FLOW.md, or pass --base. A silently empty bundle')
    console.error('reads exactly like a branch with no changes, which is worse than this error.')
    process.exit(1)
  }
  const from = git(['merge-base', base, 'HEAD'], repo).trim() || base

  const exclude = Array.isArray(cfg.git?.diff_exclude) ? cfg.git.diff_exclude
    : cfg.git?.diff_exclude ? [cfg.git.diff_exclude] : []
  const excluded = (list) => ['--', '.', ...list.map((p) => `:(exclude)${p}`)]
  const paths = exclude.length ? excluded(exclude) : []

  // One size rule for the whole pack. Applying it only to the file contents would let a
  // generated file of any size through in the diff instead — which is the same cost, one
  // section lower down, and exactly what a reviewer does not need to read.
  const changed = git(['diff', '--name-only', from, ...paths], repo).split('\n').filter(Boolean)
  const oversize = changed.filter((rel) => {
    const abs = join(repo, rel)
    return existsSync(abs) && statSync(abs).size > maxFile
  })
  const diffPaths = excluded([...exclude, ...oversize])

  const out = []
  out.push(`# flow bundle — ${branch}`)
  out.push('')
  out.push(`Base \`${base}\` · merge base \`${from.slice(0, 12)}\` · generated by \`flow bundle\`.`)
  out.push('Committed and uncommitted changes together. Nothing here is parsed or summarised.')
  out.push('')

  out.push('## Worklist')
  out.push('')
  const stat = git(['diff', '--stat', from, ...diffPaths], repo).trim()
  out.push(stat ? fence(stat) : '_no changes against the base_')
  out.push('')
  if (exclude.length) {
    out.push(`Left out by \`git.diff_exclude\`: ${exclude.map((p) => `\`${p}\``).join(' · ')}`)
    out.push('')
  }
  const untracked = git(['ls-files', '--others', '--exclude-standard'], repo).trim()
  if (untracked) {
    out.push('Untracked, so absent from the diff below:')
    out.push('')
    out.push(fence(untracked))
    out.push('')
  }

  out.push('## Diff')
  out.push('')
  const diff = git(['diff', from, ...diffPaths], repo)
  out.push(diff.trim() ? fence(diff, 'diff') : '_empty_')
  out.push('')

  out.push('## Changed files, in full')
  out.push('')
  const skipped = oversize.map((rel) => {
    const size = statSync(join(repo, rel)).size
    return `${rel} — ${size} bytes, over --max-file-bytes (${maxFile}); left out of the diff too`
  })
  let spent = 0
  for (const rel of changed) {
    const abs = join(repo, rel)
    if (!existsSync(abs)) continue                     // deleted: the diff already carries it
    if (oversize.includes(rel)) continue
    const size = statSync(abs).size
    if (spent + size > MAX_TOTAL_BYTES) { skipped.push(`${rel} — bundle full`); continue }
    spent += size
    out.push(`### ${rel}`)
    out.push('')
    out.push(fence(readFileSync(abs, 'utf8')))
    out.push('')
  }
  if (skipped.length) {
    out.push('### Not included')
    out.push('')
    out.push(skipped.map((s) => `- ${s}`).join('\n'))
    out.push('')
  }

  if (argv.includes('--checks')) {
    const cmd = cfg.quality?.static_analysis
    out.push('## Checks')
    out.push('')
    if (!cmd) {
      out.push('_`quality.static_analysis` is empty — nothing to run_')
    } else {
      out.push(`\`quality.static_analysis\`: \`${cmd}\``)
      out.push('')
      let body, code = 0
      try {
        body = execFileSync('sh', ['-c', cmd], {
          cwd: repo, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024, stdio: ['ignore', 'pipe', 'pipe'],
        })
      } catch (e) {
        body = `${e.stdout ?? ''}${e.stderr ?? ''}`
        code = e.status ?? 1
      }
      out.push(fence(`${body.trim() || '(no output)'}\n\nexit ${code}`))
    }
    out.push('')
  }

  const work = workFolder(repo, branch)
  if (work) {
    out.push('## Work')
    out.push('')
    for (const name of ['meta.json', '00-summary.md']) {
      const p = join(work, name)
      if (!existsSync(p)) continue
      out.push(`### ${name}`)
      out.push('')
      out.push(fence(readFileSync(p, 'utf8'), name.endsWith('.json') ? 'json' : ''))
      out.push('')
    }
  }

  return { text: out.join('\n'), repo, cfg, branch, work }
}

function bundle(argv) {
  console.log(buildBundle(argv).text)
}

// --- review ----------------------------------------------------------------------------
// The panel is the most expensive thing the flow does, and most of what it spends is not
// review: each subagent is an agentic loop that rediscovers the diff before reading it.
// Once `bundle` hands it the material, a reviewer needs one turn, not eighteen.
//
// This spawns a command. It does not know, and must not know, what is behind it: a
// subscription login, an API key, another vendor's CLI, or a script of your own. That is
// what `agents.exec_cmd` is — and why no provider SDK belongs in this package.

const REVIEW_SCHEMA = JSON.stringify({
  type: 'object',
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          file: { type: 'string' },
          line: { type: 'integer' },
          severity: { type: 'string', enum: ['blocker', 'major', 'minor', 'nit'] },
          what: { type: 'string' },
          fix: { type: 'string' },
        },
        required: ['file', 'what', 'fix'],
      },
    },
  },
  required: ['findings'],
})

// Neutral dimensions, used only when `quality.reviewers` is empty. Naming a stack here
// would be the leak the preflight exists to catch; these are categories, not tools.
const DEFAULT_ROLES = [
  'correctness: logic that does not do what the change claims, broken edge cases, error paths',
  'security: untrusted input reaching a sink, authorisation gaps, secrets, unsafe defaults',
  'data access: queries in loops, missing bounds, writes without a transaction, schema risk',
  'tests: what the change broke and the tests do not cover, and assertions that prove nothing',
]

function firstJson(text) {
  // Tolerant on purpose: only one harness has a structured-output flag, and requiring it
  // would lock every other one out. Find the first balanced JSON object and parse that.
  for (let i = text.indexOf('{'); i !== -1; i = text.indexOf('{', i + 1)) {
    let depth = 0, inStr = false, esc = false
    for (let j = i; j < text.length; j++) {
      const c = text[j]
      if (esc) { esc = false; continue }
      if (c === '\\') { esc = true; continue }
      if (c === '"') { inStr = !inStr; continue }
      if (inStr) continue
      if (c === '{') depth++
      else if (c === '}' && --depth === 0) {
        try { return JSON.parse(text.slice(i, j + 1)) } catch { break }
      }
    }
  }
  return null
}

// A harness with a structured-output flag answers in an envelope of its own: the findings
// arrive under `structured_output`, or as a JSON string in `result`, alongside the run's
// cost. Reading only the root is what made every role report nothing while the command
// exited 0 — the failure that looks like a clean diff. Unwrap one level, and keep the
// envelope's cost, which the inner object never carries.
function unwrapFindings(parsed) {
  if (!parsed || typeof parsed !== 'object') return null
  const cost = parsed.total_cost_usd ?? null
  if (Array.isArray(parsed.findings)) return { findings: parsed.findings, cost }
  const inner = Array.isArray(parsed.structured_output?.findings) ? parsed.structured_output
    : typeof parsed.result === 'string' ? firstJson(parsed.result)
      : null
  if (inner && Array.isArray(inner.findings)) return { findings: inner.findings, cost: cost ?? inner.total_cost_usd ?? null }
  return null
}

function runRole(cmd, role, pack, repo) {
  const shellSafe = (s) => String(s).replace(/(["\\$`])/g, '\\$1')
  const line = cmd.replaceAll('{ROLE}', shellSafe(role)).replaceAll('{SCHEMA}', shellSafe(REVIEW_SCHEMA))
  const brief = [
    `You are reviewing a diff. Your dimension, and nothing else: ${role}`,
    '',
    'Report findings only. One per entry, each with the file, the line if you can place it,',
    'what is wrong and the fix. No preamble, no summary, no praise. Nothing to report is a',
    'valid answer: return an empty list.',
    '',
    `Answer with JSON matching this schema and nothing else: ${REVIEW_SCHEMA}`,
    '',
    '--- the change under review ---',
    '',
    pack,
  ].join('\n')

  return new Promise((resolve) => {
    const child = spawn('sh', ['-c', line], { cwd: repo, stdio: ['pipe', 'pipe', 'pipe'] })
    let out = '', err = ''
    child.stdout.on('data', (d) => { out += d })
    child.stderr.on('data', (d) => { err += d })
    child.on('error', (e) => resolve({ role, error: e.message, findings: [] }))
    // A command that answers without reading the brief closes the pipe under us. That is a
    // review to judge on its output, not a crash of the round the other reviewers are in.
    child.stdin.on('error', () => {})
    child.on('close', (code) => {
      const got = unwrapFindings(firstJson(out))
      if (!got) {
        resolve({ role, code, error: `no JSON findings in the output${err ? ` (stderr: ${err.trim().slice(0, 200)})` : ''}`, findings: [] })
        return
      }
      resolve({ role, code, findings: got.findings, cost: got.cost })
    })
    child.stdin.end(brief)
  })
}

async function review(argv) {
  const built = buildBundle(argv)
  const { cfg, repo } = built
  const cmd = cfg.agents?.exec_cmd
  if (!cmd) {
    console.error('flow review: `agents.exec_cmd` is empty in FLOW.md.')
    console.error('That key is the opt-in for running the panel from here; without it the')
    console.error('agentic panel inside /flow:*:review is what reviews, exactly as before.')
    console.error('It takes any non-interactive harness invocation — {ROLE} and {SCHEMA} are')
    console.error('substituted, and the diff arrives on stdin.')
    process.exit(1)
  }

  // Substitution escapes for a double-quoted context. Inside single quotes those
  // backslashes reach the harness literally, the schema is no longer valid JSON, and every
  // role answers nothing — paid for, once per reviewer, with a clean-looking panel to show
  // for it. It cannot work, so it stops here rather than in the artifact.
  if (/'[^']*\{(SCHEMA|ROLE)\}[^']*'/.test(cmd)) {
    console.error('flow review: `{SCHEMA}`/`{ROLE}` sit inside single quotes in `agents.exec_cmd`.')
    console.error('The substitution escapes for double quotes, so single ones hand the command')
    console.error('invalid JSON and every role reports nothing. Use "{SCHEMA}" there.')
    process.exit(1)
  }

  const configured = Array.isArray(cfg.quality?.reviewers) ? cfg.quality.reviewers : []
  const roles = configured.length ? configured : DEFAULT_ROLES
  const fanout = Number(cfg.agents?.fanout_max) || 4
  const budget = cfg.agents?.budget_max === '0' ? Infinity : (Number(cfg.agents?.budget_max) || 12)
  const cap = Math.min(roles.length, budget)
  const dropped = roles.slice(cap)

  const results = []
  for (let i = 0; i < cap; i += fanout) {
    // `fanout_max` bounds the round, `budget_max` bounds the command: a round that reaches
    // past the ceiling is how a panel ends up an order of magnitude over what was asked for,
    // so the slice is capped by both.
    const round = roles.slice(i, Math.min(i + fanout, cap))
    results.push(...await Promise.all(round.map((r) => runRole(cmd, r, built.text, repo))))
  }

  // Deduplicate in code. Two reviewers finding the same thing is the panel working; the
  // main thread paying model prices to notice that is not.
  const seen = new Map()
  for (const r of results) {
    for (const f of r.findings) {
      const key = `${f.file}:${f.line ?? ''}:${String(f.what).toLowerCase().replace(/\W+/g, ' ').trim().slice(0, 80)}`
      if (seen.has(key)) { seen.get(key).roles.push(r.role); continue }
      seen.set(key, { ...f, roles: [r.role] })
    }
  }
  const order = { blocker: 0, major: 1, minor: 2, nit: 3 }
  const findings = [...seen.values()].sort((a, b) => (order[a.severity] ?? 9) - (order[b.severity] ?? 9))

  const out = [`# Review — ${built.branch}`, '']
  out.push(`${findings.length} finding(s) from ${results.length} reviewer(s), deduplicated.`)
  out.push('')
  for (const f of findings) {
    out.push(`- **${f.severity ?? 'unrated'}** \`${f.file}${f.line ? `:${f.line}` : ''}\` — ${f.what}`)
    out.push(`  fix: ${f.fix}`)
    if (f.roles.length > 1) out.push(`  raised by ${f.roles.length} reviewers`)
  }
  if (!findings.length) out.push('_none_')
  out.push('')
  out.push('## Cost')
  out.push('')
  out.push(`${results.length}/${budget === Infinity ? '∞' : budget} reviewers, ${fanout} per round.`)
  const costs = results.map((r) => r.cost).filter((c) => typeof c === 'number')
  out.push(costs.length
    ? `Reported by the harness: $${costs.reduce((a, b) => a + b, 0).toFixed(4)} over ${costs.length} run(s).`
    : 'The harness reported no cost figure, so this run has none to show.')
  const failed = results.filter((r) => r.error)
  if (failed.length) {
    out.push('')
    out.push('## Reviewers that returned nothing usable')
    out.push('')
    failed.forEach((r) => out.push(`- ${r.role.split(':')[0]} — ${r.error}`))
  }
  if (dropped.length) {
    out.push('')
    out.push(`## Skipped for budget`)
    out.push('')
    dropped.forEach((r) => out.push(`- ${r.split(':')[0]}`))
  }

  const text = out.join('\n')
  if (argv.includes('--record')) {
    recordCost(built.work, {
      phase: 'review',
      at: new Date().toISOString(),
      reviewers: results.length,
      usd: costs.length ? Number(costs.reduce((a, b) => a + b, 0).toFixed(6)) : null,
      source: costs.length ? 'harness' : 'not reported',
    })
  }
  const outFile = argv.includes('--out') ? argv[argv.indexOf('--out') + 1] : null
  if (outFile) { writeFileSync(outFile, `${text}\n`); console.log(`wrote ${outFile}`) } else console.log(text)
}

// --- cost ------------------------------------------------------------------------------
// `review` reports `<n>/<budget_max> subagents launched`, which is a headcount: two runs
// with the same count differ by an order of magnitude depending on the turns each agent
// took. The ceilings are tuned against that headcount, so they are tuned against the wrong
// number — and nobody can say whether lowering `review_depth` actually helped.
//
// What this does NOT do is guess. A harness that reports nothing gets "not reported", and
// every figure it does show is a client-side estimate, which is what the harnesses call
// them too.

function recordCost(work, entry) {
  if (!work) return
  const p = join(work, 'meta.json')
  if (!existsSync(p)) return
  let meta
  try { meta = JSON.parse(readFileSync(p, 'utf8')) } catch { return }
  meta.cost = Array.isArray(meta.cost) ? meta.cost : []
  meta.cost.push(entry)
  // Write through a temporary file: meta.json is the flow's own state, and a half-written
  // one loses the work, not just the figure.
  const tmp = `${p}.tmp`
  writeFileSync(tmp, `${JSON.stringify(meta, null, 2)}\n`)
  renameSync(tmp, p)
}

function cost(argv) {
  const repo = git(['rev-parse', '--show-toplevel']).trim()
  if (!repo) { console.error('flow cost: not a git checkout'); process.exit(1) }
  const branch = git(['rev-parse', '--abbrev-ref', 'HEAD'], repo).trim()
  const work = workFolder(repo, branch)
  if (!work) {
    console.log(`No work on \`${branch}\`, so nothing has been recorded against it.`)
    return
  }
  let meta = {}
  try { meta = JSON.parse(readFileSync(join(work, 'meta.json'), 'utf8')) } catch {}
  const entries = Array.isArray(meta.cost) ? meta.cost : []

  console.log(`# Cost — ${meta.ticket ?? branch}`)
  console.log()
  if (!entries.length) {
    console.log('Nothing recorded yet. A phase records here when it can measure what it spent:')
    console.log('`flow review --record` writes what the harness reported for its round, and a')
    console.log('harness that reports no figure is recorded as "not reported" rather than guessed.')
    return
  }
  console.log('| phase | when | agents | reported | source |')
  console.log('|---|---|---|---|---|')
  let total = 0
  for (const e of entries) {
    if (typeof e.usd === 'number') total += e.usd
    console.log(`| ${e.phase ?? '?'} | ${String(e.at ?? '').slice(0, 16).replace('T', ' ')} `
      + `| ${e.reviewers ?? '—'} | ${typeof e.usd === 'number' ? `$${e.usd.toFixed(4)}` : '—'} `
      + `| ${e.source ?? '?'} |`)
  }
  console.log()
  console.log(`Recorded so far: **$${total.toFixed(4)}** over ${entries.length} run(s).`)
  console.log()
  console.log('These are the harness\'s own client-side estimates and can differ from a bill.')
  console.log('Phases with no row did not measure anything — absence here is not zero.')
}

function usage() {
  console.log(`flow-workflows v${version()} — guided feat/bug workflows for coding agents

  npx flow-workflows install <harness> [project]
  npx flow-workflows check
  npx flow-workflows bundle [--base <ref>] [--checks] [--harness <name>] [--max-file-bytes N]
  npx flow-workflows review [--out <file>] [--record] [same options as bundle]
  npx flow-workflows cost

Harnesses: ${Object.keys(HARNESSES).join(' · ')}
  "project" installs into the current repo instead of your user folder.

Claude Code and Codex CLI have their own marketplaces:
  npx flow-workflows install claude    shows how

"bundle" prints one context pack for the current branch — worklist, diff, the changed
  files in full, and the work's handoff — so a phase reads it in one call instead of
  rediscovering it in ten. --checks also runs quality.static_analysis and copies its
  output out verbatim. Paths in git.diff_exclude are left out of the diff.

"review" runs one reviewer per role through agents.exec_cmd — any non-interactive
  harness invocation — over that same pack, one turn each instead of an agentic loop
  each, and deduplicates what comes back. Empty exec_cmd = the agentic panel reviews,
  as it always has.

"cost" prints what each phase of this branch's work actually reported spending, from
  what --record wrote into meta.json. A harness that reports no figure is recorded as
  "not reported": a headcount of subagents is not a cost, and neither is a guess.

Updating: re-run the install command — it sweeps the previous version first.
Docs: https://github.com/mashware/flow-workflows`)
}

const [cmd, tool, scope] = process.argv.slice(2)

if (cmd === 'bundle') bundle(process.argv.slice(3))
else if (cmd === 'cost') cost(process.argv.slice(3))
else if (cmd === 'review') review(process.argv.slice(3)).catch((e) => { console.error(`flow review: ${e.message}`); process.exit(1) })
else if (cmd === 'check') check()
else if (cmd === 'install' && tool === 'claude') claude()
else if (cmd === 'install' && HARNESSES[tool]) install(tool, scope === 'project' ? 'project' : 'global')
else if (cmd === 'install') {
  console.error(`Unknown harness: ${tool ?? '(none given)'}`)
  console.error(`Expected one of: ${Object.keys(HARNESSES).join(', ')}, claude`)
  process.exit(1)
} else if (cmd === '--version' || cmd === '-v') console.log(version())
else if (!cmd || cmd === '--help' || cmd === '-h' || cmd === 'help') usage()
else {
  console.error(`Unknown command: ${cmd}`)
  usage()
  process.exit(1)
}
