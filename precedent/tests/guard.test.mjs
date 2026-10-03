import assert from 'node:assert/strict';
import test from 'node:test';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createGuard, guidance, validateResponse, runPython } from '../scripts/pi-support.mjs';

const question = 'Would you prefer the existing cleanup script or manual cleanup?';

test('only one recovery per run, without fabricating a user response', () => {
  const guard = createGuard();
  const result = guard.settle(question, 'completed');
  assert.equal(result.continue, true);
  assert.equal(result.entries[0].type, 'custom_message');
  assert.equal(result.entries[0].customType, 'precedent-consultation');
  assert.match(result.entries[0].content, /shadow/i);
  assert.doesNotMatch(result.entries[0].content, /User selected/i);
  assert.equal(guard.settle(question, 'completed'), undefined);
  assert.equal(guard.settle('Should I clean the other repo?', 'completed'), undefined);
});

test('off, abort, errors, sensitive prompts, and plain progress never continue', () => {
  for (const [text, outcome, enabled] of [[question, 'aborted', true], [question, 'error', true],
    [question, 'completed', false], ['Please approve production deployment?', 'completed', true],
    ['Enter your password to continue?', 'completed', true], ['The tests passed.', 'completed', true],
    ['Example: ```Should I do this?```', 'completed', true]]) {
    assert.equal(createGuard().settle(text, outcome, enabled), undefined);
  }
});

test('reset allows next genuine user run and consultation suppresses duplicate recovery', () => {
  const guard = createGuard();
  guard.consulted();
  assert.equal(guard.settle(question, 'completed'), undefined);
  guard.reset();
  assert.equal(guard.settle(question, 'completed').continue, true);
});

test('guidance requires evidence and preserves authority', () => {
  assert.match(guidance, /resolve_decision/);
  assert.match(guidance, /shadow/);
  assert.match(guidance, /not.*permission/i);
});

test('malformed, oversized or execution-authorizing output fails closed', () => {
  const good = { version: '1.0.0', mode: 'shadow', state: 'investigate', authority: 'not_granted_by_precedent',
    execute: false, recommendation: null, decisions: [], candidates: [], warnings: [], conflicts: [] };
  assert.deepEqual(validateResponse(JSON.stringify(good)), good);
  for (const bad of ['', 'not json', JSON.stringify({ ...good, execute: true }),
    JSON.stringify({ ...good, state: 'approved' }), JSON.stringify({ ...good, mode: 'autonomous' }),
    JSON.stringify({ ...good, candidates: Array(6).fill({}) }), ' '.repeat(65537)]) {
    assert.throws(() => validateResponse(bad));
  }
});

test('actual Python bridge works without UI or network in an isolated store', async () => {
  const state = await mkdtemp(join(tmpdir(), 'precedent-test-'));
  try {
    const script = fileURLToPath(new URL('../scripts/precedent.py', import.meta.url));
    const result = await runPython({ command: 'resolve', script, state,
      request: { question: 'Which cleanup method?', repository: 'Example/repo', kind: 'preference',
        options: [{id:'script',text:'Use script'}, {id:'manual',text:'Manual cleanup'}] } });
    assert.equal(result.state, 'investigate');
    assert.equal(result.recommendation, null);
    assert.equal(result.execute, false);
    const status = await runPython({ command: 'status', script, state });
    assert.equal(status.observations, 1);
    assert.equal(status.decisions, 0);
  } finally { await rm(state, {recursive:true,force:true}); }
});

test('pre-cancelled subprocess fails without asking a human', async () => {
  const controller = new AbortController();
  controller.abort();
  await assert.rejects(runPython({ command: 'resolve', script: 'unused.py', state: '.',
    request: {}, signal: controller.signal }));
});
