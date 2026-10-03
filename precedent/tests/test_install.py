import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from install import install, LOADER


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.package = self.root / 'package'
        self.home = self.root / 'home'
        self.files = {'SKILL.md': b'synthetic skill', 'scripts/precedent.py': b'# synthetic',
                      'scripts/pi-extension.ts': b'// synthetic', 'scripts/pi-support.mjs': b'// synthetic'}
        for rel, data in self.files.items():
            path = self.package / 'skill' / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        self.manifest = {'version': '1.0.0', 'files': {r: hashlib.sha256(d).hexdigest() for r, d in self.files.items()}}
        self.save()

    def save(self):
        (self.package / 'manifest.json').write_text(json.dumps(self.manifest))

    def tearDown(self):
        self.temp.cleanup()

    def test_verified_install_and_idempotent_rerun(self):
        result = install(self.package, self.home)
        self.assertTrue(result['hash_parity'])
        self.assertFalse(result['private_memory_copied'])
        self.assertEqual((self.home / '.pi/agent/extensions/precedent.ts').read_text(), LOADER)
        self.assertEqual(install(self.package, self.home), result)
        self.assertFalse((self.home / '.agents/precedent').exists())

    def test_tampering_rejected_before_any_install(self):
        (self.package / 'skill/SKILL.md').write_text('tampered')
        with self.assertRaises(ValueError):
            install(self.package, self.home)
        self.assertFalse(self.home.exists())

    def test_traversal_and_history_rejected(self):
        for path in ['../other', '/absolute', 'History/2026-01-01.md', 'C:/absolute']:
            self.manifest['files'][path] = '0' * 64
            self.save()
            with self.assertRaises(ValueError):
                install(self.package, self.home)
            self.manifest['files'].pop(path)

    def guidance(self):
        block = '## Decision consultation\n\nSynthetic shadow-mode guidance.\n'
        raw = json.dumps({'.pi/agent/AGENTS.md': block}).encode()
        (self.package / 'guidance.json').write_bytes(raw)
        self.manifest['guidance_sha256'] = hashlib.sha256(raw).hexdigest()
        self.save()
        return block

    def test_guidance_appends_and_backs_up_without_changing_machine_settings(self):
        block = self.guidance()
        dest = self.home / '.pi/agent/AGENTS.md'
        dest.parent.mkdir(parents=True)
        old = b'# Local settings\r\nMachine-specific policy.\r\n'
        dest.write_bytes(old)
        history = self.home / '.agents/skills/precedent/History/own.md'
        history.parent.mkdir(parents=True)
        history.write_text('Keep this peer history')
        result = install(self.package, self.home)
        self.assertIn(block, dest.read_text())
        self.assertIn('Machine-specific policy.', dest.read_text())
        backups = list((self.home / '.agents/backups').rglob('AGENTS.md'))
        self.assertEqual(backups[0].read_bytes(), old)
        self.assertEqual(history.read_text(), 'Keep this peer history')
        self.assertEqual(install(self.package, self.home), result)

    def test_conflicting_guidance_is_preserved_and_blocks_install(self):
        self.guidance()
        dest = self.home / '.pi/agent/AGENTS.md'
        dest.parent.mkdir(parents=True)
        dest.write_text('## Decision consultation\nA different owner policy.\n')
        with self.assertRaises(ValueError):
            install(self.package, self.home)
        self.assertIn('different owner policy', dest.read_text())
        self.assertFalse((self.home / '.agents/skills/precedent/SKILL.md').exists())

    def test_different_active_code_is_preserved(self):
        dest = self.home / '.agents/skills/precedent/SKILL.md'
        dest.parent.mkdir(parents=True)
        dest.write_text('owned by someone else')
        with self.assertRaises(ValueError):
            install(self.package, self.home)
        self.assertEqual(dest.read_text(), 'owned by someone else')
        self.assertFalse((self.home / '.pi/agent/extensions/precedent.ts').exists())


if __name__ == '__main__':
    unittest.main()
