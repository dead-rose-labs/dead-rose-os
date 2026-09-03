# Installation

1. Verify the `.sha256` file.
2. Write `dead-rose-os-0.1.0-amd64.iso` to USB with Balena Etcher, `dd`, or Rufus in DD/raw mode.
3. Boot the target amd64 PC in UEFI mode.
4. In Dead Rose Installer, select the exact SSD/NVMe device.
5. Review its model, path, and capacity; type `ERASE` to confirm destruction.
6. Wait for Kairos installation to report completion.
7. Remove the USB and restart.
8. Create the local Dead Rose administrator in First Setup, then sign in.

The production ISO never auto-selects or auto-erases a disk. The auto-install configuration is isolated to CI and is not released.
