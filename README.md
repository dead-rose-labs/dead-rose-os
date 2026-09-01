# Dead Rose OS

Dead Rose OS is a purpose-built, local graphical control-plane operating system built on Ubuntu Server. Milestone `0.1.0` establishes the boot, display, authentication, session and standard filesystem installation foundations. The authenticated shell intentionally contains only `Coming soon`.

## Supported platform

- Target: UEFI `amd64` / `x86_64`
- OS base: Ubuntu Server 26.04 LTS (not exposed in the normal product UI)
- Canonical builder: Ubuntu 26.04 LTS `amd64`
- Development virtualization: QEMU + OVMF

macOS and other hosts can run frontend and portable Rust checks, but they are not supported image builders.

## Build interface

```sh
./dr bootstrap       # install and validate builder dependencies
./dr build           # build verified Ubuntu rootfs payload
./dr iso             # build the branded installer ISO and digest
./dr vm              # boot the installed image in QEMU
./dr installer-vm    # boot the ISO with a disposable 48 GiB target
./dr test            # frontend, Rust and repository tests
./dr clean           # remove generated files under build/
```

Artifacts are written to `build/`:

```text
dead-rose-os-0.1.0-amd64.root/
dead-rose-os-0.1.0-amd64.rootfs.tar.gz
dead-rose-os-0.1.0-amd64.rootfs.tar.gz.sha256
dead-rose-os-0.1.0-amd64.iso
dead-rose-os-0.1.0-amd64.iso.sha256
logs/
```

Curtin creates the installed GPT layout with a 512 MiB FAT32 `EFI` partition and one ext4 `ROOT` partition using the remaining disk. Mutable Dead Rose state is an ordinary directory at `/var/lib/dead-rose` inside `ROOT`. Ubuntu supplies the kernel, init system, bootloader, authentication/session infrastructure and package management.

## Runtime, installation and recovery

`greetd` creates the PAM/logind session on `tty1`; the small `dead-rose-session` supervisor runs Cage and exactly one allowlisted Tauri application as an unprivileged system account. The installed shell uses `deadrose-ui`; the live installer uses `deadrose-installer`. React never owns session or storage authority.

Boot the ISO, explicitly select a non-installer disk by its stable `/dev/disk/by-id` identity, configure the hostname and administrator, review the exact target, type `ERASE`, then install and restart. The UI sends typed requests over a group-restricted Unix socket to `dead-rose-installer-agent`. That root service verifies the embedded Ubuntu rootfs archive and delegates partitioning, filesystem creation, extraction and GRUB installation to Curtin. It never accepts arbitrary commands or paths from the UI.

The graphical shell owns `tty1`. Recovery remains intentionally available through the GRUB recovery entry or `systemd.unit=rescue.target`; the installer menu also has verbose and debug entries. Recovery output is never part of a successful normal boot. See [build instructions](docs/build.md), [runtime architecture](docs/architecture/os-runtime.md), and the [debug runbook](docs/debug.md).

## Repository map

- `apps/shell` — fullscreen Tauri login and authenticated shell.
- `apps/installer` — fullscreen image installer.
- `packages/ui` — shared Dead Rose tokens and UI primitives.
- `crates/auth` — Argon2id credentials, rate limiting and sessions.
- `crates/core` — authoritative local service.
- `crates/ipc` — typed Unix socket transport.
- `crates/session` — allowlisted Cage session supervisor and persistent-state initialization.
- `crates/installer-core` — stable disk discovery and payload validation.
- `crates/installer-agent` — narrow privileged Curtin adapter for installation.
- `os/` — mkosi, systemd, greetd, GRUB, Plymouth, Cage and live-installer configuration.
- `tests/` — security invariants, Rust tests and boot-smoke entrypoints.

Read [DESIGN.md](DESIGN.md) before any frontend work, the [rebuild audit](docs/architecture/rebuild-audit.md), and the full milestone specification in `docs/technical-tasks/` before architectural changes.
