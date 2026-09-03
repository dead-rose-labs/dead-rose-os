# Debug and recovery

## Boot choices

Press Escape while GRUB starts to reveal the menu. The installed image exposes its normal entry and GRUB-generated recovery entry. The installer ISO provides normal, safe-graphics, verbose and debug entries. Safe graphics keeps kernel modesetting available to Cage but uses the pixman renderer and disables WebKit DMABUF rendering. Debug boots to a multi-user target with increased kernel and systemd logging instead of hiding status output.

The installer debug entry also enables systemd's root debug shell on tty9. In
VirtualBox, switch to it with Host+F9 (the default Host key on Windows is Right
Ctrl). This shell exists only after explicitly selecting the debug GRUB entry;
normal boot continues directly to the Dead Rose interface without a tty1 login.

If the graphical session is not healthy 90 seconds after boot, and every 60 seconds thereafter, Dead Rose appends
targeted greetd, Cage, application, DRM and user-session diagnostics to
`/var/log/dead-rose/graphical-boot.log` and mirrors the report to the console.
The first line includes `failed_stage`, which distinguishes the backend service,
backend socket, greetd, Cage, application process, development URL and bundled
frontend asset stages. A healthy frontend journal entry contains
`DEAD_ROSE_FRONTEND_READY` with `url=tauri://localhost` (rendered as
`http://tauri.localhost` on platforms where WebKit maps the custom scheme).
The installer backend uses the Unix socket `/run/dead-rose-installer/backend.sock`;
it does not listen on a TCP localhost port. The session journal records separate
application and Cage exit codes, terminating signals and core-dump state. After
an unexpected normal-renderer exit, the supervisor retries in safe graphics mode.

Use a recovery or debug path for diagnosis. A successful normal boot stays quiet and does not expose a shell.

## Session checks

From an authorized recovery console:

```sh
systemctl status greetd dead-rose-core
journalctl -b -u greetd -u dead-rose-core
journalctl -b _UID="$(id -u deadrose-ui)" | grep DEAD_ROSE_FRONTEND_READY
loginctl list-sessions
pgrep -a cage
pgrep -a dead-rose-shell
```

The shell must run as `deadrose-ui`, not root. Inspect a process with `ps -o user,pid,ppid,args -p PID`. Repeated application crashes are intentionally delayed by `dead-rose-session`; the journal records the exit and rate limit.

For the live installer also inspect:

```sh
systemctl status dead-rose-installer-backend
journalctl -b -u dead-rose-installer-backend -u greetd
ls -l /run/dead-rose-installer/backend.sock
ls -l /dev/disk/by-id
```

The backend journal contains stage names and Curtin failures, but never the administrator password. A target identity mismatch, installer-media selection, checksum mismatch, missing `ROOT` partition, or mount failure aborts installation rather than weakening validation.

## Persistent state

Verify the installed state directory with:

```sh
findmnt -T /var/lib/dead-rose
systemctl status dead-rose-state-init
journalctl -b -u dead-rose-state-init -u dead-rose-core
```

`/var/lib/dead-rose` is part of the ordinary ext4 `ROOT` filesystem. If initialization fails, inspect root-filesystem health, ownership and the `dead-rose-state-init` journal from recovery; there is no separate state mount to repair.
