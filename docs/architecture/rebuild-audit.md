# OS architecture simplification audit

This audit records the KEEP/MODIFY/REMOVE decision required by the current Architecture Simplification & Ubuntu Platform Integration Specification. The current specification supersedes prototype assumptions in the earlier milestone document.

| Component | Decision | Result |
|---|---|---|
| Shell and installer React UI | KEEP | Preserved the branded product experience and shared UI. |
| `packages/ui`, fonts, logo and Plymouth theme | KEEP | Preserved the source-controlled brand foundation. |
| Rust auth, typed IPC, Core and sessions | KEEP | System authority remains outside React. |
| greetd, Cage, PAM and logind lifecycle | KEEP | Standard Linux session ownership remains intact. |
| GRUB, Plymouth, live ISO and QEMU smoke | KEEP | Existing boot, recovery and verification paths remain. |
| Installed payload build | MODIFY | mkosi now produces a directory rootfs which is archived for Curtin extraction. |
| Installer storage configuration | MODIFY | Curtin creates one GPT `EFI` partition and one ext4 `ROOT` partition. |
| Persistent product state | MODIFY | `/var/lib/dead-rose` is an ordinary root-filesystem directory. |
| Installer privileged backend | MODIFY | It verifies the archive, invokes standard Curtin stages, then initializes state in `ROOT`. |
| A/B partitioning and boot assumptions | REMOVE | `ROOT-A`, `ROOT-B` and future rollback scaffolding were removed. |
| Dedicated `STATE` partition and mount | REMOVE | No present product requirement justifies a separate partition. |
| Raw disk image delivery | REMOVE | Sparse RAW, zstd and bmap generation/copying were removed. |
| Curtin bmap patch | REMOVE | The pinned upstream Curtin source is staged without local behavioral patches. |
| systemd-repart layout | REMOVE | Installed disk layout is owned by the standard Curtin install configuration. |

## Resulting flow

```text
Ubuntu live ISO
  -> greetd/PAM/logind -> Cage -> unprivileged installer UI
  -> typed restricted socket -> Rust installer agent
  -> Curtin: GPT + EFI + ROOT, extract verified rootfs, install GRUB
  -> initialize /var/lib/dead-rose in ROOT
  -> reboot into Ubuntu systemd/greetd/Cage/Dead Rose shell
```

This is an Ubuntu-based product OS, not a custom Linux distribution mechanism. Dead Rose remains responsible for its user experience and narrow system services while Ubuntu remains responsible for operating-system primitives.
