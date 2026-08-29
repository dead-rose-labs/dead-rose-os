# Dead Rose OS

Dead Rose OS is a purpose-built, local graphical control-plane operating system. Milestone `0.1.0` establishes the boot, display, authentication, session and image-based installation foundations. The authenticated shell intentionally contains only `Coming soon`.

## Supported platform

- Target: UEFI `amd64` / `x86_64`
- OS base: Ubuntu Server 26.04 LTS (not exposed in the normal product UI)
- Canonical builder: Ubuntu 26.04 LTS `amd64`
- Development virtualization: QEMU + OVMF

macOS and other hosts can run frontend and portable Rust checks, but they are not supported image builders.

## Build interface

```sh
./dr bootstrap       # install and validate builder dependencies
./dr build           # build raw disk image and digest
./dr iso             # build the branded installer ISO and digest
./dr vm              # boot the installed image in QEMU
./dr installer-vm    # boot the ISO with a disposable 48 GiB target
./dr test            # frontend, Rust and repository tests
./dr clean           # remove generated files under build/
```

Artifacts are written to `build/`:

```text
dead-rose-os-0.1.0-amd64.raw
dead-rose-os-0.1.0-amd64.raw.zst
dead-rose-os-0.1.0-amd64.raw.sha256
dead-rose-os-0.1.0-amd64.iso
dead-rose-os-0.1.0-amd64.iso.sha256
logs/
```

The installed GPT layout is source-controlled under `os/mkosi.repart/`: `EFI` 512 MiB, `ROOT-A` 8 GiB, `ROOT-B` 8 GiB, and a `STATE` partition with an 8 GiB minimum that grows to fill the remaining disk. Mutable Dead Rose state lives on `STATE` at `/var/lib/dead-rose`; release roots remain replaceable.

## Installation and recovery

Boot the ISO, explicitly select a non-installer disk, configure the hostname and administrator, review the exact target, type `ERASE`, then install and restart. The installer verifies the embedded raw image before writing it.

The graphical shell owns `tty1`. Recovery remains intentionally available through the UEFI recovery entry or `systemd.unit=rescue.target`; a serial console can also be enabled by the operator. Recovery output is never part of a successful normal boot.

## Repository map

- `apps/shell` — fullscreen Tauri login and authenticated shell.
- `apps/installer` — fullscreen image installer.
- `packages/ui` — shared Dead Rose tokens and UI primitives.
- `crates/auth` — Argon2id credentials, rate limiting and sessions.
- `crates/core` — authoritative local service.
- `crates/ipc` — typed Unix socket transport.
- `crates/installer-core` — disk validation, payload verification and image writing.
- `os/` — mkosi, systemd-repart, Plymouth, Cage and installer image configuration.
- `tests/` — security invariants, Rust tests and boot-smoke entrypoints.

Read [DESIGN.md](DESIGN.md) before any frontend work and the full milestone specification in `docs/technical-tasks/` before architectural changes.
