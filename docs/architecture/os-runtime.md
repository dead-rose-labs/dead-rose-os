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

Ubuntu Server 26.04 provides the kernel, systemd, GRUB, Plymouth, PAM, logind, greetd, Cage, apt and dpkg. Dead Rose owns the branded boot, shell, installer, authentication service and typed local IPC layered on that platform. It does not replace standard Linux lifecycle or package-management primitives.

`greetd` owns VT, PAM and logind integration. `dead-rose-session` accepts only the source-controlled shell and installer executable paths, verifies that the executable is root-owned, supervises Cage, and rate-limits crash loops. It is not a generic launcher. The graphical account has no login shell and is never privileged.

`dead-rose-core` is the system authority for authentication and product state. Typed local IPC is used at the UI boundary. Persistent Dead Rose data is an ordinary directory at `/var/lib/dead-rose` on the root filesystem; `dead-rose-state-init` applies the installed hostname before the core and graphical session start.

## Live installer

The installer uses the same session chain with the `deadrose-installer` account and `dead-rose-installer` application. Its Tauri process is unprivileged and contains no disk-writing implementation.

Privileged installation is isolated in `dead-rose-installer-agent`, a root system service reachable through `/run/dead-rose-installer/backend.sock`. Access is restricted to `deadrose-installer-ipc`. The protocol contains a fixed set of requests: list disks, install, and reboot. Installation requires the selected kernel device and matching stable `/dev/disk/by-id` identity, rejects the boot medium, verifies the embedded root-filesystem archive SHA-256, and invokes Curtin with a generated fixed-shape configuration. No generic command execution is exposed.

The backend retains systemd namespace and kernel hardening, but explicitly does not enable `RestrictSUIDSGID`: Curtin must preserve the trusted Ubuntu rootfs file modes, including package-owned SUID/SGID files. This also avoids the systemd 259 `openat2()` filter interaction that prevents GNU tar extraction with `ENOSYS`.

Curtin uses standard Ubuntu/Linux storage operations to create a GPT containing a 512 MiB FAT32 `EFI` partition and one ext4 `ROOT` partition using the remaining disk. It extracts the verified Ubuntu root filesystem archive into `ROOT`, writes `/etc/fstab`, and installs GRUB. The backend refreshes the target partition table, mounts `ROOT`, and writes the administrator credential and hostname under `/var/lib/dead-rose`. The UI reports real backend progress and failures.

Ubuntu 26.04 does not publish Curtin as a binary archive package. The live-image build therefore stages Canonical's upstream Curtin source at the immutable commit and SHA-256 recorded in `scripts/stage-curtin.sh`, while runtime dependencies come from Ubuntu packages. The staged source is unmodified and its required `tgz` extraction support is validated during the build.

## Build profiles

`os/mkosi.conf` builds the Ubuntu directory root used to produce the verified root-filesystem archive. `os/installer/mkosi.conf` builds the live root used by the custom UEFI installer ISO. Runtime files are staged under `build/`; the source `mkosi.extra` tree is not mutated during builds.

The release ISO has two views over one boot path: UEFI optical firmware reaches the appended FAT32 ESP through El Torito, and UEFI USB firmware reaches that ESP through the image's GPT. A protective MBR identifies the GPT to disk-oriented tooling. The ESP contains the removable-media fallback executable `EFI/BOOT/BOOTX64.EFI`; its embedded GRUB config searches for the ISO9660 label before loading the shared external config, kernel and initrd.

Boot-smoke marker services are included only when `DEAD_ROSE_TEST_MARKERS=1`. Release artifacts are rebuilt without those services.
