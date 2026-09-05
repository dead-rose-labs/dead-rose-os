# Debugging

Diagnostics are intentionally separate from the normal product path.

```bash
systemctl status dead-rose-core
journalctl -b -u dead-rose-core
journalctl -b -u greetd
cat /etc/kairos-release
cat /etc/os-release
lsblk
mount
```

Core and the shell emit `DEAD_ROSE_CORE_READY` and `DEAD_ROSE_UI_READY mode=…` markers to the journal and console. Installer and upgrade logs are stored under `/var/lib/dead-rose/logs`.

The shell enables Tauri's `custom-protocol` feature by default because Factory
uses `cargo build` directly. This embeds `apps/shell/dist` and selects the
packaged frontend. `--release` alone does not enable Tauri production mode.
For a native shell connected to the Vite development server, explicitly use
`cargo run -p dead-rose-shell --no-default-features` after starting `pnpm dev`.

Separate follow-up: investigate PAM's `Unable to open env file: /etc/default/locale`
warning. It has not been established as the cause of the UI startup failure;
locale configuration is outside the current packaging fix.
