// Optional live-host contract smoke. No provider request or real history access.
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { parseArgs } from 'node:util';
const { values } = parseArgs({ options: { sdk: {type:'string'}, extension: {type:'string'}, skill: {type:'string'} } });
if (!values.sdk) throw new Error('Supply the installed Pi dist/index.js with --sdk');
const { DefaultResourceLoader, SettingsManager } = await import(pathToFileURL(resolve(values.sdk)).href);
const skillPath = values.skill || dirname(dirname(fileURLToPath(import.meta.url)));
const root = await mkdtemp(join(tmpdir(), 'precedent-pi-smoke-'));
const oldState = process.env.PRECEDENT_STATE;
const oldDisabled = process.env.PRECEDENT_DISABLED;
process.env.PRECEDENT_STATE = join(root, 'private');
delete process.env.PRECEDENT_DISABLED;
try {
  const loader = new DefaultResourceLoader({ cwd:root, agentDir:root, settingsManager:SettingsManager.inMemory({}),
    additionalExtensionPaths:[values.extension || join(skillPath, 'scripts/pi-extension.ts')],
    additionalSkillPaths:[skillPath], noPromptTemplates:true, noThemes:true, noContextFiles:true });
  await loader.reload();
  const result = loader.getExtensions();
  assert.deepEqual(result.errors, []);
  const extension = result.extensions.find(e => e.tools.has('resolve_decision'));
  assert.ok(extension, 'Tool did not register');
  const tool = extension.tools.get('resolve_decision').definition;
  const ctx = { signal:new AbortController().signal, ui:{notify() {}} };
  const response = await tool.execute('smoke', { question:'Which cleanup method?', repository:'Example/synthetic',
    kind:'preference', options:[{id:'script',text:'Existing script'}, {id:'manual',text:'Manual cleanup'}] }, ctx.signal, undefined, ctx);
  assert.notEqual(response.isError, true);
  assert.equal(response.structuredContent.state, 'investigate');
  assert.equal(response.structuredContent.execute, false);
  assert.deepEqual(response.structuredContent.decisions, []);
  let active = ['read', 'resolve_decision'];
  result.runtime.getActiveTools = () => active;
  result.runtime.setActiveTools = names => { active = names; };
  const command = extension.commands.get('precedent');
  await command.handler('off', ctx);
  assert.deepEqual(active, ['read']);
  assert.equal(await extension.handlers.get('before_agent_start')[0]({}, ctx), undefined);
  await command.handler('on', ctx);
  assert.deepEqual(active, ['read', 'resolve_decision']);
  assert.ok(await extension.handlers.get('before_agent_start')[0]({}, ctx));
  const event = { outcome:'completed', context:{contextMessages:[{role:'assistant',
    content:[{type:'text',text:'Would you prefer the cleanup script or manual cleanup?'}]}]} };
  const settle = extension.handlers.get('agent_before_settle')[0];
  assert.equal((await settle(event, ctx)).continue, true);
  assert.equal(await settle(event, ctx), undefined);
  assert.ok(loader.getSkills().skills.some(s => s.name === 'precedent'));
  assert.deepEqual(loader.getSkills().diagnostics, []);
  console.log(JSON.stringify({ sdkLoaded:true, extensionLoaded:true, toolExecuted:true, skillDiscovered:true,
    commandToggleVerified:true, recoveryContractVerified:true, privateHistoryAccessed:false, providerCalls:0 }));
} finally {
  await rm(root, {recursive:true,force:true});
  if (oldState === undefined) delete process.env.PRECEDENT_STATE; else process.env.PRECEDENT_STATE = oldState;
  if (oldDisabled === undefined) delete process.env.PRECEDENT_DISABLED; else process.env.PRECEDENT_DISABLED = oldDisabled;
}
