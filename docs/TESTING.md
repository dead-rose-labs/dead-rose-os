# Testing

`./dr test` runs frontend ESLint, TypeScript, Vitest, Rust formatting, Clippy with warnings denied, and Rust tests.

`tests/integration/repository.sh` checks the pinned Ubuntu/Kairos/AuroraBoot architecture, production install safety, persistence configuration, removal of legacy branding/build systems, and absence of shell interpolation in privileged Rust commands.

Appliance acceptance requires Linux amd64 Docker plus QEMU/OVMF:

```bash
./dr image
./dr test-image
./dr iso
./dr test-qemu live
./dr iso --ci
./dr test-install
```

The production ISO test waits for the real `DEAD_ROSE_UI_READY` process marker. The CI-only ISO auto-installs to its dedicated `/dev/vda`, powers off, boots with the ISO removed, verifies First Setup, then boots again and requires a persistent-state marker. Time passing alone is never treated as success.

Upgrade acceptance requires two published, pinned OCI test versions. Run the Core `StartUpgrade` request against the second approved GHCR tag, reboot, verify `/etc/kairos-release`, Core/UI readiness, version change, and the unchanged SQLite state. This test must not be reported as passed unless those images were actually published and exercised.
