import { existsSync, mkdirSync, readFileSync, realpathSync, renameSync, statSync, unlinkSync, writeFileSync } from 'node:fs'
import { dirname, isAbsolute, join, relative, resolve, sep, extname } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { spawnSync } from 'node:child_process'
import { randomUUID } from 'node:crypto'
import process from 'node:process'

const templates = fileURLToPath(new URL('../templates/', import.meta.url))
const outside = path => path === '..' || path.startsWith(`..${sep}`) || isAbsolute(path)

function checkDestination(root, target) {
  let ancestor = target
  while (!existsSync(ancestor)) ancestor = dirname(ancestor)
  if (outside(relative(root, realpathSync(ancestor)))) throw new Error('Hook destination escapes the repository through a link.')
  if (ancestor !== target && !statSync(ancestor).isDirectory()) throw new Error('Hook destination parent is a file.')
  if (existsSync(target) && !statSync(target).isFile()) throw new Error('Hook destination must be a regular file.')
}

export function planStopHook({ repo = process.cwd(), audio = 'assets/done.mp3', replaceHook = false } = {}) {
  const git = spawnSync('git', ['-C', resolve(repo), 'rev-parse', '--show-toplevel'], { encoding: 'utf8' })
  if (git.error || git.status !== 0) throw new Error('Stop-hook mode requires an existing Git repository.')
  const root = realpathSync(git.stdout.trim())
  const audioPath = resolve(root, audio)
  if (extname(audioPath).toLowerCase() !== '.mp3') throw new Error('Stop-hook audio must be an MP3 file.')
  const configPath = join(root, '.pi', 'done-sound.json')
  checkDestination(root, configPath)
  let config = {}
  if (existsSync(configPath)) {
    config = JSON.parse(readFileSync(configPath, 'utf8'))
    if ((config.version !== 1 || config.managedBy !== 'generate-audio') && !replaceHook) {
      throw new Error('Existing completion configuration is not owned by generate-audio. Explicit --replace-hook is required.')
    }
  }
  const localAudioPath = relative(root, audioPath)
  config = { ...config, version: 1, managedBy: 'generate-audio', audioPath: outside(localAudioPath) ? audioPath : localAudioPath.split(sep).join('/'), enabled: config.enabled !== false }
  const specifications = [
    ['.pi/extensions/done-sound.ts', readFileSync(join(templates, 'done-sound.ts'))],
    ['scripts/Play-DoneSound.ps1', readFileSync(join(templates, 'Play-DoneSound.ps1'))],
    ['.pi/done-sound.json', Buffer.from(JSON.stringify(config, null, 2) + '\n')],
  ]
  const patches = specifications.map(([name, content]) => {
    const target = join(root, name)
    checkDestination(root, target)
    const original = existsSync(target) ? readFileSync(target) : null
    if (name !== '.pi/done-sound.json' && original && !original.equals(content) && !replaceHook) {
      throw new Error(`Existing hook file differs: ${name}. Explicit --replace-hook is required.`)
    }
    return { target, content, original }
  })
  return { root, audioPath, externalAudio: outside(localAudioPath), patches }
}

export function installStopHook(options = {}) {
  const plan = planStopHook(options)
  if (options.dryRun) return plan
  if (!existsSync(plan.audioPath) || !statSync(plan.audioPath).isFile() || statSync(plan.audioPath).size === 0) {
    throw new Error('Generate and validate the completion MP3 before installing the hook.')
  }
  const staged = []
  try {
    for (const patch of plan.patches) {
      if (patch.original?.equals(patch.content)) continue
      mkdirSync(dirname(patch.target), { recursive: true })
      const temporary = `${patch.target}.${randomUUID()}.tmp`
      writeFileSync(temporary, patch.content, { flag: 'wx' })
      staged.push({ ...patch, temporary })
    }
    for (const patch of plan.patches) {
      const current = existsSync(patch.target) ? readFileSync(patch.target) : null
      if (Boolean(current) !== Boolean(patch.original) || (current && !current.equals(patch.original))) {
        throw new Error('Hook files changed during installation; refusing to overwrite them.')
      }
    }
    for (const patch of staged) renameSync(patch.temporary, patch.target)
    return plan
  } finally {
    for (const patch of staged) if (existsSync(patch.temporary)) unlinkSync(patch.temporary)
  }
}

function argumentsToOptions(args) {
  const options = {}
  for (let index = 0; index < args.length; index++) {
    const flag = args[index]
    if (flag === '--dry-run') options.dryRun = true
    else if (flag === '--replace-hook') options.replaceHook = true
    else if (flag === '--repo' || flag === '--audio') {
      const value = args[++index]
      if (!value || value.startsWith('--')) throw new Error(`Missing value for ${flag}`)
      options[flag === '--repo' ? 'repo' : 'audio'] = value
    } else throw new Error(`Unknown option: ${flag}`)
  }
  return options
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const options = argumentsToOptions(process.argv.slice(2))
    const plan = installStopHook(options)
    console.log(JSON.stringify({ repository: plan.root, audioPath: plan.audioPath, externalAudio: plan.externalAudio, dryRun: Boolean(options.dryRun), files: plan.patches.map(patch => patch.target) }))
  } catch (error) {
    console.error(error.message)
    process.exitCode = 1
  }
}
