#!/usr/bin/env node
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync } from 'node:fs'
import { homedir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { execFileSync } from 'node:child_process'

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

function bundle(argv) {
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

  console.log(out.join('\n'))
}

function usage() {
  console.log(`flow-workflows v${version()} — guided feat/bug workflows for coding agents

  npx flow-workflows install <harness> [project]
  npx flow-workflows check
  npx flow-workflows bundle [--base <ref>] [--checks] [--harness <name>] [--max-file-bytes N]

Harnesses: ${Object.keys(HARNESSES).join(' · ')}
  "project" installs into the current repo instead of your user folder.

Claude Code and Codex CLI have their own marketplaces:
  npx flow-workflows install claude    shows how

"bundle" prints one context pack for the current branch — worklist, diff, the changed
  files in full, and the work's handoff — so a phase reads it in one call instead of
  rediscovering it in ten. --checks also runs quality.static_analysis and copies its
  output out verbatim. Paths in git.diff_exclude are left out of the diff.

Updating: re-run the install command — it sweeps the previous version first.
Docs: https://github.com/mashware/flow-workflows`)
}

const [cmd, tool, scope] = process.argv.slice(2)

if (cmd === 'bundle') bundle(process.argv.slice(3))
else if (cmd === 'check') check()
else if (cmd === 'install' && tool === 'claude') claude()
else if (cmd === 'install' && HARNESSES[tool]) install(tool, scope === 'project' ? 'project' : 'global')
else if (cmd === 'install') {
  console.error(`Unknown harness: ${tool ?? '(none given)'}`)
  console.error(`Expected one of: ${Object.keys(HARNESSES).join(', ')}, claude`)
  process.exit(1)
} else if (!cmd || cmd === '--help' || cmd === '-h' || cmd === 'help') usage()
else {
  console.error(`Unknown command: ${cmd}`)
  usage()
  process.exit(1)
}
