#!/usr/bin/env python3
"""Install a hash-verified code package. Never copies private memory or histories."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import sys

LOADER = 'export { default } from "../../../.agents/skills/precedent/scripts/pi-extension.ts";\n'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def install(package, home):
    package = Path(package).resolve()
    home = Path(home).resolve()
    manifest = json.loads((package / 'manifest.json').read_text(encoding='utf-8'))
    files = manifest.get('files', {})
    if manifest.get('version') != '1.0.0' or not isinstance(files, dict) or not 1 <= len(files) <= 100:
        raise ValueError('Invalid package manifest')
    target = home / '.agents/skills/precedent'
    staged = []
    for rel, expected in files.items():
        path = PurePosixPath(rel)
        if path.is_absolute() or any(x in ('..', 'History', '__pycache__', 'node_modules') for x in path.parts) or '\\' in rel or ':' in rel:
            raise ValueError('Unsafe package path')
        source = package / 'skill' / rel
        dest = target / rel
        if source.is_symlink() or not source.is_file():
            raise ValueError('Package file missing or linked')
        content = source.read_bytes()
        if sha(content) != expected:
            raise ValueError('Package hash mismatch')
        staged.append((dest, content))
    required = {'SKILL.md', 'scripts/precedent.py', 'scripts/pi-extension.ts', 'scripts/pi-support.mjs'}
    if not required <= set(files):
        raise ValueError('Required runtime files missing')
    guidance = {}
    if 'guidance_sha256' in manifest:
        raw = (package / 'guidance.json').read_bytes()
        if sha(raw) != manifest['guidance_sha256']:
            raise ValueError('Guidance hash mismatch')
        guidance = json.loads(raw)
        if set(guidance) - {'.agents/skills/AGENTS.md', '.pi/agent/AGENTS.md'} or any(
                not isinstance(block, str) or not block.startswith('## Decision consultation\n') or len(block) > 2000
                for block in guidance.values()):
            raise ValueError('Invalid shared guidance')
    guidance_plans = []
    for rel, block in guidance.items():
        dest = home / rel
        if any(p.is_symlink() or (hasattr(p, 'is_junction') and p.is_junction())
               for p in (dest, *dest.parents) if p != home):
            raise ValueError('Linked guidance destination')
        old = dest.read_bytes() if dest.exists() else b''
        text = old.decode('utf-8')
        if block in text.replace('\r\n', '\n'):
            continue
        if '## Decision consultation' in text:
            raise ValueError('Different shared guidance exists; preserved')
        updated = (text.rstrip('\r\n') + ('\n\n' if text else '') + block).encode('utf-8')
        guidance_plans.append((dest, old, updated))
    # Initial rollout never replaces different active code. A future updater
    # must take a verified backup and bind an expected installed manifest.
    loader = home / '.pi/agent/extensions/precedent.ts'
    staged.append((loader, LOADER.encode('utf-8')))
    for dest, content in staged:
        for parent in (dest, *dest.parents):
            if parent == home:
                break
            if parent.is_symlink() or (hasattr(parent, 'is_junction') and parent.is_junction()):
                raise ValueError('Linked destination rejected')
        if dest.exists() and (not dest.is_file() or dest.read_bytes() != content):
            raise ValueError('Different active file exists; preserved')
    for dest, content in staged:
        dest.parent.mkdir(parents=True, exist_ok=True)
        if not dest.exists():
            # Exclusive creation refuses another writer appearing after preflight.
            with dest.open('xb') as f:
                f.write(content)
        if dest.read_bytes() != content:
            raise ValueError('Installed hash mismatch')
    for dest, old, updated in guidance_plans:
        if (dest.read_bytes() if dest.exists() else b'') != old:
            raise ValueError('Shared guidance changed during staging; preserved')
        if old:
            backup = home / '.agents/backups/precedent-1.0.0' / sha(old)[:16] / dest.relative_to(home)
            backup.parent.mkdir(parents=True, exist_ok=True)
            if not backup.exists():
                with backup.open('xb') as f:
                    f.write(old)
            if backup.read_bytes() != old:
                raise ValueError('Backup verification failed')
        dest.parent.mkdir(parents=True, exist_ok=True)
        temporary = dest.with_name(dest.name + '.precedent-tmp')
        with temporary.open('xb') as f:
            f.write(updated)
        if (dest.read_bytes() if dest.exists() else b'') != old:
            temporary.unlink()
            raise ValueError('Shared guidance changed before replacement')
        temporary.replace(dest)
        if dest.read_bytes() != updated:
            raise ValueError('Installed guidance verification failed')
    for rel, block in guidance.items():
        if block not in (home / rel).read_text(encoding='utf-8').replace('\r\n', '\n'):
            raise ValueError('Final shared guidance verification failed')
    return {'version': manifest['version'], 'installed_files': len(files), 'hash_parity': True,
            'guidance_hashes': {rel: sha(block.encode('utf-8')) for rel, block in guidance.items()},
            'history_preserved': True,
            'skill': str(target), 'loader': str(loader), 'private_memory_copied': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--package', required=True)
    parser.add_argument('--home', default=str(Path.home()))
    args = parser.parse_args()
    try:
        print(json.dumps(install(args.package, args.home)))
    except (OSError, ValueError) as error:
        print(json.dumps({'installed': False, 'error': type(error).__name__}), file=sys.stderr)
        sys.exit(1)
