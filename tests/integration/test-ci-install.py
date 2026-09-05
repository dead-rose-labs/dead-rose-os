#!/usr/bin/env python3
"""Exercise the CI guest persistence code without booting or modifying a guest."""

from pathlib import Path
import os
import sqlite3
import subprocess
import sys
import tempfile
import textwrap
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[2]


def guest_code():
    # Extract the literal file content without adding a YAML dependency to CI.
    config = (ROOT / "os/cloud-config/ci-install.yaml").read_text()
    block = config.split("- path: /run/dead-rose-ci-acceptance.py\n", 1)[1]
    block = block.split("          content: |\n", 1)[1]
    lines = []
    for line in block.splitlines():
        if line and not line.startswith("            "):
            break
        lines.append(line[12:] if line else "")
    return "\n".join(lines)


class InstalledStateTests(unittest.TestCase):
    def setUp(self):
        self.namespace = {"__name__": "ci_guest_test"}
        exec(compile(guest_code(), "ci-installed-guest", "exec"), self.namespace)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.persist = self.namespace["persist_state"]

    def test_committed_payload_survives_reopen_and_keeps_nonce(self):
        marker, nonce = self.persist(self.directory, "boot-one")
        self.assertEqual(marker, "DEAD_ROSE_CI_STATE_WRITTEN")
        self.assertEqual(len(nonce), 64)
        marker, restored = self.persist(self.directory, "boot-two")
        self.assertEqual(marker, "DEAD_ROSE_PERSISTENCE_OK")
        self.assertEqual(restored, nonce)

    def test_same_boot_cannot_prove_persistence(self):
        self.persist(self.directory, "boot-one")
        with self.assertRaisesRegex(RuntimeError, "different installed boot"):
            self.persist(self.directory, "boot-one")

    def test_wrong_payload_is_not_repaired(self):
        self.persist(self.directory, "boot-one")
        with sqlite3.connect(self.directory / "ci-acceptance.db") as db:
            db.execute("UPDATE witness SET payload = 'wrong'")
        with self.assertRaisesRegex(RuntimeError, "content mismatch"):
            self.persist(self.directory, "boot-two")

    def test_filename_without_database_is_not_proof(self):
        (self.directory / "ci-acceptance.db").touch()
        with self.assertRaises(sqlite3.DatabaseError):
            self.persist(self.directory, "boot-two")

    def test_corrupt_database_is_not_recreated(self):
        (self.directory / "ci-acceptance.db").write_bytes(b"invalid database")
        with self.assertRaises(sqlite3.DatabaseError):
            self.persist(self.directory, "boot-two")

    def test_no_ui_prevents_state_write_and_shutdown(self):
        with patch.object(self.namespace["time"], "monotonic", side_effect=[0, 241]), \
             patch.dict(self.namespace, persist_state=unittest.mock.Mock(), emit=unittest.mock.Mock()), \
             patch.object(self.namespace["subprocess"], "run") as run:
            with self.assertRaisesRegex(RuntimeError, "UI did not become ready"):
                self.namespace["main"]()
            self.namespace["persist_state"].assert_not_called()
            run.assert_not_called()


class HostSequenceTests(unittest.TestCase):
    def run_sequence(self, scenario):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for folder in ("scripts", "build", "bin", "os/cloud-config"):
                (root / folder).mkdir(parents=True)
            (root / "VERSION").write_text("0.1.0")
            (root / "firmware").write_text("fixture")
            (root / "build/dead-rose-os-0.1.0-amd64.iso").write_text("fixture")
            (root / "os/cloud-config/ci-install.yaml").write_text("#cloud-config\n")
            script = (ROOT / "scripts/test-install-qemu.sh").read_text()
            start = script.index("for candidate in ")
            end = script.index("; do", start)
            script = script[:start] + f'for candidate in "{root}/firmware"' + script[end:]
            (root / "scripts/test-install-qemu.sh").write_text(script)
            tools = {
                "mkisofs": "#!/bin/sh\nexit 0\n",
                "qemu-img": "#!/bin/sh\nexit 0\n",
                "sleep": f"#!{sys.executable}\nimport time\ntime.sleep(0.02)\n",
                "isoinfo": "#!/bin/sh\n" + textwrap.dedent("""\
                    case " $* " in
                      *" -d "*) echo 'Volume id: cidata';;
                      *" -f "*) printf '/user-data\\n/meta-data\\n';;
                      *" -x /user-data "*) printf '#cloud-config\\n';;
                      *" -x /meta-data "*) :;;
                      *) exit 1;;
                    esac
                    """),
                "qemu-system-x86_64": f"#!{sys.executable}\n" + textwrap.dedent("""\
                    import os, sys, time
                    from pathlib import Path
                    root = Path(os.environ['CI_SEQUENCE_ROOT'])
                    count = root / 'count'
                    boot = int(count.read_text()) + 1 if count.exists() else 0
                    count.write_text(str(boot))
                    args = sys.argv[1:]
                    cds = [a for a in args if 'media=cdrom' in a]
                    assert len(cds) == (2 if boot == 0 else 0)
                    serial = args[args.index('-serial') + 1]
                    if boot == 0:
                        chardev = args[args.index('-chardev') + 1]
                        log = Path(chardev.split('logfile=', 1)[1])
                    else:
                        log = Path(serial.removeprefix('file:'))
                    scenario = os.environ['CI_SEQUENCE_SCENARIO']
                    nonce = 'a' * 64
                    with log.open('w') as stream:
                        if boot == 0:
                            stream.write('DEAD_ROSE_CI_HEADLESS\\n')
                        else:
                            if not (boot == 2 and scenario == 'missing-ui'):
                                stream.write('DEAD_ROSE_UI_READY mode=first_boot\\n')
                            stream.flush()
                            # A host that kills immediately at UI_READY fails this test.
                            time.sleep(0.15)
                            if boot == 2 and scenario == 'wrong-nonce':
                                nonce = 'b' * 64
                            marker = 'DEAD_ROSE_CI_STATE_WRITTEN' if boot == 1 else 'DEAD_ROSE_PERSISTENCE_OK'
                            stream.write(marker + ' nonce=' + nonce + '\\n')
                            if scenario != 'missing-shutdown':
                                stream.write('DEAD_ROSE_CI_SHUTDOWN_REQUESTED\\n')
                    (root / ('guest-exited-' + str(boot))).touch()
                    """),
            }
            for name, contents in tools.items():
                path = root / "bin" / name
                path.write_text(contents)
                path.chmod(0o755)
            env = dict(os.environ, PATH=str(root / "bin") + ":" + os.environ["PATH"],
                       CI_SEQUENCE_ROOT=str(root), CI_SEQUENCE_SCENARIO=scenario)
            result = subprocess.run(["bash", str(root / "scripts/test-install-qemu.sh")],
                                    env=env, capture_output=True, text=True, timeout=15)
            return result, len(list(root.glob("guest-exited-*")))

    def test_full_sequence_waits_for_guest_and_detaches_media(self):
        result, completed = self.run_sequence("success")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(completed, 3)

    def test_second_boot_needs_ui_and_original_nonce(self):
        for scenario in ("missing-ui", "wrong-nonce", "missing-shutdown"):
            with self.subTest(scenario=scenario):
                result, _ = self.run_sequence(scenario)
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
