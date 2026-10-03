import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';
import { Type, type Static } from 'typebox';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createGuard, guidance, runPython } from './pi-support.mjs';

const id = Type.String({ pattern: '^[A-Za-z][A-Za-z0-9_.-]{0,79}$' });
const parameters = Type.Object({
  question: Type.String({ minLength: 1, maxLength: 2000 }),
  repository: Type.String({ maxLength: 200, description: 'Canonical OWNER/REPO, empty only for a genuinely global choice' }),
  kind: Type.Union(['fact', 'preference', 'design', 'scope', 'authority', 'human_action'].map(x => Type.Literal(x))),
  options: Type.Array(Type.Object({ id, text: Type.String({ minLength: 1, maxLength: 500 }) },
    { additionalProperties: false }), { minItems: 2, maxItems: 8 }),
  before: Type.Optional(Type.String({ maxLength: 40, description: 'Exclusive ISO timestamp cutoff for historical replay' })),
  proposal: Type.Optional(Type.Object({
    option_id: id,
    evidence_ids: Type.Array(id, { minItems: 1, maxItems: 5 }),
    rationale: Type.String({ minLength: 1, maxLength: 1000 }),
    differences: Type.Optional(Type.String({ maxLength: 1000 })),
    invalidators: Type.Optional(Type.String({ maxLength: 1000 })),
  }, { additionalProperties: false })),
}, { additionalProperties: false });

export default function precedentExtension(pi: ExtensionAPI) {
  const guard = createGuard();
  const scripts = dirname(fileURLToPath(import.meta.url));
  const state = process.env.PRECEDENT_STATE || join(homedir(), '.agents', 'precedent');
  let enabled = process.env.PRECEDENT_DISABLED !== '1';
  pi.registerTool({
    name: 'resolve_decision', label: 'Consult Precedent',
    description: 'Retrieve locally indexed, source-linked past decisions before asking Franz a question. ' +
      'Call without a proposal first; compare current context with quoted evidence, then submit an evidence-backed ' +
      'proposal if supported. Runs in shadow mode: never grants authority or executes recommendations.',
    promptSnippet: 'Consult source-linked past user choices before asking a decision question',
    promptGuidelines: [guidance],
    parameters,
    outputSchema: Type.Record(Type.String(), Type.Unknown()),
    executionMode: 'sequential',
    exposure: 'model-only',
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false },
    async execute(_callId, params: Static<typeof parameters>, signal) {
      if (!enabled) return { content: [{ type: 'text', text: 'Precedent is off for this session. Use normal decision gates.' }],
        details: { disabled: true }, isError: true };
      try {
        const result = await runPython({ command: 'resolve', script: join(scripts, 'precedent.py'), state,
          request: params, signal });
        guard.consulted();
        return { content: [{ type: 'text', text: JSON.stringify(result) }], details: result, structuredContent: result };
      } catch {
        // Mark the failed consultation too: recovery must not retry a broken runtime forever.
        guard.consulted();
        return { content: [{ type: 'text', text: 'Precedent unavailable or cancelled. No authority granted. ' +
          'Investigate directly or preserve the human question; do not infer approval.' }],
          details: { unavailable: true, execute: false }, isError: true };
      }
    },
  });
  pi.on('session_start', () => {
    if (!enabled) pi.setActiveTools(pi.getActiveTools().filter(name => name !== 'resolve_decision'));
  });
  pi.on('before_agent_start', () => {
    guard.reset();
    if (!enabled) return;
    return { message: { customType: 'precedent-guidance', content: guidance, display: false } };
  });
  pi.on('agent_before_settle', (event, ctx) => {
    if (ctx.signal?.aborted) return;
    const last = [...event.context.contextMessages].reverse().find(m => m.role === 'assistant');
    const content = last?.content;
    const text = Array.isArray(content) ? content.filter(b => b.type === 'text').map(b => b.text).join('\n') : '';
    return guard.settle(text, event.outcome, enabled);
  });
  // Observation only. Do not replace dialog answers or approve confirmations.
  pi.on('ui_prompt_start', () => {
    if (enabled) pi.appendEntry('precedent-ui-wait', { at: Date.now(), observed: true, answered: false });
  });
  pi.registerCommand('precedent', {
    description: 'Precedent status, off, or on. Always shadow mode; does not enable autonomous actions.',
    async handler(args, ctx) {
      const action = args.trim() || 'status';
      if (action === 'off' || action === 'on') {
        enabled = action === 'on';
        const active = pi.getActiveTools().filter(name => name !== 'resolve_decision');
        pi.setActiveTools(enabled ? [...active, 'resolve_decision'] : active);
        guard.reset();
        ctx.ui.notify(`Precedent ${enabled ? 'on in shadow mode' : 'off'} for this session.`, 'info');
        return;
      }
      if (action !== 'status') { ctx.ui.notify('Use /precedent status, off, or on.', 'warning'); return; }
      try {
        const status = await runPython({ command: 'status', script: join(scripts, 'precedent.py'), state });
        pi.sendMessage({ customType: 'precedent-status', content: JSON.stringify({ ...status, enabled }), display: true });
      } catch { ctx.ui.notify('Precedent unavailable. No authority granted.', 'warning'); }
    },
  });
}
