# Build

Run `./dr doctor` first. A complete appliance build requires Docker with buildx. QEMU and OVMF are required for boot acceptance.

```bash
./dr build       # frontend and Rust lint, tests, and application builds
./dr image       # dead-rose-os:0.1.0 (linux/amd64)
./dr test-image  # Ubuntu/Kairos/runtime sanity checks
./dr iso         # production AuroraBoot ISO and checksum
```

All lifecycle tool versions are centralized in `versions.env`. The image is transformed with `kairos-init`; the ISO is emitted directly by AuroraBoot and is never patched afterward.

## GitHub builds

`.github/workflows/os-build.yml` is the single CI entry point. It first calls the reusable application checks in `.github/workflows/ci.yml`; only a successful CI result on `main` can continue to the full OS build through the official Kairos Factory reusable workflow in the `kairos-io/kairos` monorepo, pinned to a full commit SHA. Pull requests stop after CI. The archived `kairos-io/kairos-factory-action` repository is not used.

Factory receives `os/Dockerfile`, `ubuntu:26.04`, the pinned versions from `versions.env`, the safe production cloud config, and the generic amd64 target. It builds and publishes an immutable `ci-<full-sha>` OCI tag, creates one ISO with pinned AuroraBoot, computes its checksum, and uploads it as a GitHub artifact. Release tags use an immutable `candidate-<full-sha>` OCI until acceptance passes.

Local development continues to use the same Dockerfile and pins:

```bash
./dr image
./dr iso
./dr test-qemu
```

Artifacts:

```text
build/dead-rose-os-0.1.0-amd64.iso
build/dead-rose-os-0.1.0-amd64.iso.sha256
```
