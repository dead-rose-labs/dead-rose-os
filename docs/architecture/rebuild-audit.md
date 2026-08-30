# OS runtime rebuild audit

This audit records the repository state assessed before the runtime migration and the resulting action. The technical specification, not the prototype behavior, is authoritative.

| Component | Status | Action | Reason |
|---|---|---|---|
| Shell and installer React UI | KEEP | Preserve | Already matches the Dead Rose product and shared design system. |
| `packages/ui`, fonts, logo and Plymouth theme | KEEP | Preserve | Source-controlled shared brand foundation. |
| Rust auth, typed core IPC and persistent sessions | KEEP | Preserve | System authority is correctly outside React. |
| GPT A/B plus `STATE` layout | KEEP | Preserve | Provides immutable/replaceable roots and persistent state. |
| mkosi raw-image builder | REFACTOR | Stage runtime files in `build/` | The image model remains useful, but builds must not mutate source trees. |
| ISO assembly and initrd live-root integration | REFACTOR | Retain and validate | The live boot mechanism is product-specific but independent of the broken graphical lifecycle. |
| Installer frontend | REFACTOR | Make fully unprivileged | The screens are reusable; raw disk authority is not. |
| Installer disk code | REPLACE | Curtin-backed root agent | Payload validation and discovery remain local, while a mature engine performs destructive installation. |
| Root systemd Cage units | REMOVE | Replace with greetd | They bypass PAM/logind and required hand-made runtime/session state. |
| Hand-made Cage environment | REMOVE | Replace with user session environment | Manual `XDG_RUNTIME_DIR` is a symptom of the obsolete lifecycle. |
| Direct root installer UI service | REMOVE | Split UI/backend | Cage and the Tauri UI must not be root. |
| GRUB/systemd-boot mixture | REPLACE | GRUB-only target profile | One supported boot path is easier to recover and validate. |

## Previous flow

```text
systemd system service (root)
  -> manually prepared Cage environment
  -> Cage
  -> Tauri shell or installer with coupled privilege
```

This duplicated display-manager responsibilities, did not create a normal PAM/logind graphical session, and made an `XDG_RUNTIME_DIR` workaround part of the architecture.

## Target flow

```text
systemd
  +-> privileged Dead Rose core/installer agent
  `-> greetd
       -> PAM + logind unprivileged session
            -> allowlisted dead-rose-session
                 -> Cage
                      -> Dead Rose Tauri UI
```

## Migration plan completed

1. Preserve UI, branding, authentication, GPT layout and viable image tooling.
2. Delete both direct Cage system services and the manual environment file.
3. Introduce one allowlisted session supervisor shared by installed and live profiles.
4. Configure greetd sessions for dedicated non-login users.
5. Move privileged installation behind a typed, restricted Unix socket and Curtin.
6. Make installed GRUB, branded Plymouth, persistent identity and recovery explicit.
7. Add static checks plus QEMU installer-to-installed boot smoke coverage.
8. Document build, runtime, debugging and VM validation.
