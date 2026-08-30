# Debug and recovery

## Boot choices

Press Escape while GRUB starts to reveal the menu. The installed image exposes its normal entry and GRUB-generated recovery entry. The installer ISO provides normal, verbose and debug entries; debug boots to a multi-user target with increased kernel and systemd logging instead of hiding status output.

Use a recovery or debug path for diagnosis. A successful normal boot stays quiet and does not expose a shell.

## Session checks

From an authorized recovery console:

```sh
systemctl status greetd dead-rose-core
journalctl -b -u greetd -u dead-rose-core
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

The backend journal contains stage names and Curtin failures, but never the administrator password. A target identity mismatch, installer-media selection, checksum mismatch, missing `STATE` partition, or mount failure aborts installation rather than weakening validation.

## Persistent state

Verify the installed state boundary with:

```sh
findmnt /var/lib/dead-rose
systemctl status var-lib-dead\\x2drose.mount dead-rose-state-init
journalctl -b -u dead-rose-state-init -u dead-rose-core
```

Do not edit an immutable root to work around a state-mount failure. Repair the `STATE` filesystem or its GPT metadata from recovery, then reboot and confirm the mount before using the graphical shell.
