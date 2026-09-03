# Dead Rose OS

Dead Rose OS is a personal Linux appliance and local control plane for a private homelab or server rack. The 0.1.0 milestone proves the appliance lifecycle: live boot, graphical installation, installed first setup, local authentication, persistent state, and OCI upgrade foundations.

The user sees one full-screen Dead Rose application. Ubuntu and Kairos remain implementation details except on diagnostic and About surfaces.

## Users and environment

- Infrastructure administrators at the local console.
- Generic amd64 UEFI PCs and QEMU with standard SATA/NVMe storage and integrated graphics.
- Offline-capable operation after installation.

## Product boundary

Dead Rose owns the shell, installer experience, authentication, product state, and typed system API. Kairos owns installation, immutable Active/Passive lifecycle, Recovery, and OCI system upgrades. Ubuntu provides the Linux userspace, systemd, NetworkManager, Wayland, and graphics stack.

## Visual identity

Calm Technical / Wine Monochrome: dark-first, warm neutral surfaces, restrained wine interaction color, Geist Sans, and Geist Mono for machine data. The interface is medium-compact, keyboard accessible, and avoids desktop or SaaS conventions.
