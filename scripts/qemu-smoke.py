#!/usr/bin/env python3
"""Boot the unmodified ISO under OVMF, require live readiness, save evidence."""
import argparse
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser()
parser.add_argument('iso', type=Path)
parser.add_argument('--output', type=Path, default=Path('artifacts/qemu'))
parser.add_argument('--timeout', type=int, default=300)
args = parser.parse_args()
if not args.iso.is_file():
    parser.error('ISO does not exist')
args.output.mkdir(parents=True, exist_ok=True)
output = args.output.resolve()

firmware_pairs = [
    ('/usr/share/OVMF/OVMF_CODE_4M.fd', '/usr/share/OVMF/OVMF_VARS_4M.fd'),
    ('/usr/share/edk2/x64/OVMF_CODE.4m.fd', '/usr/share/edk2/x64/OVMF_VARS.4m.fd'),
    ('/usr/share/edk2/x64/OVMF_CODE.fd', '/usr/share/edk2/x64/OVMF_VARS.fd'),
]
firmware = next(((Path(c), Path(v)) for c, v in firmware_pairs if Path(c).is_file() and Path(v).is_file()), None)
if firmware is None:
    parser.error('OVMF firmware missing; install ovmf (Ubuntu) or edk2-ovmf (Arch)')
code, variables = firmware
shutil.copyfile(variables, output / 'OVMF_VARS.fd')

with tempfile.TemporaryDirectory(prefix='deadrose-qmp-') as temp:
    qmp_path = str(Path(temp) / 'qmp.sock')
    acceleration = 'kvm' if os.access('/dev/kvm', os.R_OK | os.W_OK) else 'tcg'
    command = [
        'qemu-system-x86_64', '-machine', 'q35', '-accel', acceleration,
        '-cpu', 'host' if acceleration == 'kvm' else 'max',
        '-smp', '2', '-m', '4096', '-boot', 'd',
        '-drive', f'if=pflash,format=raw,readonly=on,file={code}',
        '-drive', f'if=pflash,format=raw,file={output / "OVMF_VARS.fd"}',
        '-cdrom', str(args.iso.resolve()), '-device', 'virtio-vga',
        '-device', 'qemu-xhci', '-device', 'usb-tablet',
        '-nic', 'user,model=virtio-net-pci', '-display', 'none',
        '-serial', f'file:{output / "qemu-serial.log"}',
        '-fw_cfg', 'name=opt/deadrose/ci,string=1',
        '-qmp', f'unix:{qmp_path},server=on,wait=off', '-no-reboot',
    ]
    (output / 'qemu-command.json').write_text(json.dumps(command, indent=2))
    success = False
    markers = {name: False for name in ('DEAD_ROSE_LIVE_READY', 'DEAD_ROSE_SDDM_READY', 'DEAD_ROSE_PLASMA_READY')}
    reason = 'Timed out waiting for live desktop'
    with (output / 'qemu.log').open('w') as log:
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + args.timeout
            while time.monotonic() < deadline:
                if process.poll() is not None:
                    reason = f'QEMU exited early ({process.returncode})'
                    break
                serial = output / 'qemu-serial.log'
                text = serial.read_text(errors='replace') if serial.exists() else ''
                if 'DEAD_ROSE_LIVE_FAILED' in text or 'DEAD_ROSE_BASE_FAILED' in text:
                    reason = 'Guest readiness check failed'
                    break
                for marker in markers:
                    markers[marker] = marker in text.splitlines()
                if all(markers.values()):
                    success = True
                    reason = 'UEFI live desktop readiness passed'
                    break
                # Bounded observation loop, never a boot workaround or retry.
                time.sleep(1)
            if process.poll() is None:
                try:
                    with socket.socket(socket.AF_UNIX) as connection:
                        connection.settimeout(10)
                        connection.connect(qmp_path)
                        stream = connection.makefile('rwb')
                        stream.readline()
                        for request in [
                            {'execute': 'qmp_capabilities'},
                            {'execute': 'screendump', 'arguments': {'filename': str(output / 'desktop.ppm')}},
                        ]:
                            stream.write(json.dumps(request).encode() + b'\n')
                            stream.flush()
                            while True:
                                reply = json.loads(stream.readline())
                                if 'return' in reply or 'error' in reply:
                                    if 'error' in reply:
                                        raise RuntimeError(reply['error'])
                                    break
                except (OSError, ValueError, RuntimeError) as error:
                    (output / 'screenshot-error.txt').write_text(str(error))
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
    (output / 'qemu-result.json').write_text(json.dumps({'passed': success, 'reason': reason, 'acceleration': acceleration, 'markers': markers}, indent=2))
    print(reason)
    raise SystemExit(0 if success else 1)
