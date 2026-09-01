# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Stack

React, TypeScript, Vite, Tauri 2, Tailwind CSS, shadcn/ui with Base UI, Rust, Ubuntu Server, systemd, greetd, Cage, Curtin, GRUB, Plymouth, mkosi and xorriso. The local webview ships inside a native Linux appliance shell and never loads remote content.

## Users

Infrastructure administrators operating the primary Dead Rose control server locally, including installation, authentication, recovery and later system management.

## Product Purpose

Dead Rose OS is an installable Ubuntu-based control-plane operating system. Milestone 0.1.0 proves the permanent boot, display, authentication, session and filesystem installation foundations; after login it intentionally shows only `Coming soon`.

## Positioning

The graphical interface is the operating system experience itself: a purpose-built, offline-capable appliance shell over a minimal Wayland/Cage stack, rather than a desktop distribution or browser kiosk.

## Operating Context

UEFI amd64 hardware and QEMU; an Ubuntu Server 26.04 LTS build base; offline installation from a branded ISO; local keyboard-first login; diagnostics through an intentional recovery path.

## Capabilities and Constraints

- Standard GPT layout with a FAT32 EFI System Partition and one ext4 root filesystem.
- Persistent product data in `/var/lib/dead-rose` on the ordinary root filesystem.
- Ubuntu-owned kernel, systemd, GRUB, PAM/logind and apt/dpkg platform primitives.
- Rust-owned Argon2id authentication, rate limiting and in-memory sessions over local typed IPC.
- PAM/logind-managed greetd sessions for the unprivileged `deadrose-ui` shell and `deadrose-installer` live UI.
- A typed, group-restricted installer socket and narrow root Curtin adapter.
- No conventional desktop, remote runtime assets, fake system data, generic command execution or interactive login inside the kiosk session.
- Initial architecture is amd64/UEFI only; canonical builder is Ubuntu 26.04 amd64.

## Brand Commitments

Product name `Dead Rose OS`; Calm Technical / Wine Monochrome; dark-first; Geist Sans and Geist Mono; canonical logo at `assets/brand/dead-rose-os-logo.png` sourced from the user-provided asset.

## Evidence on Hand

- Current architecture specification: `docs/technical-tasks/Dead Rose OS — Architecture Simplification & Ubuntu Platform Integration Specification.md`.
- Binding design specification: `DESIGN.md`.
- User-provided logo: `docs/images/dead-rose-os-logo.png`.
- No testimonials, customer claims or production telemetry may be fabricated.

## Product Principles

- Permanent foundations before feature breadth.
- React presents; Rust and system services authorize.
- Prefer honest absence over simulated functionality.
- Preserve recoverability while keeping normal boot quiet.
- Every risky operation identifies its exact target and waits for authoritative confirmation.

## Accessibility & Inclusion

Target WCAG 2.2 AA where applicable: complete keyboard operation, visible focus, labeled controls, non-color-only status, restrained errors and reduced-motion support.
