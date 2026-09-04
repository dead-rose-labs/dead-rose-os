# Architecture

## Runtime

```text
Ubuntu 26.04
  ↓ kairos-init (generic, core/no Kubernetes)
Kairos immutable appliance
  ↓
systemd (`graphical.target`) + NetworkManager
  ├─ dead-rose-core (root, hardened service)
  │    └─ /run/dead-rose/core.sock (root:deadrose, 0660)
  └─ greetd initial session → deadrose user → Cage → Dead Rose Tauri Shell
```

The `deadrose` graphical account has no password, login shell, or sudo. It has only the `video` and, when available, `render` supplementary access required by the graphical appliance session. The greetd default session remains an `_greetd`/`agreety` diagnostic fallback and is not the normal product path. Core is the only privileged Dead Rose application component. The protocol is newline-delimited typed JSON with a 64 KiB frame limit; no generic command API exists.

SQLite state, secrets, operation logs, and runtime data live under `/var/lib/dead-rose`. The Kairos install configuration bind-mounts that path from persistent storage.

## Build and lifecycle

```text
React build + Rust/Tauri build
  ↓
ubuntu:26.04 runtime
  ↓ pinned kairos-init
versioned Dead Rose OCI image
  ↓ pinned AuroraBoot
UEFI ISO
  ↓ Kairos manual-install
Active / Passive / Recovery / Persistent
```

Dead Rose never builds GPT, EFI, GRUB images, initramfs, SquashFS, A/B slots, or rollback logic. Those are Kairos/AuroraBoot responsibilities.

## Application state

Core determines live boot from the AuroraBoot/Kairos live mount (`/run/initramfs/live`) with `/run/cos/live_mode` as a compatibility indicator. Tests may explicitly set `DEAD_ROSE_BOOT_MODE`.

- Live boot always returns `live_installer`.
- Installed system without an administrator returns `first_boot`.
- Installed system with an administrator and no valid session returns `login`.
- A valid hashed session token returns `dashboard`.
