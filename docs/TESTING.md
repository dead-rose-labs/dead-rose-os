# Testing

`./dr test` runs frontend ESLint, TypeScript, Vitest, Rust formatting, Clippy with warnings denied, and Rust tests.

`tests/integration/repository.sh` checks the pinned Ubuntu/Kairos/AuroraBoot architecture, production install safety, persistence configuration, removal of legacy branding/build systems, and absence of shell interpolation in privileged Rust commands. The image build itself runs `tests/integration/image-sanity.sh` before Factory can turn the OCI filesystem into an ISO; this validates greetd session roles, `graphical.target`, GPU access, locale, executables, and dynamic dependencies.

Appliance acceptance requires Linux amd64 Docker plus QEMU/OVMF:

```bash
./dr image
./dr test-image
./dr iso
./dr test-qemu live
./dr test-install
```

The production ISO test waits for the real `DEAD_ROSE_UI_READY` marker. After the frontend has successfully obtained its application state, Dead Rose Shell sends the narrow typed `report_ui_ready` acknowledgement over the existing Unix socket; Dead Rose Core emits the marker through its systemd-managed console output. This keeps the signal observable on QEMU serial even though Cage and the Shell run on VT1. In GitHub Actions, acceptance downloads exactly one Factory ISO and verifies its Factory-generated checksum before QEMU starts. It never rebuilds the image or ISO.

For automated installation, QEMU attaches `os/cloud-config/ci-install.yaml` as a temporary `cidata` config-drive alongside the unchanged production ISO. The config selects only the test VM's dedicated `/dev/vda`. After installation QEMU detaches both ISO drives, boots the installed disk, verifies First Setup, then boots it again and requires a persistent-state marker. The downloadable production ISO still contains `auto: false` and never auto-selects a physical disk.

On every acceptance failure, serial console logs are uploaded as `dead-rose-qemu-diagnostics-<sha>`. Time passing alone is never treated as success.

AuroraBoot's amd64 live-media template uses `nomodeset`. The image explicitly enables KMS only for the `virtio_gpu` device used by QEMU acceptance; it does not force software rendering or alter physical GPU drivers.

Upgrade acceptance requires two published, pinned OCI test versions. Run the Core `StartUpgrade` request against the second approved GHCR tag, reboot, verify `/etc/kairos-release`, Core/UI readiness, version change, and the unchanged SQLite state. This test must not be reported as passed unless those images were actually published and exercised.
