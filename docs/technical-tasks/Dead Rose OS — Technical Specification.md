# Dead Rose OS — Technical Specification
## Milestone 0.1.0 — Foundation

> Architecture note: storage, payload delivery, installation and Ubuntu-platform decisions in [Dead Rose OS — Architecture Simplification & Ubuntu Platform Integration Specification.md](Dead%20Rose%20OS%20%E2%80%94%20Architecture%20Simplification%20%26%20Ubuntu%20Platform%20Integration%20Specification.md) supersede the earlier A/B, dedicated STATE and raw-image requirements in this document.

## 1. Purpose

Create the first bootable and installable version of **Dead Rose OS**.

This milestone establishes the permanent foundation of the operating system.

This is not a UI prototype running on Ubuntu Desktop and not a disposable demo.

The resulting project must produce a real bootable operating-system image and a bootable installer ISO.

The installed system must provide the following user experience:

Power on
→ Dead Rose OS boot splash
→ graphical Dead Rose login
→ successful authentication
→ full-screen Dead Rose OS application
→ centered `Coming soon` message.

No conventional Linux desktop must be visible.

No GNOME, KDE, desktop panel, dock, file manager, terminal window or browser UI may appear during the normal user flow.

---

# 2. Core engineering rule

Do not implement throwaway architecture.

Early versions may intentionally contain very few features, but implemented infrastructure must already follow the architecture intended for the real system.

Do NOT:

- create a temporary Electron implementation;
- create a temporary Ubuntu Desktop implementation;
- use a browser opened in kiosk mode as the main application;
- create bash scripts as the runtime architecture;
- expose a normal shell as the primary UI;
- hardcode credentials;
- use fake authentication;
- directly execute privileged shell commands from React;
- create a temporary installer that will later have to be replaced;
- install the final OS by running arbitrary apt commands against the target machine.

Prefer missing functionality over disposable functionality.

---

# 3. Product identity

Product name:

`Dead Rose OS`

Internal project identifier:

`dead-rose-os`

Initial version:

`0.1.0`

Initial supported architecture:

`x86_64 / amd64`

Initial firmware target:

`UEFI`

Legacy BIOS support is not required.

The operating-system base is:

`Ubuntu Server 26.04 LTS`

Ubuntu is an internal base and must not be exposed as the product identity in the normal UI.

The installed system must identify itself as Dead Rose OS.

Provide appropriate custom `/etc/os-release` branding while preserving fields needed to identify the Ubuntu base internally where required.

---

# 4. Read these instructions before modifying UI

Before performing any frontend or visual-design task, read:

`DESIGN.md`

`DESIGN.md` is authoritative.

If a skill conflicts with DESIGN.md, DESIGN.md wins.

Do not reinterpret or replace the existing visual direction.

---

# 5. Agent skills

Use the installed skills intentionally.

## frontend-design

Use when:

- designing a new complete screen;
- choosing page composition;
- designing login;
- designing installer screens;
- designing dashboard composition.

Do not allow it to override DESIGN.md.

## ui-ux-pro-max

Use when:

- validating UX;
- designing forms;
- considering information hierarchy;
- considering responsiveness;
- considering accessibility.

## shadcn

Use for:

- choosing shadcn/ui components;
- adding shadcn components;
- checking supported component patterns;
- implementation details involving the shadcn registry.

Do not manually recreate an existing shadcn component without a good reason.

## vercel-composition-patterns

Use when:

- extracting reusable React components;
- designing component APIs;
- avoiding oversized components;
- deciding composition patterns.

## web-design-guidelines

Use after implementing each meaningful screen.

Use it as a review step.

## impeccable

Use after the functional implementation is complete to review:

- hierarchy;
- spacing;
- typography;
- visual consistency;
- polish.

## animate

Use only where motion has a functional purpose.

## review-animations

Use after motion is implemented.

Animations must remain restrained and consistent with DESIGN.md.

---

# 6. Frontend technology

Use:

- React
- TypeScript
- Tauri 2
- shadcn/ui
- Tailwind CSS
- Base UI according to the existing shadcn configuration
- Lucide icons
- Geist
- Geist Mono where specified by DESIGN.md

All dependency versions must be locked.

Commit:

- `pnpm-lock.yaml`
- `Cargo.lock`

Do not use floating dependency ranges for critical application infrastructure.

---

# 7. Display stack

The normal graphical stack is:

Linux
→ DRM/KMS
→ Wayland
→ Cage
→ Dead Rose Tauri application

Use:

`Cage`

as the kiosk Wayland compositor.

Do not install:

- GNOME Shell;
- KDE Plasma;
- XFCE;
- Cinnamon;
- a conventional desktop environment.

The Dead Rose application owns the full display.

There must not be a desktop underneath it.

---

# 8. Runtime system user

Create a dedicated system account:

`deadrose-ui`

The graphical shell must run as this unprivileged account.

The UI must never normally run as `root`.

The account must:

- not be intended for interactive shell login;
- have only the permissions required for graphical rendering and local Dead Rose IPC;
- not have unrestricted sudo permissions.

---

# 9. Boot experience

Normal boot flow:

UEFI
→ bootloader
→ Linux kernel/initrd
→ systemd
→ Plymouth
→ Wayland/Cage
→ Dead Rose OS shell

During a successful normal boot the user must not see:

- Linux kernel log output;
- systemd service lines;
- Ubuntu branding;
- shell prompts;
- getty login;
- GRUB-style menus unless boot recovery explicitly requires them.

Diagnostics must still remain accessible through an intentional recovery/debug mechanism.

Do not destroy diagnostic information merely to hide it visually.

---

# 10. Plymouth

Implement a dedicated Plymouth theme:

`dead-rose`

Location:

`os/plymouth/dead-rose/`

The initial design must follow DESIGN.md.

Required splash content:

- Dead Rose OS branding;
- centered composition;
- restrained loading animation;
- dark background;
- no Ubuntu logo;
- no verbose startup text during normal boot.

The animation must not intentionally delay boot.

The UI should transition cleanly from Plymouth to the graphical Dead Rose shell.

---

# 11. Dead Rose shell

Create application:

`apps/shell`

Technology:

React + TypeScript + Tauri 2.

The window must:

- run fullscreen;
- have no conventional OS window frame;
- have no browser chrome;
- not expose URL/navigation controls;
- not be resizable by the normal appliance user;
- fill the active display through Cage.

The application has exactly two states in this milestone:

1. Locked / Login
2. Authenticated / Dashboard

---

# 12. Login screen

Create a production-quality Dead Rose login screen.

It must follow DESIGN.md.

Required fields:

- Username
- Password

Required actions:

- Sign in

Required states:

- idle;
- submitting;
- incorrect credentials;
- temporarily rate-limited;
- internal authentication error.

Requirements:

- password must never be logged;
- password must not be persisted in frontend storage;
- no credential may be stored in localStorage;
- no plaintext credential may be written to disk;
- disable accidental form double-submission;
- support keyboard navigation;
- Enter submits;
- accessible focus states;
- clear but restrained validation.

Successful authentication transitions to Dashboard.

The visual transition should be subtle.

---

# 13. Authentication foundation

Authentication is Dead Rose authentication, not a visible Ubuntu/Linux user login.

Create Rust service:

`dead-rose-core`

For milestone 0.1.0 it only needs to provide the small subset required for:

- checking system readiness;
- authentication;
- session creation;
- logout;
- retrieving basic product/version information.

The frontend must communicate with it using a local Unix Domain Socket or another deliberately defined local IPC abstraction.

React must never read the credential database directly.

Credential hashing:

`Argon2id`

Store:

- username;
- password hash;
- password hashing parameters;
- account metadata.

Never store the password itself.

Use secure random salts.

Implement authentication attempt rate limiting.

Use constant-time comparison where applicable.

Authentication implementation must live in Rust, not JavaScript.

---

# 14. Session

After successful login issue a short-lived local session.

For this milestone an in-memory session is sufficient.

Do not persist reusable plaintext authentication tokens to browser storage.

Logout invalidates the session and returns the UI to the login screen.

Restarting the device returns the UI to the login screen.

Do not implement automatic login.

---

# 15. Dashboard

After successful login display the initial Dashboard.

This milestone intentionally contains no management functionality.

The authenticated screen should be visually minimal.

Required content:

Centered:

`Coming soon`

Nothing else is required except minimal Dead Rose shell framing if DESIGN.md calls for it.

Do not create fake:

- metrics;
- server cards;
- nodes;
- CPU usage;
- alerts;
- charts;
- navigation items with fake data.

Prefer a deliberately empty system to simulated functionality.

---

# 16. Installation architecture

Dead Rose OS must be installable from a bootable ISO.

The installation architecture is image-based.

The installer must NOT perform a traditional package-by-package Ubuntu installation.

Build the installed system once as a reproducible disk image.

Artifact:

`dead-rose-os-0.1.0-amd64.raw`

The installer writes that validated operating-system artifact onto the target disk and performs only the required target-specific initialization.

This ensures the installed OS corresponds to the tested build artifact.

---

# 17. OS image builder

Use:

`mkosi`

Primary configuration:

`os/mkosi.conf`

Partition definitions:

`os/mkosi.repart/`

The project must build an amd64 GPT disk image.

Output naming convention:

`dead-rose-os-${VERSION}-amd64.raw`

Do not depend on manually configuring a base Ubuntu installation.

The image must be reproducible from the repository and build environment.

---

# 18. Initial disk architecture

Establish a partition layout compatible with the future Dead Rose image-update architecture.

At minimum reserve and model:

- EFI System Partition
- ROOT-A
- ROOT-B
- persistent STATE

Do not design the system around a single traditional mutable Ubuntu root partition.

Partition definitions must live in source control.

Use `systemd-repart` definitions through mkosi.

The exact partition sizes should be constants documented in the repository, not hidden magic numbers in scripts.

ROOT-B does not need to contain another running version during 0.1.0, but the layout must exist.

Future update architecture must be possible without repartitioning an installed machine.

---

# 19. Persistent state

Persistent Dead Rose state belongs outside the replaceable system image.

Canonical state location:

`/var/lib/dead-rose`

Authentication data must live in persistent state.

Do not place mutable application state inside the immutable release payload.

Filesystem ownership and permissions must be explicitly defined.

Sensitive authentication data must not be readable by `deadrose-ui`.

---

# 20. Installer ISO

Create a separate installer artifact:

`dead-rose-os-${VERSION}-amd64.iso`

The ISO is not the canonical OS artifact.

The ISO contains:

- UEFI boot environment;
- Linux installer environment;
- Dead Rose installer application;
- compressed Dead Rose OS disk payload;
- integrity metadata.

Use:

`xorriso`

for ISO assembly.

Keep ISO-building logic in source control.

Do not require a developer to manually modify an Ubuntu ISO.

---

# 21. Dead Rose Installer

Create application:

`apps/installer`

Use the same:

- React;
- TypeScript;
- Tauri;
- shadcn;
- Dead Rose UI system.

The installer is a Dead Rose application and must follow DESIGN.md.

Initial installer flow:

1. Welcome
2. Select installation disk
3. Configure hostname
4. Create Dead Rose administrator
5. Confirmation / erase warning
6. Installation progress
7. Installation complete
8. Restart

The installer must clearly identify destructive disk operations.

Never silently choose and erase a disk.

The final confirmation screen must display the exact target disk.

---

# 22. Installer backend

Implement disk operations in Rust.

Do not perform privileged storage operations from JavaScript.

The backend is responsible for:

- enumerating disks;
- rejecting the currently booted installation media;
- validating minimum disk size;
- writing the OS image;
- initializing persistent STATE;
- creating the administrator credential;
- configuring hostname/machine identity;
- installing/configuring boot data if required;
- syncing writes before reporting success.

The installer must verify the embedded OS artifact before writing it.

At minimum verify a cryptographic digest.

The architecture must allow signed release manifests.

Do not trust the payload merely because it is present on the ISO.

---

# 23. Installer safety

The installer must distinguish:

- disks;
- partitions;
- removable installer media.

Show:

- model;
- capacity;
- device identifier.

Do not guess a target.

Require explicit user selection.

Before erase, require explicit confirmation.

Do not expose raw shell commands to the frontend.

Errors must return structured error codes and human-readable UI messages.

---

# 24. ISO boot experience

When booting the installation ISO the user must see Dead Rose branding.

The user should not land in:

- Ubuntu Subiquity;
- a shell;
- a conventional Ubuntu installer;
- GNOME.

The installer is the primary interface.

---

# 25. Repository structure

Use the following top-level structure as the baseline:

dead-rose-os/
├── AGENTS.md
├── DESIGN.md
├── README.md
├── LICENSE
├── VERSION
├── Cargo.toml
├── Cargo.lock
├── rust-toolchain.toml
├── package.json
├── pnpm-lock.yaml
├── pnpm-workspace.yaml
├── apps/
│   ├── shell/
│   └── installer/
├── packages/
│   ├── ui/
│   ├── brand/
│   └── shared/
├── crates/
│   ├── core/
│   ├── auth/
│   ├── ipc/
│   ├── installer-core/
│   └── system-types/
├── os/
│   ├── mkosi.conf
│   ├── mkosi.repart/
│   ├── mkosi.extra/
│   ├── plymouth/
│   ├── cage/
│   ├── systemd/
│   ├── sysusers/
│   ├── tmpfiles/
│   └── installer/
├── assets/
│   └── brand/
├── scripts/
│   ├── bootstrap-builder.sh
│   ├── build-os.sh
│   ├── build-iso.sh
│   ├── run-vm.sh
│   ├── run-installer-vm.sh
│   └── test.sh
├── tests/
│   ├── integration/
│   └── boot/
└── .github/
    └── workflows/

Do not collapse unrelated concerns into one directory.

---

# 26. Shared UI

`packages/ui`

contains the shared Dead Rose design-system components.

Do not create separate visual implementations for:

- Installer
- Login
- Shell

They must use the same tokens and shared components.

Use shadcn/ui components as defined by DESIGN.md.

Do not introduce another general-purpose component library.

---

# 27. Branding assets

Canonical branding directory:

`assets/brand`

Applications must import from the canonical asset source or generated package.

Do not scatter duplicate logos throughout application folders.

If a final graphic logo does not yet exist, use the official text wordmark:

`Dead Rose OS`

Do not invent an unrelated permanent logo.

---

# 28. Systemd

Use native systemd units.

Do not use legacy init scripts.

Create explicit units for:

- Dead Rose core;
- graphical session;
- installer session where applicable.

Define:

- dependencies;
- ordering;
- restart behavior;
- hardening options.

Do not hide startup behavior in shell profiles.

---

# 29. Graphical startup

The installed graphical application must start automatically after the system reaches the appropriate target.

Use systemd to start:

Wayland/Cage
→ Dead Rose shell

The shell must start without requiring:

- SSH;
- terminal commands;
- manual login;
- `startx`.

The normal user should never need to type:

`dead-rose`

to launch the OS interface.

---

# 30. Recovery

Do not remove Linux recovery capability.

The graphical shell is the normal interface, but diagnostics must remain possible if it fails.

Provide and document an intentionally accessed recovery TTY or recovery boot path.

Recovery is not part of the normal visual experience.

Do not show it unless deliberately requested or graphical startup fails.

---

# 31. Build tooling UX

Create a project command wrapper:

`./dr`

Required commands:

`./dr bootstrap`

Prepare a supported Ubuntu 26.04 amd64 builder.

`./dr build`

Build Dead Rose OS raw disk image.

`./dr iso`

Build installer ISO.

`./dr vm`

Boot the built OS image in QEMU.

`./dr installer-vm`

Create a temporary virtual target disk and boot the installer ISO against it.

`./dr test`

Run automated tests.

`./dr clean`

Remove generated artifacts without deleting source files.

`./dr help`

Display available commands.

The wrapper may delegate to scripts or another build tool internally.

The interface must remain stable.

---

# 32. Build outputs

Generated artifacts belong under:

`build/`

Example:

build/
├── dead-rose-os-0.1.0-amd64.raw
├── dead-rose-os-0.1.0-amd64.raw.zst
├── dead-rose-os-0.1.0-amd64.raw.sha256
├── dead-rose-os-0.1.0-amd64.iso
├── dead-rose-os-0.1.0-amd64.iso.sha256
└── logs/

Do not commit generated OS images to Git.

---

# 33. Builder

Supported canonical builder:

Ubuntu 26.04 LTS amd64.

Create:

`scripts/bootstrap-builder.sh`

It must:

- validate distribution;
- validate architecture;
- install required build packages;
- install/pin Rust tooling;
- install/pin Node/pnpm tooling;
- validate mkosi;
- validate xorriso;
- validate QEMU;
- validate UEFI firmware availability;
- print a clear final readiness report.

Do not assume dependencies happen to exist.

---

# 34. Toolchain reproducibility

Pin important toolchains.

Use:

`rust-toolchain.toml`

for Rust.

Use the package manager field and lockfile for pnpm.

Commit exact application dependency locks.

Document mkosi requirements.

Do not silently use arbitrary globally installed versions if they affect image reproducibility.

---

# 35. QEMU development environment

The project must be fully testable without physical hardware.

`./dr vm` must boot:

- UEFI;
- the generated Dead Rose OS disk.

`./dr installer-vm` must boot:

- UEFI;
- installer ISO;
- temporary blank virtual disk.

After installation the test tooling must be able to reboot from the target virtual disk.

Prefer hardware acceleration where available.

The test environment must still clearly fail with an actionable message if acceleration is unavailable.

---

# 36. Automated smoke test

Create at least one automated boot smoke test.

It must prove that:

- image was generated;
- firmware can boot it;
- systemd reaches the Dead Rose graphical target;
- `dead-rose-core` is active;
- graphical shell process is active.

Do not rely only on the developer visually looking at a window.

---

# 37. Authentication tests

Add automated tests for:

- valid password;
- invalid password;
- unknown user;
- malformed requests;
- rate limiting;
- password hash creation;
- session invalidation;
- logout.

Never include real credentials in tests.

---

# 38. Installer tests

At minimum test:

- disk enumeration;
- installer media exclusion;
- disk-size validation;
- payload hash verification;
- invalid payload rejection;
- administrator creation logic.

Keep destructive disk tests isolated to disposable test devices/images.

Never run destructive installer tests against arbitrary host disks.

---

# 39. Security boundaries

React frontend:

untrusted presentation layer.

Tauri Rust layer:

native application boundary.

Dead Rose core:

authoritative local application service.

Privileged installer/system service:

small privileged boundary.

Do not allow arbitrary command execution from frontend IPC.

Prefer specific typed operations such as:

`authenticate(...)`

instead of:

`run_command("...")`

Never expose a generic root shell execution endpoint.

---

# 40. Tauri security

Use a restrictive capability configuration.

Do not grant frontend capabilities it does not need.

Disable development tools in release builds.

Do not allow arbitrary navigation.

Do not load remote application content.

Production UI assets must be local.

Define a strict Content Security Policy compatible with the application.

---

# 41. Network

Dead Rose OS 0.1.0 does not require remote management.

Do not create fake remote APIs merely because they will exist later.

The architecture must not prevent adding them.

The 0.1.0 UI/auth implementation must work fully offline.

The installer must not require the Internet to install the OS payload contained on the ISO.

---

# 42. Dashboard restrictions

The Dashboard intentionally contains:

`Coming soon`

Do not overbuild it.

This milestone validates:

- operating-system build;
- boot;
- graphics;
- branding;
- authentication;
- image installation;
- UI architecture.

It is not yet a server-management milestone.

---

# 43. Error experience

Normal application errors must remain inside Dead Rose UI.

Never dump:

- Rust panic output;
- JavaScript stack traces;
- kernel logs;
- systemd logs;

onto the main graphical screen during normal operation.

Log detailed diagnostics through journald.

Show users concise Dead Rose-styled error messages.

---

# 44. Logging

Rust services must use structured logging.

Integrate with journald.

Never log:

- passwords;
- password hashes;
- secrets;
- complete authentication tokens.

Log authentication failures without sensitive credential contents.

---

# 45. Version

Single source:

`VERSION`

Initial value:

`0.1.0`

Expose version in:

- OS image metadata;
- `/etc/os-release`;
- Rust build metadata;
- Tauri application;
- installer;
- artifact filenames.

Do not maintain multiple independently edited version strings.

---

# 46. README

README must explain:

- what Dead Rose OS is;
- supported architecture;
- build prerequisites;
- builder setup;
- how to build;
- how to build ISO;
- how to launch VM;
- how to test installer;
- where build artifacts appear;
- how to access recovery mode;
- project directory structure.

Commands shown in README must actually work.

---

# 47. AGENTS.md

Create `AGENTS.md`.

It must tell coding agents:

1. Read DESIGN.md before frontend tasks.
2. Do not introduce temporary runtime architecture.
3. Do not add libraries without justification.
4. Prefer Rust for privileged/system logic.
5. React is presentation, not system authority.
6. Never expose generic command execution.
7. Use shared Dead Rose UI.
8. Run relevant tests before declaring completion.
9. Do not silently weaken security to make a demo work.
10. Do not simulate functionality that is not implemented.

---

# 48. Development quality

Rust:

- `cargo fmt`
- `cargo clippy`
- tests

Frontend:

- TypeScript strict mode;
- lint;
- formatting;
- production build.

No ignored TypeScript errors.

No blanket `any`.

No ignored Rust errors with `.unwrap()` in externally influenced control paths unless explicitly justified.

---

# 49. CI

Create GitHub Actions workflows for:

- frontend lint/typecheck;
- Rust fmt;
- Rust clippy;
- Rust tests;
- frontend build.

OS image build may be a separate privileged/compatible builder workflow if necessary.

Do not make CI architecture dependent on a developer laptop.

---

# 50. Definition of Done — Dead Rose OS 0.1.0

The milestone is complete only when the following sequence works:

1. Clean supported builder is prepared using `./dr bootstrap`.
2. `./dr build` produces a bootable Dead Rose OS disk image.
3. `./dr iso` produces a bootable installer ISO.
4. `./dr installer-vm` boots the ISO.
5. Dead Rose branded installer appears.
6. User selects virtual target disk.
7. User creates administrator credentials.
8. Installer completes successfully.
9. VM reboots from installed target disk.
10. Dead Rose Plymouth animation appears.
11. No Ubuntu desktop/login UI appears.
12. Dead Rose graphical login appears.
13. Invalid credentials are rejected.
14. Valid credentials are accepted.
15. Dashboard opens.
16. Screen displays `Coming soon` centered according to DESIGN.md.
17. Reboot returns the system to locked/login state.
18. No normal interaction exposes Ubuntu shell or desktop.
19. Core services are non-root unless privilege is genuinely required.
20. Automated smoke tests pass.

---

# 51. Final expected user experience

Installation:

Power on installation media
→ Dead Rose OS Installer
→ choose disk
→ create administrator
→ install
→ restart

Installed system:

Power on
→ Dead Rose OS branded loading animation
→ Dead Rose OS Login
→ authenticate
→ fullscreen Dead Rose OS
→ `Coming soon`

Nothing else is required in 0.1.0.

Build only this milestone.

Do not implement Nodes, workloads, containers, storage management, monitoring, networking UI, remote control, deployment or cluster features yet.
