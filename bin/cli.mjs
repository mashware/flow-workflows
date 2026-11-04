#!/usr/bin/env node
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, realpathSync, renameSync, rmSync, statSync, writeFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
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

function zcode() {
  console.log('zcode reads this plugin package directly, from its own marketplace, not from npm:')
  console.log()
  console.log('  zcode plugins marketplace add mashware/flow-workflows')
  console.log('  zcode plugins install flow@flow-plugins')
  console.log()
  console.log('Then /flow:init in your repo. Updates arrive through `zcode plugins update flow`.')
  console.log('Type the /flow:-prefixed commands: zcode also exposes the plugin\'s Claude pages')
  console.log('unprefixed (/feat:start, /init, …), and those carry --harness claude.')
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
const MAX_DIFF_LINES = 2000

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
// A value wrapped in matching quotes means what is inside them. The template writes globs
// that way (`- '*.lock'`), and keeping the quotes turned every one of them into a pathspec
// that matches a filename with quotes in it — so the key silently excluded nothing. Only a
// whole-value wrap is stripped: a command that quotes one of its own arguments is untouched.
function unquote(v) {
  const m = /^(['"])([\s\S]*)\1$/.exec(v)
  return m ? m[2] : v
}

function parseFlow(text) {
  const out = {}
  let section = null
  let listKey = null
  let fence = null
  for (const line of text.split('\n')) {
    // A fenced block is an illustration, not configuration. This reader knows headings and
    // `- key:` lines and nothing else, so an example written the way `docs/CONFIGURATION.md`
    // and every FLOW.md in the wild write one — keys inside triple backticks, under a sentence
    // saying "paste this to try it" — was live config the whole time. A real repo had
    // `agents.exec_cmd` set from the block of a file whose prose argued, at length, that it was
    // deliberately unset, and every review round took the one-shot path it warned against.
    // Closing fence: same character, at least as long as the opening one (CommonMark).
    const f = /^\s{0,3}(`{3,}|~{3,})/.exec(line)
    if (f) {
      if (!fence) fence = f[1]
      else if (f[1][0] === fence[0] && f[1].length >= fence.length) fence = null
      continue
    }
    if (fence) continue
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
      out[section][listKey].push(unquote(item[1].trim()))
      continue
    }
    const kv = /^-\s+`?([a-z_]+)`?:\s*(.*)$/.exec(line)
    if (!kv) { listKey = null; continue }
    const [, key, value] = kv
    if (value.trim()) { out[section][key] = unquote(value.trim()); listKey = null }
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

// Where a FLOW file actually is. A phase run inside a linked worktree has its own root, and a
// `FLOW.md` the repo git-ignores exists only in the main checkout — so a worktree would resolve
// every key to its fallback and say nothing. Prefer the root we are in (a repo that commits its
// config gets it in every worktree, and a worktree may legitimately differ), and fall back to the
// main checkout, which `--git-common-dir` points into from anywhere.
// The main checkout is asked of git once per run: every FLOW layer and overlay probe needs it.
const mainCheckouts = new Map()
function mainCheckout(repo) {
  if (!mainCheckouts.has(repo)) {
    const common = git(['rev-parse', '--path-format=absolute', '--git-common-dir'], repo).trim()
    mainCheckouts.set(repo, common ? dirname(common) : repo)
  }
  return mainCheckouts.get(repo)
}

function rootHolding(repo, probe) {
  if (existsSync(join(repo, probe))) return repo
  const main = mainCheckout(repo)
  return main !== repo && existsSync(join(main, probe)) ? main : repo
}

// Exactly this name, case included. A case-insensitive filesystem answers `existsSync` for
// `FLOW.CI.md` with `FLOW.ci.md`, which neither the agent's listing nor a Linux CI would read.
function hasFile(root, name) {
  try { return readdirSync(root).includes(name) } catch { return false }
}

// A FLOW file is taken from the main checkout only when that checkout's HEAD does not track it —
// the git-ignored personal file a worktree never carries. One it tracks is committed, so its
// absence here is this branch's own state (deleted, renamed, not added yet), and the main
// checkout's copy would be another branch's version. When git cannot answer, nothing is borrowed:
// a guess here reads another branch's config, and the note says why the file was not read.
function flowRoot(repo, name) {
  if (hasFile(repo, name)) return { root: repo, note: '' }
  const main = mainCheckout(repo)
  if (main === repo || !hasFile(main, name)) return { root: repo, note: '' }
  let tracked
  try {
    tracked = execFileSync('git', ['ls-tree', '--name-only', 'HEAD', '--', name], {
      cwd: main, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'],
    }).trim()
  } catch {
    return { root: repo, note: `${name} in ${main} not read: git could not say whether that checkout tracks it` }
  }
  return { root: tracked ? repo : main, note: '' }
}

// The overlay names flow-core §0 recognises. A `--harness` outside this set reads no
// overlay and looks exactly like a repo that has none, so it stops the run instead: a typo
// here is worth one error message and never worth a review round nobody can trust.
const OVERLAY_HARNESSES = ['claude', 'codex', 'gemini', 'hermes', 'opencode', 'zcode']

// The context layer, `FLOW.<FLOW_CONTEXT>.md`, is chosen by whoever launches flow. The name
// becomes part of a path, so it is held to one plain ASCII segment, and a harness name would read an
// overlay as the wrong layer — compared ignoring case, because `FLOW.Claude.md` opens
// `FLOW.claude.md` on a case-insensitive filesystem. Nothing is trimmed: the agent reading the
// same variable by flow-core §0 takes it as written, and the two must resolve the same layer. A
// name that fails is skipped and named, never fatal: the phases calling this must not stop on
// configuration.
const CONTEXT_NAME = /^[A-Za-z0-9][A-Za-z0-9_-]*$/

function flowContext() {
  const value = process.env.FLOW_CONTEXT ?? ''
  if (value === '') return { name: null, note: '' }
  if (CONTEXT_NAME.test(value) && !OVERLAY_HARNESSES.includes(value.toLowerCase())) {
    return { name: value, note: '' }
  }
  // Echoed into the pack's header, which reviewers read as Markdown: a refused value is shown as
  // inline code, escaped so that no newline, backtick or `<!--` in it can open anything there.
  const shown = JSON.stringify(value).replace(/`/g, '\\u0060')
  return {
    name: null,
    note: `FLOW_CONTEXT=\`${shown}\` ignored: a context is an ASCII name matching`
      + ` [A-Za-z0-9][A-Za-z0-9_-]* other than a harness (${OVERLAY_HARNESSES.join(', ')})`,
  }
}

// The layers this run reads, in merge order, each located on its own. One root for all of
// them misses one whenever they live apart: a committed `FLOW.<context>.md` is in the worktree
// while a git-ignored `FLOW.md` or overlay exists only in the main checkout — and reading the
// main checkout's copy of a committed file reads another branch's version of it.
//
// Under `--rev` a layer the frozen revision holds is read from it: the context file is tracked,
// so it belongs to the revision being reviewed as much as the diff does, and a round editing it
// mid-flight must not hand each reader a different exclude list. An untracked layer is in no
// revision and is read live, as before.
function flowLayers(repo, harness, rev = null) {
  const context = flowContext()
  const contextFile = context.name && `FLOW.${context.name}.md`
  const layers = ['FLOW.md', contextFile, harness && `FLOW.${harness}.md`].filter(Boolean).map((name) => {
    const layer = { name, context: name === contextFile, note: '' }
    if (rev) {
      const text = gitBlob(repo, rev, name)
      if (text !== null) return { ...layer, root: repo, at: rev, text, found: true }
    }
    const { root, note } = flowRoot(repo, name)
    return { ...layer, root, note, found: hasFile(root, name) }
  })
  return { layers, context }
}

function gitBlob(repo, rev, name) {
  try {
    return execFileSync('git', ['show', `${rev}:${name}`], {
      cwd: repo, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024, stdio: ['ignore', 'pipe', 'ignore'],
    })
  } catch {
    return null
  }
}

// Which config files a run actually read. The pack says so out loud because the failure it
// makes visible is silent by nature: a phase that read the base and never looked for the
// overlay reports every key it set as unset, which is what a repo with no overlay reports too.
//
// Called without `--harness` this command is that phase. It reads the base alone and its own
// header then says `FLOW.md`, which is what a repo with no overlay prints — the same silence
// one level down, and the one the line exists to break. So a run that skipped an overlay names
// the file it skipped, because that file is where `agents.exec_cmd` and a harness's models
// live and their absence is indistinguishable from a decision not to set them. A context file
// left unread is not in that list: no `FLOW_CONTEXT` is how a laptop leaves it out on purpose.
function configFiles(repo, harness, rev = null) {
  const { layers, context } = flowLayers(repo, harness, rev)
  const found = layers.filter((l) => l.found)
  const label = (l) => l.name + (l.context ? ` [FLOW_CONTEXT=${context.name}]` : '')
    + (l.at ? ` (at ${l.at.slice(0, 12)})` : l.root === repo ? '' : ` (from ${l.root})`)
  const notes = [found.length ? found.map(label).join(' + ') : `none found in ${repo}`]
  if (context.note) notes.push(context.note)
  for (const l of layers) if (l.note) notes.push(l.note)
  for (const l of layers) if (l.context && !l.found) notes.push(`FLOW_CONTEXT=${context.name}: ${l.name} not found`)
  const skipped = harness ? []
    : OVERLAY_HARNESSES.map((h) => `FLOW.${h}.md`).filter((n) => hasFile(flowRoot(repo, n).root, n))
  if (skipped.length) notes.push(`no \`--harness\` was given, so ${skipped.join(', ')} went unread`)
  return notes.join(' — ')
}

// Base, then the context layer, then the overlay of the harness running this, exactly as
// flow-core §0 resolves it: a key present in a later layer replaces the earlier value.
function flowConfig(repo, harness, rev = null) {
  const merged = {}
  for (const l of flowLayers(repo, harness, rev).layers) {
    if (!l.found) continue
    const text = l.text ?? readFileSync(join(l.root, l.name), 'utf8')
    for (const [section, keys] of Object.entries(parseFlow(text))) {
      merged[section] = { ...(merged[section] ?? {}), ...keys }
    }
  }
  return merged
}

// `.claude/work` is git-ignored like the FLOW files, so a worktree does not carry it either — and
// the two things that read it fail silently when it is missing: the pack drops its `## Work`
// section, which it advertises and no reviewer knows to miss, and `--record` used to write the
// figure nowhere and exit 0. Same resolution as the config: here first, the main checkout otherwise.
function workFolder(repo, branch) {
  const root = join(rootHolding(repo, join('.claude', 'work')), '.claude', 'work')
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
  const harness = flag('--harness')
  if (harness && !OVERLAY_HARNESSES.includes(harness)) {
    console.error(`flow bundle: unknown harness \`${harness}\`.`)
    console.error(`The overlay it would read is \`FLOW.${harness}.md\`, which flow-core §0 does not`)
    console.error(`recognise. One of: ${OVERLAY_HARNESSES.join(', ')}.`)
    process.exit(1)
  }
  const resolves = (ref) => Boolean(git(['rev-parse', '--verify', '--quiet', ref], repo).trim())
  // `--rev` freezes what is read. Without it the pack is the live checkout, which is the
  // right answer for a phase that is about to edit it and the wrong one for a review: the
  // round applies its own fixes while its reviewers are still reading, so "the tree" is a
  // different tree for each of them and for the sha recorded at the end. A caller that has
  // resolved a candidate — a commit, or a `git stash create` object holding a dirty tree —
  // passes it here and every section below reads that one revision, the config it commits
  // included.
  const rev = flag('--rev')
  if (rev && !resolves(rev)) {
    console.error(`flow bundle: --rev \`${rev}\` does not resolve in this checkout.`)
    console.error('Pass a commit, a tag, or the object `git stash create` printed. A pack')
    console.error('built from a revision nobody can name is evidence about nothing.')
    process.exit(1)
  }
  const to = rev ? git(['rev-parse', rev], repo).trim() : null
  const cfg = flowConfig(repo, harness, to)
  const configs = configFiles(repo, harness, to)
  const branch = git(['rev-parse', '--abbrev-ref', 'HEAD'], repo).trim()
  const maxFile = Number(flag('--max-file-bytes', MAX_FILE_BYTES)) || MAX_FILE_BYTES
  const maxDiffLines = Number(flag('--max-diff-lines', MAX_DIFF_LINES)) || MAX_DIFF_LINES

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
    console.error(`Config read: ${configs}.`)
    process.exit(1)
  }
  const from = git(['merge-base', base, to ?? 'HEAD'], repo).trim() || base
  // Every diff below runs `from` → `ends`, and an empty `ends` means the working tree.
  const ends = to ? [to] : []

  const exclude = Array.isArray(cfg.git?.diff_exclude) ? cfg.git.diff_exclude
    : cfg.git?.diff_exclude ? [cfg.git.diff_exclude] : []
  const excluded = (list) => ['--', '.', ...list.map((p) => `:(exclude)${p}`)]
  const paths = exclude.length ? excluded(exclude) : []

  // Two limits, because how big a file is and how big its change is are different questions,
  // and one rule for both answers neither. A 1 MB source file with a 40-line edit belongs in
  // the diff and not in the contents — measuring it by its size drops the change this pack
  // exists to carry, and says so in a section nobody reads before the diff they were handed.
  // A file whose *diff* is enormous is the one a reviewer cannot use, and a generated file
  // nobody reviews at all belongs in `git.diff_exclude`, which is the key for exactly that.
  const changed = git(['diff', '--name-only', from, ...ends, ...paths], repo).split('\n').filter(Boolean)

  // `--numstat -z`: `<add>\t<del>\t<path>\0`, and for a rename an empty path field followed by
  // the old and new paths as their own records. A path we fail to match simply keeps its diff,
  // which is the safe direction for a rule whose failure mode was dropping too much.
  const churn = new Map()
  const fields = git(['diff', '--numstat', '-z', from, ...ends, ...paths], repo).split('\0')
  for (let i = 0; i < fields.length; i += 1) {
    const m = /^(\d+|-)\t(\d+|-)\t(.*)$/.exec(fields[i])
    if (!m) continue
    let rel = m[3]
    if (!rel) { rel = fields[i + 2] ?? ''; i += 2 }       // rename: old, new
    if (!rel) continue
    churn.set(rel, m[1] === '-' || m[2] === '-' ? null : Number(m[1]) + Number(m[2]))
  }
  const unreadableDiff = changed.filter((rel) => {
    const n = churn.get(rel)
    return n === null || (n !== undefined && n > maxDiffLines)
  })
  const diffPaths = excluded([...exclude, ...unreadableDiff])

  // With `--rev` the contents come out of that revision too. Reading them off disk instead
  // would hand a reviewer a diff of one tree and the files of another — the exact confusion
  // freezing exists to remove, and invisible in the pack, because both halves look right.
  const blobs = new Map()
  const contents = (rel) => {
    if (!to) return existsSync(join(repo, rel)) ? readFileSync(join(repo, rel), 'utf8') : null
    if (blobs.has(rel)) return blobs.get(rel)
    let body = null
    try {
      body = execFileSync('git', ['show', `${to}:${rel}`], {
        cwd: repo, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, stdio: ['ignore', 'pipe', 'ignore'],
      })
    } catch { body = null }                            // deleted in the candidate
    blobs.set(rel, body)
    return body
  }

  // The contents section keeps the file-size rule: it is the one place a file's own size is
  // what it costs.
  const sizeOf = (rel) => {
    if (to) { const b = contents(rel); return b === null ? null : Buffer.byteLength(b) }
    const abs = join(repo, rel)
    return existsSync(abs) ? statSync(abs).size : null
  }
  const oversize = changed.filter((rel) => {
    const size = sizeOf(rel)
    return size !== null && size > maxFile
  })

  const out = []
  out.push(`# flow bundle — ${branch}`)
  out.push('')
  out.push(`Base \`${base}\` · merge base \`${from.slice(0, 12)}\` · generated by \`flow bundle\`.`)
  out.push(`Config read: ${configs}.`)
  if (to) {
    out.push(`Revision \`${to.slice(0, 12)}\` (\`--rev ${rev}\`) — **frozen**. Every diff and every`)
    out.push('file below is that one revision, not the checkout, which may have moved since.')
  } else {
    out.push('Committed and uncommitted changes together. Nothing here is parsed or summarised.')
  }
  out.push('')

  out.push('## Worklist')
  out.push('')
  // The whole change, not the part that survived the limits below: a worklist that agrees
  // with a reduced diff is how a reviewer reads half a change and never finds out.
  const stat = git(['diff', '--stat', from, ...ends, ...paths], repo).trim()
  out.push(stat ? fence(stat) : '_no changes against the base_')
  out.push('')
  if (exclude.length) {
    out.push(`Left out by \`git.diff_exclude\`: ${exclude.map((p) => `\`${p}\``).join(' · ')}`)
    out.push('')
  }
  if (unreadableDiff.length) {
    out.push('**Not in the diff below**, over `--max-diff-lines` (' + maxDiffLines + ') or binary — read these from git before reviewing them:')
    out.push('')
    out.push(unreadableDiff.map((rel) => {
      const n = churn.get(rel)
      return `- \`${rel}\` — ${n === null ? 'binary' : `${n} changed lines`}`
    }).join('\n'))
    out.push('')
  }
  const untracked = git(['ls-files', '--others', '--exclude-standard'], repo).trim()
  if (untracked) {
    out.push(to
      ? 'Untracked in the checkout, so in no revision and absent from the diff below:'
      : 'Untracked, so absent from the diff below:')
    out.push('')
    out.push(fence(untracked))
    out.push('')
  }

  out.push('## Diff')
  out.push('')
  const diff = git(['diff', from, ...ends, ...diffPaths], repo)
  out.push(diff.trim() ? fence(diff, 'diff') : '_empty_')
  out.push('')

  out.push('## Changed files, in full')
  out.push('')
  const skipped = oversize.map((rel) =>
    `${rel} — ${sizeOf(rel)} bytes, over --max-file-bytes (${maxFile}); its diff is above`)
  let spent = 0
  for (const rel of changed) {
    if (oversize.includes(rel)) continue
    const body = contents(rel)
    if (body === null) continue                        // deleted: the diff already carries it
    const size = Buffer.byteLength(body)
    if (spent + size > MAX_TOTAL_BYTES) { skipped.push(`${rel} — bundle full`); continue }
    spent += size
    out.push(`### ${rel}`)
    out.push('')
    out.push(fence(body))
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
      if (to) {
        out.push('')
        out.push('Run against the **checkout**, not the frozen revision above — a linter reads the')
        out.push('working tree and this does not rewrite it. Where the two differ, the diff is the')
        out.push('evidence and this output is a second reading, taken later.')
      }
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

  return { text: out.join('\n'), repo, cfg, branch, work, configs }
}

// --- tier -------------------------------------------------------------------------------
// §2.0 of feat/review.md was 822 words of arithmetic addressed to a model: measure the diff,
// read a four-row table, take the lower of that and meta.json.size, apply the bump, flag a
// measurement landing just under a threshold. None of it is judgement, and the cost was never
// mainly the tokens — it is that the result cannot be checked. `06-review.md` recorded the tier
// the agent *said* it derived, and a round that eyeballed the diff wrote a byte-identical
// artifact. The section is explicitly aware the number carries an incentive, and then left the
// measuring to the party the incentive acts on.
//
// What stays with the model is what a command cannot see: whether a diff on a sensitive path
// changes control flow or only observability. This prints the paths and the two tiers; it does
// not pretend to decide that.

const SIZES = [['XS', 150], ['S', 600], ['M', 1500], ['L', Infinity]]
const LADDER = ['low', 'medium', 'high', 'xhigh', 'max']
const BASE_EFFORT = { XS: 'medium', S: 'high', M: 'high', L: 'xhigh' }
const PANEL = { XS: 'no', S: 'only on a sensitive surface', M: 'yes', L: 'yes' }

function sizeOfDiff(lines) {
  return SIZES.find(([, max]) => lines <= max)[0]
}

// The globs `quality.sensitive_paths` carries are the shell kind a person writes by hand:
// `src/**/Payment/**`, `*.sql`, `config/security*`. Translated here rather than shelled out to
// so the answer does not depend on the shell's globstar setting.
function globToRe(glob) {
  let re = ''
  for (let i = 0; i < glob.length; i += 1) {
    const c = glob[i]
    if (c === '*') {
      if (glob[i + 1] === '*') {
        re += glob[i + 2] === '/' ? '(?:.*/)?' : '.*'
        i += glob[i + 2] === '/' ? 2 : 1
      } else re += '[^/]*'
    } else if (c === '?') re += '[^/]'
    else re += c.replace(/[.+^${}()|[\]\\]/g, '\\$&')
  }
  return new RegExp(`^${re}$`)
}

function tier(argv) {
  const flag = (name, fallback = null) => {
    const i = argv.indexOf(name)
    return i === -1 ? fallback : argv[i + 1]
  }
  const repo = git(['rev-parse', '--show-toplevel']).trim()
  if (!repo) { console.error('flow tier: not a git checkout'); process.exit(1) }
  const harness = flag('--harness')
  if (harness && !OVERLAY_HARNESSES.includes(harness)) {
    console.error(`flow tier: unknown harness \`${harness}\`. One of: ${OVERLAY_HARNESSES.join(', ')}.`)
    process.exit(1)
  }
  const branch = git(['rev-parse', '--abbrev-ref', 'HEAD'], repo).trim()
  const resolves = (ref) => Boolean(git(['rev-parse', '--verify', '--quiet', ref], repo).trim())
  const rev = flag('--rev')
  if (rev && !resolves(rev)) {
    console.error(`flow tier: --rev \`${rev}\` does not resolve in this checkout.`)
    process.exit(1)
  }
  const to = rev ? git(['rev-parse', rev], repo).trim() : null
  const cfg = flowConfig(repo, harness, to)
  const configs = configFiles(repo, harness, to)

  const base = flag('--base') || cfg.git?.default_base || 'origin/main'
  if (!resolves(base)) {
    console.error(`flow tier: base \`${base}\` does not resolve. Set git.default_base or pass --base.`)
    console.error(`Config read: ${configs}`)
    process.exit(1)
  }
  const from = git(['merge-base', base, to ?? 'HEAD'], repo).trim() || base
  const ends = to ? [to] : []

  const exclude = Array.isArray(cfg.git?.diff_exclude) ? cfg.git.diff_exclude
    : cfg.git?.diff_exclude ? [cfg.git.diff_exclude] : []
  const paths = exclude.length ? ['--', '.', ...exclude.map((p) => `:(exclude)${p}`)] : []

  // Changed lines, not the file count: the table this resolves is written in lines.
  let changedLines = 0
  for (const line of git(['diff', '--numstat', from, ...ends, ...paths], repo).split('\n')) {
    const m = /^(\d+)\t(\d+)\t/.exec(line)
    if (m) changedLines += Number(m[1]) + Number(m[2])
  }
  const files = git(['diff', '--name-only', from, ...ends, ...paths], repo).split('\n').filter(Boolean)

  const diffSize = sizeOfDiff(changedLines)
  const work = workFolder(repo, branch)
  let meta = {}
  if (work) { try { meta = JSON.parse(readFileSync(join(work, 'meta.json'), 'utf8')) } catch {} }
  const recorded = typeof meta.size === 'string' && BASE_EFFORT[meta.size] ? meta.size : null
  const order = (s) => SIZES.findIndex(([n]) => n === s)
  const effective = recorded ? (order(diffSize) < order(recorded) ? diffSize : recorded) : diffSize

  const globs = Array.isArray(cfg.quality?.sensitive_paths) ? cfg.quality.sensitive_paths
    : cfg.quality?.sensitive_paths ? [cfg.quality.sensitive_paths] : []
  const res = globs.map((g) => [g, globToRe(g)])
  const sensitiveHits = []
  for (const f of files) for (const [g, re] of res) if (re.test(f)) sensitiveHits.push(`${f} (${g})`)

  const depth = cfg.quality?.review_depth || 'proportional'
  const budget = cfg.agents?.budget_max === '0' ? 'no ceiling' : (Number(cfg.agents?.budget_max) || 12)
  const fanout = Number(cfg.agents?.fanout_max) || 4

  // Within 10% under a threshold that changes the tier: the one number in this command with an
  // incentive on it, so the measurement says when it landed just under one.
  const thresholds = [150, 600, 1500]
  const near = thresholds.find((t) => changedLines <= t && changedLines >= Math.ceil(t * 0.9))

  const bumped = LADDER[Math.min(LADDER.indexOf(BASE_EFFORT[effective]) + 1, LADDER.length - 1)]
  const out = []
  out.push(`Changed lines: ${changedLines} over ${files.length} file(s), \`${from.slice(0, 12)}\`..`
    + `${to ? `\`${to.slice(0, 12)}\`` : 'working tree'} (base \`${base}\`)`)
  out.push(`Config read: ${configs}`)
  out.push(`review_depth: ${depth}`)
  out.push(`Diff size: ${diffSize}   ·   meta.json.size: ${recorded ?? 'not recorded'}`
    + `   ·   Effective size: ${effective}`)
  if (recorded && order(diffSize) > order(recorded)) {
    out.push(`Note: the diff points higher than the recorded size — the work may be misclassified.`
      + ` One line in 06-review.md, not a heavier review.`)
  }
  if (depth === 'full') {
    out.push('Tier: full → built-in `code-review` at `xhigh` + the project panel, whatever the size.')
  } else if (depth === 'light') {
    out.push('Tier: light → built-in (or quality.review_skill) at `medium`, no panel, no §3, no §6 —'
      + ' unless a sensitive surface applies, which raises it to proportional for this work.')
  } else {
    out.push(`Tier: proportional → built-in at \`${BASE_EFFORT[effective]}\`, panel: ${PANEL[effective]}`)
    out.push(`With the sensitive-surface bump: built-in at \`${bumped}\`, panel always`)
  }
  out.push(`Budget: budget_max ${budget} · fanout_max ${fanout}`)
  out.push(near
    ? `Within 10% under ${near}: yes (${changedLines} lines) — say so in 06-review.md beside the`
      + ' effective size. It changes no tier; it is what makes flow-core §9 checkable afterwards.'
    : 'Within 10% under a threshold: no')
  out.push(sensitiveHits.length
    ? `quality.sensitive_paths matched:\n${sensitiveHits.map((h) => `  - ${h}`).join('\n')}`
    : `quality.sensitive_paths matched: none${globs.length ? '' : ' (the key is empty)'}`)
  out.push('')
  out.push('Left to you, because a command cannot see it: whether the generic categories apply')
  out.push('(auth, secrets, payments, personal data, a public contract, a schema change), and')
  out.push('whether a matched path is a control-flow change or observability only — a log level,')
  out.push('a metric, a message text gets the review its size already earned. Decide, then record')
  out.push('which of the two it was. Any deviation from the tier above goes in 06-review.md with')
  out.push('its reason.')
  console.log(out.join('\n'))
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
    // Named, not assumed: this key belongs in a harness overlay as often as in the base,
    // and "empty in FLOW.md" over a run that never opened the overlay is a wrong answer
    // delivered confidently.
    console.error(`flow review: \`agents.exec_cmd\` is empty in ${built.configs}.`)
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
    // Every source, not a count of them. A finding one pass caught and a finding three
    // passes caught say opposite things about that pass, and a headcount collapses both.
    out.push(`  raised by: ${f.roles.map((r) => r.split(':')[0]).join(', ')}`)
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
  const outFile = argv.includes('--out') ? argv[argv.indexOf('--out') + 1] : null
  if (outFile) { writeFileSync(outFile, `${text}\n`); console.log(`wrote ${outFile}`) } else console.log(text)

  if (argv.includes('--record')) {
    // The review above is already printed: a recording that fails must never cost the panel's
    // output. Harness answers are not schema-checked, so what the writer refuses — a severity
    // outside the four, a finding with no file — is normalised here rather than lost.
    const slugs = roles.map((r, i) => {
      const slug = r.split(':')[0].trim().toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '')
      return slug ? `panel:${slug}` : `panel:role-${i + 1}`
    })
    const role = (r) => slugs[roles.indexOf(r)]
    const agents = {}
    for (const r of results.filter((x) => !x.error)) agents[role(r.role)] = (agents[role(r.role)] ?? 0) + 1
    if (!Object.keys(agents).length) {
      console.error('flow review --record: no reviewer answered, so there is no round to record.')
      process.exitCode = 1
      return
    }
    const doc = {
      round: { agents, ...(costs.length ? { usd: Number(costs.reduce((a, b) => a + b, 0).toFixed(6)) } : {}) },
      findings: findings.map((f) => ({
        sources: [...new Set(f.roles.map(role))],
        severity: SEVERITIES.includes(f.severity) ? f.severity : 'unrated',
        file: typeof f.file === 'string' && f.file ? f.file : '?',
        outcome: 'open',
      })),
    }
    const bad = validateReview(doc)
    // `exitCode`, never `exit()`: the review was just printed, and on a pipe stdout is
    // asynchronous — exiting now can cut off the output this ordering exists to keep.
    if (bad.length) { console.error(`flow review --record: nothing recorded.\n${bad.join('\n')}`); process.exitCode = 1; return }
    if (!writeReview(built.work, doc)) {
      console.error(`flow review --record: no work on \`${built.branch}\`, or its meta.json is missing or not JSON — the review above stands, unrecorded.`)
      process.exitCode = 1
      return
    }
  }
}

// --- escape ----------------------------------------------------------------------------
// A bug whose cause is a commit a flow review read is the one number that says what trimming
// the review would cost. It is charged only on evidence: the commit inside exactly one
// reviewed range, or carrying the number of exactly one reviewed MR/PR. "An ancestor of what
// was reviewed" is not evidence — the whole history of the base is an ancestor of every
// reviewed sha — and a ticket number is not either, since one ticket spans several MRs/PRs.

function escapeOf(argv) {
  let file = null
  const rest = []
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--file') file = argv[++i] ?? null
    else if (argv[i].startsWith('--file=')) file = argv[i].slice('--file='.length)
    else if (argv[i].startsWith('--')) { console.error(`flow escape: unknown option \`${argv[i]}\``); process.exit(1) }
    else rest.push(argv[i])
  }
  const commitArg = rest[0]
  if (!commitArg) { console.error('flow escape: <commit> is required'); process.exit(1) }
  const repo = git(['rev-parse', '--show-toplevel']).trim()
  if (!repo) { console.error('flow escape: not a git checkout'); process.exit(1) }
  const commit = git(['rev-parse', '--verify', '--quiet', `${commitArg}^{commit}`], repo).trim()
  if (!commit) { console.error(`flow escape: \`${commitArg}\` is not a commit in this checkout`); process.exit(1) }
  const branch = git(['rev-parse', '--abbrev-ref', 'HEAD'], repo).trim()
  const here = workFolder(repo, branch)
  if (!here) { console.error(`flow escape: no work on \`${branch}\` to record the escape in`); process.exit(1) }

  const cfg = flowConfig(repo, null, null)
  // The MR/PR a squash commit came from, and nothing else: GitHub appends `(#N)` to the end of
  // the subject, GitLab writes `See merge request <path>!N` in the body. A `(#7)` quoted
  // mid-subject — a revert, a cherry-pick — names another MR/PR and charges nobody.
  const subject = git(['log', '-1', '--format=%s', commit], repo).trim()
  const body = git(['log', '-1', '--format=%b', commit], repo)
  // A GitLab reference carries its project path, and an MR of another project with the same
  // number is not this one: the unit's url has to name that path too.
  const refs = [
    ...(subject.match(/\(#(\d+)\)\s*$/) ? [{ n: subject.match(/\(#(\d+)\)\s*$/)[1], path: null }] : []),
    ...[...body.matchAll(/See merge request (\S*)!(\d+)/g)].map((m) => ({ n: m[2], path: m[1] || null })),
  ]
  const namedBy = (url) => {
    const n = String(url ?? '').match(/\/(?:pull|merge_requests)\/(\d+)/)?.[1]
    return n && refs.some((r) => r.n === n && (!r.path || String(url).includes(`/${r.path}/-/merge_requests/${n}`)))
  }
  const isAncestor = (a, b) => {
    try { execFileSync('git', ['merge-base', '--is-ancestor', a, b], { cwd: repo, stdio: 'ignore' }); return true } catch { return false }
  }
  const resolves = (ref) => Boolean(ref) && Boolean(git(['rev-parse', '--verify', '--quiet', `${ref}^{commit}`], repo).trim())

  // Where the reviewed branch left the base. Once merged, the base contains the reviewed sha
  // and their merge-base is that sha itself, so the fork is read off the merge that brought it
  // in: the side it was merged into, at that point. A fast-forward leaves no merge to read,
  // and then there is no range — the MR/PR number is the only evidence left.
  // Every merge that brought the reviewed sha across — into the base, or into another branch on
  // its way there — gives a fork: where the reviewed branch left the side it was merged into.
  // A commit counts as reviewed only when it is an ancestor of none of them, so the narrowest
  // range wins: a branch cut from another branch owns only its own commits, never the parent's.
  // A fast-forward leaves no merge, and then there is no range — only the MR/PR number counts.
  const forks = new Map()
  const forksOf = (base, reviewed) => {
    const key = `${base} ${reviewed}`
    if (forks.has(key)) return forks.get(key)
    let list = []
    if (!resolves(base)) list = []
    else if (!isAncestor(reviewed, base)) list = [git(['merge-base', base, reviewed], repo).trim()].filter(Boolean)
    else {
      const merges = git(['rev-list', '--ancestry-path', '--merges', `${reviewed}..${base}`], repo).trim().split('\n').filter(Boolean)
      list = merges.filter((m) => isAncestor(reviewed, `${m}^2`) && !isAncestor(reviewed, `${m}^1`))
        .map((m) => git(['merge-base', `${m}^1`, reviewed], repo).trim()).filter(Boolean)
    }
    forks.set(key, list)
    return list
  }

  const matches = []
  const hereReal = realpathSync(here)
  for (const { path, meta } of worksOf(repo, new Set())) {
    if (realpathSync(path) === hereReal) continue
    const units = Array.isArray(meta.mrs) && meta.mrs.length ? meta.mrs : [meta]
    for (const u of units) {
      const reviewed = u?.reviewed_sha
      let how = null
      if (resolves(reviewed) && isAncestor(commit, reviewed)) {
        const fs = forksOf(meta.base || cfg.git?.default_base || 'origin/main', reviewed)
        if (fs.length && fs.every((f) => !isAncestor(commit, f))) how = `inside ${fs[0].slice(0, 7)}..${reviewed.slice(0, 7)}`
      }
      if (!how && reviewed && namedBy(u?.url)) how = `the commit names its MR/PR, ${String(u.url).split('/').pop()}`
      if (how) matches.push({ path, meta, unit: u, how })
    }
  }

  const works = [...new Set(matches.map((m) => m.path))]
  if (works.length !== 1) {
    // A blame that changed takes the old escape with it: counted, it would charge a review for
    // a commit the investigation no longer names.
    // Only for another commit: the same one finding no match now has lost its evidence (a ref
    // not fetched, a branch gone), which is not a reason to forget what was already shown.
    let dropped = false, kept = false
    editMeta(here, (meta) => {
      if (!meta.escape) return
      if (meta.escape.commit === commit) kept = true
      else { dropped = true; delete meta.escape }
    })
    if (dropped) console.log('The escape recorded earlier for this bug was removed: it blamed another commit.')
    if (kept) console.log('The escape recorded earlier for this same commit is kept: its evidence did not resolve this time.')
    console.log(works.length
      ? `No escape recorded: ${commit.slice(0, 7)} matches ${works.length} reviewed works (${works.map((w) => w.split('/').pop()).join(', ')}), and a guess is not evidence.`
      : `No escape recorded: ${commit.slice(0, 7)} is not inside any reviewed range or reviewed MR/PR of this repo's works.`)
    return
  }
  const m = matches[0]
  const escape = {
    work: m.path.split('/').pop(), ticket: m.meta.ticket ?? null, commit,
    file: file ?? null, size: m.unit.size ?? m.meta.size ?? null,
  }
  if (!editMeta(here, (meta) => { meta.escape = escape })) {
    console.error(`flow escape: \`${join(here, 'meta.json')}\` is missing or not JSON — nothing recorded`); process.exit(1)
  }
  console.log(`Escape recorded: ${commit.slice(0, 7)} went through the review of ${escape.work} (${m.how}).`)
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

// Read-modify-write against meta.json, the flow's own state, so both writers go through a
// temporary file: a half-written meta.json loses the work, not just the figure.
function editMeta(work, fn) {
  if (!work) return false
  const p = join(work, 'meta.json')
  if (!existsSync(p)) return false
  let meta
  try { meta = JSON.parse(readFileSync(p, 'utf8')) } catch { return false }
  fn(meta)
  const tmp = `${p}.tmp`
  writeFileSync(tmp, `${JSON.stringify(meta, null, 2)}\n`)
  renameSync(tmp, p)
  return true
}

// --- record-review -----------------------------------------------------------------------
// The only writer of a review round's rows. The origins used to be written by hand from the
// prose, and six weeks of that produced ~65 spellings for ~12 passes and outcomes written
// into the severity field. So the lists are closed here, a value outside them is refused
// with the ones that are valid, and nothing is written until every value is.

const ORIGIN_RE = /^(built-in|sweep|query-duel|yagni|contract|idiom|(panel|reinforcement):[a-z0-9][a-z0-9-]*)$/
const SEVERITIES = ['blocker', 'major', 'minor', 'nit', 'unrated']
const OUTCOMES = ['fixed', 'open', 'rejected', 'discarded', 'deferred']
const TIERS = ['light', 'proportional', 'full']
const SIZE_NAMES = SIZES.map(([n]) => n)
const ORIGINS_HELP = 'built-in · sweep · query-duel · yagni · contract · idiom · panel:<role> · reinforcement:<area>'
  + ' (<role>/<area>: lower-case letters, digits and -)'

function validateReview(doc) {
  const bad = []
  if (!doc || typeof doc !== 'object') return ['the file is not a JSON object']
  const round = doc.round
  if (!round || typeof round !== 'object' || Array.isArray(round)) return ['`round` is required: an object with at least `agents`']
  if (round.mr != null && !(Number.isInteger(round.mr) && round.mr > 0)) bad.push(`round.mr \`${round.mr}\`: a positive integer`)
  if (round.tier != null && !TIERS.includes(round.tier)) bad.push(`round.tier \`${round.tier}\`: one of ${TIERS.join(' · ')}`)
  if (round.effective_size != null && !SIZE_NAMES.includes(round.effective_size)) {
    bad.push(`round.effective_size \`${round.effective_size}\`: one of ${SIZE_NAMES.join(' · ')}`)
  }
  if (round.usd != null && typeof round.usd !== 'number') bad.push(`round.usd \`${round.usd}\`: a number, or leave it out`)
  const agents = round.agents
  if (!agents || typeof agents !== 'object' || Array.isArray(agents) || !Object.keys(agents).length) {
    bad.push('round.agents: every pass this round launched, as {origin: agents}, findings or not')
  }
  else {
    for (const [o, n] of Object.entries(agents)) {
      if (!ORIGIN_RE.test(o)) bad.push(`round.agents origin \`${o}\`: one of ${ORIGINS_HELP}`)
      if (!(Number.isInteger(n) && n > 0)) bad.push(`round.agents[${o}] \`${n}\`: a positive integer`)
    }
  }
  if (!Array.isArray(doc.findings)) bad.push('`findings` must be an array (empty when the round found nothing)')
  else {
    doc.findings.forEach((f, i) => {
      const at = `findings[${i}]`
      if (!f || typeof f !== 'object') { bad.push(`${at}: not an object`); return }
      if (!Array.isArray(f.sources) || !f.sources.length) bad.push(`${at}.sources: a non-empty list of origins`)
      else f.sources.forEach((o) => {
        if (!ORIGIN_RE.test(o)) bad.push(`${at}.sources \`${o}\`: one of ${ORIGINS_HELP}`)
        else if (agents && typeof agents === 'object' && !(o in agents)) bad.push(`${at}.sources \`${o}\`: not in round.agents — a source is a pass that ran`)
      })
      if (!SEVERITIES.includes(f.severity)) bad.push(`${at}.severity \`${f.severity}\`: one of ${SEVERITIES.join(' · ')}`)
      if (!OUTCOMES.includes(f.outcome)) bad.push(`${at}.outcome \`${f.outcome}\`: one of ${OUTCOMES.join(' · ')}`)
      if (typeof f.file !== 'string' || !f.file) bad.push(`${at}.file: the path the finding is about`)
    })
  }
  return bad
}

// One round: its findings, each once with every source, and one `cost[]` review entry saying
// what the round launched. The round number continues this work's own count, across both.
function writeReview(work, doc) {
  return editMeta(work, (meta) => {
    const rows = Array.isArray(meta.review_findings) ? meta.review_findings : []
    const costs = Array.isArray(meta.cost) ? meta.cost : []
    const last = [...rows, ...costs.filter((e) => e?.phase === 'review')]
      .reduce((n, r) => Math.max(n, Number(r.round) || 0), 0)
    const r = doc.round ?? {}
    const round = last + 1
    const mr = r.mr != null ? { mr: r.mr } : {}
    meta.review_findings = [...rows, ...doc.findings.map((f) => ({
      round, ...mr, sources: f.sources, severity: f.severity, file: f.file, outcome: f.outcome,
    }))]
    const agents = r.agents ?? {}
    meta.cost = [...costs, {
      phase: 'review', at: new Date().toISOString(), round, ...mr,
      ...(r.tier ? { tier: r.tier } : {}), ...(r.effective_size ? { effective_size: r.effective_size } : {}),
      agents, reviewers: Object.values(agents).reduce((a, b) => a + b, 0),
      usd: typeof r.usd === 'number' ? r.usd : null,
      source: typeof r.usd === 'number' ? 'harness' : 'not reported',
    }]
  })
}

function recordReview(argv) {
  const at = argv.indexOf('--file')
  const file = at === -1 ? null : argv[at + 1]
  if (!file) { console.error('flow record-review: --file <rows.json> is required'); process.exit(1) }
  const repo = git(['rev-parse', '--show-toplevel']).trim()
  if (!repo) { console.error('flow record-review: not a git checkout'); process.exit(1) }
  const branch = git(['rev-parse', '--abbrev-ref', 'HEAD'], repo).trim()
  const work = workFolder(repo, branch)
  if (!work) { console.error(`flow record-review: no work on \`${branch}\` — nothing to record against`); process.exit(1) }
  let doc
  try { doc = JSON.parse(readFileSync(file, 'utf8')) } catch (e) {
    console.error(`flow record-review: \`${file}\` is not readable JSON (${e.message})`); process.exit(1)
  }
  const bad = validateReview(doc)
  if (bad.length) {
    console.error(`flow record-review: nothing recorded — ${bad.length} value(s) outside the lists:`)
    bad.forEach((b) => console.error(`  - ${b}`))
    process.exit(1)
  }
  if (!writeReview(work, doc)) { console.error(`flow record-review: \`${join(work, 'meta.json')}\` is missing or not JSON — nothing recorded`); process.exit(1) }
  console.log(`recorded ${doc.findings.length} finding(s) and the round's agents in ${join(work, 'meta.json')}`)
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
    console.log('`flow record-review` writes what the harness reported for a review round, and a')
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
  console.log('Which reviewer found what, across every work: `flow yield`.')
}

// --- yield -----------------------------------------------------------------------------
// Whether each review pass still earns what it costs, across every work a repo has kept —
// live and archived, in this checkout and in the main one, over as many repos as are named.
// `meta.json.review_findings[]` has carried an origin per source since the rows were added;
// what it never had is a reader that counts across works, so the twenty-review rule had
// nothing to count. The origins were written by hand and drifted (`builtin`, `code-review`,
// `cli:tests`, `§5.5`…): they are mapped here, on read, and every spelling that was not
// already canonical is printed with what it was read as, so a wrong mapping is visible.

const RETIRE_AFTER = 20
const ACCEPTED = new Set(['fixed', 'open', 'deferred'])
const SECTION_ORIGINS = {
  '§3.5': 'sweep', sweep: 'sweep',
  '§3.6': 'query-duel', 'query-duel': 'query-duel',
  '§4': 'yagni', yagni: 'yagni',
  '§5': 'contract', contract: 'contract', 'contract-verifier': 'contract',
  '§5.5': 'idiom', idiom: 'idiom', 'idiom-audit': 'idiom',
}
const BUILT_IN = new Set(['built-in', 'builtin', 'builtin-code-review', 'code-review'])
const LEGACY_SEVERITY = {
  blocker: 'blocker', high: 'blocker',
  major: 'major', medium: 'major',
  minor: 'minor', low: 'minor', suggestion: 'minor',
  nit: 'nit',
}

// A panel role is whatever the repo named it; only the spelling noise is folded: a prefix
// saying which path ran it, case and spaces, and the suffixes an agent's file name adds.
function panelRole(raw) {
  let r = raw.toLowerCase().trim().replace(/\s+/g, '-')
  r = r.replace(/-(reviewer|hunter|verifier|audit)$/, '').replace(/-round\d+$/, '')
  if (r === 'testing') r = 'tests'
  if (r === 'redteam') r = 'red-team'
  if (/^silent(-failures?)?$/.test(r)) r = 'silent-failure'
  if (r === 'code-simplifier') r = 'simplify'
  return `panel:${r}`
}

function canonicalOrigin(raw) {
  const o = String(raw ?? '').trim()
  if (!o) return 'unknown'
  if (o.startsWith('reinforcement:')) return o.toLowerCase()
  const bare = o.replace(/^(§panel:|cli-panel:|cli:|panel:)/, '')
  if (BUILT_IN.has(bare)) return 'built-in'
  if (SECTION_ORIGINS[bare]) return SECTION_ORIGINS[bare]
  return panelRole(bare)
}

// Every work folder a repo holds: its `.claude/work` here and in the main checkout, live and
// `_archive/`, each meta.json read once however many of those paths lead to it.
// `seen` is shared across every repo of one call: a worktree and its main checkout, or the
// same path named twice, lead to the same folders and must count them once.
function worksOf(repo, seen) {
  const roots = new Set([join(repo, '.claude', 'work'), join(mainCheckout(repo), '.claude', 'work')])
  const works = []
  for (const root of roots) {
    for (const dir of [root, join(root, '_archive')]) {
      let entries = []
      try { entries = readdirSync(dir, { withFileTypes: true }) } catch { continue }
      for (const e of entries) {
        if (!e.isDirectory() || (dir === root && e.name === '_archive')) continue
        const p = join(dir, e.name, 'meta.json')
        let real
        try { real = realpathSync(p) } catch { continue }
        if (seen.has(real)) continue
        seen.add(real)
        try { works.push({ path: join(dir, e.name), meta: JSON.parse(readFileSync(p, 'utf8')) }) } catch {}
      }
    }
  }
  return works
}

// The rule is judged per size because the review itself is: the panel rarely runs below M,
// so XS and S are pooled or neither would ever reach twenty rounds.
function sizeBucket(size) {
  const s = String(size ?? '').toUpperCase()
  return s === 'XS' || s === 'S' ? 'XS+S' : s === 'M' || s === 'L' ? s : 'unknown size'
}

function yieldOf(argv) {
  const repos = (argv.length ? argv : ['.']).map((a) => {
    const top = git(['rev-parse', '--show-toplevel'], resolve(a)).trim()
    if (!top) { console.error(`flow yield: \`${a}\` is not a git checkout`); process.exit(1) }
    return top
  })

  // bucket → origin → counters; rounds are (work, round) keys so a round counts once.
  const table = new Map()
  const spellings = new Map()
  let rounds = 0, rows = 0, works = 0
  const seen = new Set()
  const escapes = new Map()
  const cell = (bucket, origin) => {
    if (!table.has(bucket)) table.set(bucket, new Map())
    const t = table.get(bucket)
    if (!t.has(origin)) t.set(origin, { rounds: new Set(), findings: 0, unique: 0, accepted: 0, agents: null })
    return t.get(origin)
  }
  const read = (raw) => {
    const c = canonicalOrigin(raw)
    if (raw !== c) {
      if (!spellings.has(c)) spellings.set(c, new Set())
      spellings.get(c).add(String(raw))
    }
    return c
  }

  for (const repo of repos) {
    for (const { path, meta } of worksOf(repo, seen)) {
      if (meta.escape?.work) {
        const b = sizeBucket(meta.escape.size)
        if (!escapes.has(b)) escapes.set(b, [])
        escapes.get(b).push(meta.escape.work)
      }
      const found = Array.isArray(meta.review_findings) ? meta.review_findings : []
      const costs = (Array.isArray(meta.cost) ? meta.cost : []).filter((e) => e?.phase === 'review' && e.round != null)
      if (!found.length && !costs.length) continue
      works += 1
      const sizeFor = (mr, round) => {
        const entry = costs.find((e) => e.round === round && e.effective_size && (e.mr ?? null) === (mr ?? null))
        if (entry) return entry.effective_size
        const part = Array.isArray(meta.mrs) && mr != null ? meta.mrs.find((m) => m?.n === mr) : null
        return part?.size ?? meta.size
      }
      const roundsHere = new Set()

      // A round that recorded what it launched says which passes ran, findings or not.
      for (const e of costs) {
        roundsHere.add(e.round)
        for (const [raw, n] of Object.entries(e.agents ?? {})) {
          if (!(Number(n) > 0)) continue
          const c = cell(sizeBucket(e.effective_size ?? sizeFor(e.mr, e.round)), read(raw))
          c.rounds.add(`${path}#${e.round}`)
          c.agents = (c.agents ?? 0) + Number(n)
        }
      }

      // Legacy rows are one per source; the same finding is the same (round, severity, file).
      const legacy = found.filter((r) => !Array.isArray(r.sources))
      const keyOf = (r) => `${r.round}::${LEGACY_SEVERITY[r.severity] ?? 'unrated'}::${r.file ?? ''}`
      const sourcesOf = new Map()
      for (const r of legacy) {
        if (r.count != null) continue
        const k = keyOf(r)
        if (!sourcesOf.has(k)) sourcesOf.set(k, new Set())
        String(r.origin ?? '').split('+').forEach((o) => sourcesOf.get(k).add(canonicalOrigin(o)))
      }
      for (const r of legacy) {
        rows += 1
        roundsHere.add(r.round)
        const bucket = sizeBucket(sizeFor(r.mr, r.round))
        const accepted = !r.discarded_by_skeptic && !['declined', 'discarded'].includes(r.severity)
        for (const origin of new Set(String(r.origin ?? '').split('+').map(read))) {
          const c = cell(bucket, origin)
          // A row that only carries a count says how many, never which: they are findings,
          // and nothing can say whether another source had them too — so the round they sit in
          // is not one this origin can be judged on either.
          if (r.count != null) { c.findings += Number(r.count) || 0; continue }
          c.rounds.add(`${path}#${r.round}`)
          c.findings += 1
          if (sourcesOf.get(keyOf(r)).size === 1) {
            c.unique += 1
            if (accepted) c.accepted += 1
          }
        }
      }

      for (const r of found.filter((x) => Array.isArray(x.sources))) {
        rows += 1
        roundsHere.add(r.round)
        const bucket = sizeBucket(sizeFor(r.mr, r.round))
        const sources = new Set(r.sources.map(read))
        for (const o of sources) {
          const c = cell(bucket, o)
          c.rounds.add(`${path}#${r.round}`)
          c.findings += 1
          if (sources.size === 1) {
            c.unique += 1
            if (ACCEPTED.has(r.outcome)) c.accepted += 1
          }
        }
      }
      rounds += roundsHere.size
    }
  }

  console.log(`# Review yield — ${repos.join(' · ')}`)
  console.log()
  if (!table.size && !escapes.size) {
    console.log('No review rounds recorded in the works these checkouts hold')
    console.log(`(${repos.map((r) => join(r, '.claude', 'work')).join(', ')}, archive included).`)
    return
  }
  console.log(`${works} work(s), ${rounds} review round(s), ${rows} finding row(s).`)
  for (const bucket of ['XS+S', 'M', 'L', 'unknown size']) {
    const t = table.get(bucket) ?? new Map()
    const esc = escapes.get(bucket) ?? []
    if (!t.size && !esc.length) continue
    console.log()
    console.log(`## ${bucket}`)
    if (t.size) {
      console.log()
      console.log('| origin | rounds | findings | unique | unique accepted | agents | verdict |')
      console.log('|---|---|---|---|---|---|---|')
    }
    const sorted = [...t.entries()].sort((a, b) => b[1].accepted - a[1].accepted || b[1].findings - a[1].findings)
    for (const [origin, c] of sorted) {
      const n = c.rounds.size
      const verdict = n < RETIRE_AFTER ? `too few rounds (${n}/${RETIRE_AFTER})`
        : c.accepted === 0 ? `retire at ${bucket}` : 'keep'
      console.log(`| ${origin} | ${n} | ${c.findings} | ${c.unique} | ${c.accepted} | ${c.agents ?? '—'} | ${verdict} |`)
    }
    console.log()
    console.log(`escapes: ${esc.length}${esc.length ? ` (${[...new Set(esc)].sort().join(', ')})` : ''}`)
  }
  console.log()
  console.log('"unique accepted" decides: a finding only this origin raised and that was acted on.')
  console.log(`An origin that ran ${RETIRE_AFTER}+ rounds at a size with none is retired at that size.`)
  console.log('Re-run it when the model changes — a pass that stopped paying may pay again, and back.')
  console.log('Rows written before findings carried an outcome count "accepted" as "not refuted by a')
  console.log('skeptic", and a round they record counts only for the origins with a row in it, so')
  console.log('"rounds" is a lower bound there and "agents" is unknown (—). Those rows carry no MR/PR')
  console.log('number either, so a split work\'s legacy rows count at the size of the whole work.')
  if (spellings.size) {
    console.log()
    console.log('## Spellings read as')
    console.log()
    for (const [c, raws] of [...spellings.entries()].sort()) console.log(`- ${c} ← ${[...raws].sort().join(', ')}`)
  }
}

function usage() {
  console.log(`flow-workflows v${version()} — guided feat/bug workflows for coding agents

  npx flow-workflows install <harness> [project]
  npx flow-workflows check
  npx flow-workflows bundle [--base <ref>] [--rev <ref>] [--checks] [--harness <name>]
                            [--max-file-bytes N] [--max-diff-lines N]
  npx flow-workflows tier   [--base <ref>] [--rev <ref>] [--harness <name>]
  npx flow-workflows review [--out <file>] [--record] [same options as bundle]
  npx flow-workflows cost
  npx flow-workflows record-review --file <rows.json>
  npx flow-workflows yield  [<repo-path>…]
  npx flow-workflows escape <commit> [--file <path>]

Harnesses: ${Object.keys(HARNESSES).join(' · ')}
  "project" installs into the current repo instead of your user folder.

Claude Code, Codex CLI and zcode have their own marketplaces:
  npx flow-workflows install claude    shows how
  npx flow-workflows install zcode     shows how

"bundle" prints one context pack for the current branch — worklist, diff, the changed
  files in full, and the work's handoff — so a phase reads it in one call instead of
  rediscovering it in ten. --checks also runs quality.static_analysis and copies its
  output out verbatim. Paths in git.diff_exclude are left out of the diff.
  Two limits, two questions: --max-file-bytes decides what is too big to print in full,
  --max-diff-lines what is too big to read as a diff. A large file with a small change
  keeps its diff; the worklist always shows the whole change, and anything held back is
  named there rather than at the end. Each FLOW file is read from the main checkout when
  this runs inside a worktree that does not carry it — unless the main checkout tracks it,
  since a committed file missing here is this branch's own state.
  --rev freezes what is read: the diff and the files come from that one revision instead
  of the live checkout, so every reader of the pack reads the same bytes however long
  they take. Pass a commit, or the object "git stash create" prints for a dirty tree.
  Untracked files are in no revision and stay out; --checks still runs against the
  checkout, and the pack says so.
  --harness names the overlay to merge on top of it (${OVERLAY_HARNESSES.join(' · ')}).
  Without it no overlay is read at all, which the pack's header says out loud: a key set
  only there — agents.exec_cmd, a harness's models — would otherwise read as unset.
  FLOW_CONTEXT=<name> in the environment adds FLOW.<name>.md between FLOW.md and the
  overlay — a layer the repo commits for where flow runs (ci, server…). The name is an ASCII
  letter or digit, then ASCII letters, digits, - or _, and never a harness name; anything
  else, spaces included, is skipped and named in the pack's header. Under --rev, a FLOW file
  the revision holds is read from it.

"tier" resolves the review depth from the same config: changed lines against the base,
  diff size, meta.json.size, effective size, the built-in effort with and without the
  sensitive-surface bump, the resolved budget_max/fanout_max, whether the measurement
  landed within 10% under a threshold that changes the tier, and which
  quality.sensitive_paths globs the diff matched. Arithmetic, printed once, so the tier in
  06-review.md is a computed line rather than a narrated one. What it deliberately does not
  decide: whether a generic category applies, and whether a matched path is a control-flow
  change or observability only.

"review" runs one reviewer per role through agents.exec_cmd — any non-interactive
  harness invocation — over that same pack, one turn each instead of an agentic loop
  each, and deduplicates what comes back. Empty exec_cmd = the agentic panel reviews,
  as it always has.

"cost" prints what each phase of this branch's work actually reported spending, from
  what record-review (a review's Close) or review --record wrote into meta.json. A harness that reports no figure is recorded as
  "not reported": a headcount of subagents is not a cost, and neither is a guess.

"record-review" writes one review round into this branch's work: each finding once, with
  every origin that raised it and its outcome, and what the round launched. Origins,
  severities and outcomes come from closed lists; one value outside them and nothing is
  written, and the error names the values that are valid.

"escape" tells whether the commit a bug investigation blamed went through a flow review:
  it must sit inside exactly one work's reviewed range (merge history), or carry the number
  of exactly one reviewed MR/PR in its subject (squash). Then it is recorded in this branch's
  work and "yield" counts it; anything less is said and recorded nowhere.

"yield" reads every work of the repos named (default: this one) — live and archived,
  here and in the main checkout — and prints, per reviewer or pass and per size, the
  rounds it ran, the findings it raised, how many only it raised, how many of those were
  acted on, and the agents it took. One that ran 20+ rounds at a size with no unique
  accepted finding is marked "retire" there; XS and S are pooled, since the panel rarely
  runs below M. Old spellings of an origin are mapped and listed with what they became.

Updating: re-run the install command — it sweeps the previous version first.
Docs: https://github.com/mashware/flow-workflows`)
}

const [cmd, tool, scope] = process.argv.slice(2)

if (cmd === 'bundle') bundle(process.argv.slice(3))
else if (cmd === 'tier') tier(process.argv.slice(3))
else if (cmd === 'cost') cost(process.argv.slice(3))
else if (cmd === 'yield') yieldOf(process.argv.slice(3))
else if (cmd === 'record-review') recordReview(process.argv.slice(3))
else if (cmd === 'escape') escapeOf(process.argv.slice(3))
else if (cmd === 'review') review(process.argv.slice(3)).catch((e) => { console.error(`flow review: ${e.message}`); process.exit(1) })
else if (cmd === 'check') check()
else if (cmd === 'install' && tool === 'claude') claude()
else if (cmd === 'install' && tool === 'zcode') zcode()
else if (cmd === 'install' && HARNESSES[tool]) install(tool, scope === 'project' ? 'project' : 'global')
else if (cmd === 'install') {
  console.error(`Unknown harness: ${tool ?? '(none given)'}`)
  console.error(`Expected one of: ${Object.keys(HARNESSES).join(', ')}, claude, zcode`)
  process.exit(1)
} else if (cmd === '--version' || cmd === '-v') console.log(version())
else if (!cmd || cmd === '--help' || cmd === '-h' || cmd === 'help') usage()
else {
  console.error(`Unknown command: ${cmd}`)
  usage()
  process.exit(1)
}
