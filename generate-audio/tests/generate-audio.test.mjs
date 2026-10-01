import assert from 'node:assert/strict'
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { tmpdir } from 'node:os'
import { fileURLToPath, pathToFileURL, URL } from 'node:url'
import { spawnSync } from 'node:child_process'
import process from 'node:process'
import { test } from 'node:test'
import { installStopHook } from '../scripts/install-stop-hook.mjs'

const skill = fileURLToPath(new URL('../', import.meta.url))
const helper = join(skill, 'scripts', 'New-Audio.ps1')
const mp3 = Buffer.from([73, 68, 51, 4, 0, 0, 0, 0, 0, 0])
function runPowerShell(args, key = '') {
  const result = spawnSync('pwsh', ['-NoProfile', '-File', ...args], {
    encoding: 'utf8', env: { ...process.env, OPENROUTER_API_KEY: key },
  })
  assert.ifError(result.error)
  return result
}
function repository(t) {
  const root = mkdtempSync(join(tmpdir(), 'generate-audio-'))
  t.after(() => rmSync(root, { recursive: true, force: true }))
  const git = spawnSync('git', ['init', root], { encoding: 'utf8' })
  assert.equal(git.status, 0, git.stderr)
  return root
}
function audio(root, name = 'assets/done.mp3') {
  const path = join(root, name)
  mkdirSync(join(path, '..'), { recursive: true })
  writeFileSync(path, mp3)
  return path
}

test('guide is the default and bundled reference resolves independently of cwd', t => {
  const root = repository(t)
  const output = join(root, 'new folder', 'speech.mp3')
  const result = runPowerShell([helper, '-VoicesFile', join(root, 'missing.json'), '-Prompt', 'private words', '-OutputFile', output, '-DryRun'])
  assert.equal(result.status, 0, result.stderr)
  const preview = JSON.parse(result.stdout)
  assert.equal(preview.VoiceProfile, 'guide')
  assert.equal(preview.VoiceMode, 'reference-audio')
  assert.equal(preview.OutputFile, output)
  assert.ok(preview.ReferenceBytes > 0)
  assert.ok(!result.stdout.includes('private words'))
  assert.equal(existsSync(join(root, 'new folder')), false)
})

test('explicit profile overrides guide and overwrite conflicts fail before a request', t => {
  const root = repository(t)
  const registry = join(root, 'voices.json')
  const fields = { description: 'Test voice', reference_audio: '', reference_text: '', consent: false }
  writeFileSync(registry, JSON.stringify({ version: 1, voices: [{ ...fields, name: 'narrator', speaker_id: 'test-id' }] }))
  const preview = runPowerShell([helper, '-VoicesFile', registry, '-Voice', 'narrator', '-Prompt', 'private test words', '-DryRun'])
  assert.equal(preview.status, 0, preview.stderr)
  assert.equal(JSON.parse(preview.stdout).VoiceProfile, 'narrator')
  const path = audio(root)
  const refused = runPowerShell([helper, '-Prompt', 'private test words', '-OutputFile', path, '-Force'])
  assert.notEqual(refused.status, 0)
  assert.match(refused.stderr, /already exists/)
  assert.deepEqual(readFileSync(path), mp3)
})

test('mocked generation saves an exact destination and private-data-safe sidecar', t => {
  const root = repository(t)
  const wrapper = join(root, 'mock.ps1')
  writeFileSync(wrapper, `param($Target, $Registry, $Destination)
function Invoke-WebRequest {
  param($Uri, $Method, $Headers, $ContentType, $Body, $OutFile, [switch] $PassThru, [switch] $SkipHttpErrorCheck, $TimeoutSec)
  $r = $Body | ConvertFrom-Json
  if ($r.input -ne 'private words' -or $r.model -ne 'bytedance-seed/seed-audio-1-0' -or $r.input_references[0].input_audio.format -ne 'mp3' -or $Headers.Authorization -ne 'Bearer test-key') { throw 'Unexpected request' }
  [IO.File]::WriteAllBytes($OutFile, [byte[]](73,68,51,4,0,0,0,0,0,0))
  return [pscustomobject]@{StatusCode=200;Headers=@{'Content-Type'='audio/mpeg';'X-Generation-Id'='test-generation'}}
}
& $Target -VoicesFile $Registry -Prompt 'private words' -OutputFile $Destination -Force -NoOpen
`)
  const destination = join(root, 'chosen folder', 'custom.mp3')
  const result = runPowerShell([wrapper, '-Target', helper, '-Registry', join(root, 'missing.json'), '-Destination', destination], 'test-key')
  assert.equal(result.status, 0, result.stderr)
  assert.deepEqual(readFileSync(destination), mp3)
  const metadataText = readFileSync(`${destination}.json`, 'utf8')
  const metadata = JSON.parse(metadataText.replace(/^\uFEFF/, ''))
  assert.equal(metadata.voice_profile, 'guide')
  assert.equal(metadata.voice_mode, 'reference-audio')
  assert.equal(metadata.generation_id, 'test-generation')
  for (const secret of ['private words', 'test-key']) {
    assert.ok(!metadataText.includes(secret))
    assert.ok(!result.stdout.includes(secret))
  }
})

test('installer preflight is no-write, idempotent, and preserves Git and other hooks', t => {
  const root = repository(t)
  const old = join(root, '.git', 'hooks', 'post-commit')
  writeFileSync(old, 'existing hook')
  const plan = installStopHook({ repo: root, dryRun: true })
  assert.equal(plan.patches.length, 3)
  assert.equal(existsSync(join(root, '.pi')), false)
  audio(root)
  installStopHook({ repo: root })
  installStopHook({ repo: root })
  assert.equal(readFileSync(old, 'utf8'), 'existing hook')
  const config = JSON.parse(readFileSync(join(root, '.pi', 'done-sound.json'), 'utf8'))
  assert.equal(config.audioPath, 'assets/done.mp3')
  assert.equal(config.managedBy, 'generate-audio')
})

test('installer refuses missing audio and conflicting files without changing them', t => {
  const root = repository(t)
  assert.throws(() => installStopHook({ repo: root }), /Generate and validate/)
  assert.equal(existsSync(join(root, '.pi')), false)
  const existing = join(root, 'scripts', 'Play-DoneSound.ps1')
  mkdirSync(join(root, 'scripts'))
  writeFileSync(existing, 'custom playback')
  assert.throws(() => installStopHook({ repo: root, dryRun: true }), /differs/)
  assert.equal(readFileSync(existing, 'utf8'), 'custom playback')
  audio(root)
  installStopHook({ repo: root, replaceHook: true })
  assert.notEqual(readFileSync(existing, 'utf8'), 'custom playback')
})

test('custom audio paths are honored, including an explicitly external destination', t => {
  const root = repository(t)
  const outside = mkdtempSync(join(tmpdir(), 'external-audio-'))
  t.after(() => rmSync(outside, { recursive: true, force: true }))
  const selected = audio(outside, 'custom.mp3')
  const plan = installStopHook({ repo: root, audio: selected })
  assert.equal(plan.externalAudio, true)
  const config = JSON.parse(readFileSync(join(root, '.pi', 'done-sound.json'), 'utf8'))
  assert.equal(config.audioPath, selected)
})

test('installed lifecycle callback is scoped, quiet for children, and cannot overlap', async t => {
  const root = repository(t)
  audio(root)
  installStopHook({ repo: root })
  const module = await import(pathToFileURL(join(root, '.pi', 'extensions', 'done-sound.ts')).href)
  let handler
  let finish
  let calls = 0
  const warnings = []
  const pending = new Promise(resolve => { finish = resolve })
  module.default({
    on: (name, callback) => { assert.equal(name, 'agent_settled'); handler = callback },
    exec: async (command, args, options) => {
      calls++
      assert.equal(command, 'pwsh')
      assert.equal(args.at(-1), 'assets/done.mp3')
      assert.equal(options.timeout, 15000)
      return pending
    },
  })
  const ctx = { cwd: root, hasUI: false, ui: { notify: (...args) => warnings.push(args) } }
  await handler({}, ctx)
  assert.equal(calls, 0)
  ctx.hasUI = true
  ctx.cwd = tmpdir()
  await handler({}, ctx)
  assert.equal(calls, 0)
  ctx.cwd = root
  const first = handler({}, ctx)
  await handler({}, ctx)
  assert.equal(calls, 1)
  finish({ code: 0, killed: false })
  await first
  const configPath = join(root, '.pi', 'done-sound.json')
  const config = JSON.parse(readFileSync(configPath, 'utf8'))
  writeFileSync(configPath, JSON.stringify({ ...config, enabled: false }))
  await handler({}, ctx)
  assert.equal(calls, 1)
  assert.deepEqual(warnings, [])
})
