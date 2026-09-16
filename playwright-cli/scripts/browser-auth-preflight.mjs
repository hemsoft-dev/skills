#!/usr/bin/env node

import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { homedir, platform } from 'node:os';
import { join } from 'node:path';

const LASTPASS_ID = 'hdokiejnpimakedhajhdlcegeplioahd';
const PLAYWRIGHT_EXTENSION_ID = 'mmlmfjhmonkocbjadbfplnigmagldckm';

function argValue(name, fallback) {
  const prefix = `--${name}=`;
  const match = process.argv.slice(2).find((arg) => arg.startsWith(prefix));
  return match ? match.slice(prefix.length) : fallback;
}

function chromeUserDataDir() {
  if (platform() === 'win32') {
    const base = process.env.LOCALAPPDATA || join(homedir(), 'AppData', 'Local');
    return join(base, 'Google', 'Chrome', 'User Data');
  }
  if (platform() === 'darwin')
    return join(homedir(), 'Library', 'Application Support', 'Google', 'Chrome');
  return join(homedir(), '.config', 'google-chrome');
}

function readJson(path) {
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch {
    return undefined;
  }
}

function profileNames(root) {
  if (!existsSync(root)) return [];
  return readdirSync(root, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && (entry.name === 'Default' || /^Profile \d+$/.test(entry.name)))
    .map((entry) => entry.name)
    .sort((a, b) => a === 'Default' ? -1 : b === 'Default' ? 1 : a.localeCompare(b, undefined, { numeric: true }));
}

function extensionStatus(root, profile, id) {
  const profileDir = join(root, profile);
  const extensionDir = join(profileDir, 'Extensions', id);
  let versions = [];
  if (existsSync(extensionDir)) {
    versions = readdirSync(extensionDir, { withFileTypes: true })
      .filter((entry) => entry.isDirectory())
      .map((entry) => entry.name)
      .sort();
  }

  let setting;
  for (const file of ['Secure Preferences', 'Preferences']) {
    const candidate = readJson(join(profileDir, file))?.extensions?.settings?.[id];
    if (candidate && typeof candidate === 'object') {
      setting = candidate;
      break;
    }
  }

  const installed = versions.length > 0 || Boolean(setting);
  const disableReasons = Array.isArray(setting?.disable_reasons) ? setting.disable_reasons : [];
  const enabled = installed && setting?.state !== 0 && disableReasons.length === 0;
  return {
    installed,
    enabled,
    version: versions.at(-1)?.replace(/_\d+$/, '') || null,
    source: setting?.from_webstore ? 'chrome-web-store' : versions.length ? 'profile-directory' : null,
    disableReasons,
  };
}

function runPlaywright(args) {
  let command = 'playwright-cli';
  let commandArgs = args;
  if (platform() === 'win32') {
    const cliScript = join(
      process.env.APPDATA || join(homedir(), 'AppData', 'Roaming'),
      'npm',
      'node_modules',
      '@playwright',
      'cli',
      'playwright-cli.js',
    );
    if (existsSync(cliScript)) {
      command = process.execPath;
      commandArgs = [cliScript, ...args];
    }
  }

  try {
    return execFileSync(command, commandArgs, {
      encoding: 'utf8',
      windowsHide: true,
      stdio: ['ignore', 'pipe', 'pipe'],
    }).trim();
  } catch (error) {
    return { error: error?.message || String(error) };
  }
}

function parseBoundedJson(output) {
  if (typeof output !== 'string') return undefined;
  const start = output.indexOf('{');
  if (start < 0) return undefined;
  try {
    return JSON.parse(output.slice(start));
  } catch {
    return undefined;
  }
}

const root = chromeUserDataDir();
const localState = readJson(join(root, 'Local State'));
const availableProfiles = profileNames(root);
const requestedProfile = argValue('profile', localState?.profile?.last_used || 'Default');
const profileExists = availableProfiles.includes(requestedProfile);
const lastPass = profileExists ? extensionStatus(root, requestedProfile, LASTPASS_ID) : undefined;
const playwrightExtension = profileExists ? extensionStatus(root, requestedProfile, PLAYWRIGHT_EXTENSION_ID) : undefined;
const versionOutput = runPlaywright(['--version']);
const listOutput = runPlaywright(['list', '--all', '--json']);
const list = parseBoundedJson(listOutput);
const chromeChannel = list?.channelSessions?.find((entry) => entry.channel === 'chrome');

const result = {
  platform: platform(),
  chromeUserDataDir: root,
  profile: requestedProfile,
  profileExists,
  availableProfiles,
  playwrightCli: {
    installed: typeof versionOutput === 'string',
    version: typeof versionOutput === 'string' ? versionOutput : null,
    extensionAttachDetected: chromeChannel?.extensionInstalled === true,
  },
  extensions: {
    lastPass: lastPass || { installed: false, enabled: false, version: null },
    playwright: playwrightExtension || { installed: false, enabled: false, version: null },
  },
  ready: Boolean(
    profileExists &&
    lastPass?.enabled &&
    playwrightExtension?.enabled &&
    chromeChannel?.extensionInstalled === true
  ),
};

console.log(JSON.stringify(result, null, 2));
process.exitCode = result.ready ? 0 : 2;
