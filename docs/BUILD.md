# Build

Run `./dr doctor` first. A complete appliance build requires Docker with buildx. QEMU and OVMF are required for boot acceptance.

```bash
./dr build       # frontend and Rust lint, tests, and application builds
./dr image       # dead-rose-os:0.1.0 (linux/amd64)
./dr test-image  # Ubuntu/Kairos/runtime sanity checks
./dr iso         # production AuroraBoot ISO and checksum
```

All lifecycle tool versions are centralized in `versions.env`. The image is transformed with `kairos-init`; the ISO is emitted directly by AuroraBoot and is never patched afterward.

Artifacts:

```text
build/dead-rose-os-0.1.0-amd64.iso
build/dead-rose-os-0.1.0-amd64.iso.sha256
```
