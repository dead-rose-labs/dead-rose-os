# Dead Rose OS

- Target: Arch Linux x86_64, UEFI, KDE Plasma Wayland, Calamares, Archiso.
- Use upstream components and supported configuration. No custom installer,
  partitioner, bootloader, compositor, authentication, networking or update stack.
- Keep root login locked and remove all live-only privileges from installed systems.
- Keep explicit disk selection and Calamares confirmation; never auto-install to hardware.
- Preserve upstream attribution. No AUR dependencies in the base image.
- Pin external source revisions and GitHub Action SHAs. Do not disable package signatures.
- Never claim ISO boot, installation or hardware acceptance without recorded evidence.
- Per the current user instruction, run builds and tests in GitHub Actions,
  not on this Mac. The user reviews Actions results after push.
