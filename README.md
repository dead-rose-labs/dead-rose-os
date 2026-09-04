# Dead Rose OS

Dead Rose OS is a personal Linux appliance and local control plane for a private homelab or server rack.

It combines Ubuntu 26.04, Kairos, systemd, Cage/greetd, Tauri, React, Rust, and SQLite around one product principle:

> OS as one application.

Normal boot opens the full-screen Dead Rose graphical environment. There is no Ubuntu Desktop, GNOME, generic login screen, taskbar, terminal, or browser workflow.

## Architecture

Kairos owns installation, the immutable system lifecycle, Active/Passive slots, Recovery, and OCI upgrades. Dead Rose owns the installer experience, local authentication, persistent application state, control-plane UX, and narrow typed system operations.

```text
Ubuntu 26.04 → Kairos → systemd → Dead Rose Core → Unix socket → Tauri/React Shell
```

The production image contains no Kubernetes provider.

## Development

```bash
./dr doctor
./dr build
./dr image
./dr test-image
./dr iso
./dr test-qemu
```

`./dr iso` produces:

```text
build/dead-rose-os-0.1.0-amd64.iso
build/dead-rose-os-0.1.0-amd64.iso.sha256
```

GitHub builds use the pinned Kairos Factory reusable workflow from the Kairos monorepo. Factory builds `os/Dockerfile` once and uploads the OCI/ISO artifacts; Dead Rose then verifies that exact ISO with its own UEFI live, installation, installed-boot, and persistence tests.

See [Build](docs/BUILD.md), [Testing](docs/TESTING.md), [Installation](docs/INSTALLATION.md), and [Updates](docs/UPDATES.md).
