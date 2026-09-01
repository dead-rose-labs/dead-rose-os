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

## Virtual machines

Run the installer with `./dr installer-vm`; its persistent target is `build/installer-target.qcow2`. After installation, run that installed system with `./dr vm`. The VM command uses an ephemeral snapshot so a boot session cannot modify the persistent test target. Remove or rename the target only when a fresh destructive-install test is intended.

For VirtualBox use an EFI-enabled Linux 64-bit VM, VMSVGA, at least 4 GiB RAM, two CPUs, and 128 MiB video memory. Attach the ISO as optical media and a separate 32 GiB or larger target disk. Enable 3D acceleration when supported. If the host GPU path is unreliable, use the installer debug entry and set `DEAD_ROSE_SOFTWARE_RENDERING=1` for the session while diagnosing; this forces Mesa software rendering.

## Boot smoke tests

The CI path deliberately instruments test images:

```sh
DEAD_ROSE_TEST_MARKERS=1 ./dr build
DEAD_ROSE_TEST_MARKERS=1 ./dr iso
./dr installer-vm --smoke
```

The smoke test boots the ISO with a disposable disk, drives the typed backend protocol, waits for the standard Curtin installation to complete, then boots the installed target and proves that greetd, Cage, the core service and shell run correctly with the shell owned by `deadrose-ui`. CI rebuilds production artifacts without instrumentation before publishing them.

The canonical CI invocation is `./dr installer-vm --smoke`. QEMU serial output and failure-triggered systemd/journal diagnostics are retained under `build/logs/boot/` and uploaded even when the workflow fails.
