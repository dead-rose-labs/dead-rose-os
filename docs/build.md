# Build and test

## Builder

The supported image builder is Ubuntu Server 26.04 LTS on `amd64` with UEFI tooling. From a clean checkout:

```sh
./dr bootstrap
./dr test
./dr build
./dr iso
```

`bootstrap` installs the pinned build prerequisites and validates the host. Portable Rust, TypeScript, lint and repository checks may be run on macOS, but producing the Ubuntu image and ISO there is unsupported.

The intermediate Ubuntu root directory, verified root-filesystem archive, installer ISO, checksums and logs are written beneath `build/`. `./dr clean` removes only generated entries directly beneath that directory. The rootfs archive is an installer payload, not a bootable release artifact; the ISO is the release artifact.

The installer artifact is a hybrid UEFI image. Its ISO9660 filesystem remains bootable through El Torito when attached as an optical disc, while an appended FAT32 EFI System Partition, valid GPT and protective MBR make the same bytes bootable when written directly to USB. Both paths enter `EFI/BOOT/BOOTX64.EFI`; GRUB locates the ISO filesystem by the `DEAD_ROSE_INSTALLER` label and loads `/live/vmlinuz` and `/live/initrd` without relying on a CD-specific device name.

Both image paths build the Vite frontend before compiling the Tauri executable and enable Tauri's `custom-protocol` release feature. The resulting shell and installer load bundled assets from `tauri://localhost`; neither production image requires a Vite, npm or TCP localhost server. A release compile without the bundled-assets feature fails at compile time.

## Virtual machines

Run the installer with `./dr installer-vm`; its persistent target is `build/installer-target.qcow2`. After installation, run that installed system with `./dr vm`. The VM command uses an ephemeral snapshot so a boot session cannot modify the persistent test target. Remove or rename the target only when a fresh destructive-install test is intended.

For VirtualBox use an EFI-enabled Linux 64-bit VM, VMSVGA, at least 4 GiB RAM, two CPUs, and 128 MiB video memory. Attach the ISO as optical media and a separate 32 GiB or larger target disk. Enable 3D acceleration when supported. If the host GPU path is unreliable, select `Dead Rose OS Installer (safe graphics)` in GRUB; normal boot first uses the detected hardware path and automatically retries with pixman plus WebKit DMABUF rendering disabled after an unexpected graphical exit.

## Boot smoke tests

The CI path deliberately instruments test images:

```sh
DEAD_ROSE_TEST_MARKERS=1 ./dr build
DEAD_ROSE_TEST_MARKERS=1 ./dr iso
./dr installer-vm --smoke-cd
./dr installer-vm --smoke-usb
./dr installer-vm --smoke
```

The first two smoke tests independently boot the installer under OVMF as a virtual CD/DVD and as a byte-for-byte raw USB mass-storage device. Both must reach `DEAD_ROSE_INSTALLER_UI_READY`. The full smoke test then boots the ISO with a disposable target disk, drives the typed backend protocol, waits for the standard Curtin installation to complete, and boots the installed target to prove that greetd, Cage, the core service and shell run correctly with the shell owned by `deadrose-ui`. Readiness requires the Tauri page-load marker to report a bundled `tauri://localhost` URL; a `127.0.0.1` development URL fails the smoke test.

Before boot, `tests/integration/iso-hybrid.sh` records `fdisk -l`, xorriso El Torito data and xorriso System Area data, then validates the protective MBR, primary GPT header, EFI partition type, removable-media fallback executable, kernel and initrd. CI runs all three smoke commands, rebuilds production artifacts without instrumentation, validates the hybrid layout again during the release build, and only then uploads the ISO. QEMU serial output and failure-triggered systemd/journal diagnostics are retained under `build/logs/boot/`.
