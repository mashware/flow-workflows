#!/usr/bin/env node
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync } from 'node:fs'
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

function usage() {
  console.log(`flow-workflows v${version()} — guided feat/bug workflows for coding agents

  npx flow-workflows install <harness> [project]
  npx flow-workflows check

Harnesses: ${Object.keys(HARNESSES).join(' · ')}
  "project" installs into the current repo instead of your user folder.

Claude Code and Codex CLI have their own marketplaces:
  npx flow-workflows install claude    shows how

Updating: re-run the install command — it sweeps the previous version first.
Docs: https://github.com/mashware/flow-workflows`)
}

const [cmd, tool, scope] = process.argv.slice(2)

if (cmd === 'check') check()
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
