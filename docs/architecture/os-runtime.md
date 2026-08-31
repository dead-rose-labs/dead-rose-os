# OS runtime architecture

## Installed system

The normal graphical path is:

```text
systemd graphical.target
  -> greetd on tty1
  -> PAM + systemd-logind session for deadrose-ui
  -> dead-rose-session
  -> Cage
  -> dead-rose-shell (Tauri/React)
```

`greetd` owns VT, PAM and logind integration. `dead-rose-session` is deliberately small: it accepts only the source-controlled shell and installer executable paths, verifies that the executable is root-owned, supervises Cage, and rate-limits crash loops. It is not a generic launcher. The graphical account has no login shell and is never privileged.

`dead-rose-core` is the system authority for authentication and persistent product state. Typed local IPC is used at the UI boundary. The persistent `STATE` filesystem is mounted at `/var/lib/dead-rose`; `dead-rose-state-init` applies the installed hostname before the core and graphical session start.

## Live installer

The installer uses the same session chain with the `deadrose-installer` account and `dead-rose-installer` application. Its Tauri process is unprivileged and contains no disk-writing implementation.

Privileged installation is isolated in `dead-rose-installer-agent`, a root system service reachable through `/run/dead-rose-installer/backend.sock`. Access is restricted to `deadrose-installer-ipc`. The protocol contains a fixed set of requests: list disks, install, and reboot. Installation requires the selected kernel device and matching stable `/dev/disk/by-id` identity, rejects the boot medium, verifies the embedded compressed image SHA-256, and invokes Curtin with a generated fixed-shape configuration. The pinned Curtin source receives the reviewed `patches/curtin/dd-zstd.patch`, allowing it to stream the verified zstd payload directly to the target without expanding or hashing the raw image in the live root. No generic command execution is exposed.

Ubuntu 26.04 does not publish Curtin as a binary archive package. The live-image build therefore stages Canonical's upstream Curtin source at the immutable commit and SHA-256 recorded in `scripts/stage-curtin.sh`, while all runtime dependencies still come from Ubuntu packages. This keeps the mature engine, makes the supply-chain input reviewable, and prevents an unpinned network dependency.

Curtin writes the complete source image, preserving its GPT `EFI`, `ROOT-A`, `ROOT-B`, and `STATE` layout. The backend then locates `STATE` by partition metadata on the selected disk, mounts only that partition, and writes the administrator credential and hostname state. The UI reports real backend progress and failures.

## Build profiles

`os/mkosi.conf` builds the installed GRUB disk image. `os/installer/mkosi.conf` builds the live root used by the custom UEFI installer ISO. Runtime files are staged under `build/`; the source `mkosi.extra` tree is not mutated during builds.

Boot-smoke marker services are included only when `DEAD_ROSE_TEST_MARKERS=1`. Release artifacts are rebuilt without those services.
