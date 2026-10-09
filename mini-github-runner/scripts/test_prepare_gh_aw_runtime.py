"""Exercise provisioning and service selection without changing the host."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("prepare-gh-aw-runtime.sh")
MOCK = r'''#!/usr/bin/env python3
import json, os, subprocess, sys
from pathlib import Path
name = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["MOCK_LOG"], "a") as log:
    log.write(json.dumps([name, *args]) + "\n")
if name == "sudo":
    if args[:1] == ["-u"]:
        args = args[2:]
        if args[:1] == ["-H"]:
            args = args[1:]
    sys.exit(subprocess.call(args))
if name == "tee":
    sys.stdin.read()
elif name == "dpkg":
    print("amd64")
elif name == "curl":
    Path(args[args.index("-o") + 1]).write_text("mock key")
elif name == "systemctl" and args[:1] == ["cat"]:
    sys.exit(0 if os.environ["MOCK_REGISTERED"] == "1" else 1)
elif name in ["docker", "rg", "gh"]:
    print("mock version")
'''


class RuntimePreparationTests(unittest.TestCase):
    def run_preparation(self, stored_service=None, override=None, registered=True):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            commands = root / "commands"
            commands.mkdir()
            mock = commands / "mock"
            mock.write_text(MOCK)
            mock.chmod(0o755)
            for name in ["sudo", "id", "apt-get", "install", "curl", "dpkg",
                         "tee", "usermod", "systemctl", "docker", "rg", "gh"]:
                (commands / name).symlink_to(mock)
            runner = root / "runner"
            runner.mkdir()
            if stored_service is not None:
                (runner / ".service").write_text(stored_service + "\n")
            log = root / "commands.jsonl"
            environment = dict(os.environ)
            environment.update(PATH=str(commands) + os.pathsep + environment["PATH"],
                               RUNNER_DIRECTORY=str(runner), MOCK_LOG=str(log),
                               MOCK_REGISTERED="1" if registered else "0")
            environment.pop("RUNNER_SERVICE", None)
            if override is not None:
                environment["RUNNER_SERVICE"] = override
            result = subprocess.run(["bash", str(SCRIPT)], env=environment,
                                    capture_output=True, text=True)
            entries = [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []
            return result, entries

    def test_fresh_guest_installs_dependencies_before_registration(self):
        result, entries = self.run_preparation()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(any(e[0] == "apt-get" and "docker-ce" in e for e in entries))
        self.assertFalse(any(e[:2] == ["systemctl", "restart"] for e in entries))
        self.assertTrue(any(e[:2] == ["docker", "version"] for e in entries))

    def test_registered_units_keep_their_generated_name(self):
        for service in ["actions.runner.HemSoft-yahtzee.mini-github-runner-01.service",
                        "actions.runner.hemsoft-dev-yahtzee.mini-github-runner-01.service"]:
            with self.subTest(service=service):
                result, entries = self.run_preparation(stored_service=service)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(["systemctl", "restart", service], entries)

    def test_explicit_service_override_does_not_read_missing_registration(self):
        service = "actions.runner.custom.runner.service"
        result, entries = self.run_preparation(override=service)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(["systemctl", "restart", service], entries)

    def test_invalid_override_fails_before_installation(self):
        result, entries = self.run_preparation(override="docker.service")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Invalid runner service name", result.stderr)
        self.assertEqual(entries, [])

    def test_missing_systemd_unit_is_not_restarted(self):
        result, entries = self.run_preparation(
            stored_service="actions.runner.hemsoft-dev-yahtzee.runner.service", registered=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any(e[:2] == ["systemctl", "restart"] for e in entries))


if __name__ == "__main__":
    unittest.main()
